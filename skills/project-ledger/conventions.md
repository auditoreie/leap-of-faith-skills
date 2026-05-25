# project-ledger — conventions

Lazy-loaded reference. Do not preload this file. Open it only when:
- the user asks how the skill works
- about to deviate from a default and want to confirm the rule
- generating an ADR and need voice/structure guidance beyond the template

## ADR voice

Write ADRs in the voice of the team, not a narrator. Past or present, never future ("we will…"). Decisions are accepted, not proposed.

- Title is a **decision in 6-10 words**, not a topic. Bad: "Streaming approach". Good: "Adopt fake client-side streaming for MVP, real SSE later".
- Status is one of: `Accepted`, `Superseded by ADR-NNNN`, `Deprecated`. New ADRs are always `Accepted` (use `adr new` with `--status` to override, rarely).
- Context is **why this came up**, in 2-4 sentences. Reference constraints (deadlines, dependencies, prior ADRs). No restatement of the obvious.
- Decision is **what was chosen and rejected**. Always list the alternatives that were considered and the reason for rejection — that's where the value lives.
- Consequences are split into positive, negative, follow-ups. Negative is non-negotiable — if you can't name one, the decision wasn't real.

## Task voice

Tasks are the writer's working log. First-person plural ("we") is fine. Bullets > prose. Timestamps on every working-log entry: `### 2026-05-25 14:30` style.

## ID and numbering

- ADR ids: zero-padded 4 digits, sequential, never reused. `0001`, `0002`, ...
- Task ids: `YYYY-MM-DD-<slug>`. If two tasks start on the same day with the same slug, suffix with `-2`, `-3`. Rare.

## Slug rules

Lowercase, hyphen-separated, no special chars, ≤ 40 chars. Drop articles ("the", "a"). Use the verb form when possible: `migrate-auth-provider`, not `auth-migration`.

## Token costs for common ops

Use these to plan tool calls:

| Op | Cheap | Avoid |
|---|---|---|
| `status` | `ls` + head of index | Reading all ADRs |
| `task new` | Read index + ≤3 ADRs | Code analysis |
| `task close` (ADR gen) | Read just the closed task | Re-read code/ADRs |
| `sync` | Fetch only open tasks | Mirroring closed archive |

## When a task spans multiple ADRs

If, while working, the task accumulates more than one distinct decision, prefer to **close and reopen**: close the task with the first decision as ADR, open a new task for the next decision. Avoids tangled ADRs.

## When an ADR needs revision

Don't edit accepted ADRs. Write a new one with status `Supersedes ADR-XXXX`, and add a line to the old one: `Superseded by ADR-NNNN`. Keeps history readable.

## `init` heuristics

When inferring stack from a repo, look in this order and stop at first hit:

1. `package.json` → Node/TS — check `dependencies` keys to spot frameworks (astro, next, fastify, react).
2. `pyproject.toml` / `requirements.txt` → Python — note any framework keys.
3. `go.mod` → Go.
4. `Cargo.toml` → Rust.
5. `pom.xml` / `build.gradle` → JVM.
6. Top-level files only — do not recurse into `src/`.

Top-level dirs to mention in baseline: `src/`, `app/`, `pages/`, `components/`, `api/`, `lib/`, `tests/`, `docs/`, `scripts/`, `public/`, `frontend/`, `backend/`. Skip `node_modules/`, `dist/`, `.git/`, `.next/`, build outputs.

## When to suggest `sync`

Don't volunteer. Only suggest Notion/ClickUp sync when:
- user already used it once in this project, or
- user mentions Notion/ClickUp/board/kanban in the same turn.

The default is local-only.

## Failure modes to avoid

- **Loading the whole repo to write a baseline ADR.** Baseline is a surface map. If you find yourself reading source files in `src/**`, stop — you're over-investing.
- **Mirroring closed tasks to Notion by default.** Open only.
- **Auto-running `task new` because the user mentioned work.** Wait for an explicit ask or strong signal.
- **Generating ADRs without a follow-up suggestion when consequences imply more work.** Always close the loop.
