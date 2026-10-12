# Green Cash and tap gap: plan consensus (2026-10-11)

Plans: `greencash-plan.md` (systems), `tapgap-plan.md` (gameplay). Votes: `votes-plans-*.md`. All four designers voted AGREE-WITH-CHANGES on both plans; none voted BLOCK. All required changes below are part of the spec.

## Numbering
Green Cash is D-070 and the tap gap is D-071.

## Tap gap (D-071)
- **Systems:** run a trust check. How often does a horse drawn 1st at the lane lock finish 4th or worse? It must not rise by more than 3 percentage points; otherwise lower `capFeet`. A masher or an average rider gains 2 ft or less, and a masher never gets the message. Stack the 5 ft own-screen nudge in the overlap test, and have `nudgeRoom` read the drawn offsets. Compute only for races with humans, at a human's pass end; `step` allocates nothing; the send step stays under 1 ms per race.
- **Feel:** a pull-back test. A steady rider's drawn position never drops more than 2 ft across a checkpoint close or the lane lock.
- **Message (resolved split):** UI/UX wanted it on the hint line; feel wanted it over the horse. The message is a rider-only, silent BillboardGui just above the saddle, which adds nothing to the crowded phone HUD. The wording is UI/UX's: "Giddy-up! Moving up!", or "Pulling away!" when already 1st. It has no number, shows gains only, and appears at most once every 4 s. It is hidden during the Final Burst, waits behind steering chips and coaching, and never says "leading" or "winning" before the lock. The place badge pops at the same time. Spectators see the movement but no message.

## Green Cash (D-070)
- **Gameplay:**
  - Don't regenerate the parity fixtures; change only `LEAGUE_B`.
  - A perfect rider reaches each tier's first item in no more sessions than a casual rider, and sooner in at least 3 of 5 leagues.
  - No wish chip or "You can build" pill on the results card or while Race again shows.
- **UI/UX:**
  - Barn Builder is visibly its own shop: a 🔨 header, a 💵 band, 💵 on every price, no 💎 anywhere. Tack & Paint never lists cash items, with a test checking both ways.
  - The wish shows as the item's icon and a fill bar with no %, also in the phone More cash cell.
  - The pill ranks below race-first, job prizes and feed; never during the tour; at most 10 words.
  - Only the next tier is shown, greyed, with "Opens when a horse reaches Silver" and no price. Later tiers are hidden.
  - Refunds use the two-tap "↩️ Return" → "Sure? ↩️", with "You can return it until tomorrow" and no countdown.
  - "New shelf at Barn Builder!" shows once, at a calm moment.
  - After a purchase, "See it ▶" leads to the item; the panel uses fitPanel with 64 px buttons.
- **Feel:**
  - A build moment: "Go see it!" with hoofprints to the barn, then the item drops in with a bounce, dust, a sparkle and `job_done`; paints sweep across. Reduced Motion gets a fade (`greenCash.buildFx`).
  - A ✨ next to your name on Friends' barns for 48 h, sparkling once when a friend arrives.
  - Never sell items the yard already has free (StableService:510-591); sell variants instead.
  - No hay barn made from `training_shed`.
  - Gold tier uses fair materials (painted wood, rope, bunting), never chrome.
- **Meshy:** the weathervane is built in code for 0 credits. The 37-credit cap stays reserved for the textured-crowd fallback after the playtest.
