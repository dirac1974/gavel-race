# Simulations

## steering.py — race steering baseline and calibration (D-054, D-057)

```bash
python sims/steering.py                  # acceptance report against the checked-in baseline (~3 min, all cores)
python sims/steering.py --write          # regenerate tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau first
python sims/steering.py --set groundPerLaneTurn=0.011 --races 500 --report-races 300   # try a tuning change (nothing written)
python sims/steering.py --profile d057 --write   # D-057 on: trip_baseline_d057.json + steering_report_d057.json (game files untouched)
```

Regenerate with `--write` after any change to `src/trip.py`, `trip.CONFIG` (the mirror of `GameConfig.steering`) or the course geometry; `tests/test_trip.py` fails while the baseline is stale. `--profile d057` runs the same pipeline with natural steering switched on (`trip.d057_config()`) and adds the D-057 measures (zig-zag, sideways motion, body yaw, boxed in, brushes, reach per intent, griefing, overlap stress); `tests/test_trip_d057.py` asserts its stored report. Results and tuning history: `docs/research/steering-calibration.md`.

## economy.py — progression pace and Green Cash per hour

```bash
python sims/economy.py                       # current thresholds (D-013)
python sims/economy.py --thresholds 100,100,100,100 --days 40
```

Results with D-013 thresholds (100, 110, 1,400, 3,000 League Points; 100 players per cohort, 90 days, seed 1). "Hours" = hours of play at 12 races per hour:

| Cohort | Races/day | Bronze | Silver | Gold | Champion |
| --- | --- | --- | --- | --- | --- |
| Casual (avg score 42) | 6 | day 6.8 (3.4 h) | day 15 (7.5 h) | after day 90 | after day 90 |
| Regular (50) | 12 | day 3.2 (3.2 h) | day 6.9 (6.9 h) | day 44 (44 h) | after day 90 |
| Engaged (55) | 25 | day 1.4 (2.9 h) | day 3.1 (6.5 h) | day 20 (42 h) | day 56 (116 h) |
| Skilled (70) | 25 | day 1.2 (2.6 h) | day 2.6 (5.4 h) | day 17 (36 h) | day 48 (99 h) |

With the original flat 100-point thresholds, an engaged player reached Gold on day 4.6 and Champion on day 6, far ahead of the 3-week Gold target.

Green Cash per hour of play roughly doubles to triples each league (engaged: Rookie ~330, Bronze ~800, Silver ~1,900, Gold ~4,800, Champion ~12,500), so sink prices must scale the same way.

**Not modeled yet:** Energy limits, training and Rating growth, sinks, Diamonds. Matching assumes base chance 1/8 in every race.
