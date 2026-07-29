#!/usr/bin/env sh

set -u

error=${1:-unknown}
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-resume"
PENDING="$STATE_DIR/pending"
RATE_STATE="$STATE_DIR/rate-limit.json"
MAX_STATE_AGE=21600

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$session" ] || exit 0

safe_session=$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

now=$(date +%s)

resets_at=$(
  if [ -f "$RATE_STATE" ]; then
    jq -r --argjson now "$now" --argjson max_age "$MAX_STATE_AGE" '
      (.five_hour_resets_at // null) as $reset |
      (.cached_at // null) as $cached |
      if ($reset | type) == "number" and ($cached | type) == "number"
        and ($reset | floor) == $reset
        and $reset > $now
        and $cached <= $now
        and ($now - $cached) <= $max_age
        and ($reset - $cached) > 0
        and ($reset - $cached) <= $max_age
      then $reset else empty end' "$RATE_STATE" 2>/dev/null
  fi
)
[ -n "$resets_at" ] || resets_at=null

mkdir -p "$PENDING" 2>/dev/null || exit 0

marker="$PENDING/$safe_session.json"
tmp="$marker.$$"

if jq -n \
  --arg session_id "$session" \
  --arg cwd "$cwd" \
  --arg error "$error" \
  --arg pane_id "${HERDR_PANE_ID:-}" \
  --arg socket "${HERDR_SOCKET_PATH:-}" \
  --argjson stopped_at "$now" \
  --argjson resets_at "$resets_at" \
  '{session_id: $session_id, cwd: $cwd, error: $error,
    pane_id: (if $pane_id == "" then null else $pane_id end),
    socket: (if $socket == "" then null else $socket end),
    stopped_at: $stopped_at, resets_at: $resets_at, attempts: 0}' \
  >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$marker" 2>/dev/null || rm -f "$tmp"
else
  rm -f "$tmp"
fi

exit 0
