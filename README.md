# AWS Agentic Spock

Spock is a voice-first portfolio experience built with Amazon Connect and Agentic CX Designer. A prospective client can describe a business problem and hear an approach tailored to it. A recruiter can describe the work they’re hiring for and hear a matching project and the engineering decision behind it. Curious callers can explore the same projects in their own words.

## Caller experiences

| Path | What Spock does |
| --- | --- |
| Potential client | Asks about the caller’s workflow, recommends a practical first step, and explains the benefit. Website chatbots, AI phone assistants, live-agent handoffs, automation, and full contact centers are all possible paths. |
| Recruiter | Asks what the hire would own, looks up a relevant project, and explains a specific design choice. It adapts if the recruiter changes priorities. |
| Live demo | Leads with a short choice of examples and follows the caller’s questions. A caller can switch topics or turn the walkthrough into a conversation about a real need. |

Each path can call three read-only Designer data requests. They contain public project facts and limits on what Spock can claim about each build.

| Case study | Example evidence |
| --- | --- |
| [Maya · Dialogflow CX Virtual Agent](https://github.com/RedLeopard/dialogflow-cx-virtual-agent) | Voice intake, confirmed press-1 transfer, and booking-link and owner-alert texts. |
| [Project Enterprise Connect](https://github.com/RedLeopard/project-enterprise-connect) | Amazon Connect queue routing, real-time metrics, and call recordings in S3. |
| [AncestorIQ](https://github.com/RedLeopard/AncestorIQ) | A FastAPI search application on Cloud Run, backed by a BigQuery index of historical records. |

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
| “We miss calls after hours, and following up with leads takes too long.” | “We also need a person to pick up when it’s urgent.” | Spock addresses both issues, explains the live handoff, and retrieves Maya as a relevant example. |
| “I’m hiring someone to modernize our Amazon Connect setup.” | “Actually, the role is mostly data engineering.” | Spock shifts from Enterprise Connect to AncestorIQ and explains a design choice from the new example. |
| “I’m just here to see what you can do.” | “How was this voice assistant built?” | Spock guides the caller through the experience and explains the role of Amazon Connect and Designer. |

## Next milestones

- Add one shared follow-up email tool using a verified sender. Ask for consent and confirm the address before sending a case study or recap.
- Add opt-in SMS and a private summary for the owner.
- Test the experience on the dedicated Amazon Connect number before sharing it publicly.

The earlier demo reservation prototype is available in [spock-booking.sh](spock-booking.sh).
