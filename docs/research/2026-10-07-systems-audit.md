# Systems audit: owner themes vs. code (2026-10-07)

Read: CLAUDE.md, STATUS, GAME_DESIGN, WORLD_DESIGN, DECISIONS D-013/014/015, D-035 to D-053, and the code in `game/src`. Nothing has run in Studio yet, so "exists" here means the code is written and reads correctly. It does not mean the feature works.

## (a) Horse wear: Energy, rest, overwork, soreness, vet

| Item | Status | Where |
| --- | --- | --- |
| Energy: 5 per horse, regains 1 every 20 min (offline too), +1 for feeding or grooming every 2 h | **Built** | `shared/Horse.luau` `syncEnergy/spendEnergy/addEnergy/tend`; `GameConfig.energy` |
| Cash race costs 1 Energy; Rookie, Practice and training are free; Energy refunded if a race errors | **Built** | `RaceService` `costOf`, `runRace`, `courseLoop` refund |
| "Rested" training bonus (×1.5 after 3 h with no training) | **Built** | `shared/Training.luau` `isRested`, `RESTED_SECONDS` |
| Weekly training cap (6 stat points per horse) | **Built** | `Training.WEEKLY_CAP` |
| Overwork, soreness, injury, sickness | **Not built, ruled out on purpose** (hard rule 3; D-039 rejects "sore legs after hard races"; David confirmed 2026-10-05) | none |
| Vet: heartbeat check-up, +1 bond a day, 5 Health Passport stamps (the 2nd stamp reveals Potential) | **Built** | `Training.checkup`, `TrainingService` `VetVisit`, `PaddockClient` `vetMenu` |
| Post-race cool-down hose, cosmetic leg wraps (D-039) | **Missing** | none |

Findings:
- "Resting" means `energy < max` (`Horse.view`). After a single Bronze race the dock says "Resting" (`Hud.client.luau` `render`) and the Stable Board says "napping in the straw" (`shared/Advice.luau`), but the horse can still race 4 more times. The race picker only greys a horse at 0 Energy. Rookie horses never spend Energy, so they never rest. Rest therefore has no real effect for new players, and it misleads everyone else.
- Racing doesn't count against "rested". Only training does, so the race/rest loop the owner may expect isn't there.

## (b) Age, Potential, decline, retirement, breeding, market, stalls

