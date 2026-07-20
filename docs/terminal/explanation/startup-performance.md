# Startup performance

The [async prompt](async-prompt.md) makes each *prompt* cheap. This is the other axis: the cost of *starting* an interactive shell — `zsh -i`. It is paid on every new pane, tab, SSH session, and every shell an AI agent spawns, so under a herdr + agents workload it is felt constantly. The target is the same as the prompt's: as close to zero as the tooling allows.

## The global-compinit trap

`completion.zsh` deliberately runs `compinit -C` — the fast path that skips the `compaudit` fpath security scan, the single most expensive part of completion setup (~40ms). But on Debian and Ubuntu that optimization was being **completely defeated**, and silently.

The reason is ordering. zsh sources rc files as: `/etc/zsh/zshenv` → `~/.zshenv` → (`/etc/zsh/zprofile` for login shells) → `/etc/zsh/zshrc` → `~/.zshrc`. Debian's stock `/etc/zsh/zshrc` contains, near the end:

```zsh
if (( ${${(@f)"$(</etc/os-release)"}[(I)ID*=*ubuntu]} )) && [[ -z "$skip_global_compinit" ]]; then
  autoload -U compinit
  compinit
fi
```

That is a **full** `compinit` — with the compaudit scan — and it runs *before* `~/.zshrc` is even read. So the ~40ms scan happened regardless, and then `completion.zsh` ran a second `compinit -C` on top. Measured on a warm WSL2 box: `zsh -i -c exit` was ~57ms, of which ~44ms was this one block.

The fix is the escape hatch the Debian file itself documents: set `skip_global_compinit=1` before `/etc/zsh/zshrc` runs. The only user file sourced that early is `~/.zshenv`, so that is where it goes. With it set, the global block is skipped and `completion.zsh`'s fast path is the only `compinit` that runs — completions are still fully built (the dump is loaded, `compdef` works). Measured: **~57ms → ~13ms**.

`skip_global_compinit` is Ubuntu-gated in the global file, so on Fedora, Arch, and macOS the variable is simply unused and harmless.

### Why `install.sh` appends instead of symlinking

`~/.zshenv` is not managed like the other config files. It is sourced before everything and is commonly owned by other tools (rustup writes `. "$HOME/.cargo/env"` there). Symlinking a repo copy would clobber that. So `install.sh`'s `ensure_skip_global_compinit` idempotently *appends* the one line if it is not already present, creating the file if absent. `verify.sh` asserts the line is there.

## Compiling and caching what is sourced

After the compinit fix the ~13ms that remains is dominated by sourcing the two plugins and running the `starship init zsh` / `fzf --zsh` generators. `zshrc` cuts this with two helpers:

- `_zsource <file>` — before sourcing, it (re)compiles an adjacent `<file>.zwc` when the source is newer, then `source`s the file. zsh's `source` transparently prefers a fresh `.zwc`, so the wordcode is used on every later shell. Used for the two plugins (compiled in place in their clone, so `${0:A:h}` still resolves to the plugin directory — zsh-syntax-highlighting loads its highlighters from there).
- `_zsource_gen <cache> <cmd...>` — runs `<cmd>` once, caches its output under `~/.cache/zsh`, compiles that, and sources it; on later shells it just sources the compiled cache. Used for `starship init zsh` and `fzf --zsh`, which otherwise fork on every startup. A failed generation falls back to a live `eval`, so a fresh or broken cache never breaks the shell.

Measured incremental win: ~13ms → ~9ms. Cache invalidation for the generated init scripts is handled by `install.sh` (it deletes `~/.cache/zsh/*-init.zsh*` on every run, the update entrypoint), so upgrading starship or fzf through the installer regenerates them; the plugin `.zwc` files self-heal on mtime. After a manual, out-of-band upgrade of starship or fzf, re-run `install.sh` (or clear `~/.cache/zsh`) to refresh the cache.

## The WSL `${commands}` rehash trap

One tempting way to invalidate the init caches is to compare the cache mtime against the binary's, reading the binary path from zsh's `${commands[starship]}` associative array. **Do not.** The first access to `commands` forces zsh to hash the *entire* `PATH` — stat every executable in every directory. On WSL the Windows mounts (`/mnt/c/...`) are on `PATH`, and statting them across the 9p filesystem cost ~38ms in one hit, wiping out every gain above. `command -v` (a lazy single-command lookup) costs ~0.7ms and is what the fzf guard and the fallback use. Keep `${commands[...]}` / `${+commands[...]}` out of the startup path entirely.

## Measuring it

`benchmark.sh` records interactive startup (`zsh -i -c exit`) among its metrics — see [Layout and testing](../reference/layout-and-testing.md). Because the deployed shell sets `skip_global_compinit`, that number reflects the fast path. When comparing configs, remove the global-compinit variance by measuring both with `skip_global_compinit=1` set (the block's ~40ms and its WSL `/mnt/c` fpath jitter otherwise swamp the signal).

---

Up: [Terminal](../index.md)
