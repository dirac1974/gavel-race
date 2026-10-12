# Phase 1 consult: UI/UX, race HUD (2026-10-11)

I checked the race HUD changes in `RaceController.client.luau` (`git diff HEAD`) at 667 × 375, where `hudScale` is 0.625 and the steering pad buttons are 88 px.

## What landed

- **The slider and meter are clear of the ◀ ▶ pad on phones.**
  - Pad: x 12–200.
  - Slider: x 212–655, y 300–334.
  - "RIDING" label: x 212–282; meter: x 290–556.
  - Nothing overlaps, and nothing jumps when the pad fades. This fixes my original P4.
- **The tap words step below the burst bar:** icon at y 243–295, word 297–343, hint 343–371. All of it stays on screen. The place badge and race map already hide while the burst is up (`:1254`, `Minimap.client.luau:215`), so the bar's right end is clear.
- RIDING gold-on-slate, the word pop (Reduced Motion respected) and grey-until-armed with the whoosh on arming (`:1614`) are all good.

No new floor violations.

## MUST-FIX before Phase 2

1. **Tablets and 720p PCs still have the overlap.** The fix only runs when `RaceState.phone()` is true (`RaceController.client.luau:854`).
   - On a 1024 × 768 iPad the pad is 104 px (x 12–232), and the 70 % slider starts at x 154. The left 78 px of the glow is hidden. On 1280 × 720 the overlap is x 192–232.
   - Fix: make the condition geometric, `padRace and HUD.sliderClearOfPad ~= false and (0.5 - 0.35) * w < right and w - 12 - right >= 200`. Apply the same test to the meter label (`0.3 * w - 78 < right`).
2. **"FINAL BURST ×2" sits on top of the burst bar on short screens.**
   - The title is at y 0.34 (`:353`), and its 52 px glyphs span y ≈ 131–183. The bar is at y 0.44 (165–237), and its marker reaches up to y 143. The result banner (`burstBanner`, y 0.30, 64 px, `:430`) has the same problem after the tap.
   - Fix: anchor both just above the bar. Use `AnchorPoint (0, 1)` at `UDim2.new(0, 0, 0.44, -10)`. On screens under 500 px tall, multiply the TextSize by `RaceState.hudScale()`, but never below 28 px.

## SHOULD-FIX later

- **Silent taps on the grey bar** (code review N2). While the bar is unarmed, set the hint to "Wait for the rainbow…" instead of leaving those taps without a response.
- **Champion's second target isn't greyed** (N3, `:1324`). Grey `zone2` as well.
- **The hint row ends 4 px from the bottom on a 375 px screen** (y 371). Clamp `below + 100` to `viewport.Y - 34`, or drop the hint row while the burst is up, since the word already says it.
- **The pace marker overlaps the meter by about 7 px.** The marker is 54 px tall, from y 290; the meter ends at y 297. Move the meter to y 0.74 when phone.
- **The Great/Perfect chime is lost under the tick** (N4). Kids lose their "Great!" reward sound. Keep `tap_good` on Perfect, or record the change as a decision.

## Sign-off

**No, conditional.** Fix MUST-FIX 1 and 2 (both S, config-safe, no asset). Then yes; I don't need to look again.
