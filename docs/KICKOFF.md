# Running the team

Prompts David pastes into Claude Code (terminal, desktop, web, or the mobile app). Every session reads `CLAUDE.md` first, so these stay short.

## Build loop (implement → test → review → record → push)

```
Run one build loop from CLAUDE.md on the top backlog item in
docs/memory/STATUS.md. Delegate to the agents named there. Push to main
only when tests, the policy guard, and the code-reviewer pass. Finish with
a 5-line report: what shipped, tests, review verdict, decisions logged
(provisional ones in REVIEW_QUEUE.md), next item.
```

For several in a row: replace "one build loop" with "up to 3 build loops".

## Design debate

```
Have design-moderator run the next debate on the agenda in
docs/debates/README.md. Write the record, log the recommendation as an
Accepted (provisional) decision, and add it to REVIEW_QUEUE.md. Summarize
the recommendation and the main split in 5 lines.
```

## Research

```
Have roblox-researcher answer: <question>. Primary sources only, dated,
saved under docs/research/.
```

## Reviewing provisional decisions

```
My review of docs/memory/REVIEW_QUEUE.md: D-0NN keep, D-0NN change to <...>,
D-0NN reverse. Have scribe update DECISIONS.md, apply the code or config
changes, run the tests, and push.
```

## Status check

```
Summarize docs/memory/STATUS.md and REVIEW_QUEUE.md in 8 lines.
```

## Cloud sessions and routines

Set the environment's setup script to `bash scripts/setup_cloud.sh` (pytest and Lune). Routines at claude.ai/code/routines can run the build loop nightly and a design debate weekly with the prompts above. If pushing to `main` is blocked, the loop pushes a `claude/<topic>` branch and opens a pull request instead (CLAUDE.md step 7).
