---
name: next-task
description: Work the top entry of a repo's work queue end to end — `tasks.md`, or whatever the repo's CLAUDE.md names as its queue, such as a backlog.md. Reads CLAUDE.md first, then a context-free subagent checks the entry still stands against current code and data, the main agent implements it, and a second context-free subagent validates before the entry is removed. Stale entries get rewritten and re-sorted; entries needing an author decision are worked question by question, or skipped in autonomous mode. Says so and does nothing if the repo has no queue. TRIGGER when the user says "next task", "pick up the next task", "/next-task", or asks you to start on whatever is at the top of tasks.md. SKIP when the user names specific work directly rather than pointing at the queue, skip in favour of `/work-queue` when they want several entries worked unattended in a loop, and skip in favour of `/execute-plan` when the work is a phased plan file rather than a queue of independent entries.
---

# /next-task

One entry from the queue, verified before it is started and validated before it is closed. Both checks run in fresh subagents that know nothing about what you expect to find — a verifier holding your conclusion is not a verifier.

**Arguments** — any combination, in any order:
- *(none)* — take the first entry in the file and start, interactive. Never ask which entry to work on.
- `autonomous` (`auto`, `-a`) — skip anything needing an author decision. See the mode section at the bottom.
- a number or a word from a heading (`3`, `carnivory`) — target that entry instead of the top one.

**One entry per invocation. There is no loop mode here** — looping is `/work-queue`'s job, and it owns the parts that make a loop safe: whether the tree is clean enough to start another entry, whether the last one really closed, and when everything left is waiting on the author. A second loop in here would be a silent way to grind the whole queue inside one filling context.

## 0. Load

**Read `CLAUDE.md` first, if the repo has one** — the root file, plus any nested one covering the area you would be working in. Two reasons, in this order. Its rules override this skill wherever they disagree. And it is the first place to look for where the queue lives: a line saying the work queue is `backlog.md`, or `todo.md`, or anything else, settles the question whatever the file is called. Read the docs index too if there is one.

**Then find the queue.** If `CLAUDE.md` named a file, that is the queue — believe it over a filename match, even when a `tasks.md` also exists. Otherwise take the first hit from the repo root of `docs/work-in-progress/tasks.md`, `tasks.md`, `task.md`, `TASKS.md`, `backlog.md`, `BACKLOG.md`, `todo.md`, `TODO.md`, `.claude/tasks.md`.

**If there is no queue, say which places you looked and stop.** Do nothing else. Do not create a queue file, do not fall back to a plan or discovery doc, and do not start work you inferred from the docs — a repo without a queue is a repo this skill does not apply to, and inventing one is worse than doing nothing. Same if the file you found does not read as an ordered list of work items: say what you found instead and stop, rather than guessing at its shape.

Parse the entries in file order — the top one is the highest priority. A `Not To Do` section is a list of prohibitions, not entries: never select from it, and read it before writing any code.

## 1. Select

**With no argument, take the first entry in the file. It is the highest priority by being first, and there is nothing to ask about — go straight to step 2 with it.** Only skip past it when this session has already handled it, or when autonomous mode has ruled it blocked; then take the next one down, and so on.

A number or keyword argument overrides this and selects that entry instead. Never re-verify an entry a verifier has already ruled on in this session.

## 2. Standing check — context-free subagent

`Agent` with `subagent_type: general-purpose`. **Never `fork`** — a fork inherits this context and defeats the purpose.

The prompt carries only the repo path, the queue file path, and the entry's text verbatim. It does not carry your reading of it, your hypothesis, or which outcome you are hoping for. Tell the agent to read and run, not to edit or fix.

Instruct it to: read the repo's `CLAUDE.md` and docs first; check every factual claim in the entry against the current code and the current findings docs — numbers quoted in a queue entry are the likeliest thing to have gone stale; check whether the work is already done; check whether what the entry depends on still exists.

Require exactly this report:

```
VERDICT: stands | stale | done
NEEDS_AUTHOR: yes | no
CLAIMS:
- <claim, quoted> — holds | stale: <what is true now> <file:line or doc anchor>
QUESTIONS:          (only when NEEDS_AUTHOR: yes — one decision each, never bundled)
- <question> | recommend: <answer> | why: <one line> | alternative: <the other option>
REWRITE:            (only when VERDICT: stale — the entry rewritten in the file's own voice and format)
NEW_POSITION: <n> | because: <one line>
EVIDENCE: <files and docs actually opened>
```

`NEEDS_AUTHOR: yes` means the entry cannot finish without a call only the author can make — a design decision, a scope change, an edit to a settled doc. It does not mean a number needs choosing. Where the repo separates tuning levers from blocking questions, a lever gets a starting value and the work proceeds.

