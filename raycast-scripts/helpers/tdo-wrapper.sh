#!/bin/zsh
export DISABLE_AUTO_TITLE="true"
printf '\033]0;Tasks\033\\'
/Users/dloez/.cargo/bin/tdo
printf '\033]0;Tasks\033\\'
exec zsh
