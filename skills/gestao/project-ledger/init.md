# project-ledger — `init` flow

Loaded on demand by `SKILL.md` only when running `init`.

**Goal:** the user finishes the first run with concrete insights they did not have before — not just folder structure. Boring init = wasted skill.

**Budget:** ≤ 8 cheap reads, no deep-dive into `src/**`, no sub-agents. Total target < 10K tokens.

### Steps

1. Confirm cwd is a git repo. If not, ask the user before doing anything.
2. Ensure `.claude/` is in `.gitignore`. Add if missing.
3. Create `docs/adr/`, `docs/adr/README.md` (header only), `.claude/tasks/open/`, `.claude/tasks/closed/` if missing.
4. **Surface scan** (cap at 8 reads, all shallow):
   - Manifests: `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` — pick the first that exists.
   - `README.md` (head, first ~100 lines).
   - `.gitignore` (already needed for step 2).
   - Top-level `ls`.
   - One-level `ls` of `src/`, `app/`, or `lib/` — whichever exists. Do NOT recurse.
   - `.github/workflows/` ls (or `.circleci/`, `.gitlab-ci.yml`).
   - Stack-specific config (only if obviously present): `astro.config.*`, `next.config.*`, `vite.config.*`, `drizzle.config.*`, `tsconfig.json` (just check `strict`).
5. **Run smell tests** on what was already read — no extra reads. See "Smell tests" below.
6. **Generate `docs/adr/0001-baseline.md`** from `templates/adr-0001-baseline.md`. Fill the sections honestly:
   - Project purpose — from README.
   - Stack — concrete versions, not generic labels.
   - Top-level layout.
   - **Capabilities** — what the surface shows the repo can do. Conservative.
   - **Implicit decisions worth ratifying** — choices visible in config that aren't written down (deploy target, ORM, SSR mode, multi-locale). Each gets a "proposed follow-up ADR" line.
   - **Detected gaps / opportunities** — from smell tests. Each maps to a candidate task slug.
7. Update `docs/adr/README.md` index with `- [0001 Baseline](0001-baseline.md) — {{one-line summary}}`.
8. Do not auto-create follow-up tasks. List them as **suggestions** in the final output.
9. **Final output** — value-dense, scannable. Use this shape:

   ```
   project-ledger initialized

   Created:
   • docs/adr/0001-baseline.md
   • docs/adr/README.md
   • .claude/tasks/{open,closed}/
   • .gitignore: added .claude/   (or "already present")

   Detected N things worth knowing:
   • [implicit decision] {short rule} — propose new ADR?
   • [gap]              {what's missing} — suggested task: {slug}
   • [opportunity]      {what could be wired up cheaply}
   • ...

   Next:
   1. Review docs/adr/0001-baseline.md (≈ 2 min read)
   2. Decide which implicit decisions to ratify (`adr new <slug>`)
   3. Open tasks for the gaps that matter (`task new <slug>`)
   ```

10. Do not stage or commit.

### Smell tests (no extra reads — operate only on data already in context)

Add each finding to the "Detected gaps / opportunities" section of ADR-0001 and to the final output. If a test has no signal, skip silently.

| Test | Signal | Finding tag |
|---|---|---|
| Multiple lockfiles | 2+ of `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb` | `[gap]` Mixed lockfiles — `standardize-pkg-mgr` |
| No CI workflow | `.github/workflows/` empty/absent (and no `.circleci/`, `.gitlab-ci.yml`) | `[gap]` No CI detected — `bootstrap-ci` |
| Test runner without script | dep on `vitest`/`jest`/`mocha`/`pytest`/`playwright` but no `test` script | `[opportunity]` Runner installed, no `test` script — `wire-up-tests` |
| Env not documented | dep that loads `.env` (dotenv/framework) but no `.env.example` | `[gap]` `.env.example` missing — `document-env-vars` |
| Linter absent | no `eslint`/`biome`/`ruff`/`golangci-lint` and no `lint` script | `[opportunity]` No linter wired — `add-linter` |
| TS without strict | `tsconfig.json` present and `strict: false`/missing | `[opportunity]` TS not strict — `tighten-tsconfig` |
| SSR adapter | Astro/Next has `output: 'server'`/`'standalone'` + adapter | `[implicit decision]` Deploy locked to {{adapter}} — propose ADR |
| ORM in deps | `drizzle-orm`/`prisma`/`typeorm`/`mongoose` present | `[implicit decision]` Persistence via {{orm}} — propose ADR |
| AI/LLM SDK in deps | `@anthropic-ai/sdk`/`openai`/`@langchain/*`/`@google/genai` present | `[implicit decision]` LLM strategy — propose ADR |
| Multi-locale visible | `src/locales/` or `src/i18n/` with 2+ files | `[implicit decision]` Multi-locale setup — propose ADR |

Each is a 1-line judgment from data already in context. If running a smell test requires a new read, skip it — budget matters more than completeness.

### Anti-bloat rules for init

- Do **not** read any file under `src/**` beyond a single top-level `ls`.
- Do **not** infer module architecture from filenames — that belongs to a later task, not baseline.
- Do **not** open more than 2 config files. Stop at the most relevant for the detected stack.
- Do **not** generate more than 5 smell findings in the output. If more exist, list the top 5 and put the rest as a brief note inside the ADR.
