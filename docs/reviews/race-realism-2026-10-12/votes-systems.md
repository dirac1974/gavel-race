# Systems vote: racing-plan.md (D-072)

**Verdict: AGREE-WITH-CHANGES.** Phase C, the move counting, is in scope as provisional behind `move.scale`, as David asked.

## What holds

- The draw-only and outcome split respects D-033 and D-055. The lock stays at the far turn, so τ never sees luck.
- A masher gets nothing: pips need clean single taps scoring 80 or more. Diamonds and 💵 never touch moves, pips or styles.
- The τ range of −0.02 to +0.056 is small next to the tap edge. The +0.016 move cap is less than half the trip ceiling.
- The gates are mostly right: boxed ≤ 35%, per-post and per-style ≤ 0.002, upsets ±1 pt, perfect ≤ 38%.

## Required changes

1. **Moves must be an edge between skilled and unskilled riders, not between humans and bots.**
   - As written, only humans earn `tauMove`, and Smart Steer gets one guaranteed move. Every human would gain about +0.008 against bots. That inflates solo win rates and the economy.
   - Fix it one of two ways:
     - (a) bots make moves at a tendency calibrated to an average kid;
     - (b) subtract the field mean of `tauMove`, as with the other τ terms.
   - Either way, Smart Steer's single move goes into the baseline, so a passive kid nets 0.
2. **Add sim rows:**
   - the share of races where `tauMove` changes the winner (≤ 2%) and changes any rider's place (≤ 8%);
   - the trip-part τ at p99 stays ≤ +0.04 (the clamp isn't saturated);
   - `--greencash` cash per race within ±2% (the D-070 waits are unchanged).
3. **Phase A is not cosmetic.** Filing, styles, the pass rule and shut doors change lanes, which changes ground and draft τ. Phase A needs `trip_d072.json` parity and the full §4 sim gates *before* the playtest, not after.
4. **Hurdles coupling (my ruling):**
   - In a fence zone (60 ft before to 30 ft after each fence), every horse holds its lane. That covers presses, Smart Steer filing, bot passes, shut doors and move spending.
   - Drift and stagger continue within the lane.
   - A lit move waits ("Jump first!"), keeps its pip, and fires after the zone if there is still room.
   - Passes and boxed-share gates are measured on flat races. Hurdles gets its own gate of at least 2 passes per race outside the fence zones.
5. **First-race safety:** with `introRaces = 0`, a kid's own presses in race 1 may cost τ down to the −0.02 floor. Clamp a rider's press-caused τ at ≥ 0 for their first 3 races, so early races are for learning, like the shut-door rule.
