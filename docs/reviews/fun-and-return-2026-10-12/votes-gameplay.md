# Gameplay votes: fun and return (2026-10-12)

## 1. Votes on the other proposals' top 8

**Systems**

| # | Item | Vote |
| --- | --- | --- |
| 1 | Queue strip and named lines | AGREE (merge with UX 3) |
| 2 | League Points and stage chips | AGREE |
| 3 | Tired legs → vet | AGREE: it supersedes my run trigger (§2) |
| 4 | Stages, Youngster ×1.25 training, decline at scale 0 | AGREE |
| 5 | Maiden / Allowance / Open / Cup labels | AGREE |
| 6 | Sell with a record bonus, plus Lend | AGREE |
| 7 | `--ageing` and `--legs` sims | AGREE. Add the gate "average kid's Champion plateau 35–45%". |
| 8 | Map tiles | AGREE |

**UI/UX**
- Items 1–8: AGREE.
- Item 7: the vet card merges with Systems 3 and Feel B1.
- The 30-credit signpost is out (Meshy cap 15).

**Feel**

| Item | Vote |
| --- | --- |
| B1 Cool-down vet game | AGREE (the same flow as Systems 3) |
| B2 Veteran look | CHANGE: call it the **Wise** look. 0 credits; the review sheet gate stays. |
| A1 Arrival fly-in | CHANGE: only on the first spawn of a session, any tap skips, never on a teleport or visit |
| A2 Horse says hello | AGREE |
| B5 Visiting banner and walkaround | CHANGE: defer with Everyone visiting |
| B4 Winner's circle | CHANGE: at most 4 s, skippable, before the results card. "Race again" must never wait on it. Tint the trophy in code (0 credits) unless the 10 credits fit the cap of 15. |
| A3 Class-up ceremony | AGREE |
| B3 Retirement ceremony | Defer |

## 2. Splits settled

- **Ageing: systems' numbers.**
  - Veteran (shown as "Wise") from **350** races, **−1 Rating per 25**, floor **−6**, with `age.declineScale = 0` until `--ageing` passes.
  - Why 350 beats my 250: it lands after the casual kid reaches Champion and fixes the 54% Champion stomp.
- **Vet trigger: systems' workload.**
  - +1 per counted race, drains 1 per 40 min (offline too).
  - Warning at 7, vet at 8.
  - Never in the first 10 career races; after the vet the workload sits at 2.
  - Practice adds 0 and stays open.
  - Why it beats my run trigger: "any care resets the run" made my version trivial.
- **Stage names: Young · Prime · Wise · Legend** everywhere.
  - The 100-race "Veteran" career label becomes "Wise" at 350 (one meaning per word).
  - Icons: 🌱 💪 🦉 👑. ★ stays riding only.
- **Visiting:**
  - Default **Friends**.
  - The owner chooses Friends, Everyone here or Nobody.
  - Strangers can pat and send 4 preset cheers. Treats and the post box are friends-only.
  - The gate walks everyone out.
- **Selling: three verbs.**
  - **Lend** (free, back any time).
  - **Sell to Sunny Meadow** (NPC only): 50% of the price + min(5 × wins + 100 × Cups, 600), from 25 races, 72 h undo.
  - The word "Rehome" goes away. There's no player trading.
- **Prestige races: systems' entry, no clock.**
  - Entry: Listed from Bronze, ≥ 3 wins and ≥ 6 top-3 finishes; G1 in Champion, ≥ 5 wins.
  - Instead of converting a shared card (which would bump other kids), a qualified rider is offered a "🎖️ Daisy Stakes" card on their own picker at most once per 4 league races. It uses its own queue key with bots at 15 s.
  - Purses: 2B, and 3B for G1.
  - Next build, not tonight.
- **Phone dock: UX's 5 items.** Portrait, 🏁 RACE! (with the 🔀 Pick strip), 🗺️ Map, 📋 Jobs, ☰ More.

## 3. Tonight's build: 12 items in 4 phases

**Phase 1: can find it**
1. Every place on the Map, and GO opens the thing (S/M).
2. Named queue lines with "why", the 3-picture strip and 🔀 Pick (S).
3. The 5-item phone dock and "New!" pointers (S).
4. The League Points / Cup bar and the Maiden / Allowance / Open / Cup labels on the horse card and results (S).

**Phase 2: legs and vet**

5. Tired-legs workload, the free cool-down vet check card and game, copy test, `--legs` sim (M).

**Phase 3: life arc**

6. Stages Young / Prime / Wise / Legend: chips, the path, the 10-race warning, Young training ×1.25 (S).
7. The decline in `race_rating.py` and `RaceRating.luau` with parity, `--ageing` sim, and turned on only if green (M).
8. The Wise look: frosted muzzle, 0 credits (S/M).
9. Sell (record bonus) and Lend, with `--sell` (S).

**Phase 4: reasons to come back**

10. Recurring rivals with a private head-to-head (S/M).
11. The arrival fly-in and "your horse says hello" (S).
12. The class-up ceremony and winner's circle (M).

## 4. Deferred

- Graded prestige races and Derby Day (next build).
- Everyone-visiting, with its banner and walkaround (next build, after a child-safety review).
- The retirement ceremony.
- Breeding and Legend Sparks (bloodline sim first).
- Seasonal events.
- D-072 phase B (the move): after phase A's green gates.
- D-073 Hurdles Practice: after phase B.
