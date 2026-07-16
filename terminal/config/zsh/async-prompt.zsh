unsetopt prompt_subst

_async_prompt_config="${XDG_CONFIG_HOME:-$HOME/.config}/starship-fast.toml"
_async_prompt_fd=0
_async_prompt_sep=$'\x1f'

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

  PROMPT="$(STARSHIP_CONFIG=$_async_prompt_config starship prompt "${flags[@]}")"
  RPROMPT=""

  if (( _async_prompt_fd )); then
    zle -F "$_async_prompt_fd" 2>/dev/null
    exec {_async_prompt_fd}<&-
    _async_prompt_fd=0
  fi

  exec {_async_prompt_fd}< <(
    {
      starship prompt "${flags[@]}"; printf '%s' "$_async_prompt_sep"
      starship prompt --right "${flags[@]}"; printf '%s' "$_async_prompt_sep"
    } 2>/dev/null
  )
  zle -F "$_async_prompt_fd" _async_prompt_ready
}

_async_prompt_ready() {
  local fd=$1 left right
  zle -F "$fd" 2>/dev/null
  IFS= read -r -u "$fd" -d "$_async_prompt_sep" left
  IFS= read -r -u "$fd" -d "$_async_prompt_sep" right
  exec {fd}<&-
  _async_prompt_fd=0
  [[ $left == "$PROMPT" && $right == "$RPROMPT" ]] && return 0
  PROMPT="$left"
  RPROMPT="$right"
  print -n $'\e[?2026h\e[?25l' > /dev/tty
  zle reset-prompt
  print -n $'\e[?25h\e[?2026l' > /dev/tty
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _async_prompt_precmd
