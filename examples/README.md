# Examples

Run the reference model from the repo root:

```bash
python src/gavel_race.py
```

That prints:

1. Win odds locked from base `q` with 7% overround and tiered rounding.
2. One skill field `S = [88, 72, 60, 50, 42, 35, 28, 18]` at `gamma = 0.80`, with win EV against those locked odds, and a check that `sum p' * o` still equals `C`.
3. All 28 quinella pairs: base probability and locked price, then live probability and EV after the gavel.

To probe the 20–30% +EV rate, draw `epsilon ~ Normal(0, 0.65)`, set `R = skill + epsilon`, and call `adjust_win_probs`. Count how often `p'[0] * o[0] > 1` for a high-S horse.
