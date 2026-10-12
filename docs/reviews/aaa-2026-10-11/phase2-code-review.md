# AAA Phase 2 (D-067): code review

Reviewed 2026-10-11 by code-reviewer against `CONSENSUS.md` Phase 2 and its cross-cutting rules. Scope: the uncommitted working tree on `claude/aaa-review` (diff against HEAD), Phase 2 files only. Phase 1 was reviewed in `phase1-code-review.md` and is not reviewed again here. Phase 3 work in progress (Leagues, RaceQueues, Career, class tests, sims, the Phase 3 GameConfig ladder keys) was left out as asked. Where Phase 3 code sits inside a Phase 2 file and breaks it, I list it separately at the end and don't count it against Phase 2.

Checks run:
- `python -m pytest -q`: **1727 passed, 4 xfailed**. Lune is on PATH, so `finish_tests`, `clarity_tests` and the Luau parity tests ran.
- `bash scripts/policy_guard.sh`: **exit 0**. No wagering words, no model names.
- An extra check: every `.luau` file under `game/src` compiled with Lune's `@lune/luau` `compile`. 115 of 116 compile. The one failure is `RacePicker.client.luau`, from Phase 3 code (see P3-1). RaceController compiles, but it has 195 top-level locals, close to Luau's limit of 200 (see N9).

## What holds up

- **The post-lock preview can't change the race.** I traced the code paths, not only the tests.
  - `RaceSession:previewLive` (`RaceSession.luau:387`) reads `lanes`, `scores` and `botScores`, then returns a fresh table from `RaceMath.liveChances`. It never assigns `self.live`, `self.tau`, `self.crowd` or any score.
  - The preview result goes only into `shownLive` (`RaceService.server.luau:969`). On the server, `shownLive` is read in two places: `LiveChances` and `Trip.frame` (offsets and lanes drawn on screen).
  - `Trip.advance` reads `session.live`, never `shownLive` (`RaceService:796`). It returns early once `trip.locked` is set, and the preview runs only once `trip.locked` is true (`PacePreview.afterLock`).
  - After the lock, `Trip.frame` only calls `Trip.cosmetic`. τ is set once by `setTrip`, and `advanceTrip(math.huge)` returns early because the trip is already locked.
  - `session:finish`, `ridingGain`, `tripGain` and the prizes all read `self.live` and `self.tau`, and only `closeSegment` and `setTrip` write those.
  - `finish_tests.luau:250-296` runs 12 seeds with and without 10 previews and compares order, live chances, S, prizes and the ride and trip gains. It also checks that Trip's own state before the lock doesn't depend on the chances shown.
