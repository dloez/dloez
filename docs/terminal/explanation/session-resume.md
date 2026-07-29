# Claude Code session resume

## The problem

A Claude Code session that hits the five-hour usage limit stops where it is. The turn ends, the TUI returns to its prompt, and nothing further happens — so an unattended run started before dinner is found idle at midnight, having done nothing since the limit hit. Claude Code 2.1.x has no flag that waits out a limit and carries on, so the gap has to be filled from outside the process.

## Why it types into the live session

The obvious fix is to relaunch headlessly — `claude -p --resume <session-id>` on a timer — and it is the wrong one. A resumed headless session starts from a transcript rather than from the live conversation, and anything the stopped session was holding in context is gone. For a long unattended loop that is exactly the state worth keeping: the [`work-queue`](../../../.claude/skills/work-queue/SKILL.md) skill tracks per-entry attempts in its own context, and a relaunch restarts that ledger at zero.

So `cc-resume` does not start anything. It waits for the limit to lift and then **types a word into the pane that is already sitting there**, exactly as if you had come back to the keyboard and pressed a key. The session keeps its full context and continues from where it stopped. Nothing in the recovery path calls a model: the hook records, the watcher compares two numbers, and herdr delivers the keystrokes.

## The three parts

| Part | Installed as | Role |
|------|--------------|------|
| `config/claude/hooks/stop-failure.sh` | `~/.claude/hooks/stop-failure.sh` | Claude Code `StopFailure` hook. Writes a marker naming the session, its pane, and when the limit lifts. Records only — it makes no decisions. |
| `config/claude/statusline.sh` | `~/.claude/statusline.sh` | Status line that also caches `rate_limits.five_hour.resets_at` to `~/.local/state/cc-resume/rate-limit.json`. |
| `config/claude/cc-resume` | `~/.local/bin/cc-resume` | The watcher. Sleeps until a marker is due, then `herdr pane run <pane> <text>`. |

The flow is: session stops on a rate limit → hook writes `~/.local/state/cc-resume/pending/<session>.json` → `cc-resume watch` sees the marker come due → herdr types the resume text into that pane → marker deleted.

None of the three is a compiled program; they are `sh` scripts on `PATH`. The only compiled thing involved is Claude Code, which the installer now installs too rather than assuming you had it.

## The watcher has to outlive the terminal that started it

A watcher run by hand in a pane dies with that pane, and a rate limit that lifts at 4am is exactly when nobody is there to restart it. So it is registered with the platform's own supervisor: a systemd **user** unit on Linux and WSL, a launchd **LaunchAgent** on macOS. Both start it at login, restart it if it exits, and survive a reboot.

The systemd side needs one extra step that is easy to miss: without `loginctl enable-linger`, the user manager is torn down when the last session ends, taking the watcher with it — so the installer enables lingering, and says which command to run by hand if that needs privileges. The launchd side needs a different concession: plists perform no `$HOME` expansion, so the plist is the one file in this repo that is generated from a template at install time instead of being symlinked out of the checkout.

Because the watcher runs under a supervisor rather than in a shell, it gets no interactive `PATH`. Both units set one explicitly that includes `~/.local/bin`, which is where `herdr` lives — without that the watcher would start, find no `herdr`, and log `skipped / herdr_missing` forever.

## Why the status line is load-bearing

The `StopFailure` payload says a session stopped and which session it was, but not when the limit lifts. That number reaches the machine through exactly one documented channel: the status line, which is fed `rate_limits.five_hour.resets_at` as Unix epoch seconds on every render. Caching it there is why the watcher can sleep until the reset plus a small buffer and knock once, rather than poll blindly.

Two consequences follow. A session that dies before its first API response never populated `rate_limits`, so no reset was cached and the watcher falls back to a fixed backoff. And if a different status line is already configured, the installer keeps it and warns rather than clobbering it — set `CC_STATUSLINE_DELEGATE` to the old command and point `statusLine` at ours to run both.

## Why herdr, and why no session-id lookup

herdr exports `HERDR_PANE_ID` into every pane it owns, so the hook records *its own* pane id directly. There is no lookup joining a Claude session to a terminal, because the process that failed already knows where it lives. `herdr agent list` does report `cwd` per agent (undocumented, but present in 0.7.4), which would support a fallback join — it is not needed and not used.

Delivery is `herdr pane run <pane_id> <text>`, which submits the text and Enter atomically and honours bracketed paste. herdr's docs recommend it over `pane send-text` followed by `pane send-keys Enter`, and it does not steal focus from whatever you are looking at.

herdr cannot tell *why* an agent stopped: its states are `idle`/`working`/`blocked`/`done`/`unknown`, read from a screen snapshot, and it only reports `blocked` on recognised approval UI. So the trigger has to come from Claude Code's own hook, and the two halves meet in the marker file.

