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

## Follow-up to the rulings (`tapgap-rulings.md`)

### Results against the gates

Full run: `lune run tests/luau/tap_preview_report`, 3,840 races plus 60 realistic Rookie races. **10 of 11 gates pass; the report exits 1 on the boxed share.**

| Gate | Result | Limit |
| --- | --- | --- |
| Shared-screen overlaps | 0 frames | 0 |
| Shared jerks | 2 races | ≤ 3 |
| Own-screen overlaps | 1 race | ≤ 1 |
| Own-screen jerks vs layer off | 17,888 vs 17,562 | ≤ +5% |
| Order across the line | 0/1 (the same race as with the layer off) | no worse than off |
| Residual | 12.00 ft | ≤ capFeet |
| Messages | 0 on a loss, 0 for a masher | 0, 0 |
| Pull-back (Perfect rider, no lane room) | p99 3.31 ft, worst 6.90 ft | 4 ft, 8 ft |
| Lock fade | median 1.25 s, p95 2.23 s, worst 2.63 s | 1.5, 2.5, 3.0 s |
| Trust row | −0.70 points | ≤ +3 |
| **Boxed share, realistic Rookie** | **53.0%** of 21,450 samples | **≤ 40%: FAIL** |

How the boxed share is measured:
- Field: bots at the anchor ± 6, pace scores sd 15, riders on equal horses (rated at the anchor). Riders tap perfect, average or streaky.
- Share: of the time a rider's taps have at least 4 ft to show (`heldCue.minFeet`), the share during which lane room holds it back by at least that much.

**The realistic field is no better than the equal one, so the boxing is not a harness artifact.** For the acceptance switch rider (Rookie Mile, 60 races):
- the cue (4 ft for 1 s) fires in 44 of 60 races in both fields;
- time held at 4 ft or more is 60% in the realistic field and 66% in the equal one;
- the rider is held 1 ft or more at some point in the 5 s after the 3rd Perfect in 57 of 60 realistic races and 44 of 60 equal ones.

The cause is in-lane columns: Smart Steer homes riders to lane 2. With the next-lane bound switched off (`joinSlackFeet` 100), the held time is the same 60%.

Getting under 40% needs a decision change, for example Smart Steer reacting to the preview or a different home lane for riders. Ruling 2 accepted the share for this build and replaced the gate (below). With ruling 2's setup (Rookie Mile, four riders including the masher) the boxed share is **48.5%** (48.6% after the final fix batch).

### `joinSlackFeet = -7.5` was tried and not adopted

