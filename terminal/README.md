# terminal

Portable zsh setup — starship prompt, autosuggestions, syntax highlighting, a
collapsing (transient) prompt, and async prompt rendering. No oh-my-zsh, no
brew required. Bootstraps a fresh Linux, macOS, or WSL machine with one command.

## Bootstrap a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/dloez/dloez/main/terminal/install.sh | sh
```

Then restart your shell (`exec zsh`), or log out and back in to pick up the new
default shell.

## What it does

`install.sh` is idempotent — safe to re-run any time — and emits only its own
`==>` progress lines (underlying command output is captured and shown only on
failure). It:

1. Installs any missing dependencies (`git`, `curl`, `zsh`) via the system
   package manager (`apt`, `dnf`, `pacman`, `zypper`, `apk`, or Homebrew),
   using `sudo` when it isn't run as root.
2. Installs [starship](https://starship.rs) into `~/.local/bin` if missing.
3. Clones/updates the zsh plugins into `~/.local/share/zsh/plugins`.
4. Symlinks each config file below into its canonical location, backing up any
   pre-existing real file to `<file>.bak.<timestamp>`.
5. Sets zsh as the default login shell (`chsh`), if it isn't already.
6. On WSL, sets up the font and terminal on the Windows host (see below).

When run via `curl`, it first clones this repo to `~/.local/share/dloez` and
links from there. When run from an existing checkout (e.g.
`sh terminal/install.sh`), it links directly from that checkout, so edits to a
config file are live in your shell immediately.

## WSL extras

When it detects WSL (and Windows interop is available), `install.sh` also
configures the Windows host so the prompt renders correctly:

- Installs the **JetBrainsMono Nerd Font** per-user (no admin/UAC prompt) if it
  isn't already present.
- Points Windows Terminal's WSL profile at that font, backing up
  `settings.json` first.

This step self-skips on non-WSL systems and never aborts the rest of the setup.

## Async prompt

starship's stock init re-runs starship synchronously on every prompt draw
(~40ms in any git repo, 100ms+ on cold caches). `zsh/async-prompt.zsh` splits
that into an instant git-less first paint (`starship-fast.toml`, ~5-15ms) and a
background full render that swaps git info in via `zle reset-prompt` — same
layout, no jump, and the shell is typeable immediately.

Measure before/after with `zsh terminal/benchmark.sh <label>` (requires
[hyperfine](https://github.com/sharkdp/hyperfine)); results land in
`terminal/bench-results/<label>.md`.

## Layout

`config/` mirrors `$HOME`. Each file is symlinked **individually** (never whole
directories), so any unmanaged dotfile you add alongside them stays independent
and untracked.

| Repo file | Symlinked to |
|-----------|--------------|
| `config/zshrc` | `~/.zshrc` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `config/starship-fast.toml` | `~/.config/starship-fast.toml` |
| `config/zsh/cursor.zsh` | `~/.config/zsh/cursor.zsh` |
| `config/zsh/perf.zsh` | `~/.config/zsh/perf.zsh` |
| `config/zsh/async-prompt.zsh` | `~/.config/zsh/async-prompt.zsh` |
| `config/zsh/transient-prompt.zsh` | `~/.config/zsh/transient-prompt.zsh` |

## Testing

`test.sh` runs `install.sh` in a clean `ubuntu:24.04` Docker container and
asserts the result with `verify.sh` (deps present, starship + plugins + all
symlinks in place, zsh is the default shell, the config sources cleanly, and a
second run is idempotent):

```sh
sh terminal/test.sh
```

The `Test terminal install` GitHub workflow (`.github/workflows/test-install.yaml`)
runs on push (when `terminal/**` changes), daily, and on demand:

- **lint** — `shellcheck` on the shell scripts.
- **ubuntu-test** — the container test above.
- **macos-test** — `install.sh` + `verify.sh` on a `macos-latest` runner
  (schedule and manual only, since macOS can't run in a container).
