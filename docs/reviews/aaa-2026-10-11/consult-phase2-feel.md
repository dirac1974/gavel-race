# Phase 2 consult: feel and presentation (2026-10-11)

This review covers the built finish moment, the results card, the coaching and the post-lock preview (D-067). I read the code only. Nothing has been run in Studio.

## Did it land?

Yes, and well. The emotional arc now has an ending:
- The field gallops out about 155 ft past the line, easing to a stop over about 3 s instead of hitting a wall.
- The camera eases from the chase view to the replay's side view.
- 1st gets a gold outline and confetti; 1st to 4th get a ribbon stamp.
- The card is up within 4 s of the leader crossing.
- The copy is genuinely kind. 0 stars reads "Comet loved the run with you!", there is no "so close", and "Best ride" appears for the top 3 only.
- Reduced Motion gets a clean fade.
- The orbit hands the camera back properly when a replay or a dismount takes it.
- Race again names what it will actually join (race, Practice or Cup), which is honest.

## MUST-FIX before moving on

1. **A reflex tap skips the whole moment.**
   - `RaceController.client.luau:2003-2010`: any touch, click or tap key during `phase == "play"` sets `seq.skip`.
   - The stretch drive has the kid tapping in rhythm until 1.5 s before the line, so the next reflex tap lands just after the crossing and the kid never sees the orbit, the confetti or the stamp.
   - This is the burst-arming problem again, and it needs the same fix: add `GameConfig.finish.skipAfterSeconds = 1.0` and ignore skip input until `t - seq.crossAt >= skipAfterSeconds`.
2. **The stamp covers the hero shot on phones.**
   - `FinishMoment.luau:44-47`: the stamp is 150 × 188 px, centred at y 0.36.
   - The orbit frames your horse at screen centre. On a 375 px-high phone the stamp spans about y 0.11–0.61, so it sits right on top of the winning horse during its 2.5 s.
   - Move it to the top-left third (for example `Position = (0.22, 0, 0.30, 0)`) and scale it with `RaceState.hudScale()`, or anchor it in world space over the horse with a BillboardGui at the YOU marker's height.

## SHOULD-FIX later

- **The win's loudest personal sound is `ui_pop`** (`FinishMoment.luau:98`), the generic button click. Give the stamp its own sound: `bump_soft` at pitch 0.8 plus `tap_good`. For 1st, add a second `crowd_cheer` swell at your crossing.
- **The dim is black at 45% opacity** (`finish.dim = 0.55`, `ResultsCard.luau:52`). It drains the sunny world, and the winning horse's gold outline with it. Use Ink at about 0.75, or dim only behind the card.
- **The confetti uses the sparkles texture** (`FinishMoment.luau:126`), so it reads as twinkles, not paper. Add a `confetti_square` PNG to `make_ui_svgs.py` (0 credits).
- **The ribbon placeholder colours drift from the art direction** (`FinishMoment.luau:30`): `3B7BD9`, `E5484D` and `F2C230` against the documented `2F6FDE`, `E0474C` and `FFD23F`.
- **The YOU marker stays on** (AlwaysOnTop, 12 studs up) during the side-view orbit and clutters the shot. Hide it while `finishSeq` is playing.
- **The card's stars appear all at once.** Count them in one at a time at 0.2 s each, with a rising tick (`tap_ok` at speed 1.0, 1.15, 1.3). This was my D2 "counting stars for everyone", and it's the payoff for places 5–8.
- **Still open from earlier:** the jockey crouch (feel P3) and the bunting and crowd dressing (F3).

## Sign-off

**No, not yet.** I'll sign off once the two must-fixes land. Both are S-sized and I can verify them from the diff.
