# Layout and testing

## Symlink map

`config/` mirrors `$HOME`. Each file is symlinked **individually** (never whole directories), so any unmanaged dotfile alongside them stays independent.

| Repo file | Symlinked to |
|-----------|--------------|
| `config/zshrc` | `~/.zshrc` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `config/starship-fast.toml` | `~/.config/starship-fast.toml` |
| `config/zsh/cursor.zsh` | `~/.config/zsh/cursor.zsh` |
| `config/zsh/perf.zsh` | `~/.config/zsh/perf.zsh` |
| `config/zsh/completion.zsh` | `~/.config/zsh/completion.zsh` |
| `config/zsh/history-search.zsh` | `~/.config/zsh/history-search.zsh` |
| `config/zsh/async-prompt.zsh` | `~/.config/zsh/async-prompt.zsh` |
| `config/zsh/transient-prompt.zsh` | `~/.config/zsh/transient-prompt.zsh` |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` |

`fzf` is not symlinked: the installer downloads its binary to `~/.local/bin/fzf` (alongside starship) and `zshrc` sources `fzf --zsh` at startup when the binary is present. See [Interactive features](interactive-features.md).

`herdr` follows the same split: only its `config.toml` is symlinked; the binary is downloaded to `~/.local/bin/herdr` via the official `herdr.dev/install.sh` (with `HERDR_INSTALL_DIR` pinned to `~/.local/bin`), and herdr's own runtime files (sockets, logs, `session.json`) live unmanaged alongside the linked config in `~/.config/herdr/`.

`~/.zshenv` is the one managed file that is **appended to, not symlinked** — the installer adds `skip_global_compinit=1` to it (creating it if absent), preserving any existing content such as rustup's `. "$HOME/.cargo/env"`. It must be sourced before `/etc/zsh/zshrc`, which a symlink of a repo file could not guarantee without clobbering the user's own `~/.zshenv`. See [Startup performance](../explanation/startup-performance.md).

## Neovim + kickstart

As part of the default setup, the installer downloads a recent Neovim release into `~/.local` (symlinking `~/.local/bin/nvim`, skipped if a nvim >= 0.11 is already present) and clones the personal kickstart fork [`dloez/kickstart.nvim`](https://github.com/dloez/kickstart.nvim) into `~/.config/nvim` **only if that directory is absent** (an existing config is left untouched).

The fork carries the customizations directly, so nothing is layered in at install time. `init.lua` stays byte-for-byte upstream and changes live in `after/plugin/*.lua` (overrides) and `lua/custom/plugins/*.lua` (new plugins), so `git merge upstream/master` never conflicts. The keylogger (`plugin/learning.lua`) and journal template ship in the fork too, dormant until the learning loop is enabled (below).

## Claude Code setup (opt-in)

On request the installer wires up the Claude Code layer. This is **opt-in**: `install.sh` prompts once (reading from `/dev/tty`), or runs without prompting when `INSTALL_CLAUDE=1` is set; with no tty and no env var it is skipped. It covers two things, and grows as more Claude tooling is added:

- **Skills** — symlinks each skill listed in `.claude/skills/essential-skills.txt` (one directory name per line) into `~/.claude/skills/<name>`, reusing the individual-symlink, back-up-on-conflict logic of the config files. Edit that list to change which skills are promoted system-wide. Because the links point back into the checkout, a `git pull` there updates them in place.
- **nvim learning loop** — creates the `~/.config/nvim/.learning-enabled` marker, which activates the keylogger + journal bootstrap that already ship in the nvim fork. `LEARNING.md` is the private, device-local journal (bootstrapped from `LEARNING.template.md` on first launch, git-ignored by the fork) and is never committed or synced.

| Repo path | Symlinked to |
|-----------|--------------|
| `.claude/skills/<name>` | `~/.claude/skills/<name>` |

## Commands

Run from the repo root.

| Purpose | Command |
|---------|---------|
| Full container test | `sh terminal/test.sh` |
| Assert post-install state | `sh terminal/verify.sh [repo]` |
| Lint the shell scripts | `shellcheck --severity=warning terminal/install.sh terminal/test.sh terminal/verify.sh` |
| Benchmark the prompt | `zsh terminal/benchmark.sh <label>` |

- **`test.sh`** runs `install.sh` in a clean `ubuntu:24.04` Docker container (the default run installs Neovim and clones the kickstart fork), then runs `verify.sh` against it, then repeats both with `INSTALL_CLAUDE=1` to link the skills and enable the learning loop. Requires Docker. Accepts an optional image argument (defaults to `ubuntu:24.04`).
- **`verify.sh`** asserts deps present, starship + fzf + herdr + nvim + kickstart config + plugins + all symlinks in place, zsh is the default shell, `~/.zshenv` sets `skip_global_compinit`, the config sources cleanly, that the pure-zsh instant paint matches `starship-fast.toml` byte-for-byte across a directory matrix (so the async swap never jumps — see [Async prompt design](../explanation/async-prompt.md)), that the async hook skips a redundant background render when its inputs are unchanged (the held-Enter fork-flood guard — see [Async prompt design](../explanation/async-prompt.md)), and that a **second** `install.sh` run is idempotent (reuses the existing starship). When `INSTALL_CLAUDE=1`, it also asserts the `~/.claude/skills/<name>` symlinks for each skill in `essential-skills.txt`, plus the learning plugin in the clone and the `.learning-enabled` marker. `[repo]` defaults to the parent of the script.
- **`benchmark.sh`** needs [hyperfine](https://github.com/sharkdp/hyperfine). Writes to `terminal/bench-results/<label>.md`, which is gitignored. It measures `home` and the repo itself by default; set `BENCH_REPO=/path/to/repo` to add a third (larger or language-heavy) repo to the render and module-timing runs. See [Async prompt design](../explanation/async-prompt.md) and [Startup performance](../explanation/startup-performance.md) for what it measures.

## CI

The `Test terminal install` GitHub workflow runs these on push (when `terminal/**` changes), daily, and on demand:

- **lint** — `shellcheck` on the three scripts.
- **ubuntu-test** — the container test.
- **macos-test** — `install.sh` + `verify.sh` on a `macos-latest` runner (schedule and manual only; macOS cannot run in a container).

See [CI reference](../../general/reference/ci.md).

---

Up: [Terminal](../index.md)
