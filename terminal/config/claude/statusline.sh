#!/usr/bin/env sh

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-resume"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  state=$(printf '%s' "$input" | jq -c '
    select(.rate_limits.five_hour.resets_at != null) | {
      five_hour_used: (.rate_limits.five_hour.used_percentage // null),
      five_hour_resets_at: .rate_limits.five_hour.resets_at,
      seven_day_used: (.rate_limits.seven_day.used_percentage // null),
      seven_day_resets_at: (.rate_limits.seven_day.resets_at // null),
      cached_at: (now | floor)
    }' 2>/dev/null) || state=''

  if [ -n "$state" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    tmp="$STATE_DIR/rate-limit.json.$$"
    if printf '%s\n' "$state" >"$tmp" 2>/dev/null; then
      mv -f "$tmp" "$STATE_DIR/rate-limit.json" 2>/dev/null || rm -f "$tmp"
    else
      rm -f "$tmp"
    fi
  fi
fi

if [ -n "${CC_STATUSLINE_DELEGATE:-}" ]; then
  printf '%s' "$input" | "$CC_STATUSLINE_DELEGATE"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Claude'
  exit 0
fi

epoch_to_local() {
  date -r "$1" '+%H:%M' 2>/dev/null ||
    date -d "@$1" '+%H:%M' 2>/dev/null ||
    printf '?'
}

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty | floor')
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')
resets=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

line="$model"
[ -n "$ctx" ] && line="$line · ${ctx}% ctx"
if [ -n "$five" ] && [ -n "$resets" ]; then
  line="$line · 5h ${five}% (resets $(epoch_to_local "$resets"))"
elif [ -n "$five" ]; then
  line="$line · 5h ${five}%"
fi

printf '%s' "$line"
