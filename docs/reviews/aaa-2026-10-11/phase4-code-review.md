# Phase 4 code review: presentation and world (D-069)

Reviewer: code-reviewer, 2026-10-11. Scope: Phase 4 only, as committed in `67f503f` on `claude/aaa-review`. Specs: `phase4-plan.md`, CONSENSUS Phase 4, and the PLAYTEST sections "AAA Phase 4: world and jockey (D-069)" and "AAA Phase 4: HUD, camera and finish polish (D-069)". No game code was edited.

## Checks run

- `python -m pytest -q`: **1738 passed** (84.8 s). Lune 0.10.5 is on PATH, so the Luau suites ran, including `world_dressing_tests`, `presentation_tests`, `test_compile_all` and the local-headroom check.
- `bash scripts/policy_guard.sh`: **exit 0**. It found no wagering words in game code and no model names in any tracked file.
- Manual searches:
  - No `fromRGB(20, 30, 25)` is left anywhere in `game/src`.
  - The slider glow is Gold `FFD23F` in code (`RaceController.client.luau:286`, `:553`) and in art (`burst_glow.svg`, `burst_bar.svg` on Slate `2A3247`).
  - The warm-up glow is `C.gold` (`QueueCard.client.luau:218`).
- Contrast, computed:
  - `8F4700` on Paper `FFF7E6` is about 6.4:1.
  - Ink `1D2433` on Paper is well over 4.5:1.

## Summary

The Phase 4 code is in good shape. Every piece is behind a config switch, and each draw-only module is wired in with one `require`. The pure parts (`RacePresent`, `TrackLifeView`, `JockeyPose.solve`, `TrackDressing.plan`) are tested.

Checked against the focus list:

- **JockeyPose:**
  - Writes `Motor6D.Transform` in `PreSimulation`, which runs after the Animator steps.
  - Skips R6 rigs.
  - Resets the joints to identity when a rider drops off the list.
  - Caches each rig's motors (weak keys).
- **TrackDressing:**
  - Builds server-side once per venue, inside a `pcall`.
  - Posts are `CanCollide`, `CanTouch` and `CanQuery` false, so they don't block horses or the Popper camera.
  - Its Attachments are parented before being placed.
  - It goes away with the venue.
- **GateIntro:**
  - Has four ways back to the normal camera: the per-frame `alive()`, Reduced Motion, a camera-type check and a hard `task.delay` at hand-back.
  - The countdown is unchanged.
  - It runs only for riders, inside `if riding`.
  - It never touches the FOV or the camera subject.
- **Big Board:** shows only the ordinal place, a lane chip and the horse name. Horse names come from fixed word lists (`RenameHorse` takes two words), so there's no free text or private data.
- **MusicBed:** creates nothing when the id is 0. It plays in Sound's group, so Sound Off mutes it.
- **Results card:** the star count-in is cancelled by a token and lands on the last star when the card is hidden.
- **`Ui.queueLeaveShown`:** never leaves the player with zero ways out. A hidden or slot-yielded queue card puts the dock's ✕ back.

I found no wagering mechanic or wording, no purchase prompts, and no streak or urgency pressure. The crowd art has no tickets or slips.

One item blocks the next commit: the commit message names a specific Claude model (B1). Everything else is non-blocking.

---

## BLOCKING

### B1. The commit message names a specific Claude model (CLAUDE.md hard rule 5)

- **Where:** commit `67f503f` (and the earlier `bed9d9e`), trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Problem:** Hard rule 5 says "Never mention a specific Claude model in commits". Commits before this run used `Co-Authored-By: Claude <noreply@anthropic.com>` (for example `ee4615c`, `45c0c87`). The CLAUDE.md rule takes precedence over the session's default attribution text. `scripts/policy_guard.sh` uses `git grep`, so it only scans tracked files and never sees commit messages. That's why this got through.
- **Fix:**
  - **Do not amend or rewrite `67f503f` or `bed9d9e`.** Hard rule 6 forbids it, and the branch is already pushed.
  - Write the Phase 4 fix commit, any later commits on this branch, and the PR body with `Co-Authored-By: Claude <noreply@anthropic.com>`. Never include a model name.
  - Optionally, add a check to `scripts/policy_guard.sh` for unpushed commit messages, for example `git log origin/main..HEAD --format=%B | grep -iE 'Claude (Opus|Sonnet|Haiku|Fable|Mythos)'`. That way CI and the build loop catch this too.
  - Add one line to `docs/memory/CHANGELOG.md` noting that the two commit messages carry a model name and can't be rewritten.

