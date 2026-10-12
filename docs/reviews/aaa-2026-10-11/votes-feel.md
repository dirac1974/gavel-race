# Consensus votes: feel and presentation reviewer (2026-10-11)

How to read this:
- **Priority:** 1 = before the first Studio playtest, 2 = right after it, 3 = later.
- **Source reviews:** F = feel, G = gameplay, U = ui-ux, S = systems. Duplicates are merged into one row.
- **Hard rules:** none of the fixes breaks the no-wagering rule or the rule that Diamonds never touch win chance. Kid-safety caveats are flagged in the notes.

## Audio and tap response

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| A1 | Stand-in sound effects now: a hand-edited override table merged in `Sound.luau` | F-P1, G-P2 | AGREE-WITH-CHANGE | 1 | Use Roblox-owned Creator Store audio, not only `rbxasset://sounds` built-ins. Very few built-ins exist and they sound like a generic test place. Keep the override table out of the generated `SoundAssets.luau`. |
| A2 | A soft tick on every counted tap, pitched up by score band | G-P2 | AGREE | 1 | Best single feel fix in any review. Use `PlaybackSpeed` steps on one sample so only one asset is needed. |
| A3 | Hoofbeat loop under the whole race | F-P1, G-P2 | AGREE | 1 | Already wired (`gallop_loop`); it only needs an id. |
| A4 | Race music bed in 3 layers (gate, far turn, stretch) behind `audio.music` | F-P1, F-P7 | AGREE | 2 | My own fix. Take it from Roblox's licensed music library. Duck it under voice lines. |
| B1 | Raise `tapNudgeFeet` from 2 to about 5 (drawn only, never ranked) | F-P2, G-P1 | AGREE | 1 | Both reviews give the same number. Log it as provisional. It's safe because places are ranked without it (`RaceView` :37-39). |
| B2 | Cosmetic surge on Great or Perfect: trails, hoof dust, FOV kick, 3° lean | F-P2, G-P1 | AGREE-WITH-CHANGE | 1 | Make the FOV kick a config value of about 2–3° (G says 1°, I said 4°). Drop G's "+15% leg cadence": the legs follow distance travelled, so the bigger nudge already speeds them up, and forcing cadence would make the feet slide. Off under Reduced Motion. |
| B3 | Feedback word pops (0.6 → 1.0, hold, fade) | F-P2 | AGREE | 1 | Combine with B4: pop only the words that are still shown. |
| B4 | Judgement as a spark at the marker on the bar; words only for Perfect, Early and Late (`hud.tapWords`) | G-P6 | AGREE | 2 | Good rhythm-game practice, and it cuts reading. Keep "Early" and "Late" because they say what to fix. |
| B5 | Preview live chances every second during pace segments (`previewPace`) so taps move the horse | G-P1 | AGREE-WITH-CHANGE | 1 | See C1 below: `Trip.frame` reads `shownLive`, so this changes steering gaps and possibly τ. Either use a draw-only copy for the screen or re-run `sims/steering.py`. Skill only until the far turn, as G says. |
| B6 | Make SPEED honest: rename it or drive cadence from it; replace the red→green gradient | G-P1, F-P8 | AGREE | 1 | The red-to-green gradient breaks ART_DIRECTION's no-red rule. Use gold on slate and rename it "GIDDY-UP". |

