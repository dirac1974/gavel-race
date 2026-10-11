# AAA review: core gameplay and race feel (2026-10-11)

Scope: race mechanics, input, feedback, readability, slider, Final Burst, steering, training rides. From code and docs only (nothing has run in Studio).

## 1. Verdict

The race math is the most rigorous I've seen on a kids' title: it's fair, it can't be bought, it resists macros, and Python and Luau agree. The race *feel* is weaker, and from code I'd call it a QTE treadmill. The kid taps a 2D timing bar 70 to 250 times. The horse they're riding barely answers, the taps make no sound, and in the end a secret luck number the kid never sees decides most of the result. "Tap it. Win it." is not what the code delivers. A perfect rider on a starter horse wins about one Rookie race in three, and in the races they lose they can't see what they did. Almost all of this can be fixed inside the current architecture with config-backed changes. None of it needs new math or new art.

## 2. Top problems, ranked by player impact

### P1. Your taps don't move your horse (in any way a kid can see)
**Evidence.**
- Before the Final Burst, the on-screen gaps come from `shownLive`, and that only changes when a checkpoint closes. `previewStretch` runs only after the burst (`server/RaceService.server.luau:938-966`).
- In a Mile the first checkpoint closes about 35 s in, so a tap waits up to 35 s for a positional result.
- The only instant response is `tapNudgeFeet = 2` (`shared/GameConfig.luau:55`), and it fades within 0.6 s (`client/RaceView.client.luau:70-76`). That's a quarter of a length, seen from a chase camera 14 studs back. It's invisible.
- The bar labelled "SPEED" (`client/RaceController.client.luau:306-327, 1196-1210`) doesn't change speed. A kid will see a full SPEED bar while the horse sits 6th.

**Why it hurts.** The input has no physical consequence, so the bar becomes a minigame and the 3D race becomes wallpaper.

**Fix (M, no asset).**
- Preview live chances during every pace segment, not just the stretch. Generalise `previewStretch` to `previewPace(seg)` and call it every `GameConfig.pacePreviewSeconds = 1` once `GameConfig.pacePreviewMinPasses = 4` passes have finished.
- This leaks no luck: before the far turn, the offsets are skill-only (`RaceShape.offsets` with w = 0). `Trip.frame` already consumes `shownLive` (`RaceService.server.luau:878`). `raceView.maxGapFeetPerSecond = 10` keeps the motion believable.
- Raise `tapNudgeFeet` to 4–5.
- On a Great or Perfect tap, add a cosmetic stride surge on your own horse: `HorseLegs` cadence +15% for 0.4 s, a dust puff, and a 1° FOV kick (none under Reduced Motion). Put it behind a new key, `GameConfig.raceView.surge`.
- Rename SPEED to "GIDDY-UP", or drive leg cadence from it so the label is true.

### P2. A timing game where tapping makes no sound
**Evidence.**
- `shared/SoundAssets.luau` holds only the 8 `vo_*` announcer lines. `tap_good`, `gate_bell`, `gallop_loop`, `burst_whoosh`, `count_tick` and `lock_tick` don't exist, and `Sound.play` silently does nothing for a missing name (`client/Sound.luau:7`).
- Even with the sounds uploaded, only Great+ taps would play one (`RaceController.client.luau:622-625`).

**Why it hurts.** Rhythm and timing games run on audio confirmation. Without it, every tap feels like a missed tap. It's also the cheapest fix on this list.

**Fix (S, no asset).**
- Add a fallback table in `Sound.luau` that maps the missing names to Roblox built-in `rbxasset://sounds/...` clicks and swooshes (check each in Studio) until the generated effects land.
- Add `tap_ok`: a soft tick on *every* counted tap, with pitch rising by score band (Okay < Good < Great < Perfect).
- Hoofbeats (`gallop_loop`) under the whole race.

### P3. Skill can't reliably win, and losses go unexplained
**Evidence.**
- `GameConfig.luau` (bots by league) targets about 24% solo wins, "20–35% for new to skilled kids", with κ = 1.0 (`:275`). Riding skill moves an expert from 1-in-5 to 1-in-3.
- From the far turn, luck margins (up to `maxGap = 40` ft, `:46-53`) reorder the field in the stretch.
- A kid who rode ★★★ and finished 5th gets no line about their riding at all, because `ResultsText.gainedLine` stays silent on no gain. That's the right call on losses, but it leaves nothing in its place.

**Why it hurts.** Kids attribute the outcome to the thing they can't see. Once they decide the horse "just loses", the tapping verb dies. In a Mario Kart cup, a skilled player beats the CPUs most of the time. Here the best player loses two races in three.

**Fix.**
- **(a) S:** a skill-only win condition on the results card. Rank riders by S, which is already computed at `RaceService.server.luau:1101`, and show "Best ride in the race!" or "2nd best ride of 8". The line is honest, the kid controls it, and it doesn't depend on luck. Add a cosmetic Rider rosette for the Rosette Wall, with no cash and no points. Put it behind `GameConfig.results.riderRank = true`.
- **(b) M:** add an optional per-league `league.kappa` override (default `GameConfig.kappa`). Have `economy-analyst` run `sims/economy.py --solo` for a target like "a P90 rider wins ≥ 40% of solo Rookie races on a starter, average kid unchanged". Log it as provisional.

### P4. The Final Burst eats muscle-memory taps
**Evidence.**
- Pace taps stop 1.5 s before the burst (`burstLeadSeconds`). The first tap after `burstOpen` *is* the burst, with no retry (`RaceController.client.luau:595-600`, `RaceService.server.luau:324-333`).
- After a minute of tapping in rhythm, a kid's next reflex tap lands inside the first ~0.5 s at a random marker phase, which scores about 50 on the tap worth 40% of S.

