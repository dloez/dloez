# Terminal

Portable zsh setup that bootstraps a fresh Linux, macOS, or WSL machine with one command. It provides:

- **starship** prompt (installed to `~/.local/bin`, no package manager needed).
- **zsh-autosuggestions** + **zsh-syntax-highlighting** plugins.
- A collapsing **transient prompt** — past prompts shrink to a bare `❯`.
- **Async prompt rendering** — an instant git-less first paint, then git info swapped in from a background render.

## Design stance

- **No oh-my-zsh.** Plugins are cloned directly and sourced from `~/.zshrc`; no framework overhead.
- **No Homebrew required.** starship installs from its own script; deps come from whatever system package manager is present (`apt`, `dnf`, `pacman`, `zypper`, `apk`, or `brew` if that is what you have).
- **Cross-platform.** One installer covers Linux, macOS, and WSL. On WSL it also configures the Windows host (font + Windows Terminal).
- **Symlinked, not copied.** Each config file is linked individually from the repo, so edits in a checkout are live in your shell.

## Documents

| Document | Type | Covers |
|----------|------|--------|
| [Bootstrap a machine](how-to/bootstrap-machine.md) | How-to | Run the one-command installer and verify the result. |
| [Async prompt design](explanation/async-prompt.md) | Explanation | Why the prompt renders in two paints and how the swap works. |
| [WSL host setup](explanation/wsl-host-setup.md) | Explanation | Why and how the installer configures the Windows host. |
| [Layout and testing](reference/layout-and-testing.md) | Reference | Symlink map and the test/verify/lint/benchmark commands. |

---

Up: [Documentation index](../index.md)
