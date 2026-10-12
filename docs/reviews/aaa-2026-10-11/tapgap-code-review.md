# Tap gap (D-071) code review: the pure layer and its wiring

Scope: the pure layer committed in `1456d70` (`shared/TapPreview.luau`, `RaceSession:previewOwn`, `PacePreview.beforeLock`, `RaceFx.stepNudge` `baseFall`) and the uncommitted wiring and held cue in the working tree (`RaceService.server.luau`, `RaceView`, `RaceController`, `RaceState`, `client/TapCue.luau`, `shared/TapMessage.luau`, `GameConfig.tapPreview` / `tapCue`, the tests, the report, and CI). Spec: `tapgap-plan.md`, `plans-consensus.md`, `tapgap-results.md`, `tapgap-rulings.md` (including Ruling 2).

Runs on this tree:
- `python -m pytest -q`: 1767 passed (`tests/test_tap_preview_report.py` now checks all 14 gates on the seeded subset and passes).
- `bash scripts/policy_guard.sh`: exit 0.
- Full `lune run tests/luau/tap_preview_report` (the CI step): see "CI" below.
- Commit trailers on `1456d70` and the two before it say "Claude" only.

## Verdict on the focus areas

- **Draw-only in the real wiring: holds.**
  - `TapPreview.step` returns `tp.d` (`RaceService.server.luau:986-990`). That table goes only to `RaceOffsets:FireAllClients` (`:1022`/`:1024`).
  - `Trip.advance` reads `session.live` (`:870`). Nothing reads `tp.d` or the residual back: not τ, scores, `session.live`, order, prizes, Integrity (fed by `scorePace` errors), or the result (`session:finish()`).
  - `tapPassEnd` (`:1069-1087`) only copies numbers into `tp` (`setPreview`). `previewOwn` stores nothing.
- **The lock refresh doesn't change τ.**
  - `session:setTrip(Trip.raceTau(trip))` runs before `previewStretch` (`:871` vs `:900-902`).
  - `previewLive` and `tilts` are pure (`RaceSession.luau:399-471`). `shownLive` feeds only `Trip.frame`'s drawing after the lock.
- **No luck before the far turn.**
  - `previewOwn` and `previewLive` use skills, crowd and τ only, never `session.luck`.
  - With steering off, `displayOffsets` has w = 0 before `tFar`.
  - One caveat: steering off still uses `previewLive`, which shows the bots' pre-rolled checkpoint scores (N3).
- **Rider only.**
  - `TapNote` and `TapHeld` are sent once each, with `FireClient(r.p, …)` only (`:970`, `:975`).
  - `tapRiders` holds human lanes only (`:826-830`).
  - On the client, TapCue keys on RaceController's `steer`, which exists only for riders. Spectators get nothing.
- **Server cost.**
  - The layer is built only with a trip and at least one human (`:832`). An all-bot race makes and computes nothing.
  - `tapNotes` and `TapPreview.step` allocate nothing.
  - `debug.profilebegin`/`profileend` are balanced: `send` (`:980-1027`) has no early return.
  - Pass ends still allocate (N4).
- **Reset.**
  - Server state is per race (locals in `runRace`).
  - Client: `TapCue.reset` (`TapCue.luau:52-59`) runs whenever `steer` changes. It clears the held value, the cue, the message queue, the billboard and `RaceState.tapPressure`.
  - `RaceController` and its GUI are `StarterPlayerScripts` with `ResetOnSpawn = false`, so respawning doesn't attach twice.
  - A rider who leaves is skipped (`r.p.Parent`, `:968`).
- **`enabled = false` is today's path.**
  - `tapRiders` stays empty, so `tp == nil` and `tapWholeRace == false`. The segment loop takes D-067's branch unchanged (`:1132`). There is no lock refresh, step or notes.
  - RaceView's `baseFall` is nil.
  - TapCue idles (`TapCue.luau:153`).
  - Harmless extras: the `RaceSend` profile label, `race.nudgeBase` written but unused, and a `TapPop` UIScale (Scale 1) on `placeText`.
- **Reduced Motion.**
  - `tapPressure = pressure and not still()` (`TapCue.luau:165`).
  - The extra dust goes through `myDust`, which already returns under Reduced Motion (`RaceView.client.luau:516`).
  - The billboard and badge pops are skipped (`TapCue.luau:114-126`). Only a 0.3 s fade remains.
- **Copy.**
  - The four strings ("Giddy-up! Moving up!", "Pulling away!", "Find a gap! ◀ ▶", "Your taps still count!") are all 10 words or fewer.
  - None contains a banned word, "boxed", "leading" or "winning" (`tap_wiring_tests.luau` section 5).
- **RaceController headroom.** The new code adds no top-level local, just a trailing `require(...).attach{…}` (`RaceController.client.luau:2017-2029`). Every upvalue it captures (`steer`, `myLaneIndex`, `showChip`, `steerChip`, `coach`, `cueRace`, `thumb`, `hint`, `FX`, `placeText`) is a top-level local declared earlier. `tests/test_compile_all.py` passes.

