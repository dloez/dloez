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
  sqlite      "$HOME/workspace/sqlite"
)

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
for name in home small-repo sqlite; do
  dir="${DIRS[$name]}"
  [ -d "$dir" ] || { echo "- $name: SKIPPED (missing $dir)" >>"$OUT"; continue; }
  say "  $name ($dir)"
  hyperfine --warmup 3 --min-runs 20 \
    --command-name "$name" \
    "cd '$dir' && starship prompt --terminal-width 120" \
    --export-markdown /tmp/bench-frag.md >/dev/null
  tail -n +2 /tmp/bench-frag.md >>"$OUT"
done

FAST_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship-fast.toml"
if [ -f "$FAST_CONFIG" ]; then
  say "Benchmarking blocking render (starship-fast.toml)"
  echo >>"$OUT"
  echo "## Blocking render with async prompt (fast config)" >>"$OUT"
  echo >>"$OUT"
  for name in home small-repo sqlite; do
    dir="${DIRS[$name]}"
    [ -d "$dir" ] || continue
    say "  $name ($dir)"
    hyperfine --warmup 3 --min-runs 20 \
      --command-name "$name (fast)" \
      "cd '$dir' && STARSHIP_CONFIG='$FAST_CONFIG' starship prompt --terminal-width 120" \
      --export-markdown /tmp/bench-frag.md >/dev/null
    tail -n +2 /tmp/bench-frag.md >>"$OUT"
  done
fi

say "Collecting starship module timings (sqlite)"
{
  echo
  echo "## Starship module timings (sqlite repo)"
  echo
  echo '```'
  (cd "${DIRS[sqlite]}" && starship timings 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\s' || true)
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
