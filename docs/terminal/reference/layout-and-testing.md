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
| `config/zsh/async-prompt.zsh` | `~/.config/zsh/async-prompt.zsh` |
| `config/zsh/transient-prompt.zsh` | `~/.config/zsh/transient-prompt.zsh` |

## Claude Code skills (opt-in)

The installer can also symlink each `.claude/skills/<name>` directory in this repo into `~/.claude/skills/<name>`, reusing the same individual-symlink, back-up-on-conflict logic as the config files. This is **opt-in**: `install.sh` prompts once (reading from `/dev/tty`), or links without prompting when `INSTALL_CLAUDE_SKILLS=1` is set; with no tty and no env var it is skipped. Because the links point back into the checkout, a `git pull` there updates the skills in place.

| Repo dir | Symlinked to |
|----------|--------------|
| `.claude/skills/<name>` | `~/.claude/skills/<name>` |

## Commands

Run from the repo root.

| Purpose | Command |
|---------|---------|
| Full container test | `sh terminal/test.sh` |
| Assert post-install state | `sh terminal/verify.sh [repo]` |
| Lint the shell scripts | `shellcheck --severity=warning terminal/install.sh terminal/test.sh terminal/verify.sh` |
| Benchmark the prompt | `zsh terminal/benchmark.sh <label>` |

- **`test.sh`** runs `install.sh` in a clean `ubuntu:24.04` Docker container, then runs `verify.sh` against it, then repeats both with `INSTALL_CLAUDE_SKILLS=1` to exercise the skills symlinks. Requires Docker. Accepts an optional image argument (defaults to `ubuntu:24.04`).
- **`verify.sh`** asserts deps present, starship + plugins + all symlinks in place, zsh is the default shell, the config sources cleanly, and that a **second** `install.sh` run is idempotent (reuses the existing starship). When `INSTALL_CLAUDE_SKILLS=1`, it also asserts the `~/.claude/skills/<name>` symlinks. `[repo]` defaults to the parent of the script.
- **`benchmark.sh`** needs [hyperfine](https://github.com/sharkdp/hyperfine). Writes to `terminal/bench-results/<label>.md`, which is gitignored. See [Async prompt design](../explanation/async-prompt.md) for what it measures.

## CI

The `Test terminal install` GitHub workflow runs these on push (when `terminal/**` changes), daily, and on demand:

- **lint** — `shellcheck` on the three scripts.
- **ubuntu-test** — the container test.
- **macos-test** — `install.sh` + `verify.sh` on a `macos-latest` runner (schedule and manual only; macOS cannot run in a container).

See [CI reference](../../general/reference/ci.md).

---

Up: [Terminal](../index.md)
