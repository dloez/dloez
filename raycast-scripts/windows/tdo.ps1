# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title tdo
# @raycast.mode fullOutput
# @raycast.argument1 { "type": "text", "placeholder": "add Buy milk --today, done 3, view inbox ..." }

# Optional parameters:
# @raycast.icon ·
# @raycast.packageName tdo

wsl.exe bash -c "`$HOME/.cargo/bin/tdo $($args[0])"