- Boxed share: 53.0% → 58.8% (+5.8 points, over the ruling's +5 limit).
- Equal-field acceptance races with room: 16 of 60 → 8 of 60.

So it stays at −4.

### Held API (published for the wiring)

- `TapPreview.held(tp, i) -> number`
  - Feet that lane room keeps lane `i`'s drawn horse behind its goal: `max(0, goal − drawn)` on a step where lane room held or pulled it.
  - 0 otherwise, and always 0 after the lock.
  - It is set by `step` and allocates nothing.
- **Server:** after `TapPreview.step` in `send()`, for each human lane:
  - read `TapPreview.held(tp, i)`;
  - fire the unreliable `TapHeld(feet, courseId)` to that player at most 2 Hz, only when the value changed by 1 ft or more;
  - send 0 once at the lock.
- **Client:** keep one cue per race:
  ```lua
  local cue = TapPreview.newCue()
  ```
  Every frame:
  ```lua
  local pressure, chip = TapPreview.stepCue(cue, GameConfig.tapPreview, heldFeet, dt, raceTime, locked, smart, sideRoom)
  ```
  - `heldFeet` = the last TapHeld value.
  - `smart` = no steering buttons are shown to the rider (Trip.riderControls kind `"intro"`).
  - `sideRoom` = SteerLane's `inSide` or `outSide` is `"free"`.
  - `pressure` = bob amplitude × 1.3 and one dust puff per stride. Skip it under Reduced Motion.
  - `chip`:
    - `"gap"` → "Find a gap! ◀ ▶" (riders with the buttons, a side free, at most every 10 s);
    - `"taps"` → "Your taps still count!" (riders without the buttons, once a race);
    - `nil` → nothing.
    - Never after the lock. Never use the words "boxed in".
  - `stepCue` allocates nothing.
- **Config:**
  ```
  GameConfig.tapPreview.heldCue = { minFeet = 4, minSeconds = 1.0, chipMinFeet = 6, chipMinSeconds = 1.5, chipEverySeconds = 10 }
  ```

### Tests added

All in `tap_preview_tests.luau`; the Luau suite is 1,833 of 1,833 checks.

- **`held`:** about 11 ft for a rider boxed 10 ft behind a horse in its lane with an 11 ft goal; 0 with the lane clear; 0 after the lock; 0 before any step.
- **`stepCue`:**
  - pressure after 1.0 s at 4 ft or more;
  - "gap" once after 1.5 s at 6 ft, and not again within 10 s;
  - nothing under 4 ft, no gap chip without a free side, nothing after the lock;
  - Smart Steer gets "taps" exactly once and never "gap";
  - the source scan finds no allocation.
- **Test (d):** "boxed" now means `held ≥ 1 ft`. Races with room are still 7/7: at least 4.11 ft by 2 s and 9.12 ft by 5 s.

The `race_overlap` harness gained `botAnchor` (bots rated at the league anchor, as RaceService fills them) and `riderRating`, plus per-rider boxed counts.

## Ruling 2: gates and results (supersede the "≤ 40%" gate above)

The boxed share is accepted for this build. In its place, `tap_preview_report` gates the realistic **Rookie Mile** run:
- 30 races per course;
- riders perfect, average, masher and streaky on equal horses;
- bots at the anchor ± 6, pace scores sd 15.

The harness runs `TapPreview.stepCue` per rider on the server's `held` value, twice:
- as the rider rides (Smart Steer, which shows the "taps" chip);
- as if steering with the buttons (the "gap" chip, with `sideRoom` from `Trip.riderLane`: a side `"free"`).

Full run (`lune run tests/luau/tap_preview_report`): 3,840 races plus 60 Rookie Mile races. **All 14 gates pass; the report exits 0.**

| Gate | Result | Limit |
| --- | --- | --- |
| Shared-screen overlaps | 0 frames | 0 |
| Shared jerks | 2 races | ≤ 3 |
| Own-screen overlaps | 1 race | ≤ 1 |
| Own-screen jerks vs layer off | 17,888 vs 17,562 | ≤ +5% |
| Order across the line | 0/1, the same race as layer off | no worse |
| Residual | 12.00 ft | ≤ 12 |
| Messages on a loss or for a masher | 0, 0 | 0, 0 |
| Pull-back | p99 3.31 ft, worst 6.90 ft | 4, 8 |
| Lock fade | median 1.25 s, p95 2.23 s, worst 2.63 s | 1.5, 2.5, 3.0 |
| Trust row | −0.70 points | ≤ +3 |
| Boxed share (Rookie Mile) | **48.5%** of 27,966 samples | ≤ 55% |
| Pressure cue when held ≥ 4 ft for 1 s | **109 of 109** rider-races | 100% |
| Gap chip when held ≥ 6 ft for 1.5 s with a side free | **91 of 91** (100%) | ≥ 80% |
| Masher chips; chip text containing "boxed" | 0; 0 of 243 chips | 0; 0 |

The boxed share here is 48.5%, lower than the 53.0% earlier. This run is Mile only and adds the masher, whose taps rarely have 4 ft to show.

### Tests and CI

- **Pytest:** `tests/test_tap_preview_report.py` runs the seeded subset (`tap_preview_report 6 boxed=3`, about 10 s). It requires every gate to pass and the exit code to be 0 (16 gates after the final fix batch).
- **CI:** the luau job in `.github/workflows/test.yml` runs the full report (about 12 minutes locally).

## Final fix batch (code review and consults)

### Changes

1. **Pull-back speed (feel).** `pullBackFeetPerSecond = 6`: whenever the drawn horse falls back on Trip's own, it gives ground back at most 6 ft/s. That covers a lead handed back at a close or the lock, a preview that came down, and a masher's drift. `pullPerSecond = 19` is now used only by lane room, to clear a horse that cuts in.
2. **Message (systems).** `TapPreview.message` returns only `"up"`, even when the rider is drawn 1st. `TapPreview.MESSAGES = { up = "Giddy-up! Moving up!" }`. Tests and a report gate check that no key or text contains "away", "lead" or "win".
3. **Held sends (review N6).** `TapPreview.newHeldSend()` and `TapPreview.heldSendDue(state, held, t, cfg) -> boolean`, configured by `GameConfig.tapPreview.heldSend = { feet = 1, minGapSeconds = 0.5, resendSeconds = 1 }`:
   - `state = { last, lastT }`: `last` is the value last sent, rounded to 0.1 ft; `lastT` is the race time it was sent. Start: `last = 0`, `lastT = −∞`.
   - `held` is rounded to 0.1 ft as `floor(max(0, held) × 10 + 0.5) / 10`.
   - **Due at once,** ignoring the minimum gap:
     - when the rounded value is 0 and `last > 0`;
     - when it crosses `heldCue.minFeet` (4) or `heldCue.chipMinFeet` (6) in either direction (≥ vs <, compared with `last`).
   - **Otherwise due only once `t − lastT ≥ minGapSeconds` (0.5),** and then:
     - when `|value − last| ≥ feet` (1); or
     - when `value > 0` and `t − lastT ≥ resendSeconds` (1). This resend repairs a lost unreliable packet.
   - When due, it sets `state.last = value` and `state.lastT = t`, and returns true. **Send `state.last`.**
   - It allocates nothing.
   - The harness now runs the cue on `state.last`, exactly what the client sees.
4. **Docs (N5).** `stepCue`'s `smart` means no steering buttons are shown, which is what the code does. **Tests (N9):** the 1,800-step loop now counts into one check.

### Gates

Full report: 3,840 races plus 60 Rookie Mile races. **All 16 gates pass; the report exits 0.**

| Gate | Result | Limit |
| --- | --- | --- |
| Shared overlaps | 0 frames | 0 |
| Shared jerks | 2 races | ≤ 3 |
| Own-screen overlaps | 1 race | ≤ 1 |
| Own-screen jerks vs off | 17,897 vs 17,562 | ≤ +5% |
| Order across the line | 0/1, the same as off | no worse |
| Residual | 12.00 ft | ≤ 12 |
| Messages on a loss / for a masher | 0 / 0 | 0 |
| Pull-back | p99 3.35 ft, worst 6.90 ft | 4, 8 |
| **Pull-back speed** (new) | **6.00 ft/s** | ≤ 6 |
| **Message words** (new) | keys: `up` only | no away/lead/win |
| Lock fade | median 1.25 s, p95 2.25 s, **worst 2.93 s** | 1.5, 2.5, 3.0 |
| Trust | −0.70 points | ≤ +3 |
| Boxed share (Rookie Mile) | 48.6% | ≤ 55% |
| Pressure cue (held ≥ 4 ft for 1 s) | 109 of 109 | 100% |
| Gap chip (held ≥ 6 ft for 1.5 s, side free) | 92 of 92 | ≥ 80% |
| Masher chips; "boxed" in chip text | 0; 0 of 247 | 0; 0 |

**Watch the lock fade.** Its worst case grew from 2.63 s to 2.93 s with the slower give-back, leaving 0.07 s against the 3.0 s gate. If the wiring's lock-time refresh doesn't shorten it, the lever is `fadeSeconds` (1 → 0.8), not the gate.

### Tests and CI

- `tap_preview_tests.luau`: 38 of 38 checks.
- `tests/test_tap_preview_report.py`: requires all 16 gates on the seeded subset.
- CI runs the full report.
- `python -m pytest -q`: 1767 passed. The policy guard passes.

