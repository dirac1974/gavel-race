# Status

Last updated: 2026-10-05

## Current state

- **Race model v2**: Python reference and Luau module agree exactly (300 fixture races, purses and finish orders included).
- **Roblox prototype (Phase 1)**: Rojo project in `game/` with three Giddy-up stretches and a Final Burst (D-022). Pure modules (GameConfig, ThemePack, Stride, BurstMeter, TapTime, Integrity, RaceRating, RaceSession) are tested under Lune; stride scoring has a Python mirror with parity tests. Server loop and client UI are written and compile, but **have not been run in Roblox Studio** (see `game/PLAYTEST.md`).
- **Tests**: 1,632 Python tests; 76,000+ Luau checks; policy guard; syntax check for every Luau file; GitHub Actions runs all of it.
- **Art**: playtest art (D-023) is uploaded and wired in; the place must be published to the LlamaWorks group to load it.
- **Race shape (D-033)**: secret luck at the gate gives the same Harville odds as an exponential race; luck shows from the far turn, so comebacks happen on screen while taps still count. Replays of the finish or the whole race (D-034).
- **Design**: debate 007 replaced the gavel meter with Giddy-up stretches and the Final Burst (D-022). Provisional decisions listed in REVIEW_QUEUE.md.

## In progress

(none) — the world build (Stages 1–10, D-035 to D-049) is merged. Nothing has been run in Roblox Studio yet: the next step is David's playtest with `game/PLAYTEST.md`.

## Backlog (top = next)

1. **Studio playtest of the world** (David): `game/PLAYTEST.md`, every section; enable API access in Game Settings → Security to test saving. Fix what breaks.
2. **Sound effects**: generate and upload the 15 effects once the ElevenLabs key has Sound Effects access (docs/audio/AUDIO_PLAN.md); the code already plays them when their ids arrive. Then listen in Studio and tune `LEVEL` in `Sound.luau`.
3. **Training rides** (D-053): ~~Training Ground and oval (T1)~~ done, ~~server-scored Sprint Lane + Mud Splash (T2)~~ done (PR, not yet run in Studio); ~~Gate Break + Hill Climb + Easy Rein (T3)~~ done (PR, not yet run in Studio); next ghosts / rosettes / Ride together / server Quick Train (T4). Plan: docs/debates/009. David asked for this 2026-10-05 ("You should run around with the horse").
4. **Race steering** (D-054): ~~Python trip model + calibration (S0)~~ done 2026-10-05 (`src/trip.py`, `sims/steering.py`, docs/research/steering-calibration.md); next rail coordinates + random posts (S1), Smart Steer on the server (S2, mirror `src/trip.py` and `tests/fixtures/trip.json`), rider controls (S3), replays and results (S4). Plan: docs/debates/010. David asked for this 2026-10-05.
5. **Economy sim v2** (`sims/economy.py`): Energy, training cap, Feed & Seed and market prices, stall costs, jobs ≤ 10% of race income, Cup purses; tune from playtest data.
6. **Breeding** (D-047): foal Potential 0.7 × parents + 0.3 × breed ± 5, foals at 35% of Potential; run the bloodline sim first. Foal models exist (`foal_stand_*`).
7. **Running styles** (debate 008 research): style-shaped skill offsets before the far turn; show the style before the gate.
8. **Fan cosmetics**: Fan level badges, stand flags and titles for Fan XP (D-019); monthly stamp cosmetic for jobs (D-043).
9. **Clubs and Friend Races** (D-006, D-042): party rule for cash races, Friend Races, Club visit setting.
10. ~~Diamond store~~: built (D-050). David to create the three developer products and paste their ids into `DiamondProducts.luau`.
11. **Cross-server Cup finals and Derby Day** (D-036 later).
12. **"How races work"**: a 20 s animation for kids (the For grown-ups page has the text).
13. **Anti-cheat tooling**: save Integrity trackers in the profile, review tool, "Ask for a check" button; turn off log-only after a month.
14. **Performance pass**: StreamingEnabled check, model counts on phones (58 models in ReplicatedStorage), trees and fences.
## Done

- 2026-10-05: race steering S0 (D-054): Python trip model (lanes, holds, tuck-in, Smart Steer, ground and draft, τ), `live_chances(..., extra)`, calibration sim with the generated per-post baseline (2,000 bot-mix races per course × distance), Luau parity fixtures (`trip.json`, `race_math.json` extraCases). After review: post baseline built for Smart Steer kids (per-post bias ≤ 0.002 among bots and in all-Smart lobbies), gaps move like RaceView (D-055), the mover never pushes the horse behind; every target met per course × distance with `groundPerLaneTurn` 0.010, `draftPerSecond` 0.0010, `tuckBackMax` 24 and `bots.wideShare` 0.20; the full report is stored and asserted by tests.
- 2026-10-05: training rides T3 (D-053): Gate Break (practice gate, bell from the seed, early go reruns once, latency allowance) and Hill Climb (Pip the lead pony, ring scoring) scored by the server; all four courses open; Easy Rein in Settings.
- 2026-10-05: training rides T1 + T2 (D-053): the Training Ground (oval with a hill, hoops, practice gate, path from the paddock's new south gate), the Mud Splash gymkhana in the paddock arena, server-scored Sprint Lane and Mud Splash, the course picker with Quick train, end card with stars and ribbons. Gate Break and Hill Climb show "Coming soon" until T3.
- 2026-10-05: play-test quirks (debate 011): QA audits of the race and the riding world (Lune sims); race fixes and race feel (D-055) merged: the order across the line is the result, no lurches, countdown, bounce-proof taps, phone HUD, spectating only near the course. Riding and world fixes (D-056) follow in the riding-feel PR after the training PR.
- 2026-10-05: sound (D-052): `Sound.luau` with race cues, UI pops, care and job sounds, Sound On/Off setting; 8 announcer lines generated (29 ElevenLabs credits) and uploaded to Roblox (all approved); sound effects waiting on the key permission.
- 2026-10-05: world build merged (PRs #17–#27): saving and owning horses, the world (Fair Street, Barn Lane, riding, map), care and food, two courses with the Race Board, Stable Board jobs, training and the vet, spectators (cheer, Clap Along, Fan XP), more horses (market, taming, stalls), leagues (Cups, Practice, Hall of Fame), polish (tour, settings, For grown-ups). Art pass (#20): 51 Meshy models and 66 icons uploaded; Meshy balance 460.
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
