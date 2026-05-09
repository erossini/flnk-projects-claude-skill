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
4. Compose a ranked list of work items with rationale. **Surface the list to
   the human as a numbered table** before doing anything else:

   ```
   I propose:
   1. <title>  [type, est: 4h, parent: FLNKA-9]
   2. <title>  [type, est: 8h]
   ...

   Push these to the FastLinkIt board? (y / N)
   ```

5. **Always wait for explicit "yes" / "y" before POSTing.** A "let's see" or
   "looks good" without confirmation is NOT consent.
6. On confirmation, build the JSON envelope (see schema below) and call
   `... plan <project-id> <plan.json>`. Report back the created item numbers
   from the response so the human can click them.

## Pickup mode

When the user says "start working on FLNKA-N" / "pick up the next one":

1. Resolve the work item id by listing items (or the user gave one explicitly).
2. Call `... start <project-id> <work-item-id>` with an optional summary
   ("I'll handle the FK migration first, then refactor"). The server moves
   the item to the in-progress column and returns a `runId` — **store this**
   in the conversation; you'll need it to close out.
3. Print the response so the human sees "moved from <old> to <new>".

## Wrap-up mode

When the agent finishes the work or the user says "done":

1. Call `... complete <project-id> <work-item-id> <run-id>` with a narrative
   describing what was done (key files touched, follow-up items spawned, any
   gotchas). Server moves the item to the review (or done) column.
2. If something blocks progress and you can't finish, call
   `... block <project-id> <work-item-id> <run-id> "<reason>"` instead.
   The reason is mandatory — no silent failures.

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