## BLOCKING

**B1. The new files are untracked, and the wiring breaks without them.** `git status`: `game/src/client/TapCue.luau`, `game/src/shared/TapMessage.luau`, `tests/luau/tap_wiring_tests.luau` and `tests/test_tap_preview_report.py` are `??`.
- Without TapCue, `RaceController.client.luau:2017` (`script.Parent:WaitForChild("TapCue")`) yields forever.
- Without TapMessage, `require(Shared:WaitForChild("TapMessage"))` inside TapCue yields forever.
- Without the wiring tests, `run_all.luau:226` (`require("./tap_wiring_tests")`) errors, so the CI luau job goes red.
- CI's `syntax_check` uses `git ls-files`, so it only sees these files once they are added.
- **Fix:** `git add` all four in the same commit as the wiring. Do **not** add `.claude/worktrees/`, which is also untracked.

**B2. Commit attribution must not name a model (hard rule 5).** This session's injected trailer names a specific Claude model. `policy_guard.sh` uses `git grep`, so it never sees commit messages.
- **Fix:** end the commit with `Co-Authored-By: Claude <noreply@anthropic.com>`, as in `1456d70`.

## NON-BLOCKING

**N1. D-071 is not recorded yet.**
- `docs/memory/DECISIONS.md` and `REVIEW_QUEUE.md` have no D-071 entry.
- `STATUS.md:18` still says "Not recorded yet" and that comments say "D-070". The labels are already fixed (`grep` finds no stray D-070 in the tap files), so that line is stale.
- **Required before commit (scribe).** D-071 as `Accepted (provisional)`, with alternatives, covering:
  - previewOwn over previewLive;
  - `previewBots = false`;
  - `lead = 1.2`;
  - `joinSlackFeet` kept at −4 (−7.5 tried);
  - the held cue and chip values;
  - Ruling 2 (boxed share accepted at 53%, gate ≤ 55%, the three cue gates);
  - the report gate thresholds;
  - the copy;
  - the steering-off whole-race preview (and N3);
  - TapCue living outside RaceController.
- REVIEW_QUEUE also needs the Smart Steer "find room" follow-up, which needs David's approval.

**N2. TapHeld is unreliable and sent only on change, so a lost packet strands the client's value** (`RaceService.server.luau:971-976`, `TapCue.luau:144-148`).
- Example: the client last got 7 ft, then the packet with the drop to 0 is lost. The client keeps 7 until the next change of 1 ft or more, or the lock.
- Meanwhile the pressure bob and dust stay on. A Smart Steer rider can get their once-a-race "Your taps still count!" chip, and a rider with buttons "Find a gap!", when nothing is holding them.
- **Fix:** follow the lanes' pattern (`:1018`, `resend = 2`). Resend a changed value on the next two sends that pass the rate limit. Or resend the current value once a second while it is above 0, which also caps the stale time at about 1 s.

**N3. Steering off previews with `previewLive`, so the bots' pre-rolled scores show from the gate** (`RaceService.server.luau:1084-1085` → `previewStretch` → `RaceSession:previewLive`, which reads `self.botScores[seg]`).
- This matches `tapgap-results.md` step 7. It does not match the ruling behind previewOwn ("the field's true scores arrive at the close") or the 5.4 ft slide-back that previewOwn fixed.
- It is not a luck leak: w = 0 before `tFar`, and bot pace scores are not `session.luck`. Steering is on by default.
- It also fires `LiveChances(…, preview = true)` to every client at each pass end from the gate, not once a second after the lock. FanClient ignores previews (`FanClient.client.luau:195`).
- **Fix:** either log this as a provisional decision in N1, or preview the steering-off chances with `previewOwn` (shown) so both modes agree.

**N4. Pass ends still allocate, though the comment at `RaceService.server.luau:837` says a pass end reuses its tables.**
- `session:previewOwn` builds `S` plus `liveChances`' arrays.
- `PaceMeter.score` builds `byPass` and `errors` for each rider.
- The steering-off `previewStretch` builds `done`, `partial` and `{}` at each pass end.
- At 1–2 Hz per race this costs little.
- **Fix:** reword the comment ("tapPartial/tapClean/tapDone are reused; previewOwn and PaceMeter.score allocate per pass end"). Or, if the MicroProfiler shows GC, give `previewOwn` an `out` table and a scratch `S`.

**N5. The `smart` argument doesn't match the published API.**
- `TapPreview.luau:316-317` and `tapgap-results.md` ("Held API") say `smart = no buttons, or buttons with Smart Steer on`.
- TapCue passes `not s.shown` (`TapCue.luau:164`), ignoring `s.smart`.
- The wiring is the better choice: a rider with buttons can always press ◀ ▶, so "Find a gap!" applies to them. It also matches the harness's `riders[h.id] ~= "manual"`.
- **Fix:** change the doc comment and the results note to "smart = no buttons (Smart Steer only)". Don't change the code.

