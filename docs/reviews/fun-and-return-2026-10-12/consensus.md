# Fun and return: consensus (2026-10-12)

Inputs: brief.md (David's request and directions), inventory.md, docs/research/2026-10-12-fun-and-return.md, proposal-*.md, votes-*.md. The tech lead settled the splits below. Every CHANGE in the vote files that isn't contradicted here is part of the spec.

## Decided by David (logged as such)
- Over-running can need the vet.
- Horses age and get less effective.
- Horses can be sold.
- Visiting other users' stables.
- Classes that qualify for races and prestige.
- The queue explained.

## Splits settled

| Topic | Votes | Ruling |
|---|---|---|
| Ageing | 350 / −1 per 50 / cap −4 (UI/UX, feel); 350 / −1 per 25 / −6 (gameplay); 300 / −1 per 40 / −5 (systems) | **Veteran at 350 counted races, −1 Race Rating per 50 races after that, capped at −4** (`ageing.veteranAt` 350, `declinePer` 50, `declineCap` 4). Never in Practice; League Points, ceilings and stats are untouched. Warned 10 races ahead. It ships with `ageing.declineScale = 0` until the `--ageing` sim passes. **The sim runs tonight.** David asked for real decline, so the target is to turn it on tonight, with the result in REVIEW_QUEUE. Youngster bonus: training ×1.25 for the first 30 races. |
| Stage names | Wise (gameplay, systems) / Veteran (UI/UX, feel) | **Young · Prime · Veteran · Legend.** "Veteran" is already the career word (D-059), so a second word would confuse. |
| Vet trigger | 3 of 4 for the run model | **Counted races in a row on one horse.** The warning chip comes at 5 ("💦 Worked hard!"). At 6, RACE! becomes 🩺 VET CHECK for rated races; Practice stays open. These lower the count: feed or groom −2; 30 min rest, the Spa, training or the vet reset it. Never in a horse's first 10 races. A visible "Legs" row on the horse card. |
| The vet visit | all | Feel's **Cool-down Check**: about 30 s in 4 tap steps (check legs, cold hose, soft wraps, carrot). Free, with no Diamonds anywhere. Wraps are worn for the next 3 races. No Rating or bond effect. Sky-blue states. Never use the words hurt, sore, injury, limp or sick. |
| Visiting | all: Friends default; strangers can only pat and cheer | Owner setting: **Friends (default) / Everyone here / Nobody.** The first time a kid opens the Map's barns list, ask once: "Let other riders visit? Friends · Everyone". The Map's barns list shows friends' barns **and every barn that's open to everyone**, so David's "go around and visit other users' stables" works. Strangers can look, walk the 4-stop tour, pat and cheer. Treats and carrots are for friends only. There is no taking, no text and no ratings. |
| Selling | all | A Riding School card with two buttons: 🏫 **Lend** (free, take back any time) and 💵 **Sell** (half the price paid; record bonus `sell.recordBonusCap = 0` until `--sell` passes). The word "Rehome" goes. Tamed and gifted horses sell for 0 and get the goodbye rosette. |
| Named prestige races, winner's circle, trophy retexture | deferred by 3 of 4 | **Next build.** Tonight only the class path shows them as the next goal ("Stakes: 2 more wins"). |
| Derby Day | opposed by 3 of 4 (mild FOMO) | **Not built.** |
| Phone dock | all | UI/UX's 5 items (horse, RACE! with a 🔀 Pick strip, Map, Jobs, More). |
| Meshy | cap 15 | **0 credits tonight.** The signpost is built in code. The 10-credit trophy retexture waits for the winner's circle. |

## Tonight's build: 5 phases, each followed by code review and a designer consult

1. **Find it** (UI/UX):
   - all 13 places on the Map, each with a ≤ 2-word "what to do here" line;
   - `GoTo.luau`: GO teleports (when far) and opens the feature, never while in line or racing;
   - the 5-item phone dock;
   - the queue card names your line and why, with a ❓ "how racing works" 3-picture strip shown once automatically;
   - 🔀 Pick a race before joining;
   - "New!" pointers, at most one per 3 min;
   - the Map/Book LayoutOrder bug fixed;
   - the fair signpost at spawn, built in code.
2. **Visible progress:**
   - a Cup bar plus a class path (First Win → Rising Star → Open → Stakes → Cup) on the horse card and the results card ("+6 🏅", as a bar, not a raw number);
   - a class-up mini-ceremony at the Rosette Wall.
3. **Legs and the vet:**
   - the run counter (server-authoritative, saved);
   - the warning chip; VET CHECK in place of RACE!;
   - the Cool-down Check mini-game; wraps worn on the horse;
   - the Legs row; Advice entries.
4. **Life arc:**
   - stages on the horse card;
   - the Veteran look (frosted muzzle and brows by texture script, plus a silver-and-blue bridle rosette);
   - decline in the Python model and Luau, behind `declineScale`, plus the `--ageing` sim;
   - the youngster training bonus;
   - the Riding School Lend/Sell card.
5. **Visiting:**
   - the three-way setting plus the one-time ask;
   - open barns in the Map list;
   - an arrival banner;
   - the 4-stop walkaround with a Tour pin;
   - stranger permissions (pat and cheer only).

**Still in flight:** D-072 phase A closes first (calibration, Python mirror, commit).

**Deferred:** named prestige races with the winner's circle and trophy; rival bots; the arrival fly-in; ambient life; the retirement ceremony; breeding; D-072 phase B (the move); D-073 Hurdles.
