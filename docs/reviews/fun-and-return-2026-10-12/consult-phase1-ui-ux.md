# Phase 1 "Find it" consult: UI/UX (D-075, 2026-10-12)

## Rulings on the deviations

| Item | Ruling | Reason |
|---|---|---|
| (a) Colour dots instead of 🥉 | **Accept** | 🥉 does mean 3rd place. The word ("Bronze race line") carries the meaning, so colour is never the only cue. Later: swap the emoji for the 24 px atlas `badge_<league>` icon, since emoji circles render differently across platforms. |
| (b) ❓ at 64 px | **Accept** | It matches the card's 64 px floor. The title is narrowed to clear it (`QueueCard.client.luau:103`). |
| (c) Pick strip 64 px, RACE! slot 210 | **Accept at 667 px only.** See MUST-FIX 1 and 2. | At 667 px the dock is 530 px wide, which scales to 464 px against 467 px of room. A 568 × 320 phone has only 368 px of room, so the dock would cover Hop and Gallop. |
| (d) Tappable portrait in the thumbstick zone | **Accept, provisionally** | The tap only fires on release inside the portrait, so a drag shouldn't open My Horses. Needs a PLAYTEST line: "Start a thumbstick drag on the portrait: you walk, My Horses stays shut." If it fails, set `ui.portraitTap = false`; Horses then stays in ☰ More. |
| (e) ❓ shows by itself in the first line | **Accept** | The first 15 s wait is the right moment. SHOULD-FIX: close it on `RaceTime`, not only on `Racing`, so the kid sees "Race time!". |

Checked against my proposal and votes, and passing:
- the 13-tile grid, 116 × 96, fits the phone without scrolling;
- GO follows walk / teleport / open / "After your race!";
- the "New!" pointers are spaced 180 s apart, never in the 120 s after a race, never during the tour, with a 1 Hz ring;
- the line names and the why lines (6 words or fewer);
- "Pick a race" and "Join Bronze line";
- the code-built signpost (0 Meshy).

## MUST-FIX

1. **The phone dock adapts to narrow screens** (`Hud.client.luau` `applyPhone` / `movable`).
   - If the 5-item width × `DockLayout.floor` is more than `viewX − 24 − movementColumn`, move Jobs into ☰ More.
   - If it still doesn't fit, move Map too, leaving the D-064 3-item dock.
   - Add a config key, `ui.dockShrinkOrder = { "jobs", "map" }`.
   - Lune check: at 568 × 320, the dock is ≤ 368 px wide.

2. **RACE! text fits its 142 px face** (`Hud.client.luau:263-266`).
   - "🎈 PRACTICE" at 24 px is about 155 px wide, so it wraps over "with Comet ▶". "🩺 VET CHECK" comes next and has the same problem.
   - Fix: set `raceBtn.TextScaled = true`, and add a `UITextSizeConstraint` with Max 30 and Min 18.
   - While `raceSub` is visible, add a `UIPadding` bottom of 22 px so the scaled text never covers the sub-line.

3. **Map tile labels mustn't truncate** (`WorldClient.client.luau:148`).
   - At 18 px Fredoka, "Barn Builder" and "Tack & Paint" (about 120 px) overflow the 112 px label and show "Barn Buil…".
   - Fix: set `TextScaled = true` with a `UITextSizeConstraint` of Max 18, Min 16. 16 unscaled renders at 14, the floor.

## SHOULD-FIX

- HowRacing closes on `RaceTime` (see (e)).
- Atlas icons for the 5 Map tiles with an empty `MAP_ICONS` (barnBuilder, tackShop, market, paddock, trainingGround), so they stop depending on emoji. Use `make_ui_svgs.py`; no Meshy.

## Sign-off

**Yes, after MUST-FIX 1–3** (all S, client-only). No re-review needed.
