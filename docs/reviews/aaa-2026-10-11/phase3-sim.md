# Phase 3 item 1: the ladder on realistic Ratings (D-068)

Economy analyst, 2026-10-11. Sim: `python sims/economy.py --ladder phase3` (and `--ladder current`, `--ladder-search`). Tests: `tests/test_sims.py` (ladder section).

## What was simulated

- **Horse.** A starter with every stat at 45 and Potential drawn from 70 to 85 per stat. Each training ride goes to the stat with the most room: K 0.12 × room × (0.5 + 0.5 × score/100) × 1.5 rested, rounded as in `Training.train`, and never more than `WEEKLY_CAP` = 6 a week. Care and bond come from the profile. Race Rating comes from `src/race_rating.py`, using the league's distances, Dirt or Turf, and the server's weather mix. The ceiling check uses `bestRating`, which ignores care and bond.
- **Races.** Solo races against 7 bots rated anchor ± 6 at the league's T, using the D-026 kid score models and the full Harville finish. Points are 10/6/4/2/1, plus +10 for the horse's first win in each league. The Cup opens at the points threshold or when the horse passes the league ceiling. A Cup try pays 3B to the winner and promotes on a win. A regular win pays B/q and places 2 to 4 pay 1.2/0.8/0.4 B. Purses, T and κ are unchanged, and there are no entry fees.
- **Profiles** (one horse each):

| Profile | Week | Training rides | Care | Riding |
| --- | --- | --- | --- | --- |
| casual | 3 sessions × 10 races | 2 (reaches the cap) | half | new kid (60 / 50) |
| casual-average | same | same | half | average kid (70 / 60) |
| casual-perfect | same | same | half | perfect (97 / 95) |
| engaged | 6 sessions × 10 races | 4 | full | average kid |
| engaged-perfect | same | same | full | perfect |
| light | 1 session × 10 races | 2 (reaches the cap) | half | new kid |
| light-average | same | same | half | average kid |

  Ten races fit in one session on one horse's Energy: 5 stored, about 1.5 regained, 2 care top-ups and the Spa.
- **Rating over time** (casual): 47 in week 1, 53 in week 4, 59 in week 8, 65 in week 12, 70 in week 16, 75 in week 26 and about 80 at the plateau. That is about +1.5 a week until room below Potential runs out, which confirms the systems review.

## Before: the live ladder on realistic Ratings

Values: anchors 32/46/56/69/80, Cup points 100/110/750/3000, ceilings 58/68/78/88. "To Cup" counts regular races in that league. "p in" and "p out" are the live win chance over the horse's first and last ten races in the league. Medians are over 200 horses.

| Profile | | Rookie | Bronze | Silver | Gold | Champion reached |
| --- | --- | --- | --- | --- | --- | --- |
| casual | to Cup | 20 | 30 | **231** | **799** | week **36.7** (1,100 races) |
| | p in / out | 22 / 22% | **13** / 14% | **9** / 16% | **8** / 21% | 11% |
| casual-perfect | to Cup | 15 | 21 | 174 | 630 | week 28.5 |
| engaged | to Cup | 18 | 27 | 222 | 854 | week 19.2 |

The review's cliff is confirmed. A casual kid needs 8× more races at Silver than at Bronze, wins 9% of races on entering Silver, and reaches Champion only after about 9 months. The live Gold 3000 opens the Gold Cup only because of the Rating ceiling's drift.

## After: recommended values

These are the final values. The systems consult approved them on condition of the light-player check, which passed (see below).

| GameConfig key | Before | **Recommended** |
| --- | --- | --- |
| `GameConfig.botRatingAnchor` | Rookie 32, Bronze 46, Silver 56, Gold 69, Champion 80 | **Rookie 32, Bronze 35, Silver 38, Gold 48, Champion 56** |
| `GameConfig.stakesUnlockPoints` | Rookie 100, Bronze 110, Silver 750, Gold 3000 | **Rookie 100, Bronze 200, Silver 450, Gold 900** |
| `GameConfig.leagueCeiling` | Rookie 58, Bronze 68, Silver 78, Gold 88 | **Rookie 55, Bronze 57, Silver 60, Gold 66** |
| `GameConfig.kappa` | 1.0 | 1.0 (unchanged; no per-league κ) |
| `GameConfig.botRatingSpread`, `leagues[*].B`, `leagues[*].T`, `cupPurseB`, `firstWinBonus` | | unchanged |

Races to open each Cup ("to Cup" counts regular races in the league; "week" is when the horse reached the league):

| Profile | Rookie | Bronze | Silver | Gold | Champion reached |
| --- | --- | --- | --- | --- | --- |
| **casual** (target 20/40/90/180) | **20** | **41** | **91** | **184** | week **12.0** (353 races) |
| casual-average | 19 | 37 | 85 | 174 | week 11.0 |
| casual-perfect | 15 | 31 | 71 | 148 | week 9.3 |
| engaged | 18 | 37 | 86 | 192 | week 5.8 (349 races) |
| engaged-perfect | 15 | 30 | 72 | 160 | week 4.8 |

