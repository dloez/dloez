#!/usr/bin/env sh

set -eu

REPO_URL="https://github.com/dloez/dloez.git"
MANAGED_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dloez"
PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

export PATH="$HOME/.local/bin:$PATH"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mWarn:\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; }

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

can_root() {
  [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1
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

pkg_install() {
  if command -v apt-get >/dev/null 2>&1; then
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq \
      && run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y -q "$@"
  elif command -v pacman >/dev/null 2>&1; then
    run_root pacman -Sy --noconfirm "$@"
  elif command -v zypper >/dev/null 2>&1; then
    run_root zypper --non-interactive --quiet install "$@"
  elif command -v apk >/dev/null 2>&1; then
    run_root apk add --quiet "$@"
  elif command -v brew >/dev/null 2>&1; then
    brew install "$@"
  else
    return 1
  fi
}

ensure_deps() {
  set --
  for c in git curl zsh; do
    command -v "$c" >/dev/null 2>&1 || set -- "$@" "$c"
  done
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  if ! can_root && ! command -v brew >/dev/null 2>&1; then
    err "missing: $* — need root/sudo or Homebrew to install them. Install and re-run."
    exit 1
  fi
  info "Installing dependencies: $*"
  dep_log=$(mktemp)
  if pkg_install "$@" >"$dep_log" 2>&1; then
    rm -f "$dep_log"
  else
    err "failed to install: $*"
    cat "$dep_log" >&2
    rm -f "$dep_log"
    exit 1
  fi
}

set_default_shell() {
  zsh_path=$(command -v zsh) || return 0
  if [ "$(current_shell)" = "$zsh_path" ]; then
    return 0
  fi
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    printf '%s\n' "$zsh_path" | run_root tee -a /etc/shells >/dev/null 2>&1 || true
  fi
  if run_root chsh -s "$zsh_path" "$(id -un)" >/dev/null 2>&1; then
    info "Default shell set to zsh — restart your session to take effect"
  else
    warn "Could not set default shell automatically; run: chsh -s $zsh_path"
  fi
}

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

find_repo_root() {
  script="$0"
  case "$script" in
    */*) : ;;
    *)   return 1 ;;
  esac
  [ -f "$script" ] || return 1
  dir=$(CDPATH='' cd -- "$(dirname -- "$script")" && pwd) || return 1
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/terminal/config" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname -- "$dir")
  done
  return 1
}

link_file() {
  src="$1"
  dest="$2"
  mkdir -p "$(dirname -- "$dest")"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    info "ok:     ${dest#"$HOME"/}"
    return 0
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    info "backup: ${dest#"$HOME"/} -> ${backup#"$HOME"/}"
    mv -- "$dest" "$backup"
  fi

  ln -s "$src" "$dest"
  info "linked: ${dest#"$HOME"/}"
}

setup_windows() {
  grep -qi microsoft /proc/version 2>/dev/null || return 0
  if ! command -v powershell.exe >/dev/null 2>&1; then
    warn "WSL detected but powershell.exe is unavailable — skipping Windows font/terminal setup"
    return 0
  fi

  info "WSL detected — configuring JetBrainsMono Nerd Font + Windows Terminal on the host"

  ps_dir=$(dirname "$(command -v powershell.exe)")
  wintmp=$(cd "$ps_dir" && powershell.exe -NoProfile -Command "[Console]::Out.Write(\$env:TEMP)" 2>/dev/null || true)
  wintmp_u=""
  if [ -n "$wintmp" ]; then
    wintmp_u=$(wslpath -u "$wintmp" 2>/dev/null || true)
  fi
  if [ -z "$wintmp_u" ] || [ ! -d "$wintmp_u" ] || [ ! -w "$wintmp_u" ]; then
    warn "could not resolve a writable Windows temp dir — skipping Windows font/terminal setup"
    return 0
  fi

  ps1="$wintmp_u/dotfiles-wt-setup.$$.ps1"
  stf="$wintmp_u/dotfiles-wt-status.$$"
  : >"$stf"
  cat >"$ps1" <<'PS'
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sp  = $env:DOTFILES_STATUS
$out = @()
$ok  = $true
try {
    $face  = 'JetBrainsMono Nerd Font'
    $size  = 11.5
    $scheme = 'Dark+'
    $glob  = 'JetBrainsMonoNerdFont*.ttf'
    $asset = 'JetBrainsMono.zip'

    $fontDirs = @("$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts")
    if (@(Get-ChildItem -Path $fontDirs -Filter $glob -ErrorAction SilentlyContinue).Count -gt 0) {
        $out += 'font: already installed'
    } else {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -Headers @{ 'User-Agent' = 'dotfiles' }
        $url = ($rel.assets | Where-Object { $_.name -eq $asset }).browser_download_url
        if (-not $url) { throw "could not find $asset in the latest nerd-fonts release" }
        $tmp = Join-Path $env:TEMP ('nf-jbm-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $zip = Join-Path $tmp $asset
        Invoke-WebRequest -Uri $url -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $userFonts = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Force -Path $userFonts | Out-Null
        $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        foreach ($ttf in (Get-ChildItem -Path $tmp -Filter '*.ttf')) {
            $dest = Join-Path $userFonts $ttf.Name
            Copy-Item -Path $ttf.FullName -Destination $dest -Force
            New-ItemProperty -Path $reg -Name ($ttf.BaseName + ' (TrueType)') -Value $dest -PropertyType String -Force | Out-Null
        }
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $out += 'font: installed'
    }

    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $settings = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $settings) {
        $out += 'terminal: settings.json not found - skipped'
    } else {
        $json = Get-Content -Raw -Encoding UTF8 -Path $settings | ConvertFrom-Json
        $targets = @($json.profiles.list | Where-Object {
            $_.source -eq 'Microsoft.WSL' -or $_.source -eq 'Windows.Terminal.Wsl' -or $_.name -like '*Ubuntu*'
        })
        $scope = 'WSL profile(s)'
        if ($targets.Count -eq 0) { $targets = @($json.profiles.defaults); $scope = 'profiles.defaults' }

        $changed = $false
        foreach ($p in $targets) {
            if (-not $p) { continue }
            if (-not $p.PSObject.Properties['font']) {
                $p | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{})
            }
            if ($p.font.PSObject.Properties['face']) {
                if ($p.font.face -ne $face) { $p.font.face = $face; $changed = $true }
            } else {
                $p.font | Add-Member -NotePropertyName face -NotePropertyValue $face
                $changed = $true
            }
            if ($p.font.PSObject.Properties['size']) {
                if ($p.font.size -ne $size) { $p.font.size = $size; $changed = $true }
            } else {
                $p.font | Add-Member -NotePropertyName size -NotePropertyValue $size
                $changed = $true
            }
            if ($p.PSObject.Properties['colorScheme']) {
                if ($p.colorScheme -ne $scheme) { $p.colorScheme = $scheme; $changed = $true }
            } else {
                $p | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme
                $changed = $true
            }
        }

        if (-not $changed) {
            $out += "terminal: profile already set on $scope"
        } else {
            $bak = $settings + '.bak.' + (Get-Date -Format 'yyyyMMddHHmmss')
            Copy-Item -Path $settings -Destination $bak -Force
            $ser = $json | ConvertTo-Json -Depth 32
            $ser = [regex]::Replace($ser, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
            [System.IO.File]::WriteAllText($settings, $ser, (New-Object System.Text.UTF8Encoding($false)))
            $out += "terminal: profile set on $scope (backup: $([System.IO.Path]::GetFileName($bak)))"
        }
    }
} catch {
    $out += "error: $($_.Exception.Message)"
    $ok = $false
}
if (-not [string]::IsNullOrEmpty($sp)) { Set-Content -Path $sp -Value $out -Encoding Ascii }
if (-not $ok) { exit 1 }
PS
  ps1_w=$(wslpath -w "$ps1")

  if ( cd "$ps_dir" && DOTFILES_STATUS="$stf" WSLENV="DOTFILES_STATUS/p${WSLENV:+:$WSLENV}" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1_w" ) >/dev/null 2>&1
  then
    if [ -s "$stf" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && info "  $line"
      done <"$stf"
    else
      info "  font + Windows Terminal profile configured"
    fi
  else
    warn "Windows-side setup did not complete cleanly:"
    if [ -s "$stf" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && printf '    %s\n' "$line" >&2
      done <"$stf"
    fi
  fi
  rm -f "$stf" "$ps1"
}

link_skills() {
  skills_src="$REPO_ROOT/.claude/skills"
  [ -d "$skills_src" ] || return 0
  info "Linking Claude Code skills into ~/.claude/skills"
  for skill in "$skills_src"/*/; do
    [ -d "$skill" ] || continue
    link_file "${skill%/}" "$HOME/.claude/skills/$(basename "$skill")"
  done
}

setup_skills() {
  case "${INSTALL_CLAUDE_SKILLS:-ask}" in
    1 | y | Y | yes | YES | true | TRUE)
      link_skills
      ;;
    ask)
      if (exec </dev/tty) 2>/dev/null; then
        printf '\033[1;34m==>\033[0m Link Claude Code skills into ~/.claude/skills? [y/N] ' >/dev/tty
        read -r reply </dev/tty || reply=""
        case "$reply" in
          y | Y | yes | YES) link_skills ;;
        esac
      fi
      ;;
  esac
}

