# Votes: UI/UX reviewer (2026-10-11)

Sources: G = gameplay.md, S = systems.md, F = feel.md, U = ui-ux.md. Duplicates are merged into one row.

Priority: 1 = before the first kid playtest, 2 = the round after it, 3 = later. All fixes are code and config only unless a row says otherwise.

## Votes

### Audio

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| A1 | Stand-in sounds now: a hand-edited name→id override table (`SoundOverrides.luau`) over the generated ids, using Roblox-owned or built-in audio | G P2, F P1 | AGREE | 1 | The cheapest feel win in all four reviews. Use one table, not two fallbacks. |
| A2 | A soft tick on every counted tap, pitched by score band, and hoofbeats under the whole race | G P2 | AGREE | 1 | A miss should stay silent, keeping D-055's "no failure word" spirit. |
| A3 | A three-layer race music bed cued from `tFar` and `burstOpen` (`audio.music`) | F P1 | AGREE-WITH-CHANGE | 2 | Give music its own Settings toggle, separate from Sound. Duck the music under voice lines. Don't block A1 on it. |

### Taps and the horse

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| B1 | Raise `tapNudgeFeet` from 2 to 4–5 | G P1, F P2 | AGREE | 1 | It must stay draw-only and inside `raceView.maxGapFeetPerSecond`. Re-run the overlap report so no lurch returns (D-055). |
| B2 | Cosmetic tap surge on Great or Perfect: Trails, hoof dust (`fx_dust_puff`), body pitch, an FOV kick on Perfect, the feedback label pop | G P1, F P2 | AGREE-WITH-CHANGE | 1 | Choose one config table (`raceFx`, not also `raceView.surge`). FOV +4 only on Perfect, everything off under Reduced Motion, and FOV kicks capped to 1 per 2 s so it doesn't cause motion sickness. |
| B3 | Live pace previews every second before the far turn (`previewPace`, `pacePreviewSeconds`) | G P1 | AGREE-WITH-CHANGE | 1 | Test that previews before the lock carry zero luck terms. This also makes the place badge move during play, so pair it with D3. |
| B4 | Rename the SPEED bar to "GIDDY-UP", or drive leg cadence from it | G P1 | AGREE | 2 | Use the rename (S). Also take F's colour change from red→green to gold-on-slate (F P8). |
| B5 | Sync the body bob to the leg phase (`HorseLegs.phaseOf`), with squash on the forefoot plant | F P4 | AGREE | 2 | S. Replays are fixed by the same change. |
| B6 | A crouch-and-pump jockey animation instead of the R15 sit (`raceView.jockeyAnim`) | F P3 | AGREE | 2 | Needs one animation authored in Studio, no Meshy. Keep the sit as the fallback. Never show a whip. |

### Race HUD

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| C1 | Show the tap judgement as a spark at the marker; words only for Perfect, Early and Late (`hud.tapWords`) | G P6 | AGREE | 1 | Fewer words mid-screen is good for 8-year-olds. Early and Late stay because they teach. |
| C2 | Move the burst bar to y ≈ 0.62 at 0.75 width, off the turn for home | G P6 | AGREE-WITH-CHANGE | 2 | Under C1 the feedback label sits at y 0.62, so hide it during the burst. On phones, keep the bar's height at least 64 px. |
| C3 | Phone race layout: keep the pace bar and speed meter clear of the ◀ ▶ pad; race map in a phone mode with text ≥ 14 px | U P4 | AGREE | 1 | A target hidden behind Out ▶ is a lost tap. Combine with C2 so all three reviews converge on one phone layout pass. |
| C4 | A small place ordinal on the right end of the pace bar | G P6 | AGREE-WITH-CHANGE | 2 | Use it on phones in place of the place badge, not as well as it. One place readout. |
| C5 | Restyle the race HUD to `Ui.colors` paper and ink with Fredoka | F P8, U | AGREE | 2 | Do it inside the D1 rebuild; don't run it as a separate pass. |
| C6 | Rider's YOU marker lower (7 studs) and smaller (60 px) in the chase view | F P8 | AGREE | 2 | Keep full size for spectators and replays, as F proposes. |

