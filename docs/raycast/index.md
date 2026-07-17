# Raycast

[`raycast-scripts/`](../../raycast-scripts) holds [Raycast](https://www.raycast.com/) script-command launchers that drive [`tdo`](https://github.com/dloez/tdo), a Rust todo CLI (installed at `~/.cargo/bin/tdo`). Raycast is macOS-native; the Windows variants are the same launchers reimplemented in PowerShell for a Raycast-for-Windows-style runner, routing through WSL.

## Script command headers

Each launcher is a normal script with a Raycast metadata header in comments:

```
# @raycast.schemaVersion 1
# @raycast.title tdo
# @raycast.mode fullOutput
# @raycast.argument1 { "type": "text", "placeholder": "add Buy milk --today ..." }
# @raycast.icon ·
# @raycast.packageName tdo
```

`@raycast.mode` decides how output is surfaced: `fullOutput` shows the command's stdout in Raycast; `silent` runs with no visible output (used by the window launchers).

## Scripts

| Script | Platform | What |
|--------|----------|------|
| [`macos/tdo.sh`](../../raycast-scripts/macos/tdo.sh) | macOS | Runs `tdo` with the typed argument (`fullOutput`). |
| [`windows/tdo.ps1`](../../raycast-scripts/windows/tdo.ps1) | Windows | Same, via `wsl.exe bash -c` into `tdo`. |
| [`macos/open-tasks.sh`](../../raycast-scripts/macos/open-tasks.sh) | macOS | Opens/focuses two Ghostty windows for the Today and Inbox lists, positioned via `osascript`. |
| [`windows/open-tasks.ps1`](../../raycast-scripts/windows/open-tasks.ps1) | Windows | Same idea, using Windows Terminal (`wt.exe`) and Win32 `MoveWindow` for placement. |

The `open-tasks` launchers share two cross-platform helpers under [`general/helpers/`](../../raycast-scripts/general/helpers), each setting a terminal title and `watch`-ing a `tdo view`:

- [`tdo-today.sh`](../../raycast-scripts/general/helpers/tdo-today.sh) — `[Today] Tasks`, `tdo view today`.
- [`tdo-inbox.sh`](../../raycast-scripts/general/helpers/tdo-inbox.sh) — `[Inbox] Tasks`, `tdo view inbox`.

## Gotchas

- Both `open-tasks` launchers **look for existing windows first** (by title) and only spawn/place new ones when missing, so re-triggering focuses rather than duplicates.
- Window coordinates are hard-coded to a specific multi-monitor layout; adjust them for a different setup.

See also: [docs index](../index.md).
