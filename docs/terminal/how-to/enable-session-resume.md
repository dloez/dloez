# Enable Claude Code session resume

Pick a rate-limited Claude Code session back up automatically, in place, once the usage limit lifts. Background and design: [Session resume](../explanation/session-resume.md).

## Prerequisites

- The Claude Code layer installed — see [Bootstrap a machine](bootstrap-machine.md), step 9, or run the installer as below.
- **herdr running, with your Claude sessions inside herdr panes.** The resume is delivered by typing into the pane, so a session started in a plain terminal cannot be resumed.
- `jq` on `PATH` (the installer installs it).
- A Claude.ai Pro or Max subscription. The reset time comes from `rate_limits` in the status line, which is only sent to subscribers, and only after a session's first API response.

## Steps

1. Install the runtime and register it:

   ```sh
   cd ~/workspace/dloez && INSTALL_CLAUDE=1 sh terminal/install.sh
   ```

   This symlinks `~/.claude/statusline.sh`, `~/.claude/hooks/stop-failure.sh`, and `~/.local/bin/cc-resume`, then merges the `statusLine` and `StopFailure` entries into `~/.claude/settings.json`. It is idempotent — re-running never duplicates the entries. Hook changes are picked up by Claude Code's file watcher, so no restart is needed.

   **This sets your status line.** If you already have one, the installer keeps yours and warns; to run both, set `CC_STATUSLINE_DELEGATE` to your existing command and point `statusLine` at `~/.claude/statusline.sh`.

2. Start the watcher in its own herdr pane:

   ```sh
   cc-resume watch
   ```

   One watcher covers every session and every repo on the machine. Nothing is resumed while it is not running.

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

## Troubleshooting

Read `~/.local/state/cc-resume/log.jsonl`; every decision is one line.

| Symptom | Line | Meaning |
|---|---|---|
| Nothing happens for hours | *(none)* | Not due yet. `cc-resume status` prints the wait. |
| Resume skipped | `dropped` / `pane_gone` | The pane no longer hosts an agent — closed, or Claude exited leaving a shell. |
| Resume deferred | `retry` / `dialog_stuck` | Claude's usage dialog would not dismiss, so nothing was typed. Clear it by hand and the next sweep proceeds. |
| Only one of two sessions resumed | `coalesced` | Both markers targeted the same pane; one delivery is intentional. |
| Watcher will not start | `a watcher is already running (pid N)` | Another watcher holds the lock. If that pid is dead the lock is reclaimed automatically. |

To stop cleanly, `SIGTERM` the watcher — it exits immediately and releases its lock.

---

Up: [Terminal](../index.md)
