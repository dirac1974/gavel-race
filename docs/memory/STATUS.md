# Status

Last updated: 2026-10-04

## Current state

- **Race model v2**: Python reference and Luau module agree exactly (300 fixture races, purses and finish orders included).
- **Roblox prototype (Phase 1)**: Rojo project in `game/` with three Giddy-up stretches and a Final Burst (D-022). Pure modules (GameConfig, ThemePack, Stride, BurstMeter, TapTime, Integrity, RaceRating, RaceSession) are tested under Lune; stride scoring has a Python mirror with parity tests. Server loop and client UI are written and compile, but **have not been run in Roblox Studio** (see `game/PLAYTEST.md`).
- **Tests**: 1,109 Python tests; 17,600+ Luau checks; policy guard; syntax check for every Luau file; GitHub Actions runs all of it.
- **Art**: playtest art (D-023) is uploaded and wired in; the place must be published to the LlamaWorks group to load it.
- **Design**: debate 007 replaced the gavel meter with Giddy-up stretches and the Final Burst (D-022). Provisional decisions listed in REVIEW_QUEUE.md.

## In progress

(none)

## Backlog (top = next)

1. **Debate 002 — first 10 minutes** (onboarding): first stretch, first burst, first win. Energy is decided (D-015); debate 003 is retired.
2. **DataStore layer**: profile schema (horses, stable, currencies), session locking, retries; pure serialization tested under Lune.
3. **Matchmaking**: league queues, Rating bands, party rule (D-006), bot fill.
4. **Anti-cheat**: `Integrity` (D-022) already tracks tap-gap vs beat-gap spread per player in log-only mode. Still to build: save trackers and strikes in the profile (needs item 2), the review tool and "Ask for a check" button, turning off `logOnly` after a month of real data, and reusing Integrity for Clap Along (D-020: 48+ beats). Don't flag on high scores alone.
5. **Race presentation**: a first pass exists (`TrackScene`: track, stalls, horses that move up by live chance and run to the line in finish order). Racing players now ride their own horse (D-024). Still to do: a hands-and-heels riding animation, bob on the beat with dust puffs and mane flicks (D-023), saddle cloths in lane colours, smoother client-side horse motion and a tuned race camera, and a leg cycle before launch.
6. **Spectator cheering (D-019)**: spectator mode, cheer lock before window 1, Fan XP per tap with per-race and daily caps in `GameConfig.spectator`; tests that riders and their party can't cheer in their own race and that caps hold. Then Clap Along and the crowd boost (D-020): reuse `Stride` for beats and scoring, crowd = best fan + assists, `c_i` in Python and Luau with parity tests, Top Fans board.
7. **Economy sim v2**: add Energy (D-015) with 1, 2, and 3 horses, plus training, sinks, Diamonds, and Fan XP (check the D-019 20% rule) and recalibrate bot scores for stride stretches, to `sims/economy.py`.
8. **Training and Potential**: how stats grow toward each racer's Potential cap; mirror in Python and Luau.

## Done

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
