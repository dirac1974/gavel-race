# Phase 4 plan: presentation and world (D-069)

Author: the feel reviewer, 2026-10-11. Two developers can work in parallel. RaceController is at its limit for top-level locals, so all new work goes in new modules, each wired in with a single `require`. Every item has a config switch and does nothing under Reduced Motion where noted. Colours come from `docs/art/ART_DIRECTION.md`.

## Phase 3: presentation must-fixes

None. Should-fix: in a Practice race with a friend, put a small 👫 under the friend's lane badge (client only) so each friend can find the other mid-race. Key: `friendRace.badge = true`.

## Dev A: world, track, jockey

**A0. 2D art first; both devs need it.** Draw these in `tools/ui/make_ui_svgs.py`, then upload them (images, not audio):
- `bunting_strip`: triangles in Giddy-up orange `FF9F1C`, Gold `FFD23F`, Sky `8ED6FF`, Teal `17A398` and Paper `FFF7E6` on a transparent background.
- `crowd_strip`: a tileable row of chunky toy fans, about 1 × 4 studs per tile, in four shirt palettes, waving arms, never holding paper slips or tickets.
- `confetti_square`.
- `flag_pennant`.

**A1. `client/JockeyPose.luau`**, driven from `RaceView.client.luau`.
- Every jockey on the screen's courses, bots and riders, gets a crouch: Waist forward 35°, hips -70°, knees +100°, shoulders forward 55°, elbows 70°, neck -15°. Write it to R15 `Motor6D.Transform` in `RunService.PreSimulation`, which runs after the Animator, so the sit track is overridden without being stopped.
- The pump: Waist ±4°, shoulders ±10° and Root rise 0.12 studs, once per stride, from `HorseLegs.phaseOf(horse)`.
- R6 rigs keep the sit.
- Never a whip or crop pose: arms go forward along the neck.
- Config: `jockeyPose = { enabled, waistDeg = 35, hipDeg = -70, kneeDeg = 100, shoulderDeg = 55, elbowDeg = 70, pumpDeg = 4, riseStuds = 0.12 }`.
- Accept when:
  - in the chase view the rider's back is under 45° from horizontal;
  - the pump lands on the beat and stays in step with the hoof dust;
  - feet don't sink into the horse (tune in Studio);
  - it works on the local rider and on bots;
  - the replay poses the same way (through `RaceState.placeHorse`).

**A2. `server/TrackDressing.luau`**, called once from `TrackScene.buildVenue`.
- Bunting:
  - Beams textured with `bunting_strip` (TextureMode Wrap, CurveSize 1.5 to sag) along the roof edge every 40 studs, from `standZ0` to `standZ1`.
  - Bunting on 8-stud posts along the outer homestretch rail, from the furlong pole before the finish to 200 studs past it.
  - The Twin Spires get pennants.
- Flags: flagpoles on the roof every 80 studs, each with a `flag_pennant` decal.
- Crowd: a `Texture` with `crowd_strip` (StudsPerTile 4 × 1) on the track-facing face of each `StandTier`. No new parts.
- Fallback: if an id isn't uploaded yet, use WedgePart triangles, at most 300.
- Budget: at most 350 new parts and 80 Beams.
- Config: `trackDressing = { enabled, bunting, flags, crowd }`.
- Accept when:
  - from the chase camera on the homestretch, bunting and crowd are on screen;
  - the Studio part count rises by at most 350;
  - phone frame time is unchanged within 1 ms.

**A3. `client/TrackLife.client.luau`.**
- The crowd bounces: `Texture.OffsetStudsV` moves ±0.12 at 1.5 Hz in the lobby and ±0.3 at 3 Hz from the burst until the card shows. Off under Reduced Motion.
- Flags flutter: ±6° of yaw on a sine.
- The Big Board: build a client-side SurfaceGui on `BigBoard` showing the focused race's top 4 from `RaceState.order` (lane chip, number, horse name), refreshed at 4 Hz. When no race is running it shows the "GIDDY-UP!" idle. No win %, no purse (rule 1, D-055).
- Config: `bigBoard.live = true`.
- Accept when the board order matches the place badge at every checkpoint.

