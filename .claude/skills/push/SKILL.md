---
name: push
description: Add all changes, commit with a one-line message, and push to remote. TRIGGER when the user says "push", "commit and push", "ship it", or asks to save current work to the remote repository. SKIP when the user wants to review the commit message first or stage files selectively.
---

Add all changes to git, create a commit with a simple one-line message, and push to the remote. Follow the git commit conventions from root `CLAUDE.md` → "Commit & PR Conventions" (imperative one-line message, no attribution). Never force-push.

## Default: pushing the current branch to its upstream

Chain in a single Bash call:

    git add -A && git commit -m "<message>" && git push

## Pushing to a different branch (e.g. "push to main")

When the user asks to push to a branch other than the current HEAD's natural upstream — most commonly "push (directly) to main" — do NOT chain everything in one call. Higher-stakes target, more checks. Use this sequence:

1. Fetch the target: `git fetch origin <target>`.
2. Check divergence:
   - `git log --oneline origin/<target>..HEAD` — commits your push would add
   - `git log --oneline HEAD..origin/<target>` — commits already on the target that are not in HEAD
   - If BOTH have entries, your branch has diverged from the target. `git rebase origin/<target>` first. Do NOT `git reset --soft origin/<target>` to "squash against latest" — when branches have diverged, that stages an implicit revert of every commit on the target that your branch is missing.
3. If squashing local commits into one, reset to the **merge base**, not the remote tip:
   `git reset --soft "$(git merge-base HEAD origin/<target>)" && git commit -m "<message>"`.
4. **Inspect the net diff before pushing**:
   `git diff --stat origin/<target>..HEAD`
   The file count and `+/-` magnitude must match the scope of the intended change. If they don't (e.g. "38 files changed" on a one-line config edit), STOP and investigate — that's almost always an accidental revert or a bad rebase. Do not push past this signal.
5. Push: `git push origin HEAD:<target>`.

## Smoke signals — stop and investigate

- `git commit` output reports far more files/lines than the change you made.
- `git status` after a `reset --soft` shows files you never touched.
- `git diff --stat origin/<target>..HEAD` shows changes outside the scope of the task.

Any of these means the staged state is wrong. Fix it before pushing — a bad fast-forward push lands cleanly and is not blocked by GitHub.
