#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Tasks
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📋
# @raycast.packageName Ghostty

HELPERS="/Users/dloez/Workspace/dloez/raycast-scripts/helpers"

# Check if Tasks windows already exist
TASKS_EXIST=$(osascript -e '
try
    tell application "Ghostty"
        repeat with w in windows
            if name of w is "[Today] Tasks" or name of w is "[Inbox] Tasks" then
                return true
            end if
        end repeat
    end tell
end try
return false
' 2>/dev/null || echo "false")

if [ "$TASKS_EXIST" = "true" ]; then
    osascript -e 'tell application "Ghostty" to activate'
else
    PIDS_BEFORE=$(pgrep -x ghostty | sort)

    # Launch both windows
    open -na "Ghostty" --args -e "$HELPERS/tdo-today.sh"
    open -na "Ghostty" --args -e "$HELPERS/tdo-inbox.sh"
    sleep 0.5

    # Find new PIDs (first = today, second = inbox)
    PIDS_AFTER=$(pgrep -x ghostty | sort)
    NEW_PIDS=$(comm -13 <(echo "$PIDS_BEFORE") <(echo "$PIDS_AFTER"))
    PID_ARRAY=($NEW_PIDS)

    if [ ${#PID_ARRAY[@]} -ge 2 ]; then
        # Today = left half of bottom third
        osascript -e '
        tell application "System Events"
            repeat with p in every process whose unix id is '"${PID_ARRAY[0]}"'
                set position of window 1 of p to {2560, 970}
                set size of window 1 of p to {1280, 470}
            end repeat
        end tell
        '
        # Inbox = right half of bottom third
        osascript -e '
        tell application "System Events"
            repeat with p in every process whose unix id is '"${PID_ARRAY[1]}"'
                set position of window 1 of p to {3840, 970}
                set size of window 1 of p to {1280, 470}
            end repeat
        end tell
        '
    fi
fi
