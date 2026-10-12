# Phase 2 consult: gameplay (2026-10-11)

Reviewed the working-tree diff: `PacePreview.luau`, `RaceService.server.luau` (preview loop, RideRank), `RaceController` (coaching, judge at the marker, early-burst hint, card), `ResultsText`, `QueueCard` warm-up, and the Phase 2 config.

The Phase 1 must-fixes all landed:
- The early-burst hint and shake (`GameConfig.luau:260-261`).
- `zone2` greyed while the burst is unarmed (`RaceController`, the burst armed block).
- The tap tick at about 0.4 over hoofbeats ducked to about 0.3 (`GameConfig.luau:226-227`).

## Is my #1 problem ("taps don't visibly change the race") solved?

**Better, but not solved.** The post-lock preview is correct and safe. τ is already fixed at the lock, `previewLive` stores nothing, and checkpoint closes still set the scores. It covers only the far-turn lock to the end of checkpoint 2, which is about 10–15 s:
- about 15% of a Mile;
- under 10% of a Classic.

From the gate to the lock, most of the race, the only answer to a tap is still the 4–5 ft nudge, the Perfect surge, and one change of position when checkpoint 1 closes.

Combined with Phase 1's juice and the judge word at the marker, it now *feels* answered. It still doesn't *show* that "my taps made me faster" until the far turn. The PLAYTEST Phase 1 gate question will tell us whether that's enough.

## MUST-FIX

1. **The chance arrow flickers during previews.**
   - The arrow fires on any change over 0.003 (`RaceController.client.luau`, `LiveChances` handler, the `math.abs(live[i] - before[i]) > 0.003` line).
   - With previews every second from partial pass scores, it can flip up and down every second for about 12 s. That's noise right where the kid is watching the far turn.
   - Fix: show the arrow only when `seg` differs from the last `LiveChances` seg (a checkpoint close), or require a change over 0.01 and at least 3 s between arrows. Put it behind `hud.arrowOnPreview = false`.
2. **Log the scope of item 6 honestly.** Live pace previews before the lock are still not built. Keep them open as an explicit Phase 4 or backlog row in STATUS and REVIEW_QUEUE, so the Phase 1 gate result is read with that known gap. It must not read as done.

## SHOULD-FIX later

- **Steering-off races can preview the whole race (S).** With `trip == nil`, offsets come straight from `displayOffsets(shownLive)` (`Trip.frame:1381`), so there's no calibration risk. Today the loop needs `trip` (`RaceService.server.luau:978`), so those races get no preview at all. Allow it whenever `trip` is nil.
- **Pre-lock previews (M).** Add a draw-only preview delta in `Trip.frame` before the lock (not in `st.off`), clamped with `RaceFx.nudgeRoom`. This is the real close of problem #1.
- **Ride rank against bots is inflated.** Bot Final Bursts are N(55, 15), while a patient kid gets 85+. So "Best ride" will come easily in solo races. That's kind and acceptable, but watch the playtest for "★☆☆" alongside "3rd best ride!", which reads as contradictory. Consider showing the rank only when stars ≥ 2.
- **Warm-up slider.** It's correctly non-scoring and opt-in. Check that its sweep matches the horse's league `sweepSeconds` (Rookie 2.4 s), so the practice transfers to the race.
- **Coaching length.** `coachRaces = 1` may be short for an 8-year-old. Measure taps-per-pass in races 1–3 before raising it.
- **Carried over from Phase 1:** hoofbeat cadence (2 Hz vs legs at about 3.1 Hz), a surge on 3 Greats in a row, and moving the burst bar off the horse.

## Sign-off

**Yes for Phase 2**, conditional on MUST-FIX 1 (small) and 2 (docs). The results card, "Best ride", Race again, coaching and the warm-up deliver what I asked for in P3a, P5 and C13.

Problem #1 stays **open**, not closed.
