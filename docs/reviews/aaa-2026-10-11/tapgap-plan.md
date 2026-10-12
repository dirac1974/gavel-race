# Tap gap plan: a draw-only pre-lock preview layer (D-070, provisional)

**Goal.** From the gate onwards, good taps visibly gain ground within 1–2 s. Nothing that decides the race changes: Trip inputs, τ, holds, lane choices, scores, order or prizes. No luck shows before the lock.

## Design: a shadow follower on the server

Before the lock, `Trip.frame` sends `st.off`, which chases `lead · (live − 1/n) · ramp − tuck − check` (`Trip.luau:665-673`). `live` changes only when a checkpoint closes. A new pure module, `shared/TapPreview.luau`, keeps a drawn offset `d[i]` per lane that follows a preview target:

- **Target:** `T[i] = off[i] + lead · (pv[i] − live[i]) · ramp · n/(n+k)`.
  - `pv = session:previewLive(seg, partial)`, which is skill-only and stores nothing.
  - `n` is the passes finished in the open checkpoint, and `k = shrinkPasses` (4). Shrinking means one lucky pass can't jerk the field.
- **Clamps**, applied leader-first every frame:
  1. `|d − off| ≤ capFeet` (12 ft, about 1.5 lengths).
  2. Speed `≤ feetPerSecond` (10, matching `raceView.maxGapFeetPerSecond`) and acceleration `≤ accelFeetPerSecond2` (20). No reversal jerks.
  3. Lane room: `clearFeet` (10, Trip's `holdGap`) to the horses ahead and behind whose drawn lane **or target lane `st.tgt`** is within `laneBand`. Checking the target lane means a horse gliding in is cleared before it arrives, so nothing snaps. Reuse `RaceFx.nudgeRoom` on drawn offsets.
- **Checkpoint close.** `live` jumps to roughly the old `pv`. Trip's `off` eases up behind; `d` is already there and holds. The new checkpoint starts at `n = 0`, so `T = off`, and the clamps pull `d` back no faster than `off` rises. No drop.
- **The lock.** Trip copies `view = off` (`Trip.luau:1055`). The layer keeps the residual `d − view` and decays it to 0 under the same limits within about 1 s. The post-lock `PacePreview` already moves `view` the same way.
- **Steering off** (`trip == nil`): no lanes and no holds. Preview from the gate to the last tap: `PacePreview.afterLock` gets a `trip == nil` branch (`RaceService.server.luau:1018`). The rate limits still apply.
- **Where it runs.** In `RaceService` `send()`, after `Trip.frame` and before `RaceOffsets:FireAllClients`.
  - Every screen gets the same offsets, so places agree everywhere.
  - The `lanes` arrays aren't touched.
  - `RaceView` and `Playback` don't change.
  - The own-screen tap nudge stays on top.
- **Cadence.** Recompute `pv` at every pass end (0.55–1.2 s), from pass `minPasses` (2) on.
- **No luck.** The layer is given only `live`, `pv`, `off`, `x`, `tgt` and the clock. Before the far turn `w = 0`.

## HUD (rider only)

- A chip above the slider: **"Giddy-up! +1 length"**. It shows when your drawn lead over the field's mean has grown by one length (8 ft) since the last chip, at most every 4 s.
- Gains only, never a loss, never a percentage. The place badge's pop-on-gain does the rest. `hud.arrowOnPreview` stays false.

## Config

```
GameConfig.tapPreview = { enabled = true, minPasses = 2, shrinkPasses = 4, capFeet = 12,
  feetPerSecond = 10, accelFeetPerSecond2 = 20, clearFeet = 10, residualSeconds = 1,
  steeringOffWholeRace = true, chip = { enabled = true, minFeet = 8, everySeconds = 4 } }
```

`enabled = false` gives exactly today's race.

## Tests

1. **Byte-identical decisions.** 200 seeded races (Lune `race_overlap` harness), layer on vs off. Must match exactly: Trip `off`, `x`, `tgt`, answers and brushes every tick; τ; scores; `live` at each close; finish order; prizes; and the sent `lanes`.
2. **Overlap report, d057 mode, layer on.** 3,840 races with rider profiles perfect, average, masher and streaky. Must show 0 overlaps and 0 jerks, reversals ≥ 3.5 s apart, acceleration in bounds, and no frame step above `feetPerSecond · dt`.
3. **No luck.** Permuting `session.luck` leaves pre-far-turn drawn offsets identical. A source scan checks that `TapPreview` never reads `luck`.
4. **Handovers.** Limits hold across every close and the lock, and the residual is 0 within `residualSeconds + 0.2`.
5. **Steering off.** The order on screen at the last tap equals the result.
6. **Gain target.** Rookie Mile, bots at 60, rider at 60 then all Perfect from 15 s. Versus the layer off, the drawn gain is **≥ 4 ft within 2 s of the 3rd Perfect** and **≥ 8 ft within 5 s**. A rider at the field average moves ≤ 2 ft (no phantom motion).
7. **Chip.** Never on a loss, and at most once every 4 s.

## Acceptance

- Tests 1–7 pass, plus `python -m pytest -q && bash scripts/policy_guard.sh`.
- PLAYTEST line: "Three Perfects early: your horse moves up within about 2 s; nothing jumps back at checkpoint 1 or the lane lock."
- Most testers can say how their taps changed the result.

## Split

**model-engineer**
- `TapPreview.luau` (pure: target, step, residual, chip).
- A layer-on mode and kid profiles in `race_overlap.luau` and `overlap_report.luau`.
- Tests 1–7.
- Tune `capFeet`, `shrinkPasses` and acceleration against test 6 with 0 jerks.
- No Python mirror: the layer decides nothing (note this in D-012's scope).

**roblox dev**
- `RaceService`:
  - `pv` at every pass end;
  - `TapPreview.step` in `send()` on both paths;
  - the lock residual;
  - the `trip == nil` whole-race branch.
- The chip in `RaceController`.
- `GameConfig.tapPreview`.
- PLAYTEST line; D-070 and a REVIEW_QUEUE row via scribe.
