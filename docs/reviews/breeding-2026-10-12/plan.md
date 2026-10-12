# Breeding plan (D-080 provisional, amends D-047)

Owner: systems designer, 2026-10-12. David: "Build the breeding now."

- Builds on D-047, D-078 (life arc, Legends, Riding School), D-063 (Horse Book), D-064 (symbols) and D-070 (Green Cash).
- Every value lives in `GameConfig.breeding`. `enabled = false` hides all of it.

**Honest framing.** This is the genre's proven collection engine, and the right next system. It is also the one most likely to drift into a gacha loop: Green Cash buys a random coat. The rules below keep it a raising game, not a slot machine:
- chances shown up front;
- cooldowns measured in races;
- one foal at a time;
- every coat also obtainable without breeding.

## 1. Who can breed

**Parents:** two of *your own* horses. No genders this build; they're "parents".
- Simpler copy, and it doesn't double the horses a kid needs.
- It is a realism trade-off. Flagged for David as a playtest question.

| Rule | Value (`breeding.*`) |
| --- | --- |
| Stage | Each parent is **Prime, Veteran or Legend**: at least `minParentRaces` 30 counted races. A Young horse never breeds. |
| League | At least one parent has reached **Bronze or higher** (`needLeague = "Bronze"`, by the horse's league; a Legend counts by its plaque league). |
| Legends | Can be parents. This is their second life, and it brings the legacy (§2). D-078's `career.suggest` turns **on** when breeding is enabled: the Legend card can now say "Legends can be parents!" |
| Excluded | Lent horses, horses waiting at the Riding School (sold, undo window), and a horse racing, queued, riding or training (`Leagues.retireBlock`). |
| Rest | After a foal, each parent rests for **`parentRestRaces` 20 of the owner's counted races** (any horse). The card shows "Can be a parent again in 20 races": no clock, ever. |
| One at a time | `maxWaiting` 1 foal on the way per stable. |
| Room | The stable cap of 20 (Legends included) must have a free place; otherwise "Make room first", with Lend and Sell offered. |

## 2. The math (`shared/Breeding.luau`, mirrored in `src/breeding.py`)

**Potential, per stat:**

```
P_foal = clamp( round( 0.7 × (P_a + P_b)/2 + 0.3 × anchor + U(−noise, +noise) ) + legacy, potMin, potMax )
anchor = breeding.breedAnchor = 75   (starter mean 77.5, market middle tier)
noise  = 5     potMin = 55   potMax = 100
```

- **Legacy:** if a parent is a Legend, add +`career.legacyMax` (2) to that Legend's highest-Potential stat. With two Legends, +2 to each one's best stat, never +4 on one stat.
- **Level-off:** under selection, the equilibrium is P* = 75 + Δsel / 0.3 (+ about 6.7 on the legacy stat). Picking the best of each generation (Δsel ≈ 4–5) settles near **88–92**, which is about the Market's top tier (82–95). The 0.3 anchor guarantees bloodlines can't climb without limit. The sim confirms (§7).

**Starting stats: `startShare` = 0.60** of each stat's Potential (D-047 said 0.35, so this **amends D-047**).
- At 0.35 a 75-Potential foal starts at 26 against Rookie bots at 32.
- Under the weekly training cap of 6, it would need about 13 weeks just to match a starter (45). That's a retention killer.
- At 0.60 it starts at 45, equal to a starter. A 90-Potential foal starts at 54.
- The Young training ×1.25 applies as for any horse.
- The edge from good breeding is *room to grow*, not a head start.

**Potential stays hidden** until the vet's Potential stamp (D-039). The parent card shows the family-line sprouts 🌱–🌱🌱🌱 (D-064) for the *expected* foal, never numbers.

## 3. Coat genetics (collection)

**Tonight: the 12 existing coats only.** Foal coat chances, shown on the card before paying:
- **Parent A's coat 45%**, **parent B's coat 45%** (`coatParentEach`). If both parents share a coat, it's 90%.
- **Surprise 10%** (`coatSurprise`), from a fixed family table, with every option named:

| Parent coat | Surprise coats |
| --- | --- |
| bay, chestnut, black, chestnut_blaze | buckskin or dun |
| grey | white or roan |
| palomino | buckskin |
| pinto | appaloosa |
| appaloosa | pinto |

  The rule is the union over both parents, split evenly.

**Wording:** always "chance", never the banned wagering word. The card reads "🐴 Comet's coat 45% · Maple's coat 45% · ✨ Surprise 10%: Dun or Roan".

**Rules:**
- Every coat breeding can give is also obtainable by taming or at the Market. No coat is breeding-only this build.
- No pity timers, no rerolls, no "rare!" flashes.

**Horse Book:**
- A bred coat records on the Coats page as usual.
- A new **Family** page: each horse's parents, plus a "First foal" entry.

**Later (deferred):** markings (blaze, star, socks) and breed-only combos. They need a texture pass (the frosted-muzzle script method, 0 Meshy) and the same up-front chances.

## 4. The flow

1. **Where:** the **Foaling Barn**, a small barn next to the Vet. It reuses `stable_barn` scaled to 0.6 and a straw stall, built in code. It gets a **Map tile "🍼 Foaling Barn"**, and `GoTo("foaling")` opens the card.
2. **Pick parents:** two horse slots and a list of the horses that qualify. Horses that don't qualify are greyed with the reason ("Needs 30 races", "Resting: 12 races", "Lent").
3. **See:** the expected family line (sprouts), the coat chances, the fee, and when the foal arrives.
4. **Confirm:** a two-tap "Sure? 🍼 💵 800". The fee goes. Nothing random is shown yet.
5. **Waiting:** a 🍼 chip on the stall. **The foal arrives after `foalAfterRaces` 8 of the owner's counted races, or on the next UTC day you play**, whichever comes first. The text reads "Arrives after 8 races or tomorrow", with no clock or countdown (Spa precedent). An Advice pill points to it when it's ready, never within 120 s of a race.
6. **The arrival:** at the Foaling Barn, the foal stands up beside a parent (the existing `foal_stand_bay/chestnut/grey` models, or the scaled rig for other coats). Hearts and a soft chime. Copy: "A foal is here! 🍼". No birth is shown.
7. **Naming:** NameGen word chips only (no free text), with "Suggest" and "Name me!".
8. **The foal** joins as a **Young** horse in Rookie: `origin = "bred"`, `parents = { idA, idB }`, bond 10, and a free stall if there is one (otherwise the pasture).

## 5. The economy (D-070)

**Fee** (`breeding.fee`), by the higher parent league:

| Bronze | Silver | Gold | Champion |
| --- | --- | --- | --- |
| 400 | 800 | 1,500 | 2,500 |

- That's about 1–2 sessions at the league's cash rate (the D-070 Barn Builder pace). It's a real sink that targets the post-Champion pile.
- **Diamonds never touch breeding:** no fee, no skip, no reroll, no coat. Green Cash is never sold (rule 2).
- **No profit loop:** a bred foal's "price paid" (`h.paid`) is the fee. Selling it returns 50% of the fee plus at most the 100 record bonus. A foal sold at once returns at most half the fee, so breed → sell always loses cash. A test asserts sell value < fee for every league.
- **Stable cap:** 20 total. Breeding adds a horse, so Lend and Sell (D-078) are the outlets.

## 6. Safety and policy

- **No player-to-player breeding or trading this build.** Breeding with friends' horses is deferred: it needs a consent flow, and it would be a trading vector.
- **Not a paid random item:** Green Cash is earned only, and the chances are shown in full before paying, in the spirit of rule 2. No PolicyService gate is needed (no Robux), but the disclosure is identical to what one would require.
- **Copy:** "parents", "foal", "family". Never mare/stallion, mating, pregnancy, birth or blood, and never "odds". Add the banned words to the copy test.
- No foal ever dies, sickens or is lost (rule 3).

## 7. Sims (`sims/bloodline.py`, `src/breeding.py`)

| Sim | Gate |
| --- | --- |
| 10 generations, three strategies (random pairs; best-of-each-generation with 3 foals kept; plus a Legend every generation) | Mean Potential per stat at generation 10 is ≤ 92 under best selection, and the generation-to-generation change is ≤ +0.5 by generation 8 (level-off) |
| Potential distribution | Foal sd about 3–4; the top 1% is ≤ 98; no stat above 100 |
| Ladder | A generation-3 foal's Champion arrival is ≥ 85% of a starter's (training cap binds). Bred horses don't trivialise the ladder. |
| Cash sink (casual / average / keen, 16 weeks) | Fees are 10–25% of cash created after Bronze. The engaged week-12 pile falls ≥ 30%. Barn Builder waits stay ≤ 2 sessions. |
| Time to first foal | Casual ≤ week 5, average ≤ week 4, keen ≤ week 2. This counts the second horse needed: Market or taming. |
| No-profit | Sell value < fee for every league and record |

## 8. Visuals (0 Meshy)

- **Foals:** the existing horse rig scaled by stage. A Young horse is 0.80 at race 0, growing to 1.0 by race 30. HorseLook adds a bouncier bob.
- Standing foals in the Foaling Barn use the three `foal_stand_*` models.
- Coats use the existing coat textures. Markings are deferred (texture script, no Meshy).
- The Foaling Barn is `stable_barn` scaled, plus straw and a 🍼 sign (SurfaceGui), all built in code. **Meshy: 0 of 15.**

## 9. Phasing

**Tonight (one build, about 3 phases):**
1. **Model and sim:**
   - `Breeding.luau` plus `src/breeding.py` (Potential, coat chances, eligibility, fee, sell value);
   - `sims/bloodline.py` with the §7 gates;
   - Lune and pytest tests.

   Merge only on green gates.
2. **Game:**
   - `BreedingService` (eligibility, fee, pending foal, arrival on races or the next day, naming);
   - `BreedingClient` (parent picker, chances card, arrival, naming);
   - the Foaling Barn plus its Map tile and `GoTo`;
   - foal scaling;
   - `origin "bred"`;
   - turn `career.suggest` on.
3. **Book and copy:** the Family page, bred coats recorded, Advice pill, copy test, PLAYTEST section, D-080 entry.

**Deferred:**
- markings and breed-only coats;
- genders (playtest question);
- breeding with friends' horses;
- a foal care mini-game (bottle, first steps);
- more than one foal waiting;
- seasonal foal coats.

## 10. Config and files

```
GameConfig.breeding = {
  enabled = true, minParentRaces = 30, needLeague = "Bronze", parentRestRaces = 20, maxWaiting = 1,
  foalAfterRaces = 8, foalAfterNewDay = true,
  fee = { Bronze = 400, Silver = 800, Gold = 1500, Champion = 2500 },
  parentShare = 0.7, breedAnchor = 75, noise = 5, potMin = 55, potMax = 100, startShare = 0.60,
  coatParentEach = 0.45, coatSurprise = 0.10,
  youngScaleFrom = 0.80,
}
-- career.legacyMax = 2 (existing); career.suggest = true when breeding.enabled
```

**Files:**
- **New:**
  - `shared/Breeding.luau`
  - `server/BreedingService.server.luau`
  - `client/BreedingClient.client.luau`
  - `src/breeding.py`
  - `sims/bloodline.py`
  - `tests/luau/breeding_tests.luau`
  - `tests/test_bloodline.py`
- **Changed:**
  - `Horse.luau` (origin `bred`, `parents`, repair)
  - `Profile.luau` (pending foal, rest counters)
  - `Market.luau` (sell value for bred horses)
  - `HorseBook.luau` (Family page)
  - `WorldLayout.luau` and `WorldClient` (Map tile)
  - `GoTo.luau`
  - `Advice.luau`
  - `HorseLook.luau` (foal scale)
  - `Words` (banned words)
  - `GameConfig.luau`
  - `PLAYTEST.md`
  - DECISIONS D-080 (amends D-047's 35%)
