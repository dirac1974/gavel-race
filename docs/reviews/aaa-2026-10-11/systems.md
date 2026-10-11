# Systems and progression review (2026-10-11)

Independent review of the core loop, meta loop, economy and system cohesion, from code and docs only (the game has never run in Studio). I ran `sims/economy.py` and its helpers with the horse Ratings the code can actually produce.

## 1. Verdict

The engineering is careful, and the safety rules are kept everywhere I looked. The progression spine still breaks. The Silver and Gold targets assume horses arrive with Ratings that the training cap makes impossible for months, so a casual kid hits a wall of about 250 Silver races and then about 1,000 or more Gold races. Green Cash stops meaning anything by Silver because faucets grow 37x while sinks stay flat. Friends in different leagues can never race each other. On top of an untested core, eight meta stages have added about 40 interlocking systems, and several of them reuse the same few nouns. Stop adding. Fix the spine, open racing to friends, and playtest the core with most of the meta switched off.

## 2. Top problems, ranked by player impact

### P1. The league ladder is tuned to horses that don't exist (Size M, no asset)

- **Evidence:** `sims/economy.py:68` sets `LEAGUE_ENTRY` to Bronze 58, Silver 68 and Gold 78. `Training.luau:23` sets `WEEKLY_CAP = 6` stat points per horse per week, across all four stats, which is about +1.5 Rating a week. A starter is 45 (`Horse.luau` `STARTER_STAT`) and reaches Bronze after about 21 races. It enters Silver at roughly 48–55, not 68.
- **My sim runs** (`races_to_cup` and `solo_win_rate`, new kid, realistic Ratings):

  | League | Races to open the Cup |
  | --- | --- |
  | Bronze at 47 | 31 |
  | Silver at 50–55 | 238–279 |
  | Gold at 58–65 | 1,096–1,397 |

- Champion is unreachable for non-payers, which contradicts GAME_DESIGN's "Gold ~3 weeks; non-payers can reach Champion".
- `stakesUnlockPoints.Gold = 3000` (`GameConfig.luau:285`) was never re-simmed after D-062.
- Starter Potential is 70–85, so a starter can never use the Silver ceiling (78) shortcut.
- `tests/test_sims.py` locks in the false premise.
- **Why it hurts:** the per-league cost jumps from about 25 races to about 250, a 10x cliff, right when Stable Star goals and the Horse Book run out (P4). That is the D30 quit point. Promotion itself also feels like a punishment. A fresh horse wins about 24% of Rookie races but about 13% at Bronze entry (Bronze 47: 12.6% for a new kid), and Energy starts to cost.
- **Fix:**
  1. In `economy.py`, replace the fixed `LEAGUE_ENTRY` with a Rating that follows from weeks played under `WEEKLY_CAP`, plus care and bond.
  2. Set a target curve for a casual kid: about 20, 40, 90 and 180 races for Rookie through Gold.
  3. Tune `stakesUnlockPoints` (roughly Bronze 150, Silver 400, Gold 900; the sim decides) and lower `botRatingAnchor` Silver, Gold and Champion to realistic entry Ratings.
  4. Optional: add `Training.raceGain` so a counted race gives +0.1 stat inside the weekly cap. Then "Races still help!" (`Training.luau:81`) becomes true, which today it barely is (+1 bond = +0.02 Rating).
  5. Update the test bands to match.

### P2. Green Cash is worthless by Silver (Size S plus M, no new asset for the S part)

- **Evidence:** purses `B` run 20, 50, 120, 300, 750 (`GameConfig.luau:455-466`). The sim gives a casual kid about 280/h in Rookie, 1,650/h in Silver and 4,100/h in Gold. The sinks are flat:
  - stalls total 7,100 (`Market.luau:19`)
  - hay costs 2 and grain 5 (`Care.luau:203`)
  - market horses cost about 250–2,500
  - Tack & Paint takes Diamonds only (`Style.luau`)
