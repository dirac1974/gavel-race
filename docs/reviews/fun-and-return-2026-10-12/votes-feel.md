# Votes: feel, presentation and world (fun and return, 2026-10-12)

**Meshy cap is 15** (25% of 60, brief.md). UI/UX's 30-credit `fair_signpost` is out; build it in code, from parts plus SurfaceGui arms, for 0 credits.

## 1. The other proposals' top 8

### Gameplay

| # | Item | Vote | Note |
| --- | --- | --- | --- |
| 1 | League Points / class bar | AGREE | The bar fills with one `tap_ok` tick per point (speed 1.0 → 1.3, at most 10 ticks). |
| 2 | Queue clarity | AGREE | Merge with UI 2a/2b. |
| 3 | Vet check | CHANGE | Trigger as settled in §2. Use my "Cool-down Check" presentation (proposal-feel B1). |
| 4 | Life stages | CHANGE | Numbers and names as settled in §2. Decline ships at scale 0. |
| 5 | Named prestige races | CHANGE | Cadence as settled in §2, never on a clock. Defer to the next evening alongside the winner's circle (one feature, presented properly). |
| 6 | Recurring rivals | AGREE, deferred | Good story value, but not tonight. |
| 7 | Find-it | AGREE | Merge with UI 1c. |
| 8 | Derby Day (Saturdays) | OPPOSE for now | A weekday-specific calendar invites "come back Saturday" urgency. Revisit after named races ship. |

### Systems

| # | Item | Vote | Note |
| --- | --- | --- | --- |
| 1 | Queue strip and named lines | AGREE | Merge with UI 2a/2b. |
| 2 | League Points and life-stage chips | AGREE | |
| 3 | Tired legs | CHANGE | Trigger as settled in §2. Keep `legs.fromRaces = 10` and `afterVet = 2`. |
| 4 | Life stages, Youngster boost, decline at 0 | CHANGE | Numbers as settled in §2. |
| 5 | Maiden / Allowance / Open labels | AGREE | |
| 6 | Sell with bonus, plus Lend | AGREE | One "Riding School" card holds both (§2). |
| 7 | Sims `--ageing` and `--legs` | AGREE | Run in parallel by economy-analyst. Not counted as an engineering phase. |
| 8 | Map tiles | AGREE | |

### UI/UX

| # | Item | Vote | Note |
| --- | --- | --- | --- |
| 1 | Map tile for every place | AGREE | Plus the code-built signpost. |
| 2 | GO opens the thing | AGREE | Teleport with a 0.3 s Paper fade (`FFF7E6`), never a hard cut. |
| 3 | Queue card names the line | AGREE | |
| 4 | 🔀 Pick | AGREE | |
| 5 | 5-item phone dock | AGREE | |
| 6 | Cup bar and class path | AGREE | Same as Gameplay #1. |
| 7 | Vet-check states and card | AGREE | Same visual language as B1. |
| 8 | First-time "New!" pointers | AGREE | The ring pulses at 1 Hz, so it never flashes more than 3 times a second. |

## 2. Splits, settled

**Ageing: start at systems' point with gameplay's slope.**
- The values are Veteran at 350 races (`age.veteranAt`), then **−1 Rating per 50 races, capped at −4** (×0.72 at T 12).
- −6 at ×0.61 is too steep a loss for a horse a kid loves. Starting at 350 keeps the decline off the climb.
- Ship with `declineScale = 0`, and turn it on only if `--ageing` passes, including the Champion plateau ≤ 45%.

**Vet trigger: gameplay's visible run, with systems' guards.**
- Count a run of counted races per horse: `legs.runLimit = 6`, warned at 5, Practice counts 0.
- **Feed or groom takes 2 off the run.** A Spa, a training ride, a vet visit or 30 min without racing that horse resets it to 0.
- Never in a horse's first 10 races (`legs.fromRaces`).
- The vet visit sets the run to 2, not 0.
- The horse card shows a 6-pip "Legs" row. The cause stays visible, and caring for the horse is the way to avoid it.

**Stage names: Young · Prime · Veteran · Legend.**
- "Veteran" is already the D-059 word and kids know it. "Wise" sounds odd as a label.
- Keep "getting wise" only in the warning copy: "Comet is getting wise. Soon a little slower."

**Visiting:**
- The default is 👫 Friends. Owners can choose 🌍 Everyone here or 🚪 Nobody.
- Strangers can Pat and send 4 preset cheers, shown anonymously. Treats and the post box stay friends-only.
- The owner gets the visitor chip, "Ask to leave" and Close gate.
- No text input of any kind.

**Selling:** one "🏫 Riding School" card with two choices.
- **Lend:** free, and the horse comes back any time.
- **Sell:** 50% of the price paid plus a record bonus capped at 600, with a 72 h undo.
- The word "Rehome" goes. No player trading.

**Named races:**
- Gameplay's names and entry table (Buttercup to Giddy-Up Derby; wins and races in the league).
- Systems' cadence: every 4th card in the league line becomes the named race when at least 1 qualified rider is in line. No clock, no countdown.
- Pays B until `--graded` passes, then 2B (3B for the G1).

**Phone dock (5 items):** horse portrait → 🏁 RACE! (with the 🔀 Pick strip) → 🗺️ Map → 📋 Jobs → ☰ More (Ride, Book, Cash, Horses). Also set the Book's `LayoutOrder` to 6.

**Meshy:** `trophy_cup` → `trophy_graded` retexture for 10 credits, used with the named races. Hold 5.

## 3. Build list for tonight (12 items, 4 phases)

| Phase | # | Item | Size |
| --- | --- | --- | --- |
| **1. Find it** | 1 | Map tile for every place, plus the code-built signpost | S–M |
| | 2 | GO opens the thing (teleport with a Paper fade) | M |
| | 3 | 5-item phone dock, plus the Book order fix | S |
| | 4 | The queue card names the line, the 3-picture strip and 🔀 Pick | S |
| **2. Progress you can see** | 5 | League Points and Cup bar on the results and horse cards, with ticks | S |
| | 6 | Maiden / Allowance / Open / Cup labels | S |
| | 7 | Life stages on the card (path and chip), Young scale 0.94 and train ×1.25, the Veteran look (frosted-muzzle texture script plus the rosette), decline at 0 | M |
| **3. Legs and the vet** | 8 | The run rule plus the Cool-down Check mini-game (check → hose → wraps → carrot; wraps stay 3 races) | M |
| **4. World and social** | 9 | Riding School card: Lend and Sell | S |
| | 10 | Visiting any barn: settings, arrival banner, 4-stop walkaround, owner chip | M |
| | 11 | Arrival fly-in, plus your horse greets you, plus ambient life | S |
| | 12 | First-time "New!" pointers, for every item above | S |

In parallel, economy-analyst runs `--legs`, `--ageing` and `--sell`.

## 4. Deferred

- **Next evening:**
  - named prestige races together with the winner's circle, the flower blanket and `trophy_graded` (10 credits);
  - the Rosette Wall class-up ceremony;
  - the retirement ceremony.
- **After the playtest:**
  - recurring rivals;
  - turning the ageing decline on (after the sims pass);
  - D-072 phase B (the move);
  - D-073 Hurdles.
- **Later:**
  - Derby Day;
  - breeding with Legend Sparks;
  - seasonal events;
  - the professional-polish table (typography, panel transitions, empty states), which goes in piecemeal with each item above.
