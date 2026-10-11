# Game feel and presentation review: Giddy-Up

Reviewer: creative director, feel and presentation (independent). Date: 2026-10-11. Built from the code alone: the game has never run in Studio.

## 1. Verdict

The race is engineered like a simulation and presented like a spreadsheet. The timing, playback and fairness work is excellent: no lurches, the order on screen is the result, and cues run off the server clock. But a kid sees a silent race (the only sounds are 8 voice lines), a horse that does not react to a Perfect tap, an avatar sitting upright on the horse like it is on a chair, and the same results card for 1st and 8th. The 69 to 140 seconds between "GO!" and the line have one rhythm and no build, and the race never makes a big moment of a win. None of this needs new models. It needs about two weeks of feel work in code, and nearly all of it can sit behind config.

## 2. Top problems, ranked by player impact

**P1. The race has no sound effects and no music.** Size S. No new 3D asset.
Evidence: `game/src/shared/SoundAssets.luau:4-13` holds only `vo_*` ids. `docs/audio/AUDIO_PLAN.md:26` shows all 17 effects as blocked. `Sound.luau:72` plays nothing for a missing id. So `gallop_loop`, `gate_bell`, `tap_good`, `burst_whoosh`, `finish_fanfare` and `crowd_cheer` (cued at `RaceController.client.luau:1330-1340, 1503, 1688`) are all silent, and there is no music anywhere in the plan.
Why it hurts: half of game feel is sound. A tap with no click feels broken, and a finish with no crowd feels empty. Kids will read the silence as lag.
Fix: stop waiting on the ElevenLabs key. Add `shared/SoundOverrides.luau` (name → id, edited by hand) and merge it over the generated `ids` in `Sound.luau:18-21`. Fill it from Roblox-owned free Creator Store audio (hoofbeats, crowd, bell, chime) as stand-ins. Add a `race_music` bed from Roblox's licensed music library, in three layers (`music_gate`, `music_far_turn`, `music_stretch`) cued at the times `RaceController` already computes (`tFar`, `burstOpen`). Add a key `GameConfig.audio.music = true`.

**P2. Taps do nothing you can see on the horse.** Size M. No new 3D asset.
Evidence: `GameConfig.luau:55` `tapNudgeFeet = 2`. That is a quarter of an 8-stud horse at 56 studs/s, so it can't be seen. The feedback word (`RaceController.client.luau:226`, `:615`) swaps text in place with no pop or fade, even though `ART_DIRECTION.md` "Hoof ring → On a tap" asks for both. No dust, speed lines or lean are wired in anywhere: there is no race `ParticleEmitter` or `Trail` in `client/`. `fx_dust_puff` and `fx_mane_flick` exist as art but are never used.
Why it hurts: this is the core verb, repeated 50 to 100 times a race. If the horse doesn't answer the tap, the race feels like a bar minigame with a screensaver behind it.
Fix (the effects are on screen only and never affect ranking, as `RaceView.client.luau:37-39` already guarantees):
- Raise `tapNudgeFeet` to about 5. Log it as a provisional decision.
- Add `GameConfig.raceFx = { perfectFov = 4, trailSeconds = 0.4, dustRate = ... }`.
- In `RaceView`, on `RaceState.nudgeAt`: attach two `Trail`s to the horse's flanks for 0.4 s, emit 6 `fx_dust_puff` particles from the hooves, and pitch the body forward 3°. On Perfect, add a camera FOV kick of +4 over 150 ms.
- Animate the feedback label with a UIScale tween: 0.6 → 1.0 Back Out over 100 ms, hold 350 ms, fade over 150 ms.
- Every effect is off under `ReducedMotion` except the label.

