---
name: next-task
description: Work the top entry of a repo's work queue end to end — `tasks.md`, or whatever the repo's CLAUDE.md names as its queue, such as a backlog.md. Reads CLAUDE.md first, then a context-free subagent checks the entry still stands against current code and data, the main agent implements it, and a second context-free subagent validates before the entry is removed. Stale entries get rewritten and re-sorted; entries needing an author decision are worked question by question, or skipped in autonomous mode. Says so and does nothing if the repo has no queue. TRIGGER when the user says "next task", "pick up the next task", "/next-task", or asks you to start on whatever is at the top of tasks.md. SKIP when the user names specific work directly rather than pointing at the queue, skip in favour of `/work-queue` when they want several entries worked unattended in a loop, and skip in favour of `/execute-plan` when the work is a phased plan file rather than a queue of independent entries.
---

# /next-task

One entry from the queue, verified before it is started and validated before it is closed. Both checks run in fresh subagents that know nothing about what you expect to find — a verifier holding your conclusion is not a verifier.

**Wait for a subagent, never watch one — and waiting means ending your turn.** Ending a turn with no tool call while a subagent of yours is still running does not finish you: the harness holds you until it completes and re-invokes you with its result, and that wake is the only way the result ever reaches you. Staying inside the turn until it lands is impossible without polling, and polling is the one thing forbidden here: no `sleep` loop over `seq`, no grep for `"type":"result"`, no `tail -f`, and no reading the `.output` path the spawn returned. That file is the agent's full JSONL transcript, so reading it floods the context this skill spends its whole budget keeping clean, and the loop cannot finish early — it sleeps out its remaining interval after the result has already landed. A verifier takes as long as it takes; the notification is the signal. **If you are ever awake without the result** — woken by something else, or the notification carried no verdict — the one sanctioned move is a `SendMessage` to that subagent's `agentId` asking it to restate its final report, then ending your turn again to wait for the reply. A finished agent answers that at once, and it is the only recovery path; improvising a poll loop is not one.

**Wait for a long process inside your turn, not by ending it.** When you were spawned by another agent, every turn you end while a process of yours is still running wakes that agent with a notice, spending its context and its money on nothing. So a game run, an agent run, a long build or eval is started with `run_in_background`, and you then block on it in the foreground: `timeout 590 tail --pid=<pid> -f /dev/null; ps -p <pid> >/dev/null && echo running || echo exited`, with the Bash timeout at 600000, repeated until it exits. That costs one cheap call per ten minutes and keeps your turn open, so nobody is notified. Read the log's tail once between blocks if you need to know where the run is. Ending your turn is the right wait only for a subagent of yours, which cannot be blocked on. When a condition partway through matters, such as a pause, a badge or a crash, block on it the same way: `timeout 590 grep -m1 -E '<pattern>' <(tail -n0 -F <log>)`, repeated, matching only lines that end the wait and never per-step lines such as each wake or battle. Never use a Monitor or a streaming `tail -F` while a process runs. Each event wakes you, and each wake that ends with the process alive notifies whoever spawned you.

**Arguments** — any combination, in any order:
- *(none)* — take the first entry in the file and start, interactive. Never ask which entry to work on.
- `autonomous` (`auto`, `-a`) — skip anything needing an author decision. See the mode section at the bottom.
- `detached` — only for `/work-queue`, and always alongside `autonomous`. You run inside a git worktree the caller made, the queue file is read-only, and every queue edit comes back in your report instead. See the detached section at the bottom.
- a number or a word from a heading (`3`, `carnivory`) — target that entry instead of the top one. A number counts position in the file, whether or not the headings themselves are numbered.

**One entry per invocation. There is no loop mode here** — looping is `/work-queue`'s job, and it owns the parts that make a loop safe: which entries may run at once, whether the last one really closed, and when everything left is waiting on the author. A second loop in here would be a silent way to grind the whole queue inside one filling context.

## 0. Load

**Detached, `cd` into the worktree before anything else**, so everything below is read from the worktree rather than the caller's main tree.

**Read `CLAUDE.md` first, if the repo has one** — the root file, plus any nested one covering the area you would be working in. Two reasons, in this order. Its rules override this skill wherever they disagree. And it is the first place to look for where the queue lives: a line saying the work queue is `backlog.md`, or `todo.md`, or anything else, settles the question whatever the file is called. Read the docs index too if there is one.

