# Systems cross-review: tapgap-plan.md (D-070 draw-only preview)

**Verdict: AGREE-WITH-CHANGES.**

## What holds

- **Calibration is safe.** The layer only draws, and test 1 requires the race to come out identical with it on and off: Trip, τ, scores, `live`, order, prizes and the sent `lanes`. Bot means, the ladder sims and the parity checks are unaffected, so no Python mirror is needed.
- **Server cost is small.** There are at most 2 races per server. Each pass end calls `previewLive` once, an 8-lane softmax-and-tilt, at most about 2 Hz. `TapPreview.step` runs per send at 10 Hz × 8 lanes. It reuses the `RaceOffsets` remote, so nothing new goes over the network.
- **Integrity is unchanged.** Taps earn exactly what they earned before. A visible gain makes the existing reward clearer, but it creates no new incentive to use a macro. A masher loses one tap per pass, so their horse visibly drifts back. That gives honest feedback without any words.

## Required changes

1. **Kid trust report.** Add a test row: "drawn 1st at the lock, finished 4th or worse," layer on vs off, over the overlap report's races. It must not rise by more than 3 percentage points. A bigger lead before the lock makes the D-033 luck reorder easier to read as rigged. If the row fails, lower `capFeet`.
2. **Masher and streaky profiles in test 6.** The chip never fires for a masher. An average or mashing rider's drawn gain stays at 2 ft or less. That way the game never praises bad tapping.
3. **Own-screen nudge stacked on the preview.** The overlap check (test 2) must include the 5 ft tap nudge drawn on top of the preview offsets. Confirm that `RaceFx.nudgeRoom` reads the received drawn offsets, so your own screen never overlaps.
4. **Server budget guard.**
   - Compute `pv` only for races with at least one human, and only at a human's pass end.
   - `TapPreview.step` must not allocate.
   - Add a PLAYTEST microprofiler line: `RaceService` send stays under 1 ms per race on a 20-player server.
5. **Chip copy.** Keep "Giddy-up! +1 length." Never say "leading" or "winning" before the lock.

With these, it's a sound fix for the core problem: taps that a kid can see move the horse.
