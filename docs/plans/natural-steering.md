# Plan: natural steering, boxed in and brushes (debate 012, D-057)

Copy targets: the decision text in B goes into `docs/memory/DECISIONS.md` after D-056; the rows in B2 go into `docs/memory/REVIEW_QUEUE.md`; C and D go into `docs/plans/training-and-steering.md` as a new "Steering, part 2 (D-057)" section (or a new `docs/plans/natural-steering.md`). The debate record is `debate_012.md` → `docs/debates/012-natural-steering.md`; also add item 11 to the agenda in `docs/debates/README.md`.

The prototype (`prototype/` next to this file) is scratch. `trip012.py` is `src/trip.py` with every rule below behind a config switch; with the default config it reproduces `src/trip.py` exactly (`check_parity.py`). `sim012.py`, `stress.py` and `make_tables.py` produced `prototype/results/tables.md`. Use them as the reference for N1, not as code to paste: names follow the prototype, and N1 renames `bump*` to `brush*`.

---

## B. Decision text (paste into DECISIONS.md)

## D-057 — Natural steering, boxed in and brushes

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 012. All four agreed after one rebuttal round on the motion rules, boxed in and the brush rule. The glide time split 2–2 (moderator chose 1.0 s), and so did the body-turn gain; the brush cap split 3–1. David asked for steering that "looks natural, sort of like a real horse moving", no zig-zag, horses that are "boxed in" when surrounded, and the team to consider bumping that slows the bumper "a little".
- Decision:
  - **Natural motion (the same for players, Smart Steer and bots; Trip runs it on the server):**
    - **The glide is an S-curve.** Sideways speed builds up at 4.5 lanes/s² (27 ft/s²), caps at 1.5 lanes/s (9 ft/s, a 9° drift at 56 ft/s), and brakes at the same rate. One lane takes 1.0 s from press to arrival (about 2.3 strides). D-054's glide was linear: 0.6 s at 10 ft/s, starting, stopping and reversing instantly.
    - **Chaining:** a second press the same way continues the glide without stopping (from 0.3 lane before arrival). Two lanes take 1.6 s, three 2.3 s, four 3.0 s. One press can wait; an opposite press cancels a waiting one (as D-054).
    - **Commitment:** a glide always finishes.
    - **Reverse gap:** a change the other way starts at least 0.5 s after landing.
    - **Weave gap:** a second reversal within 7 s of the last one waits 2.5 s after landing (5 s in debate 012; 7 s since the N1 review brought every masher cell under 8 reversals a minute).
    - **Bounce:** presses within 0.2 s count once.
    - **Glide reserve:** a horse gliding into a lane keeps 6 ft more room ahead and behind (clearance 14 ft ahead and 16 ft behind it).
    - **The make-room lanes after the lock** (`Trip.cosmetic`) glide on the same curve.
    - **The body:**
      - It turns with its true drift (atan of sideways over forward speed: ≤ 9°, capped at 10°), smoothed over 0.15 s.
      - It leans into the move by at most 3°.
      - On your own press it "looks" first: a 3° turn toward the press at once, held until the slide starts, or relaxed over 0.3 s if the press waits. This stands in for a head turn; the split models have no separate head.
      - Legs keep striding by distance moved (D-051).
      - The chase camera follows the track, not the body turn.
    - **Latency:** the slide starts with the server's lane. The S-curve covers 0.05 lane in its first 0.15 s, so a round trip hides inside the ease-in. SteerPredict no longer draws your sideways move ahead of the server, so a refused press never snaps back. The look cue is the instant answer.
  - **Boxed in:**
    - **No room on a side:** the rail or the outer edge, or a horse in that lane's clear zone (8 ft ahead to 10 ft behind, plus the reserve if it is gliding in). This is Trip's existing clearance rule.
    - **Boxed in:** no room on either side and a horse within 12 ft ahead in your lane.
    - **The arrows:**
      - **Out ▶ greys** (with a small horse icon) while that side has no room.
      - **◀ In greys only when trapped:** no room inside and no slot within the 3-length tuck reach (about 1% of race time). Most blocked inward presses are solved by tuck-back, and a grey button that works teaches kids not to press it.
      - Grey arrows still take presses. No buzz, no red.
    - **Presses:**
      - Inward with room: it glides.
      - Inward without room: the horse steadies back (tuck-back: automatic, at once, up to 3 lengths, visual only, as D-054) and slips in behind ("Tucked in!" as today).
      - Inward and trapped: the press keeps waiting for a gap or a tuck slot (as D-054; a press Out cancels it). Dropping it after 3 s cut casual reach in the dirt Miles from 69% to 54%.
      - Outward without room: it waits up to 1.5 s, then drops with a soft 0.2 s wobble of the arrow and no sound (D-054's promised shake; none under Reduced Motion).
      - A waiting press shows a ring on its arrow: lit while an inward press waits, filling over 1.5 s for an outward one.
    - **Chips** (riders with buttons only; at most one steering chip every 2 s):
      - "No room yet" after a press has waited 1 s with no glide and no tuck-back; at most once per 10 s.
      - "Gap!" (with `tap_good`) when a press that waited at least 0.5 s fires.
    - **No boxed-in cost** (unchanged from D-054). Being boxed costs only its natural cost: you can't reach the rail until you steady back.
  - **Brushes (rule-based contact in Trip; no collision bodies, no Roblox physics):**
    - **When:** a second press (the third since the N5 review: `brushPresses = 3`) toward a horse alongside (within 8 ft lengthwise in the next lane, alongside for at least 0.3 s), within 2 s of the first press, while the first press still waits and no tuck-back is possible. A first press never brushes, and a re-press many seconds later is a new try.
    - **What happens:**
      - The mover leans at most 1 ft toward the other horse over 0.4 s and nods.
      - It steadies back 4 ft (in Trip's offsets, recovering at 2 ft/s) and can't steer for 1 s. Its waiting press clears.
      - The other horse nods only: no slowdown, no chip, no name shown.
      - Both keep striding: no stumble, pinned ears or squeal.
      - Sound: `count_tick` at half volume.
    - **The mover pays, only the mover:** 0.002 τ per brush after the first free one, at most 3 charged (0.006, 0.3 points of S), and at most 4 brushes a race (after that presses just wait).
    - **Formula:** τ_i = clamp(scale × (trip_i − postBaseline − field mean − brushCost × charged_i), floor, ceiling). The brush term comes after the field mean (a brush never raises or lowers anyone else), sits inside the clamp, and is fixed at the lock. It never depends on luck.
    - Smart Steer and bots never brush. Nobody brushes after the lock.
  - **Server authority:** the server owns lanes, the no-room state, brushes and costs. The client's grey arrows and rings come from the 10 Hz lanes and the rider's own `SteerLane` state, as advice.
  - **Targets** (sims, every course × distance): see Tuning.
- Why:
  - **Natural motion.** A real horse changes paths over strides, not frames, and racing rules punish crossing "when insufficiently clear" (ARCI-010-035, AR 131(a)). Sideways acceleration falls from 100–200 ft/s² at 10 Hz (instant starts and reversals) to at most 30. A masher reverses 7 times a minute with at least 3.5 s between reversals, instead of 29 a minute every 0.6 s. Casual riders are untouched (1.3 reversals a minute either way).
  - **Boxed in.** David's "can't move left or right" is literal now: no sideways move into a horse, ever, and the arrow says so. The escape stays real: jockeys steady and slip in behind. Without tuck-back, steering stops working (rail riders reach the rail within 3 s 4% of the time instead of 93%), and strangers can hold a kid wide (own trip −0.015, p5 −0.06).
  - **Brushes.** They answer David's "bump and slow down" the way racing does: the horse that moved pays (ARCI-010-035 E(4)). A second press within 2 s charges casual riders in 0.4% of races (mean under 0.0001), and a griefer who bumps a kid pays every time while the kid pays nothing.
- Tuning (moderator's prototype, debate 012; all 8 course × distance cells):
  - **Acceptance targets** (regenerated baselines, 1,000 races per cell and post, 300 report races per cell). Every D-054 target still passes in every course × distance:
    - rail rider vs Smart Steer +0.017 to +0.026;
    - never-steer −0.014 to −0.016;
    - draft share 20–36%;
    - post bias ≤ 0.0022 (kid among bots and all-Smart);
    - Smart Steer kid mean −0.0009 to +0.0005.
  - **Reach target replaced.** "Inward press reaching its lane within 3 s ≥ 70%" is now counted **per intent** (no press by that rider in the 3 s before): 74–100% per cell (150 races per cell on the report seeds, final rules). Per press it falls to 64–96% (dirt Mile 69%, dirt Marathon 64%), because the slower glide and reverse gaps stretch some moves past 3 s in jammed fields, and each re-press counts again. The per-press figure stays in the report.
  - **New targets, all met:**
    - masher reversals ≤ 8 a minute with none within 3 s of the previous (7.1, 3.5 s);
    - sideways acceleration ≤ 30 ft/s² between ticks (30; D-054 200);
    - casual riders charged for a brush in ≤ 5% of races (0.4%);
    - griefing, targeted minus untargeted own trip ≥ −0.001 (−0.0005 to +0.0031);
    - 0 overlaps and fall-back ≤ 20 ft/s in 4,000 stress races.
  - Boxed (Smart Steer kid): 5.5% of pre-lock time; at least 1 s in 21% of races; trapped about 1%.
  - Brushes (second press within 2 s):
    - casual riders: 1.9% of races have one, 0.4% are charged;
    - wanderers: 35% / 13.5%, mean 0.0004;
    - mashers: 80% / 64%, mean 0.0032;
    - rail riders and ditherers: 0.
  - Griefing (strangers who tapped exactly like the kid; the kid's own trip, final rules): shadow −0.0011, crew of 3 +0.0011, bumper −0.0007. The same strangers riding for the rail without targeting anyone: −0.0013 and −0.0020. Targeting gains nothing.
- Alternatives:
  - **A 0.8 s glide** (Engagement, Young player; peak 10 ft/s, 37 ft/s²). It also passes every target (per-intent reach 76–100%) and is the playtest switch.
  - **Body turn 1.5× the drift, capped at 12°** (Engagement, Competitive): a horse drawn turning more than it moves reads as skidding.
  - **A reverse gap only**, without the weave gap: still sways every 1.5–1.9 s.
  - **Refusing opposite presses:** a press that does nothing.
  - **Wait for a gap without tuck-back:** steering stops working, and it is a griefing vector.
  - **A boxed-in penalty:** it hits rail riders making the right play and unlucky posts, and it is a griefing tool.
  - **A brush on any press at a horse alongside:** charges 51% of casual races.
  - **The bumped horse paying, or both:** a kid's score would depend on a stranger's presses. With an any-press trigger the kid was charged 1.2 bumps a race.
  - **Roblox physics collision bodies:** exploitable client-owned parts, lag on your own horse, no Python/Luau parity, and overlaps and jerks come back.
  - **No bumping at all** (Young player's opening): doesn't answer David, and a refused press has no physical feel.
  - **A brush cap of two charged** (Child safety).
- Amends:
  - D-054: the glide, presses into blocked lanes, the trip formula (brush term), Smart Steer and bots (same motion);
  - D-054 S3: SteerPredict no longer draws your sideways move ahead of the server;
  - D-054: the promised "no room" shake (never built) becomes a soft 0.2 s wobble when an outward press drops.
- Config (`GameConfig.steering` unless noted):
  - `glide = "eased"` ("linear" = D-054), `laneSpeedMax = 1.5`, `laneAccel = 4.5`, `chainWindow = 0.3`;
  - `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5`, `weaveWindowSeconds = 7` (5 in debate 012; 7 since the N1 review), `pressBounceSeconds = 0.2`, `glideReserveFeet = 6`;
  - `blockedPress = "wait"` ("d054" = D-054), `gapWaitSeconds = 1.5` (outward), `gapWaitInSeconds = 0` (0 = an inward press waits until room, as D-054), `tuckAfterSeconds = 0`;
  - `brush = "repeat"` ("off" = none), `brushAlongFeet = 8`, `brushGraceSeconds = 0.3`, `brushRepeatSeconds = 2`, `brushPays = "mover"`, `brushCost = 0.002`, `brushFree = 1`, `brushMaxCharged = 3`, `brushCheckFeet = 4`, `brushRecoverPerSecond = 2`, `steadySeconds = 1`;
  - `GameConfig.steerView` (new): `yawGain = 1`, `yawMaxDeg = 10`, `yawSmoothSeconds = 0.15`, `leanDegPerFtps2 = 0.12`, `leanMaxDeg = 3`, `lookDeg = 3`, `lookRelaxSeconds = 0.3`, `brushLeanFeet = 1`, `brushLeanSeconds = 0.4`, `brushNodDeg = 2`, `brushVolume = 0.5`, `headTurnDeg = 0` (the art follow-up sets 12);
  - `GameConfig.steerHud`: `greyArrows = true`, `waitRing = true`, `noRoomChipAfter = 1`, `noRoomChipEvery = 10`, `gapChipAfterWait = 0.5`, `chipMinGap = 2`.
- Links: debate 012 (`docs/debates/012-natural-steering.md`), src/trip.py, sims/steering.py, game/src/shared/Trip.luau, game/src/shared/SteerPredict.luau, game/src/client/RaceView.client.luau, game/src/client/RaceController.client.luau, game/src/server/RaceService.server.luau, game/src/client/Replay.client.luau

## B2. REVIEW_QUEUE rows

| Decision | Summary | How to reverse |
| --- | --- | --- |
| D-057 (motion) | Lane changes move like a horse: an S-curve glide on the server for every horse (1.0 s a lane, peak 9 ft/s, 27 ft/s²; two lanes 1.6 s), no reversing mid-glide, 0.5 s before reversing and 2.5 s before a second reversal within 5 s (no zig-zag), presses within 0.2 s count once; the body turns with its true drift (≤ 10°), leans ≤ 3° and "looks" 3° toward your press at once; the slide starts with the server's answer (no snap-back). 0.8 s is the playtest alternative | `GameConfig.steering.glide = "linear"` (D-054's 0.6 s glide); `laneSpeedMax`/`laneAccel` (0.8 s: 1.667 / 5.56); `reverseGapSeconds = 0`, `weaveGapSeconds = 0`; `GameConfig.steerView.yawGain = 0` (no body turn) |
| D-057 (boxed in) | A side with a horse in its clear zone has no room: Out ▶ greys; ◀ In greys only when tuck-back can't help (trapped). Inward presses still tuck back at once; trapped inward presses wait for room (as D-054) and outward ones 1.5 s, with a ring on the arrow; "No room yet" after 1 s of nothing (≤ once per 10 s), "Gap!" when a waiting press fires. **No boxed-in cost** (griefing test: targeting a kid gains a stranger nothing) | `GameConfig.steering.blockedPress = "d054"`; `GameConfig.steerHud.greyArrows = false`, `waitRing = false` |
| D-057 (brushes) | Rule-based brushes, no physics: a second press within 2 s toward a horse alongside while the first waits (and no tuck-back possible) leans the mover 1 ft, nods both horses, steadies the mover 4 ft and pauses its steering 1 s; **only the mover pays**, 0.002 τ after the first free one, at most 0.006 a race, fixed at the lock; bots and Smart Steer never brush; nothing after the lock. Casual riders are charged in about 0.4% of races | `GameConfig.steering.brush = "off"` (no brushes); `brushCost = 0` (visual only); `brushMaxCharged = 2` (Child safety's cap) |

---

## C. Implementation stages

Every stage is one PR. Every value lives in `GameConfig.steering`, `GameConfig.steerView` or `GameConfig.steerHud`, mirrored in `trip.CONFIG` for the model's keys. Stages N1–N2 add the rules switched off (D-054 behaviour, existing fixtures untouched). N3 flips the server behaviour and regenerates once. N4–N5 add what kids see. N6 is the docs and the optional head split. Order: N1 → N2 → N3 → N4 → N5 → N6. N4 and N5 are independent once N3 is in.

### N1. Python model and sims (model-engineer; no game change)

- `src/trip.py`, all behind `CONFIG` keys whose defaults reproduce D-054 bit for bit:
  - **State:** `v` (sideways lanes/s), `last_dir`, `arrived_at`, `last_rev_at`, `brushes`, `charged`, `check` (feet), `steady_until`, `along_since[2]`, `smart_block_at`, `last_press_at`, `events`.
  - **Eased glide** in step 4 (`glide = "eased"`). Per tick, `adt = laneAccel × dt`. The braking speed is `vb = adt × (sqrt(0.25 + 2 × dist / (adt × dt)) − 0.5)`, the speed from which steps of `adt` stop exactly in `dist`. Then `v += clamp(sign × min(laneSpeedMax, vb) − v, ±adt)` and `x += v × dt`; snap to the lane and set `v = 0` and `arrived_at` on arrival.
    - `sqrt` is correctly rounded under IEEE 754 in both CPython and Luau, so parity holds. Add it to the module's allowed-operations note.
    - If a parity case ever drifts, replace `vb` with the sqrt-free test "brake when `dist` ≤ the stopping distance from `v + adt`", where the stopping distance is `adt × dt × k(k+1)/2` with `k = v/adt`.
  - **Chaining** (`chainWindow`): the lane-change loop may start a same-direction change while |tgt − x| ≤ chainWindow; Smart Steer chains inward the same way.
  - **Reverse and weave gaps** (`reverse_gap(st, i, t)`): checked in `accept_intent` (the opposite press waits in the queue) and in the step loop (the wait timer restarts once the horse may move). `last_rev_at` is set when a change starts opposite to `last_dir`.
  - **Bounce** (`pressBounceSeconds`): a press in the same direction within 0.2 s of the last answered one is answered "bounce" and does nothing, not even pausing Smart Steer again.
  - **Glide reserve** in `_slot`: a horse with `tgt == lane` and `x != lane` blocks within `clearFeet + glideReserveFeet` ahead and `holdGap + glideReserveFeet` behind.
  - **`blockedPress = "wait"`** in `_try_move`:
    - inward: tuck at once when the slot is within `tuckBackMax`; otherwise wait (until room when `gapWaitInSeconds = 0`, else that long, then clear `want`);
    - outward: wait up to `gapWaitSeconds`, then clear.
    - Smart Steer uses `smart_block_at` as its wait clock.
  - **Brushes** (`brush = "repeat"`):
    - **Alongside tracking** after the first hold, per side: the nearest horse within `brushAlongFeet` lengthwise in the next lane (by x within `laneBand`, or tgt), ties to the lower gap then the lower index. `along_since` records when it started.
    - **In the intents loop, before `accept_intent`:** a press brushes when all hold:
      - the side has a horse alongside since at least `brushGraceSeconds`;
      - the mover is at rest and not steadying;
      - `want == d` (its first press is still waiting) and that press came at most `brushRepeatSeconds` ago (`first_press_at`, set when a press is accepted);
      - no tuck-back is possible (outward, or inward with no slot within `tuckBackMax`), and the mover isn't tucking for that press;
      - it has had fewer than `brushFree + brushMaxCharged` brushes.
    - **A brush:**
      - clears `want`/`queued`;
      - sets `steady_until = t + steadySeconds`;
      - charges the payer(s) by `brushPays` (`mover` only in the shipped config);
      - adds `brushCheckFeet` to the payer's `check`, which the skill-target loop subtracts like `tuck` and which recovers at `brushRecoverPerSecond`;
      - appends `(t, "brush", mover, other, d)` to `events`;
      - answers "brush". Presses while steadying are answered "steady" (they still pause Smart Steer).
  - `brush_charge(st, i) = brushCost × min(max(0, charged − brushFree), brushMaxCharged)`.
  - `tau(trip, posts, baseline, cfg, brush=None)` subtracts `scale × brush[i]` after the field mean and before the clamp.
  - `lock()` clears steadying and waiting presses as today.
- `sims/steering.py`:
  - **Policies:** `masher` (4 presses/s, random side), `ditherer` (alternating every 0.2 s), and the griefers `shadow`, `crew_in`/`crew_out`/`crew_ahead`, `bumper`, plus untargeted `rail1`/`rail3` controls. A `match` option pins a rider's skill target to the kid's plus N feet (the worst case).
  - **New report blocks:** reversals per minute and the shortest gap (masher, ditherer, casual); the sideways speed and acceleration distribution and maximum drift; the boxed share by post and policy, plus trapped; brushes per race and cost by policy; the griefing table (own trip and τ, targeted minus untargeted); reach per intent (below).
  - `--profile d057` runs the D-057 config, so N1 can show the targets before the flip.
  - **Reach per intent:** an inward press counts once if no press came from that rider in the previous 3 s, and it is "reached" if the horse is in its goal lane within 3 s. The per-press figure stays in the report for comparison.
- `tests/fixtures/make_fixtures.py`:
  - keep `trip.json` (200 D-054 runs, now carrying their config block explicitly);
  - add `trip_d057.json`: 200 scripted runs on the D-057 config with masher, ditherer and second-press brush cases. Expected values at fixed ticks: x, v, tgt, off; the trip, charges, events and τ with the brush term. Inputs go in as exact decimal strings as today.
- `tests/test_trip.py` (new cases):
  - default config: identical to before (all existing tests and fixtures pass unchanged);
  - D-057: a glide never reverses mid-way;
  - no change opposite to the last one starts within 0.5 s of landing, or within 2.5 s if it is a second reversal within 5 s;
  - sideways acceleration between ticks ≤ `laneAccel` × 1.05 (in lanes/s²);
  - free glides: one lane in ≤ 1.0 s, two chained in ≤ 1.7 s;
  - a first press never brushes; a press that could tuck never brushes; Smart Steer and bots never brush;
  - no brush within `brushGraceSeconds` of a horse coming alongside;
  - `brushPays = "mover"` never charges the other horse;
  - the brush term sits after the field mean and inside the clamp; nothing changes after the lock;
  - the griefing check (targeted minus untargeted own trip ≥ −0.001, mean over 200 races per cell);
  - 0 overlaps (half a lane and 6 ft) in 400 random-press races.
- Size: about 700–900 lines with tests.

### N2. Luau parity and overlap tooling (roblox-engineer; still D-054 behaviour in game)

- `game/src/shared/Trip.luau`:
  - mirror every N1 change line by line (same order, same ties);
  - `GameConfig.steering` gains every new key with D-054 defaults;
  - the bounce sits in `Trip.acceptIntent` (shared with Python), not only in `Trip.submit`.
- `Trip.cosmetic` (Luau only, after the lock): make-room glides integrate `x` with the same eased law when `glide = "eased"`.
- `tests/luau/run_all.luau`: load `trip.json` and `trip_d057.json`, merging each file's config block over `GameConfig.steering` (fixtures stop depending on whatever `GameConfig` holds).
- `tests/luau/race_overlap.luau` and `overlap_report.luau`:
  - masher and ditherer riders;
  - an injectable D-057 config block;
  - new counts: reversals per minute per rider, the shortest reversal gap, sideways acceleration of drawn lanes (ft/s²) before and after the lock, and brushes.
- Gate: 960 races per row, with D-057 injected and with defaults: 0 overlaps, ≤ 20 ft/s fall-back, the order across the line right.
- Added in the PR #49 review (eased glide only, after the lock): the make-room lanes plan ahead instead of dodging late, and keep the reverse and weave gaps. The d057 report also gates late full-lane moves (≤ 100 per 960 races in the last 2 s) and after-lock reversals (none within 3.5 s of the last). A `jitter=` option measures a jittery link; it is informational until N3.
- No visible change in game.

### N3. Flip the server behaviour; motion visuals (roblox-engineer; model-engineer regenerates)

- `GameConfig.steering` and `trip.CONFIG`: `glide = "eased"`, `laneSpeedMax = 1.5`, `laneAccel = 4.5`, `chainWindow = 0.3`, `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5`, `weaveWindowSeconds = 7` (5 in debate 012; 7 since the N1 review), `pressBounceSeconds = 0.2`, `glideReserveFeet = 6`, `blockedPress = "wait"`, `gapWaitSeconds = 1.5`, `gapWaitInSeconds = 0`. Brushes stay `"off"`.
- **Regenerate** with `python sims/steering.py --write`: `TripBaseline.luau`, `tests/fixtures/trip_baseline.json`, `steering_report.json` (with the new targets) and the `trip_d057.json` expectations if any default changed. Update `docs/research/steering-calibration.md`.
- **New shared pure module `game/src/shared/SteerPose.luau`**:
  - `SteerPose.step(state, xPrev, x, dt, forwardSpeed, look)` returns yaw and roll in radians.
  - Yaw: drawn sideways speed (Δx × laneWidth / dt) → `atan2(v, forwardSpeed) × yawGain`, clamped to ±yawMaxDeg and smoothed over `yawSmoothSeconds`; the look cue adds `lookDeg` toward the press.
  - Roll: sideways acceleration × leanDegPerFtps2, clamped to ±leanMaxDeg, smoothed.
  - Zero at rest. Sign convention tested for both directions and both courses' turns.
- **`RaceView.client.luau`:**
  - Lanes interpolate the server's 10 Hz samples over one send interval (like offsets), replacing the constant-rate lerp. Your own horse does the same.
  - **Interpolate by the server's timestamp, not by arrival.** Each sample carries the server's race time, and the screen draws one send interval behind the newest sample. Or keep a one-sample buffer, so there is always a next sample to move toward. With 0–30 ms of random delay, interpolating on arrival makes drawn lanes stall and then jump: 90 ft/s² against 30.6 on a steady link. Offsets drawn the same way show horses falling back at up to 22.2 ft/s in a quarter of the races (63% with D-054's drawing). `overlap_report d057 jitter=0.03` measures this (960 races: no overlaps, the order right). It is informational in N2, and N3 makes it pass and gates it, for offsets as well as lanes.
  - `place()` applies `CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll)` from SteerPose per horse.
  - The legs keep using the distance moved.
  - Race horses beyond 150 studs skip the pose, as legs do.
- **`SteerPredict.luau`:**
  - `press` no longer draws a lane. It returns "look" when the press is answerable (the room check stays), and `laneTo` follows the server's lane only.
  - `AHEAD` and the sideways prediction go.
  - Update `steer_controls_tests.luau`: the press answer, no drawn sideways move, no snap-back over a 0.25 s link.
- **`RaceController.client.luau`:** on a press, trigger the look cue in RaceView (`RaceState.lookSteer(dir)`). It relaxes after `lookRelaxSeconds` if no glide starts.
- **Chase camera:** keep the Follow camera on the track heading. If Studio shows it swinging with the body turn, set the camera subject to a track-aligned attachment under the seat (Studio check, PLAYTEST.md).
- **`Replay.client.luau`:** SteerPose from consecutive recorded frames (with `timeScale`), so replays turn and lean too. Recordings from before D-057 work unchanged.
- **Tests:** SteerPose pure tests; the overlap report (N2 gate) on the live config, with the jitter row (`jitter=0.03`) now gated; `steering_tests`/`steer_controls_tests` updated; the policy guard and syntax check.
- **Logs:** the `[Trip]` line adds reversals refused by the gaps and waits that dropped.
- **As built (2026-10-06; DECISIONS D-057 N3 note, REVIEW_QUEUE "N3" rows):**
  - `Playback.luau` (shared, pure) plays the samples back by their server stamps for RaceView and the overlap report alike; RaceService stamps each sample with the time its state stands for. The jitter rows pass and are gated.
  - The pose lives in `SteerPose.luau` (`step` plus `angles` for the CFrame sign); the look cue's state is `SteerPredict.look` / `lookDir`.
  - SteerPredict's D-054 prediction stays for the linear glide, and RaceView draws the linear glide exactly as D-054 did, so the switch-back is D-054 on screen too (the D-054 overlap reports print what main printed).
  - Not built: the 150-stud pose cut-off (the legs have none; the pose is one CFrame multiply). The camera stays Follow; the swing check is in PLAYTEST.
  - The sims' default profile is the game's config (`live`); `d054` keeps the D-054 baseline and report for the switch-back.

### N4. Boxed-in UI (roblox-engineer)

- **Server** (`RaceService`, `Trip`): `SteerLane` becomes `(tgt, dest, ack, wait, waitAt, tucking, courseId)`, course last.
  - `wait` = the direction of a press waiting for a gap (0 if none).
  - `waitAt` = server time it started waiting.
  - `tucking` = whether a tuck-back is under way for it.
  - Sent on change, as today.
- **`SteerPredict.sideState(view, dir)`** (pure): "free", "tuck" (no room, but a slot within `tuckBackMax`; inward only) or "blocked". It uses the same clearance (with the reserve for gliders) on the drawn lanes and offsets, and is tested against Trip's `_slot` on fixture frames.
- **`RaceController`:**
  - **Arrow states.** Normal. Grey with a small horse icon when "blocked": Out ▶ when that side has no room; ◀ In only when "blocked", never when "tuck".
  - **Wait ring.** While `wait` matches: lit for an inward press (it waits for room), filling over 1.5 s for an outward one. It is 3 px, the button's colour, and has no pulse under Reduced Motion.
  - No buzz, no red. A grey arrow still sends presses.
  - **Drop wobble:** when an outward press drops (`wait` goes to 0 with no lane change), the arrow wobbles ±4° for 0.2 s with no sound; none under Reduced Motion.
  - **Chips:**
    - "No room yet" when `now − waitAt ≥ noRoomChipAfter` and not `tucking`, at most once per `noRoomChipEvery`;
    - "Gap!" + `tap_good` when a wait of at least `gapChipAfterWait` ends in a lane change;
    - a shared limit of one steering chip per `chipMinGap`;
    - "Tucked in!" as today.
- **Copy:**
  - GrownUps: "Horses can get boxed in, like in real racing. They wait for a gap or ease back to find one. Being boxed in never costs points."
  - The ghost-thumb tip is unchanged.
- **Tests:** `SteerPredict.sideState` cases; chip rate limits as a pure helper (`SteerChips`) with tests; arrow-state table tests.
- **As built (2026-10-06; DECISIONS D-057 N4 note, REVIEW_QUEUE "N4" rows):**
  - The side states come from the server (`Trip.riderLane`, using `Trip.sideState`), carried by `SteerLane` as `(tgt, dest, ack, wait, waitAt, tucking, inSide, outSide, courseId)`. There is no client `SteerPredict.sideState`, so the arrows never disagree with the server. `"edge"` (the rail, the outside) never greys.
  - The arrow mapping and the wobble and "Gap!" detection live in `SteerHud`; the chip limits live in `SteerChips`. Both are pure and tested in `steer_hud_tests.luau`.
  - Good-news chips always show; only "No room yet" gives way to `chipMinGap`.

### N5. Brushes on (model-engineer + roblox-engineer)

- `GameConfig.steering.brush = "repeat"` with the costs above; regenerate `steering_report.json` only. Smart Steer never brushes, so the baseline is unchanged; the regeneration test proves it.
- **Server:**
  - `Trip.step` events → a new `SteerBrush(mover, other, dir, courseId)` remote to clients following that course (riders and spectators in range; D-055).
  - `RaceSession` gets the brush charges at the lock: `Trip.raceTau` passes `brush_charge` into `tau`.
  - The `[Trip]` log line adds brushes and charges per rider.
- **Client visuals (`RaceView`, via SteerPose):**
  - the mover's lean (≤ `brushLeanFeet` sideways, out and back over `brushLeanSeconds`, drawn only, never in the shown lanes used for ranking) and a `brushNodDeg` nod;
  - the other horse's nod only;
  - no particles, no impact flash, no text over horses.
  - The mover's 4 ft steady already comes in Trip's offsets.
- **Sound:** `Sound.play("count_tick", GameConfig.steerView.brushVolume)`, positional at the mover's horse for riders and spectators in range. No new sound entry. It stays silent until the effects are generated and uploaded (STATUS backlog 2), like `lock_tick`.
- **Chips:** the mover sees "No room yet" if not shown in the last 10 s. The other rider sees nothing.
- **Replays:** record brush events. The replay plays the lean and nod and no text.
- **Results:** no brush line. The trip stars already include the charge. Keep it quiet: a charge is at most 0.3 points.
- **Tests:**
  - parity: `trip_d057.json` brush cases through `Trip.raceTau`;
  - a `RaceSession` τ with charges;
  - the remote's argument order (course last);
  - a bot never in `events` as a mover;
  - nothing after the lock.
- **As built (2026-10-06; DECISIONS D-057 N5 note, REVIEW_QUEUE "N5" rows):**
  - `SteerBrush(mover, other, dir, serverTime, courseId)`: the brush's server time (the state after its tick, like the samples), so the screen draws it when the race on screen gets there (Playback's clock); fired before that tick's `SteerLane`.
  - The pose is `SteerPose.brush` (a sine out and back over `brushLeanSeconds`: the mover's lean ≤ `brushLeanFeet`, both horses' nod ≤ `brushNodDeg`), drawn only. The replay records the brush when it was drawn.
  - A brush clearing a waiting press never wobbles its arrow (`SteerHud.message`'s `brushAt`).
  - The overlap report gates the brush rows: casual riders charged in ≤ 5% of races, no horse charged for a brush it didn't make.
- **As built, N5 review (2026-10-06; DECISIONS D-057 N5 review note, REVIEW_QUEUE "N5 review" rows):**
  - A press again is the same try: a brush needs the third press that way while the first waits (`brushPresses = 3`, N1's rule was the second), still within `brushRepeatSeconds`. Kids who press once and then again (0.1–1.2 s later) are charged in ≤ 1% of races; a masher still in about 60%.
  - The pose is a sine squared (starts and ends at rest). A brush that reaches a screen over 1/30 s late starts from the beginning then (`brushLateSeconds`); one already past `brushLeanSeconds` isn't drawn, ticked or recorded.
  - The mover's chip shows as the brush is drawn. A rider's first brush ever brings a one-time tip, "Bump! Press once, then wait for a gap" (`data.flags.bumpTip`). The look cue stays off while your horse steadies.
  - The `[Trip]` log counts each rider's brushes per other horse (the griefing fail line below).
  - `bump_soft` is in the audio plan (P1, not made); brushes play `count_tick` until it is uploaded.

### N6. Docs, playtest checklist, and the optional head split

- **Docs:** `docs/GAME_DESIGN.md` race section; `game/PLAYTEST.md` steering checklist (D below); `docs/V2_PROPOSAL.md` step 5 gains the brush term; the GrownUps copy.
- **Optional art follow-up** (separate PR, after a Studio look at N3):
  - `tools/meshy/split_legs.py` cuts a **Head** piece from the neck up; the neck line is already found for the saddle cloth (`NECK_RISE`). No Meshy credits are needed: it re-splits the existing meshes.
  - Re-upload `horse_anim_<coat>` (LlamaWorks; standing OK for Roblox asset uploads).
  - `HorseLegs` poses the head about the neck joint: SteerPose's look and yaw lead by up to `headTurnDeg` (12) and the nod moves the head.
  - The body look cue falls to 0.

---

## D. Risks and playtests

### Risks

| Risk | Mitigation | Pass / fail line |
| --- | --- | --- |
| 1.0 s feels sluggish next to the slider | Instant look cue; chaining; the 0.8 s switch (`laneSpeedMax = 1.667`, `laneAccel = 5.56`) | **Fail** if more than 20% of glides get a second same-direction press before they land (Studio logs, phones), or kids prefer 0.8 s in the blind test (playtest 2). Then switch to 0.8 s |
| Weave gap reads as "my button broke" | Wait ring on the arrow; inward presses are kept until room | **Fail** if more than 30% of kids press again while the ring fills (Young player's line), or any kid says the arrows "stopped working" |
| The body turn looks like a skid, or swings the rider's camera | True drift only (≤ 9°), 0.15 s smoothing, the camera on the track heading | **Fail** if testers say "sliding" or "drifting", or the rider's camera visibly swings more than 3° on a lane change (Studio). Then `yawGain = 0.7` or a track-aligned camera subject |
| Grey arrows confuse | ◀ In greys only when trapped; a horse icon, no words | **Pass** if ≥ 60% of 8–10-year-olds asked after 3 races what a grey arrow means say "can't go that way" or "a horse is there" |
| Chip spam | "No room yet" only after 1 s of nothing, ≤ once per 10 s; one chip per 2 s | **Fail** if logs show more than 2 "No room yet" per race on average for riders with buttons (prototype casual rider: 0.4–2.7 one-second waits a race before the 10 s limit) |
| Brushes upset the bumped kid | Mover only pays; the other horse only nods; no name, no chip | **Fail** if more than 1 in 10 bumped kids get upset (observed or asked), even at zero cost. Then `brushCost = 0`, and `brush = "off"` if it persists (Child safety) |
| Brush cost feels unfair to the mover | First brush free; trigger needs a second press within 2 s; cap 0.006 | **Fail** if logs show riders with buttons charged in more than 5% of races (prototype: 0.4% casual, 64% for mashers), or kids call it unfair |
| Griefing (strangers trapping or bumping a kid) | Tuck-back kept; mover pays; positions come from taps, not steering | **Fail** if the sims' targeted-minus-untargeted own trip is below −0.001, or logs show one rider brushing the same opponent 3+ times in more than 1% of races |
| Overlaps or backward jerks return | Glide reserve; holds settle ≤ 19 ft/s; the N2 overlap gate in CI | **Fail** on any overlap or a fall-back faster than 20 ft/s in `overlap_report` (all rows, 960 races) |
| Python/Luau drift (sqrt, new ties) | Exact-decimal fixtures; fixed order; the sqrt-free fallback | **Fail** on any `trip_d057.json` mismatch beyond 1e-9 |
| Targets move with the slower glide | Regenerated baseline; per-intent reach | **Fail** if any acceptance target misses in any course × distance (prototype: all pass; per-intent reach 74–100%) |
| Smart Steer kids out-steered by bots after the change | The baseline is built for Smart Steer kids (D-054 S0) | **Fail** if a Smart Steer kid among bots averages outside 0 ± 0.003 in any cell |
| The look cue fires on a press the server refuses | It is only 3°, relaxes in 0.3 s, and never moves the horse sideways | **Fail** if any tester notices a "fake start" in 50 presses into blocked lanes |

### Playtests (phones first, ages 8–11; then keyboard and gamepad)

1. **Natural look:** chase view and a 3x replay of three races with mashing riders. **Pass:** no tester says "zig-zag", "wiggle", "slide" or "snap"; at least 2 of 3 say it looks "like real horses". Watch the last 2 s too: **fail** if a tester points out a horse swerving a whole lane just before the line.
2. **Blind 0.8 vs 1.0 s:** the same kid rides two races at each setting, in random order. **Pass for 1.0 s:** kids can't tell them apart better than chance, or don't prefer 0.8 s. Otherwise switch.
3. **Boxed in:** after 3 races with buttons, ask "What does the grey arrow mean?" and "What happened when you were stuck?" **Pass:** ≥ 60% answer "can't go that way" or "waited or eased back for a gap"; nobody says they were "punished".
4. **Brushes:** stage two kids side by side and have one press twice into the other. **Pass:** the bumper can say "I bumped, I slowed down"; the bumped kid isn't upset (see Risks).
5. **Load:** slider scores in races with D-057 against D-054 (config A/B, same kids). **Fail** if the slider S drops more than 2 points on average.
6. **Latency:** a phone on a throttled link (0.25 s each way). **Pass:** the look cue shows on the press frame, and there is no sideways snap-back in 50 presses.
7. **Logs** (one week): reversals refused by the gaps per race, waits dropped, "No room yet" per race, brushes and charges per race by policy, τ by post, Smart Steer kid mean, and how often τ binds the clamp.

**Studio checklist additions** (`game/PLAYTEST.md`):
- Lane changes ease in and out, the horse turns slightly into the move, and the rider's camera doesn't swing.
- Mashing ◀ ▶ gives at most one quick change of mind, then the horse holds its line (the ring fills).
- After "Lanes locked!", horses passing on screen move over early, in one smooth move, and never swerve a whole lane in the last 2 s; a horse that moved over doesn't swing back within 3.5 s.
- Out ▶ greys beside a horse; ◀ In greys only when it can't tuck back; a press there waits, then drops quietly.
- A third press into a horse alongside brushes it (N5 review: a press again is the same try): lean, nod, a soft tick, the mover drops back a little; the other horse only nods.
- Bots never brush; no brush starts after the lock (one from the last moment before it can be drawn just after "Lanes locked!").
- Replays show the turns, leans and brushes.
