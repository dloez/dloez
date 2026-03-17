#!/bin/bash
export DISABLE_AUTO_TITLE="true"
printf '\033]0;[Today] Tasks\033\\'
watch -n 1 "$HOME/.cargo/bin/tdo" view today
