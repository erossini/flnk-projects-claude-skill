---
name: project-planner
description: Plan work for FastLinkIt Projects (a Kanban / Agile / Waterfall RCL) from a Claude Code session — list projects, fetch context, propose a methodology-aware plan, push items as work items, and update item status as work progresses (Pending → In progress → Done / Blocked).
---

# project-planner skill

This skill turns a free-form goal ("what's next for project X?", "land these
three bugs as work items", "I want to start working on FLNKA-21") into real
rows in the user's FastLinkIt Projects board. It uses three loops:

| Mode | Trigger | What happens |
|---|---|---|
| **Plan** | "what's next for X?" / "plan some work for X" | List projects → fetch context → propose ranked items → confirm → POST plan |
| **Pickup** | "start working on FLNKA-N" | Open agent run → move item to in-progress column |
| **Wrap-up** | "I'm done with FLNKA-N" / agent finishes natural unit of work | Close agent run → move item to review/done column → narrative summary |
| **Bug** | "log a bug", "bug:", "I just hit X", "this looks broken" | Draft a single bug item with structured repro steps → confirm → POST as standalone work item |
| **Scan** | "what's on my plate?", "anything assigned to me?", "pick up the next one", "resume what I was doing" | Filter recentItems to items where assignee matches the agent identifier → group by status → suggest pickup / resume |

## Required env

Before invoking, ensure these env vars are set in the calling shell (or in a
local `.env` the user sources):

| Var | Default | Notes |
|---|---|---|
| `FLNKIT_API_KEY` | — required — | API key with the `projects` scope. Generate at `/Account/Manage/ApiKeys`. |
| `FLNKIT_API_BASE` | `https://flnk.it` | Override for local dev: `https://fastlinkit.dev.localhost:7152`. |
| `FLNKIT_AGENT_ID` | `claude-code` | Free-form identifier the server stamps onto the run row. |

If `FLNKIT_API_KEY` is missing, **stop immediately** and instruct the user to
generate one with the `projects` scope ticked.

## Plan mode

When the user asks "what's next for X?" or similar:

1. Run `lib/flnk-plan.ps1 list` (Windows) / `lib/flnk-plan.sh list` (POSIX) to
   list projects. Identify the target project from the user's wording —
   match by name fuzzily, or ask if multiple match.
2. Run `... context <project-id>` to load the methodology + Kanban columns +
   allowed work-item types + recent items. Read the response carefully:
   - **methodology** dictates allowed item types. Kanban → `task` / `bug`.
     Agile → `epic` / `feature` / `story` / `task` / `bug` / `subtask`.
     Waterfall → `task` / `bug`.
   - **columns** dictates valid `initial_status` values — use the `key` field,
     not `label`.
   - **recentItems** shows existing work — avoid duplicates, parent new items
     to existing epics/features when relevant.
3. Read the repo's `CLAUDE.md` (and any `PROJECTS.md` if present) for project
   conventions: story format, AC structure, sizing convention.
4. **Structure the plan to match the project's methodology.** This is the
   default behaviour — only flatten if the human explicitly asks ("just give
   me a flat task list", "no epic, just stories"):

   - **Agile**: produce a hierarchy. For a non-trivial goal, propose **one
     `epic`** as the root, **2-5 `feature` rows** under it (each
     `parent_local_id` = the epic), then `story` rows under each feature
     (each parent = its feature). Granular engineering chunks land as
     `task` or `subtask` under the relevant story. Bugs use `bug` and sit
     wherever they belong in the tree. For tiny goals (one cohesive
     change), skip the epic and produce 1-3 stories directly.
   - **Waterfall**: produce phase-shaped task chains. Use `task` rows with
     `parent_local_id` references to model the workstream. Set
     `depends_on_local_ids` on the FinishToStart edges so the Gantt and
     critical-path scheduler render correctly.
   - **Kanban**: flat list of `task` / `bug` rows. No hierarchy beyond
     parent_local_id where two items genuinely belong together.

   Whatever the methodology, write each item to its convention (stories
   need `acceptance_criteria`, bugs need `repro_steps`, etc. — see the
   "Conventions" section below).

5. **Surface the structured plan to the human** before doing anything
   else. Render shape per methodology:

   **Agile** — indent so the tree is visible at a glance:

   ```
   I propose for the FastLinkIt Agile project:

   1. EPIC   Customer onboarding overhaul                          (no estimate)
   2.   FEATURE   Sign-up flow refresh                              (likely: 16h)
   3.     STORY   As a new user I want to sign up via Google …      (likely: 6h)
   4.     STORY   As a new user I want a guided first-link tour …   (likely: 8h)
   5.   FEATURE   Welcome email sequence                            (likely: 12h)
   6.     STORY   As a new user I want a 3-email welcome drip …     (likely: 4h)
   7.     TASK    Wire welcome drip into IMailingSequenceService     (likely: 4h)

   Push these to the FastLinkIt board? (y / N)
   ```

   **Waterfall** — number the items, list dependencies in a "depends on"
   column so the human sees the chain at a glance:

   ```
   I propose for the Q3 platform migration project:

   #  Type  Title                                  Likely  Depends on
   1  TASK  Schema audit + migration plan          12h     —
   2  TASK  Stand up replica DB                    8h      #1
   3  TASK  Backfill replica from prod snapshot    16h     #2
   4  TASK  Cutover dry-run                        6h      #3
   5  TASK  Production cutover window              4h      #4
   6  TASK  Decommission legacy DB                 2h      #5

   Push these to the FastLinkIt board? (y / N)
   ```

   **Kanban** — flat numbered table with type, priority, and est:

   ```
   I propose for the FastLinkIt Kanban project:

   #  Type  Priority  Title                                       Likely
   1  TASK  high      WIP-limit enforcement on board columns      4h
   2  TASK  normal    Assignee avatars on Kanban cards            2h
   3  BUG   normal    Drag handle hint on hover (cards look static) 1h
   4  TASK  low       Dark-mode column-tint cleanup                1h

   Push these to the FastLinkIt board? (y / N)
   ```

   Whatever the methodology, always show the item **type** explicitly so
   the human can spot a wrong-shaped item before confirming.

6. **Always wait for explicit "yes" / "y" before POSTing.** A "let's see"
   or "looks good" without confirmation is NOT consent.
7. On confirmation, build the JSON envelope (see schema below) and call
   `... plan <project-id> <plan.json>`. Report back the created item numbers
   from the response so the human can click them.

## Pickup mode

When the user says "start working on FLNKA-N" / "pick up the next one":

1. Resolve the work item id by listing items (or the user gave one explicitly).
2. Call `... start <project-id> <work-item-id>` with an optional summary
   ("I'll handle the FK migration first, then refactor"). The server:
   - Opens a `WorkItemAgentRun` row with the agent identifier (from
     `FLNKIT_AGENT_ID`, default `claude-code`).
   - Moves the item to the in-progress column.
   - **Sets the assignee** to the agent identifier when the work item
     was previously unassigned — so the row clearly shows "Claude Code"
     in the Assignee column on the board / list. If a human was already
     assigned, the assignee is left alone (the run row still tracks the
     pickup; the audit trail remains intact).
   - Returns a `runId` — **store this** in the conversation; you'll need
     it to close out.
3. Print the response so the human sees "moved from <old> to <new>".

## Wrap-up mode

When the agent finishes the work or the user says "done":

1. Call `... complete <project-id> <work-item-id> <run-id>` with a narrative
   describing what was done (key files touched, follow-up items spawned, any
   gotchas). Server moves the item to the review (or done) column.
2. If something blocks progress and you can't finish, call
   `... block <project-id> <work-item-id> <run-id> "<reason>"` instead.
   The reason is mandatory — no silent failures.

## Bug-report mode

When the user reports a bug ("log a bug", "bug:", "I just hit X", "this
looks broken", "create a bug for Y") OR you discover a bug while working on
something else:

1. **Don't ask 5 questions.** Draft the bug from what the user gave you and
   ask ONE clarifying question only if a critical field is genuinely missing
   (e.g. "what page were you on?" when they said "the dropdown is broken"
   with no surface context). Trust your code-reading — if you can infer the
   affected file from the description, do so without asking.

2. Compose the work item with these defaults:
   - `type = "bug"`
   - `priority = "normal"` — escalate to `"high"` if the user said "blocking" /
     "broken in prod" / "data loss"; `"highest"` only on explicit request.
   - `initial_status = "backlog"` (use the actual column key from
     `get_project_context`).
   - `repro_steps` is **mandatory**. Use this template, filled from the
     user's description:

     ```
     **Repro steps:**
     1. <step 1>
     2. <step 2>
     …

     **Expected:** <what should happen>
     **Actual:** <what happens instead>

     **Affected:** <page / component / file path>
     **Environment:** <browser / OS / theme — only when relevant>
     ```

   - `description` carries any extra narrative: what you were trying when
     it surfaced, recent commits in the area, related code references,
     hypothesis. Markdown OK.
   - `tags`: always include `bug` plus area tags inferred from the
     description (`board`, `wiki`, `mailing`, `links`, `payments`, etc.).

3. **Auto-parent when the bug surfaces mid-pickup.** If you're in the middle
   of an active `start_task` run on FLNKA-X and notice an unrelated bug in
   the surrounding code, default `parent_local_id` to the **same parent
   feature** as FLNKA-X (one hop up the tree). The bug nests next to the
   work that exposed it. User can override with "no, log it standalone" —
   in which case omit `parent_local_id`.

4. Surface the proposed bug to the user for confirmation, same gate as Plan
   mode — show the rendered repro steps so they can spot a misread:

   ```
   I propose:

   BUG  Resize handle loses drag state on Blazor thead re-render
   priority: normal · tags: bug, board, ux
   parent: FLNKA-22 (Worktree-based execution sandbox)

   Repro steps:
   1. Open /projects/{id} list view
   2. Drag a column resize handle
   3. Trigger a Blazor render that replaces the thead (filter change, sort
      toggle)
   4. Try to resize again

   Expected: drag continues to work after the re-render
   Actual: handle no longer responds; pointerdown doesn't fire

   Affected: Components/Pages/ProjectDetail.razor + projects-table-resize.js
   Environment: Edge 131 / Win 11

   Push to FLNKA? (y / N)
   ```

5. After the user's "yes", POST a single-item plan to
   `/api/projects/{id}/plan` (the same endpoint Plan mode uses — Bug mode
   is a one-item special-case). Report back the new FLNKA-N + the
   `/projects/{id}` URL.

6. **If the user pasted screenshots / files**, attach them to the new
   work item AFTER the create call:
   - Each pasted image lands at a real disk path (Claude Code surfaces
     these in the conversation as `[Image: source: <path>]`).
   - List the files in the proposal preview BEFORE the confirmation gate
     so the user knows what'll be attached:

     ```
     BUG  Resize handle pushes preview off-screen
     priority: normal · tags: bug, board, ux
     📎 Attachments: screenshot-2026-05-09-bug.png (442 KB)

     Push to FLNKA + upload 1 attachment? (y / N)
     ```

   - On the user's "yes", call `... attach <work-item-id> <file-path>`
     for each file after the plan POST succeeds. The server's allowlist
     rejects executables silently — just report what landed.
   - If an attachment upload fails, surface the failure but don't roll
     back the create — the work item is still useful without the
     screenshot. Suggest re-attaching manually via the UI.

7. **Optional pickup chain**: if it's clear the user wants to start fixing
   the bug right now, ask "Want me to pick it up now? (y / N)" — on yes,
   chain straight into Pickup mode with the new item id. Don't auto-pickup
   without asking.

If the bug came up while you were already in the middle of a pickup on
FLNKA-X, the original run stays open — log the bug as a side action, then
return your attention to FLNKA-X (or call `block` on FLNKA-X if the bug
literally blocks the work).

## Scan mode

When the user asks "what's on my plate?", "anything assigned to me?",
"what should I resume?", or similar — they want to see the work already
queued for the agent, not propose new items.

1. Run `... assigned <project-id>` (helper script) or call
   `get_project_context` with `assignee = <FLNKIT_AGENT_ID, default
   "claude-code">` (MCP tool). The server returns `recentItems`
   filtered to items where `AssigneeUserId` matches the agent
   identifier, with the cap lifted to 200.

2. **Group by status** using the project's column keys, prioritising
   what the human probably wants to see first:

   - **In progress** items first — these may have an open `WorkItemAgentRun`
     that didn't get closed in a previous session. Surface them with a
     "resume?" suggestion.
   - **Review / Blocked** items next — work the agent has already done
     that's waiting for human action; mention but don't propose to do
     anything.
   - **Backlog / To do** items last — these are ready to pick up. Sort
     by `priority` desc, then by `Number`.

3. Render the response as a grouped list, with the status column the
   item's in:

   ```
   You have 4 items assigned to claude-code on FastLinkIt Agile project:

   In progress (1)
   - FLNKA-22  Worktree-based execution sandbox    (likely 28h)
              ⚠ run from previous session may still be open

   Backlog (2)
   - FLNKA-23  As an AI agent, I want a git worktree…  (priority: high)
   - FLNKA-26  As a project owner, I want per-run cost ceilings…  (priority: high)

   Review (1)
   - FLNKA-27  Surface cost progress in AI activity panel  (waiting for human review)

   Want me to resume FLNKA-22, or pick up FLNKA-23 next? (or "neither")
   ```

4. **Don't auto-resume / auto-pickup.** Always ask first. If the user
   says "resume FLNKA-22", chain into Pickup mode (the existing
   `start_task` call rejects with `409 Conflict` if there's already an
   active run — useful guard, surface the message).
   If the user says "pick up the next one" without naming an item, take
   the highest-priority backlog item from the list and confirm BEFORE
   calling `start_task`.

5. **"Pick up the next one" shortcut.** When the user phrases the trigger
   as "pick up the next one" / "give me the next task" / "what's next",
   skip the grouped list — go straight to the highest-priority backlog
   item and propose it as a Pickup-mode confirmation.

6. **Session-start passive mention** (optional, low-key): on the FIRST
   user turn in a fresh session in this repo, if Scan finds in-progress
   items assigned to the agent, mention once: *"I notice 1 item still in
   progress assigned to me from a previous session — say 'resume FLNKA-22'
   to continue."* No auto-resume. Skip the mention entirely when nothing
   is assigned (don't add noise to every session start).

If the user has multiple projects, default to scanning the project they
mentioned most recently in this conversation; otherwise scan all of them
and group by project.

## Plan JSON envelope

The plan endpoint accepts the same shape Anthropic's `submit_plan` tool emits.
Each item carries:

```json
{
  "summary": "Optional one-line description of the plan",
  "items": [
    {
      "local_id": 1,
      "title": "Add WIP limit enforcement to Kanban columns",
      "type": "task",
      "description": "Markdown body. The KanbanColumn.WipLimit field exists in the schema but no UI surfaces it...",
      "acceptance_criteria": "- Column header shows 'N / Limit' when limit set\n- Drop blocked when over limit\n- Admin override available",
      "initial_status": "backlog",
      "priority": "normal",
      "parent_local_id": null,
      "estimate_optimistic_hours": 2.0,
      "estimate_likely_hours": 4.0,
      "estimate_pessimistic_hours": 8.0,
      "depends_on_local_ids": [],
      "tags": ["kanban", "ux"]
    }
  ]
}
```

`local_id` is a within-this-plan integer. Use `parent_local_id` and
`depends_on_local_ids` to wire hierarchy + FinishToStart dependencies — they
resolve to real Guids on the server in topological order, so you don't have
to materialise parents first.

## Conventions to follow

- **Stories** — write the title as a user story when type is `story`:
  "As a <role> I want <capability> so that <outcome>". Always supply
  `acceptance_criteria` as a bullet list of testable conditions.
- **Bugs** — supply `repro_steps` (numbered list), expected vs actual, and
  the affected component / page.
- **Epics / Features** — keep the description short; treat them as containers.
  Children carry the detail.
- **Tasks** — engineering work, no story ceremony required.
- **Estimates** — three-point PERT (`optimistic` / `likely` / `pessimistic`).
  When uncertain, follow the team's convention from PROJECTS.md or CLAUDE.md.
- **Tags** — reuse existing tags from `recentItems` where they fit; otherwise
  use lowercase short names (`kanban`, `ux`, `api`, `bug`, etc.).

## Things this skill does NOT do

- Auto-merge code changes (Phase 1c, separate scoping doc).
- Bypass the human confirmation gate. Ever.
- Pick the project for the user without asking when more than one matches.
- Push items without first running `context` to validate types + columns.
- Modify or delete existing items. (Use the web UI for those.)
