# project-planner — a Claude Code skill for FastLinkIt Projects

Talk to Claude Code in plain English to plan, pick up, work on, and wrap
up project tasks against your FastLinkIt board — without leaving the
editor.

> **What is this?** A Claude Code skill (a folder under
> `~/.claude/skills/`) that wraps the FastLinkIt Projects REST API as a
> set of natural-language flows. You describe what you want, Claude does
> the API call, and your project board updates in real time.

---

## What you can do

| You say | What lands on the board |
|---|---|
| *"What's next for the Agile project?"* | A ranked, methodology-aware plan (Epic → Feature → Story → Task hierarchy) — Claude waits for your "yes", then creates the items in one round-trip. |
| *"I'll start on FLNKA-22"* | Item moves to **In progress**. Assignee is set to "Claude Code". Agent-run row records the pickup. |
| *"Done — added the migration, tests pass"* | Item moves to **Review** with your narrative summary attached. |
| *"Bug: the resize handle loses pointer events after a re-render"* + paste a screenshot | Bug created with structured repro steps, the screenshot attached as evidence. |
| *"What's on my plate?"* | Items assigned to you, grouped by status (In progress / Backlog / Review). Suggests resume / pickup. |

Five modes total: **Plan**, **Pickup**, **Wrap-up**, **Bug**, **Scan**. All
gated by an explicit human "yes" before anything writes to the board — no
auto-push.

---

## What is FastLinkIt?

