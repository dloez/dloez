# terminal/

**MANDATORY** rules when working in `terminal/`.

## Shared rules (deferred up)

- Checks & verification — see root CLAUDE.md → "Checks & Verification".
- Commits & PRs — see root CLAUDE.md → "Commit & PR Conventions".

## Terminal-specific rules

- `install.sh` must stay **POSIX sh** (`#!/usr/bin/env sh`, `set -eu`), remain **idempotent** (safe to re-run), and stay **shellcheck-clean** at `--severity=warning`.
- After changing any of `install.sh`, `verify.sh`, or `test.sh`, re-run the container test and shellcheck (commands in Checks & verification above) before committing.
- Config files under `config/` are symlinked **individually**, never as whole directories. When adding a config file, add its `link_file` line in `install.sh` and its symlink assertion in `verify.sh`.
- `~/.zshenv` is the **one** managed file that is appended to, not symlinked (other tools like rustup own it too). `install.sh`'s `ensure_skip_global_compinit` idempotently appends `skip_global_compinit=1` there; `verify.sh` asserts it. That line is what lets `completion.zsh`'s `compinit -C` fast path actually pay off — do not remove it. See [docs/terminal/explanation/startup-performance.md](../docs/terminal/explanation/startup-performance.md).
- Never touch zsh's `${commands[...]}` / `${+commands[...]}` in the `zshrc` startup path — the first access rehashes the whole `PATH`, which on WSL means statting `/mnt/c` over 9p (~38ms). Use `command -v` for a lazy single-command check.
- Generated init caches (`~/.cache/zsh/*-init.zsh`) are invalidated by `install.sh` (it deletes them each run). Plugin `.zwc` files self-heal on mtime via `_zsource`. If you add another `_zsource_gen` cache, make sure `install.sh` clears it.
- The async prompt skips its background render when the render **signature** (the `starship prompt` flag set plus `$PWD`) is unchanged. Any new starship flag that affects the first prompt line must be added to `_async_prompt_flags` so the signature invalidates correctly.
- Any interactive prompt in `install.sh` must read from `/dev/tty` — probe with `(exec </dev/tty) 2>/dev/null`, default to "no", and never block. The installer is run piped (`curl | sh`, and the container test with no tty), so `read` from stdin would consume the script or hang. Never probe the tty with a special built-in like `:` — a redirection failure on a special built-in makes non-interactive `dash` exit the whole script.
- The Claude session-resume scripts under `config/claude/` (`cc-resume`, `statusline.sh`, `hooks/stop-failure.sh`) follow the same rules as `install.sh`: POSIX sh, shellcheck-clean at `--severity=warning`, and listed in **both** the CI lint step and the root CLAUDE.md lint command. Adding a script there means adding it to both lists. See [docs/terminal/explanation/session-resume.md](../docs/terminal/explanation/session-resume.md).
- **Nothing in the resume path may call a model.** The hook records, `cc-resume` compares two numbers, and herdr delivers keystrokes. Recovery that needs an LLM to work out what to do next is the design this replaced — do not reintroduce it.
- `~/.claude/settings.json` is the **one** file the installer edits rather than symlinks, because Claude Code owns it and writes to it. `register_claude_settings` must stay idempotent (it strips its own `stop-failure.sh` entries before re-adding them) and must never clobber a foreign hook entry, a foreign `statusLine`, or any other key. Re-run it twice in any change that touches it and diff the result.
- The `StopFailure` error type is passed to the hook as an **argument** (`stop-failure.sh rate_limit`), not read from the payload — the matcher already selects the error, and the documented payload fields do not include it. Do not "simplify" this to read `.error` from stdin.
- `cc-resume` resolves its target from `HERDR_PANE_ID`, recorded by the hook in the failing pane, and never from a session-id lookup. It must refuse to type into a pane that `herdr agent list` no longer reports an agent for — otherwise the resume text runs as a shell command in a bare shell.
- Keep `starship.toml`, `starship-fast.toml`, and the pure-zsh instant paint in `config/zsh/async-prompt.zsh` **mutually in sync** — the full `starship.toml` render swaps in over the pure-zsh paint, and `starship-fast.toml` is the spec the paint must reproduce, so a mismatch makes the prompt jump. `verify.sh` asserts the paint matches `starship-fast.toml` byte-for-byte; run it after touching any of the three.

## Documentation → see docs/terminal/

- [Overview](../docs/terminal/index.md)
- [Bootstrap a machine](../docs/terminal/how-to/bootstrap-machine.md)
- [Async prompt design](../docs/terminal/explanation/async-prompt.md)
- [WSL host setup](../docs/terminal/explanation/wsl-host-setup.md)
- [Session resume](../docs/terminal/explanation/session-resume.md)
- [Interactive features](../docs/terminal/reference/interactive-features.md)
- [Layout and testing](../docs/terminal/reference/layout-and-testing.md)
