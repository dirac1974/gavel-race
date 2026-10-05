# Decisions

Every decision, newest last. Never delete an entry; mark replaced ones `Superseded by D-NNN`.

**Status:** `Accepted` (in force) · `Proposed` (awaiting David) · `Rejected` · `Superseded`.
Engineering choices may be `Accepted` by the team. Anything players experience needs David.

Template:

```
## D-NNN — Title
- Date: YYYY-MM-DD
- Status: Proposed | Accepted | Rejected | Superseded by D-NNN
- Decided by: David | team (engineering only)
- Context: why this came up
- Decision: what we do
- Consequences: what it changes, risks
- Links: debate, research, commit
```

## D-001 — No wagering; prizes are locked purses
- Date: 2026-10-04
- Status: Accepted
- Decided by: David (plan approved in chat)
- Context: Roblox prohibits simulated and actual gambling, including bets with free currency.
- Decision: free entry (Energy-gated), purses locked before the race and paid by finish. No odds display, no quinella, no prediction payouts.
- Links: docs/V2_PROPOSAL.md, docs/GAME_DESIGN.md

## D-002 — Two currencies
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: Green Cash is the main currency, earned from races, stable care, quests, and daily login, and never sold. Diamonds are bought with Robux and used for boosts and extras.

## D-002a — What Diamonds may buy
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Context: David's original idea included Diamond boosts to qualify for higher races. Buying win chance in a skill race undermines fairness, and paid probability modifiers fall under Roblox's paid random item rules.
- Decision: Diamonds buy cosmetics, time skips, and space only; never win chance, Race Rating, or the gavel. Qualifying for cash leagues is earned; Diamonds can buy an Exhibition entry to a higher league for XP and a cosmetic ribbon, with no cash purse.
- Amended 2026-10-04 (with D-015): Diamonds may not buy extra stalls, an auto-feeder, or Energy refills. More stalls means more races and more Green Cash, and the auto-feeder kept the care bonus (which raises win chance) topped up. Stalls are Green Cash only.

## D-003 — Race model v2 replaces v1
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: exponential tilt `p' ∝ q · e^{κR}`, cash purses `5 · round(B / 5q)` (rounding superseded by D-017), no margin, no tiered rounding, no skill noise, Harville finish order, flat place prizes 2nd 1.2B / 3rd 0.8B / 4th 0.4B.
- Consequences: exact per-race cash invariance traded for ~0.2–0.5% drift.
- Links: docs/V2_PROPOSAL.md

## D-004 — Skill measured against the race average
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: `R = clamp((S − mean S of this race) / 50, −0.5, 1)`.
- Consequences: same chances as league-median centering except at clamp edges; no league statistic to game; lower collusion gain. Upsets are tuned with T (frequency) and κ (who earns them).

## D-005 — Starting dials
- Date: 2026-10-04
- Status: Accepted (tunable within ranges by the team, logged here)
- Decided by: David
- Decision: T by league Rookie 22, Bronze–Silver 18, Gold 14.4, Champion 12; κ 1.0 (range 1.0–1.2); q floor 2.5%; R floor −0.5; B Rookie 20, Bronze 50, Silver 120, Gold 300, Champion 750.

## D-006 — Party members never share a cash race
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (integrity), consistent with D-001
- Decision: friends in a party race each other only in Friend Races that pay XP and cosmetics.

## D-007 — Theme-agnostic engine for reskins
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: engine code uses generic terms (Racer, Pilot, Upkeep, Facility); a ThemePack holds names, art, and condition weights. Car and boat skins later, flower contest deferred.

## D-008 — Autonomous agent team workflow
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: Claude Code agents implement, test, review, and record work, pushing to `main` when green. Design debates produce proposals only. Workflow in CLAUDE.md.

## D-009 — Design decisions delegated to the team
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("make all decisions yourself and we can review later")
- Decision: the team makes design decisions as `Accepted (provisional)`, logs reasoning and alternatives, and lists each in `REVIEW_QUEUE.md`. Hard rules 1–3 in CLAUDE.md (no wagering, Diamond limits as policy safeguards, kid safety) are not open to this delegation.

## D-010 — Gavel meter feel and difficulty curve
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009 (debate 001)
- Decision: same scoring in every league; difficulty from triangle-wave sweep speed (Rookie 2.4 s → Champion 1.1 s), a drifting target in Gold and Champion, and two half-width targets in Champion's final window. One tap per window, window 4 s in Rookie and 3 s elsewhere. Feedback labels Perfect/Great/Good/Okay/Miss with the score and win-chance change. Accessibility options; slower-meter assist only outside cash races. Taps scored at client-claimed server time if ≤ 0.3 s before arrival and inside the window.
- Alternatives: narrower scoring band per league (breaks comparability of S); fixed difficulty (no progression).
- Links: docs/debates/001-gavel-meter-feel.md, game/src/shared/GameConfig.luau, game/src/shared/GavelMeter.luau

## D-011 — Prototype race rules
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Decision: a missed tap scores 0; a disconnect scores the window's race average once per race; bots fill lanes after 20 s, rated within ±6 of the human median, scoring Normal(50, 15); bots are never paid; 4 s of running between windows; prototype runs Rookie only and keeps currency in leaderstats (no saving yet).
- Alternatives: missed tap = 25 for Rookie (gentler, but blurs the skill signal); bots at league-average rating (worse matchmaking for strong or weak horses).
- Links: game/src/shared/RaceSession.luau, game/src/server/RaceService.server.luau

## D-012 — Python and Luau must agree exactly
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (engineering)
- Decision: purse rounding uses floor(x + 0.5) in both languages (Python's round() is banker's rounding); the finish draw scans lanes in index order. Parity tests compare 300 fixture races to 1e-9, including purses and finish orders.

## D-013 — Stakes thresholds per league
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Context: flat 100-point thresholds let an engaged player (25 races/day) reach Gold on day 4.6, far ahead of the 3-week target.
- Decision: League Points to unlock Stakes: Rookie 100, Bronze 110, Silver 1,400, Gold 3,000. Simulated engaged player: Bronze ~3 h of play, Silver day 3, Gold day 20, Champion day ~56.
- Consequences: casual players (6 races/day) don't reach Gold within 90 days; revisit once Energy and training are modeled.
- Links: sims/economy.py, sims/README.md, GameConfig.stakesUnlockPoints

## D-014 — Race Rating formula and condition weights
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Decision: Rating = (Σ w·stat over Speed, Acceleration, Stamina, Grit) × (1 + 0.05 × care) + 3 × pilot level + 2 if the strategy suits the distance + 2 × bond. Distance sets base weights (Sprint favors Acceleration, Marathon favors Stamina); Turf adds Speed, Sand adds Grit and Stamina, Rain adds Grit, Wind adds Stamina; weights renormalize to 1. Focus is not in Rating. Full non-stat bonuses add about 10 points at 60 stats, one doubling of win chance at T = 14.4.
- Alternatives: multiplicative jockey bonus (scales unfairly with stats); Focus in Rating (double-counts with its meter effect).
- Links: src/race_rating.py, game/src/shared/RaceRating.luau, tests/test_race_rating.py

## D-015 — Energy
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Decision: 5 Energy per horse; each cash race costs 1; regenerates 1 every 20 minutes, offline too; feeding +1 and grooming +1, each once every 2 hours. Rookie races cost no Energy. When every horse is tired, Practice races (XP only, no cash or points) and other activities remain. Energy never affects Rating or win chance.
- Consequences: a 2-hour session allows about 11 cash races with 1 horse, 22 with 2, and more than fits with 3; Energy mainly paces single-horse players and makes a second stall the natural goal. Diamonds never refill Energy.
- Alternatives: tired horses run slower (confusing, and turns care into win chance); Diamond refills (buys extra cash races).
- Links: GameConfig.energy

## D-016 — Prizes and exactas
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Decision: 2nd–4th prizes stay flat (1.2, 0.8, 0.4 B). Fully upset-scaling them would make every horse expect the same cash (favorite vs. longshot 1.00× instead of 1.30×), removing the cash reward for training. UI shows ribbons and "1st prize", never place, show, or payout. Exactas are not a prize; at most a free spectator "call the top two" game for cosmetic ribbons.
- Amended 2026-10-04: the spectator idea is replaced by cheering (D-019); no top-two or order picks.
- Links: docs/V2_PROPOSAL.md, GameConfig.ribbons

## D-017 — Win purses round to whole cash
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (engineering correction)
- Context: rounding purses to 5 cash was documented as < 0.2% error, but the real bound is `2.5 q / B`, up to ~4.4% for a strong favorite in Rookie. Found in a parallel review of the repo.
- Decision: `Purse = round(B / q)` in whole cash (floor(x + 0.5) in both languages). Error bound `0.5 q / B`: ≤ 1% in Rookie, ≤ 0.2% from Silver up.
- Links: src/gavel_race_v2.py, src/RaceMath.luau, docs/V2_PROPOSAL.md

## D-018 — Tests and CI gate every push
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (engineering)
- Context: two sessions (cloud and local) built the repo in parallel; their histories were merged on 2026-10-04. The local one recorded this rule as its D-009 and the rounding correction as its D-010 (now D-017); those numbers were reused here, so this entry keeps the CI rule.
- Decision: GitHub Actions (`.github/workflows/test.yml`) runs pytest, the policy guard, the v2 and v1 models, Luau syntax checks, and Luau parity under Lune on every push and pull request. Parity fixtures are generated at test time, never committed (floats differ in the last digit across platforms). A red run blocks the next build loop until fixed.
- Links: .github/workflows/test.yml, scripts/policy_guard.sh, tests/fixtures/make_fixtures.py