| Item | Status | Where |
| --- | --- | --- |
| Age / decline | **None, by design** (D-037: "horses don't age or decline"). `born` is stored but never read | `Horse.luau` |
| Potential per stat: hidden, starters 70–85, training gain shrinks as a stat nears it | **Built** | `Horse.starter`, `Training.gain` |
| Retire into the Hall of Fame (player's choice, keeps a plaque, max 50) | **Built** | `Leagues.retire`, `MarketService` `RetireHorse`, `HorsesClient` (two-tap Retire, 🏅 Hall of Fame list) |
| Breeding (D-047) | **Missing**. Foal models exist (`MeshAssets`). No bloodline sim, no code (STATUS backlog #7) | none |
| Market Corral: 5 horses a week, same seed on every server, each player buys their own copy, price 250 to about 1,700 by Potential, ★ bloodline hint | **Built** | `shared/Market.luau` `stock/price/buy`, `MarketService` (statues in the corral) |
| Selling your horse | **Missing, by design** (no trading, D-037). Only crops can be sold (`Care.sell`). Retiring gives no cash back | none |
| Taming wild horses (one a day, needs a treat, 6 wild coats) | **Built** | `Market.tame`, `WildHorses.client.luau` |
| Stalls: 2 to start, buy up to 6 (300/800/2000/4000), free pasture, 20 horses max | **Built** | `Market.STALL_PRICES/buyStall`, `Profile.isStalled/swapStall` |
| Event horses | **Missing** | none |

Risks:
- Stalls go by list order (`Profile.isStalled`), so retiring a stalled horse quietly moves the first pasture horse into a stall.
- `RetireHorse` blocks retiring while racing or in line, but not while you're riding that horse or on a training ride with it.

## (c) Visiting other stables (D-042)

- **Built:**
  - 20 plots on Barn Lane, each with the owner's name sign (`StableService`).
  - The visit setting is Friends or Nobody (`GrownUps.client.luau:117`). "Club" exists only in the profile, and is treated as Friends (`WorldClient.client.luau` `allowed`).
  - Privacy walls go solid on the visitor's own screen when they're not allowed in, using a cached `IsFriendsWith`.
- **No visit flow:**
  - There's no "visit a friend" button, friend list or Map entry. The Map holds 5 fixed places and "stable" only goes to your own plot (`WorldLayout.MAP`).
  - The only way to visit is to walk Barn Lane and spot the sign.
- **Missing from D-042:**
  - The post box is decor only (`StableService.server.luau:270`). There's no carrot drop and no count.
  - Visitors can't pet or treat (every care action requires `atOwnPlot`, `CareService`).
  - No daily friend gift, no Friend Races, no Clubs.
- **Built nearby:** Ride together for training (`TrainingFriends.luau`, `RideTogether.luau`) is the one finished friend feature.
- **Safety note:** the walls are a client-side check only. That's acceptable, because the server refuses every action on someone else's plot.

## (d) Race queue

**How joining works** (`RaceService.server.luau`):
1. RACE! or the Race Board opens the picker (`RacePicker.client.luau`).
2. The picker shows 2 cards, one per course (dirt and turf). Each course holds one queue of up to 8.
3. An empty card is "Open". The first rider's horse league and race kind (Race, 🏆 Cup or 🎈 Practice) claim it (`claimCard`).
4. 20 s after the first join (`lobbyFillSeconds`), bots fill the empty lanes, rated within ±6 of the human median (`RaceSession.fillWithBots`).
5. Then a 3 s countdown and the race (Sprint about 69 s up to Marathon about 141 s), then 5 s of results.

**Waits:** about 23 s to the gate on an idle course. Joining while a race runs on that course means the rest of that race, plus 5 s, plus the 20 s fill, so up to about 3 min.

**Leagues and prestige:**
- Rookie → Bronze → Silver → Gold → Champion. Each league has a points target that opens its Cup (100 / 110 / 1,400 / 3,000).
- A league ceiling closes regular races to an over-strong horse.
- A Cup win pays 3B and promotes the horse, plus 25 💎 (`Leagues.luau`, `RaceService` around line 894).
- The Hall of Fame is a per-player list inside My Horses. It isn't shown anywhere in the world.

**Designed but missing (D-036):**
- Rating-band matchmaking (±12 widening to ±20).
- Keeping friends and party members out of the same cash race (D-006).
- Friend Races.
- The 25-point floor on each lane's score.
- Cross-server Cup finals and Derby Day.

**Problems:**
1. **League lockout.** There are only 2 cards. If a Bronze rider has claimed one and a race runs on the other, a Rookie can't race at all until one frees up. The picker *pre-selects the card with riders* even when it's the wrong league (`RacePicker` `open`; `bestCourse` does the same), and only says "That race is for Bronze horses" after Join.
2. **Horse strength barely shows against bots.** Bots are rated around the human median, so a solo player's training doesn't change their win chance. Stats mostly decide when the league ceiling forces a Cup. Kids may not feel their training pay off in races.
3. Silver Cup needs 1,400 points, roughly 470 Silver races at about 3 points a race (D-013, by design, but long).

## (e) Retention hooks that exist

| Hook | Status |
| --- | --- |
| 3 daily / 5 weekly / 5 monthly jobs, auto-claim at rollover, 1 free swap | **Built** (`Jobs.luau`, `JobService`, `StableBoard.client.luau`) |
| Monthly job stamps toward "the month's cosmetic" | **Half built**: stamps add up (`Jobs.STAMPS_FOR_COSMETIC = 8`) but nothing is ever given. The board shows "This month ⭐N" leading nowhere |
| Finish every monthly job: 25 💎 | **Built** (`JobService` `monthlyGift`) |
| Login calendar | **Only days played is counted** (`Profile.touchDay`); no calendar screen or reward |
| Garden grows offline (carrots 1 h, apples 4 h, oats 8 h) | **Built** (`Care.plant/harvest`) |
| Collections: 12 coats, 5 Passport stamps, ribbons and stall rosettes per course, Hall of Fame plaques, Tack & Paint looks | **Built** |
| Rotating content: weekly market, weekly Mud Splash layout (`TrainingCourses.weekCourse`) | **Built** |
| Fan XP: capped per race and per day, Fan levels, fan flags at levels 3 and 5 | **Built** (`Fans.luau`, `FanService`, `Style.luau` `fan_star/fan_hoof`) |
| Seasonal events, Derby Pass, Clubs, Derby Day | **Missing** |

## (f) UI and clarity

**Screens and HUD elements:**

| Screen | File |
| --- | --- |
| Dock: 💵 cash, 💎, horse card (coat dot, name, 5 hoof icons, "Resting ⭐⭐"), 🐴, 📋, 🗺️, 🏁 RACE! with ✕ leave, Ride/Get off | `Hud.client.luau`, `RideClient` |
| Touch extras: Gallop, Hop, 💎 pill top right, ⚙️ top right, tour card at the top, toasts | `Hud`, `GrownUps`, `Ui` |
| Starter pick and name chips | `Starter.client.luau` |
| Race picker (720×470) | `RacePicker.client.luau` |
| Race HUD: countdown, pace slider, speed meter, FINAL BURST ×2, place badge, ◀ In / Out ▶ (from race 4), steering chips, race strip and lap oval | `RaceController`, `Minimap`, `SteerHud` |
| Results (ribbon, "You rode ★★☆", "Good trip ★★☆", Watch the finish / Whole race ×3 / Done), then Replay | `RaceController`, `Replay` |
| Spectating: cheer strip, 👏 Clap, Top Fans panel | `FanClient` |
| Stable Board (780×520) | `StableBoard` |
| My Horses (760×500), Hall of Fame, rename, Build a stall, market card | `HorsesClient` |
| Care card (feed, groom game, treat, pet), garden, chores, Feed & Seed | `CareClient` |
| Training picker (4 courses, Quick train, Ride together), ride HUD, end card; vet game | `PaddockClient`, `TrainingRideClient` |
| Taming game | `WildHorses` |
| Map, 5 places | `WorldClient` |
| Tack & Paint shop | `StyleShop` |
| Settings and For grown-ups | `GrownUps` |

**Onboarding:** starter pick, then a 5-step tour (`shared/Tour.luau`): race, feed, groom, plant, open the board. GO hoofprints lead the way (`Guide.luau`), and Skip is always there.

**Clarity problems for an 8–10-year-old on a phone:**
1. **Stars mean 8 things:**
   - ⭐ for care in the dock
   - ★ for the ride and ★ for the trip on the results card
   - ★ bloodline in the market
   - 1–3 training stars
   - ⭐ monthly stamps
   - "⭐ Top Fans"
   - the ⭐ fallback job icon
2. **Energy has 3 looks:** a hoof icon in the dock, ⚡ with "·" in the picker. ⚡ is also the **Sprint** symbol on the same picker card (`DIST_EMOJI`).
3. **"Resting" is wrong.** It shows after any Energy is spent (see a). A kid sees "napping" on a horse that can race.
4. **The phone dock is crowded.** 7–8 items, about 950 px wide, are shrunk to 0.4–0.6 to clear the movement column (`fitDock`). 70 px buttons come out around 35 px, and the "Resting ⭐⭐" label (16 px in a 70 px box) about 8 px.
5. **Panels shrink on phones.** At a 375 px-high landscape screen the picker scales to about 0.75 and the Stable Board to about 0.68. Their 14–15 px text drops to about 10 px. This affects RacePicker 14 px hints, StableBoard rewards and "3 / 5", and HorsesClient's 13 px stall line.
6. **The race picker is a reading test.** Each card has 4 lines of text ("Open · your horse's league · Dirt", "Sprint · short 🟫 Dirt ☀️", "🎀 Ribbons and Green Cash"). Horse cards say "Loves today's race (+3)". The Cup button reads "🏆 37 pts". Cards claimed by another league look the same as joinable ones.
7. **The results card has two star rows** ("You rode" and "Good trip"), and from race 4 a "trip gained" line too.
8. **Weekly and monthly jobs are hidden behind "See".** That button fires one toast per job, up to 5 at once (`StableBoard` `ribbon`).
9. **Hidden features.** Training, vet, market, taming, Ride together, Tack & Paint, Hall of Fame and Retire are all outside the tour. They're found only through Map pictures, board GO buttons or walking. Hall of Fame sits inside My Horses.
10. **Words kids won't know:** League Points, Rating, Potential, Acceleration, Grit, pasture, stall, Cup "pts". Potential stays hidden until the second day's vet visit, so "Next: train X" can't show before that.
11. **Long toasts.** "Your taps looked automatic, so they count as practice for now…" and "Comet is too strong for Rookie races now. Win the Cup to move up!"
12. **Public leaderboard.** `PlayerData` puts Green Cash and Wins in leaderstats, which is a public ranking in the player list. That sits awkwardly with D-042's "no rankings".

## Code health risks (from reading, never run)

1. **One error could stop all syncing.** `Profiles.sendSync` runs every decorator (Race, Market, Jobs) with no `pcall`. If any one throws, the client never gets a ProfileSync and stays on "Your stable is loading…" for good. Wrap each decorator.
2. **Long wait, then a kick, on rejoin.** A save that's still locked is retried 6 times with backoff (about 70 s), then the player is kicked (`Profiles.load`). A kid rejoining fast after a crash waits a minute and then gets kicked.
3. **Retiring a horse in use.** You can retire the horse you're riding or training on (only `Racing`/`InLine` are checked). `Rides` or `StableService` may still hold its id → nil errors.
4. **The client sets the taming score.** `Tame` trusts the score the client sends (≥ 50 passes). Low stakes: one horse a day.
5. **Duplicate world.** `MarketService` falls back to `WorldScene.build()`. That's safe only because `built` is cached in the module and `build` doesn't yield. Any yield added later could build the world twice.
6. **Picker redraw can miss a league change.** `renderCards` leaves league, Cup and Practice out of its redraw key. A card claimed by a league can keep its "Open" look until the rider count changes.
7. **Mistyped tables.** `MarketService` `last` is typed `{[Player]: number}` but uses string keys. Harmless under `--!nonstrict`, but a strict pass will flag it.
8. **Typed but never checked.** `Profile.migrate` doesn't validate `market`, `jobs`, `fan` or `hallOfFame`. Each module repairs lazily, so a bad save shows up in whichever service touches it first.
