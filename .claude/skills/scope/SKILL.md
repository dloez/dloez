---
name: scope
description: Interview the user one question at a time to surface every decision behind a feature or concept before /make-plan runs. Walks the design tree branch-by-branch, resolves dependencies between decisions, explores the codebase whenever a question is answerable from code, and provides a recommended answer for every question. Saves a discovery doc that /make-plan picks up as Context. Also runs in audit mode when invoked with an existing plan file (e.g. `/scope grafana-plan.md`) — checks the plan against the anchor checklist, asks about gaps, and reports mismatches without editing the plan. TRIGGER when the user says "scope", "scope this out", "interview me", "let's figure out X", wants to nail down a feature's design before planning, or wants to audit an existing plan for unaddressed branches. SKIP for trivial single-file changes, bug fixes, or when the user has already specified the design in detail.
---

# /scope

Resolve every decision behind a feature before any plan is drafted. No silent product calls, no assumed defaults.

1. **Read docs first** — the repo's `CLAUDE.md`/docs if it has them, then the code. Note paths for the doc's References.

2. **Cover every anchor area** before declaring done — each gets a resolved decision OR an explicit "not applicable" with reasoning. Adapt the specifics to the repo's stack (read its docs first):
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

   In this monorepo, map these to the area you're in: **homelab** → which Kustomizations/HelmReleases/manifests, Flux `dependsOn` & reconcile order, 1Password/ESO secrets, ingress/DNS/certs, `flux` events; **terminal** → POSIX-sh portability, individual symlinks, macOS vs Linux, idempotent re-runs.

   Order isn't fixed — walk where dependencies lead. If the user calls it early, flag unresolved anchors so they choose with eyes open.

3. **Interview loop, one question at a time:**
   - **Codebase first.** If the answer is in code, read it instead of asking. State the finding, move on.
   - **Always recommend.** Every question carries your recommended answer + one-sentence rationale + named alternative. No bare questions.
   - Use `AskUserQuestion` when the answer space is enumerable, plain text otherwise.
   - Product decisions (what it DOES, defaults, behavior, scope) MUST be asked. Technical decisions (structure, reuse, file layout) you propose; user confirms.

4. **Save the doc.** Ask location via `AskUserQuestion`. Prefer a location the repo already defines for plans/discovery; in this monorepo that's `docs/work-in-progress/` (default), `.claude/plans/` (fallback), or `docs/personal/` (only if the user calls it "my" doc). In a repo with no such convention, default to `.claude/plans/`. Filename MUST contain `discovery`; pair with the eventual plan stem (e.g. `grafana-discovery.md` ↔ `grafana-plan.md`). Group resolved decisions by anchor area, each as Q/A/Why.

5. **Hand off — do NOT auto-invoke /make-plan.** End with a one-paragraph summary and a pointer to the doc.

# Audit mode

Triggered when invoked with an existing plan file (filename contains `plan`). Read the plan in full first.

- Treat every phase as a **proposition to test**, not a settled fact. Coverage ≠ correctness. For each phase, note its implicit assumptions and the alternatives it implicitly rejected.
- Challenge every phase, don't just check coverage.
- Save as `<plan-stem>-audit-discovery.md` (confirm filename).
- Final summary in three buckets:
  - **Gaps** — anchor areas the plan omits.
  - **Unverified assumptions** — claims without justification.
  - **Phases to reconsider** — approach is wrong/suboptimal given resolved decisions.
- **Do not edit the plan.** The user decides what to revise.
