# Systems and economy proposal: fun and return (2026-10-12)

Owner: systems designer. David's five directions are **decided by David**; this delivers them kid-safely.

- Every value lives in config and every switch can be turned off.
- Gates come from `sims/economy.py`.
- **★ = my top 8 for this evening.**

## Design spine

One loop answers ageing, selling and the endgame together: **climb → peak → Legend or sell → next horse**.

Today the D-068 ladder has two holes:
1. **The Champion stomp.** At the Champion plateau, an average kid wins about 54% of races.
2. **The post-Champion cash pile.** Engaged kids hold about 25k by week 12.

Ageing that starts at about the casual Champion arrival fixes both, and makes buying and raising the next horse the retention engine and the cash sink.

## 1. Ageing and life stages (counted in races, never days)

**Stages:** `GameConfig.age`. Races are counted (Practice excluded) per horse. A horse never ages while you're away.

| Stage | Races | Effect | Chip |
| --- | --- | --- | --- |
| Youngster | 0–29 | Training gain ×1.25 (`age.youngTrainBoost`) | 🌱 "Growing" |
| Prime | 30–349 | none | ⭐ is banned (★ = riding), so 💪 "Prime" |
| Veteran | 350+ | Gentle decline (below) | 🎖️ "Veteran" |
| Legend | opt-in from Veteran | stops racing, stays yours (D-059) | 👑 |

- **The boundary is deliberate.** 350 is about where a casual kid arrives in Champion (`--ladder phase3`: 353 races at week 12). The decline therefore lands on the endgame, not on the climb.
- `career.veteranAt` changes from 100 to 350. The 25-race career patches stay.

**Decline** (`age.declinePer = 1` Rating per `age.declineEvery = 25` races from 350, `age.declineFloor = −6` at 500):
- It applies only to the **race Rating**, through `Horse.rating`'s `ageOffset`. It never touches stats, `bestRating`, ceilings or Cups. There's no demotion, and League Points are unchanged.
- **Size:** at Champion T = 12, −1 Rating multiplies the base chance by 0.92, and the floor of −6 multiplies it by 0.61. That takes an average kid's plateau win rate from about 54% to about 38%, which fixes the stomp.
- **Practice is untouched.** Open Practice equalises horses.
- **Warned 10 races ahead:** "Comet is getting wise. Soon a little slower." The card shows the stage path from day 1.
- **Switch:** `age.declineScale` 0 or 1. Ship at 0 and set it to 1 only when the `--ageing` gates pass.

**End of a career:**
- **Legend** (D-059): `career.suggest = true` again, once at 350 races. Its benefit arrives with breeding (D-047): a Legend passes +2 Potential to one foal (`career.legacyMax`). Until breeding ships, Legend gives the plaque, the paddock and riding.
- **Rehome** (D-059, 50% of the price paid, 72 h undo): keep it as "Lend or Rehome".
  - **★ "Lend to Sunny Meadow"** is new. It's free, and the horse comes back any time with no time limit. It frees a stall (S).
- **★ "Sell" (NPC only, S):** this is Rehome with a record bonus. Player trading stays out (policy, scams).
  - Price = 50% of the price paid + min(`sell.perWin` 5 × wins in counted races + `sell.perCup` 100 × Cups, `sell.bonusCap` 600).
  - Only from 25 races (`sell.minRaces`).
  - The starter never sells; tamed horses get the bonus only.
  - This faucet is bounded: at most 600 per horse, and only after 25+ races. Sim gate: ≤ 3% of the Green Cash a casual kid creates.
- **Stable cap:** keep `Market.MAX_HORSES = 20`, with Legends counted in it, and 6 stalls. When the stable is full, the kid chooses Lend, Sell or Legend. It never deletes anything.

**Economy effect.** A new horse costs 250–2,500 (Market) plus stalls, and starts in Rookie (B 20). That drains the post-Champion pile and replays the early ladder, with every Barn Builder shelf already open. Sim gate: the engaged pile at week 12 falls by ≥ 50% with one next-horse purchase per Veteran.

## 2. ★ Over-running → "Tired legs" → free vet check (M)

**Trigger:** `GameConfig.legs`. A per-horse workload counts **every counted race, Rookie included** (Rookie costs no Energy, so new kids need this).
- Each counted race adds 1 (`legs.perRace`). Practice adds 0, so Practice always stays open.
- Workload drains 1 every 40 min (`legs.recoverSeconds = 2400`), offline too.
- At `legs.vetAt = 8` the horse shows **"Vet check time"**. Cash and rated races wait until a vet check. Practice stays open, and so do riding and care.
- **Warned** at 7: "Comet's legs are working hard. Next: a vet check."
- **Never in a horse's first 10 career races** (`legs.fromRaces`), so the first session isn't interrupted.

**Energy interplay:**
- Energy limits cash races from Bronze; legs limit every rated race.
- A casual session (10 races) meets the vet about once. Light kids mostly never do.
- Rotating horses avoids it. Legs are per horse, so this rewards a second horse, which feeds the next-horse loop.

