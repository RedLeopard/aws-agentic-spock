# AWS Agentic Spock

Spock is a voice-first portfolio experience built with Amazon Connect and Agentic CX Designer. A prospective client can describe a business problem and hear an approach tailored to it. A recruiter can discuss what the team needs and hear how Edward’s CX architecture experience fits. Curious callers can explore the same projects in their own words.

## Caller experiences

| Path | What Spock does |
| --- | --- |
| Potential client | Asks about the caller’s workflow, recommends a practical first step, and explains the benefit. Website chatbots, AI phone assistants, live-agent handoffs, automation, and full contact centers are all possible paths. |
| Recruiter | Asks what the architect needs to own and leads with Edward’s contact center architecture, conversational AI, cloud integration, and credentials. It offers relevant portfolio samples by email or text when delivery is enabled. |
| Live demo | Leads with a short choice of examples and follows the caller’s questions. A caller can switch topics or turn the walkthrough into a conversation about a real need. |

If the first reply is a side question or the welcome flow cannot match it, Spock responds conversationally. It can answer a question about the portfolio or the technology, handle small talk, and route the caller once their purpose is clear. Side questions during a journey can be answered before returning to the caller’s goal.

Each path can call three read-only Designer data requests. They contain public project facts and limits on what Spock can claim about each build.

