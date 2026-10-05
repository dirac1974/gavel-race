# Running the team

Prompts David pastes into Claude Code (terminal, desktop, web, or the mobile app). Every session reads `CLAUDE.md` first, so these stay short.

## Build loop (implement → test → review → record → push)

```
Run one build loop from CLAUDE.md on the top unblocked backlog item in
docs/memory/STATUS.md. Delegate to the agents named there. Push to main
only when tests and the code-reviewer pass. Finish with a 5-line report:
what shipped, tests, review verdict, decisions logged, next item.
```

For several in a row: replace "one build loop" with "up to 3 build loops, stopping early if anything needs my decision".

## Design debate

```
Have design-moderator run the next debate on the agenda in
docs/debates/README.md. Write the record, log the recommendation as a
Proposed decision, and add the question to OPEN_QUESTIONS. Summarize the
recommendation and the main split in 5 lines.
```

## Research

```
Have roblox-researcher answer: <question>. Primary sources only, dated,
saved under docs/research/.
```

## Answering open questions

```
My answers to docs/memory/OPEN_QUESTIONS.md: 1) <answer> 2) <answer>.
Have scribe record them as Accepted decisions and update CLAUDE.md if a
hard rule changes.
```

## Status check

```
Summarize docs/memory/STATUS.md and OPEN_QUESTIONS.md in 8 lines.
```

## Cloud sessions

Set the environment's setup script to `bash scripts/setup.sh` so pytest is available. If pushing to `main` is blocked, the loop pushes a `claude/<topic>` branch and opens a pull request instead (CLAUDE.md step 7).
