---
name: project-ledger
description: Orchestrates engineering decisions (ADRs versioned in git) and active work (local non-versioned tasks) for any project. Use when the user asks to start a new task, close a task, record an architectural decision, bootstrap a project's ledger, sync tasks to Notion/ClickUp, or check the current status of tasks/ADRs. Also triggers when the user says "registrar decisão", "abrir task", "fechar task", "gerar ADR", "sincronizar com Notion/ClickUp", or similar. Avoid invoking for one-off code edits that don't represent a decision. NÃO use para criar task no ClickUp com discovery (isso é /criar-task).
---

# project-ledger

A two-layer engineering ledger:

- **ADRs** (Architecture Decision Records) → versioned in git under `docs/adr/`. Stable, append-only history of accepted decisions.
- **Tasks** → local-only under `.claude/tasks/` (gitignored). Mutable working log of in-progress work. When a task closes, it produces an ADR.

The goal is twofold: (a) onboard quickly to a project by reading ADRs, and (b) implement without conflicting with prior decisions or legacy code.

## Subcommands

Route by the user's intent or first arg. **Do only what was asked** — do not auto-trigger other subcommands.

| Subcommand | When to run |
|---|---|
| `init` | First time using the skill in a repo, or user asks to bootstrap. |
| `task new <slug>` | User starts new work that needs tracking. |
| `task update <id>` | User reports progress, decision, or blocker on an open task. |
| `task close <id>` | User says the work is done or accepted. **Always generate an ADR from the closed task.** |
| `task list` | User wants to see what's open / recently closed. |
| `adr new <slug>` | User wants to record a decision *not* tied to a task (rare). |
| `adr list` | User wants to browse decisions. |
| `sync notion` / `sync clickup` | User asks for external mirror (requires MCP available). |
| `status` | Default if intent unclear — shows open tasks + last 3 ADRs. |

If args are ambiguous, ask one short clarifying question before acting.

## Filesystem contract

```
<repo>/
├── docs/adr/                           ← VERSIONED (git)
│   ├── README.md                       ← index
│   ├── 0001-baseline.md                ← capabilities of the repo
│   └── NNNN-<slug>.md
├── .claude/tasks/                      ← LOCAL ONLY (gitignored)
│   ├── open/
│   │   └── YYYY-MM-DD-<slug>.md
│   └── closed/
│       └── YYYY-MM-DD-<slug>.md        ← archived after close; ADR was generated from it
└── .gitignore                          ← must contain `.claude/` (skill ensures this)
```

## Token discipline (critical)

This skill runs on every interaction with a project. It must be cheap to invoke.

- **Never load all ADRs at once.** Use the index (`docs/adr/README.md`) to pick relevant ones by title.
- **Never load all closed tasks.** Closed tasks are archive — only open them if the user asks or if generating an ADR for a related decision.
- **Do not delegate to sub-agents** for simple reads/writes. Sub-agents cost more than direct file ops.
- **Lazy-load `init.md`** only for `init`, and **conventions.md** only when the user asks "how does this skill work" or when about to violate a convention.
- **Lazy-load templates** from `templates/` only when about to create the corresponding artifact. Do not preload.
- When generating an ADR from a closed task, the **closed task is the input** — do not re-analyze code unless the task is missing critical context.
- For status / list operations, prefer `ls` + reading filenames over reading file bodies.

## `init` flow

Read `init.md` (same folder) **only when running `init`**: steps, smell tests and the final output shape. Budget: ≤ 8 cheap reads, no sub-agents, < 10K tokens.

## `task new <slug>` flow

1. Compute `id = YYYY-MM-DD-<slug>`.
2. Refuse if `.claude/tasks/open/<id>.md` already exists; offer `task update` instead.
3. Read `docs/adr/README.md` and pick ADRs whose titles match keywords in the slug (max 3). Read those only.
4. Create the task file from `templates/task.md`, prefilling the "Constraints from ADRs" section with bullet refs to the matched ADRs (link by filename, do not inline the full ADR body).
5. Report the path; suggest the user describe goal / steps if not provided.

## `task update <id>` flow

- Append a timestamped entry to the "Working log" section of `.claude/tasks/open/<id>.md`. Do not rewrite earlier entries.
- If a decision was made that contradicts an ADR, flag it explicitly in the log and suggest the user open a new ADR via `adr new` after the task closes.

## `task close <id>` flow

1. Read `.claude/tasks/open/<id>.md` in full (this is the cheapest input for ADR generation).
2. Determine the next ADR number from `docs/adr/README.md`.
3. Generate `docs/adr/NNNN-<slug>.md` from `templates/adr.md`:
   - Title: short, decision-flavored (e.g. "Adopt token streaming via SSE for landing chat").
   - Status: `Accepted`.
   - Context: distilled from task's "Goal" + "Constraints" sections.
   - Decision: distilled from "Working log" — the final approach taken.
   - Consequences: positive + negative + follow-ups. If follow-ups exist, suggest the user open new tasks for them.
4. Move the task file to `.claude/tasks/closed/<id>.md`. Add a line at the top: `Closed: YYYY-MM-DD → ADR-NNNN`.
5. Update `docs/adr/README.md` index.
6. Report the new ADR path + summarize the decision in 1-2 sentences.
7. Do not stage or commit — versioning of ADRs is the user's call.

## `sync notion` flow

- Requires the Notion MCP to be connected (tools named `mcp__*Notion__*` available). If not, tell the user to authenticate and stop.
- Mirror **open tasks only** by default. Closed tasks go only if user adds `--all`.
- For each open task, search Notion for a page with title = `[task-id]`. Update if found, create if not.
- Never delete remote pages — the local ledger is source of truth, but Notion archives are user's responsibility.

## `sync clickup` flow

- Same shape as `sync notion`. Uses `mcp__*ClickUp__*` tools.
- Requires the user to provide list_id / space the first time; remember it via Auto Memory if available, otherwise ask each run.

## `status` flow

- `ls .claude/tasks/open/` → list filenames (no body reads).
- Read last 3 entries from `docs/adr/README.md`.
- One-line summary per item. Don't open any task or ADR body unless asked.

## Conventions and templates

For details on template structure, ADR voice, and edge cases, read `conventions.md` only when needed.

Templates live in `templates/`. Load on demand:
- `templates/adr.md` — for new ADRs from closed tasks
- `templates/adr-0001-baseline.md` — for the initial repo capability snapshot
- `templates/task.md` — for new tasks

## Safe-mode defaults

- **Never run git commands** unless the user explicitly asks. ADRs are written but not staged or committed.
- **Never delete files** — task close moves to `closed/`, doesn't remove.
- **Never push to Notion/ClickUp without explicit `sync` invocation.**
- If a destructive action is implied (e.g. `task delete`), confirm with the user.
