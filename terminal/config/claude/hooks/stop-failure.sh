#!/usr/bin/env sh

set -u

error=${1:-unknown}
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-resume"
PENDING="$STATE_DIR/pending"
NUDGES="$STATE_DIR/nudges"
RATE_STATE="$STATE_DIR/rate-limit.json"
MAX_STATE_AGE=21600

STOP_WINDOW="${CC_RESUME_STOP_WINDOW:-900}"
MAX_NUDGES="${CC_RESUME_MAX_NUDGES:-3}"
NUDGE_RESET="${CC_RESUME_NUDGE_RESET:-21600}"
SCAN_LINES="${CC_RESUME_SCAN_LINES:-500}"

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$session" ] || exit 0

safe_session=$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

now=$(date +%s)

find_transcript() {
  path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
  if [ -n "$path" ] && [ -f "$path" ]; then
    printf '%s' "$path"
    return 0
  fi
  slug=$(printf '%s' "$cwd" | tr -c 'A-Za-z0-9-' '-')
  path="$HOME/.claude/projects/$slug/$session.jsonl"
  [ -f "$path" ] && printf '%s' "$path"
}

SCAN_FILTER='
  def epoch: (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)? // empty;
  def main: select((.isSidechain // false) != true and (.timestamp | type) == "string");

  ([ .[] | main | select(.type == "user")
     | select((.message.content // null | type) == "string")
     | select(.message.content | test("<task-notification>"))
     | select(.message.content | test("<status>failed</status>"))
     | select(.message.content
              | test("hit your (session|usage) limit|rate limit"; "i"))
     | .timestamp | epoch ] | max // 0) as $failed
  | ([ .[] | main | select(.type == "assistant")
     | select((.message.content // [] | type) == "array")
     | select(any(.message.content[]; .type == "tool_use"))
     | .timestamp | epoch ] | max // 0) as $served
  | "\($failed) \(if $served > $failed then 1 else 0 end)"
'

scan_transcript() {
  out=$(tail -n "$SCAN_LINES" "$1" 2>/dev/null | jq -rs "$SCAN_FILTER" 2>/dev/null)
  if [ -z "$out" ]; then
    out=$(tail -n "$SCAN_LINES" "$1" 2>/dev/null | sed '$d' |
      jq -rs "$SCAN_FILTER" 2>/dev/null)
  fi
  printf '%s' "$out"
}

nudge_budget_ok() {
  ledger="$NUDGES/$safe_session.json"
  count=0
  if [ -f "$ledger" ]; then
    count=$(jq -r --argjson now "$now" --argjson reset "$NUDGE_RESET" '
      if ((.last_at // 0) | type) == "number" and ($now - (.last_at // 0)) <= $reset
      then (.count // 0) else 0 end' "$ledger" 2>/dev/null)
  fi
  case "$count" in
    '' | *[!0-9]*) count=0 ;;
  esac
  [ "$count" -lt "$MAX_NUDGES" ] || return 1

  mkdir -p "$NUDGES" 2>/dev/null || return 1
  tmp="$ledger.$$"
  if jq -n --argjson count "$((count + 1))" --argjson last_at "$now" \
    '{count: $count, last_at: $last_at}' >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$ledger" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
  find "$NUDGES" -type f -mtime +1 -exec rm -f {} + 2>/dev/null || true
  return 0
}

cleared=0
if [ "$error" = subagent_limit ]; then
  transcript=$(find_transcript)
  [ -n "$transcript" ] || exit 0

  scan=$(scan_transcript "$transcript")
  failed_at=${scan% *}
  cleared=${scan#* }
  case "$failed_at" in
    '' | 0 | *[!0-9]*) exit 0 ;;
  esac
  case "$cleared" in
    0 | 1) ;;
    *) cleared=0 ;;
  esac

  age=$((now - failed_at))
  [ "$age" -ge 0 ] && [ "$age" -le "$STOP_WINDOW" ] || exit 0

  nudge_budget_ok || exit 0
fi

if [ "$cleared" = 1 ]; then
  resets_at=$now
else
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
fi

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
