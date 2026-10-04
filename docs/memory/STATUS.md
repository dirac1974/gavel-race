# Status

Last updated: 2026-10-04

## Current state

- v2 race model: Python reference (`src/gavel_race_v2.py`) and Luau module (`src/RaceMath.luau`) written; Python covered by `tests/`; Luau not yet run in a Luau runtime.
- Game design: `docs/GAME_DESIGN.md` (condensed from the planning doc). No Roblox project yet.
- Agent team, memory docs, CI: set up in this commit.

## In progress

(none)

## Backlog (top = next)

1. **Luau parity**: install `lune` in the cloud environment (setup script or GitHub release), generate JSON fixtures from Python, and test `src/RaceMath.luau` against them.
2. **Rojo skeleton**: create `game/` Rojo project (server/client/shared), move RaceMath into shared, add a ThemePack module with horse names. No gameplay yet.
3. **Server race loop (prototype)**: lobby of 8 with bots, three gavel windows, server-scored taps, live chance updates, finish draw, results. Phase 1 of the roadmap.
4. **Gavel meter feel spec**: triangle-wave meter, speeds and zone widths per league, tap latency allowance. Needs debate 001 output first.
5. **Economy simulator** (`sims/`): cohorts, faucets and sinks, time-to-league targets.
6. **Anti-cheat checks**: tap timestamp validation, sustained S > 95 flagging, party matchmaking rule.
7. **DataStore schema** for horses, stable, currencies, with session locking.

## Done

- 2026-10-04: v2 model, Luau module, V2 proposal, agent team setup.
