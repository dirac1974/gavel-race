# Systems consult: built Phase 1 and the Phase 3 ladder sim (2026-10-11)

## Phase 1: systems risks

**Burst arming barely moves scoring balance or bot calibration.**
- The burst's weight (2 of 6, about 40%) and the bots' burst scores (55 ± 15) are unchanged.
- Arming only removes reflex taps that land early at a random point and score about 50. So human burst scores rise a little, and win rates rise by a few points.
- That makes the Phase 3 sim's kid burst models (50/60/70) slightly pessimistic, which is the safe direction.
- Every league still has a full sweep after arming (the test at `game_tests.luau:72`).

**The config switch-backs are clean.** Each of these restores the pre-D-066 behaviour:
- `burstArmSeconds = 0`
- `tapNudgeFeet = 2`
- `raceFx.enabled = false`
- `raceView.bobFromLegs = false`
- `hud.sliderClearOfPad = false`
- `hud.rideMeterLabel`

The draw-only boundary holds (code review: nothing touches RaceSession, Trip or RaceShape scoring).

**MUST-FIX**

1. **B1 (agree it blocks):** the dust and trail attachments are placed in world coordinates as if they were local offsets (`RaceView.client.luau:409-410`). Parent the attachment first, then set `CFrame` in object space.
2. **N1, raised to must-fix:** `src/burst_meter.py` defaults `arm_seconds` to 0.0, so Python callers silently get pre-D-066 scoring.
   - Add `BURST_ARM_SECONDS = 0.5` as the default.
   - Add a regex test against `GameConfig.luau`.
   - Parity is a project rule, and future sims will call this function.

Should do: **N4.** Log in D-066 that the tick replaces the Great/Perfect chime, or keep both.

## Phase 3 ladder sim: verdict

**The cliff is fixed.** The casual counts go from 20/30/231/799 races to 20/41/91/184, a steady climb of about 2× per league. Entry win rates stay between 19% and 26% in every league. That fixes the "promotion feels like punishment" problem too. The method is sound: Rating comes from the training cap, there was one joint search, and the tests pin the whole ladder.

**Bots as rivals: acceptable.** Kids never see bot Ratings. They see win rates of 20–36% and faster sweeps in the higher leagues. A Champion bot at 56 sitting next to a Rookie ceiling of 55 is a number only grown-ups will notice.

**Champion stomp: accept it as provisional.** An average kid winning 54% at the plateau only happens from about week 26, long after the playtest. Win rate rises there, but purses B/q shrink as q grows, so cash doesn't run away. Put it in REVIEW_QUEUE now. My preferred later fix is legacy goals or breeding as the Champion goal, not bots that follow the rider's Rating, because those make training invisible (against D-061).

**Cash inflation: escalate it, but don't block this change.**
- About 106k Green Cash by week 12, against 7,100 of sinks, is worse than before.
- It harms no kid: nothing trades and nothing is sold. But Green Cash becomes meaningless faster.
- A Green Cash cosmetics sink, then purse flattening, must land before any soft launch. Record this as a gate in STATUS.

**One check is required before the values land (sim only, no value changes):**
1. **Light-player profile.** The ceilings sit in a narrow band (55/57/60/66, about 7 weeks of training from first to last).
   - A kid who trains to the cap but races about 10 times a week will pass each ceiling before earning the points. Their regular races close and RACE! becomes CUP! league after league.
   - Add a `light` profile (1 session × 10 races, 2 training rides) to `--ladder`.
   - Accept the change if a light kid always has a race they can enter and wins Cups at 30% or more. Otherwise widen the gap between Bronze and Silver ceilings (57 → 56, Silver 60 → 61) and re-run.
2. **Existing saves.** Any test or playtest horse already rated about 70 in Silver becomes over-ceiling twice and goes through a run of Cups. That's fine (no loss), but note it in PLAYTEST.

## Sign-off

- **Phase 1:** YES, once B1 and N1 are fixed.
- **Phase 3 values** (anchors 32/35/38/48/56, points 100/200/450/900, ceilings 55/57/60/66, κ 1.0): **YES**, conditional on the light-profile check passing. No value changes are required as it stands. Log the Champion endgame and the cash-sink launch gate in REVIEW_QUEUE and STATUS.
