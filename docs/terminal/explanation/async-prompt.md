# Async prompt design

## The problem

starship's stock `starship init zsh` re-runs the `starship` binary **synchronously** on every prompt draw. Inside a git repo that render is ~40ms — and 100ms+ on cold caches — because it shells out to git for branch and status. That delay blocks the shell: you cannot type until the prompt finishes drawing. On every single command, in every repo, it is felt.

## The approach: two paints

`config/zsh/async-prompt.zsh` replaces the stock init with a hook that paints the prompt twice:

1. **Instant first paint (git-less).** The `precmd` hook renders the prompt with `starship-fast.toml`, whose format is only `$directory$line_break$character` — no git modules, so no git subprocess. This lands in ~5-15ms and the shell is typeable immediately.
2. **Background full render.** The same hook launches `starship prompt` (and `starship prompt --right`) with the full `starship.toml` in a child process, reading its output through a file-descriptor callback (`zle -F`). When the full render — git branch, ahead/behind, dirty state — is ready, it swaps into `PROMPT`/`RPROMPT` and calls `zle reset-prompt`.

The swap only fires when the full render actually differs from what is on screen, avoiding a needless redraw. The redraw is bracketed with synchronized-output and cursor-hide escapes so the git info appears in place without flicker.

## Why the layout must match

Because the full render swaps in *over* the first paint, the two configs must produce the **same layout minus git**. `starship-fast.toml` mirrors the directory/character portion of `starship.toml` exactly; if they drift, the swap shifts text on screen and the prompt visibly jumps. Keep the two files visually in sync whenever either changes.

## Measuring it

`benchmark.sh` quantifies the win (requires [hyperfine](https://github.com/sharkdp/hyperfine)). It measures, per directory:

- full `starship prompt` render time,
- the blocking `starship-fast.toml` render time (the first-paint cost),
- per-module starship timings,
- interactive shell startup (`zsh -i -c exit`),
- keystroke overhead through syntax-highlighting + autosuggestions.

Results land in `terminal/bench-results/<label>.md` (gitignored). See [Layout and testing](../reference/layout-and-testing.md) for the exact command.

---

Up: [Terminal](../index.md)