- **RideRank goes only to the rider, only for ranks 1 to 3, and isn't a board.** `RideRank:FireClient(p, rank, c.id)` runs inside the per-rider loop and only when `rank <= 3` (`RaceService:1138-1139`). The rank is the only data sent: no scores, no names, no other lanes. The client accepts only 1, 2 or 3, filtered by course (`RaceController:1943-1947`). `rankLine` returns "" for any other value. Tied scores share a rank, and NaN never ranks.
- **Race again does exactly what RACE! does.** The button closes the card (`Dismount`), then fires the `HudEvents.PressRace` bindable. That calls Hud's own `pressRace`: the same `inLine` guard, `oneTapKind`, and `JoinRace` call. The server still enforces `riding`, `rideable` (Energy and napping), the queue and the 0.5 s join debounce. `riding[p]` is cleared in the same server step as `RaceFinished`, with no wait between, so the join isn't refused. The label comes from `ResultsText.nextKind`, which mirrors `oneTapKind`, and a source test (`finish_tests:162`) pins Hud's rule. The button isn't a purchase prompt.
- **The finish moment never holds the card past 4 s, and it can be skipped.** The wait ends by `leaderAt + crossWaitSeconds` (1.5 s). `cardAt = min(cross + 2.5, leaderAt + 4)` (tested). Any touch, click or tap key skips. `Card.ready()` ignores button presses for 0.35 s, so the tap that skips can't also press Done or Race again.
- **Reduced Motion is respected in the finish moment.** With it on there is no orbit, no confetti, no stamp tween and no card rise, and the screen dims instead. Hud's glow and arrow, QueueCard's spinner and the coaching thumb all hold still.
- **The camera is restored on every path I traced.** The orbit only starts when the player is seated in `rideCamOn` with a horse. `orbitFrame` stops by itself if anything else takes the camera (`CameraType ~= Scriptable`). Done and Race again both go through `rideCamera(false)` (Custom). Leaving the seat goes through `watchSeat.restore` (Custom). A respawn goes through `CharacterAdded` → `rideCamera(false)`. A replay calls `endOrbit` when it closes. An abort, a new race, or the dismount timeout calls `endOrbit` plus `clearFinishFx`. `CameraSubject` is never changed. Confetti is cleaned up by Debris after 4 s, the Highlight by `Finish.clear`, and the FOV kicks are cleared when the moment starts.
- **The warm-up sends nothing.** The slider's handler and the Heartbeat have no remote calls. The only `FireServer` in QueueCard is leaving the line, and `test_clarity_floors.py:262` enforces that. The schedule uses the race's own `PaceMeter.schedule` and `paceSpec` shape.
- **Ui.slot.** Both callers (`GrownUps` and `QueueCard`) call `want(...)` on every Heartbeat, so ownership is re-decided each frame. A card can't be left hidden after the higher-priority card goes away (at most a one-frame lag). Priorities follow the spec (Race time! 40 > tour 30 > queue 20), and `test_clarity_floors:265` checks them.
- **Toast hold.** Toasts are held only during the tour's race step, while you aren't in line and aren't racing. The hold adds up to at most `holdToastSeconds` (60) per race step: `holdSince` resets only when the step changes. On release, the toasts show staggered 0.6 s apart.
- **Floors and contrast.** The new lint (`test_clarity_floors.py`) now covers every client file, including RaceController's `label` helper. Its ALLOW list has a single entry (the ✕ inside `Ui.closeButton`). `textGood` (#18692F), `textWarn` (#8F4700) and the darker plum are tested at 4.5:1 or better on paper, cream, white and gold. Bright green and orange as text are linted out.
- **Kid safety and copy.** The results card has no shop door and no prompts. The 💎 pill stays hidden through the tour's race step and during training rides. Places 5 to 8 get ride praise and never a near miss (tested against a banned-word list). "Best ride" appears only for the top 3, on your own card. The distance word is the same everywhere ("🐇 Short", never "Sprint"). No wagering words. No model names.

## BLOCKING

### B1. The post-lock preview closes a spectator's cheer window early in Short races
`game/src/client/FanClient.client.luau:192-197`, triggered by `game/src/server/RaceService.server.luau:991-1000` and `:970`.

FanClient treats the first `LiveChances` with `seg == 1` as "checkpoint 1 closed" and hides the cheer strip (`watching.cheerOpen = false`). Before Phase 2 that event only came from the real close. Now `previewStretch(seg)` fires `LiveChances(1, …)` every second once the trip locks before checkpoint 1 closes, which the code says can happen in a Short race (`RaceService:833`, and `PacePreview.afterLock(P, true, 1, 0, …)` is asserted true in `finish_tests:217`). The server keeps accepting cheers until `FanService.beforeClose(…, 1)` runs (`FanService.luau:88`). So the client hides the cheer strip up to a checkpoint early while the server would still accept a cheer. A D-019 feature regresses, and the change only affects what's drawn, so the tests don't see it.

