# AWS Agentic Spock

Spock is a voice-first portfolio experience built with Amazon Connect and Agentic CX Designer. A prospective client can describe a business problem and hear an approach tailored to it. A recruiter can ask about Edward’s qualifications or describe a role and hear the engineering decision behind a matching project. Curious callers can explore the same projects in their own words.

## Caller experiences

| Path | What Spock does |
| --- | --- |
| Potential client | Asks about the caller’s workflow, recommends a practical first step, and explains the benefit. Website chatbots, AI phone assistants, live-agent handoffs, automation, and full contact centers are all possible paths. |
| Recruiter | Answers direct questions about Edward’s qualifications and matches the role to a project or skill. It can explain his years of voice and chat work, the Alexa skill he shipped, and the book he wrote on voice development. |
| Live demo | Leads with a short choice of examples and follows the caller’s questions. A caller can switch topics or turn the walkthrough into a conversation about a real need. |

Each path can call three read-only Designer data requests. They contain public project facts and limits on what Spock can claim about each build.

| Case study | Example evidence |
| --- | --- |
| [Maya · Dialogflow CX Virtual Agent](https://github.com/RedLeopard/dialogflow-cx-virtual-agent) | Voice intake, confirmed press-1 transfer, and booking-link and owner-alert texts. |
| [Project Enterprise Connect](https://github.com/RedLeopard/project-enterprise-connect) | Amazon Connect queue routing, real-time metrics, and call recordings in S3. |
| [AncestorIQ](https://github.com/RedLeopard/AncestorIQ) | A FastAPI search application on Cloud Run, backed by a BigQuery index of historical records. |

The recruiter route also uses a public qualifications profile. It includes [Voice Applications for Beginners](https://a.co/d/0ftqIws5), the [Street Genius Rhyming Words Alexa skill](https://www.amazon.com/Street-Genius-Rhyming-Words/dp/B09PNKJH5C), Loop Social’s real-time messaging, [Energy Transmission](https://hireedwardthornton.click/energy-transmission.html) for platform engineering, Maya’s authenticated webhook for security, and Edward’s cloud credentials and technical writing.

## Designer checkpoint

The conversation installer built all three caller paths and loaded the portfolio case studies. In the initial client test, Spock switched from an after-hours phone assistant to website chat when the caller corrected where inquiries come in. The revised build prompts Spock to retain the lead follow-up goal, use the Maya case where it fits, and ask one question about the workflow. It also covers the fallback for urgent chats when an agent is unavailable.

## Install the conversations

Use Node.js 20 or newer, npm, and a scoped Designer API key for the existing **AWS Agentic Spock** app in Oregon. The installer expects **SpockWelcome** as the welcome flow and the three original caller paths attached.

1. Use the existing `.spock.env` in the repo folder. If you’re setting up a fresh clone, create it with your own Designer IDs. Git ignores this file.

   ```bash
   SPOCK_WORKSPACE_ID=your-designer-workspace-id
   SPOCK_APPLICATION_ID=your-designer-application-id
   ```

2. Run the installer and enter your Designer API key at the hidden prompt.

   ```bash
   bash spock-conversations.sh
   ```

3. Wait for `READY FOR DESIGNER TEST`, then open the app’s **Test** tab. This installer uses the Designer SDK to update the three caller paths and build the app for testing.

## Try these conversations

| Start with | Follow up with | What to verify |
| --- | --- | --- |
| “I’m a potential client. We miss calls after hours, and following up with leads takes too long.” | “Actually, most of our inquiries come through the website. We still want customers to reach a live person when it’s urgent.” | Spock pivots to website chat, explains how leads get logged and followed up, and describes the urgent handoff and fallback. It asks one question and relates Maya’s phone workflow where relevant. |
| “Why should we hire Edward?” | “What did his Alexa skill do? Can you share links to that and his book?” | Spock answers before asking about the role, uses `SpockRecruiterProfile`, and names the book and Alexa skill. In Test chat it shares both public links when asked. |
| “I’m hiring someone to modernize our Amazon Connect setup.” | “Actually, the role is mostly data engineering.” | Spock shifts from Enterprise Connect to AncestorIQ and explains a design choice from the new example. |
| “What has Edward built with Kubernetes and CI/CD?” | “How did he secure a conversational AI backend?” | Spock describes Energy Transmission’s deployment and monitoring and then explains Maya’s authenticated webhook and secret handling. |
| “I’m just here to see what you can do.” | “How was this voice assistant built?” | Spock guides the caller through the experience and explains the role of Amazon Connect and Designer. |

## Messaging and launch

Both **caller email** and **caller SMS** are required for launch.

- **Caller email.** Use Amazon SES to send a tailored recap and relevant case study. Ask for consent and read back the email address before sending. Test with a verified inbox and confirm SES production access for delivery to callers.
- **Caller SMS.** Use AWS End User Messaging SMS with Amazon Connect. Set up a registered SMS sender and production access. Ask for consent, confirm the destination number, and send a short message with the relevant link.
- **Private owner summary.** Send a separate post-call summary with the caller’s purpose, needs, and any follow-up promised or sent.
- **Voice validation.** Test the three paths on the dedicated Amazon Connect number before sharing it publicly.

The earlier demo reservation prototype is available in [spock-booking.sh](spock-booking.sh). The current experience focuses on client discovery, relevant portfolio examples, and follow-up.
