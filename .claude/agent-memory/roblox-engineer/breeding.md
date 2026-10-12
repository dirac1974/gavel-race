# Breeding (D-080)

- Server: `server/Foals.luau` (module: view, afterRace hook, onLoaded) + `BreedingService.server.luau` (remotes BreedPreview/BreedConfirm/FoalArrive, decorator view.breeding, code-built Foal Barn). RaceService calls `Foals.afterRace` once after `Profile.recordRace`.
- Don't edit `shared/Breeding.luau` (model engineer owns it, parity with src/breeding.py). Save repair lives in `Profile.repairBreeding` (pending + nextAt).
- Foal look: `HorseLook.foal/shapeFoal/raceScale` driven by `GameConfig.foalLook`; shape before welding (Rides) and before measuring the saddle (TrackScene).
- `breeding.enabled` must equal `career.suggest` (tests check); tests that flip config must restore the previous value.
- Python heredocs turn `\n` in strings into real newlines: use the Write tool for helper scripts.
