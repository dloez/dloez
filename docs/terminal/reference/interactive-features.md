# Interactive features

zsh interactivity layered on top of the prompt. Each piece is a small file under `config/zsh/`, sourced from `zshrc` between the perf tuning and the plugins.

## Completion

`config/zsh/completion.zsh` initialises zsh's completion system (`compinit`). The dump lives at `${XDG_CACHE_HOME:-~/.cache}/zsh/zcompdump`. Startup always takes the fast path — `compinit -C`, which skips the `compaudit` fpath security scan (the single biggest startup cost, ~38ms) — and loads a `zcompile`d digest of the dump. When the dump is older than 24h it is still loaded fast; the rebuild (full `compinit` + re-`zcompile`) runs in a disowned background job so the refresh never blocks a shell, only the *next* one benefits. A missing dump is built synchronously (first run on a new machine only). Styling applied: `menu select`, case-insensitive matching (`m:{a-zA-Z}={A-Za-z}`), grouped results with descriptions, and `LS_COLORS`-driven list colors when `LS_COLORS` is set. `complete_in_word` and `always_to_end` are enabled so completion works mid-word.

## fzf

fzf is installed as a single binary to `~/.local/bin/fzf` (alongside starship). The installer shallow-clones `junegunn/fzf` into `${XDG_DATA_HOME:-~/.local/share}/fzf` and runs its `install --bin`, which downloads the platform binary straight from a GitHub release — no package manager, no `api.github.com` call. `zshrc` sources `fzf --zsh` at startup when the binary is present:

| Key | Action |
|-----|--------|
| `Ctrl-R` | Fuzzy-search command history |
| `Ctrl-T` | Fuzzy-pick file paths into the command line |
| `Alt-C` | Fuzzy `cd` into a subdirectory |

The `fzf --zsh` source is redirected with `2>/dev/null`. fzf snapshots every shell option at load and `eval`s it back to restore state; that snapshot includes `zle on`, which zsh refuses to change at runtime, so an interactive shell would otherwise print `can't change option: zle` twice on every startup. The warning is cosmetic — the widgets use function-local `setopt` and work regardless — and the redirect only silences the sourced code's stderr, not the fzf binary's own errors.

## History substring search

`config/zsh/history-search.zsh` binds `↑`/`↓` to `up-line-or-beginning-search` / `down-line-or-beginning-search`: with text already on the line, the arrows walk only history entries that start with that prefix; on an empty line they behave like ordinary history navigation. Both CSI (`^[[A`) and SS3 (`^[OA`) sequences are bound so the arrows work across terminals regardless of keypad mode.

---

Up: [Terminal](../index.md)
