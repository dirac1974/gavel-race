# Tap gap: results for the pure layer (D-071, provisional)

These are the model-engineer results for `tapgap-plan.md`, with required changes 1–4 from `votes-plans-systems.md` and the two feel/UI-UX additions (the pull-back test and the "Moving up!" message).

The preview is numbered **D-071**. Green Cash took D-070.

`RaceService` and the client are not wired yet. The wiring steps are at the end.

## What was built

| File | What |
| --- | --- |
| `game/src/shared/TapPreview.luau` | New pure layer: `new`, `setRider`, `setPreview`, `closed`, `step` (no allocation), `message`, `residual`. |
| `game/src/shared/RaceSession.luau` | `previewOwn(seg, partial, expected?)`: the preview chances where every other lane keeps its own pace. Stores nothing. |
| `game/src/shared/PacePreview.luau` | `beforeLock(tapCfg, steering, seg, closed, stretch)`: the steering-off whole-race branch. |
| `game/src/shared/RaceFx.luau` | `stepNudge(..., baseFall?)`: optional cap so your horse plus its tap nudge never falls back faster than 19 ft/s. |
| `game/src/shared/GameConfig.luau` | `GameConfig.tapPreview` table. |
| `tests/luau/race_overlap.luau` | Taps mode: four kid profiles plus `fixed60`/`switch`, pace schedule, scoring, post-lock shown-chance refreshes, the layer, the own-screen nudge, digest, luck shuffle, and the numbers. |
| `tests/luau/tap_preview_tests.luau` | Tests (a) to (g), plus the pull-back test. Registered in `run_all.luau`. |
| `tests/luau/tap_preview_report.luau` | The 3,840-race report, layer on vs off. |

## Two design changes from the plan (both provisional)

### 1. `previewOwn` replaces `previewLive` as the layer's `pv`

With `previewLive`, the preview shows the bots' real scores in the open checkpoint, which are drawn at the gate. When the bots happened to score better in checkpoint 2, a rider tapping all Perfect was drawn sliding back by up to 5.4 ft.

`previewOwn` keeps every other lane at its own pace instead:

- after the first close, each lane's score so far;
- before the first close, `botPaceMean`.

So only the rider's own taps move their horse. A rider tapping as before, or tapping the bots' average before the first close, moves 0 ft. The bots' scores still arrive at the close, as they do today.

### 2. Only riders get a preview (`previewBots = false`)

Bots still make room for riders. With bot previews on, the residual gaps between neighbouring horses doubled, and lane changes could no longer clear them.

## Tuned constants (`GameConfig.tapPreview`)

```
enabled = true, lead = 1.2, minPasses = 2, shrinkPasses = 2, capFeet = 12, capBackFeet = 6,
maxSpeed = 10, maxAccel = 20, laneGapFeet = 10, hardGapFeet = 7.5, hardLaneBand = 0.55,
pullPerSecond = 19, joinClearFeet = 8, joinSlackFeet = -4, settleFeetPerSecond = 2, fadeSeconds = 1,
previewBots = false, steeringOffWholeRace = true, messageEnabled = true, messageFeet = 8,
messageEverySeconds = 4, messageMinScore = 60, messageMinPasses = 6, messageMinClean = 0.8
```

- **`lead` and `shrinkPasses`.** The effective factor `lead · n/(n+2)` is at most 1.13 after 30 passes.
  - `lead = 1` misses the acceptance gains: 3.4 ft at 2 s and 7.6 ft at 5 s.
  - `lead = 1.2` with `shrinkPasses = 4` misses the 8 ft at 5 s target.
- **`capBackFeet = 6`.** A masher drifts back at most 6 ft, so the riders behind can still clear a lane change.
- **`joinSlackFeet = -4`.** A horse in the next lane is held at most `apart − 4` ft ahead of where Trip puts it once the two are 8 ft or more apart. This keeps a lane join clearable while Trip's own horse falls back at 10 ft/s.
- **`settleFeetPerSecond = 2`.** While Trip's horse moves away faster than 2 ft/s, for example a tuck-back, the residual waits instead of doubling that motion.
- **`hardGapFeet = 7.5`.** The own-screen nudge's 1 ft slack still leaves 6.5 ft, which is outside the 6 ft overlap.
- **`messageMinPasses = 6`, `messageMinClean = 0.8`.** At least 80% of the passes must be tapped exactly once, so a masher's doubled passes never earn the message. With 4 passes and no clean-pass rule, the masher got 3 messages in 200 races.

