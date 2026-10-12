# Phase 1 consult: feel and presentation (2026-10-11)

I reviewed the built Phase 1 (D-066) against my `feel.md` review and the consensus vote, reading the code and `tools/audio/synth_sheet.py`. Nobody has played it or listened to it yet.

## Did it land?

Mostly yes.
- The bob now follows the leg phase (`HorseLegs.bob` and `phaseOf`). This was my P4, and it is done properly.
- A tap now gets a pitched tick, a nudge of about 4.3 ft, a label pop and, on Perfect, a surge. The burst arms with a whoosh at the moment it arms, which is the right cue.
- The RIDING meter is gold on slate, which fixes the red-to-green gradient.
- Everything is draw-only, behind one config switch, and turns off under Reduced Motion.
- The synth recipes are better than stand-ins usually are: band-limited, the gallop is a four-beat stride rendered as a seamless loop, the bells are warm, and nothing is harsh.

The jockey sitting upright (my P3) is still there. It was outside Phase 1, but it remains the biggest problem a kid sees on screen.

## MUST-FIX before moving on

1. **The hoofbeats run slower than the legs.** `synth_sheet.py` `gallop_loop` uses `stride = 0.5`, so you hear 2 strides a second. The legs run 56/18 ≈ 3.1 strides a second (`HorseLegs.GAITS.gallop`). `RaceController.client.luau:79` calls `Sound.loop("gallop_loop")` with no speed, even though `Sound.loop` now takes one (`Sound.luau:160`). The mismatch is roughly 3:2, and this phase exists to make sight and sound agree.
   - Fix now: pass `speed = (raceSpeedStudsPerSecond / GAITS.gallop.stride) / 2` (≈ 1.55). The pitch rises, but percussive thumps survive that.
   - Fix later: re-render the loop at the true cadence in the next sheet rebuild. Don't spend the last audio upload of this 30-day window on it now.
2. **Perfect has no sound of its own.** `RaceController.client.luau:665-670`: with the tick on, `tap_good` never plays on a pace tap. Perfect then differs from Okay only by a slightly higher tick (0.9 → 1.3 speed), while the screen is surging. A visual payoff with no audio payoff feels half-done.
   - Fix: on Perfect, also play `tap_good` at about 0.6 volume. Keep Great tick-only.
   - Log it in D-066; this also closes the code review's N4.
3. **The dust attachments are misplaced (B1).** Already being fixed. I'm adding it here so sign-off depends on it. Add a PLAYTEST line: "dust at the hooves".
4. **The bob jumps when the gait changes (code review N5, `RaceView.client.luau:166`).** It happens out of the gate and at the pull-up, which are the two moments everyone watches most closely. Blend `bob(prev)` and `bob(gait)` by `mix`.

## SHOULD-FIX later

- **Perfect zoom kick:** 1.5° at FOV 80 is about 2%, which is barely visible. Make it a PLAYTEST tuning item with a range of 2–3°. The 6° cap is right.
- **Dust on every horse:** today only your horse kicks up dust (`raceFx.dust`), so the rest of the field looks sterile. Add a puff per stride on every horse on the followed course at half size: 8 × 3 puffs a second, which is cheap.
- **Surge on Great too:** give Great a smaller surge (half the dip, no trails), so the response steps up from Good to Great to Perfect.
- **Hint on taps before the burst arms (code review N2):** a quiet "Wait for the colours…". Without it, a tap on the grey bar reads as broken.
- **Replay bob (code review N9):** scale it by speed so the field doesn't bob at full height while it eases to a stop.
- **Next phases:** the jockey crouch animation (my P3), the finish sequence (D2) and the bunting and crowd dressing (F3).

## Sign-off

**No, not yet.** I'll sign off once must-fix 1–4 land. They are all S-sized, and I need no new review cycle to verify them, only the diff.
