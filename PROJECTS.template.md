# PROJECTS.md

> **This is a starter template.** Copy it to your repo's root as
> `PROJECTS.md` and fill in the bracketed placeholders. Claude reads this
> file on every session, so anything you put here shapes the planner's
> behaviour. Keep it terse and rule-shaped — Claude prefers structure to
> prose.

Planning playbook for **<your-product-name>** — the companion to
`CLAUDE.md` for the **project-planner** Claude Code skill (and the
`@flnkit/mcp-server` MCP server). Where CLAUDE.md tells Claude *how the
codebase is organised*, this file tells Claude *how the work on it is
organised*: which projects exist, which methodology each uses, how items
should be written, and how to commit them to the board.

When Claude is asked to plan, list, prioritise, pick up, or close work,
read this file in addition to CLAUDE.md.

---

## Projects

> Resolve project ids by calling `list_projects` (MCP) or
> `flnk-plan list` (skill helper) once. Replace the placeholder rows below
> with what comes back. Refresh whenever you rename / recreate a project.

| Project name | Prefix | Methodology | id | Notes |
|---|---|---|---|---|
| <project-name-1> | <PFX1> | Agile / Kanban / Waterfall | `<guid>` | <one-line purpose>. **Default project.** |
| <project-name-2> | — | Kanban | `<guid>` | <one-line purpose>. |

API base: `https://flnk.it` (prod) — replace with your host if self-hosted.

## Project aliases

When the user mentions any of these shorthand names, resolve to the project
on the right **without asking**. Add new aliases as your team's vocabulary
evolves.

| Alias | Project |
|---|---|
| `<short>`, `<another>`, `<prefix>` | **<project-name-1>** |
| `<short>`, `<another>` | **<project-name-2>** |