## D-019 — Spectator cheering
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: David (direction: free, something to root for, prizes much smaller than racing); team (details, under D-009)
- Context: Roblox has banned simulated gambling since 2023 even with free, unbuyable currency, so being unbuyable is not the safe line; staking nothing and earning nothing of value is. A free winner pick with a flat reward makes the favorite always the best pick; scaling the reward by long shot reproduces betting odds and conflicts with hard rule 1. Research: docs/research/2026-10-04-spectator-predictions.md
- Decision: before the first gavel window, a spectator cheers for one rider. Fan XP comes from that rider's gavel taps: Perfect 3, Great 2, Good 1, Okay or Miss 0, plus a flat 2 if the rider wins (max 11 per race, 100 per day). Race Rating doesn't affect tap scores, so the favorite isn't automatically the best choice. Free (no Energy, no currency). Riders and their party can't cheer in their own race. Fan XP only unlocks cosmetics through Fan levels (badges, stand flags, titles); it never becomes Green Cash, League Points, horse or jockey XP, and is never tradeable. Never scaled by win chance; nothing in the lobby shows XP per horse. Spectators see live win chances only after cheers lock. UI words: Cheer, Your rider, Fan XP.
- Size rule: spectating stays much smaller than racing. A cheered race is worth at most 20% of the progress a rider earns from the same race; economy-analyst checks this once rider XP and cosmetic unlock rates are defined.
- Alternatives: flat XP for a correct winner pick (favorite always best); XP scaled by long shot (betting odds in all but name); "Race Reader" with win chances hidden until picks lock (teaches Race Rating, but picking the top-rated horse becomes the best move again).
- Links: CLAUDE.md hard rule 1, docs/GAME_DESIGN.md (Spectating), D-016

## D-020 — Clap Along crowd boost
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: David (direction: optional cheering game that slightly raises the horse's chance, applies to cash races, small groups can compete, about a fifth of the first proposal); team (details, under D-009)
- Decision: fans who cheered a rider (D-019) can play Clap Along: clap on that horse's hoofbeats. Each beat takes its nearest clap within ±80 ms, scored `1 − |error| / 80 ms`; every extra clap subtracts 1; fan score `s` = 100 × total / beats, floored at 0, per gavel segment. Lane crowd `D = min(1, s₁ + 0.15 s₂ + 0.10 s₃)` over its three best fans (÷100): the best fan counts in full and fans 2 and 3 add a small assist, so one great fan can max it alone, friends help a weaker fan get there, fan 4 onward adds nothing, and adding a fan never lowers it (amended 2026-10-04 by David). Boost `c_i = 0.03 · D` joins the live tilt exponent (`κ R_i + c_i`) after each window. Applies to cash races. Never sold or boosted by Diamonds; no prompts urging friends to come and cheer.
- Fan leaderboard (added 2026-10-04 by David): after each race, a Top Fans panel, shown separately from the race results, ranks that race's Clap Along fans by score: top 5 with the horse each cheered, plus the viewer's own rank. Nobody is shown at the bottom. A flagged fan still sees their own rank but is left off everyone else's board.
- Size: full crowd lifts a 12.5% horse to 12.8% (a 5% horse to 5.1%, 25% to 25.6%); one perfect fan reaches the full crowd. About 2% of the lift a perfect gavel gives (12.5% → 28%).
- Cheating: beat tempo is set per race and drifts each stride, so fixed-rhythm macros score about 0 (simulated mean 3 of 100). Reactive screen-reading bots lag the beat and score about 50 under distance scoring, below a good human's ~57. A bot that predicts the next beat can score ~82 with inhuman consistency (spread ~5 ms vs 30–50 ms for people); flag spread under 12 ms over 48+ beats. Strikes (amended 2026-10-04 by David): every flag quietly zeroes that fan's contribution for the rest of the race while their own screen keeps showing normal clap feedback, and counts as a strike on the account (at most one strike per race; timing logs kept). 2nd strike: a private, gentle warning after the race ("Your claps looked automatic, so they didn't count. Auto-clickers or scripts can turn off fan play for your account."). 3rd strike: all fan play (cheering, Clap Along, Top Fans board) is off for the account for 30 days; riding is unaffected, and Fan XP and cosmetics already earned are kept. Strikes expire after 90 days without a flag. Strikes need saved profiles (STATUS backlog item 2); until then they last for the session. A flag never lowers the horse below a fan-less baseline (otherwise a griefer could cheat on purpose while cheering a rival), never shifts the fan's timing, and is never shown to other players. A bot tuned to look human scores like a good human fan. Exposure is capped at +0.3 points of win chance.
- Fairness: riders with friends watching get a small edge over riders without, and bots never have fans; this is a mild path around D-006 (party members never share a cash race), accepted because the cap (+0.3 points) is about 1/60 of the collusion gain D-006 prevents (+20.8 points, 12.5% → 33.3%).
- Alternatives: count-weighted crowds (large groups always win); mean of all fans (weak cheerers hurt their friend); 60/25/15 weights over the best three (a lone fan got only 60%); filling empty slots with the best fan's score (a weaker second fan lowered the boost); best fan only (friends add nothing); boost 0.15 or 0.10 (David asked for smaller); friendly races only (David chose cash races too).
- Links: docs/V2_PROPOSAL.md step 5, D-019, STATUS backlog items 4 and 6

## D-021 — Tap time allowance follows measured latency
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (engineering, security fix; amends D-010)
- Context: D-010 scored a tap at the client-claimed time if it was up to 0.3 s before arrival. A modified client could wait until the marker passed the center and claim that moment, scoring 100 on every window (worth up to 2.7x win chance).
- Decision: the allowance is the player's measured one-way latency (`GetNetworkPing() / 2`, snapshotted when each window opens) plus a 0.05 s jitter margin, capped at 0.3 s. Claims older than that are scored at arrival time. A 30 ms ping gives a 65 ms band, so the old exploit now scores where the marker actually is (58 instead of 100 in the Rookie test case).
- Residual: the meter is deterministic, so a script that taps at the computed center time still scores well. That is timing skill done by a program, handled by the statistical flags in STATUS backlog item 4 (sustained S > 95), not by tap-time rules. Ping can be inflated with a lag switch, but the cap still bounds the band at 0.3 s.
- Links: game/src/shared/GavelMeter.luau (rewindAllowance, resolveTapTime), game/src/server/RaceService.server.luau, tests/luau/game_tests.luau

## D-022 — Stride stretches replace single gavel taps; macro detection
- Date: 2026-10-04
- Status: Accepted (provisional); name chosen by David: **Giddy-up**
- Decided by: David (direction: many urging taps mid-race, defeat auto-clickers, judge click-timing consistency before banning); team via debate 007
- Context: the D-010 meter always starts at the left edge, so a timed macro ("tap 0.60 s after open") scores 100 every time in Rookie–Silver. David wants many taps through the middle of the race instead of three single taps.
- Decision: each of the three windows becomes a stride stretch (about 8 beats, ≤ 10 s, ~2 taps a second). The rider taps on the horse's stride; each tap is scored by closeness to its beat (±80 ms, as Clap Along in D-020), extra taps count against, stretch score = mean over beats and replaces the window score in `S` (race maths unchanged). Tempo is set per race, drifts each stride, and changes are previewed a beat ahead; the on-screen beat counts, sound is decoration; tap anywhere; at most ~3 taps a second rewarded; Rookie starts steady, faster with more drift from Silver, an off-beat lead change in Champion. Mashing makes the horse visibly break stride. Per-beat labels are tuned so an average kid sees "Good". Bots are recalibrated to the new distribution: stretches Normal(40, 15), Final Burst Normal(55, 15), to tune from playtests (amends D-011). **Final Burst** (added by David, 2026-10-04: "more crucial"): right after the third stretch, one tap on a sweeping meter, scored `100 (1 − d)` as in D-010, with a uniformly random marker start shared by every lane, so a fixed-delay macro scores ~50, the same as tapping at random, at every delay. (Corrected during the build: the first version also required "never start inside the glow, first pass at least 0.4 s in", but simulation showed those guards make the first pass predictable and lift a tuned macro to 64–84; even "not inside the glow" alone allows ~60. The window has several passes, so an early pass is never a player's only chance.) It counts double: `S = (stretch₁ + stretch₂ + stretch₃ + 2 · burst) / 5`, so the burst is 40% of `S`; a perfect burst over an average one is worth about 1.5× win chance. Weight is a config dial. No whip anywhere: hands-and-heels riding. Players call the mechanic "Giddy-up" (David, 2026-10-04); "Gavel Derby" stays only as the working game title.
- Detection: compare each tap gap to the matching beat gap (David's delta idea, measured against the beat because steady gaps are the skill). Flag when the spread is under 12 ms over 300+ beats across 5+ races on 2+ separate days. Log only for the first month.
- Rider ladder: flag 1 logged only. Flag 2: private, neutral note with a one-tap "Ask for a check"; until cleared or 7 days pass, that rider's cash-race taps count as the race average. Flag 3: a person reviews the logs, then cash races pause 7 days (30 on a repeat); Practice, Friend Races, care, training stay open. No Green Cash or items taken back; strikes expire after 90 days; never public; nobody removed from boards; Ban API only for proven modified clients.
- Simulated: mashing ≈ 0, fixed-rhythm macro ≈ 3, good human ~57, average ~30, beat-predicting bot ~82 with ~5 ms spread.
- Alternatives: random marker start or relocating target on single taps (fixes macros but not David's "many taps"); repeated sweeping meter (interval-clicker friendly); push-and-breathe stamina gauge (rewards tap rate, thumb strain).
- Supersedes: D-010's meter motion and single tap per window (scoring formula family and labels kept); D-021's latency allowance applies per tap.
- Links: docs/debates/007-race-taps-and-macros.md, D-020

## D-023 — Playtest art direction ("County Fair Toy")
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team (art lead plus the design council review, under D-009); assets requested by David
- Decision: chunky, stylized, natural horses on a sunny county-fair race day. Small eyes on the sides of the head, no lashes or eyebrows, natural coats and manes, no flank symbols; ears forward, mouth closed, never strained. The hero isn't a buckskin mustang with a flowing black mane. Hooves dark and high-contrast on every coat, because the beat lands on the hoof. For the playtest the horse is one fixed gallop pose that bobs, with the bottom of the bob on the beat, plus a dust puff and mane flick; a leg cycle comes later (a real gallop's four footfalls could read as false beats). Lanes keep a fixed colour, pattern, and big number; "YOU" is huge; silks come later as a second marker. The Final Burst celebration plays on the rider's own screen after scoring (tiny camera punch, none under Reduced Motion, never more than 3 flashes a second); everyone else sees a small sparkle on that lane. Tap anywhere, with the hoof ring as the target and a GIDDY-UP pad as a reminder that holds steady while rings are on screen. Every ring closes in the same time. Rare coats will be natural (pinto, leopard, dapple), none in Phase 1.
- Spend: 180 of a 200-credit Meshy cap (bay horse mesh, 5 coats, finish post, gate stall with one re-roll, and a darker dapple grey re-roll David asked for). Models live in the gitignored `Models/`. Uploaded to Roblox under the LlamaWorks group with David's approval (2026-10-04); the playtest place must be published to that group. The finish post keeps its plaid disc for now (David: reevaluate later); the track's checkered line is built from parts.
- Alternatives: realistic horses (blends in with Horse Life); cartoon ponies (too young for 11–13s, close to My Little Pony); celebration shown to everyone (spotlights the losers); a big button as the only target (adds aiming error, invites mashing).
- Links: docs/art/ART_DIRECTION.md, docs/art/ART_REVIEW.md, docs/art/ASSET_PLAN.md, docs/art/IMPORT.md

## D-024 — Racing players ride their horse
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("the player should be the jockey on the horse if they are participating in the race, riding him through the race")
- Decision: at race start each racing player's avatar is seated in an invisible saddle Seat on their lane's horse and rides it to the finish; the default camera follows the rider. Jumping is disabled while riding (Space is also a tap key). About 3 s after the results, riders are dismounted beside the starting gate. Spectators and late joiners stay on the ground. Riding pose is the default sit for now; a hands-and-heels riding animation (never a whip, D-022) comes with the race presentation work.
- Links: game/src/server/TrackScene.luau (seatRider, dismountAll), game/src/server/RaceService.server.luau, game/src/client/RaceController.client.luau

## D-025 — Oval racecourse, one lap
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("it should be an oval"); team (dimensions and motion)
- Decision: races run one lap of an eight-lane oval (two 180-stud straights, inner rail radius 50, lanes 5 studs wide; lane 1 inside, about 700 studs round, lane 8 about 920). Start and finish share the line at the near end of the home straight; the stalls clear when the countdown ends. Each client animates all horses from the server's timeline (start, expected end, live chances, finish order) so motion is smooth and identical everywhere: a shared pace to 95% of the lap by the Final Burst, the likelier winners edging ahead, then a run-in where horses cross the line in the drawn order. Spectators spawn outside the home straight by the finish line. Geometry lives in `OvalTrack` (pure, tested under Lune).
- Alternatives: the 200-stud straight (David: too short, should be an oval); server-side tweening (steps with network updates, jittery for riders).
- Links: game/src/shared/OvalTrack.luau, game/src/server/TrackScene.luau, game/src/client/RaceView.client.luau

## D-026 — Continuous pace slider, first-person riding, bigger Final Burst
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("no pauses in the race for the clicks... I like the bar slider better than the horseshoe... a fill amount to the speed meter... make the ending boost bigger and more colorful"; "the player should have a front view as if they are on the horse")
- Decision: riders tap a slider for the whole race, with no pauses. The marker sweeps back and forth; each pass takes one tap, scored `100 (1 - distance from the target)`; a pass with no tap or two taps scores 0, so mashing scores about 0. The glowing target moves to a new spot every 2–3 passes and each pass's speed varies by up to ±15% (David's earlier anti-macro idea), so a fixed-interval clicker scores below an average kid (simulated 59 vs 75; good player 93; random 48). A speed meter fills from the last 5 passes. Scoring is grouped into three back-to-back checkpoints for live win chances, then the Final Burst (same slider idea, one tap, counts double) on a much bigger rainbow meter with a pulsing gold rim and "FINAL BURST ×2". Riders see the race in first person from the saddle by default and can zoom out to third person. Detection (D-022) now uses tap time minus the target-crossing moment; same flag rule and ladder.
- Supersedes: D-022's stride stretches for riders (the Stride module stays for Clap Along, D-020). The design council had rejected a plain repeating slider as auto-clicker-friendly; the moving target and speed drift address that.
- Links: game/src/shared/PaceMeter.luau, src/pace_meter.py, game/src/client/RaceController.client.luau