- **Why it hurts:** within about two weeks nothing is left to buy. Job cash rewards, chores, selling crops and the garden-to-food loop become empty checkboxes, and "Earn Green Cash → Upgrade" drops out of the core loop.
- **Fix (S):** flatten `GameConfig.leagues[*].B`, for example to 20, 35, 50, 70 and 100 (Python parity follows from config), so cash keeps its value.
- **Fix (M):** add a Green Cash tier to `Style`: a `currency = "cash"` field on the yard, paint and plate items, priced 500–5,000, using the existing models. Diamond-only premium variants stay.
- Do **not** add entry fees. They read as stakes (rule 1).

### P3. Friends can't race together (Size S/M, no asset)

- **Evidence:**
  - `Leagues.canEnter` (`Leagues.luau:96`) refuses another league's card *before* it checks Practice.
  - `RaceQueues.key` (`RaceQueues.luau:31`) keys Practice by league.
  - With 5 leagues × 3 kinds = 15 queues on 2 courses and a 20-player server, almost every field is 1 kid and 7 bots.
  - No friend or party rule exists in `RaceService` (D-006 is unbuilt).
- **Why it hurts:** Roblox kids arrive with friends. "Tap it. Shout it." with your friend is the pitch, but after the first Cup it never happens.
- **Fix:**
  1. Add `GameConfig.queue.openPractice = true`.
  2. In `canEnter`, return true for `card.practice` before the league check.
  3. Key Practice as `RaceQueues.key("Open", "practice")`. Practice pays nothing, so mixed Ratings are harmless.
  4. Add a "Race with [friend]" button on the Friends' barns list that joins the friend's Practice line.

### P4. Too many systems, and the same nouns mean different things (Size S, no asset)

- **Evidence: about 40 systems built, none of them played.** They include the Next-thing pill, jobs in 3 tiers with rerolls, monthly cloths, a Diamond gift, 18 Stable Star goals, the Rosette Wall, a Horse Book with 7 pages, Tour stamps and bests, Welcome Back, Photo Finish, career badges, Veteran, Legend, Rehome with undo, visits, Spa, the Passport, 4 training courses with weekly layouts, ghosts and Ride Together, steering with brushes, and Clap Along.
- `Progress.record` (`Progress.luau:23-29`) feeds the same events into two goal systems, Jobs and StableStar, and a third (HorseBook) counts many of them again.
- **Words used for several things**, against D-064's "one symbol per meaning":
  - **stamps:** 🎀 monthly stamps, Health Passport stamps, Tour stamps
  - **rosettes:** training golds, Stable Star goals, first wins, goodbye rosettes, the Horse Book "Rosettes" page of race places
  - **badges:** league, class and 🎖️ career badges
  - **ribbons:** training ribbons and the prize ribbon colours
