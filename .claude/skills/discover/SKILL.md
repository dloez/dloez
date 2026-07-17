---
name: discover
description: Interview the user one question at a time to surface every decision behind a feature or concept before /make-plan runs. Walks the design tree branch-by-branch, resolves dependencies between decisions, explores the codebase whenever a question is answerable from code, and provides a recommended answer for every question. Saves a discovery doc that /make-plan picks up as Context. Also runs in audit mode when invoked with an existing plan file (e.g. `/discover grafana-plan.md`) — checks the plan against the anchor checklist, asks about gaps, and reports mismatches without editing the plan. TRIGGER when the user says "discover", "interview me", "grill me", "let's figure out X", wants to nail down a feature's design before planning, or wants to audit an existing plan for unaddressed branches. SKIP for trivial single-file changes, bug fixes, or when the user has already specified the design in detail.
---

# /discover

Resolve every decision behind a feature before any plan is drafted. No silent product calls, no assumed defaults.

1. **Read docs first** per CLAUDE.md, then code. Note paths for the doc's References.

2. **Cover every anchor area** before declaring done — each gets a resolved decision OR an explicit "not applicable" with reasoning:
   - Goal & success — what does "done" look like?
   - Scope edges — what's OUT?
   - Manifests/apps changed — which Kustomizations, HelmReleases, or manifests (homelab), or which shell scripts / dotfiles (terminal), does this touch?
   - Reconciliation & dependency ordering — `dependsOn`, health checks, and apply/reconcile order between Flux resources
   - Secrets & config — 1Password/ESO secrets, ConfigMaps, Helm values, env
   - Ingress/DNS — hostnames, routing, certificates (where applicable)
   - Reuse — which existing manifest, base, or shell helper is the single source of truth?
   - Idempotency & rollback — safe to re-run/re-reconcile; how to revert a change
   - Host/OS portability — POSIX-sh portability, symlinks, macOS vs Linux (terminal)
   - Observability — logs, `flux` events, monitoring

   Order isn't fixed — walk where dependencies lead. If the user calls it early, flag unresolved anchors so they choose with eyes open.

3. **Interview loop, one question at a time:**
   - **Codebase first.** If the answer is in code, read it instead of asking. State the finding, move on.
   - **Always recommend.** Every question carries your recommended answer + one-sentence rationale + named alternative. No bare questions.
   - Use `AskUserQuestion` when the answer space is enumerable, plain text otherwise.
   - Product decisions (what it DOES, defaults, behavior, scope) MUST be asked. Technical decisions (structure, reuse, file layout) you propose; user confirms.

4. **Save the doc.** Ask location via `AskUserQuestion`: `docs/work-in-progress/` (default), `.claude/plans/` (fallback), `docs/personal/` (only if user calls it "my" doc). Filename MUST contain `discovery`; pair with the eventual plan stem (e.g. `grafana-discovery.md` ↔ `grafana-plan.md`). Group resolved decisions by anchor area, each as Q/A/Why.

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
