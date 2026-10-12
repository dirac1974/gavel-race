---
name: ladder-phase3
description: D-068 ladder retune (2026-10-11) — realistic-Rating sim results, recommended anchors/Cup points/ceilings, open Champion drift and cash-inflation flags
metadata:
  type: project
---

On 2026-10-11 the AAA review's Phase 3 item 1 replaced the fixed LEAGUE_ENTRY premise with Ratings that grow under Training.WEEKLY_CAP. A casual horse gains about +1.5 Rating a week: 47 in week 1, 65 in week 12, about 80 at the plateau. Recommended values are in `economy.PHASE3`:
- anchors 32/35/38/48/56
- Cup points 100/200/450/900
- ceilings 55/57/60/66

The casual kid profile is 3 sessions × 10 races a week with new-kid riding. On these values it opens each Cup in 20/41/91/184 races and reaches Champion in week 12.

**Why:** the old values (46/56/69/80, 110/750/3000) gave a 10× Silver cliff, 231 then 799 races, and Champion only in week 37.

**How to apply:**
- Retune anchors, Cup points and ceilings together. `--ladder-search` goes league by league, because each league's entry Rating depends on the leagues below it.
- Gold enters at 22%, not 25%, because the horse gains about +9 Rating during a six-week stay.
- Open issues to revisit:
  - Champion win rate drifts to about 54% at the plateau, since there's no ceiling.
  - Faster access to big purses gave about 1.7× more Green Cash by week 12. D-070 resolved this by flattening the purses; see [[greencash-d070]].
  - Engaged players race ahead of their training: 17% entry win rate at Champion. `Training.raceGain` is the candidate fix.
- The systems consult added a light-profile gate: 1 session × 10 races plus 2 rides, so the cap every week. It passed: no horse arrived over a ceiling, and ceiling-opened Cups were won 31–34% of the time. Widening the gap to Bronze 56 / Silver 61 was worse because it closed 51% of light horses' Bronze races. Keep the gate test.
- κ stays at 1.0. A perfect rider already earns about 1.5× per race.
- Results doc: docs/reviews/aaa-2026-10-11/phase3-sim.md. See [[sim-conventions]].
