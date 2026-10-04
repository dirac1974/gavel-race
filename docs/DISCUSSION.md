# Discussion log

Condensed from the design session. Later rules override earlier ones where they conflict.

## Request 1 — win model

Build an 8-horse model. Fair odds are each horse’s random chance to win. House edge 7%. Odds adjusted and originally rounded **down** to the nearest 0.2, shown as fifths or halves. During the race a player boosts by hitting a meter in the green zone. Performance gain is taken proportionately from underperforming participants so total house expected return stays the same, and the take depends on that player’s win probability relative to others. Give each player a score 1–100, slide the scale, show EV. Average performer stays at the expected win probability.

Response: proportional overround `r_i = q_i * 1.07`, odds `1/r_i`, floor to 0.2. Skill `(S-50)/50`. Desired delta `gamma * skill * q` with `gamma = 0.35`. Affine correction in `{1, o}` so sum of deltas and sum of delta times odds are both zero. Scenarios: all 50s; favorite boosted; longshot ace vs choking favorite; sliding scale 85 down to 15; two boosters vs two chokers. Equal-stake payout constant held at about 7.362 for that rounded board (1 unit on each of 8 horses).

## Request 2 — quinella

Exacta payout for 1st and 2nd in either order, using the same per-horse skill adjustments. New rounding: above 2:1 nearest 0.5, under 2:1 nearest 1/5, 5:1 or higher nearest whole number.

Response: either-order probability

```
q_ij = p_i * p_j / (1 - p_i) + p_j * p_i / (1 - p_j)
```

7% overround, then the new tiered round. Full 28-pair table produced for the average field. Pair probabilities sum to 1.

## Request 3 — scale skill for +EV

Scale skill difference so players can have expected value over 100% about 20–30% of the time. Examples for winning the race as well, with the formulas.

Response: raise `gamma` toward 0.80. Add realized-skill noise. Show win EVs crossing 1.0 for high `S`, and a 1-2 quinella crossing 1.0. Frequency target met by noise around skill, not by rewriting odds.

## Request 4 — odds frozen, edge kept

In both win and quinella, payout odds cannot change once the race begins, but the house edge must be maintained.

Response: odds locked from base `q` before the gates. Gavel only edits `p'`. Win edge maintained exactly by the two constraints. Quinella prices locked from base pair probabilities; post-gavel quinella EV uses new `p'` against those frozen prices. Quinella margin is approximate.

## Request 5 — repo

Create a GitHub repo and include memory documents summarizing the concept, discussion, and solution.
