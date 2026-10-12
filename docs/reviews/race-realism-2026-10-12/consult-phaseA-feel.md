# Consult: D-072 phase A and the D-074 jump, game feel (2026-10-12)

I checked the build against `votes-feel.md` (R1–R3, S1) by reading the code only. Nothing has been run in Studio.

## Verdict

**MUST-FIX: 2 items, both config plus a few lines.** I sign off on everything else.

## MUST-FIX

1. **A shut door doesn't read as "turns toward the rider".**
   - The current values are `steerView.shutYawDeg = 3`, with no jockey cue (`SteerPose.shut`).
   - A 3° yaw moves an 8-stud horse's nose about 0.2 studs, which is invisible from the chase camera. Steering already turns horses up to 10°, so 3° gets lost in that.
   - Set these values:
     - `shutYawDeg = 6`.
     - Add `shutLeanFeet = 0.6`: a drawn-only lean toward the mover through the brush lean path (`leanFeet`), eased by the same `shutEaseSeconds`. It is smaller than the brush's 1 ft, so the overlap gate holds.
     - Add the jockey cue my vote asked for (R3): `jockeyPose` pump × 1.5 on the shutting bot while the door holds (`shutPumpScale = 1.5`).
   - Gate: add an overlap-report row with doors on, which must show 0 overlaps.
2. **The jump's nose pitch is too timid.**
   - `riding.hop.pitchUpDeg = 6` and `pitchDownDeg = 4`.
   - The vy-proportional curve is correct. It's exactly the bascule S1 asked for. But 6°/4° over 0.39 s of airtime, with the ease at `pitchRate` 20, peaks at about 5°, which reads as a hop.
   - Set `pitchUpDeg = 9`, `pitchDownDeg = 7`, and keep `pitchRate` at 20.

## Signed off

- **Drift 3.5/2 ft with a cap of 1.5 ft/s per horse (3 ft/s between two).** That meets R1. It gives about ±4 ft of half-length swaps over 10–15 s, a living pack without the pulse.
- **Pass closing cap of 6 ft/s with `alongFeet` 8.** It crosses the 16 ft band in about 2.7 s, so a pass always shows the two horses side by side, comfortably over R2's 0.8 s. Real passes look like this. Keep it.
- **Landing.** `landSquash` 0.96 with `squashHeight` 4 gives a 0.16-stud dip over 80 ms. It's subtle, but with the thud (`bump_soft` at speed 0.8, volume 0.6) and the 8-puff dust it lands. Keep it.
- **Leg tuck.** Not folding on a flicker (`airDelaySeconds` 0.06) is right: bumps never fold the legs.

## Nice-to-haves

- **The drift cap clips the short wave.** Wave 2 (2 ft over 5–7 s) needs up to about 2.5 ft/s, so the 1.5 ft/s cap turns it into a plateau. Set `driftPeriod2 = { 7, 10 }` so the cap rarely bites and the motion stays sine-smooth.
- **A jump position for the free-ride jockey (S1).** While airborne, add waist +15° on top of the crouch and shoulders +20° (`riding.hop.jockeyAir`). Today JockeyPose only runs on race courses, so this needs a small hook in the RideClient pose loop.
- **A shut-door sound.** Confirm that `bump_soft` at 0.4 volume plays at the shutting bot. Positional audio is fine, but on phones keep `RollOffMaxDistance` ≥ 80 so the rider hears it.
