# Life arc sims: ageing, selling, the vet run (2026-10-12)

Reference: `src/life_arc.py` (Luau mirror `game/src/shared/Ageing.luau`, config `GameConfig.ageing` / `GameConfig.sell`). Sims: `python sims/lifearc.py --ageing|--sell|--legs [--players N]`. They are single-process and use small samples; ± values are 95% CIs over horses. Ladder: `economy.career` on the D-068 values (PHASE3, B 20/30/45/65/85).

Profiles:
- **casual**: 3 sessions of 10 races a week, new rider (`casual`).
- **average**: the same schedule with an average rider (`casual-average`).
- **keen**: 6 sessions of 10 races a week, average rider, full care, 4 rides a week (`engaged`).

## 1. Ageing (`--ageing`, 80 horses per cell, 1,500 counted races each)

Rules: Veteran at 350. −1 Rating per 50 races, so the first step comes at 400 and the cap of −4 at 550. Rated races only. Young training ×1.25 for 30 races.

The three variants are paired on one RNG stream: off, young (the boost only), and decline (`declineScale` 1).

**League arrival, median counted races (week).** Identical between young and decline in every league. The Youngster boost moves nothing, because the weekly cap of 6 already binds.

| | Bronze | Silver | Gold | Champion |
|---|---|---|---|---|
| casual | 24 (1.0) | 69 (2.3) | 166 (5.7) | 354 (12.0) |
| average | 23 (1.0) | 64 (2.3) | 152 (5.3) | 326 (11.0) |
| keen | 22 (0.5) | 64 (1.2) | 154 (2.7) | 346 (5.8) |

**Champion live win chance, off → decline:**

| races | casual | average | keen |
|---|---|---|---|
| 350–400 | 23.7 → 23.7 | 27.7 → 27.7 | 18.6 → 18.6 |
| 400–450 | 26.5 → 24.9 | 30.9 → 29.2 | 20.0 → 18.7 |
| 550–650 (cap) | 35.0 → 27.9 | 40.3 → 32.7 | 26.7 → 20.8 |
| 650–900 | 40.4 → 32.8 | 46.2 → 38.2 | 34.4 → 27.4 |
| **1,200–1,500 (plateau)** | **49.2 → 41.0** | **55.2 → 47.1** | **55.5 → 47.3** |

The CIs are ±0.2 to ±1.0 points.

**Gates:**
- **No change before 350: pass.** Decline and young give identical paths before 350.
- **Plateau between 30% and 50%: pass.** The average kid goes from 55.2% to 47.1%, which fixes the stomp. That is milder than the systems designer's 38–45%, because −4 at T 12 multiplies the base chance by 0.72.
- **League floor: pass by construction.** Leagues has no demotion and no entry floor, and decline never touches bestRating or ceilings. The lowest raced Champion Rating with decline is 53.8 (keen), against bots at 56 ± 6.

**Caveat.** Kids aren't Champion-strong yet when decline starts:
- Ageing counts races, but growth is limited per week. So during 400–900 races, keen and new-rider Veterans sit below 30% **even without decline** (keen 20–34%).
- Decline deepens this by up to 7 points.
- Cells where decline pushes a horse from ≥ 30% to below it: casual 500–650, keen 650–900, and average 400–450 (29.2%).
- `declinePer` 100 only helps casual (31.0% at 550–650).
- The smallest real fix is a follow-up option: count decline steps only once stats reach about 90% of Potential.

**Decision: `declineScale` 1 (provisional, needs logging), plateau reading.**

**Cash per race at Champion:** −2% to +3% (inside the CIs). The win purse B/q rises as q falls, so the expected win cash stays at about B.

**Who sees decline:**
- The first step comes at 400 races on one horse: casual about week 13, keen about week 7, a light kid (10 races a week) about week 40.
- The research doc puts D7 at 18–28%. That suggests, as an estimate, that well under 10% of players ever see a step, mostly keen ones.

## 2. Selling (`--sell`, 60 kids per profile)

Rules: the kid buys a Market horse (real stock distribution) once race cash covers it, races it N races from Rookie, then sells it. That is compared with racing the owned horse for the same N races.

- Prices: min 270, p10 340, median 605. The formula's floor is 250.
- The mean surplus is −400 to −2,000 at every cap up to 300, because the owned horse races in higher leagues.
- The share of kids whose **sale beats the price paid** is 0% up to cap 125, then 2% at 150 and 22–52% at 200–300 (N ≥ 100).

**Cap: `sell.recordBonusCap` = 100.**
- Half of 250, plus 100, is 225, which is less than 250. So a sale can never return more than the price, and buy → race → sell always nets less than the race cash alone.
- A test asserts that the cap stays below 125.
- The bonus reaches 100 by about 25 races with one Cup.

## 3. The vet run (`--legs`, 300 kids × 8 weeks)

The model includes:
- Energy: 5, plus 1 per 20 min; feed or groom +1 each per 2 h; Spa +1 per day.
- Care at the session start, training rides, kids heeding the chip, and waiting or quitting when out of Energy.
- Free Rookie races.

| kid | vets per session | Rookie phase | after Rookie | 20+ race sessions | races/hour |
|---|---|---|---|---|---|
| casual (8.2 races) | 0.07 | 0.40 | 0.02 | – | −0.35% |
| average (10.4) | 0.18 | 0.53 | 0.16 | 0.89 | −0.53% |
| keen (16.2) | 0.38 | 0.93 | 0.36 | 0.73 | −0.59% |

