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
- Never copy a model name from a commit trailer into docs (rule 5); bed9d9e/67f503f carry one and are exempt in policy_guard.sh. The AAA run is wrapped up (D-066..D-069); next is David's Studio playtest.
