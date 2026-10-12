# UI/UX votes: Green Cash plan and Tap gap plan (2026-10-11)

## greencash-plan.md: AGREE-WITH-CHANGES

The direction is right: one currency per shop, earned prestige only, yard items in fixed spots (no free placement on phones), and the 120 s rule applied to 💵 too. These changes are required.

1. **Make Barn Builder look like a different shop.**
   - It's a mode of the StyleShop panel, so a kid will assume it's the 💎 shop.
   - Give it its own header ("🔨 Barn Builder"), a green 💵 colour band and no 💎 tab.
   - Every price shows 💵 at the same size as the number.
   - Tack & Paint never lists cash items. A Lune test checks both directions.
2. **The wish chip is invisible on phones.**
   - On phones the cash card lives in ☰ More (`Hud.client.luau` phone dock), and "💵 1,240 · 💭 Red Barn Door 70%" won't fit 230 px at 22 px anyway.
   - Show the wish as the item's icon plus a fill bar under the cash number. No text and no %. 8-year-olds read bars, not percentages.
   - On phones, show the same bar in the More panel's cash cell. The pill below carries the "you can afford it" moment.
3. **Pill priority.** The "You can build…" pill ranks below race-first (first 3 races), job prizes and feed. It never shows while the tour owns the screen. It must stay ≤ 10 words (copy test).
4. **Show only the next tier.**
   - Show the next tier's shelf greyed out, with the league badge and "Opens when a horse reaches Silver". Hide every tier after that. Twenty locked items read as a shopping list (D-063's reasoning for cloths).
   - Use no 🔒 price tags. The price shows only once the tier opens.
5. **Returns use the two-tap pattern** already used for Legend and Back to races: "↩️ Return" → "Sure? ↩️", refunding the full 💵.
   - Show "You can return it until tomorrow" with no countdown clock (no timers).
6. **After a promotion, say "New shelf at Barn Builder!" once, later.** Not on the results card or within the 120 s window: hold it as a toast or pill for the next calm moment.
7. **After a purchase, add "See it ▶"**, which walks hoofprints to the item's yard spot, so the kid sees what they built.
8. **Floors:** the Barn Builder grid goes through `Ui.fitPanel` with 64 px buttons, and 💵 text uses `textGood`.

## tapgap-plan.md: AGREE-WITH-CHANGES

Showing tap gains in 1–2 s is the best feel fix left, and the tests are thorough. The UI changes:

1. **Copy.** "+1 length" is racing jargon an 8-year-old won't know. Use "Giddy-up! Moving up!", or "Pulling away!" when you're already 1st, with no number. Keep the 4 s limit and gains only.
2. **No new element above the slider.**
   - At 375 px the hint (y 255–283), the RIDING meter (281–297) and the slider (300–334) are already stacked, so a new chip would overlap them.
   - Show the message in the existing hint line for 1.5 s, and pop the place badge.
3. **One chip at a time.**
   - Queue the message behind `SteerChips` ("Tucked in!", "Gap!") and the coach hint, so they never stack.
   - Hide it during the Final Burst and once the bar arms.
4. **Spectators see the motion but never the chip.**

## Verdict

Agree with both, provided the changes above go in. None blocks a hard rule.
