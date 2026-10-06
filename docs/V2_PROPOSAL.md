# V2 Proposal — race model for a no-wager game

Date: 2026-10-04. Supersedes the probability adjustment in [SOLUTION.md](SOLUTION.md) for the Roblox game. v1 stays in the repo as history.

**In one line:** keep prices locked before the gates and let the gavel move only probability, but replace the linear two-constraint shift with an exponential tilt, drop the betting margin, rounding, and noise, and measure skill against the race's own average.

## Why v2 exists

The target platform (Roblox) prohibits both simulated and actual gambling, including betting free, unbuyable currency ([Community Standards](https://about.roblox.com/community-standards)). So the game has no stakes: entry is free, and the winner receives a purse locked before the race. Without stakes, several v1 choices stop making sense, and running `src/gavel_race.py` exposed real defects.

## Problems found in v1

| # | Problem | Evidence |
| --- | --- | --- |
| 1 | The odds-weighted constraint (`Σ p'·o = C`) pushes probability onto longshots regardless of how their players did | Repo example: the S = 18 longshot goes 4% → 7.95%, best expected return on the board (+83%) |
| 2 | The linear shift has no floor | 49% of random races (S uniform 1–100, σ 0.65) contain a negative win chance |
| 3 | Added skill noise (σ 0.65) blurs the link between taps and results, and only works in a linear model | Unbiased in v1, but in any positive-only model such as the v2 tilt it shifts average-play chances: favorite 25% → 24.2%, longshot 4% → 4.24%. The race draw already supplies the randomness |
| 4 | Tiered rounding pays favorites less | Expected return 0.875 for the favorite vs. 0.90–0.96 for the rest |
| 5 | Margin and "+EV in 20–30% of races" need a stake | With no stake, margin only scales purses; replaced by a skill-premium target |

## The v2 model

1. **Base win chance** from Race Ratings, floored so no horse is hopeless:
   `q_i = softmax(Rating_i / T)`, floor each `q_i` at 2.5%, renormalize. `T = 10 / ln 2 ≈ 14.4` means 10 rating points doubles a horse's chance.
2. **Locked win purse in whole cash:** `Purse_i = round(B / q_i)`. Since `q_i · B / q_i = B`, every horse expects `B` of win cash at average play, up to rounding: whole-cash rounding moves a horse's expectation by at most `0.5 q_i` cash, a share of `0.5 q_i / B` (worst case about 1% in Rookie, under 0.2% from Silver up). An earlier version rounded to 5 cash and claimed < 0.2%; that bound was wrong for small purses (up to ~4.4% in Rookie), so D-017 switched to whole cash. Place prizes are flat: 2nd 1.2B, 3rd 0.8B, 4th 0.4B.
3. **Gavel window score:** `s = 100 (1 − d)`, `d` = distance from meter center / half-width. Constant-speed (triangle-wave) meter, so a random tap averages 50. `S` = mean of three windows. *Superseded in the game by stride stretches (D-022): each window's score is the mean beat score of a stride stretch; a Final Burst tap after the last stretch counts double, so `S = (stretch₁ + stretch₂ + stretch₃ + 2 · burst) / 5`, still 0–100, and steps 4–6 are unchanged.*
4. **Skill vs. this race:** `R_i = clamp((S_i − mean S) / 50, −0.5, 1)`, mean over all lanes in the race. During the race, use only the windows played so far.
5. **Live win chance (exponential tilt):** `p'_i = q_i · e^{κ R_i} / Σ_j q_j · e^{κ R_j}`, `κ = 1.0`. With the crowd boost (D-020) and race steering (D-054) the exponent becomes `κ R_i + c_i + τ_i`:
   - `c_i ∈ [0, 0.03]` comes from the lane's three best Clap Along fans.
   - `τ_i ∈ [−0.02, +0.04]` is the lane's steering trip: ground saved on turns plus tucked-in draft, minus its post's baseline and the field mean, then minus the lane's own brush charge (D-057: 0.002 per brush it made after the first, at most 0.006; the bumped horse never pays), inside the clamp (`src/trip.py`). It is fixed at the far-turn lock and used from then on; before the lock `τ = 0`, so the trip never depends on luck, and `q` and the locked purses are unchanged.
   - `c_i = τ_i = 0` for every lane gives the formula above (`live_chances(q, R, cfg, extra)` with `extra = c + τ`; `extra=None` is bit-identical to the plain formula).
6. **Finish order:** draw the winner from `p'`, then 2nd from the remaining horses renormalized, and so on (Harville).

### Properties

| Property | v1 | v2 |
| --- | --- | --- |
| Chances stay in [0, 1] | No | Yes |
| Better timing never lowers your own chance | No | Yes (`∂p_i/∂R_i = κ p_i (1 − p_i) > 0`) |
| Equal play returns base chances | On average, if average play is exactly S = 50 | Exact whenever every lane scores the same |
| Prices locked before the race | Yes | Yes (cash purses) |
| Expected cash per race fixed | Exact | Within about 0.2–0.5% |
| Rounding treats horses equally | No | Close: ±`0.5 q / B` (≤ 1% in Rookie, ≤ 0.2% from Silver up) |

**Known edge case (tested):** if your skill is already at the floor and a rival is already capped at R = 1, other riders scoring higher raises the race average, lowers them, and can raise your chance slightly (+0.05 points in the worst case found). Whenever no clamp binds, a rival improving never raises your chance.

### Note on race-average vs. league-average skill

Because the tilt rescales the whole field, adding the same constant to every `R` changes nothing. Centering on the race average therefore gives the same chances as centering on any league median, except at the clamp edges (about 0.2% of probability per race). Race-average centering was chosen because it reads naturally ("beat the field's taps"), needs no league statistic that accounts could manipulate, and limits collusion: tanking riders drag the race average down too.

## Tuning dials

| Dial | Start | Controls |
| --- | --- | --- |
| `T` | Rookie 22, Bronze–Silver 18, Gold 14.4, Champion 12 | How often upsets happen overall |
| `κ` | 1.0 (range 1.0–1.2) | Who earns upsets: how much timing moves win chance |
| `q` floor | 2.5% | Smallest win chance; biggest purse ≈ 40B |
| `R` floor | −0.5 | How much one bad race can hurt |
| `B` | Rookie 20 → Champion 750 | Expected win cash per entry; the race faucet |
| `α` (reserve) | 1.0 | `Purse ∝ q^(−α)`; α < 1 lets favorites expect more win cash |

## Results

Reproduce with `python src/gavel_race_v2.py` (about 5 seconds; `--races` and `--seed` adjust it). Figures move by a point or so between seeds.

**Skill premium** (expected win cash vs. B, equal horses, field S ~ N(50, 15)):

| Percentile (S) | κ 0.6 | κ 0.8 | κ 1.0 | κ 1.2 |
| --- | --- | --- | --- | --- |
| P99 (85) | +41% | +56% | +73% | +90% |
| P90 (69) | +20% | +28% | +35% | +42% |
| P75 (60) | +10% | +13% | +15% | +18% |
| P50 (50) | −1% | −2% | −3% | −4% |
| P25 (40) | −11% | −15% | −19% | −23% |
| P10 (31) | −19% | −25% | −31% | −37% |

**Upsets** (κ = 1.0, ratings 70 down to 52):

| T | Favorite's base chance | Bottom-half horse wins | Longest shot wins |
| --- | --- | --- | --- |
| 14.4 | 21.5% | ~35% | ~6.3% |
| 18 | 19.5% | ~37% | ~7.2% |
| 22 | 18.1% | ~40% | ~8% |

`κ` barely changes total upsets when skill is random across horses; it decides who gets them. A longshot whose rider scores 80 goes 6.2% → 8.5% (κ 0.6), 10.4% (κ 1.0), 12.5% (κ 1.4).

**Strength still pays:** expected cash per entry at average play (win + place, in B) runs 1.46 for a 25% favorite down to 1.13 for a 4% longshot, entirely from place prizes.

## Integrity rules

- Party members never share a cash race. One perfect rider with seven friends scoring 0 goes 12.5% → 33.3% (×2.66); Friend Races pay XP only.
- The server owns meter seeds and timing; flag S above 95 sustained over 20+ races.
- A dropped window scores that window's race average, at most once per race.
- Cash races fill to 8 lanes with bots drawn from the league's recent score distribution.
- The live chance shown on screen is the exact `p'` used in the draw.

## Files

- `src/gavel_race_v2.py` — Python reference and simulations (stdlib only).
- `src/RaceMath.luau` — Roblox server module, same six steps.
- `src/trip.py` — steering trip τ for step 5 (D-054); `sims/steering.py` generates the per-post baseline (`game/src/shared/TripBaseline.luau`) and the calibration report.
- `src/gavel_race.py` — v1, unchanged.