ensure_deps

if REPO_ROOT=$(find_repo_root); then
  info "Using existing checkout: $REPO_ROOT"
else
  clone_or_update "$REPO_URL" "$MANAGED_DIR"
  REPO_ROOT="$MANAGED_DIR"
fi
CONFIG_DIR="$REPO_ROOT/terminal/config"

if command -v starship >/dev/null 2>&1; then
  info "starship already installed ($(command -v starship))"
else
  info "Installing starship"
  mkdir -p "$HOME/.local/bin"
  ss_log=$(mktemp)
  ss_script=$(mktemp)
  if curl -fsSL https://starship.rs/install.sh -o "$ss_script" 2>"$ss_log" \
     && sh "$ss_script" -y -b "$HOME/.local/bin" >>"$ss_log" 2>&1; then
    rm -f "$ss_log" "$ss_script"
  else
    err "starship install failed:"
    cat "$ss_log" >&2
    rm -f "$ss_log" "$ss_script"
    exit 1
  fi
fi

mkdir -p "$PLUGIN_DIR"
clone_or_update https://github.com/zsh-users/zsh-autosuggestions \
  "$PLUGIN_DIR/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting \
  "$PLUGIN_DIR/zsh-syntax-highlighting"

info "Linking config files"
link_file "$CONFIG_DIR/zshrc"                     "$HOME/.zshrc"
link_file "$CONFIG_DIR/starship.toml"             "$CONFIG_HOME/starship.toml"
link_file "$CONFIG_DIR/starship-fast.toml"        "$CONFIG_HOME/starship-fast.toml"
link_file "$CONFIG_DIR/zsh/cursor.zsh"            "$CONFIG_HOME/zsh/cursor.zsh"
link_file "$CONFIG_DIR/zsh/perf.zsh"              "$CONFIG_HOME/zsh/perf.zsh"
link_file "$CONFIG_DIR/zsh/async-prompt.zsh"      "$CONFIG_HOME/zsh/async-prompt.zsh"
link_file "$CONFIG_DIR/zsh/transient-prompt.zsh"  "$CONFIG_HOME/zsh/transient-prompt.zsh"

set_default_shell

setup_windows

setup_skills

info "Done. Restart your shell or run: exec zsh"
