#!/usr/bin/env sh
# install.sh — portable terminal/dotfiles setup (no oh-my-zsh, no brew required).
#
# Installs: starship prompt, zsh-autosuggestions, zsh-syntax-highlighting.
# Symlinks the config files under config/ into their canonical $HOME locations.
# Safe to re-run: every step is idempotent.
#
# Bootstrap a fresh machine with:
#   curl -fsSL https://raw.githubusercontent.com/dloez/dloez/main/terminal/install.sh | sh

set -eu

REPO_URL="https://github.com/dloez/dloez.git"
# Where the repo is cloned when this script is run standalone (e.g. via curl).
MANAGED_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dloez"
PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# --- helpers ----------------------------------------------------------------

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; }

# Fail early with a clear message if a required command is missing.
require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "'$1' is required but not installed. Please install it and re-run."
    exit 1
  fi
}

# Clone a repo if missing, otherwise pull the latest.
clone_or_update() {
  url="$1"
  dest="$2"
  if [ -d "$dest/.git" ]; then
    info "Updating $(basename "$dest")"
    git -C "$dest" pull --ff-only --quiet
  else
    info "Cloning $(basename "$dest")"
    git clone --depth 1 --quiet "$url" "$dest"
  fi
}

# Locate the checkout this script is running from, if any. Prints the repo root
# on success. Fails when piped through curl (no script file on disk).
find_repo_root() {
  script="$0"
  case "$script" in
    */*) : ;;        # looks like a path — resolvable
    *)   return 1 ;; # bare name (piped via curl) — nothing to resolve
  esac
  [ -f "$script" ] || return 1
  dir=$(CDPATH= cd -- "$(dirname -- "$script")" && pwd) || return 1
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/terminal/config" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname -- "$dir")
  done
  return 1
}

# Symlink a repo file into place, backing up any pre-existing real file.
# Only ever links individual FILES (never directories), so unmanaged files
# living alongside them in $HOME stay independent and untracked.
link_file() {
  src="$1"
  dest="$2"
  mkdir -p "$(dirname -- "$dest")"

  # Already the correct link — nothing to do.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    info "ok:     ${dest#"$HOME"/}"
    return 0
  fi

  # Something else is there (real file, or a link elsewhere) — back it up.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    info "backup: ${dest#"$HOME"/} -> ${backup#"$HOME"/}"
    mv -- "$dest" "$backup"
  fi

  ln -s "$src" "$dest"
  info "linked: ${dest#"$HOME"/}"
}

# --- prerequisites ----------------------------------------------------------

require git
require curl

# --- resolve source of the config files -------------------------------------

if REPO_ROOT=$(find_repo_root); then
  info "Using existing checkout: $REPO_ROOT"
else
  clone_or_update "$REPO_URL" "$MANAGED_DIR"
  REPO_ROOT="$MANAGED_DIR"
fi
CONFIG_DIR="$REPO_ROOT/terminal/config"

# --- starship ---------------------------------------------------------------

if command -v starship >/dev/null 2>&1; then
  info "starship already installed ($(command -v starship))"
else
  info "Installing starship"
  # Official installer; -y skips the confirmation prompt.
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- plugins ----------------------------------------------------------------

mkdir -p "$PLUGIN_DIR"
clone_or_update https://github.com/zsh-users/zsh-autosuggestions \
  "$PLUGIN_DIR/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting \
  "$PLUGIN_DIR/zsh-syntax-highlighting"

# --- symlink config files ---------------------------------------------------

info "Linking config files"
link_file "$CONFIG_DIR/zshrc"                     "$HOME/.zshrc"
link_file "$CONFIG_DIR/starship.toml"             "$CONFIG_HOME/starship.toml"
link_file "$CONFIG_DIR/zsh/perf.zsh"              "$CONFIG_HOME/zsh/perf.zsh"
link_file "$CONFIG_DIR/zsh/transient-prompt.zsh"  "$CONFIG_HOME/zsh/transient-prompt.zsh"

info "Done. Restart your shell or run: exec zsh"
