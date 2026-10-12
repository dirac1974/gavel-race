# Consensus votes: gameplay and race-feel reviewer (2026-10-11)

These are votes on every distinct fix in `gameplay.md` (GP), `feel.md` (FE), `ui-ux.md` (UX) and `systems.md` (SY). Fixes that appear in more than one review are merged into one row.

Priority: 1 = before or with the first Studio playtest; 2 = right after it; 3 = later.

## The four conflicts

1. **Race music vs the slider (C1).** A music bed with a steady beat will pull kids into tapping to the music. The slider's passes drift ±15% and its target moves, so the music would actively mistrain the core skill. The music must be beatless or ducked while the slider runs.
2. **FOV kicks (FE-P2, FE-P7, GP-P1).** A +4° kick on every Perfect, at up to 1.8 taps a second, plus eases on top of it, makes the camera pulse. On phones that risks motion sickness. Cap the per-tap kick and reserve the big kicks for the burst.
3. **The finish sequence (C11).** The FE orbit, the UX "Race again" button, my "best ride" rank and the existing replay buttons all land in the same 3 s. They need one ordered spec, or they'll fight.
4. **κ tuning and the systems ladder retune (C14 and C15).** Both change win rates and must come out of one sim run, not two separate changes.

No fix breaks a hard rule as written. The rows to watch:
- **C17 (flatten B):** fine, but it must never become entry fees. SY already says so.
- **C20 (`Training.raceGain`):** it raises Rating, which is fine because it's earned, never bought.
- **C11:** the 5th–8th copy must praise riding and never say "so close". No near-miss framing.

## Votes

