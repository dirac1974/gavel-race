# Phase 4 consult: UI/UX (2026-10-11, commit 67f503f)

## What passes

**Contrast:**
- Ink on Paper panels, and your own row in `#8F4700`: about 6:1.
- Gold countdown with a 3 px Ink outline.
- White words with a 2 px Ink stroke over the world.
- Gold glow on the Slate slider, with a white marker.
- No red-to-green bars left.

**Earlier fixes that landed:**
- Dock ✕ hidden while the queue card shows its own.
- Tour ✕ 0.6 s guard.
- RACE! reason toast never held.
- "Ask Sam to tap 🎈 Practice too!" / "You're in Sam's race!" (`RaceService.server.luau:513-519`).
- "Pick a horse first!"
- "Back to races" is 140 px and wraps.
- Praise headline for 5th–8th (`ResultsText.luau:91`).

## MUST-FIX

1. **"of 8" renders at 10 px on phones.**
   - It's 16 px × `hudScale` 0.625 (`RaceController.client.luau:383, 441-442`). The spectator board rows are also 16 px × k.
   - Fredoka One under 14 px blurs into blobs on a phone.
   - Fix: copy the Minimap's rule (`Minimap.client.luau:200-204`). Set `placeOf.TextSize = math.max(16, ceil(minTextPx / k))` and do the same for `rows[i]`.
   - Then extend `test_clarity_floors.py` to cover text sizes multiplied by `hudScale`.

2. **The rider's own YOU marker sits in the sightline.**
   - At 667 × 375 in the chase view (zoom 14, FOV 70), a marker 7 studs above the horse lands about 3 studs above the camera focus. That's around y 0.25–0.45, a 56 × 72 block over the rider's head and the horses ahead.
   - It repeats the place badge.
   - Fix (config only): hide it in your own chase view by default. Add `raceHud.youMarker.riderShown = false` and return `false` from `RacePresent.youMarker` when `chase` and not `riderShown`.
   - Keep the big marker for replays and spectators. Add a PLAYTEST line to check it.

## SHOULD-FIX

- **"Glow" → "gold".** "Tap on the glow!" is fine, but now that the target is gold, a colour word is the most concrete one for an 8-year-old ("Tap when the line hits the gold!"). Change the coach hint, the rider hint and the warm-up together, and keep the copy test's ≤ 10 words.
- **The warm-up still plays `ui_pop`** (`QueueCard.client.luau:347`) instead of the race's tap tick pitched by score. Practice should sound like the race.
- **`Ui.fitPanel` still ignores the top-bar inset** (the `PanelFit.layout(v.X, v.Y, …)` call in fitPanel). Panel corners sit under Roblox's menu and chat buttons. Pass `v.Y - inset`.
- **The career patch is still 🎖️** (`Career.luau:11`), which reads as a medal. Use a stitched-patch atlas icon.
- **The Horse Book's "Rosettes" page** (`HorseBook.luau:204`) holds ribbons and medals. Rename it "Prizes".
- **The place badge is now opaque Paper.** If it covers the race map's strip at 375 px, use 0.1 transparency.

## Sign-off

**No, conditional.** MUST-FIX 1 and 2 are small and config- or size-only. With them in, yes; no re-review needed.