---

## NON-BLOCKING

### N1. D-069 is not yet in DECISIONS.md or REVIEW_QUEUE.md (traceability; required before merge)

- **Where:** `docs/memory/DECISIONS.md` and `docs/memory/REVIEW_QUEUE.md` have no D-069 entry. `STATUS.md:29` and the commit message say "review pending", so the scribe step is expected next.
- **Fix:** the scribe adds D-069 as `Accepted (provisional)` with a REVIEW_QUEUE row. Log these deviations from `phase4-plan.md` with their switch-backs:
  - The finish stamp plays `job_done` (plus `crowd_cheer` for 1st), not `bump_soft` at 0.8 plus `tap_good` (`FinishMoment.luau:113-117`, "the consult").
  - The star ticks use `count_tick`, not `tap_ok` (`GameConfig.finish.starTick`).
  - The dressing fallback is plain-colour Beams with no crowd, not WedgePart triangles (at most 300).
  - The config key is `gateIntro`, where the plan said `raceIntro`. It also gains `lateSeatSeconds`, `frontStuds`, `chaseBackStuds` and `chaseUpStuds`.
  - `jockeyPose` gains `pelvisDeg` 15, `neckDeg`, `shoulderPumpDeg`, `seatDropStuds` and `refreshHz`.
  - The crowd also cheers once the leader passes `cheerFromProgress` 0.8. That covers spectators and no-burst races.
  - There's a `spectate` music level of 0.08.
  - The Big Board title is "🏁 Top 4" and each row shows the ordinal place.

### N2. JockeyPose keeps posing a rider for up to 0.25 s after they leave the saddle

- **Where:** `game/src/client/JockeyPose.luau:129-165`. The rider list is rebuilt only at `refreshHz` (4).
- **Problem:** when a player hops off (in the lobby, on Leave, or on respawn), their walking character keeps the crouch for up to 250 ms on every screen. It also holds for a frame or more on other players' characters.
- **Fix:** in the per-frame loop, skip and `release(r)` any rider whose `Humanoid.SeatPart` is nil or isn't the horse's `Saddle`. A property read per rider per frame is cheap. The other option is to connect `Saddle:GetPropertyChangedSignal("Occupant")` to force a `refresh()`.

### N3. JockeyPose allocates three CFrames per rider per frame

- **Where:** `JockeyPose.luau:174-176`.
- **Problem:** `CFrame.new` and `CFrame.Angles` allocate (CFrame is userdata, unlike Vector3). With up to about 24 riders across the courses, that's roughly 4k small allocations a second on phones. The pose is constant under Reduced Motion and for standing horses.
- **Fix:** when `lift == 0 and nose == 0`, use three CFrames precomputed in `start` (from the `base` pose). Optionally, quantise the pump phase into a small lookup table, for example 32 steps.

### N4. The crouch replaces the sit animation's Root offset

- **Where:** `JockeyPose.luau:174` writes `Root.Transform = CFrame.new(0, rise, 0) * Angles(pelvis)`.
- **Problem:** this overwrites whatever offset the R15 sit track puts on the Root joint (the hip drop onto the seat). Riders may sit higher than before. That's the "feet don't sink" or "float" item, and `seatDropStuds` defaults to 0.
- **Fix:** none in code before Studio. Make sure the PLAYTEST item tunes `seatDropStuds` both ways (a positive value lowers the rider). It already names the key. Note in D-069 that 0 is untested.

### N5. The YOU marker is the large 12-stud, 90 px one during the gate pass, then pops to the small one at hand-back

