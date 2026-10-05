# Audio plan: Giddy-Up

Status: voice lines made, uploaded and approved by Roblox moderation (2026-10-05); sound effects waiting on an ElevenLabs key permission (see "Blocked" below). Tone: County Fair Toy (docs/art/ART_DIRECTION.md): warm, sunny, friendly, short, nothing scary or loud. No wagering words in any prompt or line (CLAUDE.md rule 1; `tests/test_sound_assets.py` checks).

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

David approved up to **2,000 ElevenLabs credits** (2026-10-05). The generator refuses any call whose conservative estimate could take the spend past the budget: sound effects at 40 credits per second of set duration (the highest published rate; auto-duration costs about 100 per effect, so every effect sets its duration), voice at 1 credit per character. Actual voice cost on `eleven_flash_v2_5` was 0.25 credits per character (the `character-cost` response header).

The key has no `user_read` permission, so `GET /v1/user/subscription` returns 401. Spend is measured instead with `GET /v1/usage/character-stats` (cumulative since 2025-10-01) and each response's `character-cost` header.

| Batch | When (UTC) | Usage before | Usage after | Spent | Estimate (upper bound) |
| --- | --- | --- | --- | --- | --- |
| Voice, 8 lines (128 characters) | 2026-10-05 14:43 | 55,641 | 55,670 | **29** | 129 |
| Sound effects, P0 + P1 (21.1 s) | blocked | | | 0 | 844 (1,688 with every re-roll) |
| **Total** | | | | **29 of 2,000** | |

## Sounds

| Name | Priority | What | Length | Estimate | Spent | Roblox asset | Moderation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gallop_loop | P0 | hoofbeats on dirt, seamless loop (`loop: true`) | 2.0 s | 80 | | | not made |
| crowd_cheer | P0 | friendly fair crowd cheer | 3.0 s | 120 | | | not made |
| gate_bell | P0 | starting bell and gate clang | 1.5 s | 60 | | | not made |
| burst_whoosh | P0 | sparkly whoosh for the Final Burst | 1.5 s | 60 | | | not made |
| tap_good | P0 | soft bright tick (Great / Perfect tap) | 0.5 s | 20 | | | not made |
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

Voice: ElevenLabs premade voice Liam (energetic, American), model `eleven_flash_v2_5` (the cheapest; the newer `eleven_v4_turbo` has no published credit rate yet), stability 0.35, speed 1.05. Every line came back clean on the first take (peaks -0.3 to -5.5 dBFS, no clipping, about 0.2 s of tail), so no re-rolls. Lines were checked by level and length only; nobody has listened yet.

## Where each sound plays

| Moment | Sound | Code |
| --- | --- | --- |
| Gate opens | gate_bell + vo_off | `RaceController` (RaceStarted, cued at the start time) |
| Your race runs | gallop_loop (riders only; stops when the race ends) | `RaceController` |
| Field enters the final far turn | vo_far_turn (skipped if under 4 s after the start) | `RaceController` (same sum as RaceService's `tFar`) |
| Final Burst opens | burst_whoosh + vo_burst | `RaceController` (BurstOpened) |
| Great or Perfect tap; great burst | tap_good | `RaceController` |
| Burst window closes | vo_stretch | `RaceController` |
| Leader reaches the line | finish_fanfare + crowd_cheer | `RaceController` (RaceFinished, cued at the finish time) |
| Results card | vo_finish | `RaceController` |
| Photo finish in a replay | vo_photo | `Replay` |
| Any Ui button press | ui_pop (quiet; game buttons with their own sound set `NoPop`) | `Ui.button` |
| Green Cash goes up | coin | `Hud` |
| Feed / groom / treat / pet | munch / brush / munch / horse_nicker, positional at the horse | `CareClient` (CareFx) |
| Harvest | harvest_pop | `CareClient` |
| Job claimed | job_done | `StableBoard` |
| Clap Along | clap | `FanClient` |
| Vet heartbeat game | heartbeat on each beat | `PaddockClient` |
| Start galloping on your own horse | vo_giddyup (at most every 20 s) | `RideClient` |
| Stable loaded (once per visit) | vo_welcome | `Starter` |

Spectators hear race cues at half volume; only riders hear their own hoofbeats. The Settings tab has Sound On/Off (`settings.sound`, on by default); Off mutes the SoundGroup, so loops already playing stop too.

## Blocked: sound effects

`POST /v1/sound-generation` returns 401 "missing the permission sound_generation". David: open https://elevenlabs.io/app/settings/api-keys, edit the key in `ELEVENLABS_API_KEY`, and turn on **Sound Effects** access. Then:

```bash
python tools/audio/generate_audio.py --priority P0 P1
python tools/roblox/upload_assets.py --kind Audio
```

Roblox audio uploads are capped per 30 days: 100 for ID-verified accounts, 10 otherwise. The 8 voice lines used 8; the 15 effects need ID verification on the uploading account (or packing effects into one sheet with `Sound.PlaybackRegion`).
