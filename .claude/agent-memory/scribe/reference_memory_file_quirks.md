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
