# UI/UX review — Giddy-Up (2026-10-11)

Screens reconstructed from code (never run in Studio). Reference device: PLAYTEST's phone in landscape, about 667 × 375.

## 1. Verdict

The design intent beats most shipped kids' games: the hard rules show up in the UI, and the D-064 floors are config-backed and tested. Execution on the phone, the platform this game is for, is not ready. The screens were each designed alone, and nothing arbitrates between them: on a 375 px phone a queued kid sees about 15 px of the world, a new player gets four competing instructions in the first ten seconds, and the post-race card, the most emotional screen in the game, renders 22 px buttons and has no "You won!" or "Race again". The floors cover four panels out of about fifteen. Fix layout arbitration and the race-to-race loop before adding any more features.

## 2. Top problems (ranked by player impact)

### P1. The phone screen fills up as soon as you join the line — Size M, no asset
- **Evidence:**
  - The queue card is 660 × 156 at the top and scales only by width (`QueueCard.client.luau:320, 328, 334`). At 667 × 375 it covers y ≈ 44–196.
  - The Next-thing pill and Pip bubble (`StableBoard.client.luau:371–378`) plus the dock (`Hud.client.luau:57–58`) take the bottom 164 px. About 15 px of world is left.
  - Toasts sit at y = 64 (`Ui.luau:320`) and the tour card at y = 96 (`GrownUps.client.luau:192`). All three are top-centre, with no stacking rules.
  - The RACE! button becomes "In line! Dirt 12s · 3 riders" at 30 px in a 200 px button (`Hud.client.luau:214, 305–309`). That's three lines, clipped.
  - On a phone, the 💎 pill and the ⚙️ gear both sit top-right at y ≈ 44–116 (`Hud.client.luau:108`, `GrownUps.client.luau:35`) and overlap each other.
- **Why it hurts:** D-061 sells "groom while you wait", but a kid can't see their horse. Overlapping cards read as broken.
- **Fix:**
  - Add a small `Ui.slot("topCentre", priority, frame)` that shows only the highest-priority occupant (queue card > tour > toasts) and moves the others below it.
  - On `DockLayout.isPhone`, draw a compact queue card (`queueCard.compactPhone = true`): one 64 px row with the ring, "Race in 12 · 3 riders" and ✕. Tap it to see the 8 gate slots.
  - While the player is in line, the pill shows "You're in line!" for every suggestion, not only `go == "race"` (`StableBoard.client.luau:416`).
  - The RACE! button in line shows the seconds only.
  - Move the gear under the 💎 pill (`y = inset + 64`).

### P2. First minute: four instructions, two dead buttons — Size S, no asset
- **Evidence:** right after the starter pick, all of these are on screen at once:
  - the toast "Meet Comet! Tap RACE!…" (`Starter.client.luau:281`);
  - the tour card "Let's race! Tap GO…" (`Tour.luau:13`), whose GO is 44 px next to a 44 px Skip, 16 px apart (`GrownUps.client.luau:203–204`);
  - the pill "Feed Comet some hay", because `Advice.nextThing` puts feed and groom before race (`Advice.luau:510–518`);
  - the RACE! button itself.

  After GO, the tour card stays up with a GO that does nothing (`pressRace` returns while in line, `Hud.client.luau:284`).
- **Why it hurts:** a kid is told to race and to feed at once; Skip sits where a thumb aiming for GO lands.
- **Fix:**
  - While `Tour.current(flags)` is set, hide the pill and drop the Starter toast. The tour owns the screen.
  - For the race step, hide the tour's GO and pulse the real RACE! button with a hoofprint arrow. Kids learn the button they'll use forever.
  - Advance the tour on `JoinRace`, not at race end.
  - Make Skip a quiet "✕" on the far edge, 56 px, that asks once.
  - Put `race` first in `nextThing` until the first race (`nextThing.raceFirstUntilRaces = 1`).

