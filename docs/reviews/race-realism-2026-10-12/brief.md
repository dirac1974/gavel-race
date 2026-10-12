# Race realism: David's playtest feedback and the code map (2026-10-12)

## David's feedback (first Studio playtest of PR #65/#66, quoted)

> When the horse jumps it jumps straight up even if stationary, its not very realistic looking, it seems like a jump should always jump forward a bit. Maybe we should also add a straight away race type, steeple chace race or something. Also during the race hitting left or right just turned the camera and didn't do much, didn't seem like steering at all. The horses stayed in their lane the whole race, not like a realistic race at all. Horses tend to file in close to the rail and pass when they get the chance, typically easier on the straight away. Maybe some of the boost energy should be stored for the "move" to pass the next horse in front of them when they try to pass, navigating with the left and right buttons. They could be blocked in by neighboring horses trying to pass preventing them from passing at that instant sometimes which also happens in real races.

This also answers OPEN_QUESTIONS 8 (the Smart Steer "find room" study): David wants horses to find room and pass.

## Why it felt that way (code facts)

**Jump.** The only jump is the stock `Humanoid.Jump` (JumpPower 42, `Rides.luau:254`), fired from `RideClient.client.luau:123` and `TrainingRideClient.client.luau:138`.
- It has no forward push and no airborne pose. The legs keep cycling at speed, and a standing horse just rises straight up.
- Mud Splash logs need a height of at least 1.5 (`TrainingRide.luau:415`). `TC.RIDE_HOP` 4.5 is tied to JumpPower 42.
- Races have no jumps.

**Arrows turned the camera.** Steer keys are bound and sunk only while steer buttons show (`RaceController:879-893`, `:1543`). Buttons are hidden until `totals.races >= steering.introRaces` (3), and practice doesn't count.
- Until then, the arrows reach the default Roblox camera, which rotates.
- A/D do nothing, because the move controls are disabled.
- The server also ignores the presses (`RaceService:331`).

**Lanes.** Lanes change only from the gate to the far-turn lock: about 24 s of a 69 s Sprint, all of it backstretch. After the lock, lanes are cosmetic (`Trip.cosmetic`).
- Smart Steer moves inward only near turns and stops at home lane 2. Nobody changes lanes on the straights, nobody passes, and nobody moves out to pass.
- `hold` keeps a horse 10 ft behind the horse ahead in its lane, which makes lane-2 columns (boxed share 48.6%, D-071).
- One press moves one lane in 1.0 s. Blocking, tuck and brushes are in D-057.
- Drawn offsets come from skill (`lead·(live−1/n)·ramp`) plus the D-033 luck blend from the far turn. Positions reach clients at 10 Hz through `RaceOffsets`.

**Outcome.**
- At the gate: base chances q, purses and luck `L~Exp(1)` are fixed.
- During the race: segments pace, pace, burst(×2), pace update `live = q·exp(κR + c + τ)`.
- τ (Trip) is clamped to −0.02/+0.04 and is fixed at the lock.
- Finish: the order is sorted by `T = L/p_live`.
- Python reference: `src/gavel_race_v2.py`, `src/burst_meter.py`. They must stay in parity with the Luau files.

**Final Burst.** A one-tap timing meter in the homestretch (D-066). It has no stored energy; Energy is kept out of speed (D-015).

**Race types.** Two oval courses (dirt and turf), 4 distances, leagues and Cups. There are no fences in races. Training Mud Splash has logs.

## Rules that bind any plan
- **No wagering** (hard rule 1).
- **Diamonds:** never change win chance, Rating or the gavel.
- **Kid safety:** no fake urgency, no purchase prompts near races.
- **Mobile first:** two steer buttons plus the tap button. Ages 8–13.
- **Decisions:** every decision is `Accepted (provisional)` with config flags (CLAUDE.md rule 4).
- **Parity:** any change to the race math goes into the Python model and the parity fixtures, with simulations for skill premium, upset rate and fairness by post.
