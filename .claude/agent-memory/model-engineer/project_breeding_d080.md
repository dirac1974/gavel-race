---
name: breeding-d080
description: Breeding model D-080 findings - plateau math, anchor/share gate tension, stable-wide foalEveryRaces, module-name clash in sims
metadata:
  type: project
---

Breeding reference built 2026-10-12 (src/breeding.py, Breeding.luau, sims/breeding.py, docs/reviews/breeding-2026-10-12/sim.md).

- Plan's P* = 75 + dsel/0.3 overstates: best-2-of-3 foals gives dsel ~0.6, so generational lines from top-tier founders FALL to ~77 (79 with Legend). Only greedy whole-stable selection holds ~89 (its founders' level). Breeding never beats the Market top tier by more than ~1 pt.
- Systems rulings replaced per-parent rest with stable-wide foalEveryRaces 60 (p.breeding.nextAt), share 0.75, anchor 80 -> model engineer used 80.5 so pure line >= 83 while greedy <= 92 (91.7). Both gates sit near their edges; anchor is the knob (each +0.5 ~ +0.45 pure, +0.25 greedy).
- Surprise excludes parents' own coats; only pinto+appaloosa falls back to 50/50.
- sims/breeding.py shares a module name with src/breeding.py: it loads the model via importlib as "breeding_model". Keep that if editing.
- test_trip_d057 baseline tests were already failing at b6696a6 (trip.CONFIG vs stored baseline), unrelated.

**Why:** designers were voting on the plan while numbers were set; future breeding work should start from these sims.
**How to apply:** rerun `python sims/breeding.py --all` after any breeding config change; check the fee-share and Rookie gates first. Related: [[life-arc]]
