# terminal/

**MANDATORY** rules when working in `terminal/`.

## Shared rules (deferred up)

- Checks & verification — see root CLAUDE.md → "Checks & Verification".
- Commits & PRs — see root CLAUDE.md → "Commit & PR Conventions".

## Terminal-specific rules

- `install.sh` must stay **POSIX sh** (`#!/usr/bin/env sh`, `set -eu`), remain **idempotent** (safe to re-run), and stay **shellcheck-clean** at `--severity=warning`.
- After changing any of `install.sh`, `verify.sh`, or `test.sh`, re-run the container test and shellcheck (commands in Checks & verification above) before committing.
- Config files under `config/` are symlinked **individually**, never as whole directories. When adding a config file, add its `link_file` line in `install.sh` and its symlink assertion in `verify.sh`.
- Any interactive prompt in `install.sh` must read from `/dev/tty` — probe with `(exec </dev/tty) 2>/dev/null`, default to "no", and never block. The installer is run piped (`curl | sh`, and the container test with no tty), so `read` from stdin would consume the script or hang. Never probe the tty with a special built-in like `:` — a redirection failure on a special built-in makes non-interactive `dash` exit the whole script.
- Keep `starship.toml`, `starship-fast.toml`, and the pure-zsh instant paint in `config/zsh/async-prompt.zsh` **mutually in sync** — the full `starship.toml` render swaps in over the pure-zsh paint, and `starship-fast.toml` is the spec the paint must reproduce, so a mismatch makes the prompt jump. `verify.sh` asserts the paint matches `starship-fast.toml` byte-for-byte; run it after touching any of the three.

## Documentation → see docs/terminal/

- [Overview](../docs/terminal/index.md)
- [Bootstrap a machine](../docs/terminal/how-to/bootstrap-machine.md)
- [Async prompt design](../docs/terminal/explanation/async-prompt.md)
- [WSL host setup](../docs/terminal/explanation/wsl-host-setup.md)
- [Interactive features](../docs/terminal/reference/interactive-features.md)
- [Layout and testing](../docs/terminal/reference/layout-and-testing.md)
