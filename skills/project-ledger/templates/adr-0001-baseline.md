# ADR-0001: Baseline — what this repository is and is capable of

- **Status:** Accepted
- **Date:** {{YYYY-MM-DD}}
- **Source:** Initial bootstrap (no preceding task)

## Context

This is the foundational record for the repository. Future ADRs reference this as the starting point. It documents what the project does, the stack it sits on, and the capabilities visible at the surface — not an audit of the source code.

## Project purpose

{{1-3 sentences: what this repo is for, who consumes it, what problem it solves. Pull from README.md if present.}}

## Stack (surface)

- **Language / runtime:** {{e.g. Node 22, Python 3.12}}
- **Primary framework(s):** {{from package.json or equivalent}}
- **Storage:** {{databases, KV, etc — only if obvious from manifests}}
- **External services:** {{detected from deps, e.g. Supabase, Stripe — high-confidence only}}
- **Deploy target:** {{detected from config files, e.g. AWS Amplify, Vercel, Docker}}

## Repository layout (top-level only)

```
{{tree of top-level dirs/files with one-line annotation each}}
```

## Capabilities (visible from the surface)

- {{Bullet of a thing the repo can do, supported by an entry-point file or manifest. Be conservative — only list what's evident without deep code reading.}}
- {{...}}

## Known integrations

- {{Adapter / SDK / external API that's clearly wired in. Skip speculative ones.}}

## Implicit decisions worth ratifying

Choices visible in the project's config but not written down in an ADR. These are *de facto* decisions that should be ratified (or revisited) explicitly. Each one is a candidate for a follow-up ADR.

- **{{Topic — e.g. "Deploy target"}}**: {{what the config shows — e.g. "Astro `output: 'server'` + `astro-aws-amplify` adapter → SSR on AWS Amplify"}}. Suggested ADR: `{{slug, e.g. "ratify-deploy-target-amplify"}}`.
- **{{Topic — e.g. "Persistence layer"}}**: {{what's wired — e.g. "Drizzle ORM + Postgres via `drizzle-orm` dep"}}. Suggested ADR: `{{slug}}`.
- {{... drop section entirely if no implicit decisions detected ...}}

## Detected gaps and opportunities

From smell tests run during init (no deep code analysis). Each one maps to a candidate task; the user decides which are worth opening.

- `[gap]` {{what's missing — e.g. "Mixed lockfiles: package-lock.json + pnpm-lock.yaml present"}}. Suggested task: `{{slug, e.g. "standardize-pkg-mgr"}}`.
- `[opportunity]` {{cheap improvement — e.g. "Vitest in deps but no `test` script in package.json"}}. Suggested task: `{{slug}}`.
- {{... drop section entirely if no smells fired ...}}

## What this baseline does **not** cover

- Internal architecture and module boundaries (those come in later ADRs as decisions accumulate).
- Code quality, test coverage, performance characteristics.
- Decisions that have not yet been written down — assume undocumented choices may be revisited.

## Consequences

**Positive:**
- New contributors (human or agent) have a starting point.
- Future ADRs can reference this as ADR-0001 without restating context.
- Implicit decisions are now visible — the team can choose to ratify or change them.

**Negative:**
- Some capabilities listed here may be inaccurate if the surface doesn't reflect reality. Correct in a follow-up ADR if discovered.
- Smell-test detections are heuristics — a few will be false positives. Ignore the ones that don't apply.

**Follow-ups:**
- One follow-up per item in "Implicit decisions worth ratifying" and "Detected gaps and opportunities" (user opens via `task new` or `adr new`).
