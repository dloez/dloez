---
name: execute-plan
description: Execute a previously created plan from .claude/plans/, docs/work-in-progress/, or docs/personal/ (filename contains "plan"), one phase at a time with review and commit checkpoints between phases. TRIGGER when the user says "execute the plan", "continue the plan", "run phase N", or points to an existing plan file to implement. SKIP when starting fresh work with no existing plan.
---

# /execute-plan

1. **Find the plan.** If named in invocation (`/execute-plan grafana-plan.md`), use it. Otherwise: `find .claude/plans docs/work-in-progress docs/personal -maxdepth 2 -type f -name '*plan*.md' 2>/dev/null`.
   - 0 results → tell the user, stop.
   - 1 result → confirm "Use `<filename>`?"
   - 2–4 results → present via `AskUserQuestion` (label = filename, description = parent dir + last-modified).
   - 5+ → show the 4 most-recently-modified via `AskUserQuestion`; the auto-included "Other" lets the user type a path.

2. **Read the plan.** Summarize for the user: goal, phase count, next phase.

3. **Pick phase range.** If named ("run phase 3", "phases 1-3"), use it. Otherwise identify the next pending phase N and ask via `AskUserQuestion`:
   - "Just phase N (Recommended)"
   - "Phases N–N+1"
   - "Phases N–N+2"
   - "All remaining phases"

   Drop options that exceed remaining phases. If only one remains, just run it.

4. **Front-load verification.** Inspect each targeted phase's Acceptance criteria — they should match the 5-bullet spec from `/make-plan` (Claude-run / Human-run / Reuse / Neighbors / Forbidden). If missing or vague, augment the plan file first, show the user, and wait for approval before executing. Run the right checks for the area the phase touches: homelab has no test suite, so verify on the live cluster (`flux get kustomizations`, `flux build`/`flux reconcile`, `kubeconform`); terminal has real automated tests (`sh terminal/test.sh`, `sh terminal/verify.sh`, `shellcheck --severity=warning terminal/*.sh`). Don't invent pytest/jest commands.

5. **Execute one phase at a time.** For each phase:

   a. Read the CLAUDE.md files and docs referenced in the plan's Context. Audit new/moved code against them — tooling doesn't enforce every project convention (the leading `---` on hand-authored manifests, prettier formatting, pinned image tags, ESO/1Password secret references instead of plaintext, POSIX-sh portability). Verbatim moves of legacy manifests/scripts carry pre-existing violations that should be fixed in the move, not preserved.

   b. Work the to-do list in order, checking items off in the plan file as you go. **Do not run Claude-run checks mid-iteration** (review cycles can be many edits long; running checks each time is noise). If an error is obvious in the diff (a missing leading `---`, a shellcheck-flagged quoting bug), fix it without running the full check.

   c. **Run Claude-run checks at end of phase.** Execute every command/grep/build/lint/test, paste the output. Grep each forbidden pattern, confirm no matches. Confirm each Reuse manifest/base/helper is actually referenced in the diff. Never declare completion on read-backs alone.

   d. **Hand human-run checks to the user.** List them verbatim from the acceptance criteria. Do not claim the phase works end-to-end — only that Claude-run checks passed and the code is ready for verification.

   e. After the user confirms, prompt them to commit via `/push`.

   f. Update the plan's **Next step** to the following phase.

6. **New work discovered mid-phase:**
   - Prerequisite/clarification for current phase → add as a new to-do inside it, with its own acceptance criteria.
   - Net-new scope → pause, surface it, decide with the user whether to add a top-level phase or defer. **No nested sub-phases beyond one level** (no 4a/4b/4c).
   - Same kind of surprise twice in one phase → stop and re-run `/discover` against the remaining phases.

7. **All targeted phases complete:** update the docs listed in **Documentation to update** (CLAUDE.md's Keep Documentation Updated rule applies).

8. **Plan fully complete:** prompt the user to delete the plan and `/push`.

# Non-negotiables

- **One phase at a time** — never start a new phase before the current is reviewed and committed.
- **No shallow completion** — run every Claude-run check; paste output; wait for the user's confirmation on human-run checks rather than claiming on their behalf.
- **No unsolicited product decisions** — if execution uncovers a UX/default/scope choice not in the plan, stop and ask. Technical choices are yours.
- **Plan file is source of truth** for progress — keep to-do checkboxes and Next step current.
