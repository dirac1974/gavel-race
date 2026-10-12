# Breeding sims (D-080): results

`python sims/breeding.py --all --lines 300 --players 80 --races 150` (seed 1, single process, about 3 minutes). The model is `src/breeding.py`, mirrored by `game/src/shared/Breeding.luau`. Gates are from plan §7, plus the gameplay vote's Rookie gate and the systems rulings' pure-line gate. ± values are 95% confidence intervals.

**Result (re-run after the systems rulings below): all gates pass.**

## Config now (changes from the plan)

| Key | Plan | Now | Why |
| --- | --- | --- | --- |
| `breeding.foalEveryRaces` (replaces `parentRestRaces`) | rest 20 per parent | **60, stable-wide, from confirm** | Systems rulings 1–2. At 20 per parent, a kid who breeds whenever they can spends 50–74% of their cash after Bronze on fees, and three or more Bronze-or-higher horses could rotate pairs. One foal per 60 owner races closes both. The card reads "Next foal in N races". |
| `breeding.parentShare` | 0.70 | **0.75** | Systems ruling 3. |
| `breeding.breedAnchor` | 75 | **80.5** (ruling: 80) | **Flag.** At 80, the pure top-tier line is 82.8 at gen 10, missing the new ≥ 83 gate. A sweep (300 lines per cell): 80.5 gives 83.2 pure and 91.7 greedy; 81 gives 83.7 and 91.9 (too close to 92); share 0.77 with anchor 80 gives 83.05 (marginal). 80.5 is the smallest change that passes both. The reversible alternative is to keep 80 and relax the pure gate to 82.5. |
| `breeding.surprise` | 8 coats | **12 coats** | Systems ruling 4: buckskin → dun or palomino, dun → buckskin, roan → grey, white → grey. A parent's own coat is never a Surprise option. If nothing is left (only pinto + appaloosa), the 10% goes back to the parents (50/50). |
| `breeding.startMax` | — | **50** | Gameplay vote. |
| `breeding.enabled` | true | **false** | The roblox engineer flips it together with `career.suggest`. |

## Gates

| Gate | Value | Result |
| --- | --- | --- |
| Pure top-tier line (best two of 3 foals): gen-10 mean Potential per stat ≥ 83 (new) | 83.2 ±0.2 | PASS |
| … the same line ≤ 92, and gen 8 → 9 change ≤ +0.5 | 83.2; −0.19 | PASS |
| With a Legend parent every generation: ≤ 92, and gen 8 → 9 | 85.1 (Legend stat 91); −0.13 | PASS |
| Greedy stable (always breed the two best of 20): ≤ 92, and gen 8 → 9 | 91.7; +0.23 | PASS |
| No stat above 100 | max 100 (clamped) | PASS |
| Foal sd about 3–4 (one pair: the noise) | 2.92 (population pairs 4.85) | PASS |
| Top 1% ≤ 98 (two top-tier Legend parents) | 96 | PASS |
| Champion arrival of a gen-3 foal ≥ 85% of a starter's (casual / average / keen) | 86% / 89% / 89% | PASS |
| Rookie (average kid): a gen-3 foal gets ≥ 15 regular races | median 16 (p10 14) | PASS |
| Rookie (average kid): a gen-3 foal's win chance is 20–30% | 29.6% ±0.3% | PASS |
| Power: a gen-10 Legend line's Champion win chance ≤ top tier + 5 pts | 75.9% vs 79.5% | PASS |
| Power: the greedy-stable best's win chance ≤ top tier + 5 pts | 82.3% vs 79.5% | PASS |
| Fees are 10–25% of the cash created after Bronze, breeding after shopping (casual / average / keen) | 22.9% / 20.9% / 24.5% | PASS |
| Barn Builder median wait ≤ 2 sessions (breeding after shopping; breeding first) | 2, 1, 1; 2, 2, 2 | PASS |
| Keen kid's week-12 pile falls ≥ 30% | 24,696 → 7,202 (−71%) | PASS |
| First foal: casual ≤ week 5, average ≤ week 4, keen ≤ week 2 | week 3.3 / 3.3 / 1.5 | PASS |
| No profit: sell value < fee (any record) | 300 < 400, 500 < 800, 850 < 1,500, 1,350 < 2,500 | PASS |

**Info rows (reported, not gated):**
- Breeding before shopping, the stress row:
  - fee share 27.0% (casual), 24.9% (average), 26.0% (keen).
