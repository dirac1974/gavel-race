---
name: memory-file-quirks
description: Line endings and format quirks of docs/memory files (CRLF vs LF) and where AAA review sources live
metadata:
  type: reference
---

- Line endings drift: at Phase 3 (2026-10-11) DECISIONS, REVIEW_QUEUE, CHANGELOG, OPEN_QUESTIONS and docs/MEMORY.md were CRLF, STATUS was LF. Never trust a fixed list, and don't trust `grep $'\r'` in Git Bash (it reported LF for CRLF files). Count bytes with Python (`open(p,'rb').read().count(b'\r\n')`) and append via a script that matches. The Edit tool preserves CRLF.
- Large reads of DECISIONS.md overflow tool output; read by line range (`grep -n "^## D-"` first).
- AAA review run (2026-10-11): sources in `docs/reviews/aaa-2026-10-11/` (CONSENSUS.md = phase plan, D-066..D-069). Each phase gets a code review + four consult files; their must-fix items, N1 "build calls", and unfixed should-fixes must be logged in D-NNN ("Still open") and REVIEW_QUEUE before commit. Verify which fixes landed by grepping GameConfig/client code, not from the review text.
- Phases overlap: Phase 3 code sat in the tree while recording Phase 2; record only the phase asked for.
- CHANGELOG had missed commits before (ee4615c, bed9d9e); check `git log` against it each time.
- Same endings held at Phase 4 (2026-10-11): all CRLF except STATUS (LF). Phases 1–3 + Phase 4 first pass landed as ONE commit (67f503f) though CHANGELOG has a line per phase.
- Same endings at D-070 (2026-10-11). The scratchpad can hold stale files from earlier sessions: if Write says "File has not been read yet", the file already exists, so use a fresh unique name and never append a scratch file whose Write failed (this once appended old D-066 rows to REVIEW_QUEUE; fixed with `git checkout` since the file was clean).
- Post-AAA plans (Green Cash D-070, tap gap D-071) live in the same review folder: `greencash-*`, `tapgap-plan.md`, `plans-consensus.md` (numbering), `votes-plans-*`, `consult-greencash-*`. CHANGELOG had missed df2d9d3; added.
- Same endings at D-071 (2026-10-11). DECISIONS lines are so long that Read with no limit fails (>256 KB); use offset+limit. A commit can carry two decisions (1456d70 = D-070 plus D-071's unwired layer); check `git show --stat` before writing its CHANGELOG line. GameConfig comments can lag the code (D-071 comments still quoted removed copy); verify copy in the module that owns it (`TapMessage.luau`), not in comments.
- Same endings at D-072..D-074 (2026-10-12). Race-realism sources: `docs/reviews/race-realism-2026-10-12/`. Code was still changing while recording (review fixes landing mid-session: learner floor, weaveWindow 8 in trip.py only), so grep the code for each review item and say "being reworked" when unsure. A decision David makes himself (D-073 lane rule) gets "decided by David", no REVIEW_QUEUE row of its own beyond a reference row.
- Same endings at D-075..D-079 (2026-10-12; docs/research/README.md is CRLF too). Fun-and-return sources: `docs/reviews/fun-and-return-2026-10-12/` (brief, consensus, lifearc-sim with Rulings + re-run, phase*-code-review, consult-*). Commits 7f312ba and 2b70430 are local "wip:" checkpoints, and a wip commit can carry another run's docs (7f312ba holds the fun-and-return brief/proposals). The caller's spec can differ from code (asked for 🌱 Young; code has 🍼 because 🌱 = family line, D-064; "Top Horse" not "Star"); record the code and note the gap. When a run reverses older decisions, append a "Superseded in part by D-NNN" note to the old Status line.
- Never copy a model name from a commit trailer into docs (rule 5); bed9d9e/67f503f carry one and are exempt in policy_guard.sh. The AAA run is wrapped up (D-066..D-069), and the Green Cash + tap preview run (D-070, D-071) too; next is David's Studio playtest.
