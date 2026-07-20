#!/usr/bin/env zsh

set -eu

LABEL="${1:-baseline}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/terminal/bench-results"
OUT="$OUT_DIR/$LABEL.md"
mkdir -p "$OUT_DIR"

typeset -A DIRS
DIRS=(
  home        "$HOME"
  small-repo  "$REPO_ROOT"
)
BENCH_NAMES=(home small-repo)
if [ -n "${BENCH_REPO:-}" ] && [ -d "${BENCH_REPO:-}" ]; then
  DIRS[big-repo]="$BENCH_REPO"
  BENCH_NAMES+=(big-repo)
fi

say() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

{
  echo "# Prompt benchmark — $LABEL"
  echo
  echo "- date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- starship: $(starship --version | head -1)"
  echo "- machine: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
  echo
} >"$OUT"

say "Benchmarking prompt render per directory"
echo "## Prompt render (starship prompt)" >>"$OUT"
echo >>"$OUT"
for name in $BENCH_NAMES; do
  dir="${DIRS[$name]}"
  [ -d "$dir" ] || { echo "- $name: SKIPPED (missing $dir)" >>"$OUT"; continue; }
  say "  $name ($dir)"
  hyperfine --warmup 3 --min-runs 20 \
    --command-name "$name" \
    "cd '$dir' && starship prompt --terminal-width 120" \
    --export-markdown /tmp/bench-frag.md >/dev/null
  tail -n +2 /tmp/bench-frag.md >>"$OUT"
done

PAINT_SRC="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/async-prompt.zsh"
if [ -f "$PAINT_SRC" ]; then
  say "Benchmarking pure-zsh instant paint (in-process)"
  zmodload zsh/datetime
  source "$PAINT_SRC"
  _bench_paint() { local REPLY; _async_prompt_dir; _async_prompt_char }
  {
    echo
    echo "## Pure-zsh instant paint (in-process, zero forks)"
    echo
    echo '| directory | mean per paint |'
    echo '|-----------|----------------|'
  } >>"$OUT"
  for name in $BENCH_NAMES; do
    dir="${DIRS[$name]}"
    [ -d "$dir" ] || continue
    say "  $name ($dir)"
    (
      cd "$dir" || exit
      STARSHIP_CMD_STATUS=0
      repeat 200 _bench_paint
      typeset -F _s=$EPOCHREALTIME; repeat 5000 _bench_paint; typeset -F _e=$EPOCHREALTIME
      printf '| %s | %.4f ms |\n' "$name" $(( (_e - _s) * 1000 / 5000 )) >>"$OUT"
    )
  done
fi

timings_name=${DIRS[big-repo]:+big-repo}; timings_name=${timings_name:-small-repo}
timings_dir=${DIRS[$timings_name]}
say "Collecting starship module timings ($timings_name)"
{
  echo
  echo "## Starship module timings ($timings_name)"
  echo
  echo '```'
  (cd "$timings_dir" && starship timings 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\s' || true)
  echo '```'
} >>"$OUT"

say "Benchmarking interactive shell startup"
{
  echo
  echo "## Interactive shell startup (zsh -i -c exit)"
  echo
} >>"$OUT"
hyperfine --warmup 3 --min-runs 15 \
  --command-name "zsh -i" \
  "zsh -i -c exit" \
  --export-markdown /tmp/bench-frag.md >/dev/null
cat /tmp/bench-frag.md >>"$OUT"

say "Benchmarking keystroke processing (syntax highlighting + autosuggestions)"
{
  echo
  echo "## Keystroke overhead (200 chars through zle with plugins)"
  echo
} >>"$OUT"
cat >/tmp/bench-keys.zsh <<'ZEOF'
source ~/.zshrc >/dev/null 2>&1
zmodload zsh/datetime
line='git commit --amend --no-edit && git push --force-with-lease origin feature'
typeset -F start end
functions[__bench]='
  BUFFER=""
  for (( i=1; i<=${#line}; i++ )); do
    BUFFER+="${line[i]}"
    (( ${+functions[_zsh_highlight]} )) && _zsh_highlight
    (( ${+functions[_zsh_autosuggest_fetch]} )) && _zsh_autosuggest_fetch
  done
'
start=$EPOCHREALTIME
__bench; __bench; __bench
end=$EPOCHREALTIME
printf 'total for %d simulated keystrokes: %.1f ms (%.2f ms/keystroke)\n' \
  $(( ${#line} * 3 )) $(( (end-start)*1000 )) $(( (end-start)*1000 / (${#line}*3) ))
ZEOF
{
  echo '```'
  zsh -i /tmp/bench-keys.zsh 2>/dev/null || echo "(keystroke bench failed)"
  echo '```'
} >>"$OUT"

say "Results written to ${OUT#$REPO_ROOT/}"
