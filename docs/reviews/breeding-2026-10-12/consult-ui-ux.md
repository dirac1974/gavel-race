# Breeding consult: UI/UX (D-080, 2026-10-12)

**SIGN-OFF.** No must-fixes.

## Checked against votes-ui-ux.md and consensus.md

- **Two steps.** "Pick two parents", then "Your foal". Each is 640 × 400 through `Ui.fitPanel` (16 px / 64 px), so about 350 px rendered, which fits a 375 px phone.
  - Parent slots are 200 × 120, list rows 64 px with the stage emoji and a short reason.
- **Coat chances box.** 3 rows of swatch, label, a 120 × 12 bar and "%". Surprise uses ❔, and the word is always "chance". The two-tap confirm reads "💞 Have a foal" → "Sure? 💵 800".
- **No clocks.** "Arrives in N races or tomorrow" and "Next foal in N races".
- **Naming** is the Starter's step 2: "🔀 New words", "That's the name!", 64 px chips.
- **Map.** The 14th tile, "💞 Foal Barn", fits the 5 × 3 grid at the same height, so it fits a phone with no scroll. It's hidden when breeding is off.
- **Horse Book.** The 💞 Family tab's empty state reads "Two horses can start a family".
- **Legend card and the Grown-ups paragraph.** Kind and factual. They say "chance", never odds, and state that no Robux or Diamonds are involved and there are no re-rolls.
- **Symbols.** 💞 means breeding, ❔ means surprise, 🍼 stays Young (the "🍼 Comet's foal!" banner is a Young horse, consistent with consensus). No clashes.

## SHOULD-FIX (later)

1. **The atlas icon `family`** isn't drawn yet. The 💞 emoji stands in. Add it to `make_ui_svgs.py` (0 Meshy).
2. **The Surprise row** names its coats but doesn't show their swatches. Add 20 px swatches before the words, as the vote asked.
3. **"🏫 Lend or Sell" (stable full)** sits at the top right of the foal step. Check in the emulator that it doesn't cover the family-line row. If it does, move it to the bottom row in place of the confirm.
