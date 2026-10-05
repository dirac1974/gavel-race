# Status

Last updated: 2026-10-04

## Current state

- **Race model v2**: Python reference and Luau module agree exactly (300 fixture races, purses and finish orders included).
- **Roblox prototype (Phase 1)**: Rojo project in `game/`. Pure modules (GameConfig, ThemePack, GavelMeter, RaceSession) are tested under Lune. Server loop and client UI are written and compile, but **have not been run in Roblox Studio**.
- **Tests**: 1,080 Python tests; 17,600+ Luau checks; policy guard; syntax check for every Luau file; GitHub Actions runs all of it.
- **Design**: debate 001 decided the gavel meter (D-010). Provisional decisions listed in REVIEW_QUEUE.md.

## In progress

(none)

## Backlog (top = next)

1. **Giddy-up stride stretches (D-022)**: replace the single-tap windows with stride beats in `RaceSession` and a new stride module (Luau, tested under Lune), client UI (closing ring on the hoof, haptics, tap anywhere, labels), bots recalibrated, detection logging of tap-gap vs beat-gap; reuse for Clap Along. Final Burst: one random-start meter tap after stretch 3, weight 2 in `S`. Rename `Gavel*` modules and UI text to Giddy-up.
2. **Debate 002 — first 10 minutes** (onboarding), after stride stretches exist. Energy is decided (D-015); debate 003 is retired.
3. **DataStore layer**: profile schema (horses, stable, currencies), session locking, retries; pure serialization tested under Lune.
4. **Matchmaking**: league queues, Rating bands, party rule (D-006), bot fill.
5. **Anti-cheat**: server-side logging and tap-rate checks; don't flag on high scores alone (catches skilled kids). The tap-time rewind exploit is fixed (D-021); stride stretches (D-022) remove fixed-delay macros; flag beat-tracking bots by tap-gap vs beat-gap spread per D-022, with the rider ladder. Same layer covers Clap Along (D-020): flag timing spread under 12 ms over 48+ beats.
6. **Race presentation**: horses moving on a track, animation driven by the drawn finish order.
7. **Spectator cheering (D-019)**: spectator mode, cheer lock before window 1, Fan XP per tap with per-race and daily caps in `GameConfig.spectator`; tests that riders and their party can't cheer in their own race and that caps hold. Then Clap Along and the crowd boost (D-020): beat schedule from the horse's stride, scoring, crowd = best fan + assists, `c_i` in Python and Luau with parity tests, Top Fans board.
8. **Economy sim v2**: add Energy (D-015) with 1, 2, and 3 horses, plus training, sinks, Diamonds, and Fan XP (check the D-019 20% rule) and recalibrate bot scores for stride stretches, to `sims/economy.py`.
9. **Training and Potential**: how stats grow toward each racer's Potential cap; mirror in Python and Luau.

## Done

- 2026-10-04: tap-time allowance tied to measured latency (D-021), closing the claimed-time exploit.
- 2026-10-04: merged the local PR #1 history into the cloud history (cloud tree kept, as it already contained PR #1's content); refreshed GAME_DESIGN league table; D-018.
- 2026-10-04: merged a parallel review: whole-cash purses (D-017), policy guard in CI, `.claude/settings.json`, `docs/KICKOFF.md`, 567 extra tests.
- 2026-10-04: Energy (D-015), prizes and exactas (D-016), Diamond limits amended (D-002a).
- 2026-10-04: Race Rating formula (D-014) in Python and Luau; prototype races now use random conditions and starter stats.
- 2026-10-04: Studio playtest checklist; economy simulator; Stakes thresholds (D-013).
- 2026-10-04: gavel meter, race session, Rojo prototype, Luau tests, syntax checks, debate 001.
- 2026-10-04: agent team, memory docs, Python tests, Luau parity, CI.
- 2026-10-04: v2 model, Luau module, V2 proposal.
