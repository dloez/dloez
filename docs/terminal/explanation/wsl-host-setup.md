# WSL host setup

On WSL the installer's `setup_windows` step reaches out of Linux and configures the **Windows host**. This document explains why that is necessary and the interop constraints that shaped how it is done.

## Why touch the Windows side at all

The prompt is drawn by the terminal emulator, which on WSL is a Windows application (Windows Terminal) using a Windows font. starship's prompt relies on Nerd Font glyphs. No amount of Linux-side configuration makes those glyphs render — the font must exist on Windows and the terminal profile must select it. So the fix has to happen on the host.

## What it does

- **Installs JetBrainsMono Nerd Font per-user.** Fonts are copied into `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and registered under `HKCU`. A per-user install needs **no admin rights and triggers no UAC prompt** — a machine-wide install would. It downloads the font from the latest `ryanoasis/nerd-fonts` release.
- **Configures Windows Terminal's WSL profile.** It finds the WSL profile(s) in `settings.json` (by `source` of `Microsoft.WSL` / `Windows.Terminal.Wsl`, or a name like `*Ubuntu*`), falling back to `profiles.defaults`, and sets `font.face` (JetBrainsMono Nerd Font), `font.size` (`11.5`), and `colorScheme` (`Dark+`, a built-in Windows Terminal scheme, so it need not be defined in `settings.json`). It backs up `settings.json` before writing.

Both halves are **idempotent**: the font is skipped if already present, and the profile edit is skipped when the face, size, and colour scheme already match.

## Interop constraints that shaped it

WSL↔Windows interop is narrow and quoting-hostile, which drove three deliberate choices:

- **A temp `.ps1` run with `-File`, not `-Command`.** Piping a script body over stdin or `-Command` through interop is fragile — quoting and encoding mangle it. The installer writes the PowerShell to a temp `.ps1` on the Windows temp dir, resolves its Windows path with `wslpath -w`, and runs `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>`. A real file on the C: drive is read natively by PowerShell with no quoting surprises.
- **Status returned through a file, not stdout.** Capturing PowerShell's stdout across the boundary is unreliable and gets mixed with other output. Instead the script writes its status lines to a file on the Windows temp dir; the path is handed to it in the `DOTFILES_STATUS` env var, exported across the boundary via `WSLENV=...DOTFILES_STATUS/p` (the `/p` flag translates the path between Linux and Windows form). The Linux side then reads that file back deterministically.
- **Non-ASCII escaped on write.** `settings.json` is re-serialized with every non-ASCII byte escaped to `\uXXXX` before writing, so the edit never corrupts the file's encoding.

## Fails soft, never aborts

The whole step is guarded and self-skipping — it never breaks the rest of the install:

- Off WSL it returns immediately (`grep -qi microsoft /proc/version`).
- If `powershell.exe` is missing, or no writable Windows temp dir can be resolved, it warns and skips.
- If the Windows-side script errors, it warns and prints the captured status but the installer still finishes.

---

Up: [Terminal](../index.md)
