---
name: project-race-realism-d072
description: D-072 phase A (filing in, styles, drift, passing, shut doors) findings: boxed-share levers, the rider baseline entry, sim cost, gates that conflict with the plan
metadata:
  type: project
---

Findings from building D-072 phase A in src/trip.py on 2026-10-12 (branch claude/race-realism):
- Filing riders to the rail (file.homeLane 1) does NOT reduce boxed share; it makes columns. Passing barely helps on the Rookie Mile because most pre-lock time is the clubhouse turn and Trip's targets don't see the tap preview's aim. The lever that works is `file.riderRoomFeet` (a Smart Steer rider heads in only with clear run ahead): 6 ft took the Python stand-in from 66.5% to 23%.
- The Python boxed stand-in (sims/realism.py) reads about 15 points above the Luau D-071 harness (66.5% vs 48.6-53% today); compare before/after, not absolute values.
- Riders and bots behaving differently gives a common tau shift that the per-post baseline cannot remove (its residuals are mean-over-posts). The fix is a "rider" entry in the style row (front, stalker, closer, rider), so a passive kid nets 0 among bots.
- With Smart Steer on the rail, D-054's "rail rider beats Smart Steer by 0.01-0.03" target collapses (about +0.002), and intent3s drops (the rail is crowded). These are plan consequences, not bugs.
- A full `python sims/steering.py --write` takes hours (6 h CPU at 1,000 report races). Don't edit trip.py or steering.py while it runs: Pool workers re-import them. Its own footprint is small since 2026-10-12 (workers ~25 MB, parent < 100 MB: pickled chunks, baseline one cell at a time; `--mem` prints peaks, `--out DIR` writes a scratch copy). Claude Code's low-memory reaper still kills idle background shells when the machine itself is short (about 1 GB free that day), whoever holds the memory.

**Why:** these were costly to find and the phase B (the move) tuning will hit them again.
**How to apply:** before retuning pack/pass/file values, rerun sims/realism.py (paired before/after) and read the D-072 rows in the steering report.

Related: [[project-tap-preview-d071]], [[feedback-windows-python-crlf]]
