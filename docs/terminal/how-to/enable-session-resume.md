# Enable Claude Code session resume

Pick a rate-limited Claude Code session back up automatically, in place, once the usage limit lifts. Background and design: [Session resume](../explanation/session-resume.md).

## Prerequisites

- **herdr running, with your Claude sessions inside herdr panes.** The resume is delivered by typing into the pane, so a session started in a plain terminal cannot be resumed.
- `jq` on `PATH` (the installer installs it).
- On Linux and WSL, a systemd **user** session for the watcher to autostart under; on macOS, `launchctl`. Without either, the watcher has to be started by hand.
- A Claude.ai Pro or Max subscription. The reset time comes from `rate_limits` in the status line, which is only sent to subscribers, and only after a session's first API response.

## Steps

1. Install the runtime and register it:

   ```sh
   cd ~/workspace/dloez && INSTALL_CLAUDE=1 sh terminal/install.sh
   ```

   This symlinks `~/.claude/statusline.sh`, `~/.claude/hooks/stop-failure.sh`, and `~/.local/bin/cc-resume`, then merges the `statusLine`, `StopFailure`, and `Stop` entries into `~/.claude/settings.json`. It is idempotent — re-running never duplicates the entries. Hook changes are picked up by Claude Code's file watcher, so no restart is needed.

   Two events are registered because two different things end a run: `StopFailure` catches this session hitting a limit, and `Stop` catches this session giving up because a **subagent** hit one. See [Session resume](../explanation/session-resume.md) for why the second needs evidence from the transcript before it does anything.

   **This sets your status line.** If you already have one, the installer keeps yours and warns; to run both, set `CC_STATUSLINE_DELEGATE` to your existing command and point `statusLine` at `~/.claude/statusline.sh`.

   The same run installs Claude Code itself if `claude` is not already on `PATH`, and registers the watcher to start on its own — a systemd user unit on Linux and WSL, a launchd LaunchAgent on macOS. **One watcher covers every session and every repo on the machine**, and nothing is resumed while it is not running.

2. Confirm the watcher is running, and manage it if you need to:

   **Linux / WSL**

   ```sh
   systemctl --user status cc-resume        # is it running?
   systemctl --user restart cc-resume       # after editing the script
   journalctl --user -u cc-resume -f        # follow its output
   ```

   **macOS**

   ```sh
   launchctl print "gui/$(id -u)/dev.dloez.cc-resume" | head -20
   launchctl kickstart -k "gui/$(id -u)/dev.dloez.cc-resume"   # restart
   ```

   If the installer reported no systemd user session and no `launchctl`, run `cc-resume watch` yourself in a spare herdr pane instead.

3. *Optional.* Set the text typed into a given repo, one line, instead of the default `continue`:

   ```sh
   echo '/work-queue' > ~/test/.claude/on-resume
   ```

## Verification

Do not wait for a real limit. Fake a stop and drive it by hand:

1. Find the pane hosting the session you want to resume:

   ```sh
   herdr agent list | jq -r '.result.agents[] | "\(.pane_id)  \(.cwd)"'
   ```

2. Write a marker for it, substituting the pane id:

   ```sh
   HERDR_PANE_ID=w1:p3 ~/.claude/hooks/stop-failure.sh rate_limit <<'EOF'
   {"session_id":"smoke-test","cwd":"/home/david/test","hook_event_name":"StopFailure"}
   EOF
   ```

3. Confirm it is queued, and see what would be sent:

   ```sh
   cc-resume status
   CC_RESUME_DRY_RUN=1 cc-resume fire smoke-test
   ```

4. Deliver it:

   ```sh
   cc-resume fire smoke-test
   ```

   The target session receives the resume text and starts working. `~/.local/state/cc-resume/log.jsonl` gains a `resumed` line and the marker is removed.

**`fire` is the verification path, not `watch`.** A marker inherits the *real* quota reset time cached by the status line, so a smoke test left to the watcher will sit idle for however long is left on your actual five-hour window — `cc-resume status` shows exactly how long. `fire` ignores the timer, which is what makes it useful here.

### Checking the subagent-limit trigger

The `Stop` trigger writes a marker only when the session's transcript shows a recent subagent death citing a limit, so it cannot be smoke-tested with a hand-written payload alone — point it at a transcript that really contains one:

```sh
CC_RESUME_STOP_WINDOW=999999 HERDR_PANE_ID=w1:p3 \
  ~/.claude/hooks/stop-failure.sh subagent_limit <<'EOF'
{"session_id":"nudge-test","cwd":"/home/david/test","transcript_path":"/home/david/.claude/projects/-home-david-test/<session>.jsonl","hook_event_name":"Stop"}
EOF
cc-resume status
```

`CC_RESUME_STOP_WINDOW` is widened only because the failure in an archived transcript is hours old; leave it alone in normal use. A marker appears if the transcript qualifies and nothing appears if it does not — that silence is the hook working, since `Stop` fires on every turn end. Clear up afterwards with `cc-resume clear nudge-test` and `rm ~/.local/state/cc-resume/nudges/nudge-test.json`, or the test consumes one of the session's three nudges.

## Troubleshooting

Read `~/.local/state/cc-resume/log.jsonl`; every decision is one line.

| Symptom | Line | Meaning |
|---|---|---|
| Nothing happens for hours | *(none)* | Not due yet. `cc-resume status` prints the wait. |
| Resume skipped | `dropped` / `pane_gone` | The pane no longer hosts an agent — closed, or Claude exited leaving a shell. |
| Resume deferred | `retry` / `dialog_stuck` | Claude's usage dialog would not dismiss, so nothing was typed. Clear it by hand and the next sweep proceeds. |
| Only one of two sessions resumed | `coalesced` | Both markers targeted the same pane; one delivery is intentional. |
| Watcher will not start | `a watcher is already running (pid N)` | Another watcher holds the lock. If that pid is dead the lock is reclaimed automatically. |
| `fire` says the session is not pending | *(none)* | It reports the last logged outcome instead — usually `resumed at <time> into pane <p>`, meaning the marker was consumed by that resume. Knock again with the `herdr pane run` line it prints. |
| A run stopped on a subagent limit and nothing happened | *(none)* | No marker was written. Check the transcript really carries a failed `<task-notification>` naming a limit, that it is under 15 minutes old, and that `~/.local/state/cc-resume/nudges/<session>.json` has not reached `count: 3`. |
| A session keeps being nudged | repeated `resumed` | It stops itself every turn while citing an old failure. The nudge ledger caps this at three per session per six hours; delete the ledger file to reset it. |

To stop cleanly, `systemctl --user stop cc-resume` (or `launchctl bootout "gui/$(id -u)/dev.dloez.cc-resume"` on macOS). Either way it takes `SIGTERM`, exits immediately, and releases its lock. Restart it after editing the script — a running `sh` re-reads its own file as it executes, so an in-place edit can corrupt the running process.

---

Up: [Terminal](../index.md)
