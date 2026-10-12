---
name: greencash-d070
description: D-070 Green Cash sink (2026-10-11) — B 20/30/45/65/85, Barn Builder catalog 45.3k, sim gates, and the open post-Champion pile for engaged kids
metadata:
  type: project
---

On 2026-10-11 D-070 (provisional) flattened the purses. The old values were 20/50/120/300/750; the new B is 20/30/45/65/85. The Cup stays at 3B.
- The sink is a 45.3k Barn Builder catalog plus 7.1k of stalls.
- The catalog lives in `economy.CATALOG`. The game copy is `game/src/shared/BarnCatalog.luau`, and a test checks that the two match tier by tier and price by price.
- `--greencash` runs the ladder career with a per-session `ledger`. The kid buys under a "wish" policy (cheapest item on the newest shelf), keeps a 50 feed reserve, and gets +15 jobs and −12/−25 feed a session.

**Why:** with the old B a casual kid had about 61k at week 12 and owned the whole catalog. The plan's Gold B of 60 put the median Gold wait exactly at the 2-session limit, so Gold went to 65 and Champion to 85.

**How to apply:**
- The gates in tests are:
  - median wait ≤ 2 sessions in Rookie through Gold;
  - week-12 pile ≤ 2× the next price for casual, casual-perfect and light;
  - no pile on arrival at Champion;
  - feed always affordable;
  - a perfect rider reaches each first item no later than a casual kid, and sooner on ≥ 3 of 5 shelves;
  - a skill premium ≥ 1.33×.
- Open issue: engaged kids own everything about 4 weeks after Champion (about 25k at week 12 and 57k for engaged-perfect). The recommendation was to accept this for launch and re-check with a multi-horse sim that includes Market horses.
- Watch for Diamond "time skips" in GAME_DESIGN. One that touches Energy, Training or the queue would turn Diamonds into Green Cash.
- Results are in docs/reviews/aaa-2026-10-11/greencash-sim.md.

See [[ladder-phase3]] and [[sim-conventions]].