## D-027 — Churchill Downs racecourse; race length follows distance
- Date: 2026-10-04
- Status: Accepted (David confirmed the Rookie distances on 2026-10-04)
- Decided by: David ("model the track layout like a famous race track... Santa Anita, or the Kentucky Derby... maybe a 2 min race is ok"); team (details)
- Decision: the track is modelled on Churchill Downs at full scale (1 stud ≈ 1 ft): a one-mile dirt oval, 80 ft wide, quarter-mile straights, homestretch 1,234.5 ft to the finish, run counter-clockwise; turf course inside; grandstand with the Twin Spires along the homestretch, clubhouse at the first turn, infield Big Board, rose garden by the finish, barns on the backside, furlong poles and the finish pole on the inside rail. Races run at about 56 ft/s and the distance condition sets the length: Sprint 6f ~69 s (gate on the backstretch), Mile ~94 s, Classic 1¼ mi ~1:57 (gate at the top of the stretch, as in the Kentucky Derby), Marathon 1½ mi ~2:21. The gate sits straight across a straight, so outer lanes run slightly further. Rookie runs Sprint and Mile only (shorter races for new players; confirmed by David).
- Supersedes: D-025's small oval.
- Links: game/src/shared/TrackLayout.luau, game/src/server/TrackScene.luau, game/src/client/RaceView.client.luau, game/default.project.json

## D-028 — Chase camera, NPC jockeys, solid rails
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("during the race maybe it should be zoomed out a little, because you can't see the other nearby horses"; "npc horses should have roblox character style jockeys"; "you can walk right through the railing")
- Decision: the riding camera starts as a close chase view (zoom 14 studs, field of view 80, Follow camera so it turns with the horse) instead of first person; riders can zoom in to first person or out. Every bot horse carries a standard Roblox R15 character as its jockey, in lane-colour silks and helmet with white breeches, seated with Roblox's default sit animation. Rails are solid, with an invisible wall from the ground to each rail so nobody walks through; players can still jump a rail.
- Amends: D-026 (first-person default), D-024 (riders; now bots ride too).
- Links: game/src/client/RaceController.client.luau (rideCamera), game/src/server/TrackScene.luau (addJockeys, railBlocker)

## D-029 — The game is called Giddy-Up
- Date: 2026-10-04
- Status: Accepted
- Decided by: David (name, and the published Roblox experience "Giddy-Up" under LlamaWorks); tagline chosen by David from the team's options
- Decision: the game's name is **Giddy-Up**, tagline **"Tap it. Shout it. Win it."**, because kids shout "Giddy-up!" while they tap to urge their horse on (the design council's reason for the name in debate 007: happy, shoutable, thumbnail-friendly). "Gavel Derby" was the working title and stays only in history notes; the repository keeps its name (gavel-race).
- Alternatives (taglines): "Say it, tap it, ride it!", "Every tap's a Giddy-Up!", "The race you can shout!".
- Links: game/src/shared/ThemePack.luau, docs/GAME_DESIGN.md, CLAUDE.md

## D-030 — Live places and a minimap
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("it should show which place you are in near your number... the board on the side should also show which place each horse is currently in... a minimap oval of the track in the upper right during the race")
- Decision: each client ranks the horses every frame from the shared race timeline (RaceState), so every screen agrees: a big place badge ("3rd of 8") at the top right for the rider, the same place on the YOU marker over their horse, and the side board re-sorted by running order with places. After the run-in the official finish order replaces the running order. A minimap of the oval (same geometry as the track) sits in the top-right corner during the race: numbered dots in lane colours, the rider's own dot larger with a white ring, the finish line marked, homestretch along the bottom.
- Also fixed: horses ran backwards. The imported models already face Roblox's forward, so the 180-degree turn from the import notes is removed (`AssetService` YAW table, 0 by default).
- Links: game/src/client/RaceState.luau, game/src/client/Minimap.client.luau, game/src/client/RaceController.client.luau, game/src/server/AssetService.server.luau

## D-031 — Final Burst entering the homestretch; stretch drive; no pause
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("there is a pause on the final burst in the horses movement. It should be a bit earlier in the race after the final turn after they get in the straight away")
- Decision: the race runs pace (two checkpoints) from the gate to the final turn, then "FINAL BURST ×2" shows as the field turns for home and the burst opens 0.5 s into the homestretch (about 22 s from the line), then the slider resumes for the stretch drive (third checkpoint) until 1.5 s before the line. Segment order is pace, pace, burst, pace with weights 1, 1, 2, 1 (the burst is still 40% of S). Horses run at the race's constant speed and reach the line as the race ends; near the line they bend smoothly toward it instead of stopping, and leads are in feet (a strong favourite is about 55 ft ahead), so nobody freezes waiting for the result.
- Cause of the pause: leaders were capped just short of the line until the result arrived, and the pace clock stopped at the expected end.
- Links: game/src/server/RaceService.server.luau, game/src/shared/RaceSession.luau (paceSchedule spans), game/src/client/RaceView.client.luau