**Fix (pick one):**
- Mark preview events. Add a trailing argument, `LiveChances:FireAllClients(seg, shownLive, c.id, true)`, in `previewStretch`. In FanClient, ignore events where that flag is true (`function(seg, _live, courseId, preview) … if preview then return end`). RaceController's handler ignores extra arguments, so nothing else changes.
- Or make `PacePreview.afterLock` return false for `seg == 1`. This loses the Sprint preview that the gameplay consult asked for.

Add a source check in `finish_tests.luau` that FanClient's cheer close ignores previews (or that `afterLock` never previews checkpoint 1), and a PLAYTEST line: "Short race, spectating: the cheer strip stays until checkpoint 1 closes."

## NON-BLOCKING

### N1. D-067 is not yet in DECISIONS or REVIEW_QUEUE
`docs/memory/DECISIONS.md`, `docs/memory/REVIEW_QUEUE.md`. The process has the scribe add these after review, so this isn't blocking now, but it is required before commit. The entry should cover these choices, which the consensus spec leaves open:
- The post-lock preview (Phase 1 item 6 said "before the far turn … else deferred", and this build changed it to after the lock).
- `rideRank` counting bots.
- The "2nd best ride!" and "3rd best ride!" wording.
- Released toasts dropping all but the newest 3.
- `coachRaces = 1` and coaching being tied to `raceFx.enabled`.
- `warmUpRaces = 3` and `raceFirstUntilRaces = 3`.
- The gallop-out of 155 ft.
- A tour skip showing the 💎 pill straight away.

### N2. A held toast can swallow the reason RACE! did nothing
`game/src/client/Ui.luau:400-406`, `GrownUps.client.luau:307-315`. During the race step, while you aren't in line, every toast is held. That is also exactly when a refused `JoinRace` notifies the player ("Both races are full…", the `rideable` reason). A new player taps RACE!, nothing happens, and the reason arrives up to 60 s later, if it isn't dropped by `HOLD_KEEP`.
**Fix:** let a toast through if it arrives within about 3 s of a RACE! press (Hud could set `Ui.holdBypassUntil`), or let `Ui.toast` take a `priority`/`urgent` flag that skips the hold and use it for queue and join refusals.

### N3. The queue card stays hidden behind later tour steps while you wait
`GrownUps.client.luau:299`. The tour steps aside for the queue card only on the race step. On the feed, groom and plant steps (30 > 20), a kid who queues a second race sees only the dock's "In line! ⏳ 12s" until Race time!.
**Fix:** `local wants = step ~= nil and not busy and not inLine`, so the tour yields to any queue wait and comes back after the race. Alternatively, raise the queue card's priority while `v.seconds` is set.

### N4. The Reduced Motion dim can be left on screen
`RaceController.client.luau:1828` (`startFinish`, the still path). `Card.dimIn()` shows the full-screen dim before the card is visible. `ResultsCard` hides the dim only when `results.Visible` turns false. If the sequence is cleared during the up-to-0.4 s "play" phase (abort, new race, dismount timeout), `results.Visible` is already false, so the 55% black dim stays up.
**Fix:** have `clearFinishFx` also hide the dim (`Card.dim.Visible = false` whenever `not results.Visible`). For example, `clearFinishFx = function() Finish.clear(); if not results.Visible then Card.dim.Visible = false end end`.

### N5. The grooming card scrolls on 360-px-tall phones
`CareClient.client.luau:52, 84`. The grooming card is 400 px with an 18/64 floor (scale 0.875 → 350 px). On a 360-px-tall landscape phone, a common Android size, PanelFit makes the column scroll (350 > 340). The brush stroke is a drag, so the card slides under the finger while you brush. The comment says "never scrolls", which holds only at 375 px or taller.
**Fix:** make the brushing card 380 px (332 px rendered), or set `column.ScrollingEnabled = false` while the grooming game runs.

### N6. White ordinal text on the yellow ribbon disc
`FinishMoment.luau:89-90`. 3rd place draws white "3rd" on #F2C230 (about 1.7:1). The ink stroke helps, but the pattern elsewhere is ink on light colours.
**Fix:** `word.TextColor3 = if place >= 3 then INK else white`, with the stroke inverted to match.

