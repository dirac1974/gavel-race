# Phase 1 consult: gameplay (2026-10-11)

Reviewed the built Phase 1 working-tree diff against my review (`gameplay.md`) and the consensus.

## Did it land?

| Item | Verdict |
| --- | --- |
| Sound: sheet stand-ins, a tick on every tap, hoofbeats | **Landed.** The sheet is uploaded (`SoundSheet.luau:7`). Two tuning issues below. |
| Visible taps: nudge 5 ft, Perfect surge, label pop, dust | **Landed**, once B1 is fixed. The FOV caps match my vote. |
| Burst arming | **Half landed.** It's correct and has parity on the server, client and Python. But a silent ignored tap only delays the reflex by one tap (MF-2). |
| Bob from leg phase | **Landed.** |
| Slider clear of the pad, "RIDING" | **Landed.** |
| Live pace previews | **Deferred.** This was my #1 problem, and it's still open: taps still don't change the race before a checkpoint. |

## MUST-FIX before moving on

1. **B1: dust and trail attachments.** `RaceView.client.luau:409-410`. Already being fixed; add the PLAYTEST line.
2. **Taps before the burst arms need feedback.** `RaceController.client.luau:635` returns silently. A kid tapping in rhythm, every ~1.2 s, gets their *next* reflex tap counted at a random phase, so arming does nothing for them.
   - Fix: on a pre-arm tap, set `hint.Text = "Wait for the rainbow!"` and give the grey bar a small shake (none under Reduced Motion).
   - Put it behind `hud.burstEarlyHint`.
   - That breaks the rhythm, which is the whole point of arming.
3. **Grey the second target too.** `RaceController.client.luau:1313` only dims `burst.zone`. On Champion, `zone2` looks live while the burst is unarmed.
4. **The tick must be audible over the hoofbeats.** `Sound.luau:35-38`: `tap_ok` is 0.25 and `gallop_loop` is 0.45.
   - The tick is the confirmation for the core verb.
   - Either raise `tap_ok` to about 0.45, or duck `gallop_loop` to about 0.3 while a pace pass is live.
   - Confirm it by ear in Studio on a phone speaker.
5. **Log the design change.** The tick replaces the Great/Perfect chime (`RaceController.client.luau:669`). Add it to D-066 and REVIEW_QUEUE (CLAUDE.md rule 4).

## SHOULD-FIX later

- **Partial live previews, cheap (S).** After the trip lock, `Trip.frame` draws from `displayOffsets(shownLive)` and τ is already fixed (`Trip.luau:1380-1388`). Calling the stretch preview every second from `trip.locked` through checkpoint 2 therefore touches no calibration. Steering-off races can preview the whole race.
- **Previews before the lock (M).** This needs a draw-only preview layer in `Trip.frame` with a hold-gap guard (reuse `RaceFx.nudgeRoom`).
- **Hoofbeat cadence.** The `gallop_loop` stride is 0.5 s (`synth_sheet.py:223`), which is 2 Hz. The legs run at about 3.1 Hz, so the sound and the legs disagree. Regenerate the loop at stride 18/56 s, for example 6 strides in 1.93 s.
- **Tick pitch.** A continuous 0.9–1.3 speed is hard to hear apart. Step it by label instead (Okay, Good, Great and Perfect a few semitones apart).
- **Surge only on Perfect.** In Rookie, Perfect is about ±30 ms, so an average kid rarely sees the surge. Add a surge on 3 Greats in a row, still under the 0.8 s kick limit.
- **Burst bar position.** The bar is still at y 0.44, over the horse. Only the words moved. Move it to about 0.62 (my P6).
- **Code-review leftovers.** N5 (gait-change bob jump), N6 (nudge snap) and N9 (replay bob) are small but visible.
- **Playtest metric to add.** Burst taps in the first 1.5 s after arming. If they cluster, arming isn't enough.

## Sign-off

**Yes, conditional on MUST-FIX 1–4, with 5 in the docs.**

Phase 1 is honest juice: draw-only, capped, Reduced Motion-safe, and it doesn't affect race scoring. But it doesn't yet deliver "my taps made me faster". That gate depends on the live previews. I'd schedule the post-lock preview (S) into Phase 2 rather than leave all of item 6 deferred.
