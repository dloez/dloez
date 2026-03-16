#!/bin/zsh
export DISABLE_AUTO_TITLE="true"
printf '\033]0;[Today] Tasks\033\\'
watch -n 1 /Users/dloez/.cargo/bin/tdo view today
