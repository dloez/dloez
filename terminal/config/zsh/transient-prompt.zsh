# Transient prompt (powerlevel10k-style) for starship + zsh.
# After a command runs, collapse its prompt to a minimal arrow to keep
# scrollback clean. Uses the recursive-edit technique.

# Single line with no leading blank, matching starship's `add_newline = false`,
# so the prompt keeps the same vertical footprint when it collapses (no jump).
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
  PROMPT=$_transient_prompt
  RPROMPT=''
  zle .reset-prompt
  PROMPT=$saved_prompt
  RPROMPT=$saved_rprompt

  if (( ret )); then
    zle .send-break
  else
    zle .accept-line
  fi
  return ret
}
zle -N zle-line-init
