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

## Why the status line is load-bearing

The `StopFailure` payload says a session stopped and which session it was, but not when the limit lifts. That number reaches the machine through exactly one documented channel: the status line, which is fed `rate_limits.five_hour.resets_at` as Unix epoch seconds on every render. Caching it there is why the watcher can sleep until the reset plus a small buffer and knock once, rather than poll blindly.

Two consequences follow. A session that dies before its first API response never populated `rate_limits`, so no reset was cached and the watcher falls back to a fixed backoff. And if a different status line is already configured, the installer keeps it and warns rather than clobbering it — set `CC_STATUSLINE_DELEGATE` to the old command and point `statusLine` at ours to run both.

## Why herdr, and why no session-id lookup

herdr exports `HERDR_PANE_ID` into every pane it owns, so the hook records *its own* pane id directly. There is no lookup joining a Claude session to a terminal, because the process that failed already knows where it lives. `herdr agent list` does report `cwd` per agent (undocumented, but present in 0.7.4), which would support a fallback join — it is not needed and not used.

Delivery is `herdr pane run <pane_id> <text>`, which submits the text and Enter atomically and honours bracketed paste. herdr's docs recommend it over `pane send-text` followed by `pane send-keys Enter`, and it does not steal focus from whatever you are looking at.

herdr cannot tell *why* an agent stopped: its states are `idle`/`working`/`blocked`/`done`/`unknown`, read from a screen snapshot, and it only reports `blocked` on recognised approval UI. So the trigger has to come from Claude Code's own hook, and the two halves meet in the marker file.

## Guards

- **The pane must still host an agent.** Before typing, the watcher checks `herdr agent list` for the recorded pane. If the pane is gone, or Claude exited and left a bare shell, the marker is dropped rather than typed into — otherwise `continue` would run as a shell command.
- **One watcher at a time**, enforced by a lock directory at `~/.local/state/cc-resume/watch.lock`.
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
| `CC_RESUME_DRY_RUN` | unset | Print what would be typed instead of typing it. |
| `CC_STATUSLINE_DELEGATE` | unset | Command the status line pipes its JSON to for rendering. |

## Settings registration

`~/.claude/settings.json` is the one file the installer edits rather than symlinks, because Claude Code owns it and writes to it. `register_claude_settings` merges with `jq`: it strips any entry pointing at `stop-failure.sh` before re-adding ours, so re-running never duplicates, and it leaves every other key, every other hook event, and any foreign `StopFailure` entry (herdr's agent-state hook, for instance) untouched.

The error type is passed as an argument — `stop-failure.sh rate_limit` — rather than read from the hook payload. The `StopFailure` matcher is what selects the error, and the documented payload fields do not include the error type, so relying on the argument keeps the hook correct regardless of what the JSON carries.

---

Up: [Terminal](../index.md)
