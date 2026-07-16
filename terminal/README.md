# terminal

Portable zsh setup — starship prompt, autosuggestions, syntax highlighting, a
collapsing (transient) prompt, and async prompt rendering. No oh-my-zsh, no
brew required.

## Async prompt

starship's stock init re-runs starship synchronously on every prompt draw
(~40ms in any git repo, 100ms+ on cold caches). `zsh/async-prompt.zsh` splits
that into an instant git-less first paint (`starship-fast.toml`, ~5-15ms) and a
background full render that swaps git info in via `zle reset-prompt` — same
layout, no jump, and the shell is typeable immediately.

Measure before/after with `zsh terminal/benchmark.sh <label>` (requires
[hyperfine](https://github.com/sharkdp/hyperfine)); results land in
`terminal/bench-results/<label>.md`.

## Bootstrap a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/dloez/dloez/main/terminal/install.sh | sh
```

Then restart your shell (`exec zsh`).

## What it does

`install.sh` is idempotent — safe to re-run any time. It:

1. Installs [starship](https://starship.rs) (official installer) if missing.
2. Clones/updates the zsh plugins into `~/.local/share/zsh/plugins`.
3. Symlinks each config file below into its canonical location, backing up any
   pre-existing real file to `<file>.bak.<timestamp>`.

When run via `curl`, it first clones this repo to `~/.local/share/dloez` and
links from there. When run from an existing checkout (e.g.
`sh terminal/install.sh`), it links directly from that checkout, so edits to a
config file are live in your shell immediately.

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