- Greedy-stable best rated above the Market top tier's p90 Rating: **44%**.
  - It was 12% before the rulings.
  - Its win chance is +2.8 pts, inside the 5-pt gate.
  - This is the price of a stronger anchor. A kid who breeds 40 foals and keeps the best now owns a horse a little above a top-tier buy.

## Findings

1. **Pure lines now hold above Market middle, and greedy stays under 92.**
   - From top-tier founders: the pure line holds 83.2 (85.1 with a Legend). The ruling expected 84–86 at an anchor of 80; this run gives 82.8 at 80.
   - Greedy selection reaches 91.7 and is still rising about +0.2 a generation at gen 10 (91.6 at gen 12 at an anchor of 80).
   - **Watch:** both gates are close to their edges.
2. **The ladder replay is tighter but holds.** The gen-3 foal now has Potential 86 (82 before the rulings).
   - Casual Champion arrival is 86% of a starter's, against an 85% gate.
   - Its Rookie win chance is 29.6% (gate 20–30%), and the p10 kid gets 14 Rookie races.
   - **Lever:** if a playtest finds bred foals rush Rookie, lower `startMax` (50 → 48).
3. **Cash:** these numbers are unchanged. The sim's kid has a single parent pair, so 60 per stable is the same as 60 per parent here. The first foal, the fee share and the pile are as before.
4. **No profit:** a bred foal sells for half its fee plus at most 100, which is always less than the fee.

## Model notes (in `src/breeding.py`, mirrored in Luau)

- **One foal per `foalEveryRaces` owner races, for the whole stable.** `p.breeding.nextAt` is set at confirm. The block reads "Next foal in N races" ("1 race" when one is left). Horses no longer show a per-horse "Resting" reason.
- **Two Legends with the same best stat** give +2 once. Ties pick the first stat in speed, accel, stamina, grit order.
- **The roll happens once, at confirm.**
  - Potential, start stats and coat are stored on `p.breeding.pending`.
  - A second confirm is refused while a foal is on the way or the stable is waiting.
  - `arrive` only reads the stored foal back.
- **The rng draws, in order:** 4 uniforms (one per stat), then 1 for the coat. Rounding is floor(x + 0.5).

## Rulings (systems, 2026-10-12)

**1. Rest: one stable-wide rule, fees unchanged.**
- **Replace per-parent rest with `breeding.foalEveryRaces = 60`:** one foal per 60 of the owner's counted races, whatever the parents. Count from confirm.
- **Delete `parentRestRaces`.** With the stable-wide rule, a per-parent rest adds nothing but copy.
- **Fees stay 400 / 800 / 1,500 / 2,500.** Cheaper, more frequent foals would turn the coat chance into a farm. A foal is a milestone, not a loop.
- **Card:** "Next foal in N races". No clock.
- At about 1 foal a week (keen) or every 2 weeks (casual), the fee-share gate holds as simmed.

**2. Rotating pairs:** closed by ruling 1. The limit is per owner, so 3+ horses gain nothing. Add a Lune and pytest test: two different pairs back to back are refused until 60 owner races have passed.

**3. Pure lines falling to about 77: CHANGE.**
- **Why:** a top-tier pair's foals averaging about 84, with lines sliding to a starter's level, makes Legend lines pointless next to buying. A gentle pull to the middle is right; pulling to the starter level isn't.
- **New values:** `breeding.parentShare` 0.70 → **0.75** and `breeding.breedAnchor` 75 → **80** (amends D-047).
- **Expected:** a pure top-tier line holds about 84–86 (about 86 with a Legend every generation), and greedy selection holds about 89–91.
- **Re-run gates:** the existing gates still hold:
  - greedy gen-10 ≤ 92 and no rise past gen 8 (≤ +0.5);
  - the greedy best within +5 pts of the top tier's win chance;
  - Rookie win rate 20–30%;
  - Champion arrival ≥ 85% of a starter's.

  Add a new gate: **a pure line from top-tier founders at gen 10 ≥ 83**.
- If greedy goes past 92, use anchor 78 instead.

**4. Wild coats get Surprise families.** These are existing coats only, so the collection grows and the chances are shown:

| Coat | Surprise |
| --- | --- |
| buckskin | dun or palomino |
| dun | buckskin |
| roan | grey |
| white | grey |

Fallback to the parents only when the union is empty.

**Applied (model engineer, 2026-10-12):**
- Rulings 1, 2 and 4: as written.
- Ruling 3: `parentShare` 0.75, and `breedAnchor` **80.5** rather than 80, to pass the new ≥ 83 gate (see the table above).
