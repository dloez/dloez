_cursor_shape=$'\e[4 q'

_cursor_apply() { print -n "$_cursor_shape" > /dev/tty; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _cursor_apply