### P3. Results card: below the floors, no headline, no "Race again" — Size M, reuses the ribbon art
- **Evidence:**
  - The card is 360 px wide and scaled by `RaceState.hudScale()` (`RaceState.luau:45–48`, clamped at 0.62). At 375 px high that gives 13.75 px rows, 25 px "Watch the finish" and "Whole race" buttons (`RaceController.client.luau:461`), and a 22 px "Done ✕" (`:463`).
  - "Done ✕" sits 110 px above the card at y 0.24 (`:421`), which puts it at y ≈ 21, inside the Roblox top bar.
  - Your place appears only as a 22 px row, "3. Comet +8 ◀ YOU". The headline is the ★ row.
  - There is no Race again. The loop is Done → dock reappears → RACE! → wait.
- **Why it hurts:** the payoff screen's only exit is the hardest target in the game.
- **Fix:**
  - Rebuild the card with `Ui.card` and `Ui.button` and never scale it below `PanelFit.floor(16, 64, GameConfig.ui)`.
  - Order the card: a big ribbon headline ("1st! You won!" or "3rd place!"; `ribbon_*` art exists), then "You rode ★★☆", then the gain line.
  - Bottom row: **🏁 Race again** (primary, 64 px; calls `closeResults()` then `PressRace`), ↺ Watch, Done.
  - Behind `results.raceAgain = true`. It's not a purchase prompt, so D-050's rule is unaffected.

### P4. On phones the steering buttons cover the slider and the race map is unreadable — Size M, no asset
- **Evidence:**
  - The steering pad is 2 × 88 px at bottom-left, y 0.75 − 8 (`RaceController.client.luau:773–781`). The pace bar is 70 % wide at y 0.80 (`:283`). At 667 px the left ~100 px of the slider, and the "SPEED" label (`:329`), sit under Out ▶. When the glow moves left, it's hidden.
  - The race map scales to 0.62: lane digits are 9 px (rendered 5.6 px), the gap text 9 px, the title 10 px (`Minimap.client.luau:117, 148, 181`). The place badge's "of 8" is 10 px (`RaceController.client.luau:349`).
- **Why it hurts:** a hidden target is a lost tap a child blames on themselves.
- **Fix:**
  - When `RaceState.phone()` and the pad is up, place `pace.bar` and the speed meter between the pad's right edge and the right margin. The feedback text already does this (`:784–791`). Or raise the pad to y 0.50 (`steerHud.phoneLayout = "raised"`).
  - Race map on phones: drop the oval and the digits (keep the colour dots), and floor the remaining text at `ui.minTextPx`.

### P5. The core skill is taught by one line of text — Size S, no asset
- **Evidence:** the first race teaches only the hint "Tap when the marker crosses the glow" at 20 px (`RaceController.client.luau:1289`). The target moves every 2–3 passes, and the Final Burst ×2 appears once with no warning. A ghost-thumb tip is already built, but only for steering (`:740`).
- **Fix:**
  - For races ≤ 1, reuse `thumb` over the glow for the first 4 passes, and flash "NOW!" as the marker enters the zone (`hud.coachPasses = 4`).
  - Show "Big tap coming! Hit the middle" for 1.5 s before the burst.

### P6. The floors only cover four panels — Size M, no asset
- **Evidence:**
  - `Ui.fitPanel` is used only by My Horses, RacePicker, StableBoard and Rehome.
  - **The Starter, the first screen anyone sees**, scales to 0.75 with no floor (`Starter.client.luau:37–44`): word chips render at 34 px and the blurb at 13.5 px.
  - ✕ buttons come in 40, 44, 56 and 64 px (`WildHorses:162`, `CareClient:68`, `PaddockClient:81`, `StyleShop:67`, `GrownUps:60`). StyleShop tabs are 44 px with 15 px text (`StyleShop.client.luau:257`). The training "✕ Stop" is 46 px.
- **Fix:**
  - Add a single `Ui.closeButton(parent)` at `ui.panelButtonPx`.
  - Route Starter, Care, Paddock, StyleShop, GrownUps, Taming and the training cards through `Ui.fitPanel`.
  - Extend `tests/test_clarity_floors.py` to fail any `Ui.button` under 56 px, or any `Ui.text` under 14 px, in `game/src/client`. Also scan `RaceController`'s own `label` and `button` helpers.

