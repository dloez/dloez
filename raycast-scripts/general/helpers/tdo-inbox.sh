#!/bin/bash
export DISABLE_AUTO_TITLE="true"
printf '\033]0;[Inbox] Tasks\033\\'
watch -n 1 "$HOME/.cargo/bin/tdo" view inbox
