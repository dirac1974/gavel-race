# Phase 4 consult and overall sign-off: gameplay (2026-10-11)

Reviewed commit 67f503f: `GateIntro.luau`, `MusicBed.luau`, the `gateIntro` and `audio` config, and the PLAYTEST Phase 4 sections. I also checked that the earlier consult items landed.

## The two concerns

**Does the gate pass hurt tap readiness? No.**
- Dolly 1.6 s plus blend 0.4 s from the seat at GO−3 gives the chase view back at GO−1.0 (`GameConfig.luau:704`).
- The slider is already showing, still, with the first glow lit. Taps before GO never count, and the first crossing comes 0.3–1 s after GO.
- Worst case is a missed first pass, about 1 point of a 60-pass score. PLAYTEST line 643 checks it.

**Does the music risk beat-vs-marker? Not as shipped.**
- `id = 0`, so there's no music.
- The race level is 0.12, under the tick, and the bed is specified as beatless.
- The risk only returns if David picks a track with a pulse.

## MUST-FIX

None blocking.

## SHOULD-FIX

1. **Music.** Add "If the track has a steady beat, set `race = 0`" to the `audio.music` comment (`GameConfig.luau:714`) and PLAYTEST line 647.
2. **Burst bar.** It still sits over the horse at y 0.44 (`RaceController.client.luau:310`). Move it to about 0.62.
3. **Live previews before the lock.** These are logged as open (STATUS line 19). They're the last piece of "my taps made me faster".
4. **Steering-off races could preview the whole race.** The loop requires `trip` (`RaceService.server.luau:1018`).
5. **After the playtest:**
   - pace rest spans and steering's worth;
   - per-league bot scores at the faster sweeps;
   - Champion bots rated `max(anchor, rating − 9)`.

## Scorecard: my original top 5

| # | Must-do | Status |
| --- | --- | --- |
| 1 | Audible taps | **Done.** Sheet stand-ins; a stepped tick on every tap; hoofbeats ducked and in cadence with the legs. |
| 2 | Taps move the horse | **Partly done.** Nudge, Perfect surge, Great-streak surge, word at the marker, "RIDING" and the post-lock preview are in. Pre-lock preview is open. |
| 3 | Arm the Final Burst | **Done.** Parity on server, client and Python; grey bar; "Wait for the rainbow!"; second target greyed. |
| 4 | Skill's own win | **Mostly done.** "Best ride" for the top 3. κ was simulated and deferred with data, which I accept. |
| 5 | Teach the rule, eyes on the track | **Mostly done.** Coaching, the warm-up and the slider clear of the pad are in. The burst bar position is open. |

Also done: no chance-arrow flicker on previews, fair Open Practice (equal horses, Rookie settings), reversible Legends, and the finish moment with "Race again".

## Sign-off

**Yes: Phases 1–4 are ready for David's Studio playtest.**

Every tap now gets sound, motion and a word. All of it is draw-only, luck never shows early, and none of it touches Diamonds or wagering.

The open question is still the Phase 1 gate: can a kid say how their taps changed the result? If not, build the pre-lock preview next.