**Then find the queue.** If `CLAUDE.md` named a file, that is the queue — believe it over a filename match, even when a `tasks.md` also exists. Otherwise take the first hit from the repo root of `docs/work-in-progress/tasks.md`, `tasks.md`, `task.md`, `TASKS.md`, `backlog.md`, `BACKLOG.md`, `todo.md`, `TODO.md`, `.claude/tasks.md`.

**If there is no queue, say which places you looked and stop.** Do nothing else. Do not create a queue file, do not fall back to a plan or discovery doc, and do not start work you inferred from the docs — a repo without a queue is a repo this skill does not apply to, and inventing one is worse than doing nothing. Same if the file you found does not read as an ordered list of work items: say what you found instead and stop, rather than guessing at its shape.

Parse the entries in file order — the top one is the highest priority. **Note how the file carries order and identity before you change anything in it.** Some queues number their headings; some forbid numbers and say so in the file, because renumbering on every insert silently breaks each cross-reference pointing at the entries below it. Match what is there and never convert one to the other. A `Not To Do` section is a list of prohibitions, not entries: never select from it, and read it before writing any code.

## 1. Select

**With no argument, take the first entry in the file. It is the highest priority by being first, and there is nothing to ask about — go straight to step 2 with it.** Skip past it only when this session has already handled it, or — in autonomous mode — when it carries the `**Needs the author:**` marker below, whichever run wrote it; then take the next one down, and so on. Re-verifying a marked entry pays a second time for a block already recorded. Interactive, that entry is taken up and its questions are worked.

A number or keyword argument overrides this and selects that entry instead, and so does a caller that names the entry — `/work-queue` does, since a fresh subagent has no session to remember what the last one handled. Never re-verify an entry a verifier has already ruled on in this session.

## 2. Standing check — context-free subagent

`Agent` with `subagent_type: general-purpose`. **Never `fork`** — a fork inherits this context and defeats the purpose.

The prompt carries only the repo path — detached, the worktree path, named as the repo — the queue file path, and the entry's text verbatim. It does not carry your reading of it, your hypothesis, or which outcome you are hoping for. Tell the agent to read and run, not to edit or fix.