**N6. The report's cue gates don't model the wire, so "pressure cue 100%" is true by construction** (`race_overlap.luau:585-613`, `tap_preview_report.luau:191-196`).
- The harness feeds `stepCue` the server's raw `held` at every sample.
- The client sees TapHeld rounded to 0.1 ft, at most every 0.5 s, and only on a change of 1 ft or more.
- So a held value that rises from 3.6 to 4.4 ft is never re-sent. The client stays at 3.6 and the cue never fires, even though the gate counts that race as a pass. The gate uses the same thresholds and dt as the cue, so it always passes.
- **Fix:** put the send filter in a pure function, for example `TapPreview.heldSend(r, feet, stamp, everySeconds, minFeet) -> boolean`. Call it from `tapNotes` and run the harness's cues on its output. Ruling 2's gate 2 then measures what a kid actually sees.
- The 1 ft step in the rulings is also coarse next to the 4 ft trigger. `heldSendFeet = 0.5`, or "always send when crossing `minFeet` or `chipMinFeet`", would close the gap.

**N7. The lock refresh has no `now() < lastEnd` guard** (`RaceService.server.luau:900`).
- D-067's loop (`:1139`) and the harness (`race_overlap.luau:481`) only preview before the open checkpoint's last pass ends.
- The lock refresh also runs in the `LATENCY_GRACE` window after it, so the harness and the server differ slightly there.
- **Fix:** add the same guard, using `session:pacePasses(cur.seg)`'s last `t1`, or note the difference in the harness header.

**N8. The new D-071 segment loop's after-lock timer starts at the segment's open** (`:1112`), not at the lock.
- The first after-lock preview can come at the next pass end after the lock (up to one pass gap) rather than exactly 1 s after. The lock refresh (`:900`) covers the moment itself, so the effect is cosmetic.
- **Fix:** set `nextAfter = now() + every` at the lock (when `trip.locked` first becomes true in the loop).

**N9. Check count inflation** (`tap_preview_tests.luau`, the Smart Steer loop: `check(c ~= "gap", …)` inside an 1,800-step loop).
- This adds 1,800 checks to the suite's total, which hides real growth in the count.
- **Fix:** collect into a flag and check once, as the other loops do.

**N10. UI/UX consult point, still open:** "Find a gap! ◀ ▶" shows both arrows when only one side is free (`consult-tapgap-ui-ux.md:13`). A kid can press the blocked side and get "No room yet" or a brush.
- **Fix (a design call, log it in D-071):** show only the free side's arrow, using `lane.inSide`/`lane.outSide` in TapCue and two CHIP strings in TapMessage.

**N11. "Pulling away!" means "leading" in all but name.** It is the copy the plan approved and it shows only before the lock. The trust row gate (drawn 1st at the lock and finished 4th or worse, −0.70 points) shows it doesn't over-promise. Keep it in D-071's copy list so David sees it.

## CI

- `.github/workflows/test.yml:42-43` runs the full `tap_preview_report` (3,840 races plus 60 Rookie Mile races) in the luau job after `run_all`. It exits 1 unless all 14 gates pass.
- Ruling 2 has landed in the working tree. The boxed gate is now "≤ 55%" plus the three cue gates, so with today's 53% the step is expected to be green. The old `xfail(strict)` pytest has been replaced by a single 14-gate test, which passes on the seeded subset.
- The python job has no Lune, so `test_tap_preview_report.py` skips there. That is intended: the luau job runs the full report.
- `tapgap-results.md`'s "Until then: the CI step … is red" paragraph is out of date once Ruling 2 is in. The scribe should update it.
- **Full run on this tree: `PASS`, exit 0, all 14 gates.**
  - Shared jerks: 2 races (allowed 3).
  - Own-screen overlaps: **1 race (allowed 1)**.
  - Pull-back: p99 3.31 ft, worst 6.90 ft.
  - Lock fade: 1.25 / 2.23 / 2.63 s.
  - Trust row: −0.70 points.
  - **Boxed share: 48.5%** of 27,966 samples (60 Rookie Mile races).
  - Pressure cue: 109/109. Gap chip: 91/91. Masher chips: 0, and no chip says "boxed".
- Two notes for the scribe and the owner:
  - The boxed share is 48.5% here, not the 53% in `tapgap-results.md` and Ruling 2. The Ruling 2 run is Rookie Mile only, with all four profiles, masher included; the earlier run was Sprint and Mile with three profiles. Record the new number and why it differs.
  - The own-screen overlap gate has no headroom (1 of 1 allowed). Any later change to the layer, the nudge or Trip that adds one more race turns CI red. Expect that, and don't loosen the gate without a ruling.

## Result

**CHANGES REQUESTED** until B1 and B2 are done at commit time. The code itself has no blocking defect. N1 is required before commit (scribe). N2 and N6 are the most valuable follow-ups.