- **Where:** `RaceHudStyle.luau:151-155`. `chaseView` requires `CameraType == Follow`, and GateIntro holds `Scriptable` for about 2 s.
- **Problem:** the big always-on-top marker sits over the horses' faces in the line-up shot, then snaps to 7 studs and 56 px at hand-back. It's a visible pop right before GO.
- **Fix:** while `GateIntro.active` is true, either hide the marker or use the rider size. RaceHudStyle can `require` GateIntro, or GateIntro can set an attribute such as `GateHidden` on the marker the way FinishMoment sets `OrbitHidden`.

### N6. GateIntro and MusicBed create a closure every frame

- **Where:**
  - `GateIntro.luau:35-38,105`: `still()` wraps a `pcall(function() ... end)` and runs every render step.
  - `Sound.luau` `Sound.speaking()` does the same, called every Heartbeat by `MusicBed.luau:45`.
- **Fix:** cache Reduced Motion through `GetPropertyChangedSignal("ReducedMotionEnabled")`, as `RaceCamera.luau:32-38` and `TrackLife.client.luau:35-41` already do. In `Sound.speaking`, read `voice.IsPlaying` directly; `voice` is a Sound or nil, so no `pcall` is needed. This is minor because the pass lasts about 2 s, but MusicBed's loop runs forever once a track id is set.

### N7. The "green" copy is not fully gone from the docs

- **Where:**
  - `game/PLAYTEST.md:594`: "Tap once every time the marker passes the green … points at the green … 'NOW!' on the green". This contradicts `PLAYTEST.md:645`.
  - `game/src/shared/GameConfig.luau:233`: a comment quotes the old hint.
  - The `coachNowZone` comment: "the green's centre … the green is 0.2 each side".
- **Fix:** change these to "glow". No player-facing race string still says green. The Paddock minigame strings ("Wait for green…", "stay in the green band", `PaddockClient.client.luau:235,240,424,425`) describe different, actually green UI and are correct to keep.

### N8. The 30-second toast bypass after RACE! opens the picker is wide

- **Where:** `Hud.client.luau:333` uses `Ui.racePressed(FM.raceReasonPickerSeconds or 30)`. Logic is in `Ui.luau:399-414`.
- **Problem:** for 30 s after RACE! opens the picker, every toast skips the first-minute hold, including toasts that have nothing to do with the race. That partly undoes D-067's "the tour owns the first minute".
- **Fix:** open the bypass window when the picker actually sends `JoinRace` (call `Ui.racePressed(FM.raceReasonSeconds)` there). Alternatively, shorten the window to about 8 s. Either way, log the value in D-069.

### N9. Rail bunting bridges the gap at the finish line

- **Where:** `TrackDressing.luau:58-63` skips the post on the finish line, but `:204-210` still hangs a Beam from the post before the line to the post after it.
- **Problem:** this is drawn only and sits 14.5 studs outside the outer rail, behind the side camera. It's fine as is, but the comment says "never a post on the finish line" and readers may expect a gap in the bunting there.
- **Fix:** if a gap is wanted, reset `prev = nil` when a station is skipped. In `plan`, carry a `gapAfter` flag so the Beam count stays exact. Otherwise, update the comment.

### N10. TrackDressing can loop forever on a zero spacing

- **Where:** `TrackDressing.luau:42-47`. `stations(a, b, step)` with `step = 0` (from `roofSpacing`, `railSpacing` or `flagSpacing`) gives `math.ceil(inf)` and then `table.create(inf)`, which errors. The `pcall` in `TrackScene.luau:306` catches it, so the venue survives, but all dressing is lost.
- **Fix:** use `step = math.max(step, 1)` in `stations`. Add a test for `roofSpacing = 0`.

### N11. StreamingEnabled: a Beam can lose one end

- **Where:** rail and spire Beams join Attachments on different parts (`TrackDressing.luau:205-215`).
- **Problem:** if the place streams and one post streams out, its Beam has a nil Attachment on that client and simply isn't drawn. TrackLife already handles tagged instances streaming in and out through the tag signals. This is cosmetic.
- **Fix:** none needed now. If the place uses streaming, set the venue `Model`/`Folder` to `ModelStreamingMode = Atomic`/`Persistent`. Note it in PLAYTEST's budget item.

### N12. A test asserts something that doesn't apply

