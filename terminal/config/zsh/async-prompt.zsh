unsetopt prompt_subst
autoload -Uz add-zsh-hook

_async_prompt_fd=0
_async_prompt_sep=$'\x1f'
_async_prompt_trunc=3

_async_prompt_dir() {
  emulate -L zsh
  local p=$PWD logical d=$PWD root=''

  while [[ $d == /* && $d != / ]]; do
    [[ -e $d/.git ]] && { root=$d; break }
    d=${d:h}
  done

  if [[ -n $root ]]; then
    local parent=${root:h}
    [[ $parent == / ]] && logical=${p#/} || logical=${p#$parent/}
  elif [[ $p == $HOME ]]; then
    logical='~'
  elif [[ $p == $HOME/* ]]; then
    logical="~/${p#$HOME/}"
  else
    logical=$p
  fi

  local -a parts=(${(s:/:)logical})
  local shown
  if (( ${#parts} > _async_prompt_trunc )); then
    shown=${(j:/:)parts[-_async_prompt_trunc,-1]}
  elif [[ $logical == / ]]; then
    shown=/
  else
    shown=${(j:/:)parts}
    [[ $logical == /* ]] && shown="/$shown"
  fi

  REPLY=$'%{\e[1;36m%}'$shown$'%{\e[0m%}'
  [[ -w $PWD ]] || REPLY+=$'%{\e[31m%}🔒%{\e[0m%}'
  REPLY+=' '
}

_async_prompt_char() {
  emulate -L zsh
  if [[ ${KEYMAP:-} == vicmd ]]; then
    REPLY=$'%{\e[1;32m%}❮%{\e[0m%} '
  elif [[ ${STARSHIP_CMD_STATUS:-0} == 0 ]]; then
    REPLY=$'%{\e[1;32m%}❯%{\e[0m%} '
  else
    REPLY=$'%{\e[1;31m%}❯%{\e[0m%} '
  fi
}

_async_prompt_flags() {
  _async_prompt_reply=(
    --terminal-width="$COLUMNS"
    --keymap="${KEYMAP:-}"
    --status="${STARSHIP_CMD_STATUS:-}"
    --pipestatus="${STARSHIP_PIPE_STATUS[*]:-}"
    --cmd-duration="${STARSHIP_DURATION:-}"
    --jobs="${STARSHIP_JOBS_COUNT:-0}"
  )
}

_async_prompt_precmd() {
  local -a flags
  _async_prompt_flags; flags=("${_async_prompt_reply[@]}")

  local REPLY dir char
  _async_prompt_dir; dir=$REPLY
  _async_prompt_char; char=$REPLY
  PROMPT=$'\n'$dir$'\n'$char
  RPROMPT=''

  if (( _async_prompt_fd )); then
    zle -F "$_async_prompt_fd" 2>/dev/null
    exec {_async_prompt_fd}<&-
    _async_prompt_fd=0
  fi

  exec {_async_prompt_fd}< <(
    { starship prompt "${flags[@]}"; printf '%s' "$_async_prompt_sep"; } 2>/dev/null
  )
  zle -F "$_async_prompt_fd" _async_prompt_ready
}

_async_prompt_ready() {
  local fd=$1 full
  zle -F "$fd" 2>/dev/null
  IFS= read -r -u "$fd" -d "$_async_prompt_sep" full
  exec {fd}<&-
  _async_prompt_fd=0

  [[ $full == "$PROMPT" ]] && return 0
  PROMPT=$full
  RPROMPT=''
  print -n $'\e[?2026h\e[?25l' > /dev/tty
  zle reset-prompt
  print -n $'\e[?25h\e[?2026l' > /dev/tty
}

add-zsh-hook precmd _async_prompt_precmd
