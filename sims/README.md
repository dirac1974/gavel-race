# Simulations

## steering.py — race steering baseline and calibration (D-054, D-057)

```bash
python sims/steering.py                  # acceptance report against the checked-in baseline (~3 min, all cores)
python sims/steering.py --write          # regenerate tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau first
python sims/steering.py --set groundPerLaneTurn=0.011 --races 500 --report-races 300   # try a tuning change (nothing written)
python sims/steering.py --profile d057 --write   # D-057 in full (the live config since N5): trip_baseline_d057.json + steering_report_d057.json
python sims/steering.py --profile d054 --write   # D-054, the switch-back: trip_baseline_d054.json + steering_report_d054.json
```

Regenerate with `--write` after any change to `src/trip.py`, `trip.CONFIG` (the mirror of `GameConfig.steering`) or the course geometry; the tests fail while a baseline is stale. The default profile, `live`, is `trip.CONFIG`: since N3, D-057's motion and press rules, and since N5 the brushes; only it writes `TripBaseline.luau`. `--profile d057` is D-057 in full (`trip.d057_config()`, the same config since N5, so the same numbers), and `--profile d054` is the D-054 switch-back (`trip.d054_config()`). With any D-057 switch on the report adds the D-057 measures (zig-zag, sideways motion, body yaw, boxed in, brushes, reach per intent, griefing, overlap stress). The griefing test runs Smart Steer, rail, wanderer, masher and press-again (`doubletap`) kids: own trip is gated for the Smart Steer and rail kids, and the brush charges strangers add for every kid but the masher (N5 review). `tests/test_trip_d057.py` asserts the live and d057 reports, `tests/test_trip.py` the d054 one. Results and tuning history: `docs/research/steering-calibration.md`.

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