- **Where:** `tests/luau/presentation_tests.luau:103` checks that the small YOU marker is `>= GameConfig.ui.minTouchPx` ("still at least a tap-target wide"). The marker is a BillboardGui and not a tap target.
- **Fix:** drop that assertion, or reword it as a readability floor.

---

## Verified, with no finding

- **JockeyPose:**
  - The back angle is 40° from horizontal (pelvis 15 + waist 35), under the 45° limit.
  - Arms are symmetric (left and right always share a field).
  - The pump is on the landing (`pump = -nose`) and matches `HorseLegs.crossedPlant` (tested).
  - Under Reduced Motion the crouch stays and the pump stops.
  - The replay uses the same horses (`Replay.client.luau:380` calls `RaceState.placeHorse`).
  - Bot jockeys are R15 from `CreateHumanoidModelFromDescription` (`TrackScene.luau:519-521`).
- **TrackDressing:**
  - The budget is enforced in `plan` and tested with a tighter cap.
  - The posts and poles are the only Parts.
  - Each crowd Texture is created only once its image loads.
  - Tier heights are multiples of 6 (`TrackScene.luau:215`), so `crowdTileV = 6` always shows a whole row of fans at the visible top of each riser, and the `Row` attribute gives each tier its own phase.
- **TrackLife:**
  - The Heartbeat updates crowd and flags at 30 Hz, using arrays with swap-remove.
  - It allocates nothing per tick (`Vector3` is a value type).
  - Under Reduced Motion it settles everything once, then skips.
  - The board is drawn by a SurfaceGui in PlayerGui with an Adornee, so it's rebuilt when the board streams back in.
  - The 👫 mark is only on the riders' screens in a race titled "Practice" (that title comes from `RaceService.server.luau:776`). Each mark goes when the horses are rebuilt each race (`TrackScene.luau:439-445`).
  - Failed friend lookups aren't cached.
- **GateIntro:**
  - Riders only.
  - The pass fits inside the 3 s countdown, and the Follow camera is back 1.0 s before GO (tested).
  - A late seat (more than 0.3 s) skips it.
  - `RaceAborted` (`RaceController.client.luau:1685-1700`) bumps `cueRace` and calls `Cam.ride(false)`, so the next render step's checks call `stop()`.
  - On a respawn or leaving the seat, `seated()` is false, so it stops.
  - The hard hand-back timer always fires.
- **RaceHudStyle:**
  - Paper panels, Ink outlines, a Gold count with an Ink stroke, a Slate track and a Gold glow.
  - Row text is Ink, and yours is `8F4700`.
  - Text sizes are unchanged (the floors still pass `test_clarity_floors`).
  - The YOU marker hides in first person and during the orbit, through `OrbitHidden`, which `Finish.clear` restores.
- **MusicBed:**
  - Creates nothing at id 0.
  - Levels are lobby 0.35, race 0.12, spectate 0.08 and finish 0.4. The race level is at most half the tap tick's level (tested).
  - It ducks to ×0.5 while a `vo_` line plays.
- **Finish:**
  - Confetti uses `UiSheet_confetti_square` and falls back to the sparkle texture.
  - The paper confetti doesn't glow.
  - None under Reduced Motion.
  - The dim is Ink at transparency 0.75.
  - The ribbon placeholder colours match the plan.
- **Stars:**
  - Each count-in has a token. A count cut short by a hidden card lands on the final line silently.
  - Coming back from the replay sets `results.Visible` without re-counting.
  - Under Reduced Motion they show at once.
- **Assets and upload:**
  - The four strips are uploaded as Decals (`UiImages.luau`). AssetService publishes `UiSheet_<name>` for them, which `WorldArt` reads.
  - `upload_assets.py` keeps the sound sheet out of `SoundAssets`.
- **Rules:**
  - The Big Board and its tests read no chance, purse or cash (`world_dressing_tests.luau:148-152`).
  - No `PolicyService` or purchase prompts in any Phase 4 file.

## Verdict

CHANGES REQUESTED. B1 is a process fix for the next commit and the PR; nothing in 67f503f should be rewritten. Make sure N1 lands before merge.
