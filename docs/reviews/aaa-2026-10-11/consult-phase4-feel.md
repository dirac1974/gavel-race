# Phase 4 consult: feel and presentation lead (2026-10-11)

I reviewed commit 67f503f against `phase4-plan.md`. I read the code and looked at the four strips. Nothing has been run in Studio.

## Did it land?

Yes. The departures from my plan are all improvements:
- `pelvisDeg 15` to get the back under 45°.
- The pump stops under Reduced Motion.
- Rail bunting sits behind the replay's side camera.
- "the glow" replaces "the green", since the glow is now gold.

The art is on-style: chunky ink outlines, the fair palette, varied skin tones and kind faces. Nothing in it reads as a casino.

The rest holds up too:
- **Jockey pose:** a pure solver, written in PreSimulation over the sit track, symmetric arms so a whip pose is impossible, and an R6 fallback.
- **Big Board:** shows only places and names.
- **HUD restyle:** paper, ink, Fredoka, slate and gold.
- **Ribbon colours:** the hex values now match the art direction in both files.
- **Win audio:** the crowd cheer on a win closes my Phase 2 audio gap.

## MUST-FIX

1. **The gate camera's blend flies through the horses and whip-pans.**
   - `GateIntro.luau:117-121`: the blend lerps from 16 studs *in front* of lane 1's face to 14 studs *behind* your horse in 0.4 s.
   - The eye passes about 9 studs up, through riders and the 8-stud stalls, while the look target swings about 180°. That's about 450°/s, enough to make a kid queasy, and it happens one second before GO.
   - Fix: make it a cut. At the end of the dolly, run a 0.12 s Paper `FFF7E6` fade (0 → 0.4 → 0) and set the chase shot directly. Add the key `gateIntro.handOff = "cut"` and keep `"blend"` as a switch-back.
2. **The crowd tiles into an obvious grid.**
   - `TrackDressing.luau:266-271`: every tier's Texture starts at the same U, so the same four fans stack in identical columns up all 7 tiers and repeat every 16 studs along 900 studs. From the chase camera it reads as wallpaper.
   - Fix: set `t.OffsetStudsU = (k * 5.3) % D.crowdTileU`, using the tier index `k`. Optionally mirror alternate tiers with a negative `StudsPerTileU` (check in Studio). It's one line, it's free, and the fans then read as a crowd.

## SHOULD-FIX

- **Ease the dolly** (`GateIntro.luau:113`) with smoothstep, `f*f*(3-2f)`. At 1.6 s over about 70 studs a linear pan starts and stops abruptly.
- **End the dolly on *your* horse,** not lane 1: hold 0.3 s on its face with its name. That's the hero beat before the cut.
- **The pennant's horseshoe lies on its side** (`flag_pennant.png`) and reads as a "C". Turn it opening upward.
- **`confetti_square.png` is a light-grey triangle,** and tinting multiplies the grey, which dulls the confetti. Make it pure white.
- **Studio tuning for the pose:** the joint signs (`JockeyPose.SIGN`) and the knee bend can only be checked in Studio. Add a PLAYTEST line: "feet near the horse's flanks, not inside it; the back about 40°".
- **Music:** still silent until David picks a library id. Add the pick to `OPEN_QUESTIONS`.

## Sign-off

**Yes, conditional on the two must-fixes.** Both are under 10 lines and I can verify them from the diff. This also closes everything from my original review except the music source.

## Meshy verdict: spend nothing now

Hold all 45 credits. The code-built dressing and the 2D crowd cover every look in Phase 4. Spend credits only if the Studio playtest shows the textured crowd looks flat from the chase and side cameras, which needs an actual look, not a guess. In that case: `crowd_bench_block` text-to-3D (30) plus one retexture in a second palette (10), keeping 5 in reserve.
