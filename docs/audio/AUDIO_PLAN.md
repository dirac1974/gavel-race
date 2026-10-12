# Audio plan: Giddy-Up

Status: voice lines made, uploaded and approved by Roblox moderation (2026-10-05); ElevenLabs sound effects waiting on a key permission (see "Blocked" below), so every effect plays a synthesized stand-in from one sound sheet for now (see "Stand-in sound sheet", 2026-10-11). Tone: County Fair Toy (docs/art/ART_DIRECTION.md): warm, sunny, friendly, short, nothing scary or loud. No wagering words in any prompt or line (CLAUDE.md rule 1; `tests/test_sound_assets.py` checks).

## Pipeline

| Step | Command | Writes |
| --- | --- | --- |
| Plan and estimate | `python tools/audio/generate_audio.py --plan` | nothing |
| Generate (priority order) | `python tools/audio/generate_audio.py --priority P0` then `P1`, `VO` | `assets/audio/<name>.mp3`, `tools/audio/ledger.json` |
| Re-roll once | `python tools/audio/generate_audio.py --reroll <name>` | first take kept in `assets/audio/takes/` (gitignored) |
| Upload to Roblox | `python tools/roblox/upload_assets.py --kind Audio` | `tools/roblox/uploaded.json`, `game/src/shared/SoundAssets.luau` |
| Moderation check | `python tools/roblox/upload_assets.py --moderation --kind Audio` | moderation state in `uploaded.json` |

The list (names, prompts, durations, lines) is `tools/audio/sounds.json`. The game plays sounds through `game/src/client/Sound.luau`; a name with no uploaded id plays nothing, so sounds can arrive one at a time.

## Budget

David approved up to **2,000 ElevenLabs credits** (2026-10-05). The ledger keeps that cap; `--budget` can lower it for a run but never raise it. Each paid call is saved to the ledger (atomically) the moment it returns, before any other request, and a call lost to a network error or timeout is logged as `uncertain` at its full estimate. The generator refuses any call whose conservative estimate could take the spend past the budget: sound effects at 40 credits per second of set duration (the highest published rate; auto-duration costs about 100 per effect, so every effect sets its duration), voice at 1 credit per character. Actual voice cost on `eleven_flash_v2_5` was 0.25 credits per character (the `character-cost` response header).

The key has no `user_read` permission, so `GET /v1/user/subscription` returns 401. Spend is measured instead with `GET /v1/usage/character-stats` (cumulative since 2025-10-01) and each response's `character-cost` header.

| Batch | When (UTC) | Usage before | Usage after | Spent | Estimate (upper bound) |
| --- | --- | --- | --- | --- | --- |
| Voice, 8 lines (128 characters) | 2026-10-05 14:43 | 55,641 | 55,670 | **29** | 129 |
| Sound effects, P0 + P1 (22.4 s) | blocked | | | 0 | 896 (1,792 with every re-roll) |
| **Total** | | | | **29 of 2,000** | |

## Sounds

