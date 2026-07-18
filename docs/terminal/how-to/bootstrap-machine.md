# Bootstrap a machine

Set up the full zsh environment on a fresh Linux, macOS, or WSL machine with one command.

## Prerequisites

- A Linux, macOS, or WSL machine with internet access.
- `git`, `curl`, and `zsh` — or the ability to install them: root/`sudo`, or Homebrew on macOS. The installer installs any that are missing; if it cannot (no root and no Homebrew), it stops and tells you which to install.

## Steps

1. Run the bootstrap:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/dloez/dloez/main/terminal/install.sh | sh
   ```

   The installer is idempotent (safe to re-run) and prints only its own `==>` progress lines — underlying command output is captured and shown only on failure. It:

   1. Installs any missing deps (`git`, `curl`, `zsh`) via the system package manager (`apt`, `dnf`, `pacman`, `zypper`, `apk`, or Homebrew), using `sudo` when not run as root.
   2. Installs [starship](https://starship.rs) into `~/.local/bin` if missing.
   3. Clones/updates the zsh plugins into `~/.local/share/zsh/plugins`.
   4. Installs [fzf](https://github.com/junegunn/fzf) and [herdr](https://herdr.dev) into `~/.local/bin` if missing.
   5. Symlinks each config file into place, backing up any pre-existing real file to `<file>.bak.<timestamp>`. See the [symlink map](../reference/layout-and-testing.md).
   6. Sets zsh as the default login shell (`chsh`), if it isn't already.
   7. On WSL, configures the font and Windows Terminal on the host — see [WSL host setup](../explanation/wsl-host-setup.md).
   8. Installs a recent Neovim into `~/.local` and clones the personal kickstart fork (`dloez/kickstart.nvim`) into `~/.config/nvim` if absent (part of the default setup; an existing config is left untouched).
   9. Asks whether to set up the Claude Code layer — the essential skills (`.claude/skills/essential-skills.txt`) plus the nvim learning loop (opt-in). Answer `y` at the prompt, or set `INSTALL_CLAUDE=1` to run it without prompting. Skipped silently when there is no terminal to prompt on. See the [Claude Code setup](../reference/layout-and-testing.md).

2. Restart your shell to pick up the new setup:

   ```sh
   exec zsh
   ```

   Or log out and back in to pick up zsh as the default login shell.

## curl vs. checkout

- **Piped from `curl`** (the command above): the installer first clones the repo to `~/.local/share/dloez` and symlinks from there.
- **From an existing checkout** (`sh terminal/install.sh`): it links directly from that checkout, so edits to a config file are live in your shell immediately.

## Verification

- Assert the whole install:

  ```sh
  sh terminal/verify.sh
  ```

- Or eyeball it: open a new shell and confirm the starship prompt renders with correct Nerd Font glyphs (branch/status icons, no missing-glyph boxes).

---

Up: [Terminal](../index.md)
