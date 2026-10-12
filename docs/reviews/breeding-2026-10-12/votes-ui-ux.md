# Breeding plan votes: UI/UX (D-080, 2026-10-12)

## Symbols (checked in `game/src`)

- **🍼 is taken.** It is already the Young stage (`Ageing.EMOJI`, D-078). Breeding must not use it.
- **👪 is taken.** It is the "For grown-ups" tab (`GrownUps.client.luau:182`).
- **✨ is taken.** It means shine and grooming in about a dozen files.
- **Breeding symbol: 💞**, unused in `game/src`. Draw it as the atlas icon `family` (a big and a small horse head, from `make_ui_svgs.py`); 💞 is only the fallback. Use it on the Foaling Barn tile and sign, the foal-on-the-way chip, the Family page and the fee confirm.
- **Surprise symbol: ❔**, also unused.
- 🍼 stays on the foal's Young chip only.

## Votes

| § | Vote | Exact change |
|---|---|---|
| 1 Who can breed | **AGREE** | Greyed reasons are 4 words at most: "Needs 30 races", "Resting: 12 races", "Lent", "Racing now", "Young horse". "Make room first" shows Lend and Sell as buttons. |
| 2 Math | **AGREE** | Only the sprouts (🌱–🌱🌱🌱) show; no numbers. |
| 3 Coat genetics | **CHANGE** | The one-line string is about 14 words and uses 🐴 and ✨. Replace it with a **"Coat chances"** box, detailed below. Never "odds"; the copy test enforces it. |
| 4 Flow | **CHANGE** | Five fixes, detailed below. |
| 5 Economy | **AGREE** | The fee shows with 💵 at number size, in `textGood`. |
| 6 Safety | **AGREE** | Add mare, stallion, mating, pregnant, birth, blood and odds to `Words.BANNED`. |
| 7 Sims | **AGREE** | |
| 8 Visuals | **AGREE** | Foal scale 0.80 → 1.0 with the 🍼 Young chip is consistent. |
| 9 Phasing | **AGREE** | |
| 10 Config | **AGREE** | Add `breeding.icon = "family"`. |

### §3: the Coat chances box
- 3 rows, each 40 px tall:
  - a 28 px coat swatch;
  - "Comet's coat" (16 px);
  - a 120 × 12 bar;
  - "45%".
- Row 3 is "❔ Surprise" with the surprise swatches and their names ("Dun or Roan"), plus its bar and "10%".
- If both parents share a coat, the box shows 2 rows ("90%").

### §4: the flow, five fixes
1. **Two steps, so it fits a phone.** As one panel it is about 440 px, which renders about 385 and pushes the confirm below the fold.
   - Step 1, "Pick two parents": two 200 × 120 slots above a scrolling list of 64 px rows (coat dot, name, stage chip, reason), then "Next ▶".
   - Step 2, "Your foal": sprouts, the Coat chances box, "Fee 💵 800", then the confirm (two taps: "💞 Have a foal" → "Sure? 💵 800").
   - Both steps use `Ui.fitPanel` at 640 × 400 and fit without scrolling.
2. **Waiting copy counts down in races:** "Arrives in 5 races or tomorrow" (6 words). No clock.
   - It shows as a 💞 chip on the stall and on both parent cards.
   - The Map tile hint reads "Foal soon".
3. **Arrival.** The pill and banner say "💞 Your foal is here!", with GO that opens the arrival.
   - The Map tile hint becomes "Foal here!".
4. **Naming copies the Starter's step 2 exactly:**
   - title "Name your foal";
   - 64 px chips;
   - "🔀 New words";
   - "That's the name!".
   - Drop "Suggest" and "Name me!": two names for the same action.
5. **The Map tile is "💞 Foaling Barn",** tile 14 in the 5 × 3 grid.
   - Its label uses the 16–18 px TextScaled rule.
   - `GoTo("foaling")` opens the picker, or the arrival when a foal is waiting.

### Horse Book Family page
- One row per bred horse: name, the two parents' coat dots and names, and "First foal" on the first.
- Empty state: "Two horses can start a family" (6 words).

## Verdict

**AGREE WITH CHANGES** (§3 and §4). No blocks.