[**flnk.it**](https://flnk.it) is a small-business / creator / freelancer
toolkit that bundles features you'd otherwise stitch together from
Bitly + Linktree + Calendly + Mailchimp + Stripe + Zendesk + WordPress,
into a single platform with one bill, one REST API, and a coherent UI.

The **Projects** module is the part this skill drives — Kanban / Agile /
Waterfall over a unified work-item model with PERT estimation, sprints,
Gantt, time tracking, AI agents.

A few of the things flnk.it does:

- [Link shortener](https://flnk.it/features/link-shortener), [QR codes](https://flnk.it/features/qr-code-generator), [link-in-bio pages](https://flnk.it/features/link-in-bio-pages)
- [Contact CRM + email mailings](https://flnk.it/features/email-mailing) with drip campaigns + A/B testing + DKIM-signed sender domains
- [Event booking](https://flnk.it/features/event-booking), [payments + donations](https://flnk.it/features/payments), [service requests](https://flnk.it/features/service-requests)
- [REST API](https://flnk.it/features/api), [CMS plugins](https://flnk.it/features/integrations) (WordPress, Joomla, Drupal, Ghost, Shopify, Wix)
- Projects (this one)

### Don't have an account yet?

You'll need one — that's where the projects live.
**[Create one for free →](https://flnk.it/Account/Register)**

- Free plan, no card required.
- 14-day free trial on every paid plan (Starter / Basic don't need a card
  to start the trial).
- Pricing: [flnk.it/pricing](https://flnk.it/pricing).

---

## End-to-end walkthrough — from zero to your first AI-driven plan

Assume you've never used the Projects module before. Every step is
concrete; replace project names with your own.

### Step 1 — Create a project in the FastLinkIt UI

Sign in at [flnk.it](https://flnk.it), click **Projects** in the left rail
→ **+ New project**. Fill in:

- **Name**: *"Acme website rebuild"*
- **Methodology**: **Agile** (full Epic / Feature / Story / Task
  hierarchy). Pick **Kanban** for a flat task pool, or **Waterfall** for
  date-driven Gantt work.
- **Prefix**: `WEB` (so items number as `WEB-1`, `WEB-2`, … instead of
  bare `#1`).
- Status: Active. Colour: pick one. Hourly rate: optional, only matters
  if you'll bill time.

Save. You land on `/projects/{id}` with an empty list view. **Note the
project id in the URL bar** — you'll paste it into PROJECTS.md in step 2.

### Step 2 — Tell Claude about the project (PROJECTS.md)

Claude reads `PROJECTS.md` on every session and uses it to resolve
aliases, pick the default project, and shape proposals. You'll fill it in
by copying values straight from the UI you just used.

**a) Copy the starter template into your repo.**

This folder ships [`PROJECTS.template.md`](./PROJECTS.template.md) — a
clean starter with bracketed placeholders and an opening note explaining
what each section does. Copy it to your repo's root as `PROJECTS.md`:

```bash
# From your repo root, with this skill folder available:
cp path/to/project-planner/PROJECTS.template.md ./PROJECTS.md
```

If you cloned this skill into `~/.claude/skills/project-planner/`, the
template is at `~/.claude/skills/project-planner/PROJECTS.template.md`.

**b) Find each value in the UI and replace the bracketed placeholder.**

The template has placeholders like `<project-name-1>`, `<PFX1>`, `<guid>`.
Here's where each one comes from:

| Template placeholder | Where to find it in the UI |
|---|---|
| `<project-name-1>` | The **Name** you typed when creating the project. Visible at the top of `/projects` and bold on `/projects/{id}`. |
| `<PFX1>` (prefix) | The **Prefix** field on `/projects/{id}/edit`. Same letters that appear before the dash on every work-item number — `WEB-1`, `WEB-2`. Use `—` if you didn't set one. |
| `<methodology>` | The methodology pill on `/projects/{id}` (Agile / Kanban / Waterfall). |
| `<guid>` (project id) | The Guid in the URL when you have the project open: `/projects/`**`78995612-0360-4530-8fec-30443c0a61da`** — that whole second segment is the id. |
| `<one-line purpose>` | A short note for Claude — *"main delivery board"*, *"bug-tracker for the WordPress plugin"*, etc. Helps when you have several projects. |
| Aliases | Whatever shorthand you'll naturally say in conversation. The prefix (`WEB`) is always a good one; *"the website"*, *"frontend"* — anything you'd say out loud. |
| Default project | One of the names from your table — the one you'll mean when you just say *"what's next?"* with no scope. |

**c) Minimum viable PROJECTS.md** for the Acme example:

```markdown
## Projects

| Project name | Prefix | Methodology | id | Notes |
|---|---|---|---|---|
| Acme website rebuild | WEB | Agile | 78995612-0360-4530-8fec-30443c0a61da | Default project. |

## Project aliases

| Alias | Project |
|---|---|
| `acme`, `the website`, `WEB` | **Acme website rebuild** |

**Default project** (when the user gives no project hint): **Acme website rebuild**.
```

(Replace the example Guid with your actual project id from the URL.)

That alone unblocks *"what's next for acme?"* without the disambiguation
prompt. The rest of the template — methodology rules cheat sheet,
plan-shape defaults, writing conventions per type, sizing convention,
lifecycle, and confirmation gate — can wait until you've shipped your
first plan and want to refine how Claude structures proposals.

**d) Commit `PROJECTS.md`** to your repo so the planning context ships
with the codebase. Anyone else cloning the repo will land in the same
context.

### Step 3 — Generate an API key

Browser → `/Account/Manage/ApiKeys` → **Generate new key** → name it
*"Claude Code on my laptop"* → tick the **`projects` scope** → Create →
copy the raw `fli_...` key. The key is shown once.

### Step 4 — Install the skill

Two install paths:

**Personal install** (covers all your repos):

```bash
mkdir -p ~/.claude/skills/project-planner
cp SKILL.md ~/.claude/skills/project-planner/
cp -r lib ~/.claude/skills/project-planner/
chmod +x ~/.claude/skills/project-planner/lib/flnk-plan.sh   # POSIX only
```

On Windows: `%USERPROFILE%\.claude\skills\project-planner\`.

**Team install** (skill ships with one specific repo):

Drop the folder under `.claude/skills/project-planner/` at the root of
the team's repo. Claude Code auto-discovers project-local skills there,
and committing to git means everyone on the team gets it on clone.

### Step 5 — Set environment variables

The skill reads three env vars from the shell where you launch your
editor. Set them before launching Claude Code:

| Var | Default | Notes |
|---|---|---|
| `FLNKIT_API_KEY` | — required — | The `fli_...` key from step 3. |
| `FLNKIT_API_BASE` | `https://flnk.it` | Override for self-hosted (e.g. `https://fastlinkit.dev.localhost:7152` for local dev). |
| `FLNKIT_AGENT_ID` | `claude-code` | Free-form identifier the server stamps on every agent-run row. Override if you want to distinguish multiple machines / users. |

```bash
# bash / zsh
export FLNKIT_API_KEY="fli_..."
export FLNKIT_API_BASE="https://flnk.it"
```

```powershell
# PowerShell
$env:FLNKIT_API_KEY = "fli_..."
$env:FLNKIT_API_BASE = "https://flnk.it"
```

For persistence across reboots, use your OS's persistent env-var
mechanism — `setx` on Windows, `~/.bashrc` / `~/.zshrc` on POSIX.

For dev hosts using a self-signed cert, also set `FLNKIT_INSECURE=1`
(or the script auto-detects `localhost` in the base URL).

### Step 6 — Open your editor in the repo and smoke-test

Launch Claude Code in the repo where `PROJECTS.md` lives. The skill
auto-loads from `~/.claude/skills/` and Claude reads `CLAUDE.md` +
`PROJECTS.md` on the first turn.

Try this:

> *"What FastLinkIt projects do I have access to?"*

Claude calls `list_projects` and reports your projects. If you see the
project name from step 1, you're wired up correctly.

### Step 7 — Plan your first batch of work

> *"What's next for acme? I want to focus on the homepage redesign."*

Claude reads `PROJECTS.md`, calls `get_project_context` to learn the
methodology + columns, then proposes a structured plan:

```
I propose for Acme website rebuild:

1. EPIC      Homepage redesign                          (no estimate)
2.   FEATURE     Hero + above-the-fold rework            (likely: 14h)
3.     STORY     As a visitor I want a clearer value prop above the fold   (likely: 6h)
4.     STORY     As a visitor I want a faster LCP score under 2.5s         (likely: 8h)
5.   FEATURE     Social proof section                                       (likely: 8h)
6.     STORY     As a marketer I want to show 3 customer logos and 2 quotes (likely: 5h)
7.     TASK      Wire the quote carousel to the CMS                         (likely: 3h)

Push these to Acme website rebuild? (y / N)
```

Reply *"y"*. Items land on the board as `WEB-1` through `WEB-7`. Open
the project list and you'll see them in **Backlog**, with the epic at
the top and features + stories nested beneath.

### Step 8 — Pick up your first item

> *"I'll start on WEB-3 — the value-prop refresh"*

Claude calls `start_task`. **WEB-3** moves to **In progress**, the
assignee column shows *"Claude Code"*, and the agent-run history records
the pickup.

You write the code (or do the design work, or whatever the story is).

### Step 9 — Wrap up

> *"Done — replaced the hero copy, ran the LCP profile in Chrome DevTools (2.1s now), pushed to main"*

Claude calls `complete_task` with the narrative as evidence. **WEB-3**
moves to **Review** with your summary attached. Open the work item in
the UI and you'll see the AI activity panel showing the run, the
duration, and the markdown narrative.

### Step 10 — What next?

Repeat steps 8-9 for the next item, OR ask:

> *"What's on my plate?"*

Claude returns items still assigned to you, grouped by status.

From here:

- **Add a new bug**: just say *"bug: <description>"* + paste a
  screenshot if you have one.
- **Plan more work**: *"plan three more stories for the social proof
  feature"* — Claude reads the existing tree and parents the new
  stories under WEB-5.
- **Check progress**: *"how's acme tracking?"*.

---

## The five modes in detail

### Plan mode

**Triggers**: *"What's next for X?"*, *"plan some work for X"*, *"give me a plan for the homepage redesign"*.

**Behaviour**: Claude calls `list_projects` → identifies the project (using your aliases from PROJECTS.md) → calls `get_project_context` for methodology + columns + recent items → proposes a methodology-aware plan:

| Methodology | Default plan shape |
|---|---|
| **Agile** | Hierarchy: one Epic → 2-5 Features → Stories → Tasks/Subtasks. Tiny goals (one cohesive change) skip the epic and produce 1-3 stories directly. |
| **Waterfall** | Phase-shaped task chain: ordered tasks with `depends_on_local_ids` so FinishToStart edges drive the Gantt + critical-path scheduler. |
| **Kanban** | Flat list of `task` / `bug` rows. No artificial hierarchy. |

**Override the shape mid-flight**: *"don't bother with an epic, just stories"*, *"group these into two epics"*, *"these can run in parallel — no dependencies"*. Claude reshapes and re-prints.

**Always confirms** before pushing. *"Looks good"* / *"let's see"* are NOT consent — only an explicit *"y"* / *"yes"* / *"ship it"*.

### Pickup mode

**Triggers**: *"I'll start on WEB-N"*, *"pick up the next one"*, *"resume FLNKA-22"*.

**Behaviour**: Calls `start_task` against the work item. Server moves the item to the in-progress column, sets assignee to the agent identifier (only when previously empty — won't trample a human assignee), and returns a `runId` Claude stores for the wrap-up call.

If you say *"pick up the next one"* without naming an item, Claude finds the highest-priority backlog item assigned to the agent and proposes it before calling `start_task`.

### Wrap-up mode

**Triggers**: *"done"*, *"I'm done with WEB-3"*, agent finishes a natural unit of work and announces completion.

**Success path**: Claude calls `complete_task` with a narrative summarising what changed (key files, follow-up items spawned, gotchas). Item moves to **Review** (or **Done** if you say *"skip review"*).

**Stuck path**: *"Stuck — need a design call before I can finish"* → Claude calls `block_task` with the reason. Item moves to **Blocked** with the reason logged. The reason is **mandatory** — no silent failures.

### Bug mode

**Triggers**: *"log a bug"*, *"bug:"*, *"I just hit X"*, *"this looks broken"*.

**Behaviour**: Claude drafts a single bug item with a structured repro template:

```
Repro steps:
1. <step 1>
2. <step 2>
…

Expected: <what should happen>
Actual:   <what happens instead>

Affected: <page / component / file path>
Environment: <browser / OS — when relevant>
```

Defaults: `priority=normal` (escalates to `high` on *"blocking"* / *"broken in prod"* phrasing), `tags=["bug", <area>]`, no parent. Auto-parents to the parent feature when the bug surfaces mid-pickup. Asks at most one clarifying question.

**Attachments**: paste a screenshot in the same message and Claude will list it in the proposal preview (`📎 Attachments: filename.png (442 KB)`). On confirmation the bug is created first, then each attachment uploads to the new work item. Allowed: images / PDFs / docs / archives / video. Rejected: executables. Max 25 MB per file.

### Scan mode

**Triggers**: *"What's on my plate?"*, *"anything assigned to me?"*, *"pick up the next one"*, *"what should I resume?"*.

**Behaviour**: Calls `get_project_context` with the assignee filter set to the agent identifier (`claude-code` by default). Returns items grouped by status:

```
You have 4 items assigned to claude-code on Acme website rebuild:

In progress (1)
- WEB-3  As a visitor I want a clearer value prop above the fold
        ⚠ run from previous session may still be open

Backlog (2)
- WEB-4  As a visitor I want a faster LCP score under 2.5s    priority: high
- WEB-7  Wire the quote carousel to the CMS                   priority: normal

Review (1)
- WEB-3  …                                                    (waiting for human review)

Want me to resume WEB-3, or pick up WEB-4 next? (or "neither")
```

Never auto-resumes. Always asks before calling `start_task`.

**Optional session-start mention**: when Claude opens a fresh session in the repo and finds in-progress items assigned to the agent, it mentions once on the first turn — *"I notice 1 item still in progress assigned to me from a previous session"* — so you don't lose track. Skipped silently when nothing is pending.

---

## Manual use of the helper scripts

The two helpers in `lib/` are usable from any shell, not just inside
Claude Code. Useful for scripting, CI, or scratch testing.

```bash
./lib/flnk-plan.sh list
./lib/flnk-plan.sh context <project-id>
./lib/flnk-plan.sh assigned <project-id> [agent-id]      # Scan-mode lookup
./lib/flnk-plan.sh plan <project-id> ./my-plan.json
./lib/flnk-plan.sh start <project-id> <work-item-id> "summary"
./lib/flnk-plan.sh complete <project-id> <work-item-id> <run-id> ./narrative.md
./lib/flnk-plan.sh block <project-id> <work-item-id> <run-id> "reason"
./lib/flnk-plan.sh attach <work-item-id> ./screenshot.png
```

PowerShell mirror at `lib/flnk-plan.ps1` with identical subcommands.

---

## Cross-client alternative — MCP server

If you use Cursor, Claude Desktop, Continue, or another MCP-aware client
that isn't Claude Code, install the **`@flnkit/mcp-server`** npm package
instead — same seven operations exposed as MCP tools, no shell wrapper
required. The MCP server is a sibling project to this skill; they hit
the same REST API.

```bash
npm install -g @flnkit/mcp-server
```

Add to your MCP client's config (Claude Desktop, Cursor, etc.) — see
the MCP server's own README for client-specific config snippets.

---

## Troubleshooting

### `FLNKIT_API_KEY not set`

The env var didn't make it to the process. Common causes:

- You set it in one shell but launched the editor from another.
- Claude Desktop / Cursor reads from the MCP server config block, not
  your shell env. Edit the MCP client's config and put the env vars in
  the `env: { … }` block. Restart the client.

### `403 Forbidden` on every call

Your API key probably doesn't have the `projects` scope. Generate a new
one with the scope ticked.

### `409 Another agent run is already active`

You opened a run on this item before and didn't close it. Two options:

1. **Resume**: ask Claude *"complete the open run on WEB-3 with a
   narrative of what got done"*.
2. **Wait it out**: the server expires stale runs after 10 minutes of
   inactivity. The next `start_task` will succeed.

### `400 Some items use a work-item type that's not allowed for this Kanban project`

Claude tried to push a `story` to a Kanban project (which only allows
`task` / `bug`). Re-prompt: *"that's a Kanban project — convert the
stories to tasks and resubmit"*.

### Self-signed cert errors on a dev host

If hitting `https://fastlinkit.dev.localhost:7152`: the helper script
auto-detects `localhost` and disables TLS verification. If it doesn't,
set `FLNKIT_INSECURE=1`.

### Claude says it pushed but the board shows nothing

Check the `errors` array in the response — per-item validation failures
(invalid type, status that doesn't match a column key, parent local id
that wasn't itself in the plan) come back here. Claude usually surfaces
them but if you missed it, ask: *"show me the raw `submit_plan`
response"*.

---

## What this skill does NOT do

By design:

- **It will never push without your explicit "yes".** *"Looks good"* /
  silence are not consent.
- **It won't pick the project for you when multiple match.** It'll list
  the candidates and ask.
- **It won't modify or delete existing items** — only creates new items
  and transitions status. For edits / merges / splits / re-parenting,
  use the web UI.
- **It won't auto-merge code changes.** Code execution is a separate
  scoping (Phase 1c on the AI roadmap). Today, you do the coding; the
  skill tracks the work.
- **It won't bypass plan-based access controls.** The same scope and
  ownership checks that gate the web UI gate the API.

---

## Privacy

Every API call carries the API key as `X-Api-Key`. Nothing is logged
beyond the existing FastLinkIt request log. The agent-run endpoints
write a `WorkItemAgentRun` row per pickup with `AgentId = "claude-code"`
(or whatever `FLNKIT_AGENT_ID` overrides to) so you can audit which
client acted on which item. Token / cost columns are zero for external
runs since the model isn't running on the FastLinkIt server.

Attachments go through the existing FastLinkIt attachment path — same
storage, same retention, same access controls as files attached via the
UI.

---

## Files in this folder

- **`SKILL.md`** — the playbook Claude Code reads on every session.
  Defines the five modes, trigger phrases, structured templates, and
  the confirmation-gate rules.
- **`PROJECTS.template.md`** — starter template for the per-repo
  `PROJECTS.md` companion file. Copy to your repo's root and fill in.
- **`lib/flnk-plan.ps1`** + **`lib/flnk-plan.sh`** — auth + JSON
  envelope helpers the skill calls. Usable standalone from any shell.
- **`README.md`** — this file.

---

## License

MIT.
