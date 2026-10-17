---
name: scope
description: Interview the user one question at a time to surface every decision behind a feature or idea, then write it up as an idea dir in the repo's work-in-progress dir — a discovery doc plus a `tasks.md` of vertical-slice entries that /next-task and /work-queue work. Walks the design tree branch-by-branch, resolves dependencies between decisions, explores the codebase whenever a question is answerable from code, and provides a recommended answer for every question. Owns the work-in-progress layout (backlog.md + one dir per idea) for every repo, so no CLAUDE.md has to describe it. Re-running on an existing idea audits and extends it; on a repo with the old flat layout (root tasks.md, open-questions.md) it offers to migrate. TRIGGER when the user says "scope", "scope this out", "interview me", "let's figure out X", "plan X", wants to nail down a feature's design before building, wants an idea turned into tasks, or wants an existing idea's tasks audited. SKIP for trivial single-file changes, bug fixes, or when the user only wants an existing idea's tasks worked (that is /next-task or /work-queue).
---

# /scope

Resolve every decision behind an idea, then leave behind an idea dir whose `tasks.md` `/next-task` and `/work-queue` can work without asking anything the interview already settled. No silent product calls, no assumed defaults.

## The work-in-progress layout

This skill owns the layout below for every repo. `/next-task` and `/work-queue` read it from here, so a repo's `CLAUDE.md` never has to describe it — it only has to say so if it wants a different location.

**Where it lives.** A `CLAUDE.md` naming a work-in-progress dir wins. Otherwise `docs/work-in-progress/`, created on first use.

```
<wip>/
  backlog.md        cross-cutting questions, one-off tasks, unscoped ideas
  <idea>/           one dir per scoped idea, kebab-case slug
    discovery.md    the decisions this skill settled
    tasks.md        the idea's work queue, highest priority first
    ...             anything else the idea needs: notes, findings, sketches
  index.md          optional; a repo's own description of the dir
```

- **No root `tasks.md`, no `open-questions.md`.** Work lives in the idea it belongs to; a question that belongs to one idea is an entry in that idea's `tasks.md` carrying `**Needs the author:**`, next to the work it blocks. Only what belongs to no idea goes in the backlog.
- **`backlog.md`** has three `##` sections, each entry a `###` heading with its text under it:
  - `## Questions` — open decisions that span ideas or belong to none yet. Never resolve one silently in code.
  - `## Tasks` — one-off work too small for an idea. Written like a `tasks.md` entry (below); `/next-task backlog` works them.
  - `## Ideas` — things worth doing that nobody has scoped. `/scope` on one graduates it: the entry leaves the backlog and an idea dir takes its place.
- **An idea dir lives exactly as long as its work.** When its last entry closes, the durable outcome — rules into `CLAUDE.md`, concepts into the docs — is folded in and the dir is deleted; git history is the record. `/next-task` does the close-out.

## 1. Read docs first

The repo's `CLAUDE.md` and docs if it has them, then the code. Read `backlog.md` and the existing idea dirs: an open question there may already be part of this idea, and an existing idea may already own this ground — extend it rather than starting a second one. Note paths for the discovery doc's References.

**Old flat layout.** If the wip dir has a root `tasks.md` or `open-questions.md`, say so and offer to migrate before anything else: each entry or question goes to the idea that owns it — creating idea dirs as needed, with the user confirming each new slug — or to the backlog if none does, and discovery docs move into their idea's dir as `discovery.md`. Show the mapping and get a yes before moving anything. If the user declines, scope this idea into the new layout anyway and leave the old files alone.

## 2. Cover every anchor area

Before declaring done, each area gets a resolved decision OR an explicit "not applicable" with reasoning. Adapt the specifics to the repo's stack:

- Goal & success — what does "done" look like?
- Scope edges — what's explicitly OUT?
- Surfaces changed — which components / services / files does this touch?
- Dependencies & ordering — what must exist or run first; ordering, health/readiness between parts.
- Data, secrets & config — secret handling, config/env, data or schema migrations.
- Interfaces & integration — APIs, routing/ingress, DNS, external systems (where applicable).
- Reuse — which existing module, base, or helper is the single source of truth?
- Idempotency & rollback — safe to re-run; how to revert a change.
- Portability & environment — OS/runtime/platform assumptions.
- Observability — logs, metrics, events, monitoring.
- Verification — what the repo's gate is, and what only a human can check (a live cluster, a UI, real hardware).

