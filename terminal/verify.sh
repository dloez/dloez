#!/usr/bin/env sh

set -u

REPO="${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
fail=0

check() {
  desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'PASS  %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"
    fail=1
  fi
}

link_into_repo() {
  target=$(readlink "$1" 2>/dev/null) || return 1
  case "$target" in
    "$REPO"/*) return 0 ;;
    *) return 1 ;;
  esac
}

current_shell() {
  user=$(id -un)
  if command -v getent >/dev/null 2>&1; then
    getent passwd "$user" | cut -d: -f7
  elif command -v dscl >/dev/null 2>&1; then
    dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}'
  else
    printf '%s\n' "${SHELL:-}"
  fi
}

check "git installed"      command -v git
check "curl installed"     command -v curl
check "zsh installed"      command -v zsh
check "starship installed" test -x "$HOME/.local/bin/starship"

for f in .zshrc \
         .config/starship.toml \
         .config/starship-fast.toml \
         .config/zsh/cursor.zsh \
         .config/zsh/perf.zsh \
         .config/zsh/async-prompt.zsh \
         .config/zsh/transient-prompt.zsh; do
  check "symlink $f" link_into_repo "$HOME/$f"
done

check "plugin zsh-autosuggestions"     test -d "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/.git"
check "plugin zsh-syntax-highlighting" test -d "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/.git"

if [ "${INSTALL_CLAUDE_SKILLS:-}" = "1" ] && [ -d "$REPO/.claude/skills" ]; then
  for d in "$REPO"/.claude/skills/*/; do
    [ -d "$d" ] || continue
    s=$(basename "$d")
    check "skill symlink .claude/skills/$s" link_into_repo "$HOME/.claude/skills/$s"
  done
fi

zsh_path=$(command -v zsh || echo zsh)
check "default shell is zsh" test "$(current_shell)" = "$zsh_path"
check "zsh sources config cleanly" zsh -i -c 'command -v starship >/dev/null'

echo "-- second install (idempotency) --"
if out=$(sh "$REPO/terminal/install.sh" 2>&1); then
  if printf '%s\n' "$out" | grep -q 'starship already installed'; then
    echo "PASS  re-run reuses existing starship"
  else
    echo "FAIL  re-run reinstalled starship"
    fail=1
  fi
else
  echo "FAIL  re-run exited non-zero"
  printf '%s\n' "$out"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED"
fi
exit "$fail"
