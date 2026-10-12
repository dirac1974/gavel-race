# Systems votes: fun and return (2026-10-12)

The Meshy cap is 15. UI's `fair_signpost` (30) is out.

## 1. Other proposals' top 8

**Gameplay**

| # | Item | Vote |
| --- | --- | --- |
| 1 | League Points and class bar, results points row | AGREE |
| 2 | Recurring rivals | AGREE. Anchor ± 6 and draws after the existing ones keep the maths unchanged. Head-to-head stays private. |
| 3 | Named races | CHANGE. No clock schedule (see the splits), and the purse is B until `--graded` passes, then 2B. |
| 4 | Life stages | CHANGE to the split numbers below. Counted races only, never Practice. Ship with `age.declineScale = 0`. |
| 5 | Vet check | CHANGE. **No +1 bond**: bond is Rating, and over-running must never pay. Use the split's reset rules. |
| 6 | Queue clarity | AGREE. Party follow is deferred: the API is unverified in Studio. |
| 7 | Derby Day | OPPOSE for tonight. A Saturday-only cadence teaches "come back Saturday": mild FOMO. Revisit after named races exist. |
| 8 | Find-it | AGREE. Merge with UX 1c, one system. |

**UI/UX**

| # | Item | Vote |
| --- | --- | --- |
| 1 | Map tile for every place | AGREE |
| 2 | GO opens the thing (`GoTo`) | AGREE. Never while in line or racing. |
| 3 | Queue card names the line and why | AGREE |
| 4 | 🔀 Pick before joining | AGREE |
| 5 | Phone dock with 5 items | AGREE |
| 6 | Cup bar and class path | CHANGE. Path steps: Maiden · Allowance · Stakes · named-race winner. The Cup bar shows no number (as UI said). |
| 7 | Vet-check states and card | AGREE |
| 8 | "New!" pointers | AGREE. Max 1 per 3 min, never within 120 s of a race. |

**Feel**

| # | Item | Vote |
| --- | --- | --- |
| B1 | Cool-down Check | AGREE. 4 steps, ≤ 30 s, wraps for 3 races. |
| B2 | Veteran look | CHANGE. Tonight: the Wise rosette and Young scale 0.92 only. The frosted-muzzle texture waits for a "wise, not ill" kid review. |
| A1 | Arrival fly-in | AGREE |
| A2 | Horse says hello | AGREE |
| B5 | Visit banner and walkaround | AGREE |
| B4 | Winner's circle | DEFER, with named races. The 10-credit trophy retexture is OK then. |
| A3 | Class-up ceremony | DEFER, with named races. |
| B3 | Retirement ceremony | DEFER |

## 2. Splits settled

- **Ageing.**
  - Decline starts at **300 counted races** (warned at 290), −1 Rating per **40**, cap **−5**. Practice never counts.
  - That gives about −1 at a casual Champion arrival (350), so it doesn't hurt the climb. At −5 the Champion plateau drops from about 54% to about 41%, which still fixes the stomp.
  - Ship with `declineScale = 0`. Turn it on only when `--ageing` passes: casual Champion ≤ week 13, entry win rates −2 pt at most, Cup times +10% at most.
- **Vet trigger: gameplay's run model** (kids can read it).
  - `vetCheck.runLimit = 6` counted races on one horse, Rookie included; warning at 5.
  - The run resets after 30 min without racing that horse, or after a vet check or a Spa.
  - Feed and groom each take 2 off the run. Petting doesn't count: it's free to spam.
  - It never triggers in a horse's first 10 races.
  - No Rating, bond, Energy or cash effect.
- **Stage names: Young · Prime · Wise · Legend.**
  - "Veteran" stays D-059's career word.
  - Prime uses 💪, never ⭐ (★ means riding).
- **Visiting.**
  - Default 👫 Friends; the owner can opt in 🌍 Everyone here or choose 🚪 Nobody.
  - Strangers: Pat, plus 4 preset cheers shown anonymously to the owner.
  - Treats and the post box stay friends-only.
  - The owner can use per-name "Ask to leave" and Close gate.
  - No counts, no names of non-friends.
- **Sell.** One "🏫 Riding School" button with two choices:
  - **Lend:** free, and the horse comes back any time.
  - **Sell:** Rehome renamed. Half the price paid, plus a record bonus capped by `sell.bonusCap`. The cap ships at **0** until `--sell` shows it is ≤ 3% of cash created. 72 h undo. The starter never sells.
- **Named races.**
  - **No wall clock.** A league line's next card becomes its named race when a qualified rider is in line and the last named race was at least `graded.everyRaces = 4` races ago.
  - Entry uses gameplay's table (wins / races in the league): Rookie 1/8, Bronze 2/15, Silver 3/25, Gold 3/30, Champion 3/30.
  - Purse B until the sim passes, then 2B. +15 League Points for a win, also gated by the sim (Cup times −10% at most).
- **Phone dock:** horse portrait, RACE!, Map, Jobs, ☰ More (Ride, Book, Cash, Horses).

## 3. Tonight's build (ranked, 4 phases)

| Phase | # | Item | Size |
| --- | --- | --- | --- |
| **P1 Clarity** | 1 | League Points / Cup bar on the horse card, results points row, class path labels (Maiden / Allowance / Stakes) | S |
| | 2 | Queue line names and why, ❓ 3-picture strip, 🔀 Pick before joining | S |
| | 3 | Map tile for every place, plus GO opens the thing (`GoTo`) | M |
| | 4 | 5-item phone dock, plus "New!" first-time pointers | S |
| **P2 Vet** | 5 | Vet check: run trigger, states and copy, the 4-step Cool-down card, wraps for 3 races, `--legs`/run sim | M |
| **P3 Life** | 6 | Life stages Young / Prime / Wise / Legend on the card, Young training ×1.25, decline in config at scale 0, `--ageing` sim | M |
| | 7 | Riding School: Lend, plus Sell (bonus cap 0) | S |
| | 8 | Wise rosette and Young scale (code-built) | S |
| **P4 World** | 9 | Visiting: Everyone opt-in, stranger pat and cheers, Ask to leave, arrival banner and walkaround | M |
| | 10 | Recurring rivals | S–M |
| | 11 | Arrival fly-in, plus horse says hello and ambient life | S |
| | 12 | Every new state and copy through the copy test and banned words (tired-legs, strain, lame, pain, bleed) | S |

## 4. Deferred

- Named and graded races, the winner's circle and trophy retexture (10), the class-up ceremony
- Derby Day
- Turning the decline on (until `--ageing` passes) and the Sell bonus (until `--sell` passes)
- Frosted-muzzle texture
- Retirement ceremony
- Breeding and Legend Sparks (D-047, needs `sims/bloodline.py`)
- Party follow
- The signpost (over the Meshy cap)
- Seasonal events
- `--multi` horse economy sim (before soft launch)
