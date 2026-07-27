---
name: work-queue
description: Grind a repo's work queue unattended — `tasks.md`, or whatever its CLAUDE.md names as the queue — by running the next-task skill in autonomous mode, one entry per fresh subagent, committing each closed entry. Does nothing at all if the repo has no queue. Faults recover rather than ending the run — a dirty tree or abandoned work is stashed by a recovery subagent and the loop moves down the queue. Verifies every outcome from the queue file and git rather than trusting a subagent's report, and never discards work to recover. TRIGGER when the user says "work the queue", "grind the tasks", "run the task loop", "/work-queue", or asks you to work through several queue entries unattended. SKIP for a single entry — that is `/next-task` — and skip when the user wants to be asked questions as they come up, since this mode marks everything needing a decision and moves past it.
---

# /work-queue

A thin loop around `/next-task autonomous`. One entry per iteration, each in its own fresh subagent so no entry runs on a context already crowded by the last three.

**Arguments:** *(none)* caps at 5 iterations; a number caps at that many.

## It commits, and here is why

Each closed entry gets its own commit before the next iteration starts. This is not a convenience — the loop does not work without it. `/next-task` validates an entry by handing a subagent `git diff`, so if entry two's work is still sitting uncommitted, the validator checking entry three is reading both and cannot tell which is which. Committing per entry also makes `git log --oneline` the run's record, so no separate journal is needed, and it makes a dirty tree at the start of an iteration mean exactly one thing: the previous entry left work behind.

Match the repo's commit convention — run `git log --oneline -5` and copy what is there. **Never push.** Local commits are cheap to undo; a push is not.

## Before the first iteration

1. **Read `CLAUDE.md` and find the queue exactly as `/next-task` step 0 does** — that step owns the resolution order, including a `CLAUDE.md` line naming the queue something other than `tasks.md`, so do not keep a second copy of the list here. **No queue means no run:** say where you looked and stop without spawning anything. That is not a fault to recover from, and there is nothing to loop over.
2. **Clear the tree, don't refuse to start.** If `git status --porcelain` returns anything, send a recovery subagent to stash it and carry on once the tree comes back clean. That work may be the author's, so it is preserved and reported, never discarded. The loop needs a clean baseline because every per-entry validation reads `git diff` and would otherwise inherit whatever was already there.
3. Note the starting `HEAD` and the entry headings in file order. The report needs both.

## Each iteration

1. **Read the state yourself.** Re-read the queue file and run `git status --porcelain`. Carry no claim about the repo forward from the last iteration's report — the file and git are the truth, and a report is only a claim about them. Your own attempt ledger is the exception: that is your bookkeeping, not a claim, and it has to survive the iteration.
2. Check the ending conditions below. If one holds, finish and report.
3. Target the first entry not already marked as the author's call.
4. **Spawn one subagent.** `Agent`, `subagent_type: general-purpose`, **never `fork`** — a fork inherits your context, which is the thing this loop exists to avoid. Keep the prompt short: the repo path, that it should invoke the `next-task` skill in `autonomous` mode on entry N, and that it should return that skill's step 7 report verbatim. Do not summarize the entry for it, do not say what you expect it to find, and do not pass a loop argument.
5. **Verify the outcome from the file, not the report.** Re-read the queue file:
   - Entry gone → it closed. Commit it, one line, matching the repo's convention.
   - Entry still there and now marked as the author's call → it blocked. Record the questions for the final report.
   - Entry still there, rewritten or moved → it was stale and got re-sorted. Real progress, but no entry was consumed; continue without committing code, and commit the queue file edit on its own.
   - Entry still there and unchanged, but the report claims it closed → a fault. The report and the file disagree; one is wrong and neither is safe to build on. Recover and move on.
6. Check the tree again. Uncommitted work with no entry closed means an implementation was abandoned partway. Commit nothing — that is a fault, and it recovers.

Emit one short line per iteration as you go, so anyone watching can follow without reading the transcript.

## Faults recover, they do not end the run

**A fault costs the offending entry its turn, never the run.** Keep a ledger of how many times each entry has been attempted. Two attempts is the limit: on the second fault for the same entry, it is marked as the author's call with the reason written into it, and the loop moves down the queue.

**You detect and verify; subagents do the work.** Detection is a `git status --porcelain` and a re-read of the queue file, which are cheap and stay with you. Every repair is delegated to a fresh `general-purpose` subagent — never a `fork` — with a narrow brief: the fault, the paths involved, and the preservation rule below. When it returns, **check the tree yourself.** A recovery agent's word that it cleaned up is not evidence the tree is clean. The one write you keep is the per-entry commit, because you have to know exactly what went into it to report it.

**The preservation rule, in every recovery: never discard.** No `git reset --hard`, no `git checkout --` on a file, no `git stash drop`, no deleting a file to make a build pass. Recovery means moving work somewhere labelled and retrievable — a stash with a message naming the run and the entry it came from — and every stash created goes in the final report with its ref. Some of what you stash may be the author's own work.

The faults and what each recovers to:

| Fault | Recovery |
|---|---|
| Tree dirty at the start of an iteration | Subagent stashes it, labelled. Continue. |
| Work uncommitted and no entry closed — an implementation abandoned partway | Subagent stashes it, labelled with the entry. Mark the entry as the author's call, naming the gap the subagent hit. Continue. |
| The report and the queue file disagree about what happened | Believe neither. Treat the entry as not done, stash anything uncommitted, and give it its second attempt with a fresh subagent. |
| An iteration closed nothing, blocked nothing and re-sorted nothing | Second attempt. If it no-ops again, mark it as the author's call and move down. |
| The same entry re-sorted twice running | Keep the second rewrite, mark the entry as the author's call — a verifier rewriting the same entry in circles cannot settle what it should say — and move down. |
| The build or tests are broken at an iteration start, and no entry closed to explain it | Subagent bisects to whether the loop's own commits caused it. If they did, subagent reverts the offending commit with `git revert`, never a reset. If they did not, mark it in the report and continue. |

The single hard stop: **the tree will not come clean after two recovery attempts.** The loop cannot validate an entry on a tree it cannot clear, so continuing would produce meaningless passes. Stop, report the exact `git status`, and touch nothing further.

## When the run ends

These are ends, not faults — nothing to recover, and none of them is a failure:

- The iteration cap is reached.
- The queue has no entries left.
- Every remaining entry is marked as the author's call.

## Report

Lead with what closed and why the run ended. Then:

- Each closed entry with its commit.
- **Everything waiting on the author, as the actual questions, in queue order.** This is the part the author is reading for.
- **Every stash the run created, with its ref and what is in it.** Recovery preserves work by moving it out of the way, and a stash nobody is told about is work that is lost in practice.
- Every fault, what it recovered to, and which entries were marked rather than done. A run that recovered four times and closed one entry is not a clean run, and reading like one is the failure mode here.
- Anything re-sorted, and where it moved.
- The queue as it now stands, and the range of commits the run produced.

Never spin a recovered fault as a success or a short run as a finished one. If it ended on the second of five iterations, say so in the first sentence.
