#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Tasks
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📋
# @raycast.packageName Ghostty

# Check if a Ghostty window with "Tasks" title exists
WINDOW_EXISTS=$(osascript -e '
try
    tell application "Ghostty"
        repeat with w in windows
            if name of w is "Tasks" then
                return true
            end if
        end repeat
    end tell
end try
return false
' 2>/dev/null || echo "false")

if [ "$WINDOW_EXISTS" = "true" ]; then
    osascript -e 'tell application "Ghostty" to activate'
else
    # Remember PIDs before
    PIDS_BEFORE=$(pgrep -x ghostty | sort)

    open -na "Ghostty" --args -e /Users/dloez/Workspace/dloez/raycast-scripts/helpers/tdo-wrapper.sh
    sleep 0.5

    # Find the new PID
    PIDS_AFTER=$(pgrep -x ghostty | sort)
    NEW_PID=$(comm -13 <(echo "$PIDS_BEFORE") <(echo "$PIDS_AFTER"))

    if [ -n "$NEW_PID" ]; then
        # Position using the new PID
        osascript -e '
        tell application "System Events"
            set targetPID to '"$NEW_PID"'
            repeat with p in every process whose unix id is targetPID
                set position of window 1 of p to {2560, 970}
                set size of window 1 of p to {2560, 470}
            end repeat
        end tell
        '
    fi
fi
