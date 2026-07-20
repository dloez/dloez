_zdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d "${_zdump:h}" ]] || mkdir -p "${_zdump:h}"

autoload -Uz compinit
if [[ -s $_zdump ]]; then
  compinit -C -d "$_zdump"
  [[ ${_zdump}.zwc -nt $_zdump ]] || zcompile -R -- "${_zdump}.zwc" "$_zdump" 2>/dev/null
  _zdump_stale=($_zdump(Nmh+24))
  (( $#_zdump_stale )) && { compinit -d "$_zdump" && touch "$_zdump" && zcompile -R -- "${_zdump}.zwc" "$_zdump" } &!
else
  compinit -d "$_zdump"
  zcompile -R -- "${_zdump}.zwc" "$_zdump" 2>/dev/null
fi
unset _zdump _zdump_stale

setopt complete_in_word always_to_end

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{242}%d%f'
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
