# Race realism phase A (D-072): Python sims, interim (2026-10-12)

**Status: interim.** The full calibration (`python sims/steering.py --write`, 2,000 baseline races per cell and post, about 2 h) was stopped by the machine running low on memory. The live baseline, the stored report, `TripBaseline.luau` and the parity fixtures are therefore still D-057's. The figures below come from runs that did finish:
- a medium calibration (300 baseline races per cell and post, 150 report races per cell);
- paired `sims/realism.py` runs.

Both ran before two late changes: `file.riderRoomFeet` 6 and the rider entry in the style row. The ✓/✗ marks are provisional until the full write is rerun.

Before = the game today (`trip.d057_config()`, `trip_baseline_d057.json`). After = `trip.CONFIG` with D-072 on.

## Gates

| Gate | Target | Before | After (interim) | |
| --- | --- | --- | --- | --- |
| Perfect rider, solo Rookie wins | ≤ 38% | 35.0% | 35.3% (+0.29 pt, ±0.06) | ✓ |
| New / average kid | ≥ 19% / 24–27% | 20.9 / 24.3% | 21.1 / 24.6% | ✓ |
| Upsets: bottom-half / longest-shot wins (all T) | ±1 pt | 37.71 / 7.13% | 37.66 / 7.13% | ✓ |
| Cash per race (expected purse, Rookie) | ≤ 2% change | — | +0.65 to +0.85% | ✓ (see note 1) |
| Style bias, bot fields | ≤ 0.002 | — | max 0.0014 | ✓ |
| Post bias, kid among bots and all-Smart | ≤ 0.002 | 0.0010–0.0024 | 0.0018–0.0034 | ✗ (note 2) |
| Trip τ before the clamp, p99 | ≤ +0.04 | — | max +0.034 (Marathon) | ✓ |
| Drift, relative speed between two horses | ≤ 3 ft/s | — | 3.00 | ✓ |
| Boxed share, Rookie Mile (Python stand-in) | ≤ 35% | 66.5% | 23.3% with riderRoomFeet 6 (67.2% without) | ✓ (note 3) |
| Passes per race (Trip's rule, completed) | 3–10, ≥ 60% on straights | 0 | 1.1 (Sprint) to 4.1 (Marathon); 70–100% on straights | partial (note 4) |
| Drawn overtakes (half-length each way) | — | — | 11–47 a race (neighbours within 2.5 lanes; now 1.5) | reported |
| Shut doors per race (bot fields) | — | 0 | 3.3–7.8 | reported |
| Overlaps / fall-back (stress) | 0 / ≤ 20 ft/s | 0 / 19.0 | 0 / 19.0 | ✓ |

The D-054 and D-057 targets in the same medium run:

| Target | Result | Why |
| --- | --- | --- |
| Rail rider vs Smart Steer +0.01…+0.03 | ✗ (+0.001…+0.003) | Smart Steer now rides the rail (`file.homeLane` 1, as the plan asked), so the rail rider has no edge left. |
| Inward press within 3 s ≥ 70% | ✗ (53–67%) | The rail is crowded. |
| Masher reversals ≤ 8 a minute | ✗ (8.0–8.4) | Shut doors make presses wait. |
| Draft share ≤ 40% | ✗ (Sprint 40%, at the limit) | — |
| Smart Steer kid mean 0 ± 0.003 | ✗ (+0.007…+0.015) | Fixed since then by the rider entry (note 5). |
| Never-steer, griefing, brushes, stress, sideways acceleration | ✓ | — |

## Notes and proposals

1. **Cash per race.** Measured with tau in the race; `sims/economy.py --greencash` has no tau, so it doesn't move. The +0.7% is the interim kid edge from note 5, and should fall to about 0 once the rider entry is calibrated.
2. **Post bias ≤ 0.002 is at the noise floor.** Today's game fails it too (turf Sprint, all-Smart: 0.0024). The interim run used 300 baseline races. Proposal: judge it on the full 2,000-race write; if it still misses, raise `BASELINE_RACES` to 4,000.
3. **Boxed share.** `sims/realism.py` is a Python stand-in for the D-071 harness. It reads about 15 points high (66.5% before, against 48.6–53% in Luau), so the cut from 66.5% to 23% is what counts. Filing to the rail alone made boxing worse, because it builds columns. The fix is `file.riderRoomFeet` 6: a Smart Steer rider files in only with clear run ahead.
   - The shipped figure needs `lune run tests/luau/tap_preview_report` after the port.
4. **Passes per race.** Short races (the Sprint has no turn before the lock) complete about one Trip pass. Proposal: count drawn overtakes as the passes the kid sees (the plan says "drawn passes"), or accept 1–10 for the Sprint.
5. **Kid-vs-bot edge.** Riders and bots file differently, which gives a common tau shift that per-post rows can't remove. Fix: a rider entry in the style row (`front, stalker, closer, rider`), calibrated so a passive kid nets 0 among bots. Not yet measured at full size.
6. **D-054 rail-rider target.** Proposal: retire it for D-072, since the skilled-steering edge moves to phase B's move. Smallest alternative: `file.homeLane` 2 for riders, which gives up "riders file to the rail". Logged as a provisional design question.

## To finish (once memory allows)

```
python sims/steering.py --write          # live D-072 baseline (posts + styles), TripBaseline.luau, report
python sims/realism.py --json out.json   # final before/after table (this file)
python tests/fixtures/make_fixtures.py --d057   # trip.json, new trip_d072.json; trip_d057.json defaults only
```