Win rates (p in / p out):

| Profile | Rookie | Bronze | Silver | Gold | Champion (entry) |
| --- | --- | --- | --- | --- | --- |
| casual | 21 / 22% | 22 / 24% | 22 / 26% | 19 / 30% | 22% |
| casual-average | 25 / 25% | 25 / 27% | 25 / 29% | 21 / 33% | 24% |
| casual-perfect | 36 / 36% | 36 / 38% | 35 / 39% | 30 / 41% | 31% |
| engaged | 26 / 26% | 26 / 27% | 25 / 28% | 19 / 26% | 17% |

Average kid at each ceiling Rating: Rookie 32%, Bronze 36%, Silver 36%, Gold 36%.

Green Cash per race (purses unchanged):

| Profile | Rookie | Bronze | Silver | Gold | Champion |
| --- | --- | --- | --- | --- | --- |
| casual | 27 | 69 | 170 | 419 | 1,086 |
| casual-perfect | 40 | 104 | 245 | 632 | 1,631 |
| ratio | 1.48× | 1.51× | 1.44× | 1.51× | 1.50× |

How the profiles compare with GAME_DESIGN's targets:

| Target | Result |
| --- | --- |
| Bronze in about 3 h | casual 24 races (about 2 h at 12 races an hour) |
| Silver in about 3 days | engaged day 8 (62 races). A kid playing 20 races a day gets there on day 3, though training is a little behind the races. |
| Gold in about 3 weeks | engaged week 2.7, casual week 5.7 |
| A non-payer reaches Champion | yes: casual week 12, engaged week 6. Diamonds appear nowhere in the model. |

## Light-player check (systems consult)

The systems designer's condition: a kid who trains to the cap but races only about 10 times a week outgrows each league before earning its points, so the ceiling closes their regular races and RACE! becomes CUP!. The values are accepted only if this kid always has a race to enter and wins Cups at 30% or more.

| Light kid, PHASE3 values | Rookie | Bronze | Silver | Gold | Champion |
| --- | --- | --- | --- | --- | --- |
| reached (week / races played) | 0 / 0 | 3 / 24 | 7 / 63 | 10 / 91 | **15 / 141** |
| Rating on arrival | 47.7 | 50.5 | 57.1 | 61.4 | 67.4 |
| regular races before the Cup opens | 20 | 36 | 23 | 48 | – |
| horses whose regular races the ceiling closed | 0% | 16% | 100% | 100% | – |
| over the ceiling on arrival (no regular race at all) | 0% | 0% | 0% | 0% | – |
| Cup win chance, new kid (ceiling-closed horses) | – | 31% | 33% | 34% | – |
| Cup win chance, average kid | – | 35% | 37% | 38% | – |
| Cup tries (median) | 3 | 2 | 2 | 2 | – |

**Result: pass. The values are unchanged.**
- A light horse is never over the ceiling when it arrives in a league. In 200 horses, one light-average horse arrived over the Silver ceiling and went straight to its Cup.
- Every light horse gets 20 to 48 regular races in each league before the Cup.
- In Silver and Gold its Cup opens by the ceiling, not by points. It wins those Cup tries 31 to 34% of the time (new kid), so it needs about 2 tries.
- A light kid reaches Champion in week 15, after 141 races.

The suggested wider gap (Bronze 56, Silver 61) is worse:
- The ceiling closes Bronze races for 51% of light horses instead of 16%.
- Cup chances don't improve: 31%, 34% and 34%.
- So it was not adopted.

**Playtest note (from the consult):** existing saves with horses around Rating 70 in Silver will be over the ceiling twice and run through a series of Cups. Nothing is lost.

## How the search worked (one pass, because the dials interact)

Leagues were tuned in order, because each league's entry Rating depends on how long the horse spent in the leagues below.

1. Take the casual horse's median Rating when it enters the league.
2. Set the bot anchor so an average kid on that horse wins the league's entry target. The target is 25%, except Gold at 22%, which is explained below.
3. Set the ceiling at the Rating where an average kid wins about 36%.
4. Set the Cup points (to the nearest 10) so the casual median hits 20/40/90/180, then round. The raw search gave 100/190/440/870; the rounded values stay within ±5% of the targets.

Rookie keeps the D-061 anchor of 32. `search_ladder()` reproduces the table.

Why Gold enters at 22%: a casual horse spends about 6 weeks in Gold and gains about +9 Rating there, at T = 14.4. Entering at 25% would end the stay at about 40% and run into the ceiling, which would open the Cup at about 120 races instead of 180. Entering at 22% ends near 33%, so points decide the Cup and the ceiling stays the shortcut for trained horses only.

