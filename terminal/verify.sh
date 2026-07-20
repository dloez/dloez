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
check "fzf installed"      test -x "$HOME/.local/bin/fzf"
check "herdr installed"    test -x "$HOME/.local/bin/herdr"
check "nvim installed"     test -x "$HOME/.local/bin/nvim"
check "nvim config present" test -d "$HOME/.config/nvim"

for f in .zshrc \
         .config/starship.toml \
         .config/starship-fast.toml \
         .config/zsh/cursor.zsh \
         .config/zsh/perf.zsh \
         .config/zsh/completion.zsh \
         .config/zsh/history-search.zsh \
         .config/zsh/async-prompt.zsh \
         .config/zsh/transient-prompt.zsh \
         .config/herdr/config.toml; do
  check "symlink $f" link_into_repo "$HOME/$f"
done

check "plugin zsh-autosuggestions"     test -d "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/.git"
check "plugin zsh-syntax-highlighting" test -d "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/.git"

if [ "${INSTALL_CLAUDE:-}" = "1" ]; then
  if [ -d "$REPO/.claude/skills" ]; then
    skills_list="$REPO/.claude/skills/essential-skills.txt"
    if [ -f "$skills_list" ]; then
      tmp_skills=$(mktemp)
      sed -e 's/#.*//' -e 's/[[:space:]]//g' "$skills_list" | grep -v '^$' >"$tmp_skills" || true
      while IFS= read -r s; do
        check "skill symlink .claude/skills/$s" link_into_repo "$HOME/.claude/skills/$s"
      done <"$tmp_skills"
      rm -f "$tmp_skills"
    fi
  fi
  check "nvim learning plugin present"  test -f "$HOME/.config/nvim/plugin/learning.lua"
  check "learning loop enabled"         test -f "$HOME/.config/nvim/.learning-enabled"
fi

zsh_path=$(command -v zsh || echo zsh)
check "default shell is zsh" test "$(current_shell)" = "$zsh_path"
check "zsh sources config cleanly" zsh -i -c 'command -v starship >/dev/null'

paint_matches_starship_fast() {
  command -v zsh >/dev/null 2>&1 || return 0
  test -x "$HOME/.local/bin/starship" || return 0
  test -f "$HOME/.config/starship-fast.toml" || return 0
  test -f "$HOME/.config/zsh/async-prompt.zsh" || return 0
  zsh -f <<'ZEOF'
emulate -L zsh
export PATH="$HOME/.local/bin:$PATH"
source "$HOME/.config/zsh/async-prompt.zsh"
fc="$HOME/.config/starship-fast.toml"
paint() {
  local REPLY dir char
  _async_prompt_dir; dir=$REPLY
  _async_prompt_char; char=$REPLY
  print -rn -- $'\n'$dir$'\n'$char
}
repo="$HOME/.cache/starship-drift-check"
rm -rf "$repo"; mkdir -p "$repo/inner/deep"
(cd "$repo" && git init -q) 2>/dev/null
dirs=( "$HOME" / /usr/share /etc /tmp "$repo" "$repo/inner/deep" )
fails=0
for d in $dirs; do
  [[ -d $d ]] || continue
  cd $d || continue
  for st in 0 1; do
    STARSHIP_CMD_STATUS=$st
    [[ "$(paint)" == "$(STARSHIP_SHELL=zsh STARSHIP_CONFIG=$fc starship prompt --terminal-width=120 --status=$st)" ]] || (( fails++ ))
  done
done
rm -rf "$repo"
exit $(( fails > 0 ))
ZEOF
}
check "instant paint matches starship-fast" paint_matches_starship_fast

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
