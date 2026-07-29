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

On request the installer wires up the Claude Code layer. This is **opt-in**: `install.sh` prompts once (reading from `/dev/tty`), or runs without prompting when `INSTALL_CLAUDE=1` is set; with no tty and no env var it is skipped. It covers four things, and grows as more Claude tooling is added:

- **Claude Code itself** — runs the official native installer (`https://claude.ai/install.sh`, which needs `bash`), skipped when `claude` is already on `PATH`. That installer manages `~/.local/bin/claude` as a symlink into `~/.local/share/claude/versions/` and auto-updates in the background. A failure here **warns and continues** rather than aborting the bootstrap, since the rest of the layer still works against a Claude Code installed by Homebrew or npm. Set `INSTALL_CLAUDE_CLI=0` to skip it — `test.sh` does, because the download is large and CI does not need it.
- **Skills** — symlinks each skill listed in `.claude/skills/essential-skills.txt` (one directory name per line) into `~/.claude/skills/<name>`, reusing the individual-symlink, back-up-on-conflict logic of the config files. Edit that list to change which skills are promoted system-wide. Because the links point back into the checkout, a `git pull` there updates them in place.
- **Session resume** — symlinks the `StopFailure` hook, the quota-caching status line, and the `cc-resume` watcher, merges their entries into `~/.claude/settings.json`, and registers the watcher to start on its own (below). Together they resume a rate-limited session by typing into its herdr pane once the limit lifts. See [Session resume](../explanation/session-resume.md).
- **nvim learning loop** — creates the `~/.config/nvim/.learning-enabled` marker, which activates the keylogger + journal bootstrap that already ship in the nvim fork. `LEARNING.md` is the private, device-local journal (bootstrapped from `LEARNING.template.md` on first launch, git-ignored by the fork) and is never committed or synced.

| Repo path | Symlinked to |
|-----------|--------------|
| `.claude/skills/<name>` | `~/.claude/skills/<name>` |
| `terminal/config/claude/statusline.sh` | `~/.claude/statusline.sh` |
| `terminal/config/claude/hooks/stop-failure.sh` | `~/.claude/hooks/stop-failure.sh` |
| `terminal/config/claude/cc-resume` | `~/.local/bin/cc-resume` |
| `terminal/config/claude/cc-resume.service` | `~/.config/systemd/user/cc-resume.service` (Linux/WSL) |

None of those three scripts is a compiled program — they are `#!/usr/bin/env sh` scripts that behave like commands because `~/.local/bin` is first on `PATH`. The only compiled thing in this layer is Claude Code itself.

**The watcher starts on its own**, per platform:

- **Linux and WSL** — a systemd **user** unit, symlinked like any other config file, then `systemctl --user enable --now cc-resume.service`. The installer also runs `loginctl enable-linger` so the user manager (and therefore the watcher) survives logout and comes back after a reboot; if that needs privileges it warns with the `sudo loginctl enable-linger <user>` command instead of failing. `%h` in the unit expands to the home directory, so the file is machine-independent and safe to symlink.
- **macOS** — a launchd **LaunchAgent** at `~/Library/LaunchAgents/dev.dloez.cc-resume.plist`, loaded with `launchctl bootstrap gui/<uid>` (falling back to `launchctl load -w` on older systems), with `RunAtLoad` and `KeepAlive` set so it starts at login and is restarted if it dies. Unlike every other config file this one is **generated, not symlinked** — launchd plists perform no `$HOME` expansion, so `cc-resume.plist.in` is a template whose `@HOME@` placeholder is substituted at install time.
- **Neither available** — the installer says so and leaves you to run `cc-resume watch` yourself. This is the path the container test takes, since Docker has no systemd user session.

`~/.claude/settings.json` is the **one file the installer edits rather than symlinks** — Claude Code owns it and writes to it, so `register_claude_settings` merges the `statusLine` and `StopFailure` entries in with `jq`, stripping its own previous entries first so a re-run never duplicates them. Foreign hooks and a foreign `statusLine` are preserved; the latter produces a warning naming `CC_STATUSLINE_DELEGATE` as the way to keep both. Runtime state (markers, the reset cache, the decision log) lives unmanaged in `~/.local/state/cc-resume/`.

## Commands

Run from the repo root.

| Purpose | Command |
|---------|---------|
| Full container test | `sh terminal/test.sh` |
| Assert post-install state | `sh terminal/verify.sh [repo]` |
| Lint the shell scripts | `shellcheck --severity=warning terminal/install.sh terminal/test.sh terminal/verify.sh terminal/config/claude/cc-resume terminal/config/claude/statusline.sh terminal/config/claude/hooks/stop-failure.sh` |
| Benchmark the prompt | `zsh terminal/benchmark.sh <label>` |

- **`test.sh`** runs `install.sh` in a clean `ubuntu:24.04` Docker container (the default run installs Neovim and clones the kickstart fork), then runs `verify.sh` against it, then repeats both with `INSTALL_CLAUDE=1 INSTALL_CLAUDE_CLI=0` to link the skills and enable the learning loop without pulling Claude Code. Requires Docker. Accepts an optional image argument (defaults to `ubuntu:24.04`). **Two paths it cannot cover:** the Claude Code download (skipped on purpose) and the autostart registration (Docker has no systemd user session). The macOS runner in CI is what exercises the LaunchAgent.
- **`verify.sh`** asserts deps present, starship + fzf + herdr + nvim + kickstart config + plugins + all symlinks in place, zsh is the default shell, `~/.zshenv` sets `skip_global_compinit`, the config sources cleanly, that the pure-zsh instant paint matches `starship-fast.toml` byte-for-byte across a directory matrix (so the async swap never jumps — see [Async prompt design](../explanation/async-prompt.md)), that the async hook skips a redundant background render when its inputs are unchanged (the held-Enter fork-flood guard — see [Async prompt design](../explanation/async-prompt.md)), and that a **second** `install.sh` run is idempotent (reuses the existing starship). When `INSTALL_CLAUDE=1`, it also asserts the `~/.claude/skills/<name>` symlinks for each skill in `essential-skills.txt`, that `claude` is on `PATH` (unless `INSTALL_CLAUDE_CLI=0`), the three session-resume symlinks with `cc-resume` executable, that `~/.claude/settings.json` registers both the `StopFailure` hook and the `statusLine`, that the watcher is registered to autostart (the systemd unit is enabled, or the LaunchAgent plist exists; vacuously true where neither init is available), plus the learning plugin in the clone and the `.learning-enabled` marker. `[repo]` defaults to the parent of the script.
- **`benchmark.sh`** needs [hyperfine](https://github.com/sharkdp/hyperfine). Writes to `terminal/bench-results/<label>.md`, which is gitignored. It measures `home` and the repo itself by default; set `BENCH_REPO=/path/to/repo` to add a third (larger or language-heavy) repo to the render and module-timing runs. See [Async prompt design](../explanation/async-prompt.md) and [Startup performance](../explanation/startup-performance.md) for what it measures.

## CI

The `Test terminal install` GitHub workflow runs these on push (when `terminal/**` changes), daily, and on demand:

- **lint** — `shellcheck` on the three installer scripts plus the three Claude session-resume scripts.
- **ubuntu-test** — the container test.
- **macos-test** — `install.sh` + `verify.sh` on a `macos-latest` runner (schedule and manual only; macOS cannot run in a container).

See [CI reference](../../general/reference/ci.md).

---

Up: [Terminal](../index.md)