### N7. Warm-up words don't use the race's own rule
`QueueView.luau:138`. The warm-up uses 95/80/60 and says "Early" or "Late" under 60. The race uses `GameConfig.labelFor` and says Early/Late only under `hud.earlyLateBelow` (30), with "Okay" between. The comment says "the race's own rule".
**Fix:** `local w = GameConfig.labelFor(score); if score < GameConfig.hud.earlyLateBelow then w = early and "Early" or "Late" end`, keeping "Miss" out.

### N8. QueueCard's pop fights its own per-frame scale
`QueueCard.client.luau:380, 389, 415`. `Ui.pop(card)` tweens the card's only UIScale back to 1 while the Heartbeat sets `scale.Scale = clamp(width / W, …)` every frame. On tablets where the full card is scaled below 1, it jitters for 0.35 s at each phase change. The 3-2-1 `Ui.pop(secs/ring)` also ignores Reduced Motion (the countdown pop is new in the compact row).
**Fix:** pop a child frame (or a second UIScale on a wrapper) instead of `card`, and gate both pops with `if not reducedMotion()`.

### N9. RaceController is at 195 of Luau's 200 top-level locals
`RaceController.client.luau` (Phase 1 and Phase 2 added 30). It compiles today, but Phase 4's HUD restyle will almost certainly go over the limit and fail at load in Studio, where no test catches it.
**Fix:** group the new state into tables (for example `local fin = { seq = nil, card = Card, … }`, `local coachState`), or move the finish and results code into `ResultsCard`/`FinishMoment`. Also add a test that compiles every `.luau` under `game/src` with Lune's `@lune/luau` (`luau.compile`). That would also have caught P3-1.

### N10. Ui.slot and the toast hold have no Lune test
`Ui.luau:343-420`. The slot owner choice, priority changes and the hold or release ordering are pure logic inside a Roblox-only module.
**Fix:** move `slotOwner`, the want table and the held queue into a shared pure module (for example `shared/TopSlot.luau`) and test it: a higher priority wins, a lower card shows again the frame after the owner releases, Race time! outranks the tour, the hold caps at 3, and release order is kept.

### N11. HorseBook can overflow a 600-px-tall screen
`HorseBookClient.client.luau:106`. The book is 560 px tall and never shrinks on screens of 820 × 600 or larger. At exactly 600 px it has 20 px of margin and no room under the top bar.
**Fix:** use `v.Y < H + 60` (and `H + 60` for StyleShop's 520) as the narrow test.

### N12. The skip confirm and the coaching zone use hard-coded numbers
`GrownUps.client.luau:264-272` (4 s and 3.9 s), `RaceController.client.luau:1340` ("NOW!" when the marker is within 0.2). Neither can be tuned and neither is logged.
**Fix:** add `firstMinute.skipConfirmSeconds` and `raceFx.coachNowZone`.

## Phase 3 in progress (not counted against Phase 2; must be fixed before any commit)

### P3-1. RacePicker doesn't compile, and it calls `openPractice` before it is defined
`game/src/client/RacePicker.client.luau:163` has a literal line break inside `"🎈 Race with` / `" .. f.DisplayName`, which Luau rejects ("Malformed string"). The whole picker script fails to load, so More, Practice and the Cup picker break. Line 127 also calls `openPractice()` at load, but `local function openPractice` is declared at line 225, so it would be a nil global call even after the string is fixed.
**Fix:** use `"🎈 Race with\n" .. f.DisplayName`, move `leagueQueues` and `openPractice` above line 110, and add the Lune compile test from N9.

## Verdict

One blocking finding (B1). Fix it, re-run `python -m pytest -q` and `bash scripts/policy_guard.sh`, and have the scribe log D-067 (N1) before commit.

CHANGES REQUESTED