## A rate-limited session is not sitting at a prompt

This is the assumption the first version got wrong, and it cost a real double-send. When the limit is hit, Claude Code puts up a selection dialog titled **"What do you want to do?"** rather than returning to the prompt box. Typing text and Enter into that dialog does not submit a prompt — the Enter selects whichever option is highlighted.

There are two such dialogs, both with the same title. The rate-limit menu offers **Stop and wait for limit to reset** (`cancel`), **Switch to usage credits** or **Add funds to continue with usage credits** (`extra-usage`), and **Upgrade your plan** (`upgrade`); a **Upgrade to Team plan** entry appears behind a flag. Ordering is not stable — "Stop and wait" is first by default but moves last under a feature flag — so which option a blind Enter would select cannot be predicted. The second dialog appears when a usage credit balance exists and leads with **Adjust monthly spend limit**, whose Enter path writes a new spend limit. That one is why blind Enter is unacceptable rather than merely untidy.

So the watcher **looks before it types**. It reads the pane, and if the title string is present it sends `Escape` — which both dialogs wire to a benign cancel — waits `CC_RESUME_DIALOG_SETTLE` seconds, and reads again. Only once the dialog is gone does it type. If the dialog is still up, nothing is typed: the attempt is charged and the marker is retried later. A resume that cannot be delivered safely is not delivered at all.

## Guards

- **The pane must still host an agent.** Before typing, the watcher checks `herdr agent list` for the recorded pane. If the pane is gone, or Claude exited and left a bare shell, the marker is dropped rather than typed into — otherwise `continue` would run as a shell command.
- **One injection per pane per sweep.** Two markers can come due for the same pane at once — a real stop and a test marker, say, both stamped with the same reset time. The first is delivered and the rest are dropped with a `coalesced` log line, because typing the resume text twice is exactly the failure this guard exists to prevent.
- **One watcher at a time**, enforced by a lock directory at `~/.local/state/cc-resume/watch.lock` holding the owner's pid. A lock whose pid is no longer alive is treated as stale and reclaimed, so a watcher killed with `SIGKILL` does not block every later start.
- **Shutdown is prompt.** The poll runs as a background `sleep` the watcher `wait`s on, so `SIGTERM` is handled immediately instead of being queued behind a full poll interval.
- **Attempts are capped** at `CC_RESUME_MAX_ATTEMPTS` (3), with a `CC_RESUME_BACKOFF` (1200s) delay that grows per attempt, so a session that cannot be resumed stops being retried.
- **Markers expire** after `CC_RESUME_MAX_AGE` (24h), so a watcher started days later does not resume something long abandoned.
- **Every decision is logged** as one JSON line to `~/.local/state/cc-resume/log.jsonl`.

## Configuration

The resume text is per-project and defaults to `continue`. A repo that wants something else puts one line in `<repo>/.claude/on-resume` — for a queue-grinding repo that line is `/work-queue`. `CC_RESUME_TEXT` overrides the default globally; the project file wins over both.

| Variable | Default | Meaning |
|----------|---------|---------|
| `CC_RESUME_TEXT` | `continue` | Text typed when a project has no `.claude/on-resume`. |
| `CC_RESUME_POLL` | `60` | Seconds between sweeps. |
| `CC_RESUME_BUFFER` | `120` | Seconds to wait past the known reset before knocking. |
| `CC_RESUME_BACKOFF` | `1200` | Fallback delay when no reset time was cached, multiplied by attempt count. |
| `CC_RESUME_MAX_ATTEMPTS` | `3` | Attempts before a marker is abandoned. |
| `CC_RESUME_MAX_AGE` | `86400` | Seconds before a pending marker is dropped as stale. |
| `CC_RESUME_DIALOG_MARKER` | `What do you want to do?` | Title string that identifies Claude's usage dialog. |
| `CC_RESUME_DIALOG_SETTLE` | `1` | Seconds to wait after sending Escape before re-reading the pane. |
| `CC_RESUME_DRY_RUN` | unset | Print what would be typed instead of typing it. Reports whether the dialog is up. |
| `CC_STATUSLINE_DELEGATE` | unset | Command the status line pipes its JSON to for rendering. |

## Settings registration

`~/.claude/settings.json` is the one file the installer edits rather than symlinks, because Claude Code owns it and writes to it. `register_claude_settings` merges with `jq`: it strips any entry pointing at `stop-failure.sh` before re-adding ours, so re-running never duplicates, and it leaves every other key, every other hook event, and any foreign `StopFailure` entry (herdr's agent-state hook, for instance) untouched.

The error type is passed as an argument — `stop-failure.sh rate_limit` — rather than read from the hook payload. The `StopFailure` matcher is what selects the error, and the documented payload fields do not include the error type, so relying on the argument keeps the hook correct regardless of what the JSON carries.

---

Up: [Terminal](../index.md)
