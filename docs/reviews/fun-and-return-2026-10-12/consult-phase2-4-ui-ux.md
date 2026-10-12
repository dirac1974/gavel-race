# Phases 2–4 consult: UI/UX (D-076 to D-078, 2026-10-12)

## Passes

- **Cup bar:** 🏆 with a fill and no number, 160 × 12. The results card shows "🏆 Cup +6".
- **Copy length:** every line is 6 words or fewer.
- **RACE! and Race again labels:** "🩺 VET CHECK" and "🩺 Vet check" fit, because the Phase 1 TextScaled fix covers them.
- **Legs row:** "Legs", then 6 sky-blue pips (never red), then the chip, which ends at x 343 and fits the 353 px card.
- **Cool-down Check:** free, sky blue, and "🩺" means vet everywhere.
- **Riding School:** 🏫 Lend / 💵 Sell / 🏠 Home, each a two-tap confirm in the same "Sure? ⟨icon⟩" pattern.
- **Symbol clashes:** I searched `game/src` for each symbol. 🦉, 💐, 🍼 and 🧶 have no other meaning. 🏠 already means home on the Map, so it's consistent.

## MUST-FIX

1. **💦 already means Mud Splash and Grit** (`Training.luau:23`, `HorseBook.luau:41`, training ride text).
   - Change `Legs.CHIP_WARN` (`Legs.luau:18`) to **"🧣 Worked hard! Cool-down soon"**: 4 words, and the icon points at the cure.
   - The Cool-down panel's droplet stays 💦: it's water, inside the game.

2. **The class path chips are emoji only** (`HorsesClient.client.luau:141-145`): 🐣🚀🎽💐🏆, about 60 px each. An 8-year-old can't decode a row of emoji.
   - Make the **current** step's chip double width and show `ClassPath.label(step)` ("🎽 Open").
   - The other steps stay emoji only.
   - Use `TextScaled` with a `UITextSizeConstraint` of 14 to 16 and `TextWrapped = false`.

3. **The stage chips overflow** (`HorsesClient.client.luau:170-172`). "🦉 Veteran" at 16 px is about 80 px in a 76 px chip, so it wraps out of its 24 px height.
   - Apply the same rule as #2: the current stage shows emoji plus word in a double-width chip, the others emoji only, with `TextScaled` 14 to 16.

4. **"Star Race" sits next to "Rising Star"**, so one path has two "Star" names. ★ also means "how you rode" (D-064).
   - Rename it **"Big Race"** and keep 💐: `ClassPath.WORD.Star = "Big Race"`, giving the ceremony line "💐 Comet is Big Race ready!" and "💐 Big Race: 2 more wins".
   - Add "Star Race" to the copy test's old-names list.

## SHOULD-FIX

- **Card height on phones.** A 500 px card cell is taller than the phone's list view (about 327 unscaled), so every card scrolls past its buttons. On phones (`DockLayout.isPhone`), fold the class, stage and legs rows behind a "📈 Progress" toggle. Cell 330 closed, 500 open.
- **🍼 for Young** reads a little babyish for 11–13-year-olds. Fine for now; review it at the playtest.

## Sign-off

**Yes, after MUST-FIX 1–4** (all S: copy and client only). No re-review needed.