**The vet check:** free, about 30 s, tap-only. Cold hose → leg wraps → carrot.
- It resets workload to `legs.afterVet = 2`, not 0, so the vet is a pit stop and not a reset button.
- It gives no Energy, no bond and no Rating.
- The horse wears cosmetic wraps in its next race.
- It reuses Spa's steps and art (`spa_wash_stall`), so it costs 0 Meshy.
- Spa (+1 Energy) stays as is and moves into the same Vet card.

**Never:**
- a limp, wound, blood, pain sound or Rating loss;
- a paid cure, or Diamonds;
- the words hurt, injury, sick, sore or limp (copy test);
- blaming copy. Use "Comet ran his heart out! Vet check time".

**Anti-exploit:** the vet gives nothing, so there's nothing to farm. Alt accounts gain nothing. Workload is saved per horse, so rejoining can't clear it.

## 3. Classes and qualification

**★ Rename the labels to the real ladder (S).** Within each league, using D-062's class logic:
- **Maiden** (no win in this league);
- **Allowance** (1–2 wins);
- **Open** (3+);
- **Cup** (Cup open).

**Graded prestige races (M–L, after tonight):**
- **Who can enter:**
  - **Listed** from Bronze: ≥ 3 wins in the league and ≥ 6 top-3 finishes;
  - **G3** from Silver;
  - **G2** from Gold;
  - **G1 "Giddy-Up Derby"** in Champion: ≥ 5 league wins.
- **No new queue.** A league line's next card becomes Graded (`graded.every = 4` races of that league) when ≥ 1 qualified rider is in line. Non-qualified riders in that line go on the other course or the next card. Always returning, no clock, no "last chance".
- **Purses within D-070:** win pays 2 × B for Listed, G3 and G2, and 3 × B for G1. Places are as usual. League Points are as usual.
- **Sim gate:** casual cash per race +≤ 3%. Barn Builder waits are unchanged.
- **Titles:** "G3 winner" on the horse card, a plaque on the Rosette Wall and a Horse Book page. Never sold, never 💎, no public ranking.

## 4. ★ Queues made legible (S)

**Keep three lines and add no merge:** League race, Cup, Open Practice. Graded rides the league line.
- Merging Cup into the race line would mix prizes.
- The 15 s bot fill already caps every wait at about one race plus 15 s.

**What changes is the explanation:**
- The queue card names the line: "🏁 Bronze races line · 2 waiting · bots join at 0".
- A 3-picture "how racing works" strip: join → line fills → bots fill at 0.
- The picker shows every line with its count, and why yours is yours ("Comet is Bronze").
- League Points finally get a UI: "🏆 Cup in 140 points" on the horse card ★. They're invisible today.

## 5. Economy sim plan (`sims/economy.py`, M)

| Flag | What it does | Gates |
| --- | --- | --- |
| `--ageing` | Ladder with stages and decline | Casual Champion week 12 ± 0.5; Gold-stay win rate drop ≤ 1 pt; Champion plateau, average kid ≤ 40%; Veteran week by profile, reported |
| `--legs` | Workload per session | Casual ≤ 1 vet a session; engaged ≤ 3 per 2 h; light: ≥ 80% of sessions with no vet; Practice never blocked |
| `--multi 2,3` | Horse rotation with Energy, legs, next-horse buys | Barn Builder wait ≤ 2 sessions; pile ≤ 2× at week 12; engaged post-Champion pile −50% |
| `--sell` | Record bonus | ≤ 3% of cash created; no buy-race-sell profit loop (sell ≤ buy for < 100 races) |
| `--graded` | Graded cards | Cash per race +≤ 3%; first G3 for casual by about week 8; every Graded field has a human |

Also re-run `--solo`, `--ladder phase3` and `--greencash`, and keep them unchanged within their bands.

## Risks

- **Decline reads as punishment.** Mitigations: the 10-race warning, the stage path shown from day 1, decline only after Champion, and a floor of −6. If kids feel cheated, keep `declineScale = 0`.
- **Vet stops feel like nagging.** Tune `vetAt` from playtest data. Practice is always open.
- **Graded splits fields.** It rides the league line, and bots fill.
- **Maturity rating.** No realistic injury is depicted: wraps and a hose only. Confirm on the questionnaire.

## ★ Tonight (top 8)

1. Queue legibility strip plus named lines (S).
2. League Points and life-stage chips on the horse card (S).
3. Tired legs → free vet check, `legs.*` (M).
4. Life stages shown, Youngster training boost on, decline at `declineScale = 0` (S).
5. Maiden / Allowance / Open labels (S).
6. Sell with a capped record bonus, plus Lend to Sunny Meadow (S).
7. Sims `--ageing` and `--legs` (M). Turn decline on only if they pass.
8. Map tiles for Market, Feed & Seed / Barn Builder, Training and Tack & Paint (S).