Order isn't fixed — walk where dependencies lead. If the user calls it early, flag unresolved anchors so they choose with eyes open; each one left open becomes a `**Needs the author:**` entry, never a silent default.

## 3. Interview loop, one question at a time

- **Codebase first.** If the answer is in code, read it instead of asking. State the finding, move on.
- **Always recommend.** Every question carries your recommended answer + one-sentence rationale + named alternative. No bare questions.
- Use `AskUserQuestion` when the answer space is enumerable, plain text otherwise.
- Product decisions (what it DOES, defaults, behavior, scope) MUST be asked. Technical decisions (structure, reuse, file layout) you propose; user confirms.

## 4. Write the idea dir

Propose the slug (`grafana`, `rate-limit`) and confirm it with the user unless they named it. Then write:

**`discovery.md`** — Goal, resolved decisions grouped by anchor area (each as Q/A/Why), scope edges, and References (docs and code read).

**`tasks.md`** — one `##` heading per entry, highest priority first, order carried by position (no numbering). Each entry is a vertical slice:

```
## <imperative heading: the behavior delivered>

<What changes and why, linking discovery.md sections rather than repeating them.>

**Do:**
- [ ] <action>

**Acceptance:**
- Claude-run: <exact commands/greps — the repo's gate, builds, lints, a read-back proving reuse>
- Human-run: <exact live/manual steps, specific enough that the user doesn't infer the scenario>
- Reuse: <existing modules/bases/helpers that MUST be used, with paths>
- Neighbors: <nearest existing module to mirror>
- Forbidden: <anti-patterns that must not appear in the diff>

**Touches:** `<path>`, `<dir>/`
**After:** <heading of an entry that must land first>
```

The `**Touches:**` / `**After:**` lines follow `/next-task`'s scheduling-lines section; leave `**After:**` out when there is none. Acceptance lines that do not apply say `none` rather than disappearing, so absence never reads as "forgot to check". Every product decision the interview left open is its own entry carrying `**Needs the author:**` with the question under it, placed above the work it blocks, and that work names it in `**After:**`.

**Vertical slices, non-negotiable.** An entry delivers one new piece of behavior exercisable end-to-end through whatever surface the idea touches — a reconciled resource, an endpoint answering, a script that runs, an installed symlink — and spans every layer the idea itself touches. Each entry must be committable on its own without breaking the build, the deploy or the installer. Horizontal entries are forbidden: no "the schema half", "the API half", "the UI half". Red flags: a heading like "schema", "types", "wiring" or "scaffolding"; no human-run check because nothing observable changed; one entry producing a contract whose only caller is a later entry. Fix by starting from the thinnest end-to-end happy path and growing it.

*Example — "add Grafana":* ✓ chart + namespace so the pod comes up healthy → ingress + DNS so it is reachable → provisioned dashboards. ✗ namespace → chart repo → release → ingress, where nothing is reachable until the last entry.

**Size.** An entry is one `/next-task` pass. If it would fill a context before closing, split it now.

**Backlog.** Remove any `## Ideas` entry this idea graduated, and move any `## Questions` entry it now owns into its `tasks.md` (or drop it, if the interview settled it). Questions it raised that belong to no idea go into the backlog's `## Questions`. Update the wip `index.md` if the repo keeps one that lists ideas.

## 5. Hand off

Do NOT start working the tasks. End with a one-paragraph summary, the path to the idea dir, the entry count with how many need the author, and the next command: `/next-task <idea>` or `/work-queue <idea>`.

# Audit mode

Triggered when invoked on an existing idea (`/scope grafana`). Read `discovery.md` and `tasks.md` in full first.

- Treat every entry as a **proposition to test**, not a settled fact. Coverage ≠ correctness. For each, note its implicit assumptions and the alternatives it implicitly rejected; check it against the anchor checklist, the vertical-slice rule and the acceptance shape above.
- Interview on the gaps as in step 3.
- Final summary in three buckets: **Gaps** (anchor areas no entry covers), **Unverified assumptions**, **Entries to reconsider**.
- Show the proposed changes to `discovery.md` and `tasks.md` and apply them only on the user's yes. Never touch an entry carrying `**Attempted once:**` without saying so.