- Stable Star's 18 goals and the Horse Book are finite and done in about 2–3 weeks, just before the P1 wall.
- The phone dock hides all of this behind ☰ More.
- Steering (D-057, `Trip.luau`, 1,391 lines) is worth about 2 points of a 100-point ride.
- **Fix:**
  1. Freeze new systems until the playtest data is in.
  2. For the first playtest, switch the meta off with the flags that already exist: `spa.enabled`, `visit.enabled`, `career.enabled`, `rehome.enabled`, `comeback.photo` and `comeback.horseBook`. Measure the GAME_DESIGN Phase 1 gate ("can say how their taps changed the result") and D1 on the core alone.
  3. Rename so each noun has one meaning:
     - **Rosette:** only what hangs on the Wall.
     - **Medal:** training golds.
     - **Sticker:** Passport stickers.
     - **Pin:** friend pins (today's Tour stamps).
     - **Stamp:** the 🎀 monthly stamps only.
     - **Badge:** league badges only. The class label is a "tag", and the 25-race award is a "career star", if ★ allows it; otherwise "career patch".
  4. Make Stable Star repeatable: after the last goal of a kind, add tiers ×2 and ×4 in `StableStar.GOALS` (config data only).

### P5. Legend Retirement is irreversible, suggested too early, and gives nothing (Size S, no asset)

- **Evidence:**
  - `Career.suggestLegend` fires at 100 races (`GameConfig.career.veteranAt`). With realistic pacing that is in the middle of the Silver grind.
  - `Leagues.retire` (`Leagues.luau:138`) sets `h.legend` permanently, and nothing clears it.
  - The starter *can* become a Legend (only Rehome blocks the starter).
  - `legacyMax` is unused until breeding exists.
- **Why it hurts:** two taps and the horse a kid bonded with never races again. That gives the kid nothing and can't be undone, while Rehome, the lesser act, has a 72 h undo.
- **Fix:**
  1. Add `Leagues.unretire(p, id)` and a "Back to the races" button. The horse keeps its league and points, and the plaque stays.
  2. Add `career.suggest = false` until breeding ships, or suggest only from Gold upward or at the horse's Potential cap.

### P6. The Next-thing pill sells chores, not the race (Size S, no asset)

- **Evidence:** `Advice.nextThing` (`Advice.luau:94-118`) orders its suggestions claim → feed → groom → Cup → daily job → train → race.
- **Why it hurts:** every session opens on chores, though the pitch is "come back for the horse, stay for the race".
- **Fix:** after the first feed of the day, put "Race with Comet" ahead of the daily jobs and training. Make the order a config list, `nextThing.order`.

### P7. Energy rarely limits a casual kid, and the Spa is a whole system for +1 (Size S, no asset)

- **Evidence:** a horse has 5 Energy, regains 3 an hour, gets +2 from care and +1 from the Spa, about 11 cash races in a one-hour session. The casual cohort plays 6 races a day. Rookie is free. The cap mainly hits engaged kids and pushes them off their favourite horse.
- **Fix:** leave the Energy numbers alone and build nothing more on Energy. Fold the Spa into the Vet visit as one "Check-up & Spa" card, so there is one vet loop instead of two.

## 3. What is genuinely good, and must not be broken

- **Hard-rule discipline is real, not decoration:** no streaks, a flat Welcome Back gift (`WelcomeBack.luau:356`), no countdowns, jobs never ask for a win, auto-claim at rollover, and the Practice fallback instead of a purchase when a horse naps.
- **Every value lives in config with a switch-back.** That is exactly what makes the fixes above cheap.
- **The sim-first culture works.** The D-061 gate caught bad bot anchors. It needs better inputs (P1), not less use.
- **D-033's skill-then-luck race shape:** purses B/q keep strength from snowballing cash, and comebacks show on screen.
- **No ageing, no decline, care only ever adds a bonus**, and Rehome pays 50% of the price paid with an undo. These are the right kid-safe forms of "age" and "sell".
- **Per-league queues** fixed a real lockout.
- **Pure, Lune-tested modules** with server authority, everywhere.

## 4. Top 5 must-do, in order

1. **Rebuild the progression sim on realistic Ratings and retune the ladder** (P1, M). Model Rating from the training cap, set the per-league race targets, and retune `stakesUnlockPoints` and `botRatingAnchor` (optionally `Training.raceGain`). Update `tests/test_sims.py`.
2. **Open Practice to every league and add "Race with a friend"** (P3, S/M). Add `queue.openPractice`, change the `canEnter` order and use an "Open" Practice queue key.
3. **Give Green Cash value again** (P2). Flatten `leagues[*].B` (S), then add Green Cash decor in `Style` (M).
4. **Freeze features and playtest the core with the meta off** (P4, S). Use the existing `enabled` flags, measure the Phase 1 gate and D1, then rename the overloaded nouns.
5. **Make Legend reversible and stop the early suggestion** (P5, S). Add `Leagues.unretire` and `career.suggest = false` until breeding exists.
