# Phase A (D-072) code review: filing in, the pack, passing, shut doors, learner floor, fixed lanes

Reviewer: code-reviewer, 2026-10-12. Branch `claude/race-realism`, uncommitted tree.
**Static review only.** Free memory was about 450 MB with the `--write` calibration running, so neither pytest nor Lune were run. The quick fixes (D-074 jump, steer keys) were skipped; see `quickfix-code-review.md`.

## Verified (no finding)

- **Parity.** `src/trip.py` and `Trip.luau` match line for line. I checked `new_state`/`Trip.new` (uniform layout `2n + 7i`), `_door_shut`/`doorShut`, `_door_wait`, `_pass_step`/`passStep`, `wave`, `_pack_step`, `pack_feet`, `_crowded`, `_blocker`, `tau` (style, learner floor, `fixed`) and the step-loop changes. The sentinels differ only by indexing (−1 vs 0). `wave` uses floor, not sin, so the two stay bit-identical. `trip_d072.json` is gitignored and generated, like the other fixtures.
- **Determinism and luck.** `RaceSession.new` draws luck and bot scores (`RaceSession.luau:140,148`) and the posts before `Trip.start`. The 7n new uniforms come after them, so neither luck nor the outcome reaches the pack. Later pace-schedule and burst-phase draws shift by 7n, which is harmless because they stay independent. PackEvent sends only pre-drawn, luck-free facts.
- **τ invariants.**
  - The style row is subtracted with the post's, before the field mean.
  - The learner floor sits inside the clamp, after the brush.
  - The monotonicity and clamp tests cover style and floor (`test_trip_d072.py:325`).
  - The sim reports the p99 before the clamp.
- **No shut doors on learners.** `_door_shut` returns before choosing a bot (`trip.py`, `Trip.luau doorShut`). `doorWouldShut` mirrors this, so a learner's arrow never greys from a door.
- **The PackEvent remote** goes server → all only, so no client input reaches it. It fires only from `trip.packEvents`, which grow only before the lock. The rate is small: a bot can shut a door at most once every 6.5 s, and there are at most 4 passes per horse (≤ 64 out/pass events a race). Each payload is 6 scalars.
- **Server authority.** `SteerRequest` still requires `cur.steers[player]`, and nobody gets steers in a fixed-lanes race (`RaceService.server.luau:781-784`). A forged press would answer "fixed" anyway.
- **Wording.** No wagering words and no model names in the diff or the new files.

## BLOCKING

1. **The game runs D-072 against D-057's baseline, with no style row.**
   - `GameConfig.luau:129-157` turns every block on.
   - `TripBaseline.luau` is dated 2026-10-06 and has no `styles`, so `Trip.styleRow` returns nil (`RaceService.server.luau:789`) and every style counts 0.
   - phaseA-sim.md measured exactly this state as a +0.007…+0.015 τ edge for a passive Smart Steer kid, with post bias up to 0.0034. That breaks the systems vote ("passive kid nets 0, no human edge").
   - Consensus: "Phase A changes outcomes, so it needs Python parity … and the full sim gates before David plays it."
   - Fix: don't merge or playtest until `steering.py --write` has regenerated `TripBaseline.luau` (posts and styles) and `make_fixtures.py` has re-stamped `.fixtures.sha256` (still dated 10-11). Then re-run the gates. Or ship with the blocks off until then.
2. **Commit trailer (hard rule 5).** This session's injected attribution again puts a model name in `Co-Authored-By`. Use `Co-Authored-By: Claude <noreply@anthropic.com>`.

## SHOULD

1. **The learner floor fires on any counted press.** `trip.py:605` and `Trip.luau:358` count `"steady"` and `"bounds"` presses too, and `learner_floors` (`trip.py:1383`, `Trip.luau:1198`) floors the whole τ, not just the part the presses caused.
   - A learner on the rail who presses ◀ once ("bounds", no lane change) gets τ ≥ 0 for free: an edge of E[max(0, −τ)] over passive kids and bots.
   - The systems vote said "clamp a rider's **press-caused** τ".
   - Fix: count only presses that changed something (accepted/queued/brush), and measure the learner edge in the sim. Otherwise accept it as a provisional choice in DECISIONS and REVIEW_QUEUE.
2. **Fixed lanes after the lock.** `Trip.cosmetic` (`Trip.luau:1585`) has no `st.fixed` guard. It is safe today only because every horse holds a distinct post lane.
   - Add `if st.fixed then return st.shown end` (or similar).
   - Let `Trip.submit` (`:1395`) refuse with "fixed" before queueing.
   - Test the whole race through `Trip.start`/`advance`/`frame`/`raceTau` with `fixedLanes`. The test at `trip_d072_tests.luau:356` says "Trip.raceTau too" but never calls it, and stops at 30 s, before the lock.
3. **The rulings aren't in the gates yet.**
   - `TARGETS_D072` (`steering.py:131`) still holds 0.002 for both cases; ruling 1 says kid-among-bots ≤ 0.002 and all-Smart ≤ 0.003.
   - `intent3s` (`:120`) is still 0.70; ruling 3 says ≥ 55% within 3 s and ≥ 85% within 6 s.
   - `weaveWindowSeconds` is still 7 (`trip.py:96`, `GameConfig.luau:106`); ruling 4 says 8.
   - Drawn overtakes (`OVERTAKE_FEET` 4 with hysteresis, `:84`) aren't ruling 8's "1 length clear held 2 s".
   - The Sprint pass band (1–10) isn't split out.
4. **The binding "every pass alongside ≥ 0.8 s" is relaxed to a median of 0.8–1.5 s with a 0.5 s floor** (`trip_d072_tests.luau:344-348`). Either add the closing cap or get a logged ruling.
5. **Traceability.** DECISIONS and REVIEW_QUEUE have no D-072 entry, and David's Hurdles ruling isn't recorded as "decided by David". Both are needed before commit (scribe).

## NIT

- The chip reads "No room yet" (`RaceController.client.luau:1627`, and the existing 1084/1637), but the consensus copy is "No room yet!".
- `RaceView.client.luau:346` fires PackDrawn for "out" and "pass" on receipt, not at draw time, which contradicts `RaceState.luau`'s "as RaceView draws it". Nothing listens to those kinds yet.
- `shutYawDeg = 3` (`GameConfig.luau:205`) may not read as "visibly turns toward the rider". Check it in the feel consult.
- `_pass_step`'s `s` parameter is unused (`trip.py:1105`).
- The `controls` type at `RaceService.server.luau:769` lacks `learner`, `pips` and `races`.

**CHANGES REQUESTED**
