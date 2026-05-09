# project-planner — a Claude Code skill for FastLinkIt Projects

Lets you say "what's next for project X?" or "I'll start working on FLNKA-21"
inside a Claude Code session and have Claude push real work items + lifecycle
transitions back to your FastLinkIt board, instead of leaving the plan stuck
in chat history.

> **Looking for the user guide?** See
> [docs/ProjectPlannerGuide.md](../../docs/ProjectPlannerGuide.md) for a
> hands-on walkthrough with conversation transcripts and troubleshooting.
> This README focuses on installation and configuration.

## What is FastLinkIt?

[**flnk.it**](https://flnk.it) is a small-business / creator / freelancer
toolkit that bundles the features you'd otherwise stitch together from
Bitly + Linktree + Calendly + Mailchimp + Stripe + Zendesk + WordPress, into a
single platform with one bill, one REST API, and a coherent UI.

The **Projects** module — Kanban / Agile / Waterfall over a unified work-item
model with PERT estimation, sprints, Gantt, time tracking, and AI agents — is
what this skill lets you drive from Claude Code without leaving your editor.

A few of the things flnk.it can do:

- **[Link shortener](https://flnk.it/features/link-shortener)** — branded
  short URLs with click analytics, expiration, file links, interstitials.
- **[QR codes](https://flnk.it/features/qr-code-generator)** — customisable
  with logos and colours, scan tracking.
- **[Link-in-bio pages](https://flnk.it/features/link-in-bio-pages)** —
  branded landing pages with templates and donation blocks.
- **[Contact CRM + email mailings](https://flnk.it/features/email-mailing)** —
  bulk emails, drip campaigns, A/B subject testing, custom DKIM-signed sender
  domains.
- **[Event booking](https://flnk.it/features/event-booking)** — public
  booking pages with paid + free events via Stripe / PayPal.
- **[Payments + donations](https://flnk.it/features/payments)** — Stripe and
  PayPal merchant onboarding, products, fundraising campaigns, embeddable
  donate widgets.
- **[Service requests](https://flnk.it/features/service-requests)** —
  escrow-style engagements with manual capture.
- **[REST API](https://flnk.it/features/api)** — programmatic access with
  scoped API keys (the same API this skill calls).
- **[CMS plugins](https://flnk.it/features/integrations)** — WordPress,
  Joomla, Drupal, Ghost, Shopify, Wix.

Browse the full feature list and case studies at
[flnk.it](https://flnk.it).

### Don't have an account yet?

You'll need a FastLinkIt account to use this skill — that's where the
projects live. **[Create one for free →](https://flnk.it/Account/Register)**

- Free plan, no card required.
- 14-day free trial on every paid plan (Starter / Basic don't even need a
  card to start the trial).
- Pricing details: [flnk.it/pricing](https://flnk.it/pricing).

Once you're signed in, generate an API key with the `projects` scope at
`/Account/Manage/ApiKeys` and you're ready to install this skill. See
[Configure](#configure) below.

## What it does

- **Plan mode** — read CLAUDE.md, fetch the project's methodology + columns,
  propose a ranked list with rationale, wait for your "yes", then POST the
  plan as work items (with hierarchy + dependencies preserved).
- **Pickup mode** — when you say "start working on FLNKA-N", opens an agent
  run server-side and moves the item to the in-progress column. Status shows
  up live for any teammate watching the board.
- **Wrap-up mode** — when the work is done, closes the run with a narrative
  summary and moves the item to review (or done). On failure: blocks the run
  with an explicit reason instead of failing silently.

## Install (v1, git-clone)

```bash
# Clone or copy this folder into your Claude Code skills directory
mkdir -p ~/.claude/skills/project-planner
cp SKILL.md ~/.claude/skills/project-planner/
cp -r lib ~/.claude/skills/project-planner/
chmod +x ~/.claude/skills/project-planner/lib/flnk-plan.sh   # POSIX only
```

On Windows the same files live at:

```
%USERPROFILE%\.claude\skills\project-planner\
```

For team distribution, drop the folder under `.claude/skills/` at the root of
the team's repo — Claude Code auto-discovers project-local skills there.

## Configure

Set the API key (generate at `<host>/Account/Manage/ApiKeys` with the
`projects` scope ticked):

```bash
# bash / zsh
export FLNKIT_API_KEY="fli_..."
export FLNKIT_API_BASE="https://flnk.it"   # or https://fastlinkit.dev.localhost:7152 for local dev
```

```powershell
# PowerShell
$env:FLNKIT_API_KEY = "fli_..."
$env:FLNKIT_API_BASE = "https://flnk.it"
```

For dev hosts using a self-signed cert, also set `FLNKIT_INSECURE=1` (or the
script auto-detects `localhost` in the base URL).

## Use

Just talk to Claude Code naturally inside a repo where this skill is
installed:

```
> what should I work on next for the FastLinkIt Agile project?

[Claude reads CLAUDE.md, fetches project context, proposes a ranked list,
 waits for your confirmation, and pushes the items on "yes".]

> I'll start with the WIP-limit task — FLNKA-21

[Claude calls flnk-plan start, reports "moved from Backlog to In progress
 (run id 47)". You write code. Then:]

> done — open and close the limit checks

[Claude calls flnk-plan complete with a narrative of what changed, item
 moves to Review.]
```

## Manual use of the helper

The two helper scripts are usable from any shell, not just inside Claude Code:

```bash
./lib/flnk-plan.sh list
./lib/flnk-plan.sh context <project-id>
./lib/flnk-plan.sh plan <project-id> ./my-plan.json
./lib/flnk-plan.sh start <project-id> <work-item-id> "summary of what I'm doing"
./lib/flnk-plan.sh complete <project-id> <work-item-id> <run-id> ./narrative.md
./lib/flnk-plan.sh block <project-id> <work-item-id> <run-id> "needs design review"
```

PowerShell is identical with `.ps1` extension and `-` instead of `--` flags.

## Cross-client alternative

If you use Cursor, Claude Desktop, or another MCP-aware client, install the
**`@flnkit/mcp-server`** npm package instead — same six operations exposed as
MCP tools, no shell wrapper required. See `plugins/mcp-server/README.md` in
this repo.

## Privacy

Every API call carries the bearer key as `X-Api-Key`. Nothing is logged
beyond the existing FastLinkIt request logging. The agent-run endpoints
write a `WorkItemAgentRun` row per pickup with `AgentId = "claude-code"`
(or whatever `FLNKIT_AGENT_ID` overrides to) so you can audit which client
acted on which item. Token / cost fields are zero for external runs since
the model isn't running on the server.
