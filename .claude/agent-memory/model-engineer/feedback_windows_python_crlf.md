---
name: feedback-windows-python-crlf
description: On this Windows machine, Python text-mode writes turn LF repo files into CRLF; use newline='' or the Edit tool
metadata:
  type: feedback
---

When patching repo files with a Python script, open them with `newline=''` (read and write), or use the Edit tool. Plain `open(p, 'w')` writes CRLF, and `grep -c $'\r'` under Git Bash reports 0, so the change goes unnoticed. Check with `tr -cd '\r' < f | wc -c`.

**Why:** on 2026-10-11 this silently converted TapPreview/RaceFx/RaceSession to CRLF and broke a source-scan test that looked for "\nend\n".
**How to apply:** use it for any scripted multi-line edit in this repo.
