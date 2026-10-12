# Consensus votes: systems and progression reviewer (2026-10-11)

These are my votes on every distinct fix in the four reviews: gameplay.md (GP), ui-ux.md (UX), feel.md (FX) and systems.md (SY). I merged the duplicates.

- **Priority:** 1 = before or at the first playtest, 2 = straight after, 3 = later or only if the data asks for it.
- **Fair-race rules:** a "draw-only" effect changes what the screen shows and never the race result or win chance. Every effect of that kind must stay draw-only and sit behind a config key.

## Votes

| id | fix (one line) | source review(s) | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| V01 | Sound stand-ins now: a hand-edited override table of Roblox-owned or built-in sounds over the missing effect ids | GP P2, FX P1 | AGREE | 1 | It's the cheapest, highest-impact fix. Use FX's `SoundOverrides.luau` as the single mechanism, not two fallback tables. |
| V02 | A soft tick on *every* counted tap, its pitch rising with the score band | GP P2 | AGREE | 1 | A timing game needs this. Keep "Okay" audibly neutral, not a fail sound. |
| V03 | Hoofbeat loop under the whole race | GP P2, FX P1 | AGREE | 1 | Merged into V01. |
| V04 | Race music bed in 3 layers (gate, far turn, stretch), `audio.music` | FX P1 | AGREE-WITH-CHANGE | 2 | Ship one licensed loop first. Layers come after the playtest says the race feels flat. It must sit under the voice lines and under the Sound Off setting. |
| V05 | Raise `tapNudgeFeet` from 2 to 4–5, draw-only | GP P1, FX P2 | AGREE | 1 | GP and FX agree. Log it as provisional, as a draw-only change. |
| V06 | A cosmetic surge on Great or Perfect taps: leg cadence, Trails, hoof dust, body pitch, FOV kick, label pop | GP P1, FX P2 | AGREE-WITH-CHANGE | 1 | Make it one `raceFx` table with one owner, not GP's `raceView.surge` plus FX's `raceFx`. Cap the total FOV change across V06, V25 and V26 at about +6°. All of it off under Reduced Motion. |
| V07 | Live pace previews every second during pace segments (`previewPace`) | GP P1 | AGREE | 1 | Before the far turn the gaps are skill-only, so no luck is revealed. This is what makes taps *move* the horse. Run the overlap and playback checks again, since gaps move more often. |
| V08 | Rename the SPEED bar ("GIDDY-UP"), or drive leg cadence from it; colour it gold over slate, not red to green | GP P1, FX P8 | AGREE | 1 | A false label teaches a false model. The colour change also fixes an ART_DIRECTION breach. |
| V09 | Ignore Final Burst taps for `burstArmSeconds = 0.5` and show a grey bar until it's armed | GP P4 | AGREE | 1 | It keeps D-022's uniformly random marker phase. Only input is delayed. Add the same gate on the server's `BurstTap`. |
| V10 | Show riders their skill rank: "Best ride in the race!" / "2nd best ride of 8" from S | GP P3a | AGREE-WITH-CHANGE | 1 | Yes to the line. No to a new "Rider rosette", which would add a sixth meaning to "rosette" (SY P4). Count it as a Stable Star skill goal instead. Rank against everyone in the race, bots included, and say "ride", never "odds". |
| V11 | Per-league `kappa` (how much riding skill counts) so a P90 rider wins ≥ 40% of solo Rookie races, sim-validated | GP P3b | AGREE-WITH-CHANGE | 2 | Run it in the **same** sim pass as V30 (bot anchors and unlock points). Tuning kappa and the anchors separately will fight. Riding skill only, so no Diamond or wagering conflict. |
| V12 | Up/down arrow follows your rank among riders, not live p ("Better than 5 riders") | GP P8 | AGREE | 2 | It's honest and can't read as odds. Keep it positive-only on screen, like `gainedLine`. |
| V13 | "Warm up!" slider on the queue card while waiting, client-only, sends nothing | GP P5 | AGREE-WITH-CHANGE | 1 | Yes, but it competes with UX P1's compact phone queue card for the same 375 px. On phones the warm-up replaces the gate slots while it runs. |
| V14 | First-race coaching: ghost thumb over the glow for 4 passes, "Tap once every pass", "Big tap coming!" before the burst | GP P5, UX P5 | AGREE | 1 | Merged duplicate. Reuse the steering ghost thumb. Copy stays ≤ 10 words. |
| V15 | Later: a "Rhythm Ride" training course reusing PaceMeter and BurstMeter | GP P5 | AGREE-WITH-CHANGE | 3 | Only if V13 and V14 aren't enough. This is a new system, which the feature freeze (V33) holds back. |
| V16 | Judgement shown at the marker; words only for Perfect and Early/Late (`hud.tapWords`) | GP P6 | AGREE | 2 | It keeps eyes on the race and fits V06's label pop. |
| V17 | Move the burst bar to y ≈ 0.62 at 0.75 width | GP P6 | AGREE | 2 | Check it against UX P4's phone layout so it doesn't collide with the steering pad. |
| V18 | Small place ordinal at the right end of the pace bar | GP P6 | AGREE | 2 | — |
| V19 | 3 s "Steady…" rest span at the lane lock; slower sweep while lanes are open | GP P7 | AGREE-WITH-CHANGE | 3 | It changes pace scoring and bot calibration (D-026 sims). Do it after the playtest, and only if kids miss passes while steering. |
| V20 | If kids don't steer, set `steering.scale = 0` rather than adding steering rules | GP P7, SY P4 | AGREE | 1 | Decide from the playtest. Freeze any new steering work now. |
| V21 | Top-centre slot arbiter (queue card > tour > toasts) | UX P1 | AGREE | 1 | Overlap reads as broken. It's a small `Ui.slot` helper. |
| V22 | Compact phone queue card, pill says "You're in line!", RACE! shows seconds only, gear moved off the 💎 pill | UX P1 | AGREE | 1 | D-061's "groom while you wait" promise depends on it. |
| V23 | The tour owns the screen: hide the pill and the Starter toast, pulse the real RACE!, advance on JoinRace, quiet ✕ Skip | UX P2 | AGREE | 1 | — |
| V24 | Next-thing pill puts race ahead of chores (`raceFirstUntilRaces`, or a config order) | UX P2, SY P6 | AGREE | 1 | Merged. I'd go further: after the first feed of the day, race comes before jobs, with a `nextThing.order` list. |
| V25 | Results card rebuild: floored sizes, a ribbon place headline, "You rode ★★☆", a 64 px 🏁 Race again, Done out of the top bar | UX P3, FX P5 | AGREE | 1 | Race again is not a purchase prompt, so D-050 holds. If the horse is napping, Race again joins Practice and must say so. |
| V26 | Finish sequence: orbit camera, confetti for 1st, ribbon stamps for 2nd–4th, counting stars for 5th–8th, gallop-out past the line | FX P5 | AGREE-WITH-CHANGE | 2 | Keep it to 2.5 s or less and skippable by tap. It must never delay V25's Race again. 5th–8th praise the ride (stars), never "so close" near-miss copy. |
| V27 | Keep the phone slider clear of the steering pad; race map phone mode with no digits and floored text | UX P4 | AGREE | 1 | A hidden target is a lost tap the kid blames on themselves. |
| V28 | Floors everywhere: `Ui.closeButton`, Starter and other panels through `fitPanel`, a lint test for any button < 56 px or text < 14 px | UX P6 | AGREE | 1 | The Starter is the first screen. A lint test makes the floor stick. |
| V29 | Phone dock with 4 items: horse portrait, RACE!, 🐴 Ride, ☰ More | UX P7 | AGREE | 2 | Riding is the fantasy. Re-run the D-064 floor test with 4 items. |
| V30 | Rebuild the progression sim on realistic Ratings; retune `stakesUnlockPoints` and `botRatingAnchor`; optional `Training.raceGain` | SY P1 | AGREE | 1 | My own fix. Sim it together with V11. Update `tests/test_sims.py`. |
| V31 | Open Practice to every league plus "Race with [friend]" (`queue.openPractice`) | SY P3 | AGREE | 1 | My own fix. Practice pays nothing, so mixed fields carry no fairness or wagering risk. |
| V32 | Flatten purses `B` and add Green Cash decor in `Style` | SY P2 | AGREE | 2 | My own fix. No entry fees (rule 1). Flattening B changes the Python reference, so keep parity. |
| V33 | Feature freeze; first playtest with the meta flags off; measure the Phase 1 gate and D1 | SY P4 | AGREE | 1 | Every review says to fix the core before adding features. |
| V34 | One meaning per word: stamp, rosette, badge, ribbon, Ride, 🐴; status line distance word from `PickerText` | SY P4, UX P8 | AGREE | 2 | Merged duplicate. My mapping is in systems.md; UX adds "Race this one" and a Pip icon. |
| V35 | Repeatable Stable Star tiers (×2, ×4) | SY P4 | AGREE | 3 | Config data only. Do it before the D30 cliff matters. |
| V36 | `Leagues.unretire` plus `career.suggest = false` until breeding exists | SY P5 | AGREE | 1 | Kid safety: no permanent loss behind two taps. |
| V37 | Fold the Spa into the Vet as one "Check-up & Spa" card; build nothing more on Energy | SY P7 | AGREE | 3 | Not urgent. Fewer loops. |
| V38 | Text colours `textGood` / `textWarn` and a contrast check | UX P9 | AGREE | 2 | — |
| V39 | Jockey crouch-and-pump animation authored in Studio, speed from the stride rate | FX P3 | AGREE | 2 | Needs Studio time, but no Meshy credits. No whip pose. |
| V40 | Body bob synced to the leg phase (`HorseLegs.phaseOf`) with squash on the forefoot plant | FX P4 | AGREE | 2 | It's cheap and fixes replays too. |
| V41 | Gate intro: 5 s countdown, white fade, line-up dolly | FX P6 | AGREE-WITH-CHANGE | 3 | Keep the 3 s countdown and run the dolly during the existing 15 s wait. Two more seconds per race adds wait time in every race. |
| V42 | Mid-race beats: checkpoint banner with stars, crowd swell, place-badge pop only when your place goes up, FOV ease on the backstretch and at the burst | FX P7 | AGREE-WITH-CHANGE | 2 | Keep the banner small and off the slider (it conflicts with V16 and V17's "eyes on track"). The FOV ease counts toward V06's cap. |
| V43 | Track and HUD art pass: bunting, billboard crowd, live Big Board, Paper/Ink HUD restyle, smaller YOU marker for the rider | FX P8 | AGREE | 3 | Polish after the playtest. The YOU marker change is S; do it with V27. |
| V44 | Meshy `crowd_bench_block` (30) plus one retexture (10), only if the billboard crowd reads badly | FX P8 | AGREE | 3 | Spend only after Studio shows the billboards fail. |

## Conflicts and hard-rule checks

- **Too many effects on one tap:** V06, V16, V42 and V43 each add motion or overlays. One owner must keep the per-tap effect budget, with the FOV cap and Reduced Motion as the gate.
- **Same screen space:** V13, V21, V22 and V27 all compete for the 375 px phone. Build V21's slot arbiter first.
- **Two dials on win rate:** V11 (kappa) and V30 (bot anchors and unlock points) both move win rates. Run them as one sim and one decision.
- **"Rosette" overload:** V10's proposed Rider rosette would deepen the vocabulary problem (V34). Use a goal, not a new award noun.
- **No hard-rule conflicts found:**
  - No entry fees, odds or pick language anywhere.
  - "Better than N riders" and "Best ride" rank skill, not predictions.
  - Race again is not a purchase prompt.
  - Celebrations are draw-only and play on the rider's own screen.
  - Legend undo (V36) and losers getting ride praise (V26) are kid-safe.
