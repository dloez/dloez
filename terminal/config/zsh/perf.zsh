# Performance tuning for zsh plugins.
# NOTE: these must be sourced BEFORE zsh-autosuggestions / zsh-syntax-highlighting.

# zsh-autosuggestions
ZSH_AUTOSUGGEST_MANUAL_REBIND=1     # don't rebind widgets every prompt (big speedup)
ZSH_AUTOSUGGEST_USE_ASYNC=1         # compute suggestions in the background
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20  # skip suggestions for very long lines

# zsh-syntax-highlighting
ZSH_HIGHLIGHT_MAXLENGTH=512         # don't highlight huge pastes
