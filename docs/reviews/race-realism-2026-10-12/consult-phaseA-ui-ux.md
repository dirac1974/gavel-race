# Phase A consult: UI/UX (D-072, 2026-10-12)

## Checked against votes-ui-ux.md

| Item | Status | Where / note |
|---|---|---|
| Staged onboarding: race 1 buttons only, race 2 tip, race 3 pips hook | **Pass** | `Trip.riderControls` (`Trip.luau:1354-1368`): `tip` from `tipRace − 1`, `pips` from `pipsRace − 1`, `introRaces 0`. |
| Labels never change mid-race | **Pass** | `paintButtons`/`paintArrow` only change colour, transparency and the icon. "◀ In" / "Out ▶" stay put. |
| Arrow promise: grey while a door would shut | **Pass** | `riderSide` returns `"blocked"` when `doorWouldShut` (`Trip.luau:1443-1444`), so the arrow is grey with 🐎 and never lit into a shut door. |
| Copy "No room yet!" | **Pass** | `RaceController.client.luau:1084, 1627, 1637`. |
| Hurdles (`fixedLanes`) hides the buttons | **Pass** | No controls or steers are sent in a fixed-lanes race (`RaceService.server.luau:781-784`), so the pad stays hidden, keys are sunk, and there is no hint and no lock bell. |
| Keys never turn the camera | **Pass** | `saddleKeys` bound from saddle to dismount (`RaceController.client.luau:889-916`). |
| Message priority | **Acceptable for phase A** | Coaching sits on the hint line and chips sit above the pad, so they never collide. The vote's full priority queue is needed in phase B, when move chips arrive. |

## MUST-FIX

### 1. Clear the gamepad selection when the results close
`GuiService.SelectedObject = Card.doneBtn` (`RaceController.client.luau:1899`) is never cleared. If it stays set, the D-pad passes through to menu navigation (`:899`) in the next race, so the D-pad stops steering.

Fix: in `closeResults`, and when a replay starts:
```lua
if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(Card.gui) then
  GuiService.SelectedObject = nil
end
```

### 2. Select Race again, not Done
The primary action is 🏁 Race again. Select `Card.againBtn` when it is visible, else `Card.doneBtn`. The 0.35 s `Card.ready` guard already stops an instant A press.

### 3. A 16 px dead zone round the steering pad
The buttons now show from race 1, while the kid is still learning tap-anywhere. A thumb drifting onto the pad edge steers instead of tapping.

Fix:
- Add a transparent `TextButton` at `steerPad` size + 32 px (16 px each side), ZIndex just under the arrows. It sinks touches and does nothing.
- Add the key `steerHud.padHaloPx = 16`, where 0 means off.
- Add a PLAYTEST line: "tap near the pad: no lane change".

## Sign-off

**Yes, after must-fixes 1–3** (all size S, client-only). No re-review needed.
