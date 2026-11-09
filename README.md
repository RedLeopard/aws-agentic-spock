# AWS Agentic Spock

Spock is a voice-first portfolio experience built with Amazon Connect and Agentic CX Designer. A prospective client can describe a business problem and hear an approach tailored to it. A recruiter can ask about Edward’s qualifications or describe a role and hear the engineering decision behind a matching project. Curious callers can explore the same projects in their own words.

## Caller experiences

| Path | What Spock does |
| --- | --- |
| Potential client | Asks about the caller’s workflow, recommends a practical first step, and explains the benefit. Website chatbots, AI phone assistants, live-agent handoffs, automation, and full contact centers are all possible paths. |
| Recruiter | Answers direct questions about Edward’s qualifications and matches the role to a project. It can explain his years of voice and chat work and describe how his Alexa app suggests rhymes. With delivery enabled, it can send the app and book links by text or email. |
| Live demo | Leads with a short choice of examples and follows the caller’s questions. A caller can switch topics or turn the walkthrough into a conversation about a real need. |

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

Use Node.js 20 or newer, npm, and a scoped Designer API key for the existing **AWS Agentic Spock** app in Oregon. The installer expects **SpockWelcome** as the welcome flow and the three original caller paths attached.

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

3. Wait for `READY FOR DESIGNER TEST`, then open the app’s **Test** tab. This installer uses the Designer SDK to update the three caller paths and build the app for testing.

## Try these conversations

| Start with | Follow up with | What to verify |
| --- | --- | --- |
| “I’m a potential client. We miss calls after hours, and following up with leads takes too long.” | “Actually, most of our inquiries come through the website. We still want customers to reach a live person when it’s urgent.” | Spock pivots to website chat, explains how leads get logged and followed up, and describes the urgent handoff and fallback. It asks one question and relates Maya’s phone workflow where relevant. |
| “Why should we hire Edward for voice and chat?” | “How does his Alexa app work?” | Spock uses `SpockRecruiterQualifications`, explains that people can ask Alexa for rhymes, and connects the app and book to the role. |
| “Send me both links.” | “Text, please.” In a new test choose email instead. | With link delivery enabled, Spock asks for the selected destination, reads it back, and waits for confirmation before calling `SpockSendRecruiterLinks`. Use your own test inbox and phone and verify receipt separately. |
| “I’m hiring someone to modernize our Amazon Connect setup.” | “Actually, the role is mostly data engineering.” | Spock shifts from Enterprise Connect to AncestorIQ and explains a design choice from the new example. |
| “What has Edward built with Kubernetes and CI/CD?” | “How did he secure a conversational AI backend?” | Spock describes Energy Transmission’s deployment and monitoring and then explains Maya’s authenticated webhook and secret handling. |
| “I’m just here to see what you can do.” | “How was this voice assistant built?” | Spock guides the caller through the experience and explains the role of Amazon Connect and Designer. |

## Send the recruiter links by text or email

Spock sends the book link, the Alexa app link, or both as requested. It asks the caller to choose a channel and reads back the destination before sending. If a caller changes the address, number, or channel, Spock confirms the new choice first. It reports a send after the provider accepts the request.

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

```bash
SPOCK_USE_EXISTING_LINK_STACK=1 bash spock-conversations.sh --with-email-delivery
```

## Launch checks

- **Caller email and SMS.** Verify actual receipt on both channels. Client recaps and other follow-up links are separate from the recruiter delivery flow.
- **Private owner summary.** Send a separate post-call summary with the caller’s purpose, needs, and any follow-up promised or sent.
- **Voice validation.** Test the three paths on the dedicated Amazon Connect number before sharing it publicly.

The earlier demo reservation prototype is available in [spock-booking.sh](spock-booking.sh). The current experience focuses on client discovery, relevant portfolio examples, and follow-up.
