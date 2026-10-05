# Status

Last updated: 2026-10-04

## Current state

- **Race model v2**: Python reference and Luau module agree exactly (300 fixture races, purses and finish orders included).
- **Roblox prototype (Phase 1)**: Rojo project in `game/` with three Giddy-up stretches and a Final Burst (D-022). Pure modules (GameConfig, ThemePack, Stride, BurstMeter, TapTime, Integrity, RaceRating, RaceSession) are tested under Lune; stride scoring has a Python mirror with parity tests. Server loop and client UI are written and compile, but **have not been run in Roblox Studio** (see `game/PLAYTEST.md`).
- **Tests**: 1,109 Python tests; 17,600+ Luau checks; policy guard; syntax check for every Luau file; GitHub Actions runs all of it.
- **Art**: playtest art (D-023) is uploaded and wired in; the place must be published to the LlamaWorks group to load it.
- **Race shape (D-033)**: secret luck at the gate gives the same Harville odds as an exponential race; luck shows from the far turn, so comebacks happen on screen while taps still count. Replays of the finish or the whole race (D-034).
- **Design**: debate 007 replaced the gavel meter with Giddy-up stretches and the Final Burst (D-022). Provisional decisions listed in REVIEW_QUEUE.md.

## In progress

**Stage 2 — The world** (branch `claude/stage2-world`):
- `WorldLayout` (pure, tested): Fair Street on z = -324 through a tunnel in the grandstand (Gate 1), Barn Lane on x = 1220 with 20 plots (90 × 118), the Trail loop and meadow east of the lane; ground and bounds extended to x = 1900.
- `WorldScene`: builds the street (fountain, lamps, bunting), Race Board, Feed & Seed, Vet, Training Paddock, Market Corral, Trail Gate, Trail, trees and lighting; uploaded models replace part-built ones when they load.
- `StableService`: plot per player, barn with one bay per stall and stalled horses, spawn at your gate, Map travel (`Travel` remote), visit setting published on the plot.
- `Rides`/`RideClient`: ride your active horse anywhere (Humanoid rig owned by the rider; walk 16, gallop 46; stand/gallop models switched by speed, bob via Motor6D).
- `WorldClient`: privacy walls solid for players who aren't allowed in (default Friends), Map panel, Race Board prompt. `Guide`: pathfinding hoofprints for GO buttons (used from Stage 5).

**Stage 3 — Care and food** (branch `claude/stage3-care`, stacked on Stage 2):
- `Care` (pure, tested): feed (hay/grain), groom, treats (3 a day), pet, garden (carrot 1 h, apple 4 h, oats 8 h; never withers), chores (hay + cash, 4 h per stall), Feed & Seed prices and selling crops.
- `CareService`: checks ownership, distance to your plot or the shop, rate limits; `CareFx` hearts and sparkles for everyone.
- `CareClient`: care card per horse, brushing game, garden and shop cards, prompts on your own plot only.
- `StableService`: stall doors named for chores, garden beds with crops growing in stages and a sparkle when ready, a sparkle on horses brushed today; refreshes every 20 s.

## Backlog (top = next)

World build stages from [WORLD_DESIGN.md](../WORLD_DESIGN.md) (D-035 to D-047). David's go-ahead (2026-10-04): build autonomously, merge as we go, Meshy up to 1,305 credits.

1. **Stage 1 — Your horse**: Profile and DataStore (session lock, autosave, migrations), horse records, wallet and items, starter pick and naming, races use your active horse and pay into your save, HUD.
2. **Stage 2 — The world**: Fair Street, Barn Row plots, your barn with stalls and horses, Map fast-travel, hoofprints, riding your horse around.
3. **Stage 3 — Care and food**: feed, groom, pet, garden, Feed & Seed, chores; care and bond in Rating; Energy top-ups.
4. **Stage 4 — Race Board**: league cards, horse picker, queue, dirt and turf races at once, Friend Races.
5. **Stage 5 — Stable Board**: horse status, next step, daily/weekly/monthly jobs, auto-claim, GO hoofprints.
6. **Stage 6 — Training and vet**: four training games, Potential, weekly cap, rested bonus; heartbeat check-up and Health Passport.
7. **Stage 7 — Spectators**: cheer cards, Clap Along, Fan XP, Top Fans (D-019, D-020).
8. **Stage 8 — More horses**: Market Corral, the Trail, taming, pasture, stall purchases.
9. **Stage 9 — Leagues**: League Points, Stakes, promotion, Bronze and up, Hall of Fame.
10. **Stage 10 — Polish**: first 10 minutes, For grown-ups, sound, art pass, mobile pass, performance.
11. Older items still open: anti-cheat tooling (save trackers once Stage 1 lands), economy sim v2 (Energy, training, sinks, jobs ≤ 10% of race income), running styles (debate 008 research), "How races work" animation, race presentation extras (riding animation, dust, saddle cloths).
12. **Art (parallel)**: Meshy models for barns, stalls, Fair Street, crops, props, more coats (budget in memory).

## Done

- 2026-10-04: Stage 1 your horse (PR #17): saved profiles, starter pick, race queue, dock HUD.
- 2026-10-04: world design (D-035 to D-047) from the design council's world workshop; build stages planned.
- 2026-10-04: exponential race and race shape (D-033), stretch-drive previews, ride report, replays (D-034); debate 008.
- 2026-10-04: continuous pace slider with speed meter and a big rainbow Final Burst (D-026); first-person riding; Churchill Downs racecourse with distance-based race length (D-027).
- 2026-10-04: playtest art uploaded to Roblox (LlamaWorks group): 5 horse coats incl. a darker dapple grey, finish post, gate stall, 2 UI atlas sheets; `AssetService`, `TrackScene`, and client art wiring with placeholder fallbacks.
- 2026-10-04: Giddy-up stretches and the Final Burst (D-022): Stride, BurstMeter (uniform random start), TapTime, Integrity (log only), RaceSession segments with burst weight 2, server loop, client hoof ring and tap-anywhere input, bots recalibrated, Python stride mirror with parity tests, playtest checklist.
- 2026-10-04: tap-time allowance tied to measured latency (D-021), closing the claimed-time exploit.
- 2026-10-04: merged the local PR #1 history into the cloud history (cloud tree kept, as it already contained PR #1's content); refreshed GAME_DESIGN league table; D-018.
- 2026-10-04: merged a parallel review: whole-cash purses (D-017), policy guard in CI, `.claude/settings.json`, `docs/KICKOFF.md`, 567 extra tests.
- 2026-10-04: Energy (D-015), prizes and exactas (D-016), Diamond limits amended (D-002a).
- 2026-10-04: Race Rating formula (D-014) in Python and Luau; prototype races now use random conditions and starter stats.
- 2026-10-04: Studio playtest checklist; economy simulator; Stakes thresholds (D-013).
- 2026-10-04: gavel meter, race session, Rojo prototype, Luau tests, syntax checks, debate 001.
- 2026-10-04: agent team, memory docs, Python tests, Luau parity, CI.
- 2026-10-04: v2 model, Luau module, V2 proposal.