Why the Rookie ceiling drops from 58 to 55: ceilings should rise from league to league. A Rookie horse at 57.5 would otherwise move up straight past the Bronze ceiling of 57. At 55 an average kid wins about 32%. A horse needs about 7 weeks of training without racing to reach it, so the casual route never touches it.

## Recommendations

1. **Tuning:** set the three tables above in `game/src/shared/GameConfig.luau`. These are numbers inside existing keys, with no new mechanic. Update `tests/luau/class_tests.luau:28-30`, which pins Silver 750 and Bronze 110 / Gold 3000, to the new values. `race_button_tests.luau` "anchors rise with the league" still holds (32 < 35 < 38 < 48 < 56), and the `world_tests.luau` ceiling checks (Ratings 50 and 60 in Rookie) still hold at 55.
2. **Tuning:** keep κ at 1.0 with no per-league override. The skill premium is already clear: a perfect rider earns about 1.5× per race in every league and reaches Champion 2.7 weeks sooner. A perfect rider wins 35% of solo Rookie races at κ 1.0, 38% at 1.2 and 41% at 1.4. The gameplay review's target of "P90 ≥ 40%" would need κ ≥ 1.4, which also stretches the new-to-perfect gap. That stays deferred, as CONSENSUS says.
3. **Provisional design decision (for David):** the targets are counted races per league for a casual kid (20/40/90/180), the average kid's entry win rate is 25% (Gold 22%), and an average kid wins about 36% at the ceiling. The Gold entry target and the ceiling cut are design calls, logged here so the scribe can file them under D-068.
4. **Provisional design decision, accepted for now:** Champion has no ceiling and nothing to move up to. A casual horse keeps training after it arrives, and an average kid's Champion win rate at anchor 56 drifts from 25% (Rating 65, week 12) to 34% (70, week 16), 44% (75, week 26) and about 54% (80, plateau). The winner's purse shrinks as q grows (B/q), so cash does not run away, but win rates do. During the feature freeze this is accepted as the endgame reward. A later option is Champion bots rated max(anchor, the rider's Rating − 9), or Legend Retirement and breeding as the Champion goal. Revisit after the playtest. This needs David's review.
5. **Flag (economy):** players now reach the big purses much sooner. By week 12 a casual kid has earned about 106k Green Cash under the new ladder, against about 62k under the old one, while sinks stay flat (stalls total 7,100). Purse flattening (CONSENSUS, deferred) and a Green Cash cosmetics sink are now more urgent. Neither is in this change.
6. **Flag (engaged players lag their training):** a kid who races twice as much per week enters Gold and Champion with a lower Rating, with 19% and 17% entry wins for an average kid. This is tolerable. The systems review's optional `Training.raceGain` (+0.1 stat per counted race, inside the cap) would close the gap. It is a new rule, so it waits for the freeze to lift.

## Diamond check

No route from Diamonds to Green Cash or win chance in this change. Anchors, Cup points and ceilings depend only on League Points, Ratings from training, care and bond, and riding. The Spa's +1 Energy is free. Tack & Paint is cosmetic.

## Model limits

- Kid scores are the same in every league. In the game, faster sweeps in Gold and Champion would lower a kid's scores, and bots' scores, which are fixed, would not drop with them. That could cost a few points of win rate in the top leagues.
- Steering trip τ and crowd boost are left out (both are small and centred).
- Races are solo. Other humans in the queue replace bots and shift win rates either way.
- Training rides always hit the rested bonus and spread across stats.

## Tests

`python -m pytest -q tests/test_sims.py`: 31 passed, 4 xfailed.

- `test_phase3_light_player_never_stuck[Bronze|Silver|Gold]` checks four things for the light kid: at most 1% of horses arrive over the ceiling, at least 15 regular races come before the Cup opens, ceiling-closed Cup tries are won at least 30% of the time, the median is at most 4 tries, and Champion comes by week 20.
- The 19 other new ladder tests run against `economy.PHASE3` and pass now. They cover:
  - casual races to each Cup within ±20%
  - no cliff, and Champion by week 16
  - engaged reaches Gold by week 3.5 and Bronze within 36 races
  - entry win rates in band
  - ceiling win rates 28–37%
  - rising ceilings
  - skill premium of at least 1.33× per race
  - unchanged purses and Rookie anchor
  - mirrors of Training and purse values against the Luau source
  - the old ladder's cliff, reproduced
- `test_game_config_is_one_whole_ladder` passes with either the whole old ladder or the whole new one in GameConfig, never a mix.
- The **PENDING_CONFIG** tests, `test_live_config_casual_races_to_cup[Bronze|Silver|Gold]` and `test_live_config_is_phase3`, read the live GameConfig. They are strict xfails until the recommended values land, and become normal tests after that. When the values land, set `economy.CURRENT` to them, or leave it as the "before" record.
- The D-062 Silver tests are pinned to their own premise (750 points, Silver-entry horse 68, D-061 bots) as history, so the retune doesn't break them.