## 3. Branch on the verdict

**`stale` → rewrite and re-sort.** Apply the rewrite, move the entry to `NEW_POSITION`, renumber everything, and fix whatever else the file says about itself — intro lines that count entries or name which ones need the author, and cross-references to entry numbers. If the entry is wholly obsolete, delete it and say in your report what was deleted and why, since nothing else will record that. Then go back to step 1 and select again; never implement an entry on the same pass that found it stale.

Invoking this skill authorizes edits to the queue file. It authorizes nothing else the repo gates. If the rewrite implies a change to a settled doc, that is an author question, not a queue edit.

**`done` → confirm and close.** Check the evidence yourself — a git log and a look at the code, not a second subagent. If it holds, remove the entry and renumber. If it doesn't, treat the verdict as `stands`.

**`NEEDS_AUTHOR: yes` → block.** In autonomous mode, skip it (see below). Interactive, work the questions **strictly one at a time**:

1. Ask question 1 and only question 1. Lead with your recommended answer and the reason in a sentence or two, then name the alternative. `AskUserQuestion` when the answers are enumerable, plain text when they are not.
2. Discuss until you actually agree. If the direction looks wrong, say so once and plainly; if the author reaffirms it, build it that way and stop arguing.
3. Get an explicit confirmation. Enthusiasm is not confirmation. A subagent report arriving mid-discussion is not confirmation. Your own sentence saying you'll treat it as confirmed is not confirmation.
4. Record the settled answer where the repo says settled things go — showing the exact text and getting a yes on that text before writing it.
5. Only now ask question 2.

Never batch questions, never carry an unconfirmed answer into the next one, and never start implementing while one is open. When the last is settled, re-run step 2 with a fresh verifier if the answers changed what the entry asks for; otherwise go to step 4.

**`stands`, no author input → implement.**

## 4. Implement

You do this, in this context — not a subagent. You are the one holding the settled answers.

Follow the repo's rules exactly. The ones that usually bite: code only where the repo authorizes it, tuning values in the config file rather than constants buried in logic, comment style as the repo demands, no mechanism invented that the docs do not already describe, and measurements written to the findings doc rather than into a settled doc. Obey any cap the repo sets on batch or simulation runs, and check what is already running before you launch anything.

If implementing turns up a gap you would have to invent your way across, **stop**. That is an author question — go to step 3's block path with it. Leave what you wrote in the working tree, uncommitted, and do not start another entry: a second entry's changes would tangle with the first's.

## 5. Validation — a second context-free subagent

A fresh `general-purpose` agent. Not the step 2 verifier, not a fork.

Give it the entry as it stood and the diff (`git status`, `git diff`). Give it nothing about how the work went, what was hard, or what you believe you got right. Tell it to run things, not fix them.

It checks: the entry is satisfied exactly, not approximately; the build and tests pass, run by it; no doc now contradicts the change; the repo's rules were followed; nothing outside the entry's scope was touched; no unauthorized file was created.

```
VERDICT: pass | fail
DEFECTS:
- <file:line> — <what is wrong> — <what the entry asked for>
UNVERIFIED: <what it could not check, and why>
```

## 6. Close out

**Pass** → remove the entry, renumber, fix the file's counts and cross-references, report.

**Fail** → fix exactly the named defects and validate again with another fresh agent. Two rounds at most. Still failing, stop: the entry stays in the queue, the work stays uncommitted, and your report says plainly what fails and what you tried. Never remove an entry no validator has passed.

Do not commit unless the author asks, and never push. Say the work is ready and leave the commit to them. When `/work-queue` is driving, it commits between entries and will tell you so — that is its call, not yours.

Then stop. One entry per invocation.

## 7. Report

Lead with the outcome: which entry, and whether it closed, blocked, or was re-sorted. Then what the verifier found, which files changed, what the validator said, and what is now at the top of the queue. Anything waiting on the author goes last, as a list of the actual questions.

## Autonomous mode

For runs where nobody is watching. It changes five things:

- An entry needing an author decision is **skipped**, not asked about. Before moving on, mark the block in the entry so the next run doesn't pay for the verification again — use whatever convention the file already uses for author-gated entries, plus a short line naming the open questions.
- Stale entries are still rewritten and re-sorted. That needs nobody.
- No question is ever asked. If a decision surfaces mid-implementation, it stops rather than deciding.
- Abandoning an implementation partway **ends this invocation** — never start a second entry to make up for it, because the tree is dirty and the next entry's work would tangle with it. Leave the work in place and say so in the report; under `/work-queue` a recovery subagent stashes it and the loop carries on without you.
- Nothing settled or permanent gets written, because that takes the author's confirmation.

If every remaining entry is blocked, stop and report the full set of questions waiting, in queue order.
