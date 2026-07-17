---
name: make-plan
description: Create a structured implementation plan broken into vertical-slice phases with to-do lists, saved to .claude/plans/, docs/work-in-progress/, or docs/personal/ (filename must contain "plan"). TRIGGER when the user asks to plan a task, design an approach, break a feature into phases, or propose an implementation before coding. SKIP for trivial single-file changes or bug fixes.
---

# /make-plan

Convert resolved context into a vertical-slice plan. **Never ask the user mid-flow** — that's `/discover`'s job. Anything you can't resolve from a discovery doc, the codebase, the docs, or your own technical judgment goes in the plan's **Open questions — delegated to /discover** section, never in a chat reply.

## Process

1. **Discovery doc.** If the user named one (`/make-plan grafana-discovery.md`), read it. Otherwise: `find docs/work-in-progress docs/personal .claude/plans -maxdepth 2 -type f -name '*discovery*.md' 2>/dev/null` — if a single match clearly relates to this task, read it. Treat its **Resolved decisions** as authoritative; copy its **Open questions** and **References** into the plan.

2. **Read docs + code** per CLAUDE.md (Documentation-First Rule).

3. **Identify surfaces in scope** — Kustomizations/HelmReleases/manifests, reconciliation & dependency ordering, secrets & config, ingress/DNS, shell scripts/dotfiles, idempotency & rollback, host/OS portability. List in Context.

4. **Blind-spot sweep.** Walk `/discover`'s anchor checklist (scope edges, manifests/apps changed, reconciliation & dependency ordering, secrets & config, ingress/DNS, reuse, idempotency & rollback, host/OS portability, observability). Resolve each via discovery doc → code/docs → your technical judgment. Product decisions still unresolved → list under "Open questions — delegated to /discover" with a placeholder in the plan body so phases stay concrete. Technical questions are yours; resolve them.

5. **Pick save location** (no asking):
   - `docs/work-in-progress/` (default) · `docs/personal/` (only if user called it "my plan") · `.claude/plans/` (fallback).
   - Filename MUST contain `plan` (e.g. `grafana-plan.md`). No `plans/` subdirectory.

## Plan structure

- **Goal** — brief description.
- **Context** — docs read, key files, public contracts in scope, resolved decisions.
- **Open questions — delegated to /discover** — unresolved product decisions, each naming what's at stake. Write "None — all decisions resolved" if empty; the section is always present so absence never reads as "I forgot to check".
- **Phases** — vertical slices (see below), each with:
  - **Description** — the new behavior delivered end-to-end.
  - **To-do list** — checkbox actions.
  - **Acceptance criteria** — see below.
- **Documentation to update** — docs to write/edit once all phases ship.
- **Next step** — one sentence: which phase to start, or "Run `/discover` on this plan to resolve open questions before executing."

## Vertical slices (non-negotiable)

A phase = **one new piece of behavior exercisable end-to-end through whatever surface the task touches** — a reconciled Flux resource, a `flux`/`kubectl` check, an app answering on its ingress, a running shell script, an installed symlink. The slice spans every layer the *task itself* touches. Homelab-only changes end at a reconciled, healthy resource on the cluster; terminal-only tweaks end at the installed/verified dotfile. Every phase must be committable and pushable without breaking reconciliation or the installer.

**Horizontal phases are forbidden** — don't ship "the schema half", "the API half", "the UI half" as separate phases.

Red flags:
- A phase titled "schema", "types", "wiring", or "scaffolding" with no exercisable behavior.
- No human-run acceptance check because nothing observable changed.
- One phase produces a contract; a later phase produces its only caller.

Fix by starting from the thinnest end-to-end happy path and growing it.

**Example — "add Grafana to cluster tom":**
- ✓ Vertical: P1 = HelmRepository + HelmRelease + namespace so Grafana reconciles and the pod comes up healthy · P2 = Ingress + DNS so it's reachable · P3 = provisioned dashboards/datasources.
- ✗ Horizontal: P1 = namespace · P2 = HelmRepository · P3 = HelmRelease · P4 = Ingress. Nothing is reachable until P4.

**Nesting:** at most one level (e.g. Phase 4 and Phase 4 post). No 4a/4b/4c — if you want a second sub-phase, the parent was too big; split into top-level phases.

## Acceptance criteria (required per phase)

Vague criteria are the main reason phases get declared done on shallow checks. Each phase MUST list:

- **Claude-run checks** — exact commands/greps for structural correctness, matched to the area you touched. Examples: homelab — `flux build kustomization <name> --path <dir>` succeeds, `kubeconform` passes, `prettier --check <files>` passes and every hand-authored manifest starts with a leading `---`; terminal — `sh terminal/test.sh` and `sh terminal/verify.sh` pass, `shellcheck --severity=warning terminal/*.sh` is clean; read-back of a file to confirm an existing manifest/base/helper is reused rather than re-implemented.
- **Human-run checks** — exact live/manual steps (e.g. `flux get kustomizations` shows the resource Ready, `flux reconcile kustomization <name>`, the app answers on its ingress, a fresh dotfiles install produces the expected symlinks), specific enough that the user doesn't infer the scenario. Checks are area-dependent: homelab has no test suite, so live-cluster verification is the only behavioral check there; terminal has automated tests, so put `sh terminal/test.sh` under Claude-run checks and reserve human-run steps for anything the tests don't cover.
- **Reuse requirements** — existing manifests, bases, or shell helpers that MUST be reused, with paths. Prevents silent re-implementation.
- **Neighbor conventions** — nearest existing module to mirror (e.g. "follow `homelab/apps/tom/pihole.yaml`" for a new app, or an existing function in `terminal/install.sh`). Catches drift from project conventions.
- **Forbidden patterns** — anti-patterns that must not appear in the diff (e.g. a hand-authored manifest missing its leading `---`, `:latest`/unpinned image tags, plaintext secrets committed instead of ESO/1Password references, `TODO`, non-idempotent installer steps).
