# CLAUDE.md

Operating manual for this personal monorepo. Rules live here; rationale lives in [docs/](docs/index.md). Per-area `CLAUDE.md` files defer to this one.

## Documentation-First Rule

Before touching an area, read in this order: [docs/index.md](docs/index.md) → the area index (`docs/<area>/index.md`) → the code. Docs are Diátaxis-structured per area:

- `explanation/` — why/rationale/decisions.
- `how-to/` — numbered, prerequisite-gated task steps with a Verification section.
- `reference/` — austere lookup tables; each area may have a `dictionary.md`.

Docs cover what code cannot show (architecture, decisions, conventions, gotchas). Do not restate code in docs.

## Keep Documentation Updated

After any change, `grep` `docs/` for the area you touched and fix stale docs in the same change. A new **rule** goes in a `CLAUDE.md`; a new **concept** goes in `docs/`. Never let code and docs drift.

## Markdown Line Wrapping

Do NOT hard-wrap prose in `CLAUDE.md` or `docs/`. Write each paragraph, list item, or table row as a single physical line and let it soft-wrap in the editor — never insert manual line breaks to hit a column width. Fenced code blocks keep their own line breaks.

## Memory Policy

Do NOT rely on private or session memory for durable rules. Anything that must persist belongs in checked-in `CLAUDE.md`, `docs/`, or `.claude/skills/`. If you learn a rule mid-task, write it down here or in docs before finishing.

## Repository Layout

| Area | What | Docs |
|------|------|------|
| `homelab/` | Talos + Flux GitOps k8s, one cluster `tom`. | [homelab/CLAUDE.md](homelab/CLAUDE.md), [docs/homelab/](docs/homelab/index.md) |
| `terminal/` | Portable zsh/starship dotfiles + `install.sh` bootstrap + CI. | [terminal/CLAUDE.md](terminal/CLAUDE.md), [docs/terminal/](docs/terminal/index.md) |
| `raycast-scripts/` | macOS + Windows Raycast launchers for the `tdo` CLI. | [docs/raycast/](docs/raycast/index.md) |
| `scripts/` | Repo tooling (e.g. `add-yaml-markers.sh`), run by CI. | [docs/general/reference/ci.md](docs/general/reference/ci.md) |

## Commit & PR Conventions

- Commit messages: imperative one-liners — `add X`, `fix Y`, `update Z`.
- NEVER add `Co-Authored-By` or "Generated with Claude" attribution. History stays authored by the human.
- NEVER force-push.
- PRs target `main` and are **draft by default**.
- Exception: Flux pushes `image-automation-<cluster>-<app>` branches that CI turns into auto-PRs — see [docs/general/reference/ci.md](docs/general/reference/ci.md).

## YAML & Formatting

- Every hand-authored `homelab/**/*.yaml` starts with a `---` document marker and is prettier-formatted: 2-space indent, single quotes, no trailing commas.
- CI auto-fixes both on PRs; do not fight it.
- Exempt: `flux-system/`, `talos/`, `terraform/`.
- Details and rationale: [docs/general/reference/conventions.md](docs/general/reference/conventions.md).

## Secrets

- NEVER commit Talos `secrets.yaml`, `talosconfig`, or generated node configs (`controlplane*.yaml`, `worker*.yaml`), `**/id_rsa`, or any real secret.
- Cluster secrets are delivered via 1Password + the External Secrets Operator, not checked into git.

## Checks & Verification

| Purpose | Command |
|---------|---------|
| Terminal install test (clean container) | `sh terminal/test.sh` |
| Terminal assertions | `sh terminal/verify.sh` |
| Shell lint | `shellcheck --severity=warning terminal/install.sh terminal/test.sh terminal/verify.sh` |
| Homelab (no test suite) | verify on the live cluster with `flux get kustomizations` |

## Plans

Plans and discovery docs live in `docs/work-in-progress/` (default), `docs/personal/`, or `.claude/plans/`. The filename must contain `plan` or `discovery`. Use the `make-plan`, `execute-plan`, and `discover` skills to read/write them.

---

Start at [docs/index.md](docs/index.md).
