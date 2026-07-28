---
name: work-queue
description: Grind a repo's work queue unattended — `tasks.md`, or whatever its CLAUDE.md names as the queue — by running the next-task skill in autonomous mode, one entry per fresh subagent, committing each closed entry. Does nothing at all if the repo has no queue. Faults recover rather than ending the run — a dirty tree or abandoned work is stashed by a recovery subagent and the loop moves down the queue. Verifies every outcome from the queue file, git, and the repo's own gate run before each commit rather than trusting a subagent's report, and never discards work to recover. TRIGGER when the user says "work the queue", "grind the tasks", "run the task loop", "/work-queue", or asks you to work through several queue entries unattended. SKIP for a single entry — that is `/next-task` — and skip when the user wants to be asked questions as they come up, since this mode marks everything needing a decision and moves past it.
---

# /work-queue

A thin loop around `/next-task autonomous`. One entry per iteration, each in its own fresh subagent so no entry runs on a context already crowded by the last three.

**Arguments:** *(none)* runs uncapped — until the queue is empty or every remaining entry is the author's call. A number caps at that many iterations.

## It commits, and here is why

Each closed entry gets its own commit before the next iteration starts. This is not a convenience — the loop does not work without it. `/next-task` validates an entry by handing a subagent `git diff`, so if entry two's work is still sitting uncommitted, the validator checking entry three is reading both and cannot tell which is which. Committing per entry also makes `git log --oneline` the run's record, so no separate journal is needed, and it makes a dirty tree at the start of an iteration mean exactly one thing: the previous entry left work behind.

Match the repo's commit convention — run `git log --oneline -5` and copy what is there. **Never push.** Local commits are cheap to undo; a push is not.

**The gate runs before the commit, and it is the only evidence at that step you did not get from the subagent.** Reading the outcome off the queue file rather than off the report is the right instinct, but it is weaker than it sounds: the subagent that did the work is also the one that edited the file, so both are its output. The repo's gate is not. One command, run by you, on the tree in front of you — that is what makes a closure a fact instead of a claim, and it is cheap because the repo chose it to be cheap. Running it *before* the commit rather than at the next iteration's start is what keeps a broken entry out of history entirely, so the loop never needs to bisect its own commits or revert one.

## Before the first iteration

1. **Read `CLAUDE.md` and find the queue exactly as `/next-task` step 0 does** — that step owns the resolution order, including a `CLAUDE.md` line naming the queue something other than `tasks.md`, so do not keep a second copy of the list here. **No queue means no run:** say where you looked and stop without spawning anything. That is not a fault to recover from, and there is nothing to loop over.
2. **Clear the tree, don't refuse to start.** If `git status --porcelain` returns anything, send a recovery subagent to stash it and carry on once the tree comes back clean. That work may be the author's, so it is preserved and reported, never discarded. The loop needs a clean baseline because every per-entry validation reads `git diff` and would otherwise inherit whatever was already there.
3. **Find the gate and hold the machine cap yourself.** Two things out of `CLAUDE.md`. The gate is the command the repo says a change has to pass — you run it before every commit, so know it before the first iteration and know which kinds of change the repo exempts from it. The cap is whatever the repo says about how much of the machine a run may take: a thread ceiling, a rule against two batches at once, an instruction to check what is already running. **That cap counts every session at once, not every subagent separately.** Your subagents cannot see each other, the author's own work, or a second loop in another terminal, so the checking is yours: run whatever the repo names before each iteration, subtract what is already running, and pass what is left into the subagent's prompt as its budget. A loop that leaves this to each subagent has every one of them believe it owns the machine.
4. Note the starting `HEAD` and the entry headings in file order. The report needs both. **Read back any attempt markers already in the file** — a run that died mid-flight leaves them behind, and they are the part of its ledger that survived.

## Each iteration

1. **Read the state yourself.** Re-read the queue file and run `git status --porcelain`. Carry no claim about the repo forward from the last iteration's report — the file and git are the truth, and a report is only a claim about them. Your own attempt ledger is the exception: that is your bookkeeping, not a claim, and it has to survive the iteration.
2. Check the ending conditions below. If one holds, finish and report.
3. Target the first entry not already carrying `**Needs the author:**`. That is the marker `/next-task` writes when it blocks, and it is a fixed string precisely so this step can read it back — match it literally rather than reading the prose around it for intent.
4. **Spawn one subagent.** `Agent`, `subagent_type: general-purpose`, **never `fork`** — a fork inherits your context, which is the thing this loop exists to avoid. Keep the prompt short: the repo path, that it should invoke the `next-task` skill in `autonomous` mode on entry N, and that it should return that skill's step 7 report verbatim. Do not summarize the entry for it, do not say what you expect it to find, and do not pass a loop argument.
5. **Verify the outcome from the file, not the report.** Re-read the queue file:
   - Entry gone → it closed. **Run the repo's gate yourself before you commit anything.** It passes: commit, one line, matching the repo's convention. It fails: commit nothing, send a recovery subagent to stash the work labelled with the entry, mark the entry with the failure, and continue. Skip the run only where the repo itself says a change of that shape cannot reach what the gate measures, and say why in the report.
   - Entry still there and now carrying `**Needs the author:**` → it blocked. Record the questions for the final report.
   - Entry still there, rewritten or moved → it was stale and got re-sorted, or it was too big for one pass and got split into parts. Real progress, but no entry was consumed; continue without committing code, and commit the queue file edit on its own.
   - Entry still there and unchanged, but the report claims it closed → a fault. The report and the file disagree; one is wrong and neither is safe to build on. Recover and move on.