| Case study | Example evidence |
| --- | --- |
| [Maya · Dialogflow CX Virtual Agent](https://github.com/RedLeopard/dialogflow-cx-virtual-agent) | Voice intake, confirmed press-1 transfer, and booking-link and owner-alert texts. |
| [Project Enterprise Connect](https://github.com/RedLeopard/project-enterprise-connect) | Amazon Connect queue routing, real-time metrics, and call recordings in S3. |
| [AncestorIQ](https://github.com/RedLeopard/AncestorIQ) | A FastAPI search application on Cloud Run, backed by a BigQuery index of historical records. |

The recruiter route also uses a public qualifications profile. It includes [Voice Applications for Beginners](https://www.amazon.com/dp/B09SNKVGSR), an [AI-assisted voice app for Alexa devices](https://www.amazon.com/dp/B09PNKJH5C) that suggests rhymes when you say a word, Loop Social’s real-time messaging, [Energy Transmission](https://hireedwardthornton.click/energy-transmission.html) for platform engineering, Maya’s authenticated webhook for security, and Edward’s cloud credentials and technical writing.

## Designer checkpoint

The conversation installer built all three caller paths and loaded the portfolio case studies. In the initial client test, Spock switched from an after-hours phone assistant to website chat when the caller corrected where inquiries come in. The revised build prompts Spock to retain the lead follow-up goal, use the Maya case where it fits, and ask one question about the workflow. It also covers the fallback for urgent chats when an agent is unavailable.

## Install the conversations

Use Node.js 20 or newer, npm, and a scoped Designer API key for the existing **AWS Agentic Spock** app in Oregon. The installer expects **SpockWelcome** as the welcome flow, **SpockClarify** in the workspace, and the three original caller paths attached. The key needs application write access to assign the Unknown flow on the first run.

1. Use the existing `.spock.env` in the repo folder. If you’re setting up a fresh clone, create it with your own Designer IDs. Git ignores this file.

   ```bash
   SPOCK_WORKSPACE_ID=your-designer-workspace-id
   SPOCK_APPLICATION_ID=your-designer-application-id
   ```

2. Run the installer. It reads your Designer API key from macOS Keychain if available, or asks for it at a hidden prompt. To save or update the key on your Mac, run this once and enter the key when `security` prompts you.

   ```bash
   security add-generic-password -U -a "$(id -un)" -s 'Spock Designer API' -w
   ```

   Then run the installer.

   ```bash
   bash spock-conversations.sh
   ```

3. Wait for `READY FOR DESIGNER TEST`, then open the app’s **Test** tab. The installer updates the caller journeys, routes Unknown replies to **SpockClarify**, and builds the app for testing.

## Try these conversations

| Start with | Follow up with | What to verify |
| --- | --- | --- |
| “I’m a potential client. We miss calls after hours, and following up with leads takes too long.” | “Actually, most of our inquiries come through the website. We still want customers to reach a live person when it’s urgent.” | Spock pivots to website chat, explains how leads get logged and followed up, and describes the urgent handoff and fallback. It asks one question and relates Maya’s phone workflow where relevant. |
| “Is Edward a loser?” | “I’m asking if he’s dumb.” Then “What’s he built?” and “I’m hiring for a contact center migration.” | Spock stays composed, pivots to Edward’s work, and switches to the recruiter journey when the caller states their hiring need. |
| “I’m a recruiter.” | “What does CX mean?” Then “We’re migrating a legacy call center to AWS.” | Spock gives the recruiter intro, answers the side question, then matches the hiring priority to Edward’s migration experience and an example from his portfolio. |
| “I’m a recruiter.” | “I’m not sure what the role needs yet.” | Spock offers the Enterprise Connect routing and Maya handoff samples in a short reply and gives the recruiter one next step. |
| “What about his work expertise?” | “Yes, email me the portfolio samples.” | Spock leads with skills and credentials, asks for the destination, reads it back, and waits for confirmation before calling `SpockSendRecruiterLinks`. Test a corrected address and a declined confirmation as well. |
| “Email me the CX samples.” | Confirm a test inbox you control that is unverified in the SES sandbox. Then say “yes” again after the rejection. | Spock shares the samples in chat when SES rejects the email. The second “yes” leaves the email attempt closed. |
| “Can you send the book and Alexa app links?” | Choose an enabled channel and confirm a test destination. | Spock sends the requested book and app links. Check the Debugger for provider acceptance with a receipt ID, then verify actual receipt in your inbox or on your phone. |
| “I’m hiring someone to modernize our Amazon Connect setup.” | “Actually, the role is mostly data engineering.” | Spock shifts from Enterprise Connect to AncestorIQ and explains a design choice from the new example. |
| “What has Edward built with Kubernetes and CI/CD?” | “How did he secure a conversational AI backend?” | Spock describes Energy Transmission’s deployment and monitoring and then explains Maya’s authenticated webhook and secret handling. |
| “I’m just here to see what you can do.” | “How was this voice assistant built?” | Spock guides the caller through the experience and explains the role of Amazon Connect and Designer. |

## Send the recruiter links by text or email

Spock offers the Amazon Connect and Dialogflow CX case studies for CX hiring questions. It can also send the full portfolio or the book and Alexa app links on request. It reads back the destination and what it will send, then waits for confirmation. If a caller changes the address, number, or channel, Spock confirms the new choice first. The send tool returns a status and a provider receipt ID on acceptance. Confirm actual receipt separately.

### Test email first

1. In Oregon (`us-west-2`), verify the sending address or domain in [Amazon SES](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html). If SES is in its sandbox, verify the test inbox too. The SES checks need `ses:GetAccount` and `ses:ListEmailIdentities`. The installer reads the selected identity with `ses:GetEmailIdentity`.
2. Add these settings to the same `.spock.env` used by the conversation installer. `SPOCK_SES_IDENTITY` can be the verified address itself or its verified domain.

   ```bash
   SPOCK_AWS_ACCOUNT_ID=your-aws-account-id
   SPOCK_SES_IDENTITY=example.com
   SPOCK_SES_FROM_EMAIL=spock@example.com
   ```

3. Use an AWS CLI profile for that account with CloudFormation change set and stack provisioning permissions. Use a Designer key with access to secrets, data requests, flows, and builds. Run the email test installer.

   ```bash
   bash spock-conversations.sh --with-email-delivery
   ```

4. Open the new build in Designer Test and confirm delivery to your own inbox. Also try declining at readback and verify in the Debugger that the send tool stays idle.

### Add text delivery

1. In Oregon, register an [AWS End User Messaging SMS](https://docs.aws.amazon.com/end-user-messaging/latest/userguide/nx-sms.html) number or pool and verify your test number if the account is in the SMS sandbox. Add the sender ARN to `.spock.env`.

   ```bash
   SPOCK_SMS_ORIGINATION_ARN=arn:aws:sms-voice:us-west-2:123456789012:phone-number/phone-example
   ```

2. Run `bash spock-conversations.sh --with-link-delivery` to upgrade the same stack and recruiter route. In Designer Test, choose text and verify receipt on your test phone. Request production access for SES and SMS before opening delivery to general callers.

Either delivery flag provisions [the link delivery stack](spock-link-delivery.yaml), checks the authenticated webhook without sending a message, and attaches the send tool to the recruiter route. For a conversation-only build, run the installer without a flag before enabling delivery. Once enabled, include the flag for the enabled mode or upgrade from email to both channels.

If an AWS administrator provisions the stack separately, upload `spock-link-delivery.yaml` to CloudFormation in Oregon. Use stack name `aws-agentic-spock-link-delivery`, set `SesIdentity` and `SesFromEmail` to match `.spock.env`, and leave `SmsOriginationArn` blank for email-only testing. Add stack tags `Project=aws-agentic-spock` and `Component=link-delivery`, then acknowledge the template's IAM role. After the stack completes, the local AWS profile needs `cloudformation:DescribeStacks` for this stack and `secretsmanager:GetSecretValue` for the secret ARN listed as `WebhookKeyArn` in its Outputs tab. The Designer installer uses those outputs to wire the webhook.

For an existing stack, update it with the current template before building the recruiter flow. The installer checks that the webhook supports portfolio samples and receipts. When debugging email in the SES sandbox, enter the address exactly as verified in Oregon, including capitalization. In Designer’s Debugger, `identity_not_verified` means SES rejected an unverified identity. If the same address and link selection were already rejected, allow the 10-minute deduplication window to expire before starting a new test. `accepted` with a receipt ID means SES accepted the request. For either outcome, the Lambda logs record the provider result without the address.

```bash
SPOCK_USE_EXISTING_LINK_STACK=1 bash spock-conversations.sh --with-email-delivery
```

To update the recruiter journey on an app that has customized caller routes, use the recruiter-only installer. It checks the recruiter flow for compatibility and builds with the other flows and app settings already in Designer.

```bash
SPOCK_RECRUITER_ONLY=1 SPOCK_USE_EXISTING_LINK_STACK=1 bash spock-conversations.sh --with-email-delivery
```

## Launch checks

- **Caller email and SMS.** Verify actual receipt on both channels. Client recaps and other follow-up links are separate from the recruiter delivery flow.
- **Private owner summary.** Send a separate post-call summary with the caller’s purpose, needs, and any follow-up promised or sent.
- **Voice validation.** Test the three paths on the dedicated Amazon Connect number before sharing it publicly.

The earlier demo reservation prototype is available in [spock-booking.sh](spock-booking.sh). The current experience focuses on client discovery, relevant portfolio examples, and follow-up.
