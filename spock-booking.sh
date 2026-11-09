#!/usr/bin/env bash
# AWS Agentic Spock | install the booking API and wire it to the LiveDemo flow.
# Usage: bash spock-booking.sh
# To select a named AWS CLI profile: AWS_PROFILE=your-profile bash spock-booking.sh
set -euo pipefail
umask 077

spock_config="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.spock.env"
if [[ -f "$spock_config" ]]; then
  source "$spock_config"
fi
: "${SPOCK_AWS_ACCOUNT_ID:?Set SPOCK_AWS_ACCOUNT_ID in .spock.env}"
: "${SPOCK_WORKSPACE_ID:?Set SPOCK_WORKSPACE_ID in .spock.env}"
: "${SPOCK_APPLICATION_ID:?Set SPOCK_APPLICATION_ID in .spock.env}"
export SPOCK_WORKSPACE_ID SPOCK_APPLICATION_ID


for program in aws node npm; do
  if ! command -v "$program" >/dev/null 2>&1; then
    printf 'Install %s, then run this script again.\n' "$program" >&2
    exit 1
  fi
done
if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) < 20 ? 1 : 0)'; then
  printf 'This script needs Node.js 20 or newer.\n' >&2
  exit 1
fi

account="$(aws --region us-west-2 --no-cli-pager sts get-caller-identity --query Account --output text)"
if [[ "$account" != "$SPOCK_AWS_ACCOUNT_ID" ]]; then
  printf 'The active AWS CLI credentials point to a different account than the Spock Connect instance. Select its profile and rerun.\n' >&2
  exit 1
fi

spock_work="$(mktemp -d "${TMPDIR:-/tmp}/spock-booking.XXXXXXXX")"
trap 'rm -rf -- "$spock_work"' EXIT
cd "$spock_work"
npm install --no-audit --no-fund amazon-connect-acxd-sdk@0.3.0

if [[ -z "${ACXD_API_KEY:-}" ]]; then
  read -r -s -p 'Spock API key (hidden): ' ACXD_API_KEY </dev/tty
  printf '\n'
fi
if [[ "$ACXD_API_KEY" != acxd_live_*.* ]]; then
  printf 'Enter the full API key for the spock-deploy Designer user.\n' >&2
  exit 1
fi
export ACXD_API_KEY