| Name | Priority | What | Length | Estimate | Spent | Roblox asset | Moderation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gallop_loop | P0 | hoofbeats on dirt, seamless loop (`loop: true`) | 2.0 s | 80 | | | not made |
| crowd_cheer | P0 | friendly fair crowd cheer | 3.0 s | 120 | | | not made |
| gate_bell | P0 | starting bell and gate clang | 1.5 s | 60 | | | not made |
| count_tick | P1 | soft drum tick for "3, 2, 1" (a drum, not a bell: D-054's lane lock uses bell ticks; D-055) | 0.5 s | 20 | | | not made |
| lock_tick | P1 | soft bell ting, three before the lanes lock at the far turn (D-054 S3) | 0.8 s | 32 | | | not made |
| bump_soft | P1 | soft padded thump as two horses brush shoulders (D-057 N5; not `brush`, which is grooming) | 0.5 s | 20 | | | not made |
| burst_whoosh | P0 | sparkly whoosh for the Final Burst | 1.5 s | 60 | | | not made |
| tap_good | P0 | soft bright tick (Great / Perfect tap) | 0.5 s | 20 | | | not made |
| tap_ok | P1 | tiny wooden tick on every counted tap, pitched by score at runtime (`speed`) | 0.5 s | 20 | | | not made |
| finish_fanfare | P0 | short cheerful brass flourish | 2.5 s | 100 | | | not made |
| ui_pop | P0 | soft button pop | 0.5 s | 20 | | | not made |
| coin | P0 | Green Cash chime | 1.0 s | 40 | | | not made |
| horse_nicker | P0 | soft friendly nicker | 1.5 s | 60 | | | not made |
| brush | P1 | grooming brush strokes | 1.5 s | 60 | | | not made |
| munch | P1 | horse munching a carrot | 2.0 s | 80 | | | not made |
| harvest_pop | P1 | crop pulled from the soil | 0.8 s | 32 | | | not made |
| job_done | P1 | reward sparkle | 1.5 s | 60 | | | not made |
| clap | P1 | single hand clap (Clap Along) | 0.5 s | 20 | | | not made |
| heartbeat | P1 | gentle stethoscope lub-dub (vet game, one per beat) | 0.8 s | 32 | | | not made |
| vo_off | VO | "And they're off!" | 0.98 s | 16 | 4 | 130778732640541 | Approved |
| vo_far_turn | VO | "Into the far turn!" | 1.35 s | 18 | 4 | 80734371828506 | Approved |
| vo_burst | VO | "Final Burst!" | 0.98 s | 12 | 3 | 97283117250795 | Approved |
| vo_stretch | VO | "Down the stretch they come!" | 1.39 s | 27 | 6 | 74640240555284 | Approved |
| vo_finish | VO | "What a finish!" | 1.07 s | 14 | 3 | 115641721595924 | Approved |
| vo_giddyup | VO | "Giddy-up!" | 0.88 s | 9 | 2 | 136221961883615 | Approved |
| vo_welcome | VO | "Welcome to Giddy-Up!" | 1.16 s | 20 | 4 | 106737745847156 | Approved |
| vo_photo | VO | "Photo finish!" | 1.02 s | 13 | 3 | 112611222026285 | Approved |

Voice: ElevenLabs premade voice Liam (energetic, American), model `eleven_flash_v2_5` (the cheapest; the newer `eleven_v4_turbo` has no published credit rate yet), stability 0.35, speed 1.05. Every line came back clean on the first take (peaks -0.3 to -5.5 dBFS, no clipping, about 0.2 s of tail), so no re-rolls. **The voice files peak at -0.3 dBFS**, close to full scale, so `VOICE_LEVEL` in `Sound.luau` plays them at 0.7. Lines were checked by level and length only; nobody has listened yet. **Listen to every line in Studio (and on a phone) before publishing**, and tune `VOICE_LEVEL` and `LEVEL` there.

## Where each sound plays

| Moment | Sound | Code |
| --- | --- | --- |
| Countdown | count_tick on "3", "2" and "1" (D-055) | `RaceController` (RaceStarted) |
| Lanes lock at the far turn | lock_tick three times, a second apart, before "Lanes locked!" (riders with the steering buttons only; D-054 S3) | `RaceController` (TripInfo) |
| Two horses brush shoulders (D-057 N5) | bump_soft at half volume (`steerView.brushVolume`), positional at the horse that pressed, as the screen draws the brush | `RaceView` (SteerBrush) |
| Gate opens | gate_bell, then vo_off 0.25 s later so they don't stack | `RaceController` (RaceStarted, cued at the start time) |
| Your race runs | gallop_loop (riders only, while in the saddle; stops when the race ends, you leave the saddle or respawn) | `RaceController` |
| Field enters the final far turn | vo_far_turn (skipped if under 4 s after the start) | `RaceController` (same sum as RaceService's `tFar`) |
| Final Burst opens | burst_whoosh + vo_burst | `RaceController` (BurstOpened) |
| Great or Perfect tap; great burst | tap_good | `RaceController` |
| Burst window closes | vo_stretch | `RaceController` |
| Leader reaches the line | finish_fanfare + crowd_cheer | `RaceController` (RaceFinished, cued at the finish time) |
| Results card | vo_finish (only if the screen still follows that race) | `RaceController` |
| Photo finish in a replay | vo_photo | `Replay` |
| Any Ui button press | ui_pop (quiet; game buttons with their own sound set `NoPop`) | `Ui.button` |
| Green Cash goes up | coin; held while you ride and played with your results card (the prize lands just before the leader reaches the line, so an early chime would give the result away); skipped right after job_done | `Hud` |
| Feed / groom / treat / pet | munch / brush / munch / horse_nicker, positional at the horse | `CareClient` (CareFx) |
| Harvest | harvest_pop | `CareClient` |
| Job claimed | job_done | `StableBoard` |
| Clap Along | clap | `FanClient` |
| Vet heartbeat game | heartbeat on each beat | `PaddockClient` |
| Start galloping on your own horse | vo_giddyup (at most every 20 s; cuts the Gallop button's pop) | `RideClient` |
| Stable loaded (once per visit) | vo_welcome | `Starter` |

Riders always hear their own race. Spectators hear race cues at half volume, and only when their character is within about 250 studs of that race's course (`SPECTATOR_HEARING_STUDS` in `RaceController`, measured from the course's outer edge with `TrackLayout.distanceToTrack`; the infield counts as at the track). Only riders hear their own hoofbeats. The Settings tab has Sound On/Off (`settings.sound`, on by default); Off mutes the SoundGroup, so loops already playing go quiet too, and a loop started while Off is heard once Sound is back On.

## Stand-in sound sheet

Until the ElevenLabs effects exist, every effect in `sounds.json` (including `tap_ok`) has a synthesized stand-in, all packed into **one** Audio upload, so the 30-day audio cap isn't spent per effect.

| Step | Command | Writes |
| --- | --- | --- |
| Synthesize and pack | `python tools/audio/synth_sheet.py` | `assets/audio/sound_sheet.wav` (mono 16-bit 44.1 kHz, 27 s), `tools/audio/sheet.json` (name -> start, length, loop), `assets/audio/synth_preview/<name>.wav` (gitignored), `game/src/shared/SoundSheet.luau` |
| Upload (one audio upload) | `python tools/roblox/upload_assets.py --kind Audio --only sound_sheet` | record `sound_sheet` in `uploaded.json`, its id in `SoundSheet.luau` |

- Uploaded 2026-10-11 as asset **87356614588667**; moderation was `Reviewing` at upload. Until it is Approved the clips play nothing in game; a Rejected sheet drops to id 0.
- Synthesis is numpy-only and seeded: bells and chimes are additive and FM, the gallop is four strides of a four-beat hoof pattern rendered round a circle (a seamless 2.0 s loop), the crowd is filtered noise, formant voices and claps under a gentle swell. Every clip is band-limited to 35 Hz to 9 kHz, de-clicked, and peak-normalized to -3 dBFS. Clips start on a 10 ms grid with 0.25 s of silence between them.
- `Sound.luau` plays a name's own uploaded id first; with none, it plays that name's clip from the sheet (`PlaybackRegionsEnabled`, `PlaybackRegion`, and `LoopRegion` for loops). An ElevenLabs effect uploaded later replaces its stand-in with no code change.
- `Sound.play(name, volume?, at?, speed?)` and `Sound.loop(name, volume?, speed?)` take an optional `PlaybackSpeed` (clamped 0.25 to 4), for `tap_ok` pitched by score.
- The sheet's offsets are tied to the uploaded file: `synth_sheet.py` keeps an uploaded sheet unless run with `--rebuild` (which needs another audio upload), and `SoundSheet.luau` gets id 0 if the file on disk no longer matches the upload. To drop a clip that sounds wrong without re-uploading, add its name to `MUTED` in `synth_sheet.py` and re-run it.
- **Nobody has listened yet**, `horse_nicker` (a pitched, fluttering formant voice) especially. Listen to the previews and in Studio, on a phone too, then tune `LEVEL` in `Sound.luau` or mute clips.

## Blocked: sound effects

`POST /v1/sound-generation` returns 401 "missing the permission sound_generation". David: open https://elevenlabs.io/app/settings/api-keys, edit the key in `ELEVENLABS_API_KEY`, and turn on **Sound Effects** access. Then:

```bash
python tools/audio/generate_audio.py --priority P0 P1
python tools/roblox/upload_assets.py --kind Audio
```

Roblox audio uploads are capped per 30 days: 100 for ID-verified accounts, 10 otherwise, so `upload_assets.py --force` re-uploads sounds only with `--kind Audio`, and an upload request is never resent when it may already have gone through. Sounds that moderation marks Rejected are left out of `SoundAssets.luau`. The 8 voice lines used 8; the 19 effects need ID verification on the uploading account (or another packed sheet). The stand-in sheet used the 9th.