**Why it hurts.** The biggest moment of the race is lost to a reflex, and the kid never learns why.

**Fix (S, no asset).**
- Add `GameConfig.burstArmSeconds = 0.5`. Taps that early are ignored on both the client and the server (`BurstTap` handler).
- Draw the bar grey until it's armed, then switch it to rainbow.
- This keeps D-022's anti-macro property. The marker's phase is still uniformly random; only the input is delayed, not the marker's start.

### P5. Practice doesn't practise the race
**Evidence.**
- Training rides (`shared/TrainingCourses.luau:9-17`: hoops, gate break, follow Pip, gymkhana) train free riding. Nothing rehearses the slider or the burst.
- A new rider gets one line, "Tap when the marker crosses the glow" (`RaceController.client.luau:1289`), and the first tap wipes it (`:621`). It never states the core rule: every pass needs exactly one tap, and an untapped pass scores 0 (`shared/PaceMeter.luau:98-107`).

**Why it hurts.** The first race is a live, paid race where the kid learns the rules by losing.

**Fix (S/M, no asset).**
- A non-scoring "Warm up!" slider on the queue card during the 15 s lobby wait (`client/QueueCard.client.luau`). It runs `PaceMeter.schedule` on the client with local labels and sends nothing to the server.
- First-race copy: "Tap once every time the marker passes the green!", held through the first 3 passes.
- Later (M): a "Rhythm Ride" course on the training oval that reuses `PaceMeter` and `BurstMeter`.

### P6. The HUD keeps the kid's eyes off the race
**Evidence.**
- Pace bar at y 0.80, speed bar at 0.75, judgement words and icon at 0.62, place badge top-right, steer pad bottom-left (`RaceController.client.luau:302-336, 776-791`).
- A judgement word every 0.55–1.2 s.
- The burst bar is 90% wide and 72 px tall at y 0.44 (`:303`), covering the turn for home, the most dramatic shot in the race.

**Fix (S/M, no asset).**
- Show each tap's judgement as a spark at the marker's position on the bar (rhythm games put the judgement where the hit happens). Keep words only for Perfect and Early/Late, behind `GameConfig.hud.tapWords = "perfectOnly"`.
- Move the burst bar to y ≈ 0.62 at 0.75 width.
- Put a small place ordinal on the right end of the pace bar, so position reads without looking away.

### P7. One verb, no breathing room, and steering it can't afford
**Evidence.**
- About 70 taps in a Rookie Mile; about 250 at Champion's 0.55 s pass in a Marathon.
- An untapped pass counts 0, so a kid who looks up to steer or watch loses score.
- The best trip is worth "about 2 points of a 100-point ride" (GAME_DESIGN, For grown-ups). That's about what two missed passes cost. Steering is the most-engineered system in the game and close to net-zero for a kid.

**Fix (M, no asset).**
- Phase the race with `GameConfig.pace.restSpans`: a 3 s "Steady…" breather at the far-turn lane lock, where the bell and "Lanes locked!" already land. `PaceMeter.schedule` and `RaceSession:paceSchedule` already take spans.
- Optionally slow the sweep while lanes are open, with `pace.steerPhaseSweepScale = 1.2`.
- Re-run the pace sims so the bot means stay calibrated.
- If playtests show kids don't steer, set `steering.scale = 0` rather than adding more steering rules.

### P8. The chance arrow contradicts good tapping
**Evidence.** The up/down arrow follows your live p (`RaceController.client.luau:1536-1540`), so it drops after "Great, Great, Great" whenever the field scored higher.

**Fix (S).** Make the checkpoint line relative: "Checkpoint 1: Great! Better than 5 riders". Point the arrow at the change in your *rank* among riders, not at p.

## 3. Genuinely good: do not break

- **The fairness core:** the exponential tilt (better timing never lowers your chance), purses locked before the gate, Diamonds kept away from win chance, and the live chance on screen being the exact p′ used.
- **Anti-macro design:** one tap per pass, a target that moves with speed drift, a uniformly random Final Burst phase, the latency-capped tap allowance (D-021), and the 150 ms bounce rule. Keep these as you change feel.
- **"The order on screen at the line is the result"** (D-033/D-055): no reshuffle, no near-miss shaping, and luck hidden until the far turn.
- **The `ridingGain` counterfactual** ("Your taps gained Comet 2 places!"): an honest, shown-only-when-positive attribution. Build P3a next to it.
- **Kind failure language:** no "Miss", a grey glow, Early/Late that says what to fix, "Finish strong!", no false starts, the 3-2-1 countdown.
- **Steering guardrails:** Smart Steer by default, never outward, no penalty for being boxed in, buttons only from race 4, brushes charged to the mover.
- **Everything is a config dial.** That's what makes every fix above cheap and reversible.

## 4. Top 5 must-do, in order

1. **Make taps audible (P2):** a fallback sound table, a tick on every tap pitched by score, hoofbeats. S.
2. **Make taps move the horse (P1):** live pace previews every second, a bigger nudge plus a cosmetic stride surge, an honest SPEED bar. M.
3. **Arm the Final Burst (P4):** `burstArmSeconds = 0.5` with a grey-to-rainbow bar. S.
4. **Give skill its own visible win (P3a, then P3b):** "Best ride in the race!" from S, a cosmetic Rider rosette, then a sim-validated per-league κ. S then M.
5. **Teach the rule before the first race and get eyes back on the track (P5 + P6):** the queue-card warm-up slider, first-race copy, judgement at the marker, the burst bar off the horse. S/M.

Run all five, then the PLAYTEST race section with kids on phones. Measure taps per pass, burst scores in the first 0.5 s, and whether kids can say "my taps made me faster". That's the Phase 1 gate in GAME_DESIGN.
