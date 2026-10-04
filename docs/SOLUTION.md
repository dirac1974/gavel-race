# Solution

> **Superseded for the game build by [V2_PROPOSAL.md](V2_PROPOSAL.md) (2026-10-04).** This file documents v1, the wagering design, and is kept for history.

All payout multipliers below are **locked before the race**. The gavel never rewrites them.

## 1. Lock win odds

Base probabilities `q_i` with `sum q_i = 1`.

```
r_i = q_i * 1.07
o_raw_i = 1 / r_i
o_i = round_tier(o_raw_i)
```

Tiered round:

- if `o_raw >= 5`: nearest integer
- else if `o_raw > 2`: nearest 0.5
- else: nearest 0.2

Pre-race win EV if probabilities stay at `q`:

```
WinEV_i = q_i * o_i
```

Equal-stake book constant (1 unit on every horse, total stake 8):

```
C = sum_i q_i * o_i
```

House retains `8 - C` in expectation on that book. This `C` is what the gavel adjustment must preserve.

## 2. Gavel adjustment (probabilities only)

Performance `S_i` in 1..100.

Deterministic skill:

```
skill_i = (S_i - 50) / 50
```

Optional realized skill (for the 20–30% +EV target):

```
R_i = skill_i + epsilon_i
epsilon_i ~ Normal(0, 0.65)
```

Desired shift, proportional to relative skill and to base win probability:

```
desired_i = gamma * R_i * q_i
```

`gamma = 0.80` is the scale aimed at occasional +EV. `gamma = 0.35` was the first illustrative value and rarely cleared 100% EV.

Final shift:

```
delta_i = desired_i + a + b * o_i
```

Solve `a`, `b` from the 2x2 system so that:

```
sum delta_i = 0
sum delta_i * o_i = 0
```

Explicit solution (`n = 8`):

```
sum_d  = sum desired_i
sum_do = sum desired_i * o_i
sum_o  = sum o_i
sum_oo = sum o_i^2
det = n * sum_oo - sum_o^2

a = (sum_oo * (-sum_d) - sum_o * (-sum_do)) / det
b = (n * (-sum_do) - sum_o * (-sum_d)) / det
```

Adjusted win probability and EV against **locked** odds:

```
p'_i = q_i + delta_i
WinEV_i = p'_i * o_i
```

Because both constraints hold:

```
sum p'_i = 1
sum p'_i * o_i = C
```

So if 1 unit is bet on each horse, expected total payout is still `C` after every gavel result. Posted odds did not move. Underperformers (negative skill) supply the negative desired term; the affine term in odds-space stops a pure skill transfer from changing the house’s odds-weighted liability.

## 3. Lock quinella odds (either order)

Computed from **base** `q`, then frozen.

```
q_ij = q_i * q_j / (1 - q_i) + q_j * q_i / (1 - q_j)
r_ij = q_ij * 1.07
o_ij = round_tier(1 / r_ij)
```

These 28 pair prices do not change when the race starts.

## 4. Quinella probability after the gavel

Use adjusted win probabilities, same either-order formula:

```
q'_ij = p'_i * p'_j / (1 - p'_i) + p'_j * p'_i / (1 - p'_j)
QuinellaEV_ij = q'_ij * o_ij
```

`o_ij` is the locked price. Quinella EV can move with skill. The win-book constraint does not make every quinella’s expected payout invariant for arbitrary stakes. Overall quinella margin stays near the 7% overround when skill is moderate; it is not a second exact invariant.

## 5. Why +EV can appear without moving odds

`WinEV_i = p'_i * o_i`. Odds `o_i` are constant. Raising `p'_i` above `q_i` raises that horse’s EV. The constraints force other horses’ EV down by the same odds-weighted amount. A high `S` horse can clear EV 1.0. With `gamma = 0.80` and `sigma = 0.65` on realized skill, that happens on the best horse’s win (and on some pairs that include it) in roughly 20–30% of realizations, not on every race.

Average `S = 50` has `desired = 0`. It still receives `a + b * o_i` if the field is unbalanced.

## 6. Example field

`q = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04]`

Locked win odds depend on `round_tier` applied to `1 / (q_i * 1.07)`. See `src/gavel_race.py` for the numbers this field produces.