## Horse, rider and race pacing

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| C1 | Sync the body bob to the leg phase (`HorseLegs.phaseOf`) and squash on the beat | F-P4 | AGREE | 1 | My own fix. It's S-sized and fixes replays too. |
| C2 | Jockey crouch-and-pump animation authored in Studio, timed to the stride, replacing the chair-sit | F-P3 | AGREE | 1 | Needs an animation owned by the group (0 Meshy credits). Never a whip. |
| C3 | Arm the Final Burst: ignore taps in its first 0.5 s (`burstArmSeconds`), grey bar until armed | G-P4 | AGREE | 1 | The server must enforce it too. This doesn't touch D-022's random phase. Sound can mark "armed": the whoosh at arm time, not at open. |
| C4 | Move the burst bar to y 0.62 at 0.75 width so it stops covering the turn for home | G-P6 | AGREE-WITH-CHANGE | 2 | y 0.62 is where the feedback label sits. Move that label above the bar while the burst is up. |
| C5 | 3 s "Steady…" rest span at the far-turn lock (`pace.restSpans`) | G-P7, F-P7 | AGREE | 2 | Exactly the breather the race's emotional curve needs. Re-run the pace and bot sims. The "Into the far turn!" line and a music swell land well here. |
| C6 | Slower sweep while lanes are open (`steerPhaseSweepScale`) | G-P7 | AGREE-WITH-CHANGE | 3 | Only after playtest data. It's a gate and weight change that needs sims. |
| C7 | Set `steering.scale = 0` if kids don't steer in the playtest | G-P7, S-P4 | AGREE | 2 | Decide this after the playtest. Keep the visuals (smooth lanes look good) even at scale 0. |
| C8 | Checkpoint line relative to riders ("Better than 5 riders"), arrow from rank change | G-P8 | AGREE-WITH-CHANGE | 2 | Positive phrasing only. Never "Worse than 6". When the line can't be positive, show stars only. |
| C9 | Mid-race beats: checkpoint banner with stars, a place-up pop (never a place-down pop), FOV ease | F-P7 | AGREE | 2 | My own fix. Combine it with C8's line. |
| C10 | Gate intro: 5 s countdown, white fade at the seat, line-up camera pass | F-P6 | AGREE | 2 | My own fix. `gateCountdownSeconds` is read on the server (tStart), so it's a config change plus a playtest check that tap scheduling is unchanged. |

## Results and finish

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| D1 | Rebuild the results card: floored sizes, a place headline with the ribbon, a 64 px Race again, Done out of the top bar | U-P3, F-P5 | AGREE | 1 | The biggest overlap across reviews. Order: finish sequence (D2) → card → Race again. Race again isn't a purchase prompt, so rule 3 holds. Never put the 💎 door on this card. |
| D2 | Finish moment: orbit camera, confetti for 1st, ribbon stamps for 2nd–4th, counting stars for everyone, gallop-out past the line (`PAST_LINE` about 0.04) | F-P5 | AGREE | 1 | My own fix. Keep it to 2.5 s so it doesn't delay D1's Race again. Skip the orbit under Reduced Motion. |
| D3 | "Best ride in the race!" rider rank from S on the results card, plus a cosmetic Rider rosette | G-P3a | AGREE-WITH-CHANGE | 1 | Show it only for ranks 1–3 among the field ("Best ride!", "2nd best ride!"). "7th best ride of 8" is shaming (rule 3 spirit). The rosette is cosmetic only, with no cash and no League Points. |
| D4 | Per-league κ override, validated by sims, so a P90 rider wins ≥ 40% of solo Rookie races | G-P3b | AGREE-WITH-CHANGE | 2 | Only after D3 and B5 ship and the playtest shows kids still blame luck. It's a weight change, so it needs the economy-analyst sim and a provisional decision. It also interacts with S1's bot anchors, so tune both in one sim pass. |

## Onboarding and phone layout

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| E1 | First race coaching: ghost thumb over the glow for 4 passes, "NOW!", "Tap once every pass", warning before the burst | U-P5, G-P5 | AGREE | 1 | Both reviews ask for it. Reuse the existing steering ghost-thumb tip. |
| E2 | Non-scoring warm-up slider on the queue card | G-P5 | AGREE-WITH-CHANGE | 2 | This fights U-P1's compact phone card. On phones, show it only when the card is tapped open. It must send nothing to the server. |
| E3 | "Rhythm Ride" training course reusing PaceMeter and BurstMeter | G-P5 | AGREE-WITH-CHANGE | 3 | Good idea, but it's a new system. Defer it under S-P4's feature freeze. |
| E4 | Top-centre slot arbiter, compact phone queue card, "in line" pill, move the gear off the 💎 pill | U-P1 | AGREE | 1 | A broken first screen hides every feel fix. |
| E5 | Tour owns the screen, pulse the real RACE! button, Skip away from GO, advance on JoinRace | U-P2 | AGREE | 1 | Combine with E6. |
| E6 | Next-thing pill: race first (first session / after the first feed of the day), order as config | U-P2, S-P6 | AGREE | 1 | One config list, `nextThing.order`, covers both. |
| E7 | On phones, keep the pace bar clear of the steering pad; race map phone mode | U-P4 | AGREE | 1 | A hidden target is a lost tap. The pad only exists from race 4, so this is about layout, not first contact. |
| E8 | Floors everywhere: `Ui.closeButton`, Starter through `fitPanel`, lint test for small buttons and text | U-P6 | AGREE | 2 | Do the Starter screen first (priority 1). |
| E9 | 4-item phone dock with Ride; tappable horse card | U-P7 | AGREE-WITH-CHANGE | 3 | Check in the emulator against the thumbstick zone before changing it (D-056). |
| E10 | Text contrast colours (`textGood`, `textWarn`) and a contrast test | U-P9 | AGREE | 2 | Cheap, and an accessibility must. |

