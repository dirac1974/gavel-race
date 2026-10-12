# Green Cash sink: Barn Builder sim (D-070)

Economy analyst, 2026-10-11.
- **Sim:** `python sims/economy.py --greencash` (16 weeks, 100 kids per profile). `--purses 20,30,45,60,80` tries other B values.
- **Tests:** `tests/test_sims.py`, Green Cash section.
- **Catalog and final prices:** `greencash-plan.md` → "Final prices (sim)".

## What was simulated

**Cash in.** Each kid runs the D-068 ladder career (`economy.career`, PHASE3 values) for 16 weeks:
- **Real race cash at the new B.** A win pays B/q, places 2–4 pay 1.2/0.8/0.4 B, and a Cup win pays 3B. League Points, ceilings and training work as in `phase3-sim.md`.
- **Jobs:** +15 a session.
- **Feed and seeds:** −12 a session with half care, −25 with full care, at `Care.SHOP` prices.
- **Start:** 50 cash.
- **Ledger:** the career records race cash per session. A ledger run never stops early at Champion.

**Cash out: Barn Builder.**
- The catalog has 39 items: 35 cosmetics totalling 45,300, plus the four stalls (7,100). Each stall is placed on the shelf of the league where a kid would want it.
- A shelf opens at the highest league reached.
- **"Wish" kid (default):** wishes for the cheapest unowned item on the newest open shelf. When the wish becomes affordable, the kid builds it at the end of that session, then moves to the next wish. The kid never spends below a 50-cash feed reserve.
- **"Saver" kid:** same rules, but opens Barn Builder only once every 4 weeks.

**Profiles** (from `economy.PROFILES`, one horse each):
- casual: 3 sessions × 10 races a week, new-kid riding
- casual-perfect: the same schedule, perfect riding
- engaged: 6 sessions × 10 races, average riding
- engaged-perfect: 6 sessions × 10 races, perfect riding
- light: 1 session × 10 races

**Measures:**
- **wait:** for every session spent in a league, the number of sessions until the next build, counting the current one. A build at the end of this session counts as 1. The median is taken over sessions and kids.
- **1st item:** the session in which the kid builds its first item from that league's shelf.
- **pile:** the week-12 balance divided by the price of the next unowned item ("all owned" means nothing is left to buy).
- **at Champion:** the same ratio on the session the horse reaches Champion.

## Purses

Final B is **20 / 30 / 45 / 65 / 85**, Cup 3B. For comparison, the plan proposed 20/30/45/60/80, and the values before D-070 were 20/50/120/300/750.

| B (Rookie → Champion) | Casual wait, Rookie/Bronze/Silver/Gold (sessions) | Casual pile at w12 | Casual balance at w12 |
| --- | --- | --- | --- |
| 20/50/120/300/750 (before) | 1 / 1 / 1 / **10** | **all owned** | **61,391** |
| 20/30/45/60/80 (plan) | 1 / 1 / 1 / 2 (at the limit for all seeds) | 0.46–0.54 | 1,330 |
| **20/30/45/65/85 (chosen)** | 1 / 1 / 1 / 1 | 0.42–0.50 | 1,294 |
| 20/35/50/70/90 | 1 / 1 / 1 / 1 | 0.49 | 1,109 |
| 20/25/40/55/75 | 1 / 1 / 2 / 2 | 0.54 | 1,475 |

- **Why the final values:**
  - The plan's Gold B worked, but its median Gold wait sat exactly on the 2-session limit at every seed.
  - Gold is the shelf with the 1,800–3,500 items and the 2,000 stall. Gold 65 / Champion 85 brings the median to 1 and keeps p75 at 2.
  - Rookie, Bronze and Silver stay at the plan's values.
- **Ladder unchanged.** B sets purses only, so `--ladder phase3` is unchanged: casual Champion in week 12.0 and engaged Gold in week 2.7. The D-068 tests pass.

## Results (final B, 100 kids, seed 1)

| Profile | Wait R/B/S/G | 1st item R/B/S/G/C (session) | Cash per race R/B/S/G/C | Balance w4/w8/w12/w16 | Pile at w12 (p90) | At Champion (p90) | Feed always OK |
| --- | --- | --- | --- | --- | --- | --- | --- |
| casual | 1/1/1/1 | 1/3/8/18/38 | 26/39/61/89/121 | 622 / 1,332 / 1,294 / 2,473 | 0.42 (0.86) | 0.35 (0.49) | yes |
| casual, saver | 12/8/5/6 | –/48/12/24/36 | same | 816 / 1,931 / 1,472 / 884 | 0.44 (0.89) | 0.68 (**3.36**) | yes |
| casual-perfect | 1/1/1/1 | 1/2/6/13/30 | 44/59/89/134/177 | 739 / 272 / 2,523 / 13,998 | 0.48 (0.93) | 0.46 (0.80) | yes |
| engaged | 1/1/1/1 | 1/3/7/16/38 | 30/46/68/101/133 | 1,821 / 2,543 / **24,864** / 57,260 | **all owned** | 0.33 (0.54) | yes |
| engaged-perfect | 1/1/1/1 | 1/2/6/14/30 | 41/60/90/139/175 | 319 / 14,624 / **57,091** / 96,746 | **all owned** | 0.55 (0.92) | yes |
| light | 1/1/1/2 | 1/3/7/11/– | 25/40/59/91/119 | 265 / 516 / 1,039 / 2,000 | 0.52 (0.95) | 0.52 (0.73) | yes |