## Tests: `tap_preview_tests.luau`, 24 of 24 pass

| Test | Result |
| --- | --- |
| (a) 200 seeded races (25 per course and distance), layer on vs off | 200/200 digests identical: Trip `off`/`x`/`tgt` every tick, `live` every tick and at each close, τ, finish order, prizes, sent lanes. 200/200 same order. |
| (b) Luck shuffle, 12 race pairs | Every drawn offset before the lock is identical. A source scan finds no `luck` in TapPreview's code. |
| (c) Limits | 0 shared overlap frames and 0 own-screen frames (nudge stacked). 0 jerk frames; fastest server fall back 19.0 ft/s. Order across the line unchanged. Residual at most 12 ft. Away from lane room the residual moves at most 10.00 ft/s and 20.06 ft/s² (+0.25 tolerance for the settle step). Residual gone at most 2.43 s after the lock (bound 2.8 s). |
| (d) Rookie Mile, bots at 60 (sd 0), equal horses, switch rider (60, then all Perfect from 15 s) | Where the field leaves room (7 of 30 races): at least 4 ft within 2 s of the 3rd Perfect (lowest 4.11 ft) and at least 8 ft within 5 s (lowest 9.12 ft), 7/7 each. **Boxed in 23 of 30.** Rider at 60 throughout: +0.00 ft. Masher: at most +0.59 ft, 0 messages. |
| Pull-back (Perfect and fixed-60 riders, 16 races) | At most 0.14 ft beyond Trip's own fall at any close or the lock. |
| (e) Steering off, 30 races | The order on screen at the last tap equals the result, 30/30. |
| (f) Trust | Drawn 1st at the lock and finished 4th or worse: 36.0% on vs 38.0% off. |
| (g) Allocation | `step` has no table constructor, `table.` call, closure or string building; 5,000 steps grow the heap by 0 KB. |
| Messages | 1,126 shown; none for a masher, none on a loss; at least 4.0 s apart. |

## Report: `lune run tests/luau/tap_preview_report` (d057 mode, 3,840 races)

Riders were perfect, average, masher and streaky. Each race ran with the layer on and off from the same seed, and every rider's own screen drew the tap nudge (with the `baseFall` cap).

