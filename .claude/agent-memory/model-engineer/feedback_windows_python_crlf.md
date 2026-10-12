---
name: feedback-windows-python-crlf
description: On this Windows machine, Python text-mode writes and Git Bash `sed -i` turn CRLF repo files into LF/CRLF mixes; use newline='' or the Edit tool
metadata:
  type: feedback
---

When patching repo files with a Python script, open them with `newline=''` (read and write) and `encoding='utf-8'` (GameConfig.luau has non-ASCII; the cp1252 default crashes), or use the Edit tool. Plain `open(p, 'w')` writes CRLF, and `grep -c $'\r'` under Git Bash reports 0, so the change goes unnoticed. Check with `python -c "b=open(p,'rb').read();print(b.count(b'\r\n'), b.count(b'\n'))"`.

Never `sed -i` a tracked file here: on 2026-10-12 it silently stripped every CR from sims/steering.py. Long multi-line Python heredocs with mixed quotes can also fail to parse in the Bash tool; write the script to the scratchpad and run it instead.

**Why:** on 2026-10-11 a text-mode write converted TapPreview/RaceFx/RaceSession to CRLF and broke a source-scan test that looked for "\nend\n"; the sed incident cost a re-normalisation pass.
**How to apply:** any scripted multi-line edit in this repo.
