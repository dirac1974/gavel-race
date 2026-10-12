# Quick fixes code review: forward hop, air pose, saddle keys (2026-10-12)

Reviewer: code-reviewer. Scope: the quick fixes only (HorseJump, `riding.hop`, Rides JumpPower, `TC.RIDE_HOP`, RideClient and TrainingRideClient hop and pose loop, HorseLegs air pose, RaceController saddle keys, `RaceInput.saddleKey`, horse_jump and world tests, PLAYTEST). `src/trip.py`, `sims/` and the Trip parity work were not reviewed.

Runs: `lune run tests/luau/run_all.luau` gives 89777/89777 checks passed. `pytest tests/test_compile_all.py` gives 2 passed. `scripts/policy_guard.sh` exits 0 (it uses `git grep`, so it doesn't see the two untracked files). No model names and no wagering words in the diff or the new files.

## BLOCKING

**B1. A hop in the Gate Break stall goes forward and counts as an early go.** Files: `game/src/client/RideClient.client.luau:130`, `game/src/client/TrainingRideClient.client.luau:144`, `game/src/shared/HorseJump.luau:149`.
- The hop's cap is `hh.WalkSpeed`. In the stall after "Ready", `gateFrame` sets `TrainingState.speed = if s.released then nil else 0` (`TrainingRideClient.client.luau:741`).
- Once the kid has let go of the stick (the normal armed state), the speed is `nil`, so WalkSpeed is the course gallop (46). The horse stands still only because the stick is idle.
- So `launchSpeed(0, nil, 46)` returns `forwardMin` 14, and the horse travels about 5.4 studs. That is more than `accel.goStuds` 2 (`TrainingRide.luau` `gone()`), so a hop before the bell is an early go: a rerun, then `breakFloor`.
- This contradicts the spec, the GameConfig comment, the PLAYTEST line and the RideClient comment ("a hop is never an early go"). It quietly punishes a kid for pressing Space while they wait.
- The Lune test only checks `ls(0, nil, 0) == 0`. It never covers the real stall state, so it passes by construction.
- **Fix:** let the course say what a hop's cap is, instead of using WalkSpeed:
  - add a `TrainingState.hopCap` that `gateFrame` sets to 0 in `ready`, `bell` and the stop inside `hold`, and to `nil` elsewhere;
  - pass `math.min(hh.WalkSpeed, TrainingState.hopCap or math.huge)` from both hop sites.
- Add a test that a hop in the armed stall with a released stick moves less than `goStuds`. A pure helper such as `TC.hopCap(gate, released)` would make this testable.

## SHOULD

**S1. The new required modules are untracked.** `game/src/shared/HorseJump.luau` and `tests/luau/horse_jump_tests.luau` show as `??`.
- RideClient, TrainingRideClient and the test runner all `require` them. If a commit misses them, `WaitForChild("HorseJump")` yields forever with no error, and CI's syntax check (`git ls-files`) never sees the file.
- `git add` both files with this change.

**S2. The D-number doesn't match the consensus.** `consensus.md` numbers the forward jump **D-074** (D-072 is racing-plan, D-073 is Hurdles). The code and docs say D-072: `GameConfig.luau:431` and `:679`, `HorseJump.luau:2`, `HorseLegs.luau` (AIR_POSE, apply), `RideClient`, `TrainingRideClient`, `PLAYTEST.md:696`, and `run_all.luau` with the test header.
- The saddle-key fix arguably does belong under D-072 (steering).
- Relabel the jump as D-074. The steeplechase-plan header ("D-072 provisional") also disagrees with the consensus; note which number wins.

**S3. Nothing is logged yet.** `DECISIONS.md` and `REVIEW_QUEUE.md` have no D-072 or D-074 entries.
- Add the provisional choices that differ from the plan:
  - a 0.12-stud landing dip in place of the 0.96 squash;
  - no landing thud or dust puff;
  - the `holdSeconds` and `airDelaySeconds` values;
  - the Smart Steer chip copy;
  - D-pad pass-through only while a menu has the gamepad selection.
- Per the usual flow this can land with the scribe, but it is required before commit.

**S4. The landing feedback is not what the spec says** (`steeplechase-plan.md` §1, Pose). The spec has a squash to 0.96 for 80 ms plus a soft thud and a dust puff. The build has a 0.12-stud dip and no sound or dust (`GameConfig.luau` `hop.landDip` and `landSeconds`, `RideClient.client.luau` pose loop). Either add the thud and dust under Reduced Motion rules, or log the cut (S3).

**S5. In free riding, the Humanoid fights the push.** `HorseJump.luau:116` and `RideClient.client.luau` (`hh:Move(flight, false)`).
- In free riding the launch speed is the current speed + 4, which is above WalkSpeed: 20 against WALK 16, and 50 against GALLOP 46.
- In Freefall the Humanoid's air control pulls toward `Move × WalkSpeed` on every physics substep, and `Stepped` resets the velocity only once a frame. The horse's speed saw-tooths at 240 Hz against 60 Hz.
- Courses aren't affected (there the cap is WalkSpeed).
- **Fix:** while a flight is live, set `WalkSpeed` to the flight speed and restore it on landing, or cap the free-ride launch at WalkSpeed + 0. Check it in Studio either way.

**S6. Other players' airborne pose depends on replicated Humanoid state.** `RideClient.client.luau:254`.
- `hh:GetState()` on a humanoid this client doesn't own may lag, or may not report Freefall reliably. Jumping lasts only one transient frame.
- Add a fallback, `|v.Y| > some threshold`, using the `v` already read in the loop. With the 0.06 s air delay this won't flicker on bumps.
- The PLAYTEST line for a second account covers it, but the fallback is cheap.

**S7. The Smart Steer chip can say something untrue.** `RaceController.client.luau:908`. The `steer` state defaults to `shown = false, smart = true` (`:1421`).
- With `GameConfig.steering.enabled = false`, no SteerControls arrives and nobody steers, yet an arrow still shows "Smart Steer is steering for you".
- Hurdles (no lane changes) will hit the same case.
- **Fix:** pass `s.smart and trip-active` into `saddleKey`, for example by setting a flag when SteerControls arrives, and return "sink" otherwise.

## NIT

- **N1.** `RideClient.client.luau:272` calls `reducedMotion()` (a pcall) once per rig per frame. Read it once per frame, or cache it on `GetPropertyChangedSignal` the way RaceController does at `:114-117`.
- **N2.** `horse_jump_tests.luau` covers 5.0 to 1.1 studs before a log. The spec asks for 100% from 4 to 1. The comment explains the 2% miss at exactly 1.0 (10 Hz sampling); add that note to the plan or to D-074 so the gate is honest.
- **N3.** The spec names the pose `HorseLegs.airPose`, but the code has `HorseLegs.AIR_POSE`. It's harmless; align one of them.
- **N4.** `RaceController.client.luau:899` passes the D-pad only while `GuiService.SelectedObject ~= nil`, and nothing in the client sets a selection on the results card. A gamepad player has to enter UI navigation themselves before "Done" is reachable. That isn't new, but the PLAYTEST line at `:702` implies it just works. Consider `GuiService.SelectedObject = Card.doneBtn` when the card opens for a gamepad player.
- **N5.** A hop at a turn on a course flies straight for up to 0.39 s, because the magnet and Easy Rein are overridden. It's fine at these speeds; check in the playtest that it never carries a kid through a rail.

## Checked and fine

- **The `Stepped` connection.** It is module-level, connected only while a flight is live, and disconnected when `flights` empties. `flights`, `lastHop` and `air` are swept of dead instances.
- **The hop never beats a course.** On courses the cap is the course pace (WalkSpeed), and the 51 cap is below the server's 53 `maxSpeed`. `maxStep` includes the vertical, and the test samples a full arc at 51 through `TR.screen`.
- **Mud Splash still clears.** Peak 3.68 is above `logHeight` 2, and the horse is above 1.5 studs for 0.30 s (8.3 studs at the lope) against the 6-stud window. `TC.RIDE_HOP` is derived from config, and world_tests is updated.
- **No hop during the 3-2-1.** Both hop sites check the phase.
- **Keys are sunk for the whole saddle span.** They are bound from `setJumping(false)` at race start (`:1498`) and released at every `setJumping(true)`: Done, the timeout, a stopped race, seat loss and respawn. They are sunk at High+1 above the camera. A/D stay off (move controls are disabled). CAS doesn't fire while a TextBox (chat) is focused.
- **Kid safety.** No urgency, no purchase, no fail state. The chip copy is kind and 5 words.

CHANGES REQUESTED