## D-032 — Race strip replaces dots on the oval
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, design council consult (4/4 for the race strip); David asked for a fix to the minimap overlap
- Decision: the race map has a race strip like a TV broadcast's running order: one row per lane so dots never stack, zoomed to the field (leader near the right edge, everyone spaced by their real gap, at least ~10 lengths shown) with a checkered flag sliding in when the line is in range, and a line of text with your gap in horse lengths ("1.5 lengths behind the leader", "Leading by 2 lengths"). Above it a small still oval shows only your own dot and the distance to go ("Homestretch!" once in the stretch). Your dot is larger with a white ring; every dot shows its lane number in high contrast.
- Rejected: spreading dots across the track by lane (doesn't fix squashed distances, suggests lanes matter), a panning zoomed map (motion while timing taps; kids think their horse stopped), a bigger map (phone space), hiding other horses.
- Open for David: three of four designers say the running-order board on the left is now one display too many (place badge plus strip cover it) and suggest hiding it during the race. Kept for now because David asked for it.
- Links: game/src/client/Minimap.client.luau


## D-033 — The horse sets the odds, taps move them, luck shows from the far turn
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, debate 008 (blend while tapping: child safety, competitive and moderator; hands-off reveal: engagement, young player); David agreed with the panel's direction
- Decision: the finish is an exponential race. At the gate each horse gets a secret luck number `L ~ Exp(1)` (never sent to clients); its projected finish time is `T = L / p` with `p` its live chance, and the finish order is sorted by `T`, which is exactly the Harville distribution the race always used, so purses and odds are unchanged. On screen, up to the final far turn each horse's offset from the shared pace comes from live chance (skill, 320 ft per unit of share above fair); from the far turn to the last tap the offsets blend toward the projected order (luck: leader +20 ft, gaps 24·log(T ratio) clamped 2–40 ft) with weight `x²`, so late chargers come through while taps still count and the order on screen at the line is the result (no reshuffle). The stretch drive previews live chances every second. A Great or Perfect pace tap gives your own horse an instant 2 ft nudge (same for everyone, never luck), the place badge shows an up or down arrow when your chance moves (never a percentage), and the results card leads with "You rode ★★☆" and, only when positive, "Your riding gained you N places!" (your place versus riding at the race average with the same luck). Energy stays out of speed (D-015 stands); a rested horse trains 50% faster inside the weekly cap (to build with training).
- Tuning: in simulation the eighth-pole leader wins 61% and 11% of winners come from 3rd or worse there (Kentucky Derby proxy 74% and 12%); smoothstep gave 89% and 1%. All values in `GameConfig.raceShape`.
- Alternatives: hands-off reveal after the last tap (slot-machine structure), no race shape (no comebacks), energy as a speed factor (punishes play and absence, invites paid speed).
- Links: game/src/shared/RaceShape.luau, game/src/shared/RaceSession.luau (luck, previewLive, ridingGain), game/src/server/RaceService.server.luau (offsets, previews, RideReport), game/src/client/RaceView.client.luau, docs/debates/008-race-dynamics-and-replay.md

## D-034 — Replays: the finish, or the whole race at 3x
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, debate 008 replay round (4/4); David asked for "just the last 1/4 of the race, or a full race sped up"
- Decision: after every race the results card offers "↺ Watch the finish" (final quarter at real speed, from when the leader passes 75%) and "Whole race ×3" (3x until the final quarter, then real speed); never autoplayed. Riders stay in the saddle until they press Done (server dismounts everyone after 60 s). Playback uses only what this screen recorded (10 frames a second) and ends on the official result: no re-simulation, no ghost horses. Side-on camera on your horse with a Behind toggle; Reduced Motion gets a fixed finish-line camera. REPLAY banner, letterbox and warm tint, no tap pad, no prompts. Overlays: your tap results, checkpoint stars, burst pulse, "+N" where you gained places in the final quarter. Half speed over the last 2 s only when you won; a photo-finish still when 1st and 2nd were under a length apart. A new race cancels any replay.
- Alternatives: autoplay (pressure to watch), server-side re-simulation (could show things not shown live), slow motion on narrow losses (replays the near miss).
- Links: game/src/client/Replay.client.luau, game/src/client/RaceController.client.luau (results buttons), game/src/client/RaceState.luau

## D-035 — One server, one small world
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (young player draft; research brief (competitors 16–30 players; Roblox has no plot feature, build our own))
- Decision: 20-player servers; racecourse, Fair Street (Race Board, Feed & Seed, Vet, Training Paddock, Market Corral, Trail Gate), Barn Row (one plot per player, loaded from the save), the Trail; all within ~20 s ride of the grandstand; ride your horse everywhere, Map fast-travel with five pictures, GO hoofprints.
- Alternatives: Private stable servers (teleports split friends), backside barns across the track (long rides, crossing the track during races).
- Links: docs/WORLD_DESIGN.md

## D-036 — Racing in a shared world
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (competitive and young player critiques)
- Decision: Two courses (dirt and turf) run a race each, so two run at once; one card per league on the Race Board and a Race button anywhere; a league posts within 30 s of its first rider, bots fill after 20 s; picker shows each horse's Energy and today's fit as Rating; Rookie free, cash races 1 Energy; cash fields never mix leagues, Rating band ±12 widening to ±20; friends and party members never share a cash race (Friend Races instead); each lane counts at least 25 in the race average.
- Alternatives: Strict one-track queue (2–4 min waits with mixed leagues), several races drawn per client on one course (riders replicate to everyone), teleport per race (breaks the shared world).
- Links: docs/WORLD_DESIGN.md

## D-037 — Owning horses
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (engagement draft; child safety; competitive)
- Decision: Pick 1 of 3 starters (coats differ, stats equal), name by tapping suggestions; 2 stalls to start, buy up to 6, free pasture for extras; one active horse follows you and is preselected; new horses from the Market Corral (weekly restock, rare stock returns), taming on the Trail, events, breeding later; never for Robux or Diamonds, no trading; no ageing; retiring is the player's choice with a Hall of Fame plaque.
- Alternatives: Diamond horses (pay-to-win through stats), loot-box horses (paid random items), ageing horses (loss).
- Links: docs/WORLD_DESIGN.md

## D-038 — Care and food
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (engagement draft; child safety critique)
- Decision: Feeding and grooming each fill half of today's care (full care = +5% Rating until rollover, then back to baseline, never below); each also +1 Energy once per 2 h; petting and treats add bond; garden beds grow offline and never wither; Feed & Seed sells hay, grain, seeds and treats; chores always give hay; starter hay for new players; rest speeds training.
- Alternatives: Hunger and thirst meters that drain (guilt and pressure; Horse Valley's vet sells restores), food required to race.
- Links: docs/WORLD_DESIGN.md

## D-039 — The vet is a wellness clinic
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (child safety draft; engagement agreed)
- Decision: Free check-ups with a heartbeat tapping game (+1 bond a day), Health Passport stamps (one reveals Potential), cool-down hose after races; nothing to cure or buy. David's "sick horse to the vet" conflicts with hard rule 3, so it is not built (David confirmed 2026-10-05: skip sick horses).
- Alternatives: Sickness from neglect (hard rule 3), sore legs after hard races (teaches that racing hurts horses).
- Links: docs/WORLD_DESIGN.md

## D-040 — Training
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (competitive draft; debate 008)
- Decision: One mini-game per stat at the Training Paddock (Sprint Lane, Gate Break, Hill Climb, Mud Splash); gain ∝ (Potential − stat); weekly cap reachable in about 3 sessions per horse; rested horses +50% inside the cap.
- Alternatives: Passive timers only (no play), unlimited training (grind), Diamond training skips (pay-to-win).
- Links: docs/WORLD_DESIGN.md

## D-041 — Spectators
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (young player draft)
- Decision: Cheer cards for anyone near the rail or in the grandstand, for either course; Clap Along after cheering; Fan XP cosmetic only (D-019, D-020); the Big Board shows races to anyone far away.
- Alternatives: —
- Links: docs/WORLD_DESIGN.md

## D-042 — Friends and safety
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (child safety draft and critique; research (age-banded chat since January 2026))
- Decision: Roblox chat only, preset emotes for players who can't chat, every typed name filtered; stable visits Friends (default), Club or Nobody, closed gate for others, anonymous carrot count for strangers; one free treat a day per friend (bond only); no trading, no cash transfers.
- Alternatives: Public visit counts or likes (popularity scores), open visits (stalking risk), gifts of cash (begging, alt farming).
- Links: docs/WORLD_DESIGN.md

## D-043 — Stable Board: daily, weekly and monthly jobs
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (young player, engagement, competitive and child safety critiques; haunt-nyc Mission Center)
- Decision: Noticeboard in the barn and a clipboard button; horse status row (ready, napping, crops ready, training ready), next step per horse, 3 daily / 5 weekly / ~5 monthly jobs, never win jobs, auto-claim at rollover, one free reroll a day, calendar counts days played and pauses, no streaks, countdowns, bell, red badge or push notifications; wording states facts about the horse, never feelings about absence.
- Alternatives: haunt-nyc's tabs as-is (more reading), win tasks (luck, collusion), Diamond rerolls (buying Green Cash).
- Links: docs/WORLD_DESIGN.md

## D-044 — Money guardrails (amends D-002a)
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (child safety; engagement agreed)
- Decision: Diamond time skips apply to decor builds only; Diamonds buy cosmetics, decor, stall and stable skins, tack looks, the Derby Pass and extra rerolls; never horses, stats, Green Cash or paid random items; the Diamond store isn't built until David signs off.
- Alternatives: Skips for garden, training, Energy or foals (each leaks into stats, races or random rolls).
- Links: docs/WORLD_DESIGN.md

## D-045 — For grown-ups
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (child safety draft)
- Decision: A button explaining races (no gambling, nothing buys speed), Diamonds, the visit setting and weekly play time, with a pointer to Roblox parental controls and an optional break reminder.
- Alternatives: —
- Links: docs/WORLD_DESIGN.md

## D-046 — Leagues and careers
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (competitive draft)
- Decision: Stakes unlock by League Points and a win promotes; once a horse's Rating passes its league's ceiling its Stakes opens and regular cash races close to it; Bronze adds Classic, Silver adds Marathon; strength pays through places and faster League Points (purses are B/q).
- Alternatives: Demotion (loss), letting over-strong horses farm low leagues.
- Links: docs/WORLD_DESIGN.md

## D-047 — Breeding (later)
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, world workshop (competitive draft)
- Decision: From Bronze, Green Cash fees only; foal Potential 0.7 × parents' average + 0.3 × breed average ± 5; foals start at 35% of Potential; coats separate from stats; a sim must show bloodlines level off before building.
- Alternatives: Diamond breeding boosts (paid random items), full inheritance (runaway bloodlines).
- Links: docs/WORLD_DESIGN.md

## D-048 — League promotion races are called Cups
- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team (moderator call, small)
- Decision: in the game the Stakes race of each league (D-013, D-046) is called the **Cup**: "Rookie Cup", "Bronze Cup", and so on ("Win the Rookie Cup to move up!"). Rules are unchanged: League Points or the league ceiling open it, the winner gets 3B and moves up a league.
- Why: "stake(s)" is on the policy guard's wagering list (hard rule 1), and for kids it reads like betting ("high stakes"); "Cup" is a familiar sports word with a trophy to match.
- Alternatives: "Stakes race" (allowed by the guard as a phrase but still betting-flavoured for kids), "Championship" (too long for buttons), "Final".
- Links: game/src/shared/Leagues.luau, game/src/server/RaceService.server.luau, game/src/client/RacePicker.client.luau

## D-049 — The first ten minutes: a guided tour you can skip
- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team (young-player's first-10-minutes script from the world workshop, trimmed to five steps)
- Decision: after the starter pick, a small card at the top of the screen walks the player through five steps, each finished by doing it (the same events the Stable Board counts): ride in a race, feed your horse, brush it, plant your carrot seeds (new players start with two), open the Stable Board. Each step has a GO button (golden hoofprints, or the race picker) and the card has Skip; Settings can show it again. Nothing is locked behind the tour; older saves that have already raced skip it.
- Alternatives: a long text tutorial (kids don't read it), forced steps (pressure), no tour (the world is big and new players wander).
- Links: game/src/shared/Tour.luau, game/src/server/SettingsService.server.luau, game/src/client/GrownUps.client.luau

## D-050 — The Diamond store: Tack & Paint
- Date: 2026-10-05
- Status: Accepted (provisional); David approved building the store ("yes do diamond store")
- Decided by: team (child-safety and engagement/young-player consults; moderator sided with child safety where they disagreed)
- Decision: Diamonds are bought with Robux through three developer products, **1 Diamond = 1 Robux in every pack** (50, 100, 250; no bigger-pack bonus). They buy looks only, in the **Tack & Paint** shop on Fair Street or from the 💎 button in the dock: saddle cloths and helmets (worn when riding around the world; races keep lane colours), barn paint sets (walls, roof, trim), gold name plates, yard decor in fixed spots (bench, lanterns, saddle rack, picnic table, hay cart, bridge); prices in steps of 25. **Never sold:** horses, coats, stats, speed, Green Cash, food, seeds, stalls, Energy, race entries, job rerolls, fan gear (earned with Fan levels), trophies and rosettes (they look like real wins), anything random; no Derby Pass yet (its season clock pressures kids). Free Diamonds only from milestones: 25 per league promotion and 25 for finishing every monthly job; never for Fan levels (Fan XP includes backing the winner, so it stays cosmetic, hard rule 1), logging in, streaks or race places. Our own caps on top of Roblox parental controls: 250 Robux in any 24 hours, 1,000 in any 30 days (rolling). Any look can be returned within 24 hours for all its Diamonds. The server refuses Diamond prompts while in line, racing, on the results screen and for 2 minutes after a race, past the caps, or when PolicyService can't be read. The shop opens only by a tap: no pop-ups, offers, timers, "limited", "best value" or rotating stock; visitors see no prices. Receipts are recorded and saved before PurchaseGranted. The Star Set (stars cloth, star helmet, star flag) puts a gold star on your name plates.
- Amends: D-002a and D-044 (no Exhibition entries, no Diamond rerolls, no time skips for now, Derby Pass later).
- Alternatives: bonus tiers on bigger packs (exchange rates that change with bundle size are a point in the May 2026 FTC complaint), selling fan flags or trophies, race-day cosmetics over lane colours, login Diamonds.
- Links: game/src/shared/Style.luau, game/src/shared/DiamondProducts.luau, game/src/server/StyleService.server.luau, game/src/server/Purchases.server.luau, game/src/client/StyleShop.client.luau

## D-051 — Running legs
- Date: 2026-10-05
- Status: Accepted
- Decided by: David ("lets add animated legs/feet when the horse runs"); team (method)
- Decision: the standing horse of every coat is cut into a body and four legs (tools/meshy/split_legs.py: legs below 38% of the height, split front/back by low-vertex clusters, left/right at the widest gap, the long tail stays on the body, a thin overlap above the cut hides the hip seam) and uploaded as `horse_anim_<coat>`. Each leg swings about its hip in a gait picked by speed: walk (four-beat, 18°), trot (diagonal pairs, 26°), gallop (four-beat with suspension, 36°, front legs reach further); the phase follows distance travelled so feet keep pace with the ground; legs ease back to standing when a horse stops. Race horses (live and replays) and wild horses pose their anchored legs each frame; ride horses swing legs on hip Motor6Ds that every client drives. One-piece gallop poses stay as the fallback until the split models load.
- Review fixes: each leg's resting place is stored on it (LegRest attribute, AssetService), so a pose never drifts; gait changes cross-fade over a quarter second; legs rest when a race or replay ends; slow-motion replays pick the gait for the race's real speed; riding at 16 studs/s walks (walk < 20, trot < 36, gallop above); source normals kept (smooth shading); only overlap faces right above a leg go with it (no belly flaps); a horse whose legs didn't import separately falls back to the one-piece poses; wild horses beyond 150 studs skip the legs.
- Saddle cloth: the split also makes a **Cloth** piece, a clean blanket shaped to the horse's back just behind the withers (a grid of rays cast onto the body). It's hidden until shown: race horses wear it in their lane colour with the lane number on both sides; ridden horses wear the rider's Tack & Paint cloth (D-050). Seats sit just below the cloth's top, so jockeys sit on the back of the bigger standing model.
- Alternatives: Meshy rigging (humanoids only), separate per-pose models (no motion), Roblox Animation Editor rigs (needs Studio work by hand on every coat).
- Links: tools/meshy/split_legs.py, game/src/shared/HorseLegs.luau, game/src/client/RaceView.client.luau, game/src/server/Rides.luau

## D-052 — Sound and the race announcer
- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team (audio lead, small call)
- Decision: one warm, upbeat announcer voice (ElevenLabs premade "Liam", Flash v2.5) with eight short lines, plus short friendly sound effects (docs/audio/AUDIO_PLAN.md). Race cues follow the shared clock: bell and "And they're off!" at the gate, "Into the far turn!", whoosh and "Final Burst!", "Down the stretch they come!" when the burst closes, fanfare and cheer at the line, "What a finish!" on the results card, "Photo finish!" in a replay. Riders hear their own race and their own hoofbeats; spectators hear race cues at half volume, and only within about 250 studs of that race's course. The Green Cash chime waits for your results card, so it never gives the result away. UI buttons pop quietly. Sound is on by default with an On/Off choice in Settings (`settings.sound`).
- Why: sound tells young players what's happening without reading, and on a phone their eyes are on the slider; the announcer names the race moments the HUD already shows.
- Alternatives: no announcer (less excitement, more reading), a different voice per moment (costs more, less familiar), sound off by default (most kids never find it), spectator cues heard everywhere in the world (an announcer in the stables and on the trail).
- Links: game/src/client/Sound.luau, game/src/client/RaceController.client.luau, tools/audio/sounds.json

## D-053 — Training rides

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 009 (4/4 on the shape after one rebuttal round); David asked: "The training ground should be more than just the click the meter a few times. You should run around with the horse."
- Decision: training becomes four short ride-through courses on your own horse, using the free-riding controls.
  - **Where:** a Training Ground south of the Training Paddock (`WorldLayout.places.trainingGround`, x 650–950, z −70 to 70), reached by a gate in the paddock's south fence. It holds a training oval (160-stud straights, centre-line radius 55, 24 studs wide, ~666 studs a lap). The paddock arena holds the gymkhana.
  - **The four courses** keep the stat names players know:
    - **Sprint Lane** (Speed, a "breeze"): 3 laps through 18 hoops 10 studs wide; only the next one glows, with hoofprints between them. Score = 100 × hoops / 18.
    - **Gate Break** (Acceleration, gate school): 3 breaks from a practice gate; the bell rings after a random 1.5–3.5 s; gallop to the flag 120 studs on. A break scores 100 for a reaction ≤ 0.5 s, falling to 40 at 2 s. Going early reruns that break once ("Wait for the bell!").
    - **Hill Climb** (Stamina): follow Pip the lead pony for 2 laps over a gentle hill, staying in a ring 1–3 lengths behind as Pip weaves and changes pace (30–42 studs/s). Inside the ring your horse matches Pip's speed by itself. Score = share of time in the ring.
    - **Mud Splash** (Grit, gymkhana): 4 puddles to splash through (7.5 each), 3 low logs to hop (12 each, clean = airborne), and 4 wide bending poles in a slow zone where the horse canters by itself (8.5 each).
  - **Length:** each ride takes 35–50 s.
  - **No failure states:** a missed hoop or knocked pole just doesn't count; there's no on-screen timer, and the horse never stumbles, refuses or looks hurt.
  - **Gain:** the D-040 formula is unchanged, with quality = 0.5 + 0.5 × the server's score / 100. Rested ×1.5 stays.
  - **Cap and cost:** the weekly cap stays 6 points per horse. **Training costs no Energy** (D-015 unchanged). After the cap the courses stay open for stars, ribbons and your ghost, with no gain ("Speed is full this week. Ride for stars!").
  - **Rewards:**
    - 1–3 stars (2 at a score of 60, 3 at 90);
    - a bronze, silver or gold ribbon per course per horse (silver at 75; gold at 90 and under par);
    - a rosette on the stall wall for each gold;
    - the Stable Board "train" job.
    - No bond, cash, Energy or Diamonds.
  - **Equal physics:** horse stats don't change course speed.
  - **Solo:** a private, see-through ghost of your best run.
  - **With friends:** Roblox friends can "Ride together" from a shared 3-2-1, each scored alone. Course riders never collide with anyone. Shared results show stars and ribbons, never ranked times. A friend's ghost appears only if they share it (off by default). No leaderboards.
  - **Controls:** the free-riding ones (thumbstick or WASD; Gallop button, Shift or a new R2 binding; Jump, Space or A), with a soft 4-stud hoop magnet. **Easy Rein** in Settings (off by default) steers toward the next hoop or ring, with no score penalty.
  - **Server validation:**
    - The client sends no score; the server samples the ride rig at 10 Hz and finds every hoop, gate, log, pole, puddle and ring event itself.
    - It discards samples over 53 studs/s, jumps over 12 studs, and samples off the course. More than 10% discarded scores at the 0.5 floor, with no accusation. The floor is log-only for the first two weeks.
    - Sessions are 4 s apart, at most 40 an hour. A race starting, getting off or leaving the ground ends the session with no gain and no penalty.
  - **Quick Train:** the four 10-second games stay on the course picker for everyone, labelled "Quick train". They share the same cap with quality capped at 0.85 and move to server scoring (server seed, D-021 latency allowance).
  - **Later:** "This week's course", a rotating Mud Splash layout with no countdown, whose ribbons can be earned whenever it returns.
- Amends: D-040 (the meter games become Quick Train; courses are the default).
- Alternatives: meter games plus a cosmetic warm-up lap (not what David asked; still trusts the client); one mixed course for all stats (can't train the suggested stat); seeded green-window hoops with timed scoring (near-miss feel; the speed ceiling already stops hacks); 1 Energy per session (competes with racing); bond after the cap (bond is in Race Rating, so it becomes an uncapped grind); Speed stat raising course speed (minority, Engagement).
- Implementation notes (T1 and T2, 2026-10-05, provisional, roblox-engineer): calls the plan left open.
  - **Mud Splash pace:** the paddock arena (170 × 150) is too small for a 35–50 s gymkhana at a gallop, so the course is six lanes joined by turns, ridden at an arena lope of 28 studs/s (`grit.pace`) with the poles at a canter (20). Ideal 37 s. A gallop in that arena would also be too fast to steer on a phone. Alternative: two laps of a shorter loop (each piece counted twice, or the second lap pointless).
  - **Gate Break's practice gate** stands in the oval's infield with its own lane and a loop back to the gate, so it never blocks Sprint Lane or Hill Climb riders on the track. Ideal 39 s with a canter back between breaks. Alternative: a gate on the back straight (in everyone's way) or one that appears only for its rider.
  - **The hill** is on the south (back) straight, 6 studs high with 40-stud ramps (slope 0.15); one Sprint Lane hoop sits on top.
  - **Props never collide:** hoops, poles, logs and finish posts are in the `CourseProps` collision group with CanCollide off, so no horse snags. A log scores only when the horse is 1.5 studs above its riding height within 3 studs of it ("Clean hop!"); riding through it just doesn't score.
  - **Picking a course puts you at its start** (and calls your active horse if you weren't riding), with the horse held still for the 3-2-1. Courses train the active horse; Quick train still lets you pick any stalled horse.
  - **Quick train's quality is capped at 0.85 now** (score 70), as D-053 says, though its games stay client-scored until T4.
  - **Ending:** Sprint Lane ends after three laps of progress; Mud Splash at its finish arch (only after 40% of its ideal time). A ride still going after 120 s ends; it counts (bronze at least) only with real riding in it: something scored, or more than a quarter of the course. Otherwise it ends with no gain and "Let's try that one again!". Leaving the course area for 2 s, getting off, a race or Stop end it with no gain.
  - **Network freezes and dropped samples (fixed after review, 2026-10-05):** a position that doesn't change right after movement is a frozen replica and is skipped, so the catch-up is measured over the whole freeze. A too-fast catch-up is dropped and counted, but only a teleport (over `maxStep`) stops crossings counting across it. Progress round the oval clamps an over-large jump instead of throwing it away, and snaps back onto each hoop ridden through. Tested with single and back-to-back freezes, 1% random 100–200 ms freezes on 100 rides, freezes that wobble a hair and freezes on the run-in: a perfect ride scores 18/18 and ends at the line every time. Off-course samples don't score and don't count toward the floor.
  - **Collisions:** players on foot are in a `Walkers` group that collides like Default except with `TrainingRiders`, so course riders never collide with anyone.
  - **Controls:** in a course a part-pushed stick still rides at full course speed (only its direction counts, above a 0.2 deadzone).
- Implementation notes (T3, 2026-10-05, provisional, roblox-engineer):
  - **Gate Break flow:** a break readies ("Ready…") once the horse has stood still in the stall for 0.5 s (`accel.settleSeconds`). A go is the horse getting 2 studs (`accel.goStuds`, about goSpeed × one 0.1 s sample) from where it was readied, or leaving the stall; its start is worked back from that distance at a gallop, never before the break was readied, so a frozen replica at a standing start doesn't make it look slow. The server rings the bell on time and the bell comes from a server-only seed that is never sent (Pip's seed is the shared one), and no event carries the bell time. The stall box is the stall plus a little room round it (11 × 8 studs).
  - **Latency allowances (corrected after review):** Gate Break: the bell goes out and the go comes back, so the round trip plus the race's jitter margin (`TrainingRide.bellAllowance`), measured when each bell rings, capped at 0.3 s. Hill Climb: the rider's screen runs the countdown and Pip on the server's clock (TrainBegin carries the go time; `workspace:GetServerTimeNow()`), and the server sees the rider one trip late, so one way plus the margin (`TrainingRide.lagAllowance`), from the ride's median ping.
  - **Back to the gate:** between breaks the horse canters (the ideal time already assumed it) and stops by itself in the middle of the stall, so kids don't overshoot an 8-stud stall; the hold lets go after 3 s if the server hasn't readied it. A stick still pushed from riding in has to be let go once before the horse can leave the stall, so nobody is launched into an early go. After the go, settling back in the stall without reaching the flag still ends the break (no getting stuck).
  - **Early twice** counts as an easy start (breakFloor 40): the doors open and "Off you go! Ride to the flag!"; there is no fail.
  - **Hill Climb ring** is measured round the oval (8–24 studs behind Pip, 6 either side of his line), so it never drifts; the ride ends when Pip finishes his two laps. Time off the track (the infield too) counts as out of the ring; only frozen and too-fast samples are left out. Behind the ring by any amount the horse gallops to catch up; ahead of it, it eases to 70% of Pip's pace.
  - **Pip** is the uploaded palomino with running legs at 0.85 scale (`horse_anim_palomino`), with the fitted Cloth tinted teal and "Pip" on it, seen only by his rider (riding friends come with Ride together, T4). No new models.
  - **The practice gate never collides** (CourseProps, CanCollide off), now that ride rigs have a shins collider.
  - **Easy Rein** steers 75% (15% when you pull more than 90° away, so you can still turn round) toward a point a little ahead on the course (on the track at the next hoop's line, along the gymkhana or gate route, at Pip's line), only while the stick is pushed, so the rider still chooses to go. No score change.
  - **Ideal times:** Gate Break includes the 0.5 s settle per break: 40.3 s with average bells. Its par (gold) uses the bell waits that ride really had, so gold never depends on bell luck.
- Implementation notes (T4, 2026-10-05, provisional, roblox-engineer):
  - **Ghosts per player per course,** not per horse: course physics is the same for every horse (equal physics above), so your best ride is a fair ghost whatever you rode, and there are only four to keep. The ghost shows the coat it was ridden on. Best = more score, then a quicker time. Only unflagged rides become ghosts.
  - **Ghost storage:** its own DataStore (`GiddyUp_Ghosts_v1`, key `ghosts_<userId>`), loaded the first time a ride needs it (3 tries), saved on leaving, every 2 minutes if changed and at shutdown, always merging with what's stored (the better run per course wins), so a failed load or a second server never overwrites a better ghost. Encoding: 4 Hz, 0.5-stud, ≤ 300 points, deltas as base64url varints (about 5 characters a point, under 1.5 KB a ghost).
  - **Friends' ghosts** show only in a solo ride, only from friends in the same server who turned on "Share my ghost with friends" (off by default), at most two.
  - **Ride together** is two riders (you and one friend) for now. Friendship comes from a cache filled when players join (`IsFriendsWith`, pcall). The stable visits setting doubles as the friends privacy switch: "Nobody" on either side means no invites. Invites are accept-only, lapse after 20 s with no countdown shown, one pending either way, 8 s apart and at most 5 in five minutes; the card carries only the inviter's Roblox display name and a course. The group shares one countdown (2.5 s longer, for horses being called) and one Pip (one seed for both, simpler than seeing each other's); each rider has their own bells and is scored alone. Riders start side by side, except Gate Break where both share the stall (they pass through each other). The end card shows the friend's stars and ribbon only.
  - **Rosettes** sit under the horse's name plate on its stall, one per course with a gold ribbon (the uploaded rosette_ribbon, or a part rosette).
  - **Quick train on the server:** the games are pure functions of a server seed and tap times (QuickTrain), so the screen and the server agree; taps are resolved with TapTime.resolve and the race's one-way allowance. Small changes so the server can know when a game ends: a Sprint Lane round with no tap passes after 6 s (scores 0), a Gate Break light with no tap 4 s after green counts as the slowest tap, Mud Splash's puddle spacing varies a little (0.7–0.8 s) with the seed and Hill Climb's band with it. The reaction time and the hold game's countdown are no longer shown (no timers on screen).
- Links: docs/debates/009-training-rides.md, game/src/shared/TrainingCourses.luau, game/src/shared/TrainingRide.luau, game/src/server/TrainingService.server.luau, game/src/client/TrainingRideClient.client.luau, game/src/shared/WorldLayout.luau, game/src/server/WorldScene.luau

## D-054 — Race steering

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 010 (4/4 after one rebuttal round; drafting 3–1, Young player wanted ground only); David asked for steering "constrained to look realistic where they can affect the outcome slightly".
- Decision:
  - **When:** riders change lanes from the gate to the far-turn entry. Three soft bell ticks, then "Lanes locked!"; after that lanes are cosmetic, and the stretch is the slider and the Final Burst only.
  - **How a lane change works:**
    - One press moves one lane, with a 0.6 s glide that starts instantly on the rider's screen; at most one change per 0.6 s, one queued.
    - **Tuck-in:** a horse alongside blocking a move toward the rail makes yours ease back (up to ~1.5 lengths) and slot in behind it. This is visual only.
    - A blocked move outward cancels after 1 s.
    - Horses never overlap or bump; the mover gives way; a horse held behind another is drawn there.
  - **The trip:**
    - Ground: 0.012 per lane off the rail per 180° of turn. Earlier turns count live; the far turn is booked from the lane held at the bell.
    - Tucked in: 0.0012 per second while 0.5–3 lengths behind a horse in the same lane, before the lock only, capped at 0.016.
    - **No boxed-in penalty.**
    - τ_i = clamp(scale × (trip_i − postBaseline[course][distance][post_i] − field mean of the same), −0.02, +0.04); scale = 1.
    - Win chance becomes p ∝ q · exp(κR + c + τ). τ is fixed at the lock and used from then on (checkpoint 2, Final Burst, stretch previews, finish). Before the lock τ = 0, so the trip never depends on luck, and Harville and the locked purses are unchanged.
    - Size: the best trip, +0.04 (2 points of S), gives +0.44 pp win chance and gains a place in about 1 race in 15; the worst, −0.02, costs 1 point.
  - **Smart Steer:**
    - On by default. It rides one off the rail, heads in about 8 s before turns, tucks in when blocked, never seeks a draft and never moves out.
    - Any input pauses it for 5 s; it then resumes but never moves the rider outward. Settings has an on/off toggle (default on).
    - The arrows are hidden for each player's first 3 races, then introduced with a ghost-thumb tip.
  - **Controls:**
    - Phone: two big buttons bottom-left (◀ In, Out ▶); the default touch thumbstick is off during races, and every other touch still taps the slider.
    - Keyboard: A/← and D/→, taken out of "any key taps".
    - Gamepad: D-pad or a left-stick flick, taken out of "any button taps".
  - **Server authority:**
    - The server owns all lanes. Clients send intents (`SteerRequest(dir, seq)`), applied on the next 10 Hz tick in arrival order (ties: leader first, then the inside horse), with no rewind; the rider's own glide is predicted.
    - Spam is rate-limited; requests after the lock are ignored; disconnects go to Smart Steer.
    - Lane positions go out with the gaps at 10 Hz until the lock.
  - **Bots and posts:**
    - Bots use Smart Steer with variety (4–12 s lead before turns; 25% ride the rail) drawn after all existing random draws.
    - Posts are drawn at random by the server (no longer humans first), never shown as a draw, and corrected by the per-post baseline.
  - **Feedback:** "Saved ground!" at turn exits, "Tucked in!" with wind lines, a gentle tip when wide into a turn (never "lost a place"), and "Good trip ★★☆" on the results (★★★ at τ ≥ +0.015, ★★ at ≥ −0.005, otherwise ★, never zero). "Your trip gained you N places!" appears only when positive.
  - **Replays** record each horse's lane per frame on this screen and add your line as a ribbon with green chevrons, wind lines and the lock marker; no ideal-line ghost.
  - **Python:** `live_chances(..., extra)` and `src/trip.py` mirror `Trip.luau` exactly (D-012).
- Tuning: in the moderator's prototype a skilled steerer gains +0.011 to +0.023 over Smart Steer, a rider who never steers with Smart Steer off loses 0.014–0.016, and the post baseline cuts post bias from up to ±0.02 to at most 0.003. Without tuck-in most lane changes were refused. All values are in `GameConfig.steering`, and the post baselines are generated into `TripBaseline.luau` by `sims/steering.py`.
- Amends: D-026 (steering keys and buttons are no longer slider taps), D-033 (lane holds and tuck-ins on screen before the far turn; τ in the exponent from the lock), V2_PROPOSAL step 5 (exponent κR + c + τ), D-032 (lanes now mean something; the race strip keeps one row per horse).
- Alternatives:
  - cosmetic steering only (kids learn the input does nothing; kept as `scale = 0`);
  - steering live through the far turn (clearance would depend on positions luck is moving);
  - real-scale ground loss (steering would outweigh taps);
  - a boxed-in penalty (strangers could hurt each other; invites griefing and collusion);
  - continuous stick or tilt steering (load next to the slider);
  - swipes (a swipe starts as a touch, so kids would swipe through their taps);
  - post bias folded into q (changes locked purses; the baseline keeps q untouched).
- Links: docs/debates/010-race-steering.md, src/trip.py, sims/steering.py, game/src/shared/Trip.luau, game/src/shared/TripBaseline.luau, game/src/shared/TrackLayout.luau, game/src/shared/RaceSession.luau, game/src/server/RaceService.server.luau, game/src/client/RaceController.client.luau, game/src/client/RaceView.client.luau, game/src/client/Replay.client.luau

## D-055 — Race feel and HUD fixes

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 011. It was a short round of independent openings, 4/4 on direction for every call; the moderator settled sizes and words. David asked after his play-test: "the behavior still had some quirks, review with the game design team". The QA race audit (Lune sims) supplied the findings; the pure bugs are fixed separately.
- Decision:
  - **Bounce taps** (amends D-026):
    - A tap within **150 ms** of the last *counted* tap is ignored. This holds across a pass boundary too.
    - The first tap counts, never the better of two. A real second tap later in the same pass still scores the pass 0.
    - The server scores it in `PaceMeter.score`, mirrored in `src/pace_meter.py` (parity tests). The client applies the same rule to its labels.
    - Ignored taps are never used as timing samples. (Tallying them in the integrity log waits for the anti-cheat tooling, STATUS backlog.)
    - Simulated with 15% of taps bouncing: Rookie 66 → 77.5 (77 with no bounces). Mashers still score ≤ 4.2 in every league. The fixed-interval clicker stays at 59.
  - **Gate countdown:** (the drum tick, `count_tick`, is in the sound list but silent until the sound effects are generated and uploaded)
    - Big "3", "2", "1" at the centre over the existing 3 s before the gate, one per second on the server clock, each with a soft drum tick. The bell rings with **"GO!"**, then "And they're off!".
    - Drum, not bell, because D-054's lane lock uses bell ticks.
    - The camera moves into the saddle at "3". The slider shows still, with the first glow lit.
    - Taps before the bell do nothing and show nothing (no false starts).
    - Spectators in range see smaller numbers. Reduced Motion fades the numbers instead of popping them.
  - **Tap feedback:**
    - A pass that ends with no tap shows no word and no icon; the glow greys for 0.3 s and the speed meter dips as today.
    - A tap scoring under 30 says **"Early"** or **"Late"** (tap time against the pass's ideal time) instead of "Miss".
    - A second tap says **"One tap!"** (was "Too fast!"), with the same hint.
    - A rider who misses the Final Burst sees **"Finish strong!"**; spectators see no burst text.
  - **Spectator range** (amends D-041):
    - A non-rider follows a race only within **250 studs** of that course's outer edge, the same range as race sound (D-052). Once following, they keep it until 300 studs, so nothing flickers at the edge.
    - **Busy rule:** no race HUD, cheer strip or results card during a training ride, a care or training game, or while a full-screen panel is open (shops, My Horses, Stable Board, Map). The HUD appears when the kid is done, if still in range.
    - A spectator gets a results card only if they followed the finish (checked when the card appears, about 2.4 s after the line).
    - As built: following is decided when the race starts (within 250 studs); the HUD then hides while busy or beyond 300 studs and comes back when the kid is done. A kid who walks up mid-race sees the next race.
    - Far away there is nothing: no toast and no badge. The Race Board on Fair Street is the far view (D-041).
  - **Running-order board** (amends D-030/D-032; answers OPEN_QUESTIONS #1 provisionally):
    - **Riders:** the board is hidden from the gate to the finish on every device; the race strip and the place badge show position.
    - **Riders' status line:** it no longer prints the live "Win chance: N% (+d)"; the badge's up/down arrow stays (D-033).
    - **Spectators:** rows show place, lane badge, name and a ★ on the rider they cheered, who gets the up/down arrow after cheers lock (D-019).
      - Phones (short side ≤ 500 px): the top 3 plus their rider, at most 4 rows, shown once the cheer strip has closed.
      - Tablets and PC: all 8 rows.
    - **No win % or purse column anywhere.** Next to names, the pair reads like a tote board, and a live % tells a kid mid-race that they've lost. Prizes stay on the race picker card.
  - **Tap keys** (amends D-054's carve-out):
    - Only Space, Enter (Return and KeypadEnter), left mouse, touch, and gamepad A and R2 tap.
    - On keyboard devices the slider shows a small "SPACE" key cap.
    - The first other key pressed during a pass shows "Tap: SPACE or click" ("Tap: A or R2" on a gamepad), once per race.
    - Steering keys (A/D, arrows, D-pad), C (clap), E/X (prompts), I/O, Tab and `/` are simply not taps.
  - **Config:**
    - `GameConfig.pace.bounceSeconds = 0.15` (0 = D-026 rule);
    - `GameConfig.gateCountdownSeconds = 3` (replaces `COUNTDOWN` in `RaceService`);
    - `GameConfig.hud.missedPassLabel = ""` ("Miss" = old behaviour);
    - `GameConfig.hud.earlyLateBelow = 30`;
    - `GameConfig.spectate = { rangeStuds = 250, keepStuds = 300 }` (also replaces `SPECTATOR_HEARING_STUDS`);
    - `GameConfig.hud.riderBoardInRace = false` (true = David's D-030 layout);
    - `GameConfig.hud.boardShowsChance = false`;
    - `GameConfig.hud.spectatorBoardRowsPhone = 4`;
    - `GameConfig.tapKeys`;
    - `GameConfig.raceView` holds the on-screen motion fixes that came with this round (every lane timed on lane 1 so the crossing order is the result, gaps change at most 10 ft/s, horses ease out of the gate, the tap nudge is drawn but not ranked).
- Why:
  - Every call removes a moment where a kid did the right thing and the game said otherwise: a bounce zeroing a good tap, a start with no warning, a failure word while they look away, a stray key spending the burst, or a race popping over the barn.
  - The board change also takes the last win percentages off the race screen (D-033, D-019).
- Alternatives:
  - keep two taps = 0 (punishes motor noise, not cheating);
  - measure the 150 ms from the *last* tap (a fast masher would keep one tap per pass);
  - a non-scoring warm-up sweep during the countdown (Engagement; taps that do nothing confuse first-timers);
  - "Miss" only after N untapped passes (still a failure word);
  - a 220-stud range (Young player; the busy rule covers shops and training);
  - a "go watch" toast for far-away players (a pull every 1–2 minutes);
  - board hidden on phones only (two layouts, and the % problem stays);
  - keep the board as is (56% of a phone screen);
  - a deny-list of keys (the tech lead's interim; every new binding leaks in);
  - gap in lengths on spectators' rows (Competitive, Child safety; the strip already shows gaps).
- Links:
  - docs/debates/011-playtest-quirks.md
  - game/src/shared/PaceMeter.luau
  - src/pace_meter.py
  - game/src/shared/GameConfig.luau
  - game/src/server/RaceService.server.luau
  - game/src/client/RaceController.client.luau
  - game/src/client/RaceState.luau
  - game/src/client/Minimap.client.luau
  - game/src/client/FanClient.client.luau

## D-056 — Riding feel and world fixes

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 011 (4/4 on direction; the moderator settled sizes and words). The QA riding-and-world audit (Lune sims) supplied the findings; the pure bugs are fixed separately.
- Decision:
  - **Hop button:**
    - On touch, while riding outside a race, a **"⬆️ Hop"** button sits at Roblox's own jump spot and size: 70 px at (1,−95,1,−90) when the screen's short side ≤ 500 px, otherwise 120 px at (1,−170,1,−210). It uses the existing JumpRequest hop. Gallop stays above it.
    - **Right-column rule:** on touch the bottom-right column belongs to movement buttons (Hop, Gallop). The dock fits into the width to its left (about W − 154 px on phones, scale 0.55–1 as today), so Ride/Get off is never under the jump thumb.
    - PC and gamepad keep Space and A.
  - **Gaits** (amends D-051):
    - walk {stride 5, amp 24°} below **12** studs/s;
    - trot {stride 7, amp 30°} from 12 to 36, so riding at 16 studs/s trots at 2.3 Hz;
    - gallop {stride 18, amp 40°} above 36: 2.6 Hz riding, 3.1 Hz racing.
    - Bob = 0.15 × |sin 2π·phase| driven by the leg phase, minus the lowest hoof's lift, so hooves stay on the ground and the rider moves with the back. Reduced Motion keeps the camera off the bob.
    - Simulated: planted-hoof slip at riding speed falls from 73% to 38%. QA's walk at 16 studs/s would have needed 3.2 Hz "sewing-machine" legs; real trots run about 1.5 Hz and gallops 2.2–2.5 Hz.
    - As built: the bob moves the horse's body only; the saddle stays on the rig's root, so the rider doesn't bob (the body's 0.15 rise never reaches the rider). Moving the rider with the back waits for a Studio check.
  - **Diamond button** (amends D-050's placement):
    - On touch, 💎 leaves the dock for a 48 px "💎 N" pill at the top-right, below the Roblox top bar. It has no glow, pulse, badge or sound, and a tap opens Tack & Paint as before. PC keeps 💎 in the dock.
    - On every device, both shop doors (the 💎 button and the Fair Street counter prompt) are hidden in line, while racing, on the results card, for D-050's 2 minutes after a race, and during training rides. No countdown or "back soon" text appears.
    - On touch nothing tappable sits in the thumbstick zone (left 40% × bottom ⅔ of the screen). The cash and horse cards there are display-only, and My Horses opens from a 🐴 button in the dock's button group, outside the zone.
  - **Cheering:**
    - CLAP sits at **(1,−170,1,−230)** on every device, one column left of Gallop and Hop: 170×90 on foot, 120×70 while riding.
    - The cheer bar becomes a silent strip at the top centre under the status line: 56 px tall, chips at least 48 px wide.
    - It shows only inside D-055's spectator range and never during the busy rule.
    - After a cheer it shrinks to one 40 px line, "📣 Your horse: 3 · Comet", in the same spot.
    - It is never shown mid-screen.
  - **Stall while the horse is out:**
    - The stall is empty with a plaque on the door: "🐴 Comet is out riding" (free riding and training rides) or "🏁 Comet is at the races". Visitors see the same.
    - Care prompts at the empty stall are hidden.
    - The horse is back the moment you get off or its race ends.
  - **Training props stay soft** (constrains QA fixes riding #4 and #12):
    - Log jumps never collide with a horse. A hop over one while airborne shows a "Clean hop!" sparkle, which is what D-053 scores.
    - Cones and poles go in a `CourseProps` collision group that the new shins collider ignores, and they wobble when touched.
    - A horse never stops at a prop (D-053: no refusals).
    - The Trail bridge is still sunk to ground level as QA proposed.
  - **Gamepad gallop:** R2 (hold), as in D-053, with L3 kept. Not ButtonX, because X is the Roblox ProximityPrompt key used by the care prompts. Shift stays the PC gallop and must not toggle Shift Lock while riding.
  - **Taming:**
    - The client shows "Getting to know you…" with a filling heart until the server answers.
    - Then it shows "💖 Friends!" or **"Not yet, try again!"**. Not "So close": that is near-miss wording.
  - **Ride or Map while still seated after a race:** a "Tap Done first" notice instead of nothing.
  - **Bug fixes that came with it (QA riding audit):** taming checks where the horse stood when the game began (it silently failed about half the time); a 1–2.5-stud "shins" collider stops the ride horse at troughs, beds and the fountain (it ignores CourseProps); getting off puts you where the horse stood; calling the horse checks for room (four headings) or says "Find an open spot"; your own horse's name tag is hidden from you; Shift gallop sits above Shift Lock while riding; the Trail bridge is sunk to the ground; the Race Board fits its frame; touch layout follows the last input (`Ui.touchLayout()`).
  - **Config:**
    - `GameConfig.riding.hopButton = true`;
    - `HorseLegs.GAITS` and `HorseLegs.WALK_BELOW = 12`;
    - `GameConfig.riding.bobAmp = 0.15`;
    - `GameConfig.touchLayout.gemPlacement = "topRight"` ("dock" = D-050 layout) and `movementColumn = 176`;
    - `GameConfig.fans.clapOffset`, `clapSizeOnFoot`, `clapSizeRiding`;
    - `GameConfig.fans.cheerStripTop = true`;
    - `GameConfig.stable.awaySign = true`.
- Why:
  - On phones the controls must sit where Roblox kids' thumbs already go, and steering must never open a store.
  - A horse should move like a horse at the speed it actually goes.
  - An empty stall must never look like the horse ran away (hard rule 3).
  - A training prop must never stop a horse (D-053).
- Alternatives:
  - re-enable Roblox's jump button (jumping from a seat dismounts);
  - QA's walk {5, 24°} at riding speed (3.2 Hz legs);
  - keep the walk and only shorten the stride (cadence or slip, one has to give);
  - 💎 left in the dock with a smaller hit area (still in the thumbstick zone);
  - remove the touch 💎 button entirely (Tack & Paint counter only; harder to find what you own);
  - CLAP shrunk to 100×60 while riding (Child safety; a rhythm target needs size);
  - the stall horse hidden with no sign (reads as a missing horse);
  - solid log jumps (QA; a missed hop becomes a refusal);
  - auto-hop over logs (Engagement; hides whether you hopped);
  - gallop on ButtonX (QA; clashes with prompts);
  - "So close, try again!" (Young player; near-miss framing).
- Links:
  - docs/debates/011-playtest-quirks.md
  - game/src/client/RideClient.client.luau
  - game/src/client/Hud.client.luau
  - game/src/client/StyleShop.client.luau
  - game/src/client/FanClient.client.luau
  - game/src/shared/HorseLegs.luau
  - game/src/server/Rides.luau
  - game/src/server/StableService.server.luau
  - game/src/server/WorldScene.luau
  - game/src/shared/ModelSpecs.luau
  - game/src/client/WildHorses.client.luau
  - game/src/server/MarketService.server.luau
