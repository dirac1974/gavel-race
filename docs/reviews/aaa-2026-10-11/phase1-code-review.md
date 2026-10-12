# AAA Phase 1 (D-066): code review

Reviewed 2026-10-11 by code-reviewer against `CONSENSUS.md` Phase 1 and its cross-cutting rules. Scope: the uncommitted working tree on `claude/aaa-review` (diff against HEAD), Phase 1 files only. `sims/economy.py`, `tests/test_sims.py` and the Phase 3 docs were left out, as asked.

Checks run:
- `python -m pytest -q`: **1719 passed, 4 xfailed**. Lune is on PATH, so the Luau parity, `race_fx_tests` and the burst fixtures ran.
- `bash scripts/policy_guard.sh`: **exit 0**. No wagering words, no model names.

## What holds up

- **Burst arming matches everywhere.** `BurstMeter.armed/tapScore` (Luau), `burst_meter.armed/tap_score` (Python), `RaceSession:submitBurst` (server) and `tap()` in `RaceController` all use `t - open >= burstArmSeconds`. 200 fixture cases check parity, including the arm-minus-1e-6 boundary.
- **A tap before the burst arms is never credited.** `TapTime.resolve` returns either the claimed time or the later arrival time, so the resolved time is never earlier than the claim. A tap the client saw as armed is armed on the server, and a pre-arm claim (or a future claim that falls back to a pre-arm arrival) returns nil before `lane.scores[seg]` is written. The rider's one tap stays available, and `game_tests.luau:357-363` tests this. Spamming early taps costs the server the same as spamming taps after the first one did before. I found no new exploit.
- **Every league still gets a full sweep after arming.** `game_tests.luau:72` checks `windowSeconds - burstArmSeconds >= sweepSeconds` for every league. The marker keeps its random start (D-022), and the fixed-delay macro test still holds.
- **The effects are draw-only.** The nudge only changes `shown`. `RaceState.progress[i]` (rank, place badge, replay frames) still uses `p`. Surge, dust, trails and kicks never touch RaceSession, Trip, RaceShape, PaceMeter, Playback or RaceService, and `race_fx_tests.luau` checks for that by source search. `Trip.frame` is untouched.
- **The FOV caps hold.** There is one owner, RaceController. `RaceFx.fov` clamps the total to `fovMaxDeg` (6). The Perfect kick is 1.5° and fires at most every 0.8 s. The burst kick is 4°. Reduced Motion blocks new kicks and clears running ones.
- **The Sound sheet fallback is correct.** A name's own id wins over the sheet. Id 0 and a missing sheet both play nothing, and nothing errors into the caller. Regions are set before parenting, `LoopRegion` is set only for loops, and `rewind` puts `TimePosition` at `clip.start`. Sound Off still mutes the group, so loops keep working. `upload_assets.py` drops the sheet id to 0 when the sheet is Rejected or the file's hash changes. The checked-in wav's sha256 matches `uploaded.json`.
- **Per-frame cost is low.** `aheadScratch` is reused. The per-frame cost is one `phaseOf`/`bob` call and value-type CFrames. Dust is 1 particle a stride and 6 on a surge, with a 0.45 s lifetime. Reduced Motion is cached at 2 Hz in RaceView.

## BLOCKING

### B1. The dust and trail attachments are placed in world coordinates as if they were local offsets
`game/src/client/RaceView.client.luau:409-410`
```lua
a.WorldPosition = (box * CFrame.new(offset)).Position
a.Parent = body
```
`WorldPosition` is set while the Attachment has no parent. With no parent, `WorldPosition` is the same as `Position`, so the world point is stored as a local offset. Once the attachment is parented to `body`, it sits at `body.CFrame * worldPoint`, which can be hundreds of studs from the horse. The hoof dust and both flank trails would then emit somewhere in the sky, or off the track. This is the main visible part of Phase 1.2. I haven't verified it in Studio (the file is marked "written without Studio access"), but the fix is safe either way.

**Fix:** parent the attachment first, then place it, or set the local CFrame directly:
```lua
a.Parent = body
a.CFrame = body.CFrame:ToObjectSpace(box * CFrame.new(offset))
```
Add a source-level check in `race_fx_tests.luau` that `a.Parent = body` comes before the placement line. Add a PLAYTEST line: "dust appears at the hooves, not elsewhere".

## NON-BLOCKING

### N1. The Python mirror has no 0.5 constant
`src/burst_meter.py:53,57`. The spec says "`burstArmSeconds = 0.5`, the same on server, client and the Python mirror". Python defaults `arm_seconds` to `0.0`, so any Python caller that leaves it out (sims, a future gavel_race_v2 burst) silently gets pre-D-066 behaviour.
**Fix:** add `BURST_ARM_SECONDS = 0.5` to `burst_meter.py` and make it the default. Add a test that reads `GameConfig.luau` with a regex and asserts the two values are equal.

### N2. Taps before the burst arms get no feedback
`game/src/client/RaceController.client.luau:635`. A kid who taps on the grey bar sees and hears nothing. That's not wrong, but it can read as "the game ignored me".
**Fix:** while the bar is grey, change `hint.Text` to something like "Wait for the colours…" (no sound), then restore the "One big tap in the glow" hint once the bar arms. Keep this behind config.

