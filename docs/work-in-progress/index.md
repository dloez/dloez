# Work in progress

This directory holds **non-authoritative** working documents: implementation plans and discovery notes. Nothing here is a rule or a spec — the authoritative sources are the root [CLAUDE.md](../../CLAUDE.md) and the rest of [docs/](../index.md). When a plan is implemented, the durable outcome moves into `CLAUDE.md`/`docs/`; the plan itself stays here as a record.

## What lives here

- **Plans** and **discovery docs**, paired by stem (e.g. `foo-discovery.md` → `foo-plan.md`).
- Filenames must contain `plan` or `discovery` (this is how the skills find them).
- Plans may also live in `docs/personal/` or `.claude/plans/`; this directory is the default.

## Lifecycle

State each doc's status at the top:

1. **Draft** — being written or discovered; decisions still open.
2. **In progress** — approved and being executed phase by phase.
3. **Implemented** — done; kept for history. Fold any lasting rule/concept into `CLAUDE.md`/`docs/` before closing out.

## Skills

- `scope` — interviews to surface decisions, writes a discovery doc here.
- `make-plan` — turns a task (and any discovery doc) into a phased plan here.
- `execute-plan` — reads a plan from here and runs it phase by phase.

See also: [docs index](../index.md).