**Cash created and destroyed** (median per week over 16 weeks):

| Profile | Created | Destroyed | Net |
| --- | --- | --- | --- |
| casual | 2,606 | 2,398 | +208 |
| casual-perfect | 4,183 | 3,311 | +872 |
| engaged | 7,001 | 3,425 | +3,576, all of it after the catalog runs out |
| light | 705 | 568 | +137 |

## Against the targets

| Target | Result |
| --- | --- |
| Next item affordable within 2 sessions, every league up to Gold | **Pass.** The median wait is 1 for casual and engaged, and 1–2 for light. Test: `test_greencash_next_item_within_two_sessions` (casual, light, engaged). |
| A fresh Rookie builds within 1–2 sessions | **Pass.** First item in session 1. |
| Week-12 balance ≤ 2× the next item's price | **Pass** for casual, casual-perfect and light (median 0.42–0.52, p90 under 1). **Fails after Champion for engaged kids**, who own everything by about week 9–10 (see the flags below). |
| No pile before Champion | **Pass** for every profile: 0.33–0.55× on arrival at Champion (p90 ≤ 0.92). |
| Saver | Report only. It holds up to about 3.4× the next price (p90) when it reaches Champion, because it shops only every 4 weeks. It never runs short of feed. |
| Feed and seeds always affordable | **Pass** for every profile, saver included. A 50 reserve covers the most a session's feed costs (25). |
| Skill (gameplay): a perfect rider reaches each shelf's first item no later than a casual kid, and sooner on ≥ 3 of 5 shelves | **Pass, 4 of 5** (Rookie ties at session 1): 1/2/6/13/30 against 1/3/8/18/38. |
| Skill premium ≈ 1.5× per race | **Pass:** 1.69 / 1.51 / 1.46 / 1.51 / 1.46, mean about 1.53. Every league is ≥ 1.33. |

## Diamond to Green Cash or win-chance routes

**None found.**
- Diamond packs (`DiamondProducts.luau`) buy only Tack & Paint cosmetics.
- Style returns refund the currency that was paid. Barn Builder must keep this (Lune test in the plan).
- Diamonds never refill Energy (GAME_DESIGN, Energy).
- No Diamond item touches feed, seeds, Energy, Training or Market.

**Watch items:**
- GAME_DESIGN still lists "time skips" among Diamond uses. Any time skip that lets a horse race, train or regain Energy sooner turns Diamonds into races, which means Green Cash and League Points. It must stay off Energy, Training and the race queue.
- If a garden or planter is ever sold for 💎, its crops must not be sellable through `Care.SELL`.

## Recommendations

1. **Tuning (landed).**
   - B is 20/30/45/65/85 in `GameConfig.leagues`, `LEAGUE_B` (`src/gavel_race_v2.py` and `sims/economy.py`), the B row of `V2_PROPOSAL.md` and the league table in `GAME_DESIGN.md`.
   - The parity fixtures are untouched. Appending to `make_fixtures.py`'s B list would change every later RNG draw, which means a regeneration, so it was skipped.
2. **Provisional design decision: the catalog price list** in `greencash-plan.md` → "Final prices (sim)".
   - It applies the feel vote: yard variants only, a re-themed hay loft, fair-material Gold and a code-built weathervane. Tier totals stay at the plan's 45k.
   - This goes to the D-070 entry for David's review.
3. **Open, for David: engaged kids pile up after Champion.**
   - Engaged and engaged-perfect kids own all 39 items about 4 weeks after reaching Champion. By week 12 they hold about 25k and 57k, and by week 16 about 57k and 97k.
   - B can't fix this without breaking casual Gold.
   - The plan's goal is "no pile *before* Champion", which holds.
   - Options are:
     - (a) accept it, since Champion is the end of the ladder and Market horses, foals and more horses are real sinks this one-horse sim leaves out;
     - (b) a later Champion shelf that grows by milestone (never timed or "limited");
     - (c) lower Champion B, which barely helps (−5 B is about −6%).
   - Recommendation: (a) for launch, then re-check with a multi-horse sim.
4. **Note on numbering.** GameConfig's tap-preview block (`GameConfig.luau` ~357) is labelled D-070, but the consensus numbers the tap gap D-071 and Green Cash D-070. The scribe should fix the comment.
