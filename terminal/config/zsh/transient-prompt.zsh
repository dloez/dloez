_transient_prompt='%F{242}❯%f '

zle-line-init() {
  emulate -L zsh

  [[ $CONTEXT == start ]] || return 0

  while true; do
    zle .recursive-edit
    local -i ret=$?
    [[ $ret == 0 && $KEYS == $'\4' ]] || break
    [[ -o ignore_eof ]] || exit 0
  done

  local saved_prompt=$PROMPT
  local saved_rprompt=$RPROMPT
  print -n $'\e[?2026h\e[?25l' > /dev/tty
  PROMPT=$_transient_prompt
  RPROMPT=''
  zle .reset-prompt
  PROMPT=$saved_prompt
  RPROMPT=$saved_rprompt
  print -n $'\e[?25h\e[?2026l' > /dev/tty

  if (( ret )); then
    zle .send-break
  else
    zle .accept-line
  fi
  return ret
}
zle -N zle-line-init
