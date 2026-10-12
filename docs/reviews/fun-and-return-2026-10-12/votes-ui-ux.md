# Votes: UI/UX (fun and return, 2026-10-12)

**Meshy correction:** the cap is 15, not 37. The Fair Street signpost is now **built in code**: wood posts with 6 arms, each arm a SurfaceGui label with an icon and a word for a Map place, standing at the spawn. 0 credits.

## 1. The other proposals' top 8

### Gameplay

| # | Item | Vote | Note |
|---|---|---|---|
| 1 | League Points and class bar | CHANGE | Use 🏆 for the bar (🏅 already means league-badge fallback and "New best"). The results row is "🏆 Cup +6" with a bar and no "46/200". Numbers stay only on the horse card, small. |
| 2 | Queue clarity | AGREE | Merged with mine. |
| 3 | Vet check | AGREE | Its trigger wins (§2). |
| 4 | Life stages | CHANGE | Use the boundaries and switch in §2. |
| 5 | Named prestige races | CHANGE | No clock schedule; use the per-horse rest in §2. |
| 6 | Recurring rivals | AGREE | Defer: not tonight. |
| 7 | Find-it | AGREE | Merged with my "New!" pointers. |
| 8 | Derby Day | OPPOSE (tonight) | A weekday event is a calendar pull. Revisit once named races are proven. |

### Systems

| # | Item | Vote | Note |
|---|---|---|---|
| 1 | Queue legibility | AGREE | |
| 2 | League Points and stage chips | CHANGE | Show a bar, not "Cup in 140 points". |
| 3 | Legs workload | CHANGE | A drain over time is an invisible meter. Use gameplay's run rule (§2). Keep "never in the first 10 career races". |
| 4 | Stages shown, Youngster boost, decline 0 | AGREE | |
| 5 | Maiden / Allowance / Open | CHANGE | These are jargon to an 8-year-old. Keep the kid labels: 🐣 First Win, 🚀 Rising Star, 🎽 Open, and add 🏵️ Stakes winner. |
| 6 | Sell plus Lend | AGREE | See §2. |
| 7 | Sims `--ageing`, `--legs` | AGREE | `--legs` becomes the run-rule cadence check. |
| 8 | Map tiles | AGREE | Subsumed by my every-place Map. |

### Feel

| # | Item | Vote | Note |
|---|---|---|---|
| 1 | Cool-down Check | AGREE, merged | Use its 4 steps on my card. The carrot is **tapped**, not dragged (drag is hard on phones). Hose hold is 1.2 s per leg. |
| 2 | Veteran look | CHANGE | Put the frosted muzzle behind `present.veteranLook` and turn it on only after the "wise, not ill" review sheet. Call the bridle piece a "Veteran charm": rosette means the Wall. |
| 3 | Arrival fly-in | CHANGE | First session of the day only, skippable at once. Defer: not tonight. |
| 4 | Horse says hello and ambient life | AGREE | Defer: not tonight. |
| 5 | Visiting banner and walkaround | AGREE | Barn name only for non-friends. |
| 6 | Winner's circle | AGREE | Defer until named races are proven. Reserve the 10-credit trophy retexture for it. |
| 7 | Class-up ceremony | AGREE | |
| 8 | Retirement ceremony | AGREE | Defer. |

## 2. Splits settled

### Ageing
- **Stages:** Young 0–29 races, Prime 30–349, Veteran from 350 (systems, about the casual Champion arrival), then Legend.
- **Decline (gameplay's gentler slope):** −1 Rating per 50 races from 350, capped at −4.
- **Switch:** `age.declineScale = 0` tonight, set to 1 only when `--ageing` passes.
- **Warning copy:** "Comet is getting wise" / "Soon a little slower".

### Vet trigger (gameplay's rule, with systems' first-10 exemption)
- **Rule:** 6 counted races in a row, Rookie included, without care, a Spa, a training ride, a vet visit or 30 minutes' rest.
- **Exemption:** never in a horse's first 10 career races.
- **Warning at race 5:** "Comet's legs are working hard."
- **At 6:** "🩺 Vet check time!"
- **Why this rule:** one line explains it, and care is the cure, which teaches care. After the vet, the run count goes to 0.

### Stage names
"Young · Prime · Veteran · Legend". Icons are atlas-only: 🌱, 💪, 🦉, 👑. 🎖️ stays the career patch. "Wise" lives only in the warning copy.

### Visiting
| | Rule |
|---|---|
| Default | Friends |
| Options | "👫 Friends", "🌍 Everyone here", "🚪 Nobody" |
| Strangers | Only same-server players whose owner chose Everyone here. Pat plus 4 preset cheers only. No treats, no post box, no names shown to the owner. |
| Friends | Keep treats and pins (D-060). |
| Owner | "🚪 Close gate" and "👋 Ask to leave". |

### Selling
Two buttons on the My Horses card:
- **"🏫 Lend":** free, back any time.
- **"💵 Sell":** Rehome renamed. 50% of the price paid plus the capped record bonus (systems), 72 h undo, from 25 races. The starter never sells.

### Named prestige races
- **Format:** one per league (gameplay's names and entry table), on its own line key `graded`. No clock.
- **Rest rule:** a horse may enter its league's named race once per 5 races of its own: "Ready in 3 races" (counted in races, like age).
- **Purse:** ship at B; raise to 2B only on the `--graded` sim.
- **Titles:** shown on the horse card and on Rosette Wall plaques.

### Phone dock
5 items: horse portrait (opens My Horses), 🏁 RACE! with a 56 px "🔀 Pick" strip, 🗺️ Map, 📋 Jobs, ☰ More. Renders 455 px wide, within the 467 px space beside the right-hand Hop/Gallop column.

## 3. Build list for tonight, ranked (4 phases)

### Phase 1: find it and understand it
| # | Item | Size |
|---|---|---|
| 1 | Every place on the Map, plus the what-to-do lines and the code-built signpost | M |
| 2 | GO opens things: walk if near, teleport and open if far (`GoTo.luau`) | M |
| 3 | Queue card names the line and why, ❓ 3-picture strip, 🔀 Pick before joining | S |
| 4 | Phone dock with 5 items | S |
| 5 | 🏆 Cup bar and class path on the horse card, plus the results points row | S |
| 6 | First-time "New!" pointers | S |

### Phase 2: the vet
| # | Item | Size |
|---|---|---|
| 7 | Vet check: run rule, warning and states, 4-step Cool-down card, copy test words | M |

### Phase 3: life and prestige
| # | Item | Size |
|---|---|---|
| 8 | Life stages shown, Youngster training boost, decline at 0, `--ageing` and run-rule sims | M |
| 9 | Lend and Sell buttons | S |
| 10 | Named prestige races: `graded` line, entry, 5-race rest, titles, purse B | M–L |

### Phase 4: people and moments
| # | Item | Size |
|---|---|---|
| 11 | Visiting: 3-way setting, stranger pat and cheer, arrival banner | M |
| 12 | Class-up ceremony at the Rosette Wall | S |

## 4. Deferred
- Winner's circle and the trophy retexture (hold the 10 credits).
- Retirement ceremony.
- Arrival fly-in.
- Ambient life.
- Rivals.
- Derby Day.
- Party follow.
- Breeding with Legend Sparks.
- Seasonal events.
- Frosted-muzzle Veteran look (waits on the review sheet).
- Turning decline on, and graded 2B purses (both wait on sims).
- Fence-zone and move work: stays on the D-072/073 track.