| Row | Layer on | Layer off |
| --- | --- | --- |
| Shared-screen overlap frames | **0** | 0 |
| Own-screen overlap frames | **2 frames, 1 race** | 0 |
| Shared jerk frames (falling back faster than 20 ft/s) | **7 frames, 2 races** (fastest 47 ft/s) | 0 |
| Own-screen jerk frames | 17,888 | 17,562 (the D-066 nudge's own, see below) |
| Order across the line wrong | 0 last-frame, 1 crossing | 0, 1 (the same race: not the layer) |
| Rider reversals, sideways acceleration | 3.5 s gap; 30.6 ft/s² | |
| Residual away from lane room | at most 10.00 ft/s and 20.1 ft/s² | |
| Residual gone after the lock | median 1.25 s, 95% 2.23 s, at most 2.63 s | |
| Messages | perfect 17,840; average 2,595; streaky 2,000; **masher 0**; on a loss 0; at least 4 s apart | |
| Trust row (drawn 1st at lock, finished 4th+) | 44.24% | 44.95% (change **−0.70 points**, limit +3) |
| Perfect rider's extra pull-back, no lane room involved | close: 99% 3.54 ft, at most 6.90 ft; lock: 99% 3.18 ft, at most 4.80 ft | |

**The report exits 1.** Each failing row is below.

### Known shortfalls (for the tech lead and the design council)

1. **Boxed-in riders don't move.**
   - In a bunched equal field, Smart Steer puts most horses in lanes 1–2 columns, 10 ft apart. The layer won't draw a horse through the one ahead in its lane, so the rider's gain is blocked about 77% of the time. That's 23 of 30 acceptance races.
   - Where there is room, every acceptance target passes.
   - The levers that would help are design calls:
     - let Smart Steer see the preview. This changes decisions, so it needs a recalibration and breaks test (a) by design;
     - show "Find a gap!" while the preview is held.
2. **Rare lane-join jerks.**
   - 7 shared frames in 2 of 3,840 races, plus 2 own-screen overlap frames in 1 race.
   - Cause: Trip tucks a rider back at its 19 ft/s hold pull while it glides into a lane behind a horse. Then the residual has no fall-back budget left under the 20 ft/s jerk line.
   - Removing them needs either `joinSlackFeet ≤ -7.5`, so a rider could never be drawn ahead of a horse just ahead in the next lane, or TapPreview being given Trip's tuck state.
3. **Lock residual takes longer than planned.**
   - The plan asked for the residual to be gone within `fadeSeconds + 0.2` (1.2 s). That is physically impossible from 12 ft at 10 ft/s and 20 ft/s².
   - Measured: median 1.25 s, worst 2.63 s. The layer holds for 1 s while the shown offsets catch up, then eases out.
4. **Pull-back in mixed fields.**
   - Steady riders against steady bots: at most 0.14 ft.
   - Against random bots, the field's checkpoint scores arriving at a close or the lock can still pull a Perfect rider's drawn horse back. 99th percentile is 3.5 ft at a close and 3.2 ft at the lock; worst 6.9 ft.
   - With `lead = 1` the worst case is about 2.9 ft, but the acceptance gains fail.
5. **Own-screen nudge needs the cap.**
   - With RaceView's nudge as it is, the layer raises own-screen jerk frames from 1,508 to 8,580 in 80 races.
   - With `RaceFx.stepNudge`'s new `baseFall` cap it adds only 2% (17,888 vs 17,562 over 3,840 races). The remaining frames are D-066's own nudge snaps.

## API for the wiring (roblox dev)

These changes are all in `RaceService.server.luau` and RaceView/RaceController.

1. **At the gate.** After `Trip.start`, when `TapPreview.enabled(GameConfig.tapPreview)` and the race has a human:

   ```lua
   tp = TapPreview.new(#session.lanes, GameConfig.tapPreview, trip.lead, GameConfig.steering.gapRampSeconds, GameConfig.steering.laneBand)
   for i, lane in session.lanes do TapPreview.setRider(tp, i, not lane.isBot) end
   ```

2. **At each pass end** in the open pace checkpoint before the lock, only when a human rides:
   - `done` = the passes of `session:pacePasses(seg)` with `t1 <= now()`.
   - For each human lane: `score, _, single = PaceMeter.score(done, taps, bounce)`; then `partial[i] = score` and `clean[i] = single / #done`.
   - Call:

     ```lua
     TapPreview.setPreview(tp, session.live, session:previewOwn(seg, partial), #done, partial, clean)
     ```

3. **After each `session:closeSegment(seg)`:** call `TapPreview.closed(tp)`.

4. **In `send(stamp, frameDt)`, after `Trip.frame`:**

   ```lua
   offsets = TapPreview.step(tp, offsets,
       if trip.locked then trip.shown else trip.x,
       if trip.locked then trip.shownTgt else trip.tgt,
       stamp - tStart, trip.locked)
   ```

   - `t` is race time. `step` takes `dt` from successive `t` values, so pre-lock sends with `frameDt = 0` are fine.
   - It returns `tp.d`, the same table every call. Fire it at once.

5. **At the lock:** in `advanceTrip`, right after `setTrip`, refresh `shownLive` once with `previewLive` (when `PacePreview.afterLock` is true).
   - This lets the shown offsets rise to the drawn horse within the 1 s hold, so the residual is absorbed instead of decayed.
   - The harness models this refresh.

6. **Message.** In `send`, before the lock, for each human lane call `TapPreview.message(tp, i, stamp - tStart)`.
   - `"up"` → "Giddy-up! Moving up!"; `"away"` → "Pulling away!"; `nil` → nothing.
   - Fire it to that player only; the client shows the BillboardGui.

7. **Steering off (`trip == nil`).** At each pass end, when `PacePreview.beforeLock(GameConfig.tapPreview, false, seg, session.closed, false)` is true, run `previewStretch(seg)`. That is the existing `previewLive` refresh of `shownLive`.

8. **RaceView `myNudge`.** Pass `baseFall = max(0, lastOffset − race.offset[myLane] * ramp)` as the 6th argument of `RaceFx.stepNudge`. `nudgeRoom` already reads the received (drawn) offsets.

`GameConfig.tapPreview.enabled = false` gives exactly today's race: the layer returns Trip's offsets unchanged (tested).

## Invariants and parity

- No decision changes, so no Python mirror is needed (D-012 scope note).
- `src/RaceMath.luau` is unchanged.
- No change to `src/gavel_race_v2.py`.
- The `test_invariants.py` and Luau property checks pass unchanged: chances positive and summing to 1, monotonicity, equal scores give base chances, expected cash.