Races/hour counts only the rule's own time (the chip care and the 30 s check). Cash per hour moves the same way, since cash per race doesn't change.

**Target check:**
- **Keen:** about once per long session (0.73).
- **Casual:** rarely after Rookie, but 0.40 per session in races 11–26, because free Rookie races have no Energy top-ups to lower the run.
- Out-of-Energy feeds and grooms (−2) are what keep the counter low in cash leagues.

**Sensitivity:**

| setting | change |
|---|---|
| `fromRaces` 26 | casual Rookie phase 0.40 → 0.00 |
| `fromRaces` 20 | 0.18 |
| care −1 | keen long sessions 0.86 |
| `runLimit` 5 | casual 0.47 per session after Rookie (too often) |
| `runLimit` 7 | keen 0.22 |

**Recommendation:**
- Keep 6 and −2.
- Consider `fromRaces` 20–26 if new kids shouldn't meet the vet in their second session.
- Feed and groom should lower the run only once per kind per cooldown, or grooming can be spammed to dodge the vet.

## Rulings (systems, 2026-10-12)

**1. Decline waits for the horse's peak: CHANGE.**
- **The rule:** a decline step counts only after **both** of these hold: the horse has ≥ `ageing.veteranAt` (350) counted races, **and** its stats have reached **`ageing.peakShare = 0.90`** of Potential (the mean of `stat / Potential` over the four stats).
- **Counting from:** `h.ageing.declineFrom`, the race count when both first hold. Store it, and never un-set it.
- **Steps:** `declinePer` 50 and `declineCap` 4 count from `declineFrom`.
- **Card:** at the peak it says "💪 Comet is at his best!". The 10-race warning comes before the first step.
- **Why it's fair:** decline arrives only when training can no longer improve the horse, which is real ageing. Long-time players (plateau horses) still see all of it.
- **Re-run gate (`--ageing`):**
  - no cell where decline alone drops the average kid from ≥ 30% to < 30%;
  - plateau 30–50%;
  - no change before 350 races.
- **No exploit:** skipping training to dodge decline costs far more Rating than decline does.

**2. `legs.fromRaces = 26`.** It's the simmed value: no vet in the Rookie phase, so a new kid's first two sessions are vet-free.

**3. One "Veteran".**
- `career.veteranAt` changes from 100 to **350**, the same as `ageing.veteranAt`. D-059 is amended. The two keys must stay equal; add a test.
- Stages: Young (0–29) · Prime (30–349) · Veteran (350+) · Legend (opt-in from Veteran, `retireNeedsVeteran` true).
- Career patches every 25 races stay "patches".
- The Veteran toast fires once, at 350.
- Existing saves:
  - Legends stay Legends;
  - horses at 100–349 races show Prime, and nothing is taken away. This applies only to saves from the build where Veteran started at 100.

**4. Anti-spam.** Feed −2 and groom −2 count once per kind per horse per `energy.careCooldownSeconds` (2 h). That's the same cooldown as the Energy top-up, so there's one rhythm for kids. Care itself is already once a day.
- Key: `legs.careCooldownSeconds = energy.careCooldownSeconds`.

**5. Accepted, with conditions:**
- `sell.recordBonusCap = 100`: **ACCEPT.** The test asserting the cap stays below 125 stays.
- `declineScale = 1`: **ACCEPT, provisional,** once ruling 1 is built and its re-run passes. Log it in REVIEW_QUEUE as "decided by David (real decline)", with the numbers.

## Re-run after the rulings (2026-10-12)

The rulings above are built in `src/life_arc.py` and `Ageing.luau`, with parity covered by `tests/fixtures/ageing.json`:
- `peakShare` 0.90 and the stored `declineFrom`;
- `legs.fromRaces` 26;
- `legs.careCooldownSeconds` 7,200;
- `career.veteranAt` 350, kept equal to `ageing.veteranAt` by a test;
- cap 100;
- `declineScale` 1.

**`--ageing`** (80 horses per cell, 1,500 races each):

| | declineFrom (median) | first step (about) | worst window, off → decline | plateau 1,200–1,500, off → decline |
|---|---|---|---|---|
| casual | 630 | week 23 | 650–900: 40.4 → 36.1 | 49.2 → 41.0 |
| average | 640 | week 23 | 650–900: 46.2 → 42.0 | 55.2 → 47.1 |
| keen | 1,020 | week 18 | 900–1,200: 46.9 → 44.6 | 55.5 → 47.7 |

**Gates:**
- **Decline alone never takes a cell from ≥ 30% to below 30%: pass.** No window, in any profile.
- **Plateau between 30% and 50%: pass.**
- **No change before 350: pass.** Decline never acts before `declineFrom`.

`declineScale` stays 1. Cash per race moves −1% to +3%.

**Share who see decline:** the first step comes at about week 18–23, so very few players will see it (an estimate: fewer than the 10% given before).

**`--legs`** (300 kids × 8 weeks; feed and groom count once per kind per 2 h):

| kid | vets per session | in the Rookie phase | in 20+ race sessions | own time cost |
|---|---|---|---|---|
| casual | 0.03 | 0.01 | – | −0.20% |
| average | 0.20 | 0.00 | 0.72 | −0.36% |
| keen | 0.64 | 0.01 | **1.09** | −0.49% |

Both targets are met: keen kids about once per long session, casual kids rarely.
