# Plan votes: feel and presentation (2026-10-11)

## greencash-plan.md: AGREE-WITH-CHANGES

The sink, the tiers set by the best league reached, one currency per shop and the 24 h return are all right. As written, though, buying something has no moment.

Required changes:
1. **A build moment.**
   - The item is bought at Feed & Seed but lives in the yard, so the payoff is invisible.
   - After a purchase, show "Go see it!" with a GO button and hoofprints to your barn.
   - When you arrive, the item drops in: scale 0 → 1.15 → 1 with Back easing, a dust puff, a sparkle burst, `job_done`, and a toast "Red Barn Door built!".
   - Paints sweep across the barn over 0.6 s instead of switching.
   - Reduced Motion: a plain fade.
   - Key: `greenCash.buildFx`.
2. **Visitors notice.**
   - For 48 h, a new build shows ✨ beside your name on Friends' barns and sparkles once when a friend arrives.
   - No counts, and no comparison between barns.
3. **Don't sell what every yard already has.** `StableService.server.luau:510-591` already places, free in every yard:
   - a hay bale, a water trough, a feed bucket and a wheelbarrow;
   - the horseshoe over the door (`:552`);
   - the photo board.

   Selling these makes a kid pay for what they own. Replace them with variants: a painted trough, a flower-box wheelbarrow, a gold horseshoe.
4. **The small hay barn must not reuse `training_shed`.** That model is a Fair Street landmark, and a copy in the yard will read as "training here". Use a new tint with a hay-loft sign, or drop the item.
5. **Gold-heavy items need fair colours.** Use painted wood trim, rope and bunting colours, never chrome or anything that glints like a jackpot.

### Meshy call: don't spend credits on the weathervane

A weathervane is thin arrows on a cross. Meshy fails at thin parts, as the asset plan records for the gate and the saddle. Build it in code: a pole, a wedge arrow, an N/E/S/W cross, and a horse silhouette as double-sided decals from `make_ui_svgs.py`, turning slowly on the client. That costs 0 credits.

Keep the 37 credits for the textured-crowd fallback (30 + retexture). The crowd is seen in every race; a Champion roof item is seen by few kids. If credits are still free after the playtest, a chunky horse topiary for Champion is a shape Meshy handles well.

## tapgap-plan.md: AGREE-WITH-CHANGES

This is the right architecture. It is server-side and identical on every screen, all its decisions are byte-identical, it is limited in speed and acceleration, it clears the target lane before a horse glides in, and the n/(n+k) shrink stops one-pass jerks. Motion should read as earned.

Required changes:
1. **Test for pull-back at a checkpoint close.** If `pv` overestimated, `d` slides back as the checkpoint closes. That is rubber-banding, and the current tests only check the limits. Add: a steady rider's drawn offset never drops more than 2 ft across any close or the lock.
2. **Put the chip on the horse.** Show "Giddy-up! +1 length" in a BillboardGui just above your saddle, under the YOU marker at 7 studs, not above the slider. The gain then sits on the thing that gained.
   - Keep it silent: the tick, the word, the nudge and the place pop already make sound.
   - Never show it during the Final Burst.
3. **Order of build.** The 5 ft own-screen nudge stacks on the 12 ft cap. Run the overlap test with the nudge on, and keep `RaceFx.nudgeRoom` applied after the layer.
