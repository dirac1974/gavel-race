# Roblox project (Rojo)

Phase 1 prototype: one Rookie race loop with bots, three Giddy-up stretches and a Final Burst (D-022), server-scored taps, live win chances, results, integrity logging. No saving yet.

## Run in Studio

1. Install [Rojo](https://rojo.space) (CLI and Studio plugin).
2. `cd game && rojo serve`
3. In Studio, open a new Baseplate, connect the Rojo plugin, then Play.

## Layout

| Path | Roblox location | What |
| --- | --- | --- |
| `src/shared/` | ReplicatedStorage.Shared | Pure modules: GameConfig, ThemePack, Stride (Giddy-up beats and scoring), BurstMeter (Final Burst), TapTime (latency rules), Integrity (macro detection), RaceRating, RaceSession |
| `../src/RaceMath.luau` | ReplicatedStorage.Shared.RaceMath | Race math (mirrors the Python reference) |
| `src/server/` | ServerScriptService.Server | RaceService: lobby, segment schedule, tap validation, prizes, integrity logging |
| `src/client/` | StarterPlayerScripts.Client | RaceController: hoof-beat ring, burst meter, tap anywhere, board |

Pure modules take their dependencies as arguments and never touch Roblox services, so they are tested under Lune (`lune run tests/luau/run_all`). The server and client scripts were written without Studio access and still need a Studio playtest.