### Results and finish

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| D1 | Results card rebuild: floored sizes, a place-ribbon headline, a 64 px "🏁 Race again", Done out of the top bar | U P3, F P5 | AGREE | 1 | Merged with F's ribbon stamps. Race again is not a purchase moment, so D-050 is unaffected. |
| D2 | Finish sequence: 2.5 s orbit camera, confetti and a gold Highlight for 1st, ribbon stamps for 2nd–4th, stars counting up for 5th–8th, gallop-out past the line | F P5 | AGREE-WITH-CHANGE | 2 | Any tap skips the orbit. The card with Race again must be up within 4 s of the line. Confetti on your own screen only. |
| D3 | "Best ride in the race!" / "2nd best ride of 8" from S, plus a cosmetic Rider rosette | G P3a | AGREE-WITH-CHANGE | 1 | Private to your own card; it can never become a board or leaderboard (D-042). It's the honest headline for a kid who lost, so it goes into D1's layout. Systems S4 renames "rosette": call this a Rider ribbon if the rosette is reserved for the Wall. |
| D4 | The chance arrow follows rank change among riders ("Better than 5 riders"), not p | G P8 | AGREE | 2 | Removes the case where "Great, Great, Great" shows a down arrow. |
| D5 | Pop the place badge only on a gain; checkpoint banners with stars and a crowd swell | F P7 | AGREE-WITH-CHANGE | 2 | Keep banners small and at the bar, not mid-screen. That conflicts with G P6's "eyes on the track" goal, so playtest one variant. |

### Start and the first minute

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| E1 | Gate intro: countdown 3→5 s, white fade around the seat, a 2 s line-up dolly | F P6 | AGREE-WITH-CHANGE | 2 | The fade: yes, it's S. The dolly only for a rider's first 10 races, or skippable, and the total gate time stays ≤ 5 s. Every second here is added to every race (taps-to-race). |
| E2 | Arm the Final Burst: ignore taps in its first 0.5 s and draw the bar grey until armed (`burstArmSeconds`) | G P4 | AGREE | 1 | A small fix for the biggest moment. Mirror the rule on the server and in the Python model (parity). |
| E3 | First-race teaching: a ghost thumb or "NOW!" on the first passes, the copy "Tap once every time…" held for 3 passes, and a heads-up before the burst | U P5, G P5 | AGREE | 1 | Merged. Reuse the existing steering ghost thumb. |
| E4 | A non-scoring warm-up slider on the queue card while waiting | G P5 | AGREE-WITH-CHANGE | 2 | Conflicts with U P1: on a phone the queue card already covers half the screen. Make it a "Warm up" button on the compact card that expands, for the first 3 races only. Sends nothing to the server. |
| E5 | Tour owns the screen: hide the pill and the Starter toast during the tour, teach the real RACE! button, move Skip away from GO, advance the tour on joining the line | U P2 | AGREE | 1 | |
| E6 | Next-thing pill puts "Race with Comet" first (after the first feed of the day; race first before the first race); a configurable `nextThing.order` | S P6, U P2 | AGREE | 1 | Merged. Two reviews found this independently. |

### Phone layout and copy

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| F1 | Top-centre slot arbiter, a compact phone queue card, the pill reads "in line" while queued, the gear moved off the 💎 pill | U P1 | AGREE | 1 | |
| F2 | Floors everywhere: `Ui.closeButton`, `fitPanel` on every panel starting with the Starter, a lint test for buttons < 56 px and text < 14 px | U P6 | AGREE | 1 | Feeds S P4 too: fewer panels to floor if the meta is switched off. |
| F3 | A 4-item phone dock: tappable horse portrait, RACE!, 🐴 Ride, ☰ More | U P7 | AGREE | 2 | Thumbstick conflict to be checked in the emulator. |
| F4 | One meaning per noun: Rosette = the Wall only, Medal = training golds, Sticker = Passport, Pin = friend tours, Stamp = monthly only, Badge = league only, class = "tag", 25-race award = "career patch" | S P4, U P8 | AGREE-WITH-CHANGE | 2 | Use "career patch", never "career star": ★ means riding only (D-064). Add U's "Ride" verb split ("🏁 Race this one") and the race screen's "Sprint" → "🐇 Short". A copy test can enforce it. |
| F5 | Text colours that pass contrast (`textGood`, `textWarn`) and a contrast test | U P9 | AGREE | 2 | |

