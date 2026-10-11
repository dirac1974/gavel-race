# AAA review — consensus and build plan (2026-10-11)

Four independent reviewers (gameplay, UI/UX, systems, feel) each wrote a review blind, then voted on every fix in all four reviews (`votes-*.md`). Out of about 40 merged fixes, none got a DISAGREE vote. Only fixes all four voted for are built. Where a voter attached a change, the change is part of the spec below. Decisions are D-066 to D-069, all `Accepted (provisional)`, listed in REVIEW_QUEUE.

## Cross-cutting rules agreed in voting

- **Draw-only.** Nudges, surges, effects and finish moments only change what is drawn, never the score, the order or the trip. `Trip.frame` and the steering τ calibration stay as they are, and any live preview uses a draw-only copy.
- **One camera-kick owner.** Total field-of-view change stays at or under +6°. A Perfect-tap kick is at most 1.5° and at most once every 0.8 s; the big kick belongs to the burst. Reduced Motion turns all kicks off.
- **No longer races.** The 3-2-1 countdown stays at 3 s. The finish moment lasts at most 2.5 s, can be skipped, and the results card is up within 4 s of the line.
- **Kind copy.** "Best ride" shows only for the top 3 rides and is never a leaderboard. Places 5 to 8 get praise for the ride, never "so close".
- **Music.** Only a beatless or ducked bed while the slider runs, so kids tap to the marker and not to a beat. Percussion is allowed only in the last stretch.
- **Words.** ★ means riding only (D-064), so a career mark is a "career patch", not a "career star". No new rosette types.
- **Tuning changes run in one sim.** The ladder retune, bot anchors and any κ change come from one simulation pass. Purse flattening waits until a Green Cash cosmetics sink exists. No entry fees, ever.
- **Feature freeze.** No new systems in this run. The meta gets a switch so David can playtest the core loop alone.
- **Meshy.** Everything is done in code first; the budget is 45 credits (25% of 180).

## Phases

### Phase 1 — Race feel and sound (D-066)
1. Sound now: synthesized stand-in effects for every planned effect name, packed into one sound sheet played with `PlaybackRegion` (one upload). `Sound.luau` reads the sheet when an effect has no own id, so ElevenLabs effects replace stand-ins as they arrive. A tick on every counted tap, pitched by its score. Hoofbeats under the race.
2. Taps visible on the horse: `tapNudgeFeet` 2 → 5 (draw-only); a cosmetic surge on Perfect; the feedback label pops; hoof dust from the existing art; all under `GameConfig.raceFx`.
3. Arm the Final Burst: `burstArmSeconds = 0.5`, the same on server, client and the Python mirror; the bar is grey until armed; the marker still starts at random.
4. Horse body bob driven by the leg phase (`HorseLegs.phaseOf`), not by a separate clock. Leg cadence unchanged (it follows distance).
5. Race HUD: the pace slider sits clear of the phone steering pad; "SPEED" is relabelled, since it doesn't change speed; the burst bar doesn't collide with the feedback label.
6. Live pace previews every second before the far turn, draw-only, with a test that they carry no luck. If this can't be done without touching `Trip.frame`, it is deferred.

### Phase 2 — Results, finish and the first minute (D-067)
1. Finish moment: horses gallop out past the line (`PAST_LINE`), a 2.5 s orbit using the replay camera rig, confetti for 1st, ribbons for 2nd to 4th, skippable.
2. Results card rebuilt at the floors: a place-ribbon headline, a 64 px "🏁 Race again" (`results.raceAgain`), "Best ride in the race!" for the top 3 only, kind copy for every place, and 64 px replay and Done buttons kept clear of the Roblox top bar.
3. First race coaching: "Tap once every time the marker passes the green", taught with the existing ghost thumb, and judgement shown at the marker.
4. First minute: the tour owns the screen and points at the real RACE! button; Skip sits apart from GO; the Next-thing pill puts racing before chores.
5. Phone screen budget: `Ui.slot` shows one top-centre card at a time; a compact 64 px queue card on phones (`queueCard.compactPhone`) with a "Warm up" button for the first 3 races; the pill says "in line" while queued; the ⚙️ gear moves below the 💎 pill.
6. Floors everywhere: `Ui.closeButton`, `Ui.fitPanel` on every panel, the Starter at the floors, and a lint test that fails any button under 56 px or text under 14 px. Race map text readable on phones. Contrast fixes for green and orange text.

### Phase 3 — Progression and friends (D-068)
1. One sim on realistic Ratings (training cap): retune `stakesUnlockPoints` and `botRatingAnchor` toward a casual kid reaching each league in about 20/40/90/180 races; update `tests/test_sims.py`.
2. Practice open across leagues (`queue.openPractice`), with one "Open" Practice queue and a "Race with [friend]" button.
3. Legend Retirement can be undone (`Leagues.unretire`), `career.suggest = false` until breeding exists, and the starter can't be retired while it is the only racer.
4. Core-playtest switch: one `GameConfig.corePlaytest` flag that turns off Spa, visits, careers, rehoming, Photo Finish and the Horse Book through their existing flags (off by default).
5. Word meanings: "career patch", and a one-meaning pass over stamp, rosette, badge and ribbon in player copy.

### Phase 4 — Presentation and world (D-069)
1. Gate line-up camera pass during the lobby wait; the countdown stays at 3 s.
2. Jockey crouch-and-pump pose driven in code from the stride phase (Motor6D), instead of the default sit.
3. County Fair track dressing in code: bunting, flags, a billboard crowd, a Big Board that shows the race.
4. Race HUD restyled to the art direction (no dark green boxes, no red-to-green meter); the YOU marker moved off the middle of the chase view.
5. A beatless music bed, ducked while the slider runs, if a source is available (ElevenLabs music permission or a synthesized pad).
6. Meshy only where code can't reach the look (for example a crowd block), within what is left of 45 credits.

## Deferred (agreed, waiting for playtest data)
- Rest spans at the lane lock (changes the bot calibration sims).
- Per-league κ beyond what the Phase 3 sim needs.
- Purse flattening (needs the cosmetics sink first).
- Three-layer music.
- Any `steering.scale` change.

## Process per phase
Developers implement → test-engineer (pytest, Lune, policy guard) → code-reviewer → fix blocking findings → the four reviewers consult with the developers on the built phase → agreed fixes → scribe (DECISIONS, REVIEW_QUEUE, STATUS, CHANGELOG) → commit and push `claude/aaa-review`.
