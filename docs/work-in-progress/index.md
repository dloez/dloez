# Work in progress

This directory holds **non-authoritative** working material: ideas being scoped and built, and a backlog of what belongs to none of them yet. Nothing here is a rule or a spec — the authoritative sources are the root [CLAUDE.md](../../CLAUDE.md) and the rest of [docs/](../index.md).

## Layout

The layout is defined by the `scope` skill (`.claude/skills/scope/SKILL.md`, section "The work-in-progress layout"), not here, so it travels to every repo the skills are installed in without a `CLAUDE.md` describing it. In short:

- [backlog.md](backlog.md) — cross-cutting open questions, one-off tasks, and ideas nobody has scoped yet.
- `<idea>/` — one dir per scoped idea, holding its `discovery.md`, its `tasks.md` work queue, and whatever else the idea needs. A question that belongs to one idea is an entry in that idea's `tasks.md`, not in the backlog.
- No root `tasks.md` and no `open-questions.md`.

An idea dir lives exactly as long as its work: when its last entry closes, its durable outcome is folded into `CLAUDE.md`/`docs/` and the dir is deleted. Git history is the record.

## Skills

- `scope` — interviews to settle every decision behind an idea, then writes its dir: `discovery.md` plus a `tasks.md` of vertical-slice entries with acceptance criteria. Re-run on an existing idea to audit and extend it; on a repo with the old flat layout it offers to migrate.
- `next-task <idea>` — takes one entry from that idea's `tasks.md` (or `backlog`'s tasks), does a quick inline check that it still stands (a few reads, no gate run), implements it, then has a second one validate before the entry is removed. Closes out the idea when its last entry goes.
- `work-queue <idea>` — runs `next-task` in autonomous detached mode over one idea, one entry per fresh subagent and git worktree, with entries whose `**Touches:**` lines do not overlap running side by side. It is the only writer of the queue file, the backlog and the base branch.

Both `next-task` and `work-queue` need the idea named; without it they ask rather than guess.

See also: [docs index](../index.md).