### Progression and economy

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| G1 | Rebuild the progression sim on Ratings the training cap can produce; retune `stakesUnlockPoints` and `botRatingAnchor`; optional `Training.raceGain`; update the test bands | S P1 | AGREE | 1 | The most important non-UI finding. A 10x cliff at Silver is a quit point that no UI polish can hide. Sim first, then provisional decisions. |
| G2 | Per-league κ override, validated by the sim, so a top rider wins ≥ 40% of solo Rookie races | G P3b | AGREE-WITH-CHANGE | 2 | Run it in the same sim pass as G1; the two interact, since both move win rates. Average-kid rates must stay in band. |
| G3 | Flatten league purses B (e.g. 20/35/50/70/100) | S P2 | AGREE-WITH-CHANGE | 2 | Only after G1's sim, because B also feeds the D-062 Cup pacing. Make it cash-for-placing only; never entry fees, as S says (rule 1). |
| G4 | Green Cash cosmetics tier in `Style` (yard, paint, plates, 500–5,000) | S P2 | AGREE | 2 | Healthy: earnable cosmetics with Diamond variants alongside them. No timers and no "limited". |
| G5 | Open Practice to every league (`queue.openPractice`), plus "Race with [friend]" from the Friends' barns list | S P3 | AGREE | 1 | Roblox friends only, joining a no-prize Practice. Kid-safe. The button goes on the queue card's More too. |
| G6 | `Leagues.unretire` ("Back to the races"); `career.suggest = false` until breeding exists | S P5 | AGREE | 1 | Kid safety: irreversible loss of a bonded horse after two taps is the wrong default. |
| G7 | Fold the Spa into one Vet "Check-up & Spa" card; build nothing more on Energy | S P7 | AGREE-WITH-CHANGE | 3 | Fine as a UI merge. Keep the D-058 nap cues; they are kind, clear rest signals. |
| G8 | Repeatable Stable Star tiers (×2, ×4) | S P4 | AGREE | 3 | Config data only. |

### Pacing and scope

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| H1 | Freeze new systems; first playtest with the meta flags off (spa, visit, career, rehome, photo, horseBook) | S P4 | AGREE | 1 | Also cuts the UI surface P6 has to floor. Turn the meta back on in a second session. |
| H2 | A 3 s "Steady…" rest span at the lane lock (`pace.restSpans`) | G P7 | AGREE-WITH-CHANGE | 2 | It touches scoring, so sims and Python/Luau parity come first. The bell and "Lanes locked!" already land there, so it's good for readability. |
| H3 | Slower sweep while lanes are open (`steerPhaseSweepScale = 1.2`) | G P7 | AGREE-WITH-CHANGE | 3 | Only if the playtest shows kids drop taps while steering. Bot means must be re-run. |
| H4 | `steering.scale = 0` if kids don't steer, rather than more steering rules | G P7, S P4 | AGREE | 3 | It's a playtest decision. The switch already exists. |
| H5 | A "Rhythm Ride" training course reusing `PaceMeter` and `BurstMeter` | G P5 | AGREE | 3 | After H1, since it's a new system. |
| H6 | Measure attention at Sprint length before touching race speed | F P7 | AGREE | 2 | A measurement step, not a change. |

### World presentation

| id | fix (one line) | source | vote | priority | note |
|---|---|---|---|---|---|
| I1 | Track dressing: bunting, billboard crowd, live top-4 Big Board | F P8 | AGREE-WITH-CHANGE | 3 | The Big Board shows lane chips and names only, never win % or purses (D-055). |
| I2 | Meshy crowd bench (30) plus a retexture (10), only if the billboards read badly | F | AGREE | 3 | Conditional spend. |

## Conflicts flagged

- **E4 vs F1:** the warm-up slider would make the queue card bigger, while the phone screen budget needs it smaller. Resolved as an expandable button on the compact card.
- **D2 / E1 vs the race-again loop:** an orbit plus a longer gate add seconds to every race. Both must be skippable, with hard time caps (card ≤ 4 s after the line, gate ≤ 5 s).
- **D5 vs C1:** mid-race banners would put text back mid-screen. Keep them at the bar.
- **F4:** "career star" breaks ★ = riding only (D-064). Use "patch".
- **G3 vs G1:** purse changes interact with Cup pacing, so sim them together.
- **Hard rules:** no fix adds wagering, entry fees, paid power or purchase prompts near races. D3 and D4 compare riders only on the kid's own card. G5 is friends-only Practice with no prizes.
