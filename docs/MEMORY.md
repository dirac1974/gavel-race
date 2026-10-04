# Memory — Gavel Race

Durable summary of the concept, discussion, and solution. Written so a later session can resume without the original chat.

Date of design session: 2026-07-16. Repo created 2026-10-03.

## Concept

An 8-horse race game. Each horse has fair win probability `q_i` (sum 1). The house posts win odds with a 7% edge, then rounds them. During the race a player may boost their horse by hitting a moving meter while it is in the green zone (the gavel). The boost is not free probability: it is taken from underperforming horses so the house’s expected return on the locked odds stays the same.

An average performer (`S = 50`) always performs at the expected (base) win probability, aside from small ripples caused by other players’ skill.

## Hard rules (final)

1. Payout odds for win and quinella are computed before the race and **cannot change once the race begins**.
2. The house edge must still be maintained after gavel results.
3. Quinella means 1st and 2nd in **either order** (unordered pair).
4. Rounding for posted odds:
   - 5:1 or higher: nearest whole number
   - greater than 2:1 and under 5:1: nearest 0.5
   - 2:1 or under: nearest 1/5 (0.2)
5. Skill should be scaled so a strong player can have expected value over 100% about 20–30% of the time, without moving the posted odds.

Earlier in the session, win odds were specified as rounded **down** to the nearest 0.2 and shown as fifths or halves. The later rounding rule above supersedes that for both win and quinella.

## Solution in one paragraph

Lock decimal odds `o_i` from `q_i` with a 7% overround and the tiered round. Map performance `S_i` to skill `(S_i - 50) / 50`. Desired probability shift is `gamma * skill_i * q_i`. Add an affine correction `a + b * o_i` solved so the sum of shifts is 0 and the sum of shifts times locked odds is 0. Then `p'_i = q_i + delta_i` and win EV is `p'_i * o_i` with `o_i` unchanged. Quinella probabilities are the either-order top-two formula on `p'`, but quinella **payouts** stay at the values computed from base `q` before the race. With `gamma = 0.80` and realized-skill noise `sigma ≈ 0.65`, a high-S horse’s win bet is +EV in roughly a quarter of realizations.

## Decisions

- Equal-stake book on the eight win bets is the invariant: if 1 unit is bet on each horse, expected total payout stays at the pre-race constant `C = sum(q_i * o_i)`.
- Underperformers are horses with skill below 0. Mass is taken in proportion to `q_i` (relative win probability) plus the odds-space correction, which accounts for different payout liabilities.
- Quinella house edge is approximate, not a second exact invariant. Exact win-book invariance is required; quinella odds are locked from base probabilities so they cannot move mid-race.
- `gamma = 0.35` was the first illustrative scale (almost all bets stayed −EV). `gamma = 0.80` is the scale aimed at the 20–30% +EV target.
- Example base field: `q = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04]`.

## Open / not built

- Live race simulation (positions, multiple gavel windows, meter physics).
- Bet-distribution-independent house edge (fixed-odds edge depends on where money lands; the invariant assumes balanced action or is the odds-weighted moment).
- Ordered exacta (specific 1st then 2nd) was discussed and deferred; product is either-order.
- Jurisdiction / gaming-license framing was not part of this design.

## v2 — no-wager game model (2026-10-04)

The model is being used for a kid-friendly Roblox horse racing game. Roblox prohibits simulated and actual gambling, including betting free currency, so the game has no stakes: entry is free and the winner receives a purse locked before the race. v2 replaces the v1 probability adjustment; v1 stays as history. Full detail: [V2_PROPOSAL.md](V2_PROPOSAL.md).

### Why v1 was changed

- The `Σ p'·o = C` constraint rewarded longshots regardless of play (repo example: S = 18 horse 4% → 7.95%).
- The linear shift went negative in about 49% of random races.
- Skill noise blurred the gavel, and it only averages out in a linear model.
- Tiered rounding paid favorites less (expected return 0.875 vs. 0.90–0.96).
- Margin and the "+EV 20–30%" target require a stake.

### v2 decisions

1. Base chance `q = softmax(Rating / T)`, floored at 2.5%; `T` by league (Rookie 22 … Champion 12).
2. Win purse `5 · round(B / 5q)`: every horse expects `B` at average play. No margin, no tiered rounding.
3. Window score `100 (1 − d)`, constant-speed meter; `S` = mean of 3 windows.
4. Skill measured against **this race's average**: `R = clamp((S − mean S) / 50, −0.5, 1)`. Same chances as a league median (the tilt is shift-invariant) except at clamp edges; chosen for clarity, no gameable statistic, and lower collusion gain.
5. Exponential tilt `p' ∝ q · e^{κR}`, `κ = 1.0`. Always positive; better timing never lowers your own chance.
6. Finish order by sequential draw (Harville). Flat place prizes 2nd 1.2B, 3rd 0.8B, 4th 0.4B.
7. Quinella dropped (a pair prediction for a payout is a bet).
8. `T` controls how often upsets happen; `κ` controls who earns them.
9. Exact per-race cash invariance traded for ~0.2–0.5% drift, absorbed by `B`.
10. Party members never share a cash race.

### Open

- Set `κ` and `T` from playtests.
- Reserve dial `α` (`Purse ∝ q^(−α)`) if training needs to pay more win cash.