**P3. The jockey sits on the horse like it is on a chair.** Size M. No new 3D asset.
Evidence: `TrackScene.luau:506` `SIT_ANIMATION` is Roblox's default R15 sit, played on bots at `:563-569`. Riders get the same pose from `Seat:Sit` (`:597`). The crouch and pump in `ASSET_PLAN.md` item 15 is still "To do in Studio".
Why it hurts: in the chase view (`RaceController.client.luau:106`, zoom 14) the player's own avatar is the biggest object on screen for the whole race. An upright avatar with its legs forward breaks the fantasy every frame.
Fix: author one 1-second looped crouch-and-pump animation in Studio's Animation Editor (free, owned by the group, never a whip). Play it on bots and on the local rider's Animator, and set its speed from the stride rate so the pump matches the legs. Add the key `GameConfig.raceView.jockeyAnim`. Keep the sit as the fallback.

**P4. The body bob is out of step with the legs.** Size S. No new 3D asset.
Evidence: `RaceView.client.luau:60` `BOB_HZ = 1.8`, and `:431` `abs(sin)` gives 3.6 bobs per second. The legs run at 56/18 ≈ 3.1 strides per second (`HorseLegs.luau:22`). The two drift in and out of phase about every 2 seconds, so the horse looks like it swims. The art direction's rule "squash lands exactly on the beat" isn't met either.
Fix: have `HorseLegs` keep each horse's phase and add `HorseLegs.phaseOf(horse)`. Compute the bob from that phase: lowest point at the forefoot plant, Y squash 0.96 for 60 ms, pitch ±3°. Emit the dust puff on the same plant. This fixes it for replays too, since `RaceState.placeHorse` is shared.

**P5. Every finish gets the same ending: no win moment, no ribbon moment.** Size M. No new 3D asset.
Evidence: `RaceController.client.luau:1672-1690` sets the text "And they're home!" (`:1682`), then after `runInSeconds` shows the same dark card (`:401`, `showResults` at `:1610`) for every place. The live camera stays on Follow, and the horses stop dead within `PAST_LINE = 0.012` of the race length (`RaceView.client.luau:61`), about 46 studs in a Sprint.
Why it hurts: winning is the reward the whole loop builds toward, and it lands as a text label. Losing also needs a kind landing, and right now it gets the same dead card.
Fix:
- Add a short finish sequence from `RaceState.setFinal` on the rider's screen only. Over 2.5 s a scriptable camera arcs around your horse, reusing the replay's side-on rig (`Replay.client.luau:402-429`).
- 1st: confetti `ParticleEmitter` bursts at the finish post, a gold `Highlight` on the horse, and a big blue-ribbon stamp.
- 2nd to 4th: the matching ribbon stamps onto the card.
- 5th to 8th: "Great ride!" with the ride stars counting up, one chime per star. This is about the rider's skill, never placement, so it is kid-safe.
- Raise `PAST_LINE` to about 0.04 so the field gallops out past the line.
- Add `GameConfig.finishFx = { enabled, orbitSeconds = 2.5 }`. ReducedMotion skips the orbit.

**P6. The start is a hard teleport.** Size S/M. No new 3D asset.
Evidence: `RaceService.server.luau:669` `tStart = now() + COUNTDOWN` (3 s). The rider is seated at `:757`. The camera snaps into the saddle at "3" (`RaceController.client.luau:1351-1357`).
Why it hurts: the build-up before the gate is where the excitement starts. Right now a kid is pulled out of the barn mid-step and the bell rings almost at once.
Fix: raise `gateCountdownSeconds` to 5. Fade the screen to white over 0.3 s around the seat. Then add a 2-second "line-up" dolly along the gates showing each lane badge and rider name, then "3, 2, 1". Gate the whole sequence with `GameConfig.raceIntro.enabled`.

**P7. The middle of the race is flat.** Size M. No new 3D asset.
Evidence: one slider with one rhythm, about 57 passes in a Rookie Sprint (sweep 2.4 s, `GameConfig.luau:455`). Checkpoints are just hint text (`RaceController.client.luau:1495`). The place badge swaps text with no pop (`:1176`). There are only three voice lines between "off" and the burst.
Fix:
- Turn each `PaceResult` into a beat: a banner sweeps in with 1 to 3 stars stamped in, a crowd swell, and a +1 music layer.
- Pop the place badge (UIScale 1.25 → 1, plus a tick) when your place improves. Don't pop it when you lose a place.
- Add an FOV ease of +3 down the backstretch and +5 at the burst.
- Separately, measure attention at Sprint length in the playtest before anyone touches `raceSpeedStudsPerSecond` (that change touches steering calibration).

