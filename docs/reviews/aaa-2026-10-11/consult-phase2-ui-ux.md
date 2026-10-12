# Phase 2 consult: UI/UX lead (2026-10-11)

Screens re-derived from the diff at 667 × 375 (phone, top-bar inset about 36 px) and 1024 × 768 (iPad).

## What landed

- **First minute:** the tour holds the top slot; RACE! shows a glow and a 🐾👇 arrow; the pill and the 💎 pill are hidden; toasts are held. One voice.
- **Compact queue card:** a 509 × 64 row at x 12–521 with the 💎 pill clear of it, and a Warm-up that expands below it.
- **iPad:** the full 672 px card is centred and clear of the right-hand column.
- **"In line!":** shows on the pill, on RACE! (with ⏳ 12s underneath) and on the card.
- **The gear sits under 💎.**
- **Floors and contrast** applied across the panels. Both Phase 1 must-fixes are in (`RaceController.client.luau:411, 489, 895`).
- **Results on iPad:** the card fits unscrolled at scale 1.

## MUST-FIX

1. **On phones, the results card's buttons are below the fold.**
   - The full card is about 524 px tall (`ResultsCard.luau:169-224`). At the floor scale of 0.875 it renders 458 px into a 333 px room, so it scrolls (`:155-162`).
   - The visible part ends around unscaled y 369, while 🏁 Race again starts at y 370 and Done at y 442. A kid sees the place and the stars, but neither exit; with the 58 px top bar it is worse.
   - Fix: when `f.scroll` and the screen is landscape, use a two-column layout at `CARD_W = 720` (630 px rendered).
     - Left column: headline, cheer, best ride, stars, gain line and Race again. About 312 px tall, 273 px rendered.
     - Right column: the result rows, then ↺ Finish, ↺ Whole race and Done.
     - Gate it with `results.twoColumnBelowPx = 500`. It fits with no scroll.
2. **On phones, the Starter's Next ▶ is cut off.**
   - `Starter.client.luau` passes `fitPanel(panel, 720, 470, nil, 18, 64)`, which hits the 0.875 floor: 411 px rendered in 355 px, so it scrolls.
   - Next ▶ lands at y ≈ 351–407 on a 375 px screen, so only about 24 px of it shows. This is the first button anyone presses.
   - Fix: when `viewY < 500`, shrink the horse viewports from 150 to 104 px and close up the title gap so H = 404 (353 px rendered, fits). Or pin Back and Next in the top row next to the title.

## SHOULD-FIX later

- **`Ui.fitPanel` ignores the top-bar inset** (`Ui.luau` fitPanel `apply`). Panels centre in the full viewport, so their top corners sit under Roblox's menu and chat buttons. Subtract `GuiService:GetGuiInset().Y` from the room, as `ResultsCard.fit` already does.
- **A double tap skips the tour.** The confirm (`GrownUps.client.luau` tourSkip) is the same button in the same place, so an 8-year-old's quick double tap skips. Ignore a second tap within 0.6 s.
- **Two ✕ buttons to leave the line:** the dock's (`Hud.client.luau` leaveBtn) and the queue card's. When the queue card is showing, hide the dock's.
- **The warm-up doesn't match the race.** It plays `ui_pop` and says "Tap on the green!" (`QueueCard.client.luau` warmBar). Use the race's `tap_ok` tick pitched by score, and the race's own hint words, so the practice carries over.
- **The headline for 5th–8th.** "8th place!" is honest, but for these places lead with the praise line and put the place under it. A copy test can hold it to kind words only.
- **The compact row text is 231 px wide** while Warm up is offered. Check "⏳ 12 · 3 riders" doesn't truncate in the emulator.

## Sign-off

**No, conditional.** Fix MUST-FIX 1 and 2. Both are layout-only, size S, config-gated and need no assets. Then yes; no re-review needed if the PLAYTEST phone-emulator line shows "Race again" and "Next ▶" without scrolling.