**Default project** when the user gives no project hint at all (just *"what's
next?"* / *"any bugs?"*): **<project-name-1>**.

**Disambiguate only when there's genuine collision** — single-word prompts
that cleanly hit one alias resolve silently; multi-match references ask.

---

## Methodology rules

The server validates work-item types against project methodology — pick the
wrong type and the plan is rejected. Cheat sheet:

| Methodology | Allowed types |
|---|---|
| **Kanban** | `task`, `bug` |
| **Agile** | `epic`, `feature`, `story`, `task`, `bug`, `subtask` |
| **Waterfall** | `task`, `bug` |

`get_project_context` returns the authoritative list per project — call it
before writing a plan and use the keys it returns.

## Default plan shape per methodology

When the user asks for a plan, **structure it to match the project's
methodology** by default. Only flatten if they explicitly ask ("just give me
a flat list", "skip the epic"):

- **Agile**: hierarchy. For non-trivial goals propose **one `epic`** as the
  root, **2-5 `feature` rows** under it, then **`story` rows** under each
  feature, with `task` / `subtask` rows for the engineering chunks inside
  each story. Bugs use `bug` and live wherever they belong in the tree. For
  tiny single-cohesive-change goals, skip the epic and produce 1-3 stories
  directly.
- **Waterfall**: phase-shaped task chains. Use `task` rows with
  `parent_local_id` for grouping and `depends_on_local_ids` for the
  FinishToStart edges so the Gantt + critical-path scheduler render
  correctly.
- **Kanban**: flat list of `task` / `bug`. No artificial hierarchy.

Hierarchy round-trips through the server's topo-sort materialiser — you
don't have to land parents first.

---

## Writing conventions

### Epics (Agile only)
- Container for a multi-week chunk of work.
- Title: noun phrase ("<Customer onboarding overhaul>").
- Description: 2-3 sentences on the *outcome* — not the implementation.
- No estimate.

### Features (Agile only)
- Sits between Epic and Story. One delivery sprint or two.
- Title: capability ("<Multi-tenant API keys with scope inheritance>").
- Description: bullet list of what's in scope + what's out.

### Stories
- Title in user-story form: **"As a *role*, I want *capability*, so that *outcome*."**
- `acceptance_criteria` is **mandatory**: bullet list of testable conditions.
  Each bullet is one observable behaviour. No "should be performant" type
  hand-waving — express it as a measurement ("p95 latency ≤ 200ms under
  100 concurrent users").
- 3-point PERT estimate (`optimistic` / `likely` / `pessimistic`) in hours.
- `priority`: `lowest` / `low` / `normal` / `high` / `highest`. Default
  `normal`; reserve `high` / `highest` for blockers and customer escalations.

### Tasks
- Engineering work, no story ceremony.
- Title imperative ("<Add WIP-limit check to drag handler>").
- Description optional but encouraged when the task isn't obvious from the
  title.
- 3-point PERT estimate when possible.

### Bugs
- Title: short symptom ("<Mailing send loop deadlocks on large groups>").
- `repro_steps` mandatory: numbered list, expected vs actual, affected page
  / component.
- Estimate optional — bugs vary wildly.

### Test tasks (any methodology)
- **When to use**: smoke-test / verification work generated AT WRAP-UP TIME
  — the human needs to manually verify Claude's work after `complete_task`
  fires. Distinct from `acceptance_criteria` on the parent story
  (which are conditions baked into the story itself).
- **Type**: `task` (works in Kanban / Agile / Waterfall — every methodology
  allows it).
- **Title**: `"Test: <one-line description>"` or `"Smoke test: <…>"`.
- **Parent**: the work item that produced the code being tested
  (`parent_local_id`).
- **Description**: numbered verification steps + expected outcome per step.
- **Tags**: always `test` + `smoke-test`, plus area tags inherited from the
  parent (`board`, `mailing`, `payments`, etc.).
- **Estimate**: usually small (15-60 minutes per test) but document if it
  involves slow setup (provisioning a test environment, waiting on async
  jobs).
- Pre-emptive tests — written *before* the code — are folded into the parent
  story's `acceptance_criteria` instead. Don't double-track.

### Subtasks (Agile only)
- Use sparingly — overuse turns the board into a TODO list.
- Reserve for genuinely separable chunks of one Story (front-end vs
  back-end, migration vs cutover).

## Sizing convention

- Hours, not story points. Estimates are 3-point PERT (`optimistic`,
  `likely`, `pessimistic`).
- One ideal eng day = **6 hours** (matches the project's
  `Projects:DefaultHoursPerDay` default — adjust if your team uses a
  different baseline).
- If a single item is over 16 likely-hours, split it into smaller items.

## Tags

Reuse existing tags from the project's recent items where they fit. When
introducing a new tag, prefer:

- area: `<feature-area-1>`, `<feature-area-2>`, `<feature-area-3>`, …
- type: `bug`, `feature`, `refactor`, `docs`, `tests`, `perf`, `security`
- track: `<initiative-1>`, `<initiative-2>`, …

Lowercase, single-word, dash-separated when needed (`auth-flow`, not
`AuthFlow`).

---

## Lifecycle (when Claude works on a task)

When Claude picks up a work item to actually do the work:

1. Call `start_task(projectId, workItemId, "what I'm about to do")`. Server
   moves the item to the in-progress column, sets the assignee to the agent
   identifier (when previously empty), and returns a `runId`.
2. Do the work — write code, run tests, etc.
3. **Success path**: call `complete_task(projectId, workItemId, runId, narrative)`
   with a summary of what was done. Server moves the item to review (or
   done if `skipReview: true`).
4. **Stuck path**: call `block_task(projectId, workItemId, runId, reason)`
   with an explicit blocker. Server moves the item to the blocked column.
   The reason is mandatory — no silent failures.

The `runId` survives the conversation: store it next to the item id so the
close-out call can find it.

## Confirmation gate

Before calling `submit_plan`, **always** print the proposed item list as a
numbered table with title, type, parent, estimate, and rationale. Wait for
the user's explicit "yes" / "y" / "ship it". Anything ambiguous ("looks
good", "let's see") is NOT consent.

Before calling `start_task`, confirm which item the user means when their
phrasing is fuzzy ("the WIP-limit one" — there might be two).

After every state change (`submit_plan`, `start_task`, `complete_task`,
`block_task`), report the response back so the user sees what landed.

---

## What's currently open

> Refresh this list periodically by asking Claude *"what's next for
> <default-project>?"* and letting it run `get_project_context`. The list
> below is a manual seed; it goes stale fast.

<delete this section if you don't want a manual roadmap, OR replace with
your own ranked next-steps list>

1. **<thing 1>** — <one-line description>. ~<estimate>
2. **<thing 2>** — <one-line description>. ~<estimate>
3. **<thing 3>** — <one-line description>. ~<estimate>