**P8. The track does not match the art direction.** Size M. No new 3D asset by default.
Evidence: the grandstand is grey concrete and brick (`TrackScene.luau:36-44, 197-258`). It has no bunting and no crowd, and the Big Board shows a static "GIDDY-UP!" (`:265-288`). The race HUD uses dark-green boxes (`RaceController.client.luau:204, 337, 401`) and GothamBlack instead of Paper, Ink and Fredoka. The speed meter is a red-to-green gradient (`:324`), which `ART_DIRECTION.md` forbids. The YOU marker sits 12 studs up with AlwaysOnTop (`:1380`), right in the middle of the chase view.
Fix:
- Build bunting from WedgeParts in lane colours along the roof edge and the homestretch rail.
- Make the crowd from billboard sprites drawn by `make_ui_svgs.py` (free) and bob them with the music.
- Have the client fill the Big Board with the live top 4 as lane chips.
- Restyle the HUD with `Ui.colors` paper and ink.
- Change the speed meter to gold over slate.
- For the rider in the chase view, lower the YOU marker to 7 studs and shrink it to 60 px. Keep it full size for spectators and replays.

### Meshy (45 credits), ranked
1. **Nothing for P1 to P7.** All of them are code, tweens, particles, camera and sound.
2. If the billboard crowd reads badly in Studio: one `crowd_bench_block` text-to-3D (30 credits), a short bench of chunky toy-style fans, tiled along the tiers.
3. A `retexture` of that block in another shirt palette (10 credits) so the tiling doesn't repeat.
4. Hold the last 5 credits.

## 3. What is genuinely good, and must not be broken

- **Server-clock cueing** (`cue()` in `RaceController.client.luau:58`): every sound and label is placed by time, never by tween completion. New effects must go through it.
- **Timestamped playback** (`Playback`, `RaceView.client.luau:365-372`) and **no reshuffle at the line** (D-055): horses never lurch and the order on screen is the result. Any new nudge must stay draw-only.
- **Distance-driven legs** (`HorseLegs.step`): no foot sliding, and gaits cross-fade.
- **Steering pose limits**: at most 10° of turn and 3° of lean, and brushes nod with nothing that looks hurt. Kid-safe and readable.
- **The replay**: a broadcast side camera, slow motion only when you won, a photo-finish still, and no shop prompts. This is the best presentation in the game. Reuse its camera rig.
- **ReducedMotion is respected** everywhere, there are no full-screen flashes, and celebrations play only on your own screen after scoring.
- **Voice lines never overlap**, and spectators hear the race at half volume and only within range.
- **The lighting stack** (`WorldScene.luau:904-930`, a light touch of bloom, atmosphere and sun rays) is tasteful. Don't push it.

## 4. Top 5 must-do, in order

1. **Get sound in now** (P1): `SoundOverrides.luau` filled with Roblox-owned stand-in effects, plus a three-layer race music bed. Size S.
2. **Make taps visible on the horse** (P2): a bigger draw-only nudge, Trails, hoof dust, an FOV kick on Perfect, and the label pop. Size M.
3. **Sync the bob to the legs and add a jockey crouch animation** (P4 + P3): the horse and rider read as one galloping body. Size S + M.
4. **Add a finish sequence for every place** (P5): an orbit camera, confetti for 1st, ribbon stamps for 2nd to 4th, counting stars for everyone, and a gallop-out past the line. Size M.
5. **Add the gate intro and mid-race beats** (P6 + P7): a 5 s countdown with a line-up dolly, checkpoint banners, a place-up pop, and music layers. Size M.

All five are code and config only, and they spend 0 Meshy credits. Each should be logged as a provisional decision with an off switch.
