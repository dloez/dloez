# Documentation

Docs for the `dloez/dloez` personal monorepo. Rules and workflow live in the root [CLAUDE.md](../CLAUDE.md); this tree explains the *why* and provides lookup reference. Default branch: `main`.

## Documentation system

Docs follow [Diátaxis](https://diataxis.fr/), split per area into three kinds:

- **explanation/** — rationale, decisions, background.
- **how-to/** — numbered steps with prerequisites and a Verification section.
- **reference/** — austere lookup tables and dictionaries.

Docs cover what code cannot: architecture, decisions, conventions, and gotchas.

## Homelab

Talos + Flux GitOps Kubernetes, one cluster (`tom`).

| Document | Type | Description |
|----------|------|-------------|
| [homelab/index.md](homelab/index.md) | Index | Overview of the homelab area and its docs. |
| [homelab/explanation/architecture.md](homelab/explanation/architecture.md) | Explanation | How Talos, Flux, and the cluster layout fit together, and why. |
| [homelab/how-to/bootstrap-cluster.md](homelab/how-to/bootstrap-cluster.md) | How-to | Stand up the `tom` cluster from bare Talos nodes to a reconciling Flux install. |
| [homelab/reference/dictionary.md](homelab/reference/dictionary.md) | Reference | Terms, hostnames, IPs, and paths used across the homelab. |

## Terminal

Portable zsh/starship dotfiles, a one-command bootstrap, and CI.

| Document | Type | Description |
|----------|------|-------------|
| [terminal/index.md](terminal/index.md) | Index | Overview of the terminal area and its docs. |
| [terminal/explanation/async-prompt.md](terminal/explanation/async-prompt.md) | Explanation | Why the prompt renders in two passes (pure-zsh first paint + background git). |
| [terminal/explanation/wsl-host-setup.md](terminal/explanation/wsl-host-setup.md) | Explanation | Why and how bootstrap touches the Windows host under WSL. |
| [terminal/reference/layout-and-testing.md](terminal/reference/layout-and-testing.md) | Reference | Config-to-`$HOME` symlink map and the test/verify commands. |
| [terminal/how-to/bootstrap-machine.md](terminal/how-to/bootstrap-machine.md) | How-to | Bootstrap a fresh Linux/macOS/WSL machine. |

## Raycast

macOS + Windows Raycast launchers for the `tdo` CLI.

| Document | Type | Description |
|----------|------|-------------|
| [raycast/index.md](raycast/index.md) | Index | Overview of the Raycast launcher scripts. |

## General

Repo-wide conventions and CI, shared by every area.

| Document | Type | Description |
|----------|------|-------------|
| [general/reference/conventions.md](general/reference/conventions.md) | Reference | Commit/PR style, YAML markers + prettier, and the secrets policy. |
| [general/reference/ci.md](general/reference/ci.md) | Reference | The three GitHub workflows and their gotchas. |

## Work in progress

| Document | Type | Description |
|----------|------|-------------|
| [work-in-progress/index.md](work-in-progress/index.md) | Index | Non-authoritative plans and discovery docs, and their lifecycle. |