## Dev B: HUD, camera, music, finish polish

**B1. `client/GateIntro.luau`.** It runs in the countdown, not in the lobby wait: taking the camera during the wait would pull kids out of grooming (D-061). The countdown stays at 3 s.
- At seating (`start - 3`), the camera goes Scriptable and dollies in front of the gate from lane 8 to lane 1 at height 7, looking at the horses' faces, over `dollySeconds = 1.6`.
- It then blends over 0.4 s to behind your horse and hands back to Follow at `start - 1.0`.
- "3, 2, 1" still shows.
- It applies to riders only, never under Reduced Motion, and never to spectators.
- Config: `raceIntro = { enabled, dollySeconds = 1.6, blendSeconds = 0.4, handBackBefore = 1.0 }`.
- Accept when the Follow camera is live at least 0.8 s before GO, the first pass is never missed, and a late seat skips straight to the chase view.

**B2. `client/RaceHudStyle.luau`**, plus the YOU marker.
- `RaceHudStyle.apply(gui)` restyles RaceController's existing instances by name: Paper `FFF7E6` panels, a 2–3 px Ink `1D2433` UIStroke, Fredoka One for labels, Builder Sans Bold for numbers, Gold `FFD23F` count with an Ink stroke, the slider track in Slate `2A3247`, the glow in Gold.
- No `20,30,25` greens remain.
- Accept when a grep for `fromRGB(20, 30, 25)` in the race HUD finds nothing at runtime and the text contrast is ≥ 4.5:1.
- YOU marker, for the rider in the chase view: `StudsOffsetWorldSpace` 7, size 56 × 72 px, hidden in first person (zoom < 2) and during the finish orbit. Spectators and replays keep 12 studs and 90 px.
- Config: `raceHud.youMarker = { riderStuds = 7, riderPx = 56, otherStuds = 12, otherPx = 90 }`.
- Accept when, on a 667 × 375 screen, the marker never overlaps the middle third of the screen at chase zoom.

**B3. `client/MusicBed.luau`.**
- **Decision: don't spend the last audio upload on a synthesized pad.** Keep that slot for an emergency, such as the sheet being Rejected or the gallop loop re-render. Use a beatless track from Roblox's free licensed music library, which costs no upload. David picks the id.
- Config: `audio.music = { id = 0, lobby = 0.35, race = 0.12, finish = 0.4, fadeSeconds = 0.6, duckUnderVoice = 0.5 }`. While `id = 0`, there is no music.
- Behaviour: ducked to `race` while the slider runs, so it never competes with the tap tick, and ducked further while any `vo_` line plays (`Sound.recent`). It respects the Sound setting.
- Accept when a kid can still hear every tap tick over the music.

**B4. Finish polish (`FinishMoment.luau`, `ResultsCard.luau`).**
- Confetti uses `confetti_square`.
- The dim is Ink at 0.75: `finish.dimColour`, `finish.dim = 0.75`.
- Ribbon placeholder colours become `2F6FDE`, `E0474C`, `FFD23F` and `FFFFFF`.
- The stamp sound is `bump_soft` at speed 0.8 plus `tap_good`, replacing `ui_pop`.
- For 1st, a second `crowd_cheer` plays at your crossing.
- The card's stars count in at 0.2 s each with `tap_ok` at speeds 1.0, 1.15 and 1.3. Under Reduced Motion they show at once.

## Meshy: spend 0 credits now

Code, Beams, Textures and 2D strips cover every item above. Hold all 45 credits. Only if the playtest shows the textured crowd reads flat from the chase camera, spend 30 on a `crowd_bench_block` and 10 on a retexture with a second palette. Nothing else in Phase 4 needs a model.

## Order and handoff

A0 → (A1, A2, A3) and (B1, B2, B3, B4) in parallel. Then the test-engineer adds pure tests (pose angles from phase, dolly timing, ducking levels, a dressing part-count cap), the code-reviewer runs, and I consult.
