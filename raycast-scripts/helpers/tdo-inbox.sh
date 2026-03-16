#!/bin/zsh
export DISABLE_AUTO_TITLE="true"
printf '\033]0;[Inbox] Tasks\033\\'
watch -n 1 /Users/dloez/.cargo/bin/tdo view inbox