| id | fix (one line) | source review(s) | vote | priority | note |
| --- | --- | --- | --- | --- | --- |
| C1 | Sound stand-ins now: a hand-edited override table (`SoundOverrides.luau`) merged over the generated ids, filled with Roblox-owned effects | GP-P2, FE-P1 | AGREE | 1 | The cheapest, biggest win on the list. Use FE's override-file shape. |
| C1a | A tick on *every* counted tap, pitched by score band (`tap_ok`); today only Great+ has a sound | GP-P2 | AGREE | 1 | A timing verb needs a confirmation every time, not only on success. |
| C1b | Three-layer race music bed (gate, far turn, stretch) from the licensed library, `audio.music` key | FE-P1 | AGREE-WITH-CHANGE | 2 | Beatless or pad-style while the pace slider is live, or ducked about −8 dB under the taps. A steady beat would teach kids to tap to the music instead of the marker (see C1 conflict above). Full percussion only in the last stretch. |
| C2 | A bigger draw-only tap nudge: `tapNudgeFeet` 2 → 4–5 | GP-P1, FE-P2 | AGREE | 1 | Keep it draw-only and unranked, as it is today (`RaceView` 37-39). |
| C2a | Tap juice on Great+: flank trails 0.4 s, hoof dust, 3° body pitch, a pop on the feedback label; `raceFx` config | FE-P2, GP-P1 | AGREE | 1 | Use the existing `fx_dust_puff` art. Everything off under Reduced Motion except the label. |
| C2b | FOV kick on taps: +4° on every Perfect (FE) or 1° on Great+ (GP) | FE-P2, GP-P1 | AGREE-WITH-CHANGE | 2 | Cap at ≤ 1.5° and at most one kick every 0.8 s. Keep the +4–5° kick for the burst only. |
| C3 | Live pace previews: run `previewLive` every second in every pace segment (`pacePreviewSeconds`, `pacePreviewMinPasses`), so taps move the horse in seconds, not after a checkpoint | GP-P1 | AGREE | 1 | Shows no luck: before the far turn the offsets are skill-only. Without this, C2 is just decoration. |
| C3a | Make the SPEED meter honest: rename it, or drive leg cadence from it; gold over slate instead of red-to-green | GP-P1, FE-P8 | AGREE | 2 | Merged. The red-to-green gradient also breaks ART_DIRECTION. |
| C4 | Arm the Final Burst: ignore taps in the first `burstArmSeconds = 0.5`, bar grey until armed | GP-P4 | AGREE | 1 | Only delays input; the marker's random start stays, so D-022's anti-macro property holds. Pairs with UX's "Big tap coming!" cue (C9). |
| C5 | Move the slider clear of the steering pad on phones (bar right of the pad, or pad raised) | UX-P4, GP-P6 | AGREE | 1 | UX measured what I suspected: the glow hides under Out ▶. Prefer the bar narrowed to the right; a pad raised to 0.50 covers the horse. |
| C5a | Phone mode for the race map: drop the oval and digits, floor text at 14 px | UX-P4 | AGREE | 2 | — |
| C6 | Tap judgement shown at the marker on the bar; words only for Perfect and Early/Late (`hud.tapWords`) | GP-P6 | AGREE | 2 | Pairs with FE's label pop (C2a): the pop goes on the at-marker spark. |
| C7 | Move the burst bar off the horse (y 0.44 → about 0.62, 0.75 wide) | GP-P6 | AGREE | 2 | Check against UX's steering-pad budget; the steering pad is hidden by burst time. |
| C8 | Lower and shrink the rider's own YOU marker in the chase view (7 studs, 60 px) | FE-P8 | AGREE | 2 | It sits in the middle of the shot today. |
| C9 | First-race coaching: the ghost thumb over the glow for 4 passes ("NOW!"), honest rule copy ("tap once every time…"), a "Big tap coming!" cue before the burst | UX-P5, GP-P5 | AGREE | 1 | Merged. Copy must state the one-tap-per-pass rule, which nothing on screen says today. |
| C9a | Non-scoring warm-up slider on the queue card during the lobby wait | GP-P5 | AGREE-WITH-CHANGE | 2 | My own idea, amended for UX-P1: only inside the compact phone queue card, and it opens by a tap, never by default. Otherwise it worsens the screen crowding. |
| C9b | A "Rhythm Ride" training course reusing PaceMeter and BurstMeter | GP-P5 | AGREE-WITH-CHANGE | 3 | Defer until SY's feature freeze lifts (C21). |
| C10 | Results card rebuild: floored sizes, a place headline with the ribbon, Done out of the top bar | UX-P3, FE-P5 | AGREE | 1 | Merged with C11 and C12. |
| C11 | Finish sequence: 2.5 s orbit on your horse, confetti and gold highlight for 1st, ribbon stamps for 2nd–4th, star count-up for 5th–8th, gallop-out (`PAST_LINE` 0.04), `finishFx` key | FE-P5 | AGREE-WITH-CHANGE | 2 | One ordered spec with C10, C12 and the replays: orbit → card → buttons. Skippable by tap, never longer than 2.5 s. 5th–8th copy praises the ride, never "so close". |
| C12 | Skill-only win on the card: "Best ride in the race!" or "2nd best ride of 8" from S, plus a cosmetic Rider rosette | GP-P3a | AGREE | 1 | My own fix. It gives FE's 5th–8th landing real, earned content. Call it a "ribbon", not a rosette, if SY's renames (C22) land. |
| C13 | "🏁 Race again" as the primary 64 px button on the results card | UX-P3 | AGREE | 1 | Not a purchase prompt, so D-050 is unaffected. Must not appear before the finish sequence ends (C11). |
| C14 | Per-league `league.kappa` override, sim-validated (P90 kid ≥ 40% solo Rookie wins) | GP-P3b | AGREE-WITH-CHANGE | 2 | Run it in the same sim pass as C15; the two together set win rates. |
| C15 | Rebuild the progression sim on realistic Ratings and retune `stakesUnlockPoints` and `botRatingAnchor` | SY-P1 | AGREE | 1 | The most important non-feel finding. A 10x cliff at Silver will kill retention whatever the race feels like. |
| C16 | Make the chance arrow and checkpoint line relative to the riders ("better than 5 riders") | GP-P8 | AGREE | 2 | FE-P7's checkpoint banner (C19) is where this line goes. |
| C17 | Flatten league purses B (e.g. 20/35/50/70/100) and add Green Cash decor in `Style` | SY-P2 | AGREE-WITH-CHANGE | 2 | Economy sim first, in the same pass as C15. Never as entry fees. |
| C18 | Open Practice to every league and add "Race with [friend]" | SY-P3 | AGREE | 1 | A race is only fun with friends in it. Practice pays nothing, so mixed Ratings and colluding friends are harmless. |
| C19 | Mid-race beats: checkpoint banner with stars, a place-badge pop on gains only, crowd swell | FE-P7 | AGREE | 2 | A pop on gains only is honest; no shake or red on a lost place. |
| C19a | Pace rest spans: a 3 s "Steady…" breather at the lane lock (`pace.restSpans`); optionally a slower sweep while lanes are open | GP-P7 | AGREE-WITH-CHANGE | 2 | My own; amended to playtest first with Sprint attention data (FE-P7 asks the same). Re-run the bot pace sims. |
| C19b | Measure attention at Sprint length before touching `raceSpeedStudsPerSecond` | FE-P7 | AGREE | 1 | Measuring costs nothing; speed changes would break the steering calibration. |
| C20 | `Training.raceGain`: +0.1 stat per counted race, inside the weekly cap | SY-P1 | AGREE | 2 | Makes "Races still help!" true. It's earned Rating, never sold. |
| C21 | Freeze new systems; first playtest with the meta switched off via the existing flags; measure the Phase 1 gate | SY-P4 | AGREE | 1 | Strongly agree. The gate is a race question; the meta only adds noise to the answer. |
| C22 | One meaning per noun (rosette, medal, sticker, pin, stamp, badge) | SY-P4 | AGREE-WITH-CHANGE | 3 | Use "career patch", not "career star": ★ means riding (D-064). Do it after the playtest. |
| C23 | Make Stable Star goals repeatable (×2 and ×4 tiers) | SY-P4 | AGREE | 3 | — |
| C24 | Legend reversible (`Leagues.unretire`); no Legend suggestion until breeding | SY-P5 | AGREE | 2 | Irreversible loss of a bonded horse for nothing is a kid-safety smell. |
| C25 | Next-thing pill puts the race first (first race, and after the daily feed); `nextThing.order` | SY-P6, UX-P2 | AGREE | 1 | Merged. |
| C26 | Fold the Spa into the Vet as one card; build nothing more on Energy | SY-P7 | AGREE | 3 | — |
| C27 | First-minute tour owns the screen: pill hidden, GO is the real RACE! pulsing, Skip moved away, advance on JoinRace | UX-P2 | AGREE | 1 | — |
| C28 | Phone screen budget: top-centre slot arbiter, compact queue card, gear off the 💎 pill | UX-P1 | AGREE | 1 | — |
| C29 | Floors everywhere: `Ui.closeButton`, Starter through `fitPanel`, lint test for < 56 px buttons and < 14 px text | UX-P6 | AGREE | 2 | Extend the lint to `RaceController`'s own helpers; the race HUD is where size matters most. |
| C30 | Phone dock with 4 items: portrait, RACE!, Ride, More | UX-P7 | AGREE | 2 | — |
| C31 | One meaning for "Ride" and 🐴; status line uses `PickerText` distance words | UX-P8 | AGREE | 3 | — |
| C32 | Text colours that pass contrast (`textGood`, `textWarn`) and a contrast test | UX-P9 | AGREE | 2 | — |
| C33 | Bob synced to the leg phase (`HorseLegs.phaseOf`), squash and dust on the forefoot plant | FE-P4 | AGREE | 2 | Cheap and fixes the "swimming" look; dust on the plant is the same emitter as C2a. |
| C34 | Jockey crouch-and-pump animation (hands and heels, no whip), speed from stride rate | FE-P3 | AGREE | 2 | The rider's own avatar is the biggest object on screen. |
| C35 | Gate intro: countdown 3 → 5 s, white fade around the seat, 2 s line-up dolly | FE-P6 | AGREE-WITH-CHANGE | 3 | Keep 3-2-1 at 3 s and run the dolly during the last seconds of the lobby fill instead, so the wait doesn't grow. Behind `raceIntro.enabled`. |
| C36 | Track dressing: bunting, billboard crowd, live Big Board, HUD restyled in paper and ink | FE-P8 | AGREE | 3 | Crowd billboards only if Studio shows the stands empty. Meshy last. |
| C37 | Steering's value is about 2 points: decide after the playtest whether to keep `steering.scale` or set it to 0 | GP-P7, SY-P4 | AGREE | 2 | Both reviews reach this independently. No more steering rules until kids show they steer. |