6. Check the tree again. Uncommitted work with no entry closed means an implementation was abandoned partway. Commit nothing — that is a fault, and it recovers.

Emit one short line per iteration as you go, so anyone watching can follow without reading the transcript.

## Faults recover, they do not end the run

**A fault costs the offending entry its turn, never the run.** Keep a ledger of how many times each entry has been attempted. Two attempts is the limit: on the second fault for the same entry, it gets the `**Needs the author:**` marker with the reason written into it, and the loop moves down the queue.

**Write the first attempt into the entry too, not only into the ledger.** One line reading `**Attempted once:**` and what the fault was. An uncapped run is long and the ledger lives in your context, so it dies with the loop — that line is the only part of it a restarted run can read back, and without it the next run starts every entry at zero attempts and pays for the same two faults over again. State that has to outlive an iteration belongs in the file, not in a head, which is the rule the loop already follows everywhere else.

**`**Attempted once:**` is not the author's-call marker and must never be written as one.** Step 3 keeps selecting an entry that carries it — one fault does not gate an entry, it costs it a turn. On the second fault the line is replaced by `**Needs the author:**` with both reasons under it, and only then does the entry stop being selected.

**You detect and verify; subagents do the work.** Detection is a `git status --porcelain` and a re-read of the queue file, which are cheap and stay with you. Every repair is delegated to a fresh `general-purpose` subagent — never a `fork` — with a narrow brief: the fault, the paths involved, and the preservation rule below. When it returns, **check the tree yourself.** A recovery agent's word that it cleaned up is not evidence the tree is clean. The one write you keep is the per-entry commit, because you have to know exactly what went into it to report it.

**The preservation rule, in every recovery: never discard.** No `git reset --hard`, no `git checkout --` on a file, no `git stash drop`, no deleting a file to make a build pass. Recovery means moving work somewhere labelled and retrievable — a stash with a message naming the run and the entry it came from — and every stash created goes in the final report with its ref. Some of what you stash may be the author's own work.

The faults and what each recovers to:

| Fault | Recovery |
|---|---|
| Tree dirty at the start of an iteration | Subagent stashes it, labelled. Continue. |
| Work uncommitted and no entry closed — an implementation abandoned partway | Subagent stashes it, labelled with the entry. Mark the entry, naming the gap the subagent hit. Continue. |
| The gate fails on a tree where an entry just closed | Commit nothing. Subagent stashes the work, labelled with the entry. Mark the entry with what failed, and continue — the entry did not close, whatever the file says. |
| The report and the queue file disagree about what happened | Believe neither. Treat the entry as not done, stash anything uncommitted, and give it its second attempt with a fresh subagent. |
| An iteration closed nothing, blocked nothing and re-sorted nothing | Second attempt. If it no-ops again, mark it and move down. |
| The same entry re-sorted twice running | Keep the second rewrite, mark the entry — a verifier rewriting the same entry in circles cannot settle what it should say — and move down. |

**Which of the two markers each row writes.** A row that marks an entry outright — the abandoned implementation, the failed gate — writes `**Needs the author:**` with the reason under it, the same string `/next-task` writes and step 3 selects on. A row that gives the entry a second attempt writes `**Attempted once:**` now and `**Needs the author:**` only if it faults again.

**Nothing in this loop bisects or reverts its own commits.** That path existed to deal with a breakage discovered an iteration after it landed; the gate now runs before each commit, so a broken entry never lands. If the gate is failing at the start of an iteration it is not the loop's doing, and it is a hard stop rather than a fault, below.

Two hard stops, and both are stops because continuing past them produces work that only looks done:

- **The tree will not come clean after two recovery attempts.** The loop cannot validate an entry on a tree it cannot clear, so continuing would produce meaningless passes. Stop, report the exact `git status`, and touch nothing further.
- **The gate fails at the start of an iteration, on a tree the loop has not touched.** Every commit it made passed the gate before landing, so this came from the baseline it inherited or from the stash it cleared. Do not bisect, do not revert, and do not carry on: the next entry's gate run will fail for a reason that has nothing to do with the entry, and grinding forward would mark the whole queue for a breakage none of it caused. Stop and report the exact failure.

## When the run ends

These are ends, not faults — nothing to recover, and none of them is a failure:

- The queue has no entries left.
- Every remaining entry carries `**Needs the author:**`.
- An iteration cap was given as an argument, and it is reached. With no argument there is no cap, so this is not one of the ways an uncapped run ends — do not stop an uncapped run because it feels long, because several entries have closed, or because a good place to report has come up. Keep taking entries until one of the two conditions above holds, or until a hard stop does.

## Report

Lead with what closed and why the run ended. Then:

- Each closed entry with its commit, and that the gate passed before it landed. Name any entry where the gate was skipped and the repo rule that allowed it.
- **Everything waiting on the author, as the actual questions, in queue order.** This is the part the author is reading for.
- **Every stash the run created, with its ref and what is in it.** Recovery preserves work by moving it out of the way, and a stash nobody is told about is work that is lost in practice.
- Every fault, what it recovered to, and which entries were marked rather than done. A run that recovered four times and closed one entry is not a clean run, and reading like one is the failure mode here.
- Anything re-sorted or split, and where it moved.
- The queue as it now stands, and the range of commits the run produced.

Never spin a recovered fault as a success or a short run as a finished one. If a capped run ended on the second of five iterations, say so in the first sentence. If an uncapped run stopped with un-gated entries still in the queue, that is not an end at all — say in the first sentence why it stopped early and what is left.