## Words and art coherence

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| F1 | One meaning per word: Ride, 🐴, distance words, stamps, rosettes, badges, ribbons | U-P8, S-P4 | AGREE-WITH-CHANGE | 2 | Use S's mapping, but not "career star": ★ is riding-only (D-064). Use "career patch". "Ribbon" stays the prize colours only. |
| F2 | Race HUD to the art direction: Paper/Ink, Fredoka, smaller YOU marker in the chase view | F-P8, U (lower) | AGREE | 2 | Do it alongside D1 so every race screen matches. |
| F3 | Track dressing: bunting, billboard crowd, live Big Board | F-P8 | AGREE | 2 | Code only. Meshy is held (30 + 10) in case the billboard crowd fails. |

## Systems and economy

| id | fix (one line) | source | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| G1 | Rebuild the progression sim on realistic Ratings; retune `stakesUnlockPoints`, `botRatingAnchor`, `Training.raceGain` | S-P1 | AGREE | 1 | Gate and threshold changes, done properly through the sim. The S1 bot anchors interact with D4's κ, so run them in one pass. |
| G2 | Flatten league purses B (20/35/50/70/100) | S-P2 | AGREE-WITH-CHANGE | 2 | Sinks first (G3), then flatten by sim. B changes the 300-race parity fixtures and D-017. A Champion purse of 100 also kills the "big race" feel, so keep a visible step at each league. |
| G3 | Green Cash cosmetics tier in Style (`currency = "cash"`) | S-P2 | AGREE | 2 | Rule 2 is fine: cosmetics only, and Green Cash still isn't sold. |
| G4 | No entry fees | S-P2 | AGREE | 1 | Entry fees would read as stakes (rule 1). Recorded so nobody proposes one later. |
| G5 | Open Practice across leagues (`queue.openPractice`) and "Race with [friend]" | S-P3 | AGREE | 1 | Practice pays nothing and touches no win chance, so it's safe. Friends shouting together is the pitch. Cash races still keep friends apart (D-006). |
| G6 | Feature freeze; first playtest with the meta flags off | S-P4 | AGREE | 1 | Feel fixes only until the core is measured. This puts E3 and the rest of the meta on hold. |
| G7 | Stable Star tiers ×2 and ×4 after the last goal | S-P4 | AGREE | 3 | Config data, but only after the freeze. |
| G8 | Legend reversible (`Leagues.unretire`) and `career.suggest = false` until breeding exists | S-P5 | AGREE | 2 | Kid safety: an irreversible two-tap loss of a bonded horse is the real issue. |
| G9 | Fold the Spa into the Vet as one card; build nothing more on Energy | S-P7 | AGREE-WITH-CHANGE | 3 | Agree that nothing more should be built on Energy. Hold the Spa fold until the playtest shows it's confusing; it's already built and tested. |

## Conflicts between fixes

- B5 and the steering calibration: `Trip.frame` reads `shownLive`, so B5 changes steering unless it gets a draw-only copy.
- E2 and E4 compete for phone screen space; E4 wins.
- C4 and the feedback label both sit at y 0.62.
- D2's finish sequence must not delay D1's Race again.
- D4 and G1 both move win rates, so they need one combined sim.
- F1's "career star" clashes with ★ being riding-only.
- G6's freeze puts E3, G7 and G9 on hold.
