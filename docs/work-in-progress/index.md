# Work in progress

This directory holds **non-authoritative** working documents: implementation plans and discovery notes. Nothing here is a rule or a spec — the authoritative sources are the root [CLAUDE.md](../../CLAUDE.md) and the rest of [docs/](../index.md). When a plan is implemented, the durable outcome moves into `CLAUDE.md`/`docs/`; the plan itself stays here as a record.

## What lives here

- **Plans** and **discovery docs**, paired by stem (e.g. `foo-discovery.md` → `foo-plan.md`).
- Filenames must contain `plan` or `discovery` (this is how the skills find them).
- Plans may also live in `docs/personal/` or `.claude/plans/`; this directory is the default.
- An optional **task queue** at `tasks.md` — an ordered list of work, highest priority first, one `## N. Title` heading per entry. It is exempt from the naming rule above because the two skills that read it look for it by name. To call it something else, name that file as the queue in a `CLAUDE.md`; the skills read `CLAUDE.md` before they go looking, and a pointer there wins over a filename match.

## Lifecycle

State each doc's status at the top:

1. **Draft** — being written or discovered; decisions still open.
2. **In progress** — approved and being executed phase by phase.
3. **Implemented** — done; kept for history. Fold any lasting rule/concept into `CLAUDE.md`/`docs/` before closing out.

## Skills

- `scope` — interviews to surface decisions, writes a discovery doc here.
- `make-plan` — turns a task (and any discovery doc) into a phased plan here.
- `execute-plan` — reads a plan from here and runs it phase by phase.
- `next-task` — takes one entry from `tasks.md`, has a context-free subagent check the entry still stands against current code before any work starts, implements it, then has a second one validate before the entry is removed. Blocked entries are worked question by question, or marked and skipped in autonomous mode.
- `work-queue` — loops `next-task` in autonomous mode, one entry per fresh subagent, committing each closed entry. Faults recover rather than ending the run, and nothing is discarded to recover.

`execute-plan` and `next-task` are not the same tool: a plan is one piece of work broken into phases you check off, a queue is many independent pieces of work that each need re-checking because the code moved under them.

See also: [docs index](../index.md).
