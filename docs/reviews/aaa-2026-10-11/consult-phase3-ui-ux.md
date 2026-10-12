# Phase 3 consult: UI/UX (2026-10-11)

## Floors and layout: pass

- **👫 Friends button:** 150 × 64. It sits clear of the centred title and the ✕.
- **Friend buttons:** 200 × 130 with 20 px text.
- **Empty state:** 20 px, kind wording.
- **Legend row:** 80 + 160 + 80 px plus gaps is 332 px, inside a row of about 337 px. That's only 5 px spare (see SHOULD).
- **Two-tap confirms are consistent:** "👑 Legend" → "Sure? 👑" in red, and "🏁 Back to races" → "Sure? 🏁" in green. Same pattern, and the colour matches what each one does.

## MUST-FIX

1. **"Race with Sam" can be untrue** (`RacePicker.client.luau:171, 177`; `RaceService.server.luau:473-494`).
   - Sam is never told (no invites, which is correct). If Sam isn't already in a Practice line, `friendPracticeCourse` returns nil.
   - The kid still sees "🎈 Practice race with Sam!" and then races bots alone. To a kid, that reads as broken, or as Sam ignoring them.
   - Fix:
     - Drop the client toast at `:177`.
     - Have the server send one Notice from the join:
       - when the course was found: "🎈 You're in Sam's race!";
       - when it wasn't: "Ask Sam to tap 🎈 Practice too!".
     - Both are under 10 words.
     - Optionally, label the button "🎈 Join Sam" when Sam is in a Practice line.

## SHOULD-FIX

- **Silent failure on the friend button** (`:175`). It does nothing if no horse is picked. Preselect the active horse when the Friends page opens, or toast "Pick a horse first!".
- **The Legend row has 5 px spare.** Make "🏁 Back to races" 140 px wide with wrapping on, so a wider emoji glyph on some devices can't push ✏️ Name off the card.
- **Patch vs medal icons.** 🎖️ is a military medal, but it's now called a "patch", and training medals are 🥉🥈🥇. An 8-year-old will call 🎖️ a medal. Give the patch its own icon (`Career.BADGE`, `Career.luau:58`): a stitched-patch atlas icon from `make_ui_svgs.py`, no Meshy.
- **Two kinds of stamp remain:** Passport stamps and 🎀 monthly stamps. Rename the monthly ones to "🎀 bows" after the playtest. The bow emoji already says it.
- **The Horse Book "Rosettes" page** now holds ribbons and medals. Rename the page to "Prizes".

## Words, for an 8-year-old

- **"Medal" (training):** clear.
- **"Tour pin" / "📍 Pin":** clear. Kids collect pins.
- **"Career patch":** fine once the icon matches.
- **"Back to races":** clear.
- **"Open class" vs "Open Practice":** "Open Practice" never appears in player copy (good). Keep it that way.

## Sign-off

**No, conditional.** Fix MUST-FIX 1: S, no asset, server Notice plus removing one client line. Then yes, with no re-review needed.