### N3. On Champion, the second target isn't greyed while unarmed
`RaceController.client.luau:1313`. Only `burst.zone` is dimmed (0.6). `zone2`, which is visible for `twoTargetFinal`, stays at 0.25, so one glow looks live and the other looks dead.
**Fix:** also set `burst.zone2.BackgroundTransparency` with the same `if armed` rule.

### N4. The tick replaces the Great/Perfect chime
`RaceController.client.luau:669`. With `tapTick` on, `tap_good` no longer plays on a Great or Perfect pace tap. The spec only adds a tick. Dropping the chime is a design choice and isn't logged.
**Fix:** log it in D-066 and REVIEW_QUEUE, or play `tap_good` quietly on Perfect as well as the tick.

### N5. The bob jumps when the gait changes
`RaceView.client.luau:166`. The legs cross-fade between gaits over 0.25 s (`MIX_RATE`). The bob switches at once from trot (2 bobs, plant 0.21) to gallop (1 bob, plant 0.66), so the body can jump by up to `bobStuds * speed` in a single frame out of the gate and while pulling up.
**Fix:** expose `s.prev` and `s.mix` from `HorseLegs.phaseOf`, or add a `HorseLegs.bobOf(model)` that blends `bob(prev, p)` and `bob(gait, p)` by `mix`.

### N6. The nudge snaps back when a horse cuts in ahead
`RaceFx.stepNudge` / `RaceView.client.luau:467`. If a horse glides into your lane within `nudgeClearFeet + nudge` ahead, the drawn nudge drops at once by up to about 4.3 ft. It never overlaps the other horse, which was the requirement, but the snap is visible. The comment says this is on purpose.
**Fix (optional):** keep the hard clamp, but also ease toward a falling `room` at `nudgeFeetPerSecond` when that is still clear (for example, clamp to `room` only when `drawn > room + 1`). Otherwise, leave it and note it in PLAYTEST.

### N7. Neighbour positions for the nudge room are one frame old
`RaceView.client.luau:465`. `myNudge` runs inside the per-lane loop, so `race.offset[j]` and `race.lane[j]` for `j > myLane` haven't been updated yet this frame. That's at most about 0.17 ft of error, which is harmless.
**Fix:** compute the nudge after the lane loop, or note the staleness in a comment.

### N8. The drawn nudge peaks at about 4.3 ft, not 5
`tapNudgeFeet = 5`, but the 10 ft/s follow-rate cap limits a single tap's drawn peak to about 4.29 ft (computed at 60 fps). PLAYTEST says "up to about 5 ft", which is close enough.
**Fix:** say "about 4 to 5 ft" in PLAYTEST and the GameConfig comment, or raise `nudgeFeetPerSecond`. It can't go above `maxGapFeetPerSecond`, and a test enforces that.

### N9. The replay bob ignores the gate-out and pull-up ramp
`Replay.client.luau:376`. Replay passes the full `bobStuds` amplitude. Live passes `bobStuds * speed`. `blend` covers standing, but replays bob at full height through the line ease-out, where the live view fades the bob. PLAYTEST says "Replays bob the same way".
**Fix:** scale by the replay's `speed` term, the same way the live view does, or note the difference.

### N10. Comment mismatch in RaceFx
`game/src/shared/RaceFx.luau:11` says "0.9 to 1.2 by default". The config gives 0.9 to 1.3, and the test asserts 1.3.
**Fix:** change the comment to 1.3.

### N11. `reducedMotion()` allocates a closure on every call
RaceController calls it every frame through the kick handler (`:154`), the burst rim, `popFeedback`, and so on. Each call creates a closure for the `pcall`. That's small, but it runs on phones.
**Fix:** cache it at 2 Hz, the way `RaceView.client.luau` already does.

### N12. Phase 1.6 (live pace previews) wasn't built, and nothing records the deferral
The spec allows deferring it, but the deferral has to be written down.
**Fix:** the scribe records "1.6 deferred" with the reason in D-066, STATUS and REVIEW_QUEUE.

### N13. D-066 isn't logged yet
`docs/memory/DECISIONS.md` and `REVIEW_QUEUE.md` have no D-066 entries yet. The scribe step comes after review, but these must land before the commit, as CLAUDE.md rule 4 requires. The entries should cover: arm 0.5 s, nudge 5 ft with rate cap and clearance, tick replacing the chime (N4), RIDING label, the slider moving clear of the pad, the stand-in sheet using the 9th audio upload, and dust and trails switched off under Reduced Motion.

### N14. The stand-in sheet is still in moderation
`uploaded.json` shows `moderation: "Reviewing"`. Until it's Approved, every stand-in plays nothing. That's handled correctly, but playtesters should know.
**Fix:** before the playtest, run `python tools/roblox/upload_assets.py --moderation`. Add a PLAYTEST line saying to do that first.

## Hard rules
- No wagering words: the policy guard passes, and `test_sound_sheet.py` scans the sheet text.
- Diamonds: nothing in this phase touches them.
- Kid safety: no prompts, timers or urgency. Arming lowers how much a reflex mis-tap costs.
- No model names: the policy guard passes.

## Verdict
**CHANGES REQUESTED.** Fix B1. Before commit, the scribe must also complete N12 and N13.
