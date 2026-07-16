# terminal

Portable zsh setup — starship prompt, autosuggestions, syntax highlighting, and
a collapsing (transient) prompt. No oh-my-zsh, no brew required.

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
| `config/zsh/perf.zsh` | `~/.config/zsh/perf.zsh` |
| `config/zsh/transient-prompt.zsh` | `~/.config/zsh/transient-prompt.zsh` |