Two lines in an entry are bookkeeping rather than content: `**Needs the author:**`, and the `**Attempted once:**` line `/work-queue` writes after a fault. Pass them through, and tell the verifier they are records of past runs, not claims about the code to check. The [scheduling lines](#scheduling-lines) `**Touches:**` and `**After:**` are neither: they are a forecast. Have the verifier name under `TOUCHES` any path the work will plainly have to edit that the line leaves out, and never call an entry stale over them.

Instruct it to: read the repo's `CLAUDE.md` and docs first; check every factual claim in the entry against the current code and the current findings docs; check whether the work is already done; check whether what the entry depends on still exists; and **check whether the work needs something another entry still in the queue would add** — a function, a config key, a file, a doc section that is not in the code yet and that another entry's Do creates. That is a dependency, not staleness: the entry is right, it is only early.

**Tell it what `stale` means, because the default reading of the word is wrong and it is the most expensive mistake this skill makes.** `stale` is for an entry whose *work* no longer makes sense: what it depends on is gone, the change is already in, the docs now contradict what it asks for, or it describes a mechanism that has since been replaced. It is **not** for a figure that has drifted or a line reference that has moved. Numbers quoted in a queue entry go out of date within a pass or two, and a moved `file.rs:120-140` means somebody edited above it — neither one changes what the entry asks you to build. Have the verifier list those under `CLAIMS` as drifted, name what is true now, and still return `stands`. The implementer corrects them in passing as part of the work.

**Why this distinction is load-bearing.** A `stale` verdict sends step 3 back to select without implementing. So an entry carrying live figures returns `stale` on every single visit and is rewritten every time instead of built — the queue file grows, no code lands, and under `/work-queue` the entry is charged an attempt for a defect that was never in the work. If a verifier cannot decide which kind it has found, `stands` is the cheaper error: the implementer reads the code anyway.

Require exactly this report:

```
VERDICT: stands | stale | done
NEEDS_AUTHOR: yes | no
CLAIMS:
- <claim, quoted> — holds | stale: <what is true now> <file:line or doc anchor>
QUESTIONS:          (only when NEEDS_AUTHOR: yes — one decision each, never bundled)
- <question> | recommend: <answer> | why: <one line> | alternative: <the other option>
REWRITE:            (only when VERDICT: stale — the entry rewritten in the file's own voice and format)
NEW_POSITION: <n>, or `after: <heading>` where the file does not number | because: <one line>
TOUCHES: <paths the work will edit that the entry's **Touches:** line misses, or `none`>
DEPENDS_ON: <heading of a queued entry this work needs first> — <what it needs from it, file:symbol>, one per line, or `none`
EVIDENCE: <files and docs actually opened>
```

`NEEDS_AUTHOR: yes` means the entry cannot finish without a call only the author can make — a design decision, a scope change, an edit to a settled doc. It does not mean a number needs choosing. Where the repo separates tuning levers from blocking questions, a lever gets a starting value and the work proceeds.

**It also does not mean a build decision needs taking.** Which files change, what the types look like, where a field lives, what a condition may test, what one step leaves behind for the next, which order the parts land in — these are the implementer's, and a design doc that settles a mechanic's *meaning* without settling its representation is normal rather than a blocker. Answer `NEEDS_AUTHOR: no` and let the implementer choose and record it. Reserve `yes` for what would change what the product is.

## 3. Branch on the verdict

**`stale` → rewrite and re-sort.** First check it is really stale and not merely drifted, per step 2 — a verdict resting only on moved figures or shifted line numbers is a `stands` with corrections to make in passing, and treating it as stale costs the entry a whole pass and produces prose instead of code. If it is genuinely stale: apply the rewrite, move the entry to `NEW_POSITION`, and fix whatever that file uses to carry order and cross-references — the numbers if it numbers, the headings and anchors if it does not. **Never add numbering to a file that has none, and never renumber one that says not to.** Fix whatever else the file says about itself: intro lines that count entries or name which ones need the author, and every reference pointing at the entry you moved. If the entry is wholly obsolete, delete it and say in your report what was deleted and why, since nothing else will record that. Then go back to step 1 and select again; never implement an entry on the same pass that found it stale. The rewrite carries [scheduling lines](#scheduling-lines) like any entry you write. **Detached, edit nothing and select nothing:** the rewrite, or the deletion, goes into your `QUEUE_EDIT` and the invocation ends there.

Invoking this skill authorizes edits to the queue file. It authorizes nothing else the repo gates. If the rewrite implies a change to a settled doc, that is an author question, not a queue edit.

**`done` → confirm and close.** Check the evidence yourself — a git log and a look at the code, not a second subagent. If it holds, remove the entry and fix the order and references as above — detached, report `QUEUE_EDIT: close` with an empty diff instead. If it doesn't, treat the verdict as `stands`.

**`NEEDS_AUTHOR: yes` → block.** In autonomous mode, skip it and mark it (see below). Interactive, work the questions **strictly one at a time** — including for an entry that arrives already carrying the marker from an earlier autonomous run, and the marker comes off once its questions are settled:

1. Ask question 1 and only question 1. Lead with your recommended answer and the reason in a sentence or two, then name the alternative. `AskUserQuestion` when the answers are enumerable, plain text when they are not.
2. Discuss until you actually agree. If the direction looks wrong, say so once and plainly; if the author reaffirms it, build it that way and stop arguing.
3. Get an explicit confirmation. Enthusiasm is not confirmation. A subagent report arriving mid-discussion is not confirmation. Your own sentence saying you'll treat it as confirmed is not confirmation.
4. Record the settled answer where the repo says settled things go — showing the exact text and getting a yes on that text before writing it.
5. Only now ask question 2.

Never batch questions, never carry an unconfirmed answer into the next one, and never start implementing while one is open. When the last is settled, re-run step 2 with a fresh verifier if the answers changed what the entry asks for; otherwise go to step 4.

**`DEPENDS_ON` names an entry still in the queue that this one's `**After:**` does not already list → wait for it.** Check the claim first: open the other entry and confirm its Do really creates what this work needs, and that the thing is really absent from the code. If it holds, do not implement — building the missing piece here duplicates the other entry's work and collides with it when both land. Add the heading to this entry's `**After:**`, move the entry to just below the one it waits on if it sits above it, and go back to step 1. This is not a stale verdict and nothing about the entry is rewritten. **Detached, edit nothing:** report `QUEUE_EDIT: depends` and end the invocation. A dependency on something no queued entry provides is not this case — that is an ordinary stale or blocked verdict.

**`stands`, no author input → implement.**

## 4. Implement

You do this, in this context — not a subagent. You are the one holding the settled answers.

Follow the repo's rules exactly. The ones that usually bite: code only where the repo authorizes it, tuning values in the config file rather than constants buried in logic, comment style as the repo demands, no mechanism invented that the docs do not already describe, and measurements written to the findings doc rather than into a settled doc. Obey any cap the repo sets on batch or simulation runs, and check what is already running before you launch anything.

If implementing turns up a gap, **decide which kind it is before stopping.** A gap in the *design* — something that would change what the product is, reverse a settled decision, or add a mechanic nobody agreed to — is an author question, so go to step 3's block path, leave what you wrote uncommitted, and do not start another entry: a second entry's changes would tangle with the first's, and detached, nobody checked it for clashes. A gap in the *build* is yours: what the type looks like, where the state lives, what a condition may test, what one step hands the next. Choose it, write it down where the repo says such things go, name it in the report as a decision you took, and carry on. Stopping on a build gap is the single commonest way an entry gets abandoned half-done, and it asks the author a question they were never the right person to answer.

**If the entry is more than one pass of work, split it instead of starting it.** An entry whose scope is a whole document, or that would fill this context long before it closes, must not be taken up and abandoned halfway — that leaves a dirty tree and buys nothing, and under `/work-queue` it reads as a fault and gets the entry marked for a decision nobody actually needs to make. Rewrite it in the queue as two or more entries in the file's own format and order, each with its own [scheduling lines](#scheduling-lines) and every part after the first carrying `**After:**` on the part before it, take the first one, and say in your report what you split and where the rest went. Detached, the parts go into your `QUEUE_EDIT` rather than the file, and you still take the first. That is a queue edit, which this skill already authorizes. Splitting is not the same as finding an entry stale: the entry is right, it is only bigger than one invocation, so the standing check it already passed carries to the part you take.

## 5. Validation — a second context-free subagent

A fresh `general-purpose` agent. Not the step 2 verifier, not a fork.

**Keep the `agentId` the spawn returns.** Round two continues that same agent and addresses it by that exact id. Agents spawned this way have no name, so `general-purpose` — the subagent *type* — is not a handle and addressing it will fail. Losing the id means round two cannot happen at all.

Give it the entry as it stood, the repo path to run in, and the diff (`git status`, `git diff`). Detached, that path is your worktree, and say so plainly: a subagent starts in the caller's directory rather than yours, and a validator that runs `git diff` in the main tree sees an empty diff and passes nothing. The same goes for the step 2 verifier. Give it nothing about how the work went, what was hard, or what you believe you got right. Tell it to check and report, not to fix.

**A finding is a claim to check, never a fact to adopt.** Tell the validator to write findings as what the diff must be checked against — "line 40 says both baselines read zero; only one baseline follows the rebuild, so verify the count" — and never as a correction to paste in. A validator that hands over a figure of its own invention gets it copied into the work unread, and then flags it as a defect on the next round: an error it created, propagated, and billed a round for catching. Whatever a validator asserts about the repo, the implementer confirms against the repo before acting on it.

**The validator returns its verdict as its final message and messages nobody.** It has no one to notify: whoever is waiting on it receives its completion. A validator that tries to send its verdict onward is guessing at a handle it does not have, and the verdict goes missing while both agents wait.

It checks: the entry is satisfied exactly, not approximately; the repo's own gate passes, run by it; no doc now contradicts the change; the repo's rules were followed; nothing outside the entry's scope was touched; no unauthorized file was created.

**The repo decides what a validator is allowed to run, not this skill.** Read the gate out of `CLAUDE.md` and name that exact command in the prompt. Where a repo names one cheap command and rules out everything past it, that ruling holds: a validator that launches a long batch, a sweep or a simulation because "tests" sounded like it meant everything is burning the author's machine to re-confirm what the gate already covers. **A validator never re-takes a measurement to check a figure already reported** — it tests the reported figures against the diff for reasoning, units and scope, and says so when one does not follow. If the change cannot reach anything the gate measures, have it say why and skip the run rather than proving nothing at cost.

**Blocking and non-blocking are different findings, and only one of them costs a round.** A figure that does not match the run, a claim untrue of the code, a dead link, a scope claim a reader would draw a different conclusion from, or the entry not actually satisfied — those are `DEFECTS` and the verdict is `fail`. Wording that is merely looser than it could be is a `NIT`: "over x" where the figure reads closer to x, a superlative true of the table it sits under but not of every table, a hedge that could be sharper. **A report whose findings are all nits is a `pass`.** Fix them before closing and do not spend a round on them.

**This matters most on a docs-only diff**, where every finding is prose by construction. A validator holding prose to the standard of a figure turns each tightened sentence into another full re-read of the whole change, and the second read finds a third sentence, because there is always one more. Documentation has to be *right* — no wrong number, no false claim, no dead link — and that is what `DEFECTS` covers. It does not have to be optimally worded before an entry may close.

```
VERDICT: pass | fail
DEFECTS:            (blocking — wrong figure, false claim, dead link, misleading scope, entry unsatisfied)
- <file:line> — <what is wrong> — <what the entry asked for>
NITS:               (non-blocking — wording that could be tighter, changing no conclusion)
- <file:line> — <what would be tighter>
UNVERIFIED: <what it could not check, and why>
```

## 6. Close out

**Pass** → fix any nits it listed, remove the entry, fix the file's counts and cross-references the way step 3 describes, report. Detached, leave the file alone and report `QUEUE_EDIT: close`. **Nits are not re-checked** — a fixed nit that needed a second opinion was a defect and should have been reported as one.

**Fail** → confirm each named defect against the repo before touching anything, per the rule above, then fix exactly the ones that hold and say in your report if one did not. Then **send them back to the same validator rather than spawning a fresh one**. Continue it with `SendMessage`, addressed to the `agentId` from its spawn: it already holds the entry, the diff and its own findings, so it re-reads a delta instead of the whole change. Cold re-reads are what made rounds expensive, and a fresh agent re-reading everything is also what produces a new crop of unrelated wording notes each time. The context-free rule governs the *first* read, where a validator holding your conclusion is not a validator; round two asks only whether the named defects were fixed, which is the one question that validator is best placed to answer.

**Then wait for it, by ending your turn.** A turn that ends with no tool call while the validator is live does not finish you: the harness holds you until the validator completes and wakes you with its verdict, per the rule at the top. There is nothing to poll and nothing to report yet, so end the turn and let the wake come. What does finish you is ending a turn with nothing of yours outstanding, which is why the pass — verdict, fixes, close-out, report — is finished in the turn the notification wakes you into, and why a turn is never ended on `waiting for the validator` once the verdict has arrived: the caller would see a finished agent, the queue entry neither closed nor marked, and someone has to reconstruct where you got to. If you wake and the verdict is not in front of you, `SendMessage` the validator's `agentId` asking it to restate its report and end the turn again.

**Two rounds at most.** Still failing on defects, stop: the entry stays in the queue, the work stays uncommitted, and your report says plainly what fails and what you tried. Never remove an entry whose defects a validator has not cleared. If the second round returns only nits, that is a pass — fix them and close.

Do not commit unless the author asks, and never push. Say the work is ready and leave the commit to them. When `/work-queue` is driving, detached, it commits, rebases and merges your worktree's branch itself — that is its call, not yours.

Then stop. One entry per invocation.

## 7. Report

Lead with the outcome: which entry, and whether it closed, blocked, was re-sorted or was split. Then what the verifier found, which files changed, which gate the validator ran and what it said, and what is now at the top of the queue. Anything waiting on the author goes last, as a list of the actual questions. Detached, end with the `QUEUE_EDIT` block below.

## Scheduling lines

Two lines every entry you write carries, rewrites and split parts included, so `/work-queue` can tell which entries are safe to run at the same time. Put them after the entry's body, before any marker lines.

```
**Touches:** `src/agent.py`, `src/README.md`, `tests/agent/`
**After:** <another entry's heading, verbatim>; <another>
```

- `**Touches:**` — the repo-relative paths the work will edit, docs included. A trailing `/` means a whole directory, globs are fine, and `*` means the entry has to run alone. Never list the queue file itself. Write it from what the work will touch rather than what it is about: two entries about one feature that edit different files can run side by side, and two unrelated entries that both append to one README cannot.
- `**After:**` — the headings of entries that have to land first, separated by `;`, written without any leading number in a file that numbers its headings, since numbers shift with every landing. Leave the line out when there are none. An entry is only a dependency when this one's work needs its result, not when it merely reads better in that order.

A wrong `**Touches:**` costs a rebase conflict and a re-run, never a broken base, so a quick honest guess beats none. When you cannot guess at all, write `*`. An entry with no line at all is scheduled as `*` anyway.

## Detached mode

For `/work-queue` running several entries at once, each in its own git worktree on its own branch. It always comes with `autonomous`, keeps everything that mode changes, and changes four more things:

- **Work only inside the worktree path the caller gave you.** The caller's directory is the shared main tree, and other entries' work lands there while you run. `cd` into the worktree before every command and use absolute paths under it for every read and edit. Every subagent you spawn is told the worktree is its repo path. The worktree is a fresh checkout: gitignored things — environments, dependencies, generated data — are not there until you set them up the way the repo's docs say.
- **The queue file is read-only.** Other passes are reading it at the same time, and the caller is its only writer. Every step above that would edit it — removing an entry, a rewrite, a split, a block marker, a defect queued as a new entry — goes into the `QUEUE_EDIT` block instead, written out in full in the file's own voice so the caller can apply it as it stands.
- **A stale, done or blocked verdict ends the invocation.** Do not select another entry. The caller schedules entries around which files each one touches, and an entry you pick for yourself is one nobody checked for clashes.
- **Do not commit.** The caller commits, rebases onto the base branch, runs the gate and merges.

```
QUEUE_EDIT: close | block | rewrite | split | depends | none
ENTRY: <the heading you were given, verbatim>
QUESTIONS:     (block — the lines that go under **Needs the author:**, one per line)
REWRITE:       (rewrite — the whole entry as it should stand, scheduling lines and any marker lines included; or `delete` with the reason)
NEW_POSITION:  (rewrite — `top`, `after: <heading>`, or `<n>` in a file that numbers)
PARTS:         (split — every part as a whole entry, in order, then `CLOSED: <heading>` if you implemented and validated the first)
DEPENDS_ON:    (depends — the verifier's lines, each checked by you: `<heading> — <what it needs, file:symbol>`)
NEW_ENTRIES:   (any — defects no entry reaches, each a whole entry followed by its position, in NEW_POSITION's forms)
VALIDATION: pass | fail | pending | not-run   (fail = two rounds still failing; pending = the verdict never reached you)
TOUCHED: <git diff --name-only in the worktree, untracked files included>
```

`close` with an empty `TOUCHED` is a `done` verdict. `none` means the pass ended without any of the others — say why in the prose above the block.

## Autonomous mode

For runs where nobody is watching. It changes six things:

- An entry needing an author decision is **skipped**, not asked about. Before moving on, mark the block in the entry so the next run doesn't pay for the verification again.
- **The mark is one fixed shape, not one you invent.** A line reading `**Needs the author:**`, then the open questions under it, one per line. Do not reword it, and do not reach for whatever phrasing the file happens to use elsewhere: `/work-queue` selects the next entry by looking for exactly this string, and a marker worded differently by each subagent is one the loop cannot read back. If the entry carries a line saying it needs no decision, replace that line rather than leaving the file contradicting itself.
- Stale entries are still rewritten and re-sorted. That needs nobody.
- No question is ever asked. If a decision surfaces mid-implementation, it stops rather than deciding.
- Abandoning an implementation partway **ends this invocation** — never start a second entry to make up for it, because the next entry's work would tangle with it. Leave the work in place and say so in the report; under `/work-queue` the orchestrator keeps it on your worktree's branch and the loop carries on without you. An entry too big to finish is not this case: split it before writing anything, per step 4.
- Nothing settled or permanent gets written, because that takes the author's confirmation.

If every remaining entry is blocked, stop and report the full set of questions waiting, in queue order.