### P7. The phone dock hides the core fantasy, and its biggest card does nothing — Size S, no asset
- **Evidence:**
  - On touch the horse card can't be tapped (`horseHit.Visible = not on`, `Hud.client.luau:406`).
  - On a phone, Ride, Horses, Map, Jobs, Book and cash all move into ☰ More (`:363–394`). Riding your horse, which David asked for, takes 2 taps.
- **Fix:**
  - Set `ui.dockPhoneItems = 4`: a 70 px horse portrait (coat dot over the Energy pips) that opens My Horses, then RACE!, 🐴 Ride, ☰ More. That's ≈ 440 px, which fits at scale 1.
  - GUI buttons take the touch before the thumbstick does; confirm this in the emulator.

### P8. Symbols and words that still mean two things — Size S, no asset
- **Evidence:**
  - "Ride" means three things: make this horse active (`HorsesClient.client.luau:154`), ride in the world (`RideClient.client.luau:54`), and a Legend ride (`HorsesClient.client.luau:148`).
  - 🐴 means My Horses, Ride, Pip, the starter and loading.
  - The race status line says "Sprint" (`RaceController.client.luau:1286`), but the picker says 🐇 Short.
- **Fix:**
  - Rename My Horses' button to "🏁 Race this one".
  - Pip gets their own icon.
  - The status line takes its distance word from `PickerText`.

### P9. Coloured text fails contrast — Size S, no asset
- **Evidence:** "Loves this race" uses `C.green` #46C46A: 2.2:1 on white and 1.6:1 on the selected gold card. `orangeDark` is 3.1:1 (`RacePicker.client.luau:256`). Plum sublines at 16 px are about 4.5:1.
- **Fix:** add `Ui.colors.textGood = #1E7A3C` and `textWarn = #A65300` for text, keep the bright colours for fills, and add a contrast check to `clarity_tests`.

Lower priority: the race HUD's own GothamBold helpers look like a different game; toasts have no cap and don't wrap.

## 3. What's genuinely good: don't break it

- **The race screen follows the hard rules:** no live win % and no purse on the board (D-055). The 💎 door shuts around races. The Diamond pill has no glow, pulse or badge. There are no red badges, bells, streaks or countdowns-to-offer anywhere.
- **One-tap "🏁 RACE! with Comet ▶"** and a queue card that names every horse and says "🤖 Bots join at 0". That's honest wait design; keep the content and just make it compact on phones.
- **The floors are config-backed and tested** (`DockLayout`, `PanelFit`, `Words` copy tests, ≤ 10-word toasts, a banned-word scan). This is rare discipline; extend it, don't replace it.
- **Tap feel:** tap anywhere, the 150 ms bounce, no "Miss", "Early" and "Late" instead of failure words, a 3-2-1 countdown, and a tip shown once for wrong keys.
- **Accessibility:** Okabe-Ito lane colours, Reduced Motion respected, steering arrows never red.
- **Copy:** word-chip naming (nothing to filter), "They're all just as fast. Pick the one you love!", no guilt in `Advice`.
- **Golden hoofprints** (`Guide.luau`) as the one meaning of GO across the game.

## 4. Top 5 must-do (in order)

1. **Phone screen budget (P1):** a top-centre slot arbiter, a compact phone queue card, the pill set to "in line" while queued, and the gear moved off the 💎 pill.
2. **Results card (P3):** floored sizes, a place headline with the ribbon, a 64 px "🏁 Race again", and Done out of the top bar.
3. **One voice in the first minute (P2 + P5):** the tour owns the screen, RACE! is the taught button, Skip moves away from GO, and the first race is coached with the existing ghost thumb.
4. **Race HUD on phones (P4):** keep the slider clear of the steering pad, and give the race map a phone mode with readable text.
5. **Floors everywhere (P6), starting with the Starter:** add `Ui.closeButton` and a lint test that fails any button under 56 px or text under 14 px in the client.

Next: the 4-item phone dock with Ride (P7), the "Ride" and 🐴 meanings (P8), and the text colours (P9).
