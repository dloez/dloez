_zdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d "${_zdump:h}" ]] || mkdir -p "${_zdump:h}"

autoload -Uz compinit
_zdump_fresh=("$_zdump"(Nmh-24))
if (( $#_zdump_fresh )); then
  compinit -C -d "$_zdump"
else
  compinit -d "$_zdump"
fi
unset _zdump _zdump_fresh

setopt complete_in_word always_to_end

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{242}%d%f'
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
