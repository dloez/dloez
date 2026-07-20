# Async prompt design

## The problem

starship's stock `starship init zsh` re-runs the `starship` binary **synchronously** on every prompt draw. Inside a git repo that render is ~40ms — and 100ms+ on cold caches — because it shells out to git for branch and status. That delay blocks the shell: you cannot type until the prompt finishes drawing. On every single command, in every repo, it is felt.

Even a git-less "fast" config does not fix this on its own: rendering it still forks and execs the `starship` binary (~2ms warm, and it jitters badly under load — exactly when AI agents are hammering the box). p10k feels instant because its first paint forks **nothing** — it builds the prompt string in pure zsh. That is the bar.

## The approach: two paints

`config/zsh/async-prompt.zsh` replaces the stock init with a hook that paints the prompt twice:

1. **Instant first paint (pure zsh, zero forks).** The `precmd` hook builds `PROMPT` in zsh alone — no subprocess — reproducing starship's default `directory` and `character` modules: bold-cyan path with `~`/truncate-to-repo/read-only-lock, and a green/red `❯` (or `❮` in vi command mode). This lands in ~0.02ms, so the shell is typeable instantly.
2. **Background full render.** The same hook launches `starship prompt` with the full `starship.toml` in a child process, reading its output through a file-descriptor callback (`zle -F`). When the full render — git branch and status, plus language, docker, and cloud modules — is ready, it swaps into `PROMPT` and calls `zle reset-prompt`.

The swap only fires when the full render actually differs from the instant paint, avoiding a needless redraw. The redraw is bracketed with synchronized-output and cursor-hide escapes so the git and context info appear in place without flicker. There is no right-prompt render: `starship.toml` sets no `right_format`, so `RPROMPT` is always empty and rendering it was a wasted process spawn.

## Why the paint must match — and how that is enforced

The full render swaps in *over* the instant paint, so the instant paint's directory and character must be **byte-identical** to what starship produces; otherwise text shifts on screen and the prompt visibly jumps. `starship-fast.toml` (format `$directory$line_break$character`) is the spec for that: it renders exactly the directory + character portion of `starship.toml`, and the pure-zsh paint must reproduce it.

Rather than trust that by discipline, `terminal/verify.sh` asserts it: it builds the pure-zsh paint and compares it byte-for-byte against `starship-fast.toml` across a directory matrix (home, repo root, deep-in-repo, read-only, `/`) for both success and error status. Drift therefore fails a check instead of silently making the prompt jump. Keep `starship.toml`, `starship-fast.toml`, and the pure-zsh paint mutually consistent whenever any of the three changes.

## Measuring it

`benchmark.sh` quantifies the win (requires [hyperfine](https://github.com/sharkdp/hyperfine)). It measures, per directory:

- full `starship prompt` render time (the background cost),
- the pure-zsh instant-paint time (the first-paint cost, run in-process),
- per-module starship timings,
- interactive shell startup (`zsh -i -c exit`),
- keystroke overhead through syntax-highlighting + autosuggestions.

Results land in `terminal/bench-results/<label>.md` (gitignored). See [Layout and testing](../reference/layout-and-testing.md) for the exact command.

---

Up: [Terminal](../index.md)