cat > booking-stack.yaml <<'SPOCK_CFN'
AWSTemplateFormatVersion: '2010-09-09'
Description: Demo reservation API for AWS Agentic Spock
Resources:
  BookingTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Ref AWS::StackName
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
      TimeToLiveSpecification:
        AttributeName: expiresAt
        Enabled: true
  BookingSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Description: Shared webhook credential for Spock's demo reservation API
      GenerateSecretString:
        ExcludePunctuation: true
        PasswordLength: 48
  BookingLogs:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${AWS::StackName}'
      RetentionInDays: 7
  BookingRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: SpockBookingAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:BatchGetItem
                  - dynamodb:PutItem
                  - dynamodb:DeleteItem
                Resource: !GetAtt BookingTable.Arn
              - Effect: Allow
                Action: secretsmanager:GetSecretValue
                Resource: !Ref BookingSecret
              - Effect: Allow
                Action:
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: !GetAtt BookingLogs.Arn
  BookingHandler:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Ref AWS::StackName
      Runtime: python3.12
      Handler: index.handler
      Role: !GetAtt BookingRole.Arn
      MemorySize: 128
      Timeout: 10
      Environment:
        Variables:
          BOOKING_TABLE: !Ref BookingTable
          BOOKING_SECRET: !Ref BookingSecret
      Code:
        ZipFile: |
          """Spock's demo schedule and DynamoDB-backed reservation operations."""

          import base64
          import hashlib
          import hmac
          import json
          import os
          import re
          import secrets
          import time
          from datetime import datetime, timedelta
          from functools import lru_cache
          from zoneinfo import ZoneInfo

          import boto3
          from botocore.config import Config
          from botocore.exceptions import BotoCoreError, ClientError


          TABLE_NAME = os.environ["BOOKING_TABLE"]
          TIME_ZONE = ZoneInfo("America/New_York")
          CONFIG = Config(connect_timeout=2, read_timeout=2, retries={"total_max_attempts": 2})
          DB = boto3.client("dynamodb", config=CONFIG)
          SECRETS = boto3.client("secretsmanager", config=CONFIG)
          SESSION_LIFETIME = 2 * 60 * 60
          SLOT_HOURS = (11, 14)


          @lru_cache(maxsize=1)
          def signing_key():
              value = SECRETS.get_secret_value(SecretId=os.environ["BOOKING_SECRET"])["SecretString"]
              return value.encode("ascii")


          def issue_session(scope, key):
              identity = secrets.token_hex(16)
              payload = f"{identity}.{int(time.time()) + SESSION_LIFETIME}"
              signature = hmac.new(key, f"spock-session-v1:{scope}:{payload}".encode(), hashlib.sha256)
              return f"{payload}.{signature.hexdigest()}"


          def session_identity(token, scope, key):
              if not isinstance(token, str) or not re.fullmatch(r"[0-9a-f]{32}\.[0-9]{10,11}\.[0-9a-f]{64}", token):
                  return None
              identity, expiration, signature = token.split(".")
              expected = hmac.new(key, f"spock-session-v1:{scope}:{identity}.{expiration}".encode(), hashlib.sha256)
              if int(expiration) <= time.time() or not hmac.compare_digest(signature, expected.hexdigest()):
                  return None
              return identity


          def demo_schedule(now=None):
              """Generate the next 14 calendar days of 30-minute weekday demo slots."""
              now = now or datetime.now(TIME_ZONE)
              slots = {}
              for days in range(14):
                  day = now.date() + timedelta(days=days)
                  if day.weekday() >= 5:
                      continue
                  for hour in SLOT_HOURS:
                      start = datetime(day.year, day.month, day.day, hour, tzinfo=TIME_ZONE)
                      if start <= now:
                          continue
                      slot_id = start.strftime("%Y-%m-%dT%H:%M")
                      clock_hour = start.strftime("%I").lstrip("0")
                      slots[slot_id] = {
                          "slotId": slot_id,
                          "startsAt": start.isoformat(timespec="minutes"),
                          "label": f"{start:%A, %B} {start.day} at {clock_hour} {start:%p} Eastern",
                      }
              return slots


          def get_record(pk):
              return DB.get_item(TableName=TABLE_NAME, Key={"pk": {"S": pk}}, ConsistentRead=True).get("Item")


          def occupied(keys):
              taken = set()
              pending = {TABLE_NAME: {"Keys": [{"pk": {"S": key}} for key in keys], "ConsistentRead": True}}
              if not keys:
                  return taken
              for _ in range(3):
                  result = DB.batch_get_item(RequestItems=pending)
                  taken.update(item["pk"]["S"] for item in result["Responses"].get(TABLE_NAME, []))
                  pending = result.get("UnprocessedKeys", {})
                  if not pending:
                      return taken
              raise RuntimeError("Availability read did not complete")


          def booking_view(record):
              return {
                  "reference": record["reference"]["S"],
                  "slotId": record["slotId"]["S"],
                  "startsAt": record["startsAt"]["S"],
                  "label": record["label"]["S"],
                  "revision": int(record["revision"]["N"]),
              }


          def booking_record(pk, slot, reference, revision, expires):
              values = {
                  "pk": pk,
                  "kind": "BOOKING",
                  "reference": reference,
                  **slot,
              }
              return {
                  **{name: {"S": value} for name, value in values.items()},
                  "revision": {"N": str(revision)},
                  "expiresAt": {"N": str(expires)},
              }


          def lock_record(pk, owner, expires):
              return {
                  "pk": {"S": pk},
                  "kind": {"S": "SLOT"},
                  "bookingPk": {"S": owner},
                  "expiresAt": {"N": str(expires)},
              }


          def put_new(item):
              return {"Put": {
                  "TableName": TABLE_NAME,
                  "Item": item,
                  "ConditionExpression": "attribute_not_exists(pk)",
              }}


          def transact(actions):
              try:
                  DB.transact_write_items(TransactItems=actions)
                  return True
              except ClientError as error:
                  if error.response["Error"]["Code"] != "TransactionCanceledException":
                      raise
                  # Re-read consistent state to distinguish a race from a committed retry.
                  return False


          def result(status, record=None, **fields):
              response = {"status": status, **fields}
              if record:
                  response["booking"] = booking_view(record)
              return response


          def run_operation(operation, payload, scope, key):
              token = payload.get("sessionKey")
              if operation == "/availability" and token in (None, ""):
                  token = issue_session(scope, key)
              identity = session_identity(token, scope, key)
              if identity is None:
                  return result("invalid_session")

              booking_pk = f"{scope}#BOOKING#{identity}"
              slot_prefix = f"{scope}#SLOT#"
              existing = get_record(booking_pk)
              schedule = demo_schedule()
              if operation == "/availability":
                  taken = occupied([slot_prefix + slot_id for slot_id in schedule])
                  slots = [slot for slot_id, slot in schedule.items() if slot_prefix + slot_id not in taken]
                  return result("available", existing, sessionKey=token, timeZone=str(TIME_ZONE), slots=slots)

              slot_id = payload.get("slotId")
              if not isinstance(slot_id, str):
                  return result("invalid_slot", existing)
              if operation == "/book" and existing:
                  status = "booked" if existing["slotId"]["S"] == slot_id else "already_booked"
                  return result(status, existing)
              if operation == "/reschedule":
                  if not existing:
                      return result("no_booking")
                  if existing["slotId"]["S"] == slot_id:
                      return result("moved", existing)
                  if type(payload.get("revision")) is not int or payload["revision"] != int(existing["revision"]["N"]):
                      return result("booking_changed", existing)

              slot = schedule.get(slot_id)
              if slot is None:
                  return result("invalid_slot", existing)

              expires = int(datetime.fromisoformat(slot["startsAt"]).timestamp()) + 86400
              if scope.startswith("SMOKE#"):
                  expires = int(time.time()) + 3600
              target_pk = slot_prefix + slot_id
              reserve_slot = put_new(lock_record(target_pk, booking_pk, expires))

              if operation == "/book":
                  ref = f"SPK-{identity[:10].upper()}"
                  updated = booking_record(booking_pk, slot, ref, 1, expires)
                  if transact([reserve_slot, put_new(updated)]):
                      return result("booked", updated)
                  latest = get_record(booking_pk)
                  if latest:
                      status = "booked" if latest["slotId"]["S"] == slot_id else "already_booked"
                      return result(status, latest)
              else:
                  old = booking_view(existing)
                  updated = booking_record(booking_pk, slot, old["reference"], old["revision"] + 1, expires)
                  update_booking = {"Put": {
                      "TableName": TABLE_NAME,
                      "Item": updated,
                      "ConditionExpression": "revision = :expected",
                      "ExpressionAttributeValues": {":expected": {"N": str(old["revision"])}},
                  }}
                  release_old = {"Delete": {
                      "TableName": TABLE_NAME,
                      "Key": {"pk": {"S": slot_prefix + old["slotId"]}},
                      "ConditionExpression": "bookingPk = :owner",
                      "ExpressionAttributeValues": {":owner": {"S": booking_pk}},
                  }}
                  if transact([reserve_slot, update_booking, release_old]):
                      return result("moved", updated)
                  latest = get_record(booking_pk)
                  if latest and latest["slotId"]["S"] == slot_id:
                      return result("moved", latest)
                  if latest != existing:
                      return result("booking_changed", latest)

              if get_record(target_pk):
                  return result("slot_taken", existing)
              return result("try_again", existing)


          def http(status_code, body):
              return {
                  "statusCode": status_code,
                  "headers": {"content-type": "application/json", "cache-control": "no-store"},
                  "body": json.dumps(body, separators=(",", ":")),
              }


          def handler(event, _context):
              path = event.get("rawPath")
              if path not in ("/availability", "/book", "/reschedule"):
                  return http(404, result("not_found"))
              headers = {name.lower(): value for name, value in (event.get("headers") or {}).items()}
              supplied_key = headers.get("x-spock-booking-key", "").encode()
              if len(supplied_key) != 48:
                  return http(401, result("unauthorized"))
              try:
                  key = signing_key()
                  if not hmac.compare_digest(supplied_key, key):
                      return http(401, result("unauthorized"))
                  smoke_id = headers.get("x-spock-test-run", "")
                  if smoke_id and not re.fullmatch(r"[0-9a-f]{32}", smoke_id):
                      return http(400, result("invalid_request"))
                  scope = f"SMOKE#{smoke_id}" if smoke_id else "DEMO"
                  body = event.get("body") or "{}"
                  if len(body) > 4096:
                      return http(400, result("invalid_request"))
                  if event.get("isBase64Encoded"):
                      body = base64.b64decode(body, validate=True)
                  payload = json.loads(body)
                  if not isinstance(payload, dict):
                      return http(400, result("invalid_request"))
                  return http(200, run_operation(path, payload, scope, key))
              except ValueError:
                  return http(400, result("invalid_request"))
              except (ClientError, BotoCoreError, RuntimeError) as error:
                  print(f"Spock booking dependency failure: {type(error).__name__}")
                  return http(503, result("service_unavailable"))
  BookingApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Ref AWS::StackName
      ProtocolType: HTTP
  BookingIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref BookingApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !GetAtt BookingHandler.Arn
      PayloadFormatVersion: '2.0'
      TimeoutInMillis: 12000
  AvailabilityRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref BookingApi
      RouteKey: POST /availability
      Target: !Sub 'integrations/${BookingIntegration}'
  BookRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref BookingApi
      RouteKey: POST /book
      Target: !Sub 'integrations/${BookingIntegration}'
  RescheduleRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref BookingApi
      RouteKey: POST /reschedule
      Target: !Sub 'integrations/${BookingIntegration}'
  BookingStage:
    Type: AWS::ApiGatewayV2::Stage
    DependsOn: [AvailabilityRoute, BookRoute, RescheduleRoute]
    Properties:
      ApiId: !Ref BookingApi
      StageName: '$default'
      AutoDeploy: true
      DefaultRouteSettings:
        ThrottlingRateLimit: 5
        ThrottlingBurstLimit: 10
  BookingPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref BookingHandler
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${BookingApi}/*/POST/*'
Outputs:
  BookingApiUrl:
    Value: !GetAtt BookingApi.ApiEndpoint
  BookingSecretArn:
    Value: !Ref BookingSecret
  BookingTableName:
    Value: !Ref BookingTable
SPOCK_CFN

cat > designer.mjs <<'SPOCK_DESIGNER'
import { execFileSync } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import {
  AgenticCXDesignerClient,
  CreateApplicationBuildCommand,
  CreateDataRequestCommand,
  CreateSecretCommand,
  GetApplicationBuildCommand,
  GetApplicationCommand,
  GetDataRequestCommand,
  GetFlowCommand,
  GetSecretCommand,
  ListApplicationBuildsCommand,
  UpdateDataRequestCommand,
  UpdateFlowCommand,
  UpdateSecretCommand,
} from 'amazon-connect-acxd-sdk';

const region = 'us-west-2';
const stackName = 'aws-agentic-spock-booking';
const applicationIdentifier = process.env.SPOCK_APPLICATION_ID;
const flowIdentifier = 'LiveDemo';
const secretName = 'SpockBookingWebhookKey';
const secretDescription = 'Webhook credential managed by the Spock booking stack.';
const flowDescription = 'Spock live booking v1: availability, booking, and rescheduling.';
const apiKey = process.env.ACXD_API_KEY;
const client = new AgenticCXDesignerClient({
  region,
  workspaceId: process.env.SPOCK_WORKSPACE_ID,
  apiKey,
});

const sessionKey = {
  type: 'string',
  description: 'Opaque sessionKey returned by SpockAvailability. Copy exactly. Never show it to the caller.',
};
const slotId = {
  type: 'string',
  description: 'The exact slotId from the current SpockAvailability result, after caller confirmation.',
};
const revision = {
  type: 'integer',
  description: 'The current booking revision returned by a tool. Copy the number exactly.',
};
const objectSchema = (properties, required = []) => ({
  type: 'object', properties, ...(required.length ? { required } : {}),
});
const slot = objectSchema({ slotId: { type: 'string' }, startsAt: { type: 'string' }, label: { type: 'string' } });
const booking = objectSchema({
  ...slot.properties, reference: { type: 'string' }, revision: { type: 'integer' },
});
const responseSchema = objectSchema({
  status: { type: 'string' },
  sessionKey: { type: 'string' },
  timeZone: { type: 'string' },
  slots: { type: 'array', items: slot },
  booking,
}, ['status']);
const tools = [
  {
    id: 'SpockAvailability',
    path: '/availability',
    description: 'Read demo slots and current booking. Omit sessionKey only on the first call. Always reuse the returned key afterward.',
    requestSchema: objectSchema({ sessionKey }),
  },
  {
    id: 'SpockBook',
    path: '/book',
    description: 'Book one demo slot. Use only after the caller confirms the exact date and time you read back.',
    requestSchema: objectSchema({ sessionKey, slotId }, ['sessionKey', 'slotId']),
  },
  {
    id: 'SpockReschedule',
    path: '/reschedule',
    description: 'Move the current booking after the caller confirms the new date and time. Pass the current booking revision.',
    requestSchema: objectSchema({ sessionKey, slotId, revision }, ['sessionKey', 'slotId', 'revision']),
  },
];

const journeyPrompt = [
  'You are Spock in the live demo of AWS Agentic Spock. Speak naturally in short sentences.',
  'You can check, book, and move a 30-minute demo reservation. The schedule is a sample calendar in Eastern time.',
  'On entry, offer to check the demo schedule. If the caller already asked for availability, check it now. Do not repeat the welcome greeting.',
  'Use SpockAvailability for times. Give at most two options that match the requested day and time. Say the date and time in Eastern time. If unavailable, offer the closest returned option.',
  'Keep the first sessionKey in memory and use it for every later availability, booking, and rescheduling request. Copy each key, slotId, and booking revision exactly from tool results. Never reveal the sessionKey, request credentials, or accept them from a caller.',
  'Before any write, read back the exact demo date and time and ask for confirmation. Wait for a clear yes. If the caller corrects the time, check the new time and read it back before acting.',
  'Use SpockBook for the first confirmed reservation. After a booking exists, use SpockReschedule for any confirmed change. Keep the same booking reference and use the latest revision. Never create a second reservation in this conversation.',
  'Only say a booking was made or moved if the tool returns booked or moved for that exact slot. Give its reference and date. Stay in the conversation so they can change it.',
  'On slot_taken, check availability again and offer another time. On already_booked or booking_changed, read the current booking from the result and ask whether to move it. On a timeout or try_again, check SpockAvailability with the existing sessionKey before suggesting another write. If the current booking cannot be verified, say so.',
  'When interrupted, answer a question about how the demo works, then return to the outstanding choice or confirmation. Do not treat the side question as confirmation. If they change their mind, acknowledge the new request and confirm that instead.',
  'Verified facts about this demo: Amazon Connect hosts the voice experience. Agentic CX Designer manages the conversation and invokes the booking tools. API Gateway and Lambda run the requests. DynamoDB stores demo reservations and commits a move atomically so two callers cannot claim the same slot.',
  'For anything outside those facts, say you only have information about this demo. Avoid collecting names, phone numbers, emails, or payment information. Give the booking confirmation in the conversation.',
  'Use the done exit only when the caller clearly says they are finished.',
].join('\n');

const send = (Command, params) => client.send(new Command(params));
function aws(args, showProgress = false) {
  return execFileSync('aws', ['--region', region, '--no-cli-pager', ...args], {
    encoding: 'utf8',
    stdio: showProgress ? 'inherit' : ['ignore', 'pipe', 'pipe'],
  })?.trim();
}

async function lookup(Command, params) {
  try {
    return await send(Command, params);
  } catch (error) {
    if (error.name === 'ResourceNotFoundException' || error.$metadata?.httpStatusCode === 404) return null;
    throw error;
  }
}

function readStack() {
  try {
    return JSON.parse(aws(['cloudformation', 'describe-stacks', '--stack-name', stackName, '--output', 'json'])).Stacks[0];
  } catch (error) {
    if (error.stderr?.includes('does not exist')) return null;
    throw error;
  }
}

function deployStack() {
  const existing = readStack();
  if (existing && !existing.Tags?.some(({ Key, Value }) => Key === 'Project' && Value === 'aws-agentic-spock')) {
    throw new Error('A stack with this name exists without the Spock project tag.');
  }
  aws([
    'cloudformation', 'deploy', '--template-file', 'booking-stack.yaml',
    '--stack-name', stackName, '--capabilities', 'CAPABILITY_IAM',
    '--no-fail-on-empty-changeset', '--tags', 'Project=aws-agentic-spock', 'Component=booking',
  ], true);
  return Object.fromEntries(readStack().Outputs.map(({ OutputKey, OutputValue }) => [OutputKey, OutputValue]));
}

function check(condition, message) {
  if (!condition) throw new Error(message);
}

async function smokeTest(baseUrl, key) {
  const testRun = randomBytes(16).toString('hex');
  const unauthed = await fetch(baseUrl + '/availability', {
    method: 'POST', signal: AbortSignal.timeout(15000),
  });
  check(unauthed.status === 401, 'The booking API did not reject an unauthenticated request.');

  async function request(path, payload) {
    const response = await fetch(baseUrl + path, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-spock-booking-key': key,
        'x-spock-test-run': testRun,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(15000),
    });
    check(response.ok, 'Booking smoke test received HTTP ' + response.status + ' from ' + path + '.');
    return response.json();
  }

  const initial = await request('/availability', {});
  check(initial.status === 'available' && initial.slots?.length >= 2, 'The booking API did not return two test slots.');
  const first = initial.slots[0].slotId;
  const second = initial.slots[1].slotId;
  const session = { sessionKey: initial.sessionKey };
  const bookingRequest = { ...session, slotId: first };
  const booked = await request('/book', bookingRequest);
  check(booked.status === 'booked' && booked.booking?.slotId === first && booked.booking?.revision === 1,
    'The first demo booking was not saved.');
  const replayed = await request('/book', bookingRequest);
  check(replayed.status === 'booked' && replayed.booking?.reference === booked.booking.reference &&
    replayed.booking?.revision === 1, 'A repeated booking did not resolve to the original reservation.');

  const other = await request('/availability', {});
  const occupied = await request('/book', { sessionKey: other.sessionKey, slotId: first });
  check(occupied.status === 'slot_taken', 'Two sessions were able to claim one demo slot.');

  const moveRequest = { ...session, slotId: second, revision: 1 };
  const moved = await request('/reschedule', moveRequest);
  check(moved.status === 'moved' && moved.booking?.slotId === second &&
    moved.booking?.reference === booked.booking.reference && moved.booking?.revision === 2,
    'The API did not move the original reservation.');
  const repeatedMove = await request('/reschedule', moveRequest);
  check(repeatedMove.status === 'moved' && repeatedMove.booking?.revision === 2,
    'A repeated move did not resolve to the same revision.');

  const final = await request('/availability', session);
  check(final.booking?.slotId === second && final.booking?.revision === 2 &&
    final.slots.some((entry) => entry.slotId === first) && !final.slots.some((entry) => entry.slotId === second),
    'Availability did not reflect the move.');
  console.log('PASS: API authentication, booking, duplicate protection, and atomic rescheduling.');
}

function nodeId(label) {
  const hash = createHash('sha256').update('aws-agentic-spock/LiveDemo/' + label).digest('hex');
  return [hash.slice(0, 8), hash.slice(8, 12), '4' + hash.slice(13, 16),
    '8' + hash.slice(17, 20), hash.slice(20, 32)].join('-');
}

function expectedFlowState(flow) {
  const nodes = flow.nodes ?? {};
  if (flow.description === flowDescription) {
    const attached = nodes[nodeId('journey')]?.metadata?.generativeJourney?.tools ?? [];
    if (tools.every(({ id }) => attached.some((tool) => tool.dataRequest?.dataRequestId === id))) return 'installed';
  }
  if (flow.description === 'Spock caller route: LiveDemo' &&
    Object.keys(nodes).length === 3 &&
    nodes[nodeId('start')]?.type === 'start' &&
    nodes[nodeId('reply')]?.type === 'basic' &&
    nodes[nodeId('reply')]?.messages?.[0]?.body === 'You’re in the right place. You just reached Spock’s live demo path.' &&
    ['end', 'terminate'].includes(nodes[nodeId('end')]?.type)) return 'placeholder';
  throw new Error('LiveDemo differs from the Spock placeholder this setup expects. Check the current flow before upgrading it.');
}

function bookingNodes() {
  const nodes = {};
  const link = (label, name = 'next', conditions = []) => ({ nodeId: nodeId(label), name, conditions });
  const statusLink = (status, label) => link(label, status, [{
    left: { type: 'node_status' }, operator: 'eq', right: { type: 'constant', value: status },
  }]);
  function add(label, type, x, y, options = {}) {
    const id = nodeId(label);
    nodes[id] = { nodeId: id, type, canvasMetadata: { x, y }, ...options };
  }
  add('start', 'start', 300, 40, { childNodes: [link('journey')] });
  add('journey', 'generative_journey', 300, 200, {
    childNodes: [
      link('close', 'done', [{
        left: { type: 'system', name: 'System.gjConditionIndex' },
        operator: 'eq', right: { type: 'constant', value: 0 },
      }]),
      statusLink('timeout', 'error'),
      statusLink('failure', 'error'),
    ],
    metadata: {
      generativeJourney: {
        prompt: journeyPrompt,
        modelType: 'amazon-nova-2-lite',
        enableZeroTurnMode: false,
        maxSteps: 10,
        maxTokens: 2048,
        temperature: 0.3,
        tools: tools.map(({ id }) => ({ type: 'dataRequest', dataRequest: { dataRequestId: id, payload: {} } })),
        exitConditions: [{ name: 'done', prompt: 'The caller clearly says they are finished with the demo.' }],
      },
    },
  });
  add('close', 'basic', 60, 500, {
    messages: [{ type: 'text', body: 'Thanks for trying Spock.' }],
    childNodes: [link('end')],
  });
  add('error', 'basic', 540, 500, {
    messages: [{ type: 'text', body: "I couldn't verify the last step. Thanks for trying Spock." }],
    childNodes: [link('end')],
  });
  add('end', 'terminate', 300, 710, { childNodes: [] });
  return nodes;
}

async function installSecret(value) {
  const existing = await lookup(GetSecretCommand, { secretIdentifier: secretName });
  if (!existing) {
    await send(CreateSecretCommand, {
      name: secretName, secretValue: value, isSensitive: true, description: secretDescription,
    });
  } else {
    check(existing.description === secretDescription, 'A different Designer secret uses the Spock booking name.');
    if (existing.secretValue !== value) {
      await send(UpdateSecretCommand, { secretIdentifier: secretName, secretValue: value, isSensitive: true });
    }
  }
}

async function installDataRequests(baseUrl) {
  for (const tool of tools) {
    const url = baseUrl + tool.path;
    const headers = [{ key: 'x-spock-booking-key', value: '{' + secretName + ':NLX.Secret}', sensitive: true }];
    const config = {
      type: 'object',
      description: tool.description,
      sensitive: true,
      requestSchema: tool.requestSchema,
      responseSchema,
      webhook: {
        implementation: 'external', method: 'POST', url, headers, sendContext: false,
        environments: { development: { url, headers }, production: { url, headers } },
      },
    };
    const existing = await lookup(GetDataRequestCommand, { dataRequestIdentifier: tool.id });
    if (!existing) {
      await send(CreateDataRequestCommand, { dataRequestId: tool.id, ...config });
    } else {
      check(existing.description === tool.description, 'A different Data request uses the name ' + tool.id + '.');
      if (existing.webhook?.url !== url || existing.webhook?.environments?.development?.url !== url) {
        await send(UpdateDataRequestCommand, { dataRequestIdentifier: tool.id, ...config });
      }
    }
    console.log('Ready: ' + tool.id);
  }
}

async function buildApplication(flow, app, baseUrl) {
  const fingerprint = createHash('sha256')
    .update(JSON.stringify([flow.saveId ?? flow.updatedAt, app.updatedAt, baseUrl]))
    .digest('hex').slice(0, 10);
  const description = 'Spock live demo booking v1 (' + fingerprint + ')';
  const { items = [] } = await send(ListApplicationBuildsCommand, { applicationIdentifier, maxResults: 25 });
  const prior = items.find((item) => item.description === description && ['PENDING', 'BUILT'].includes(item.status));
  let build = prior ?? await send(CreateApplicationBuildCommand, { applicationIdentifier, description });
  console.log('Designer build: ' + build.buildId);
  for (let attempt = 0; attempt < 80; attempt += 1) {
    if (build.status === 'BUILT') return build;
    check(build.status !== 'FAILED', 'The Designer build failed. Open this build in Designer for the validation details.');
    await delay(3000);
    build = await send(GetApplicationBuildCommand, { applicationIdentifier, buildIdentifier: build.buildId });
  }
  throw new Error('The build is still processing. Check its status under Deploy in Designer.');
}

let webhookKey;
let phase = 'Designer preflight';
try {
  const app = await send(GetApplicationCommand, { applicationIdentifier });
  check(app.name === 'AWS Agentic Spock' && app.settings?.defaultFlows?.welcome?.flowId === 'SpockWelcome' &&
    app.flows?.some(({ flowId }) => flowId === flowIdentifier), 'Could not verify the expected Spock app and LiveDemo route.');
  const original = await send(GetFlowCommand, { flowIdentifier });
  const state = expectedFlowState(original);

  phase = 'AWS stack deployment';
  console.log('Deploying the Spock booking API in Oregon...');
  const outputs = deployStack();
  const baseUrl = outputs.BookingApiUrl?.replace(/\/$/, '');
  check(baseUrl && outputs.BookingSecretArn, 'The booking stack did not return the expected outputs.');
  webhookKey = aws(['secretsmanager', 'get-secret-value', '--secret-id', outputs.BookingSecretArn,
    '--query', 'SecretString', '--output', 'text']);
  check(/^[A-Za-z0-9]{48}$/.test(webhookKey), 'Could not read the generated webhook credential.');

  phase = 'Booking API smoke test';
  console.log('Checking the deployed API with isolated demo slots...');
  await smokeTest(baseUrl, webhookKey);

  phase = 'Designer booking tools';
  await installSecret(webhookKey);
  await installDataRequests(baseUrl);

  phase = 'LiveDemo flow update';
  const current = await send(GetFlowCommand, { flowIdentifier });
  check((current.saveId ?? String(current.updatedAt)) === (original.saveId ?? String(original.updatedAt)),
    'LiveDemo changed during setup. Run again to recheck the current flow.');
  let readyFlow = current;
  if (state === 'placeholder') {
    readyFlow = await send(UpdateFlowCommand, {
      flowIdentifier,
      description: flowDescription,
      aiDescription: 'Use when a caller wants to see the technology in action, try the Spock demo, or check, book, or move a sample reservation.',
      untrained: false,
      nodes: bookingNodes(),
    });
  }

  phase = 'Designer build';
  const build = await buildApplication(readyFlow, app, baseUrl);
  console.log('READY FOR DESIGNER TEST: ' + build.buildId);
  console.log('DynamoDB table: ' + outputs.BookingTableName);
} catch (error) {
  let message = String(error.stderr || error.message || error).trim();
  for (const value of [apiKey, webhookKey]) {
    if (value) message = message.replaceAll(value, '[redacted]');
  }
  const http = error.$metadata?.httpStatusCode;
  console.error(phase + ' failed' + (http ? ' (HTTP ' + http + ')' : '') + ': ' + message);
  process.exitCode = 1;
}
SPOCK_DESIGNER

node designer.mjs
