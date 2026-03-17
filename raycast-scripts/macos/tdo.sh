#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title tdo
# @raycast.mode fullOutput
# @raycast.argument1 { "type": "text", "placeholder": "add Buy milk --today, done 3, view inbox ..." }

# Optional parameters:
# @raycast.icon ·
# @raycast.packageName tdo

eval "$HOME/.cargo/bin/tdo" $1
