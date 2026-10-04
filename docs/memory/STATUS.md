# Status

Last updated: 2026-10-04

## Current state

- **Race model v2**: Python reference and Luau module agree exactly (300 fixture races, purses and finish orders included).
- **Roblox prototype (Phase 1)**: Rojo project in `game/`. Pure modules (GameConfig, ThemePack, GavelMeter, RaceSession) are tested under Lune. Server loop and client UI are written and compile, but **have not been run in Roblox Studio**.
- **Tests**: 471 Python tests; 17,000+ Luau checks; syntax check for every Luau file; GitHub Actions runs all of it.
- **Design**: debate 001 decided the gavel meter (D-010). Provisional decisions listed in REVIEW_QUEUE.md.

## In progress

(none)

## Backlog (top = next)

1. **Studio playtest checklist** (`game/PLAYTEST.md`): what David should verify the first time he runs the prototype, since agents can't open Studio.
2. **Economy simulator** (`sims/economy.py`): cohorts (casual, regular, skilled; payer, non-payer), faucets and sinks, time-to-league targets. Feeds debate 003.
3. **Debate 002 — first 10 minutes** (onboarding), then **003 — Energy system**.
4. **Horse data model**: stats, Potential, conditions weights, Race Rating function (pure module + Python mirror + tests).
5. **DataStore layer**: profile schema (horses, stable, currencies), session locking, retries; pure serialization tested under Lune.
6. **Matchmaking**: league queues, Rating bands, party rule (D-006), bot fill.
7. **Anti-cheat**: flag sustained S > 95, tap-rate checks, server-side logging.
8. **Race presentation**: horses moving on a track, animation driven by the drawn finish order.

## Done

- 2026-10-04: gavel meter, race session, Rojo prototype, Luau tests, syntax checks, debate 001.
- 2026-10-04: agent team, memory docs, Python tests, Luau parity, CI.
- 2026-10-04: v2 model, Luau module, V2 proposal.
