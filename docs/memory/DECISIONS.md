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
  - **Ghosts per player per course,** not per horse: course physics is the same for every horse (equal physics above), so your best ride is a fair ghost whatever you rode, and there are only a few to keep. The ghost shows the coat it was ridden on. Best = more score, then a quicker time. Only unflagged rides become ghosts. **Sprint Lane and Mud Splash only** (after review): a Gate Break ghost would bolt at another ride's bell, and a Hill Climb ghost followed another Pip, so those two have none.
  - **Ghost storage:** its own DataStore (`GiddyUp_Ghosts_v1`, key `ghosts_<userId>`), loaded the first time a ride needs it (3 tries), saved on leaving, every 2 minutes if changed and at shutdown. A save merges with what's stored (`Ghost.mergeStore`): a stored run is replaced only if this version can read it and the new one is better; newer encodings, courses and keys pass through untouched, so a rolling update or T5 never erases anything. A new best during a save keeps the entry dirty (an edits counter, like Profiles). Encoding: 4 Hz, 0.5-stud, ≤ 480 points (120 s, a whole ride), deltas as base64url varints (about 5 characters a point, under 2.5 KB a ghost).
  - **Friends' ghosts** show only in a solo ride, only from friends in the same server who turned on "Share my ghost with friends" (off by default) and don't have stable visits set to Nobody, at most two; their ghosts load only when they share.
  - **Ride together** is two riders (you and one friend) for now. Friendship comes from a cache filled when players join (`IsFriendsWith`, pcall). The stable visits setting doubles as the friends privacy switch: "Nobody" on either side means no invites, and a friend whose stable hasn't loaded can't be invited. Invites are accept-only, lapse after 20 s with no countdown shown, one pending either way, 8 s apart, at most 5 sent and 3 received in five minutes, and after "Not now" the same friend can't be asked again for a minute. A friend in a shop or game panel (or riding, racing) answers "busy" automatically, with no cooldown. The card sits top right (away from the thumbstick), scales to the screen, ignores taps in its first half second, and carries only the inviter's Roblox display name and a course. The group shares one countdown (2.5 s longer, for horses being called) and one Pip (one seed for both); each rider has their own bells and is scored alone. Riders start side by side, except Gate Break where both share the stall (they pass through each other) and each sees the other fade while waiting in the stall, so a friend's go at their own bell never looks like theirs. The end card shows the friend's stars and ribbon only, tagged with the group, so it never lands on a later solo card; a friend who stops, leaves or hits an error shows as resting.
  - **Rosettes** sit under the horse's name plate on its stall, one per course with a gold ribbon (the uploaded rosette_ribbon, or a part rosette).
  - **Quick train on the server:** the games are pure functions of a server seed and tap times (QuickTrain), so the screen and the server agree; taps are resolved with TapTime.resolve and the race's one-way allowance (the client claims the exact moment its preview used). Small changes so the server can know when a game ends: a Sprint Lane round with no tap passes after 6 s (scores 0, with a "Next one!" cue), a Gate Break light with no tap 4 s after green scores 0 like going early, Mud Splash's puddle spacing varies a little (0.7–0.8 s) with the seed and Hill Climb's band with it; a Mud Splash tap with no puddle near costs 15 points, so mashing doesn't pay. A game whose card is closed (or when a race starts) ends with no gain and doesn't count as a session; a game with no tap that counted gains nothing; nothing toasts during a race; a course ride and a Quick train game never overlap. The reaction time and the hold game's countdown are no longer shown (no timers on screen).
- Implementation notes (T5 "This week's course", 2026-10-05, provisional, roblox-engineer):
  - **Four Mud Splash layouts, one a week:** `TrainingCourses.weekCourse(now)` is layout `Training.week(now) % 4 + 1` (weeks start Monday 00:00 UTC, like the training cap; the week of 2026-10-05 is layout 3). Every layout starts at the same line, rides the same six lanes and has 4 puddles, 3 logs and 4 poles worth 100; they differ in the canter lane (4, 2, 5, 3), where the puddles and logs sit and where the finish arch stands. Ideal times 36.9–37.4 s. Layout 1 is the T2 Mud Splash. Every layout passes the T1 checks plus new ones: no overlaps (pieces, start line, finish arch), 8 studs to ride between pieces in a lane, nothing within 18 studs of a turn, pieces in riding order, a perfect ride scores 100 and finishes. `GameConfig.training.grit.layoutPin` (0 = by the week, 1–4 = always that one) is for playtests, or 1 to switch the weekly course off. Alternatives: a new layout each day (that feels like a timer); layouts of different lengths (ideal times and par drift).
  - **A course key per layout** (`grit_w1`..`grit_w4`), not a layout field: ribbons, best runs and ghosts are flat maps keyed by course, so each layout reuses them unchanged (Profile, `TrainingRide.record`, Ghosts and the ghost store's merge). The picker and the picture signs still say `grit` (the stat); the server resolves it. Alternative: `ribbons.grit = { [layout] = ribbon }` (changes the shape every reader expects; an older server would find a table where a string was).
  - **Migration (corrected after review):** T2–T4 saved Mud Splash as `grit`, which is layout 1, so `grit` and `grit_w1` name the same course: a profile load gives both keys the better ribbon and the better run of the two, and keeps `grit`, so a T2–T4 server still shows the layout-1 ribbon. The ghost store isn't rewritten: a stored `grit` ghost loads as `grit_w1` (`Ghost.loadRuns`), and `Ghost.mergeStore` still passes old and unknown keys through.
  - **Profile repair keeps courses it doesn't know (after review):** a rolling update must never erase a newer build's ribbons (a `grit_w5` gold was lost after one load before). Any other ribbon or best-run entry with a string key of up to 32 characters and a valid value passes through, at most 16 per map (alphabetical first); bad values, number keys and empty or over-long keys are dropped. Repairing twice gives the same as once. T2–T4 servers already live still drop unknown keys, so if one is live when T5 ships, publish with Shut Down All Servers or Migrate to latest update (game/PLAYTEST.md, Setup).
  - **Tests and the off switch:** the rotation tests set `layoutPin` to 0 and put the shipped value back, so shipping `layoutPin = 1` (weekly course off) keeps the suite green.
  - **The server's week:** the layout comes from the server's `os.time()` when a ride (or a Ride together pair) starts, whatever the client asked for (`TrainingCourses.resolve`), and the ride keeps it to the end, so a server running across Monday 00:00 switches between rides, never mid-ride. ReplicatedStorage's `WeeklyCourse` attribute names the week's layout for clients.
  - **Props on each screen:** the server builds all four layouts into `ReplicatedStorage.Gymkhanas`; each client copies the week's into the arena (`GymkhanaView`) and rebuilds it when the week changes, except during its own Mud Splash ride, which keeps the ride's layout until it ends. Props never collide, so copies per screen are safe; just after Monday 00:00 a rider still on last week's layout and someone watching may see different props for a minute. Alternative: one set built by the server and switched when nobody is riding (a busy arena could stop it ever switching, and someone would still be mid-ride).
  - **Rosettes:** one Mud Splash rosette for a gold on any layout (`Profile.rosettes`), the simpler choice: at most four rosettes and a tidy stall. Alternative: a rosette per layout (up to seven).
  - **Picker:** the Mud Splash tile says "This week's course" with four small ribbon icons, one per layout (the ribbon on it, or a faint empty one), this week's ringed in orange. No dates, timers or "last chance"; a layout's ribbons can be earned whenever it comes back. Quick train is unchanged (it's keyed by stat).
- Links: docs/debates/009-training-rides.md, game/src/shared/TrainingCourses.luau, game/src/shared/TrainingRide.luau, game/src/server/TrainingService.server.luau, game/src/client/TrainingRideClient.client.luau, game/src/client/GymkhanaView.luau, game/src/shared/WorldLayout.luau, game/src/server/WorldScene.luau

## D-054 — Race steering

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 010 (4/4 after one rebuttal round; drafting 3–1, Young player wanted ground only); David asked for steering "constrained to look realistic where they can affect the outcome slightly".
- Decision:
  - **When:** riders change lanes from the gate to the far-turn entry. Three soft bell ticks, then "Lanes locked!"; after that lanes are cosmetic, and the stretch is the slider and the Final Burst only.
  - **How a lane change works:**
    - One press moves one lane, with a 0.6 s glide that starts instantly on the rider's screen; at most one change per 0.6 s, one queued.
    - **Tuck-in:** a horse alongside blocking a move toward the rail makes yours ease back (up to 3 lengths, `tuckBackMax` 24 ft; ~1.5 before the S0 calibration) and slot in behind it. This is visual only.
    - A blocked move outward cancels after 1 s.
    - Horses never overlap or bump; the mover gives way; a horse held behind another is drawn there. A lane change needs 1 length clear ahead (`clearFeet`) and `holdGap` (10 ft) clear behind in the new lane, so the mover never pushes the horse behind it.
  - **The trip:**
    - Ground: 0.010 per lane off the rail per 180° of turn (0.012 before the S0 calibration). Earlier turns count live; the far turn is booked from the lane held at the bell.
    - Tucked in: 0.0010 per second (0.0012 before the S0 calibration) while 0.5–3 lengths behind a horse in the same lane, before the lock only, capped at 0.016.
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
    - Bots use Smart Steer with variety (4–12 s lead before turns; 25% ride the rail, 20% ride one lane wider, added in S0) drawn after all existing random draws.
    - Posts are drawn at random by the server (no longer humans first), never shown as a draw, and corrected by the per-post baseline.
  - **Feedback:** "Saved ground!" at turn exits, "Tucked in!" with wind lines, a gentle tip when wide into a turn (never "lost a place"), and "Good trip ★★☆" on the results (★★★ at τ ≥ +0.015, ★★ at ≥ −0.005, otherwise ★, never zero). "Your trip gained you N places!" appears only when positive.
  - **Replays** record each horse's lane per frame on this screen and add your line as a ribbon with green chevrons, wind lines and the lock marker; no ideal-line ghost.
  - **Python:** `live_chances(..., extra)` and `src/trip.py` mirror `Trip.luau` exactly (D-012).
- Tuning: in the moderator's prototype a skilled steerer gains +0.011 to +0.023 over Smart Steer, a rider who never steers with Smart Steer off loses 0.014–0.016, and the post baseline cuts post bias from up to ±0.02 to at most 0.003. Without tuck-in most lane changes were refused. All values are in `GameConfig.steering`, and the post baselines are generated into `TripBaseline.luau` by `sims/steering.py`.
- Calibration (S0, 2026-10-05, model engineer, revised after the PR #37 review): every acceptance target now passes in every course × distance cell (docs/research/steering-calibration.md).
  - **Ground 0.010** per lane per 180° (was 0.012): at 0.012 a rail rider beat Smart Steer by +0.030 in Marathons (three turns count); now +0.017 to +0.026.
  - **Draft 0.0010 per second** (was 0.0012): the Sprints were at 40% draft share of the positive trip; now 35% or less in every cell.
  - **Tuck-in up to 3 lengths** (`tuckBackMax` 24 ft, was ~1.5). The horse eases back to the slot behind the whole group alongside, or waits for room if that slot is further back.
    - With the race view's 10 ft/s gap limit (D-055), which Trip now copies before the lock, 1.5 lengths left the Miles at 60–74% of inward presses reaching their lane within 3 s. Now 81–98% in every cell.
  - **The mover never pushes the horse behind:** a lane change needs 1 length clear ahead and 10 ft (`holdGap`) behind in the new lane.
  - **`bots.wideShare = 0.20`** (new): 20% of bots ride one lane wider than Smart Steer, alongside the 25% on the rail. With rail riders only, the average bot out-steered Smart Steer, and a Smart Steer kid among bots averaged τ = −0.007 (dirt Marathon). Now −0.0009 to +0.0003.
  - **The per-post baseline is built for Smart Steer kids:** half from a kid at each post among bots, half from all-Smart lobbies, calibrated on clamped τ.
    - The first baseline came from all-bot fields and left a kid at post 2 up to 0.009 below the field: it leads the lane-2 line without drafting, while a quarter of bots there take the rail.
    - Post bias is now at most 0.0018 for a kid among bots and 0.0020 in all-Smart lobbies. Bot fields keep up to +0.007 at post 2, which pays nobody.
  - **Trade-off (provisional):** drafting favours the horses behind a line. In bot fields, the on-screen leader after checkpoint 1 averages τ −0.002 to +0.002 and the last horse +0.001 to +0.005, about 0.3 points of S at most. By tapping alone the gap is under 0.001.
    - Reversible: `draftPerSecond = 0` makes the trip ground only.
    - Proposed, not built: a draft baseline by running position.
- S1 (2026-10-05, PR #41): posts are drawn after the session is built, not right after `fillWithBots` as the plan said.
  - RaceService draws them from the race's generator after the slider's passes; `RaceSession:assignPosts` then renumbers the lanes by post, carrying every per-horse value with its horse.
  - This keeps the earlier draws (bots, luck, bot scores, passes) in order. Only the Final Burst's start, drawn when the burst opens, moves to a later draw: harmless with an unseeded, uniform start shared by every lane.
  - `GameConfig.steering.drawPosts = false` keeps the old humans-first lanes.
- S2 (2026-10-05): the trip runs on the server, with Smart Steer for everyone (bots with their variety, riders with plain Smart Steer until S3's controls). **S2 ships cosmetic: `GameConfig.steering.scale = 0`** (tech lead). Riders can't steer yet, so their τ shouldn't move with bot variety they can't affect; S3 sets it to 1 when the buttons go live (done, below). Build calls:
  - **Trip on the server:** `Trip.luau` mirrors `src/trip.py`, agreeing with all 200 `trip.json` runs to 1e-9 (answers exactly).
    - Lune's JSON reader can land a number one ulp off, and two horses exactly `holdGap` apart turn that into a different race. So the fixture carries the inputs as exact decimal strings, and the test takes config values from `GameConfig`.
    - Trip is built after the posts draw (lane = post) and draws its two uniforms per lane after every other gate draw.
    - `RaceSession` declares its tables (`PER_LANE`, `PER_SEGMENT_LANE`, `NOT_PER_LANE`); `assignPosts` moves the per-lane ones, `tau` included, and a test fails on any unclassified table.
  - **On screen:** with steering on, the server sends what to show for the whole race, at 10 Hz: `RaceOffsets (offsets, [lanes,] course)`, course last.
    - The screen interpolates the 10 Hz samples instead of easing them again, so held gaps stay at 10 ft (review S1). Lanes glide linearly at the race's lane speed (S3). Clients skip their 30% gap ramp, because Trip's gaps already grow in over 8 s.
    - Lanes go out rounded to 0.01 lane, and only when they change (plus once a second).
    - Up to the lock, the offsets and lanes are Trip's.
    - After the lock, the offsets are the race shape's targets as the screen would ease them. The server keeps that eased copy, carried on from Trip's offsets at the lock, and holds horses so none runs through another.
    - **Make-room lanes after the lock** (`Trip.cosmetic`, Luau only, never touching τ) work on that shown copy. A horse closing on one ahead in its lane, or about to pass it, glides to the nearest free lane it can reach across clear lanes (outward first). Boxed in, a horse in its way moves over instead, cascading up to three horses deep.
    - **Why holds were needed:** at the lock Smart Steer has packed the field into lanes 1 and 2, and the race shape reorders it within a second. Lane changes alone left horses running through each other in about 96% of races (review B1, reproduced).
    - **Hold release:** holds let go 1 s before the line so the order across the line is the result. Releasing at 0.5 s left one race in 960 wrong.
    - **Measured** (`tests/luau/overlap_report.luau` and the 64-race test in `trip_tests`): no horse within half a lane and 6 ft of another in 960 + 1,200 races (scale 0 and 1), and the order across the line was the result in every one.
    - `GameConfig.raceView.easePerSecond` (2.5) names the view's easing rate, which was a literal, so Trip and the view share it.
  - **Loops:** a race that errors is marked aborted, and its offsets and trip loop stop (no lock or remotes for a dead race; this also fixes the old offsets loop running on until the next race).
  - **The lock:**
    - `TripInfo` (on, lock time) goes out at the start and `TripLocked` at the bell.
    - The live chances shown refresh at once with τ: a `LiveChances` resend with the closed checkpoint, never 0. When the lock comes before checkpoint 1, as it can in a Sprint, the checkpoint carries it.
    - Clients note `TripLocked`; the bell sound and "Lanes locked!" come with the controls in S3.
    - Catch-up ticks use the live chances of the moment. Around checkpoint 1, a tick or two may use the new chances early or late. That is fair: the chances are shared, only the gaps' timing moves, and τ is measured against the same field.
    - `setTrip` clamps τ again and refreshes the live chances from the checkpoints closed so far. An all-zero τ (scale 0) changes nothing, bit for bit.
    - `ridingGain` keeps your trip; `tripGain` removes only your trip.
  - **RideReport** carries trip stars and trip places gained before the course id; the results line comes in S4.
  - **Steering off:** `steering.enabled = false` sends exactly today's remotes (no `TripInfo`, offsets without lanes, the old `RideReport`) and draws nothing extra.
- S3 (2026-10-05): the rider controls. **`GameConfig.steering.scale = 1`**: steering counts now that riders can steer. Build calls:
  - **Requests:** `SteerRequest(dir, seq)` goes through `Trip.submit`, which checks it as it arrives: the player rides in this race (never a bot's lane), it's before the lock, dir is −1 or 1, seq rises, the race has started (a press during the countdown is refused), and the rider sent fewer than `requestsPerSecond` (8, game only) in the last second; spam is dropped. The next 10 Hz tick applies waiting requests in arrival order through `Trip.step`, where `Trip.acceptIntent` (the Python mirror, unchanged) checks the request gap, the queue and the track's edges. Requests still waiting at the lock are dropped.
  - **Who has the buttons** (`Trip.riderControls`, pure and tested): a rider's first `introRaces` races (3) have no buttons, counted from `totals.races` (races that count, not Practice) when the race starts; a missing profile counts as a first race. The server ignores requests from riders without buttons.
    - In those races everyone has Smart Steer, even with it turned off in Settings, so no kid without buttons is left at their post (a rider who never steers with Smart Steer off loses 0.01–0.02).
    - **Their τ is 0** (tech lead, S3 review): they can't affect their trip, so it neither helps nor costs them. It is zeroed after the clamp; the field mean still counts them, and bots and riders with buttons keep their τ.
    - The ghost-thumb tip ("Steer to the rail before the turn ◀") shows once, on the first race with buttons (`flags.steerTip`).
  - **Smart Steer:** any press pauses it for 5 s; it then resumes and never moves the rider outward (Trip as in S0). `settings.smartSteer` (on by default, boolean only) turns it off for riders with buttons; their lanes then change only when they press. A rider who leaves goes to Smart Steer.
  - **Controls:** ◀ In / Out ▶ bottom-left at 75% of the screen height, above the speed meter and the thumbstick zone, 88 px on phones and 104 px × the HUD scale elsewhere, over the tap area. On a narrow screen the tap words move right of the buttons while they're up. Keys A/← and D/→, the D-pad and a left-stick flick (fires past 0.6, re-arms under 0.3) come from `RaceInput`, a pure table checked against `GameConfig.tapKeys`. While you have the buttons, the steering keys are bound through ContextActionService above the camera's priority and sunk, so the arrows steer instead of turning the default camera. The buttons sit inside the device's safe area (clear of a notch). The move controls are off while racing, so A/D don't walk and the touch thumbstick and jump button leave the screen; a respawn brings them back, and taking your seat re-applies it.
  - **Your own glide** (`SteerPredict`, pure, shared by RaceView and the overlap simulation; reworked after the S3 review's B1, where the first version could stick in a lane the server never took):
    - The server tells each rider with buttons about their own lane, on change (`SteerLane`): the lane taken (`tgt`), where it ends once waiting presses are done (`Trip.laneAfter`), and the last press answered (`ack`; spam and countdown refusals are answered too).
    - A press draws one lane, and only from a resting server lane that has answered every earlier press, into a lane with room by the server's lanes (checked every frame). That is the move the server makes on its next tick. A press the server would queue (gliding, waiting for room, a press queued or unanswered) draws nothing.
    - It goes at most 0.45 lane over until the server answers, so a refused move never comes within half a lane of a horse the server let into that lane meanwhile; on a usual connection the answer comes first.
    - The answer ends it, and your horse follows the lane the server took. A fallback ends it if the server's lane stops coming closer for 1.5 s. After the lock your horse follows the lanes everyone sees.
  - **The lock:** three soft bell ticks a second apart before it (`lock_tick`, new in the sound list and silent until uploaded), then "Lanes locked!"; the buttons grey and fade 2.5 s later, before the Final Burst. Only riders with buttons get the bell and the words. Nothing shakes or counts down.
  - **Chips** (client, from what the screen shows, riders with buttons only):
    - "Saved ground!" leaving a turn ridden on the rail (mean lane under 1.5) or at least a quarter lane inside the field's mean, as τ is measured against the field; only once you have pressed a steering control that race (Smart Steer's own moves don't earn it).
    - "Tucked in!" after 1 s in the draft credit's zone (4–24 ft behind a horse in your lane), not again within 10 s, at most 3 a race and none once the credit is full (`draftCap`), with wind lines from 0.3 s.
    - "The rail is shorter on turns ◀" (debate 010's words) when you steer yourself (Smart Steer off or paused) and are one lane or more outside its home lane within its turn lead of a turn, the far turn included; at most twice a race.
  - **Logs:** one `[Trip]` line per race at the lock: riders' posts, Smart Steer or not, τ, and how their presses were answered.
  - **Measured** (`tests/luau/overlap_report.luau`, riders pressing at random through `Trip.submit`): 960 races with 2 riders on Smart Steer (48,387 presses accepted, 8,985 queued) and 960 with 3 riders on Smart Steer off (74,530 accepted, 14,447 queued) gave no horse within half a lane and 6 ft of another, and the order across the line was the result in every race.
    - **The rider's own screen** (`overlap_report ... predict`: rider 1 presses from its screen, singles, doubles, mashes and In-then-Out pairs, over a link of 0.1 s each way, drawn by `SteerPredict`): with 2 riders, 70,307 presses in 960 races, its horse never overlapped another on its own screen, every prediction was answered within 0.28 s and none timed out, and it was back with the shared view at the lock. With 3 riders on Smart Steer off, the same, again 0 overlaps on the rider's screen. At 0.25 s each way: 0 overlaps, predictions answered within 0.58 s.
    - In the 3-riders-off run, one race in 960 showed two horses 5 ft apart nose to tail in lane 1 for the last 0.3 s before the line (18 frames), after the holds let go: S2's release window, where the race shape's finishing gap between them was under 6 ft and no lane was free to move out. Not the controls; fixed in S4 (the half-lane step).
  - Alternatives: count Practice races towards the three (a Practice-only kid would meet the buttons sooner; kept to races that count, like `totals.races`); apply the Smart Steer setting in the first three races too (strands kids who turned it off with no buttons); chips for every rider (more to read in the first races, which the plan keeps simple); chips from the server (another remote for words the screen can work out).
- S4 (2026-10-05): replays, results and docs. The D-054 build is complete. Build calls:
  - **Results:** "Good trip ★★☆" under "You rode ★★☆" (stars from `GameConfig.steering.stars` via `Trip.stars`, one to three, never none). "Your trip gained you N places!" shows in the card's foot only when it's a gain, under "Your riding gained you N places!" when that's a gain too. The card grows a row per gain line. The wording lives in `ResultsText` (pure, tested).
  - **Riders in their first 3 races see no trip line** (the simpler choice over a one-time "Steering arrives after 3 races" hint). Their τ is 0 and they had no buttons, so "Good trip ★★☆" would be about Smart Steer, not them. The server leaves the trip fields out of their `RideReport`.
  - **Replay** (`ReplayTrip`, pure, tested; recordings from before steering are safe):
    - Horses run in the lanes recorded on this screen.
    - A rider who had the buttons gets their line on the track up to the lock, as flat strips just above the dirt, shown as their horse passes them. It's gold, and green with chevrons through turns where they saw "Saved ground!".
    - Wind lines show over their tucked-in spans, and "Lanes locked!" shows as they pass the lock.
    - Every steering race gets a bar across the track at the lock, with a "🔔 Lanes lock" sign.
    - No ideal-line ghost.
    - The race records the lock time and event (RaceView), plus saved turns, tucked-in spans and whether you had the buttons (RaceController); your presses were already recorded.
  - **The half-lane step** (S3 follow-up): in the last moments, when holds let go so the order across the line is the result, a horse still boxed in behind another in its lane (no free lane, nothing able to make way) edges half a lane over if nobody near is within half a lane of the spot.
    - It starts `laneSeconds` before the holds let go, so the step is done by then.
    - Lanes, not targets: the step never changes where a horse finishes. Its shown offset does change a little: once it is half a lane over, the hold behind the horse ahead lets it go, a moment before the holds let everyone go, so it reaches its place slightly sooner (under a foot apart on the way in the test case, 0.08 ft at the line). The order across the line is the same with the step on or off.
    - **No backward jerks** (S4 review). The first version started the step while holds still applied; a horse at x = 1.5 counted as in both lanes, so the hold pulled it or its new neighbour back 7–8 ft in a tick (70–80 ft/s). Now:
      - a horse taking a half-lane step isn't held against a horse more than 0.45 lanes from it;
      - a hold never pulls a horse back faster than 19 ft/s on screen. A steady hold needs at most twice the 10 ft/s gap limit, so only sudden snaps are spread over a few frames.
    - **Make-room after the lock, tightened** (the S4 review's backward-speed check found S2 snaps of 24–88 ft/s in a few races in a hundred):
      - a horse gliding across a lane counts as in it, so nobody moves onto its path;
      - a move needs `holdGap` (10 ft) clear ahead and behind in the new lane, not `clearFeet` (8 ft);
      - a move never goes in front of a horse that is catching up with you.
    - Measured over 960 races each for all bots, 2 riders, 3 riders on Smart Steer off, and the rider's-own-screen runs at 0.1 s and 0.25 s (`overlap_report`): no overlaps anywhere, the order across the line right in every race, and no horse drawn falling back faster than 20 ft/s after the lock. The step happened in 10 to 13 races per 960.
    - Before the lock, Trip's own holds still hopped a horse arriving in a lane back by up to 30 ft/s in bot fields and about 50 ft/s with riders pressing, for one tick. Fixed in the follow-up below.
    - Alternatives: release the holds earlier (S2: at 0.5 s one race in 960 crossed in the wrong order, and an earlier release doesn't separate two horses whose finishing gap is under a length), keep holding non-passing pairs (shifts a horse off its place, which can reorder it against another lane's horse), or a minimum finishing gap in the race shape (changes every finish to fix one in hundreds).
- Pre-lock hop fix (2026-10-05, after S4):
  - **The cause:** before the lock a lane change needs `clearFeet` (8 ft) ahead, but a hold keeps `holdGap` (10 ft). A horse arriving 8–10 ft behind another, or catching up during its glide, was snapped back to 10 ft in one tick.
  - **The fix:** `src/trip.py` and `Trip.luau` now settle a held horse back no faster than `holdPullPerSecond` (19 ft/s, new in `trip.CONFIG` and `GameConfig.steering`), counted from where it was at the start of the tick. The view after the lock reads the same value.
    - Following a horse never needs more (a follower moves back with the horse ahead, at most 10 ft/s), so steady holds are exact as before. Only a fresh arrival is spread over a few ticks.
    - Lane decisions are unchanged. I picked this over "require the full 10 ft ahead", which would change which moves are allowed and still miss a horse catching up mid-glide.
  - **Parity and regeneration:** `TripBaseline.luau`, `trip_baseline.json`, `steering_report.json` and the parity fixtures were regenerated; Python and Luau agree on all 200 scripted runs.
  - **Calibration:** every target still passes in every course × distance, and the numbers moved by at most 0.0001.
    - Rail rider vs Smart Steer: +0.016 to +0.026.
    - Never-steer: −0.015 to −0.013.
    - Within 3 s: 81–98% per cell (90.4% overall).
    - Draft share: 20–35%.
    - Post bias: at most 0.0017 for a kid among bots and 0.0020 for all-Smart fields.
    - Smart Steer kid mean: −0.0009 to +0.0003.
    - Details in docs/research/steering-calibration.md.
  - **Spacing:** horses within half a lane stay at least 8.8 ft apart (400 random-press races), and a close arrival is back at 10 ft within 5 ticks.
  - **On screen** (`overlap_report`, 960 races per row: all bots, 2 riders, 3 riders on Smart Steer off, and the rider's own screen at 0.1 s and 0.25 s):
    - 0 overlaps on any screen;
    - no horse falls back faster than 20 ft/s before or after the lock (19.0 ft/s at most on either side; it was 30–52 ft/s before the lock);
    - the order across the line is right in every race.
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

## D-057 — Natural steering, boxed in and brushes

- Date: 2026-10-05
- Status: Accepted (provisional). Built N1–N6 (2026-10-06); not yet played in Studio (see "Built" below)
- Decided by: team, debate 012. All four agreed after one rebuttal round on the motion rules, boxed in and the brush rule. The glide time split 2–2 (moderator chose 1.0 s), and so did the body-turn gain; the brush cap split 3–1. David asked for steering that "looks natural, sort of like a real horse moving", no zig-zag, horses that are "boxed in" when surrounded, and the team to consider bumping that slows the bumper "a little".
- Decision:
  - **Natural motion (the same for players, Smart Steer and bots; Trip runs it on the server):**
    - **The glide is an S-curve.** Sideways speed builds up at 4.5 lanes/s² (27 ft/s²), caps at 1.5 lanes/s (9 ft/s, a 9° drift at 56 ft/s), and brakes at the same rate. One lane takes 1.0 s from press to arrival (about 2.3 strides). D-054's glide was linear: 0.6 s at 10 ft/s, starting, stopping and reversing instantly.
    - **Chaining:** a second press the same way continues the glide without stopping (from 0.3 lane before arrival). Two lanes take 1.6 s, three 2.3 s, four 3.0 s. One press can wait; an opposite press cancels a waiting one (as D-054).
    - **Commitment:** a glide always finishes.
    - **Reverse gap:** a change the other way starts at least 0.5 s after landing.
    - **Weave gap:** a second reversal within 7 s of the last one waits 2.5 s after landing (5 s in debate 012; 7 s since the N1 review brought every masher cell under 8 reversals a minute).
    - **Bounce:** presses within 0.2 s count once.
    - **Glide reserve:** a horse gliding into a lane keeps 6 ft more room ahead and behind (clearance 14 ft ahead and 16 ft behind it).
    - **The make-room lanes after the lock** (`Trip.cosmetic`) glide on the same curve.
    - **The body:**
      - It turns with its true drift (atan of sideways over forward speed: ≤ 9°, capped at 10°), smoothed over 0.15 s.
      - It leans into the move by at most 3°.
      - On your own press it "looks" first: a 3° turn toward the press at once, held until the slide starts, or relaxed over 0.3 s if the press waits. This stands in for a head turn; the split models have no separate head.
      - Legs keep striding by distance moved (D-051).
      - The chase camera follows the track, not the body turn.
    - **Latency:** the slide starts with the server's lane. The S-curve covers 0.05 lane in its first 0.15 s, so a round trip hides inside the ease-in. SteerPredict no longer draws your sideways move ahead of the server, so a refused press never snaps back. The look cue is the instant answer.
  - **Boxed in:**
    - **No room on a side:** the rail or the outer edge, or a horse in that lane's clear zone (8 ft ahead to 10 ft behind, plus the reserve if it is gliding in). This is Trip's existing clearance rule.
    - **Boxed in:** no room on either side and a horse within 12 ft ahead in your lane.
    - **The arrows:**
      - **Out ▶ greys** (with a small horse icon) while that side has no room.
      - **◀ In greys only when trapped:** no room inside and no slot within the 3-length tuck reach (about 1% of race time). Most blocked inward presses are solved by tuck-back, and a grey button that works teaches kids not to press it.
      - Grey arrows still take presses. No buzz, no red.
    - **Presses:**
      - Inward with room: it glides.
      - Inward without room: the horse steadies back (tuck-back: automatic, at once, up to 3 lengths, visual only, as D-054) and slips in behind ("Tucked in!" as today).
      - Inward and trapped: the press keeps waiting for a gap or a tuck slot (as D-054; a press Out cancels it). Dropping it after 3 s cut casual reach in the dirt Miles from 69% to 54%.
      - Outward without room: it waits up to 1.5 s, then drops with a soft 0.2 s wobble of the arrow and no sound (D-054's promised shake; none under Reduced Motion).
      - A waiting press shows a ring on its arrow: lit while an inward press waits, filling over 1.5 s for an outward one.
    - **Chips** (riders with buttons only; at most one steering chip every 2 s):
      - "No room yet" after a press has waited 1 s with no glide and no tuck-back; at most once per 10 s.
      - "Gap!" (with `tap_good`) when a press that waited at least 0.5 s fires.
    - **No boxed-in cost** (unchanged from D-054). Being boxed costs only its natural cost: you can't reach the rail until you steady back.
  - **Brushes (rule-based contact in Trip; no collision bodies, no Roblox physics):**
    - **When:** a second press (the third since the N5 review: `brushPresses = 3`) toward a horse alongside (within 8 ft lengthwise in the next lane, alongside for at least 0.3 s), within 2 s of the first press, while the first press still waits and no tuck-back is possible. A first press never brushes, and a re-press many seconds later is a new try.
    - **What happens:**
      - The mover leans at most 1 ft toward the other horse over 0.4 s and nods.
      - It steadies back 4 ft (in Trip's offsets, recovering at 2 ft/s) and can't steer for 1 s. Its waiting press clears.
      - The other horse nods only: no slowdown, no chip, no name shown.
      - Both keep striding: no stumble, pinned ears or squeal.
      - Sound: `count_tick` at half volume.
    - **The mover pays, only the mover:** 0.002 τ per brush after the first free one, at most 3 charged (0.006, 0.3 points of S), and at most 4 brushes a race (after that presses just wait).
    - **Formula:** τ_i = clamp(scale × (trip_i − postBaseline − field mean − brushCost × charged_i), floor, ceiling). The brush term comes after the field mean (a brush never raises or lowers anyone else), sits inside the clamp, and is fixed at the lock. It never depends on luck.
    - Smart Steer and bots never brush. Nobody brushes after the lock.
  - **Server authority:** the server owns lanes, the no-room state, brushes and costs. The client's grey arrows and rings come from the 10 Hz lanes and the rider's own `SteerLane` state, as advice.
  - **Targets** (sims, every course × distance): see Tuning.
- Why:
  - **Natural motion.** A real horse changes paths over strides, not frames, and racing rules punish crossing "when insufficiently clear" (ARCI-010-035, AR 131(a)). Sideways acceleration falls from 100–200 ft/s² at 10 Hz (instant starts and reversals) to at most 30. A masher reverses 7 times a minute with at least 3.5 s between reversals, instead of 29 a minute every 0.6 s. Casual riders are untouched (1.3 reversals a minute either way).
  - **Boxed in.** David's "can't move left or right" is literal now: no sideways move into a horse, ever, and the arrow says so. The escape stays real: jockeys steady and slip in behind. Without tuck-back, steering stops working (rail riders reach the rail within 3 s 4% of the time instead of 93%), and strangers can hold a kid wide (own trip −0.015, p5 −0.06).
  - **Brushes.** They answer David's "bump and slow down" the way racing does: the horse that moved pays (ARCI-010-035 E(4)). A second press within 2 s charges casual riders in 0.4% of races (mean under 0.0001), and a griefer who bumps a kid pays every time while the kid pays nothing.
- Tuning (moderator's prototype, debate 012; all 8 course × distance cells):
  - **Acceptance targets** (regenerated baselines, 1,000 races per cell and post, 300 report races per cell). Every D-054 target still passes in every course × distance:
    - rail rider vs Smart Steer +0.017 to +0.026;
    - never-steer −0.014 to −0.016;
    - draft share 20–36%;
    - post bias ≤ 0.0022 (kid among bots and all-Smart);
    - Smart Steer kid mean −0.0009 to +0.0005.
  - **Reach target replaced.** "Inward press reaching its lane within 3 s ≥ 70%" is now counted **per intent** (no press by that rider in the 3 s before): 74–100% per cell (150 races per cell on the report seeds, final rules). Per press it falls to 64–96% (dirt Mile 69%, dirt Marathon 64%), because the slower glide and reverse gaps stretch some moves past 3 s in jammed fields, and each re-press counts again. The per-press figure stays in the report.
  - **New targets, all met:**
    - masher reversals ≤ 8 a minute with none within 3 s of the previous (7.1, 3.5 s);
    - sideways acceleration ≤ 30 ft/s² between ticks (30; D-054 200);
    - casual riders charged for a brush in ≤ 5% of races (0.4%);
    - griefing, targeted minus untargeted own trip ≥ −0.001 (−0.0005 to +0.0031);
    - 0 overlaps and fall-back ≤ 20 ft/s in 4,000 stress races.
  - Boxed (Smart Steer kid): 5.5% of pre-lock time; at least 1 s in 21% of races; trapped about 1%.
  - Brushes (second press within 2 s):
    - casual riders: 1.9% of races have one, 0.4% are charged;
    - wanderers: 35% / 13.5%, mean 0.0004;
    - mashers: 80% / 64%, mean 0.0032;
    - rail riders and ditherers: 0.
  - Griefing (strangers who tapped exactly like the kid; the kid's own trip, final rules): shadow −0.0011, crew of 3 +0.0011, bumper −0.0007. The same strangers riding for the rail without targeting anyone: −0.0013 and −0.0020. Targeting gains nothing.
- Built (N1–N6, 2026-10-06; not yet played in Studio). The numbers are in docs/research/steering-calibration.md; the stage notes follow. Final values:
  - **Glide:**
    - `glide = "eased"`: `laneSpeedMax = 1.5` lanes/s (9 ft/s) and `laneAccel = 4.5` lanes/s² (27 ft/s²). One lane takes 1.0 s, two 1.6 s, three 2.3 s, four 3.0 s.
    - `chainWindow = 0.3` lane; `glideReserveFeet = 6`.
    - The 0.8 s switch is `laneSpeedMax = 1.667`, `laneAccel = 5.56`.
  - **No zig-zag:** `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5` within `weaveWindowSeconds = 7`, `pressBounceSeconds = 0.2`. After the lock, make-room moves are planned ahead, with the same gaps.
  - **Body:**
    - the turn is the drift (`yawGain = 1`), at most 10°, smoothed over 0.15 s;
    - the lean is 0.12° per ft/s², at most 3°;
    - your press's look cue is 3°, relaxing over 0.3 s, and never for a press the server will ignore or hold;
    - the chase camera stays on the track heading.
  - **Boxed in:**
    - `blockedPress = "wait"`: outward presses wait 1.5 s, then drop with a 4° wobble; inward presses wait until room, or tuck back at once within 24 ft.
    - Out ▶ greys after 0.2 s blocked; ◀ In greys only when tuck-back can't help.
    - "No room yet" after 1 s, at most once per 10 s and never within 2 s of another chip; "Gap!" after a wait of 0.5 s or more.
    - No penalty.
  - **Brushes:**
    - `brush = "repeat"`, `brushPresses = 3`: the third press toward a horse alongside (within 8 ft, alongside for 0.3 s), within 2 s of the first, while it waits, with no tuck-back.
    - The mover pays 0.002 τ after `brushFree = 1`, at most `brushMaxCharged = 3` (0.006 a race), and steadies back 4 ft (2 ft/s back) for 1 s. The bumped horse never pays.
    - Drawn: lean 1 ft and nod 2° over 0.4 s on a sine squared; a late brush restarts (`brushLateSeconds = 1/30`).
    - The first brush ever brings the one-time tip "Bump! Press once, then wait for a gap".
  - **Calibration** (live and d057, the same config): every D-054 τ target and every D-057 target pass in every course × distance.
    - Casual riders are charged in 0.0% of races, press-again kids in ≤ 0.8%, the masher in 56%.
    - Griefing gates hold (own trip for the Smart Steer and rail kids; brush charges for every kid but the masher).
    - The shadow finding is open for David (REVIEW_QUEUE).
  - **On screen** (overlap report, every mode): 0 overlaps, fall-back ≤ 19.3 ft/s, the finish order right, 0–2 late full-lane moves per 960 races, no after-lock reversal within 3.5 s.
  - **Switch-back:** eight keys (`Trip.d054Config` / `trip.d054_config()`; recipe in PLAYTEST "Natural steering (D-057)" → 5). The D-054 baseline, report and parity runs are kept. Every other D-057 key already holds its D-057 value in `D057_OFF` (`brushPresses` 3 included, since N6), where nothing reads it while the switches are off.
  - **Not built:** the optional head split, a later art option. It needs `split_legs.py` to cut a Head piece, re-uploaded horse meshes and a HorseLegs head joint (`headTurnDeg`), and it can't be checked without Studio. It would move the look cue and the nod to the head.
  - **Next:** David's Studio playtest (PLAYTEST "Natural steering (D-057)", phones first), then a call on the shadow finding.
- N1 (2026-10-06, model engineer, revised after the PR #48 review): the Python model and sims, switched off. Details and numbers are in docs/research/steering-calibration.md ("Natural steering (D-057), stage N1").
  - **Built:**
    - Every rule is in `src/trip.py` behind `trip.CONFIG` keys with the plan's `GameConfig.steering` names, all off. The game, `TripBaseline.luau`, `trip_baseline.json`, `steering_report.json` and `trip.json` stay byte for byte as before; a full `sims/steering.py --write` reproduces them.
    - `trip.config_record` leaves the D-057 keys out of a recorded config while they hold the literal D-054 values in `trip.D057_OFF`, so records stay right after N3 flips `CONFIG`.
    - `trip.d057_config()` turns D-057 on: the eased glide, chaining, reverse and weave gaps, the press bounce, the glide reserve and wait-for-room presses. It also brings `side_state` (with the "tuck" flag N4 needs), `boxed_in`, `no_tuck_inside` (D-057's "trapped", the grey ◀ In), `boxed_no_tuck`, brushes and the brush term in τ.
    - `sims/steering.py --profile d057` adds the D-057 policies and measures and stores four exact probe races with its report.
    - `make_fixtures.py --d057` writes `trip_d057.json`: 200 runs and 12 edge runs for the N2 port.
  - **Tuning change (provisional, REVIEW_QUEUE): `weaveWindowSeconds` 7, not 5.**
    - With 5, a masher reversed 8.35 times a minute in the dirt Mile and 8.34 in the dirt Marathon, against the ≤ 8 target in every course × distance. Pooled over the cells it was 7.6, the way debate 012 measured it.
    - With 7, every cell is between 6.3 and 7.5. Casual reach per intent and brush charges don't move. Reversals stay at least 3.5 s apart.
    - The reviewer's 6 s left the dirt Marathon at 8.11.
  - **D-057 on, measured** (2,000 baseline races per cell and post, 600 report races per cell). Every D-054 τ target passes in every course × distance:
    - rail vs Smart Steer +0.017 to +0.026;
    - never-steer −0.015 to −0.013;
    - draft share 20–35%;
    - post bias ≤ 0.0017 for a kid among bots and ≤ 0.0024 in all-Smart lobbies;
    - Smart Steer kid mean −0.0009 to +0.0003.
  - **The new targets pass too:**
    - reach per intent 72–98% per cell (per press 65–94%);
    - glides of 1.0, 1.6, 2.3 and 3.0 s for one to four lanes;
    - brushes charge casual riders in 0.6% of races, and the other horse is never charged;
    - griefing (targeted minus untargeted own trip) −0.0004 to +0.0029;
    - 0 overlaps and fall-back ≤ 19.0 ft/s in 4,000 stress races.
    - Sideways acceleration between 10 Hz ticks peaks at 30.4 ft/s² on a landing tick (Trip's own speed ≤ 27). The prototype measured the same 30.4 and quoted it as 30, so the check allows the landing tick (≤ 30.5).
  - **Call (provisional, REVIEW_QUEUE): the 2 s brush window starts when the waiting press was pressed, even if it queued** behind a glide or a reverse gap.
    - The plan timed it from the last accepted press, which could be an older press the other way.
    - Casual riders are charged in 0.60% of races against 0.48% with the plan's rule; mashers 66% against 62%.
    - With the plan's rule the model matches debate 012's prototype exactly (200 of 200 heavy-press races).
  - **Other calls where the plan was open:**
    - The brush check sits in `accept_intent` after the bounce and steady checks, in the same order as the plan, so a finger bounce never brushes.
    - New key `boxedAheadFeet = 12`, reported only.
    - Griefing is checked pooled over the cells, and every cell passes as well.
    - Smart Steer's wait clock only counts an unbroken wait.
    - Reach per intent counts a first press answered cancelled, steady or brush as an intent; none of those can be a first press in practice.
- N2 (2026-10-06, roblox engineer): Luau parity and overlap tooling, still D-054 in the game.
  - **`Trip.luau`** mirrors every N1 rule line by line, behind the same keys:
    - the S-curve glide (`easeStep`, `math.sqrt`), chaining, no reversal mid-glide, the reverse and weave gaps, and the bounce;
    - the glide reserve, wait-for-room presses, and `sideState`, `boxedIn`, `noTuckInside` and `boxedNoTuck`;
    - brushes, every new clock, and `tau(..., brushCharges)`.
  - **`GameConfig.steering`** gains the 25 D-057 keys at their D-054 values, checked equal to `trip.CONFIG` in full. `Trip.d057Config` builds the D-057-on config and is checked equal to `trip.d057_config()`.
  - **`Trip.raceTau`** now passes each mover's brush charges. They are all zero while brushes are off, which changes nothing.
  - **Parity:**
    - `tests/luau/trip_d057_tests.luau` replays `trip_d057.json` at 1e-9: 50 scripted runs (a snapshot every 20 ticks) and 12 edge runs.
    - It checks every answer and every snapshot field: lanes, sideways speeds, offsets, targets, waiting presses, steadying, charges, tucking, tuck-back, every clock (the six D-057 clocks plus `smartBlockAt`, `lastPressAt` and its direction, `wantAt`, `lastChange` and `lastDir`), side states, boxed and no-tuck.
    - It also checks every brush event with its tick, the trip, charges, τ with the brush term, and stars.
    - Configs come from the exact-decimal strings.
    - A mutation check (widening the brush window by 0.15 s) fails it in 7 different fields.
    - `trip.json` parity is unchanged.
    - `make_fixtures.py --d057` now runs in CI. The fixture is cut to 50 runs: 7.3 MB, written in about 6 s on a laptop.
    - `tests/test_luau_parity.py` regenerates the fixtures only when a hash of `make_fixtures.py`, the five modules it imports and `trip_baseline.json` has changed, or a fixture is missing. The hash is kept in `tests/fixtures/.fixtures.sha256` (gitignored). A test checks that the hash covers every module the generator imports.
  - **After the lock (Luau only), all switched on by `glide = "eased"`:**
    - The make-room lanes glide on the same S-curve (`st.shownV`, carried on from Trip's sideways speeds at the bell), so nothing slides at once.
    - A horse rests a tick after landing before it sets off again, including on the bell's tick. Landing and setting straight off the other way drew 44–47 ft/s².
    - The look-ahead, crossing time and half-lane-step lead come from the eased glide time (`Trip.glideSeconds`).
    - A horse moving in front of another keeps the glide reserve (6 ft) from it. Without this, one race in 960 had a cut-in that ended in a finish-line overlap.
    - **Planned, not dodged** (PR #49 review). The first version searched for a way out early near the line, and that made 378–422 full-lane swerves in the last 2 s per 960 races (D-054: 59–99) to save 1–2 races from an overlap. Instead:
      - The plan is where each horse is heading by the last tap: the race shape at full luck weight, worked out every tick as the live chances move. `Trip.frame` passes it to `Trip.cosmetic`.
      - A horse whose planned place is within holdGap + glideReserveFeet of a horse ahead in its lane, or past it, moves over now, while they are up to 3 s of closing apart (`PLAN_SECONDS`). The horse behind on screen, the one overtaking, makes one S-curve move, outward first. If it is boxed in, a horse in its way moves over instead, as before.
      - Free lanes are still judged on the targets now, not the plan. Judged on the plan, a horse that will pass half the field finds no lane free, stays boxed on the rail, and runs through the others when the holds let go (a second seed family showed it).
      - In the half-step window a horse still boxed in edges half a lane over before it tries a full lane change, so a late meeting ends in a small step.
      - It is not a full path planner. A pairwise planner over whole offset paths was more code than N2 needed, and this rule meets the same target.
    - **The reverse and weave gaps hold after the lock too** (PR #49 review). A move the other way waits 0.5 s after landing, or 2.5 s for a second reversal within 7 s. The gaps carry on from the trip at the bell (`st.shownDir`, `shownRevAt`, `shownArrived`). Before this there were 55–71 reversals within 3 s per 960 races, the shortest 0.7 s apart.
    - **The holds after the lock** (eased only) count two horses gliding into the same lane as sharing it already. A 1.0 s glide from either side would otherwise meet before the hold saw them in one lane. A half-lane step frees a horse from the hold only once the step is done (half a lane apart), because the S-curve takes its last 0.05 lane slowly.
    - With D-057 off nothing changes: the D-054 overlap reports (960 races each: bots; two riders predicting at 0.1 s and 0.25 s; three riders on manual) print exactly what main prints.
  - **Lanes on the wire** are rounded to 0.001 lane with the eased glide, instead of 0.01. N3's screen draws the S-curve from these samples, and 0.01 lane of rounding adds up to 12 ft/s² of sideways jitter.
  - **`SteerPredict`** predicts nothing with the eased glide: the slide starts with the server's lane, as D-057 decides. N3 adds the look cue. Its D-054 behaviour is unchanged.
  - **Overlap tooling:** `race_overlap.luau` and `overlap_report.luau` gain a `d057` mode.
    - Riders: a masher, a ditherer and a casual rider pressing through `Trip.submit`. With `predict`, rider 1 presses from its own screen and the three follow.
    - Drawing: lanes are drawn as N3's RaceView will draw them, with the 10 Hz samples interpolated.
    - Delayed messages: the client keeps drawing until the last delayed samples land. Before, a 0.25 s link judged the finish order on a stale frame.
    - New counts: reversals per rider, the shortest gap between them, the drawn sideways acceleration (excluding frames after the stream ends), brushes, and boxed-in time. Reversals a minute count each rider's own time, also when two riders share a style.
    - After the lock (every horse): the moves, full-lane moves in the last 2 s ("late moves"), half-lane steps in the last 2 s, and reversals with the gap to the one before.
    - Rider 1's own horse is drawn through `SteerPredict.laneTo` and interpolated like the shared lanes, so the own-screen column measures what the rider would see (with the eased glide that is the server's lane).
    - `jitter=S` adds 0 to S s of random delay to each message, still delivered in order. It is informational until N3: the report prints what it finds and exits 0.
    - The report exits 1 on any overlap on either screen, any jerk over 20 ft/s, a wrong finish order, a rider reversing within 3 s, a horse reversing after the lock within 3.5 s of its last reversal, more than 100 late moves per 960 races, or drawn acceleration over 31.7 ft/s². That bound is Trip's landing tick (30.4) plus up to 1.2 for the 0.001-lane rounding.
    - Lune tests: the 16-race D-057 overlap test also checks the after-lock reversal gap and no late moves. Seed 174221 (dirt and turf Marathon) and seed 277168 (dirt Marathon), with rider 1 on its own screen at 0.1 s and 0.25 s, are stored as repro races. Without the plan, 174221 overlaps on dirt.
  - **Measured with D-057 on** (960 races per row; all pass):

    | Row | Overlaps (shared / own) | Fastest fall-back before / after the lock | Order wrong | Shortest reversal gap | Drawn accel before / after the lock | Brushes a race | Riders boxed |
    | --- | --- | --- | --- | --- | --- | --- | --- |
    | Masher + ditherer + casual, Smart Steer | 0 / – | 19.0 / 19.0 ft/s | 0 | 3.5 s | 30.6 / 30.6 ft/s² | 2.76 | 15.5% |
    | The same, Smart Steer off | 0 / – | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 2.88 | 14.2% |
    | Rider 1 from its screen + the three, 0.1 s link | 0 / 0 | 19.0 / 18.9 | 0 | 3.5 s | 30.6 / 30.6 | 4.07 | 13.7% |
    | The same, 0.25 s link | 0 / 0 | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 4.10 | 13.6% |

    After the lock (the same rows):

    | Row | Full-lane moves in the last 2 s (races) | Half-lane steps in the last 2 s | Moves after the lock | Reversals after the lock | Within 3.5 s of the last | Shortest gap |
    | --- | --- | --- | --- | --- | --- | --- |
    | Smart Steer | 2 (2) | 35 | 11,029 | 4,146 | 0 | 3.5 s |
    | Smart Steer off | 2 (2) | 45 | 11,084 | 4,153 | 0 | 3.5 s |
    | Own screen, 0.1 s | 0 (0) | 29 | 9,940 | 3,931 | 0 | 3.5 s |
    | Own screen, 0.25 s | 0 (0) | 27 | 9,905 | 3,905 | 0 | 3.5 s |
    | D-054, for comparison (bots; 2 riders predicting; 3 on manual) | 59–99 (37–77) | 11–17 | 8,352–14,099 | 4,157–5,990 | 234–511 | 0.6 s |

    Reversals a minute: masher 7.1–7.7, ditherer 11.8–12.4, casual 1.8. Half-lane steps happen in 19–28 races per 960 (D-054: 11). A second seed family (3,840 more races across the four rows) also passed: no overlaps, jerks or wrong orders, 0–1 late moves a row, and no after-lock reversal within 3.5 s.
    - **A jittery link** (informational until N3; `jitter=0.03`, 0–30 ms on each message, 960 races, with and without rider 1 on its screen): no overlaps, the order right, the after-lock counts as above. Drawn lanes reach 90 ft/s², and offsets draw horses falling back at up to 22.2 ft/s in 242–263 races (D-054: 608). Both come from interpolating on arrival. N3's RaceView interpolates by the server's timestamp (or keeps a one-sample buffer) and makes this row pass.
- N3 (2026-10-06, model engineer and roblox engineer): the server behaviour flipped on, and the motion visuals.
  - **Config:** `trip.CONFIG` and `GameConfig.steering` switch D-057's motion and press rules on: `glide = "eased"`, `chainWindow = 0.3`, `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5`, `pressBounceSeconds = 0.2`, `glideReserveFeet = 6`, `blockedPress = "wait"`. Brushes stay `"off"` (N5); the boxed-in UI is N4. Bots, Smart Steer and riders all move by these rules on the server.
  - **The switch-back** is `trip.d054_config()` / `Trip.d054Config`: those seven keys at their D-054 values (REVIEW_QUEUE has them). `tests/test_trip.py` now holds that config to every D-054 promise, against the D-054 baseline and report, kept as `trip_baseline_d054.json` and `steering_report_d054.json` (`sims/steering.py --profile d054`). The eight D-054 parity runs still hash byte for byte as at main 7abfa27. On screen, RaceView draws the linear glide exactly as D-054 did, and the four D-054 overlap reports (with the D-054 baseline) print exactly what main prints.
  - **Calibration** (`python sims/steering.py --write`; the default profile is now the game's, `live`): every D-054 τ target and every D-057 target passes in every course × distance against the regenerated `TripBaseline.luau` (table in docs/research/steering-calibration.md). Rail rider vs Smart Steer +0.017 to +0.026; never-steer −0.015 to −0.013; reach per intent 73–98%; draft share 20–35%; post bias ≤ 0.0017 (kid among bots) and ≤ 0.0024 (all-Smart); Smart Steer kid −0.0009 to +0.0003; masher 6.3–7.4 reversals a minute, none within 3.5 s; sideways acceleration 30.4 ft/s²; griefing −0.0003 to +0.0030; stress 0 overlaps, 19.0 ft/s.
  - **Fixtures:** `trip.json` is the game's config now (200 runs at parity), and `trip_d057.json` gains one run on the whole switch-back.
  - **Screen playback** (`Playback.luau`, shared and pure):
    - RaceService stamps every steering sample with the server time its state stands for: before the lock Trip's last fixed tick, after it the frame's time, with the make-room step taken from the last stamp. `RaceOffsets` is `(offsets, [lanes,] serverTime, courseId)`; the course id stays last.
    - RaceView draws the race a delay behind the newest sample and interpolates offsets and lanes between samples by their stamps. The delay is the longest recent lag plus one send interval plus 0.05 s; the clock runs at most 4% fast or slow to change it, never jumps, and never draws backwards. A late sample holds the newest.
    - After the code review: the lag is measured once a frame from the newest arrival (a 0.8 s client freeze used to add 0.5 s of delay for half a race; now nothing), a packet overtaken by a later one is dropped with its lanes (`Playback.pushOffsets`), lanes go out on the two samples after a change too, the replay's last frame no longer snaps a lane back, the replay camera follows the track's heading rather than the body turn, and a replay starting mid-glide starts at its sideways speed (`SteerPose.prime`).
    - The overlap report draws with the same module, and its jitter rows now pass and are gated.
  - **The body** (`SteerPose.luau`, shared and pure; `GameConfig.steerView`): with the eased glide, every horse in a steering race turns with its true drift, atan(sideways / forward speed), smoothed over 0.15 s and capped at 10°, and leans 0.12° per ft/s² of sideways acceleration, capped at 3°. `SteerPose.angles` turns the pose into `CFrame.Angles` (higher lanes are the horse's right on every course). The legs keep striding by distance, and the replay keeps its time scale and the rest hooks. D-054's linear glide (the switch-back) has no pose and no look cue, so its screen is D-054's.
  - **The look cue:** your press turns your horse 3° toward it at once (over about 0.05 s), on your screen only, when the lane it asks for has room by the lanes on your screen (`SteerPredict.look`). It holds until your horse starts over on your screen; it relaxes over 0.3 s when the server's answer shows the press waits, at the lock, or after 1.5 s. The sideways move waits for the server: nothing is drawn ahead of it.
    - Second review: no cue for a press the server will ignore or hold (the same way within `pressBounceSeconds` of the last cue, against a glide under way, the other way within `reverseGapSeconds` of landing or `weaveGapSeconds` for a second reversal within `weaveWindowSeconds`), and never the other way while a cue is held. Landings and reversals are read off your horse as drawn. A kid mashing at random, 4 presses a second (`overlap_report predict ownStyle=masher`): the cue swings the body from one side to the other 0.14 times a second (0.55 before), cues 0.65 a second (2.2 before), and the body never turns more than 3° beyond its drift. The report gates it (under 0.5 a second).
  - **Replays** draw the recorded lanes on a monotone cubic through the frames (`ReplayTrip.laneCurve`), and turn and lean the bodies from the replayed lanes and progress in race time. Old recordings stay on their posts.
  - **Logs:** the `[Trip]` line ends with presses held by the reverse or weave gap and waits that dropped.
  - **Calls made where the plan was open:**
    - SteerPredict's D-054 prediction (AHEAD) stays, used only by the linear glide, so the switch-back is whole (the plan said it goes).
    - No 150-stud pose cut-off (the plan said "as legs do", but the legs have none; the pose is one CFrame multiply).
    - The chase camera stays Follow; whether it swings with the body turn is a PLAYTEST check, with the plan's fix (a track-aligned subject) if it does.
  - **Measured on screen** (the game's config unless noted; 960 races per row; all pass):

    | Row | Overlap frames (shared / own) | Fastest fall-back before / after the lock | Order wrong | Shortest rider reversal gap | Drawn accel before / after the lock | Full-lane moves in the last 2 s (races) | After-lock reversals within 3.5 s (shortest gap) |
    | --- | --- | --- | --- | --- | --- | --- | --- |
    | Masher + ditherer + casual, Smart Steer on | 0 / – | 19.0 / 19.0 ft/s | 0 | 3.5 s | 30.6 / 30.6 ft/s² | 2 (2) | 0 (3.5 s) |
    | The same, Smart Steer off | 0 / – | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 2 (2) | 0 (3.5 s) |
    | Rider 1 from its screen + the three, 0.1 s link | 0 / 0 | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 0 | 0 (3.5 s) |
    | The same, 0.25 s link | 0 / 0 | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 0 | 0 (3.5 s) |
    | Masher + ditherer + casual, 0–30 ms jitter | 0 / – | 19.3 / 19.2 | 0 | 3.5 s | 30.1 / 29.7 | 2 (2) | 0 (3.5 s) |
    | Own screen 0.1 s + 0–30 ms jitter | 0 / 0 | 19.3 / 18.7 | 0 | 3.5 s | 30.1 / 29.2 | 0 | 0 (3.5 s) |
    | Own screen 0.25 s + 0–30 ms jitter | 0 / 0 | 19.3 / 19.0 | 0 | 3.5 s | 30.2 / 29.0 | 0 | 0 (3.5 s) |
    | Bots only | 0 / – | 19.0 / 19.0 | 0 | – | 30.6 / 30.6 | 0 | 0 (3.5 s) |
    | Brushes on (N5 preview) | 0 / – | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 2 (2) | 0 (3.5 s) |
    | Brushes on, own screen 0.1 s | 0 / 0 | 19.0 / 19.0 | 0 | 3.5 s | 30.6 / 30.6 | 0 | 0 (3.5 s) |

    - The jitter rows before N3 (arrival-timed drawing): 90 ft/s² and horses falling back at 22.2 ft/s in 242–263 races per 960. Now within every gate.
    - Reversals a minute (the game's config): masher 7.1–7.7, ditherer 11.7–12.4, casual 1.8–1.9, rider 1 on its own screen 6.3. Half-lane steps in the last 2 s: 27–37 a row. Riders boxed 13.5–15.6% of their pre-lock time; brushes 0 (on in the preview rows: 2.76 a race).
    - The look cue (own screen): about 27,400 of 70,163 presses showed it (the rest asked for a lane with no room, or past the edge); it held at most 0.45 s on a 0.1 s link and 0.78–0.85 s on a 0.25 s link; nothing was drawn ahead of the server.
    - The D-054 switch-back (`d054`, with the D-054 baseline): the four D-054 reports (bots; 2 riders predicting at 0.1 s and 0.25 s; 3 riders on manual) print exactly what main prints. Its jitter row still fails as D-054 always did (608 races falling back at 22.2 ft/s): the linear glide keeps D-054's arrival-timed drawing.
    - A second seed family (3,840 races: the game's config, own screen at 0.1 s, jitter, own screen at 0.25 s with jitter) passes every gate too (0–1 late moves a row).
    - Second review: the report also judges the order in which the horses cross the line on the drawn screen (each horse's pace plus drawn offset reaching the race length); right in every race of every mode. RaceService now steps and sends every fixed tick before the lock (the loop wakes about every 0.117 s, so about one tick in seven used to go unsent); `trip_d054.json` (20 runs on the switch-back, the D-054 baseline) keeps Trip.luau's D-054 path at parity in CI; resting horses (the race ends or aborts, a replay closes) straightens their bodies; a long frame gap can't overshoot the playback delay.
- N4 (2026-10-06, roblox engineer): the boxed-in UI, for riders with the buttons.
  - **What the rider hears.** `SteerLane` is now `(tgt, dest, ack, wait, waitAt, tucking, inSide, outSide, t, courseId)`, course id last; `t` is the race time the state stands for, so the screen times every wait on the server's clock, never by arrival. It is built by `Trip.riderLane` and sent on change, up to the lock, to riders with the buttons only.
    - `wait` is the direction of a press waiting for room; `waitAt` is the race time its wait for room starts. A press held by a reverse or weave gap reports the time the hold ends (the model resets its own wait start every tick of the hold), so `waitAt` stays steady.
    - `tucking` says whether a tuck-back is under way.
    - Each side is `"free"`, `"tuck"` (inward only: no room, but tuck-back finds a slot), `"blocked"` (a horse is in the way and tuck-back can't help) or `"edge"` (the rail or the outside). The server works it out (`Trip.sideState`, at parity with Python) rather than the client from its drawn lanes, as the plan had it, so the arrows never disagree with what the server will do.
  - **The arrows** (`SteerHud`, pure):
    - Out ▶ greys, with a small 🐎 icon on its top edge, while a horse leaves no room outside. ◀ In greys only when `"blocked"` (D-057's "trapped"), never when `"tuck"`, so it never greys a button that still works at once. An arrow greys once its side has stayed blocked 0.2 s on screen (`greyAfterSeconds`; a horse sweeping past never blinks it, and it matches the playback's lead on the drawn horses), and comes back at once. The grey is a warm 172/166/158, 2.1:1 against the bone-white button.
    - Grey arrows still take presses. No buzz, no red.
    - A press waiting for room shows a 3 px ring in the button's colour: lit (breathing gently; steady under Reduced Motion) for an inward press, filling over `gapWaitSeconds` (1.5 s) for an outward one.
    - An outward press that drops after its wait makes its arrow wobble ±4° over 0.2 s, with no sound; none under Reduced Motion. A wait you cancel by pressing the other way doesn't wobble. The ring and the wobble use the config's outward wait (`gapWaitSeconds`, or D-054's `outwardWaitSeconds` with the switch-back). N5 note: a brush also clears a waiting press, and that must not wobble.
  - **The chips** (`SteerChips`, pure):
    - "No room yet" once a press has waited 1 s with no move and no tuck-back; once per wait, at most once per 10 s, and never within 2 s of another steering chip.
    - "Gap!" with `tap_good` when a wait for room of at least 0.5 s (server time) ends in the move, unless the wait saw a tuck-back ("Tucked in!" says that one).
    - Good-news chips ("Saved ground!", "Tucked in!", "Gap!", the turn tip, "Lanes locked!") always show, and only "No room yet" gives way to them.
  - **Who sees it:** only riders with the buttons. Spectators and a rider's first 3 races hear no `SteerLane`, and the HUD needs `shown`. The buttons show for every input, so keyboard and gamepad riders get the same arrows, ring, wobble and chips.
  - **Grown-ups page:** "Horses can get boxed in, like in real racing: they wait for a gap or ease back to find one. There's no penalty for being boxed in; a horse held wide just runs a little farther." (No promise about points: brushes charge the mover in N5.) The page's paragraphs now sort in the order they're written.
  - **Calls made where the plan was open** (in REVIEW_QUEUE):
    - The side states come from the server.
    - Nothing greys at the rail or the outside: there's no horse there, so a grey arrow with a horse icon would be wrong. Those presses are refused quietly, as in D-054.
    - Good-news chips always show.
    - The wobble only follows a drop by the server.
    - The outward ring fills straight across, not round the edge (Roblox UI has no radial fill without an image).
  - **Measured** (review): the first test only checked `Trip.sideState` against itself. Now `steer_hud_tests` checks behaviour in 12 real fields (varied chances; a masher, a ditherer, a casual rider and a rail seeker). On every tick a rider could press at once, a copy of the trip takes the press and steps a tick, and the arrow shown is the server's state one tick old:
    - ◀ In: 3,408 presses tried, 891 grey, 1,274 tuck-back states; 0.23% disagree (grey but the press would act, or normal but it wouldn't).
    - Out ▶: 11,699 presses tried, 4,905 grey; 0.23% disagree.
  - **Review probe** (48 races, 4 rider styles; 0.45 s one-way lag): "Gap!" per race went from 7.81 / 6.35 / 2.48 / 1.38 (masher / ditherer / casual / rail seeker) to 0.94 / 0 / 0.10 / 0; no "Gap!" after a tuck-back (was 381). SteerLane sends fell from 3.3 to 2.7 per rider-second (steady `waitAt`). Short Out ▶ grey blinks (under 0.3 s) went from 485 server flips (368 of one tick, about 2.5 per rider-race) to 91 on screen (0.47 per rider-race).
  - The overlap report is unchanged in every mode.
- N5 (2026-10-06, model engineer and roblox engineer): brushes on.
  - **Config:** `brush = "repeat"` in `trip.CONFIG` and `GameConfig.steering` (`brushPays = "mover"`). D-057 is now on in full, so `trip.d057_config()` is `trip.CONFIG`.
  - **The rule** is N1's and is unchanged: a second press within 2 s toward a horse alongside, while the first waits and no tuck-back is possible. Only the mover pays: 0.002 τ per brush after the first free one, at most 0.006, fixed at the lock. Bots and Smart Steer never brush, nothing happens after the lock, and riders in their first 3 races have no buttons.
  - **Calibration** (`python sims/steering.py --write`): The baseline is unchanged: Smart Steer never brushes, so the regenerated table and its probes are identical to N3's, and only the recorded config changed. Every D-054 τ target, every D-057 target and the griefing bound hold in every course × distance (table in docs/research/steering-calibration.md):
    - D-054 targets:
      - rail rider vs Smart Steer +0.017 to +0.026;
      - never-steer −0.015 to −0.013;
      - draft share 20–35%;
      - post bias ≤ 0.0017 (kid among bots) and ≤ 0.0024 (all-Smart);
      - Smart Steer kid −0.0009 to +0.0003.
    - D-057 targets:
      - reach per intent 72–98% (85.7% overall);
      - masher 6.3–7.5 reversals a minute, none within 3.5 s;
      - sideways acceleration 30.4 ft/s²;
      - stress, 4,000 races: 0 overlaps, 19.0 ft/s (with 9,760 brushes).
    - **Brushes by policy** (one rider among seven bots):
      - casual: 2.1% of races with a brush, 0.6% charged (0–1.3% per cell; the target is ≤ 5%);
      - wanderer: 36% / 13%, mean cost 0.0004;
      - masher: 82% / 66%, mean cost 0.0033 (at most 0.006);
      - rail riders, never-steer and ditherers: 0.
      - No horse but the mover is ever charged.
    - **Griefing** (targeted minus untargeted own trip; the bound is ≥ −0.001):
      - Smart Steer kid: shadow +0.0003, crew +0.0029, bumper +0.0005;
      - rail kid: +0.0001, +0.0001, −0.0004.
      - The kid is never charged for a stranger's brush, and a Smart Steer kid is never charged at all.
  - **What everyone sees** (`SteerBrush(mover, other, dir, serverTime, courseId)`, course id last, to every screen following the course, before that tick's `SteerLane`):
    - The mover leans toward the other horse (at most 1 ft, drawn only, never in the lanes that rank the race) and nods (2°), then eases back 4 ft (Trip's steady, under the hold-pull cap, so it never jerks back).
    - The other horse only nods. Both on a sine out and back over 0.4 s (`SteerPose.brush`).
    - No stumble, no flash, no text over the horses.
    - A soft `count_tick` at half volume, positional at the mover's horse. It stays silent until the effects are uploaded.
    - The brush plays when the race on screen gets there (its server time against the playback clock), and the replay records it then.
  - **The mover's rider** sees "No room yet" under the chips' limits; the other rider sees nothing. A wait the brush cleared never wobbles its arrow (the N4 carry-over).
  - **Results:** no brush line; the trip stars already include the charge.
  - **Log:** the `[Trip]` line lists each rider's brushes and brush cost.
  - **Grown-ups page:** "A rider who keeps pressing into a horse alongside makes the two brush shoulders. A brush costs the horse that bumped a tiny bit (a third of a point at most), never the horse that was bumped. Bots and Smart Steer never bump."
  - **Tests:**
    - `steer_brush_tests.luau`:
      - the pose (caps, smooth, the other horse only nods, the nod's sign);
      - the cleared wait;
      - the mover's chip limits;
      - mashing races: only riders' presses brush, only movers pay, `Trip.raceTau` takes the charges and RaceSession uses them, nothing after the lock;
      - the remote's shape;
      - no stumble or hurt words.
    - `trip.json` now carries τ with the brush term, at parity.
    - `test_trip_d057.py`: the live report's brush and griefing checks.
  - **On screen** (`overlap_report`, 960 races per row; brushes on in every D-057 row): on every row:
    - 0 overlaps on any screen;
    - no horse falling back faster than 20 ft/s (19.0–19.3, the 4 ft steady included);
    - the finish order right at the last frame and at each horse's crossing;
    - 0–2 full-lane moves in the last 2 s a row;
    - no after-lock reversal within 3.5 s;
    - drawn acceleration ≤ 30.6 ft/s².
    - A second seed family (3,840 races) is clean too.
    - The D-054 rows still print what main prints.
  - **Brushes by rider style** (the overlap report's riders; the gate is casual riders charged in ≤ 5% of races):
    - masher: 85–88% of races with a brush, 72–74% charged, about 2.7 a race;
    - casual: 1.5–5.6% with a brush, 0.0–1.4% charged;
    - ditherer: 0 (its presses alternate sides, so there's never a second press toward the same horse);
    - rider 1 on its own screen: 62–65% / 40–41% with the press patterns, 84–87% / 67–72% mashing at 4 a second.
    - No horse was ever charged for a brush it didn't make.
- N5 review (2026-10-06, model engineer and roblox engineer): a press again is the same try. Tables in docs/research/steering-calibration.md ("The N5 review").
  - **The rule:** a brush needs the third press toward a horse alongside while the first still waits (`brushPresses = 3` in `trip.CONFIG` and `GameConfig.steering`; N1's rule was the second press, `brushPresses = 2`). Everything else is unchanged: within 2 s of the first press, alongside for 0.3 s, no tuck-back possible. Each horse counts its presses that way since the first one started waiting (`same_presses` / `samePresses`, in the parity snapshots).
  - **Why:** kids press again when nothing seems to happen. With N1's rule, a kid who pressed again 0.4–1.2 s later paid in 58–59% of races among bots, and in up to 77% when boxed in. Measured over seven rules and eight press patterns (casual, one press, double-tap, again after 0.5 s, 1 s and 0.3–0.8 s, outward, wanderer, masher):
    - "a second press within 0.6 s is the same try" helped double-taps only (again after 1 s: still 58%);
    - `brushFree = 2`: 39–49%;
    - both together: 28–46%;
    - a 1.3 s minimum gap met the bars, but a press again at 1.5 s would brush, and the masher fell to 40%;
    - the third press: every casual and press-again pattern ≤ 0.8% in every scenario, the masher 61%.
    - It is also the easiest to say: a rider who keeps pressing.
  - **Calibration** (`python sims/steering.py --write`; the `d057` profile's files are the same run, since its config is the live one):
    - The baseline table and probes are identical; only the recorded config gained `brushPresses`.
    - Every D-054 τ target, every D-057 target and the griefing gates pass in every course × distance.
    - Brushes by policy among bots (was with N1's rule):
      - casual: 0.04% of races with a brush (2.1%), charged in 0.0% in every cell (0.6%);
      - wanderer: 6.9% / 0.4% (36% / 13%);
      - masher: 76% / 56% (82% / 66%), mean cost 0.0027.
    - Stress: 0 overlaps, 19.0 ft/s, 8,183 brushes.
  - **Griefing, with the new kids** (`GRIEF_KIDS` adds wanderer, masher and a press-again kid, `doubletap`: a press every 2–6 s, pressed again 0.3–0.8 s later). Own trip, targeted minus untargeted, with the brush-charge part in brackets:
    - Smart Steer kid: shadow +0.0003, crew +0.0030, bumper +0.0005 (no charges);
    - rail kid: +0.0001, +0.0001, −0.0004 (no charges);
    - wanderer: −0.0030, +0.0143, −0.0016 (no charges);
    - press-again kid: +0.0003, +0.0273, +0.0023 (charges 0.0000; the review measured −0.0019 to −0.0031 from the crew with N1's rule);
    - masher: −0.0029, +0.0292 (charges −0.0022), −0.0015.
    - **The gates:**
      - own trip ≥ −0.001 for the Smart Steer and rail kids, pooled and in every cell (−0.0008 at worst), the riders D-057's bound was written for;
      - the brush charges strangers add ≥ −0.001 for every kid but the masher (`griefing_brushes`): a masher who keeps pressing into a box pays, which is the lesson;
      - only the mover pays, for every kid.
  - **The shadow finding is not a brush effect.** Over the same races, a shadow costs a wanderer −0.0032 with brushes off and −0.0037 with them on. A kid who presses once per intent (never a brush) loses −0.0050 to a shadow and −0.0033 to a bumper.
    - What happens: the shadow sits inside the kid at its pace and follows it out, so inward presses meet it and outward ones don't. A random presser drifts wide: 0.23 lanes wider at the lock, 0.0045 more ground lost, 0.0012 back in draft.
    - Smart Steer, rail riders and press-again kids are unaffected.
    - No small rule fixes it: Smart Steer resuming 2.5 s after a press instead of 5 s about halves it in a probe and changes how every pressing kid rides.
    - Not changed in this PR. Numbers and options in REVIEW_QUEUE ("N5 review: shadow finding").
  - **Screens:**
    - The lean and nod are a sine squared (they start and end at rest: 1.7% of the lean on the first frame at 60 fps, was 13%). The test now samples at a real 60 fps.
    - A brush first drawn over 1/30 s late starts from the beginning then (`steerView.brushLateSeconds`, `SteerPose.brushStart`). One whose whole lean is already past isn't drawn, ticked or recorded.
    - The mover's chip shows as the brush is drawn (`RaceState.BrushDrawn`), not on arrival. The cleared-wait guard still starts on arrival.
    - No look cue while your horse steadies after your brush (`SteerPredict` view `steadyUntil`; the overlap tool mirrors it).
    - The nod-axis comment in RaceView is corrected: Angles is Rx·Ry·Rz, so the nod turns about the track's sideways axis.
  - **The first-brush tip:** a rider's first brush ever (it is free) shows "Bump! Press once, then wait for a gap" instead of "No room yet".
    - Once per player: `data.flags.bumpTip`, set by the server at that brush; `Trip.riderControls` adds `bumpTip`, and SteerControls carries it before the course id.
    - Chosen over once every few races: a tip that comes back after more brushes reads as a telling-off.
    - No blame or cost words.
  - **Log:** the `[Trip]` line counts each rider's brushes per other horse (`brushes 3 (into post 4 x2, post 6 x1)`, `Trip.brushesInto`), for the plan's "same horse 3+ times" fail line.
  - **Audio plan:** `bump_soft` (P1, not made; not `brush`, which is grooming). Brushes play `count_tick` until it is uploaded.
  - **Tests:**
    - parity edges for the third press and N1's second (`press-again`, `press-again-n1`), and the brush edges rebuilt as threes;
    - `test_a_press_again_kid_is_rarely_charged_and_a_masher_still_is`;
    - `steer_brush_tests.luau`: the late start, the tip, the steady look cue, `brushesInto`, and the τ ceiling allowed to absorb a charge.
  - **On screen** (`overlap_report`, every mode): 960 races a row, every mode:
    - 0 overlaps on any screen; no horse falling back faster than 20 ft/s (19.0–19.3);
    - the finish order right at the last frame and at each crossing;
    - 0–2 full-lane moves in the last 2 s a row, no after-lock reversal within 3.5 s;
    - drawn acceleration ≤ 30.6 ft/s²; the look cue swings 0.04–0.05 times a second (0.13–0.14 mashing).
    - Brushes by rider style:
      - masher: 80–82% of races with a brush, 57–66% charged;
      - casual and ditherer: none charged (one casual race in 960 had a brush);
      - rider 1 on its own screen with the press patterns: 34–38% / 13–14% (was 62–65% / 40–41%; its mash pattern is five presses in 0.3 s);
      - rider 1 mashing at 4 a second: 78% / 58–60% (was 84–87% / 67–72%).
    - The D-054 rows print what main prints. Its jitter row still fails, as since N3: D-054 draws on arrival.
- Alternatives:
  - **A 0.8 s glide** (Engagement, Young player; peak 10 ft/s, 37 ft/s²). It also passes every target (per-intent reach 76–100%) and is the playtest switch.
  - **Body turn 1.5× the drift, capped at 12°** (Engagement, Competitive): a horse drawn turning more than it moves reads as skidding.
  - **A reverse gap only**, without the weave gap: still sways every 1.5–1.9 s.
  - **Refusing opposite presses:** a press that does nothing.
  - **Wait for a gap without tuck-back:** steering stops working, and it is a griefing vector.
  - **A boxed-in penalty:** it hits rail riders making the right play and unlucky posts, and it is a griefing tool.
  - **A brush on any press at a horse alongside:** charges 51% of casual races.
  - **The bumped horse paying, or both:** a kid's score would depend on a stranger's presses. With an any-press trigger the kid was charged 1.2 bumps a race.
  - **Roblox physics collision bodies:** exploitable client-owned parts, lag on your own horse, no Python/Luau parity, and overlaps and jerks come back.
  - **No bumping at all** (Young player's opening): doesn't answer David, and a refused press has no physical feel.
  - **A brush cap of two charged** (Child safety).
  - **N5 review, for natural pressing:** a second press within 0.6 s counting as the same try (press-again at 1 s still charged in 58% of races), `brushFree = 2` (39–49%), both (28–46%), and a 1.3 s minimum gap (passes, but a press again at 1.5 s brushes and the masher falls to 40%). The third press won.
  - **N5 review, the first-brush tip:** once every few races (it comes back after more brushes, which reads as a telling-off).
- Amends:
  - D-054: the glide, presses into blocked lanes, the trip formula (brush term), Smart Steer and bots (same motion);
  - D-054 S3: SteerPredict no longer draws your sideways move ahead of the server;
  - D-054: the promised "no room" shake (never built) becomes a soft 0.2 s wobble when an outward press drops.
- Config (`GameConfig.steering` unless noted):
  - `glide = "eased"` ("linear" = D-054), `laneSpeedMax = 1.5`, `laneAccel = 4.5`, `chainWindow = 0.3`;
  - `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5`, `weaveWindowSeconds = 7` (5 in debate 012; 7 since the N1 review), `pressBounceSeconds = 0.2`, `glideReserveFeet = 6`;
  - `blockedPress = "wait"` ("d054" = D-054), `gapWaitSeconds = 1.5` (outward), `gapWaitInSeconds = 0` (0 = an inward press waits until room, as D-054), `tuckAfterSeconds = 0`;
  - `brush = "repeat"` ("off" = none), `brushAlongFeet = 8`, `brushGraceSeconds = 0.3`, `brushRepeatSeconds = 2`, `brushPresses = 3` (N5 review; 2 = N1's rule), `brushPays = "mover"`, `brushCost = 0.002`, `brushFree = 1`, `brushMaxCharged = 3`, `brushCheckFeet = 4`, `brushRecoverPerSecond = 2`, `steadySeconds = 1`;
  - `GameConfig.steerView` (new): `yawGain = 1`, `yawMaxDeg = 10`, `yawSmoothSeconds = 0.15`, `leanDegPerFtps2 = 0.12`, `leanMaxDeg = 3`, `lookDeg = 3`, `lookRelaxSeconds = 0.3`, `brushLeanFeet = 1`, `brushLeanSeconds = 0.4`, `brushNodDeg = 2`, `brushVolume = 0.5`, `brushLateSeconds = 1/30` (N5 review), `headTurnDeg = 0` (the art follow-up sets 12);
  - `GameConfig.steerHud`: `greyArrows = true`, `waitRing = true`, `noRoomChipAfter = 1`, `noRoomChipEvery = 10`, `gapChipAfterWait = 0.5`, `chipMinGap = 2`.
- Links: debate 012 (`docs/debates/012-natural-steering.md`), src/trip.py, sims/steering.py, game/src/shared/Trip.luau, game/src/shared/SteerPredict.luau, game/src/client/RaceView.client.luau, game/src/client/RaceController.client.luau, game/src/server/RaceService.server.luau, game/src/client/Replay.client.luau

## D-058 — Rest and the Spa Day (no injury)
- Date: 2026-10-07
- Status: Accepted (provisional). **Flagged for David** (OPEN_QUESTIONS 5): he asked on 2026-10-07 for "injury or care at the vet" from over-running; this decision gives vet care without injury.
- Decided by: team, debate 013 (4/4 against any sore or injured state; Spa details settled in rebuttal)
- Context: David's 2026-10-07 wish for injury and vet care meets hard rule 3 ("never … sicken"), D-039 ("sore legs after hard races" rejected) and his own 2026-10-05 "skip sick horses". The audit also found "Resting" shows after one cash race while the horse can race 4 more times, so today's rest words are wrong.
- Decision:
  - **Tired cues only when they're true:** the horse yawns at 1 Energy and lies down in the straw with Zzz at 0. The dock and picker show Energy as 5 horseshoe pips and say "Ready" from 1 up and "Napping" only at 0 (`energy.restingLabelAt = 0`, `energy.yawnAt = 1`). When every horse is napping: "Great day! Comet's dreaming of tomorrow."
  - **Spa Day at the vet:** free, about 30 s: hose (D-039's cool-down hose, finally built), brush and a towel, tapping only. Once per horse per server day (`spa.perDay = 1`); it says "Spa opens again tomorrow", never a countdown. Gives +1 Energy (`spa.energy = 1`, never above max), a Health Passport stamp and a cosmetic shine on the horse's next race. **No bond, no Rating, no win chance.**
  - **Never:** a sore, hurt, limping, injured or sick state, a vet bill, a cure for sale, or the words hurt, sore, injury, limp, sick in game text.
- Consequences: David's "care at the vet" exists as a daily, positive ritual. Energy is unchanged as the only limit on cash races (D-015). Rookie horses (free races) still never tire; the Spa's Energy matters from Bronze.
- Alternatives: a mild non-blocking "sore" state fixed by a free vet visit (closest to David's words; 0/4: kids read it as "I hurt my horse", D-039, maturity rating risk); sore that lowers Rating (rule 3 and D-015: care would become win chance); a "Puffed & muddy" look after 3 cash races (dropped in rebuttal: mud and sweat can read as hurt; Child safety's grinning "Muddy & happy" variant kept as the minority view, `spa.muddyLook = false`); Spa +1 bond (bond is Rating, D-014); a 20 h cooldown (a timer kids watch).
- Links: debate 013, docs/plans/horse-life-and-retention.md (stages 1 and 4), docs/research/2026-10-07-retention-and-horse-life.md
- Built, the label only (stage 1, 2026-10-07; not yet played in Studio): `Horse.view` gives `ready = energy ≥ 1` and `resting` only at `energy.restingLabelAt` (0); the dock says "Ready" / "Napping", the picker "😴 Napping", and `Advice` says "napping" only at 0. The yawn, the lying pose and Spa Day are stage 4.
- Built, stage 4 (2026-10-07; not yet played in Studio): **rest cues** in the stall from Energy (`Spa.restPose`): "🥱 Yawn!" bubble at `energy.yawnAt` (1), and at 0 the horse lies in the straw with "💤 Napping" (Meshy `horse_lie_bay`, `horse_lie_palomino`, `horse_lie_grey`, the starter coats; other coats sink the standing model `spa.napLowerStuds` into a straw bed that hides the legs; retexturing all twelve coats was left out to keep the balance clear of the floor while stage 5 also used Meshy). **Spa Day** (`shared/Spa.luau`, `GameConfig.spa`): at the Vet's new wash bay beside the clinic (its own "Spa Day" prompt) or the Vet's horse card (🩺 Check-up beside 🛁 Spa Day); three tap steps (Rinse 6, Brush 6, Dry 4 taps, about 30 s); the server takes it only for your stalled horse, at the Vet, not racing, `spa.minSeconds` (8, less `spa.lagAllowance` 1.5 for the trip) after `SpaStart`, while that horse's Spa is open today (a finish it can't take says "Let's try the Spa again!", never nothing) (server UTC day, like care). Gives +1 Energy (never above 5; a full horse still gets the stamp and the shine, "full of Energy"), the Health Passport's Spa Day stamp with a count (not part of the check-up's stamp order), and sparkles rising off the horse in its next race (consumed when it races, given back if the race aborts). No bond, Rating, care or win chance (tested). Then "🌙 Spa opens again tomorrow", no clock. When a race uses a rider's last Energy and every horse they own is napping: "Great day! Comet's dreaming of tomorrow." after the results. Stable Board daily job "Give a horse a Spa Day" (3 cash + a carrot, like the check-up). A napping horse's Stable Board tip says "Next: a Spa Day at the Vet" (after feeding and grooming). Copy test: no string in `game/src` (the parents' page excepted, which says horses never get sick) contains hurt, sore, injur…, limp or sick. Alternatives considered while building: refusing the Spa for a full horse (a kid who comes to the Spa should never be turned away), a client-only shine via RaceView (the server builds the race horses, so the shine rides with them and replicates), a real-time cooldown (a timer, D-058 rejects it).

## D-059 — Careers, Legend Retirement and Rehoming
- Date: 2026-10-07
- Status: Accepted (provisional)
- Decided by: team, debate 013 (4/4; rehome undo 3–1)
- Context: David: "Horses can age and become less effective, be sold". D-037 rules out ageing, decline and trading; the research shows kid games make age a gain.
- Decision:
  - **No ageing, no decline.** Each horse has a **career** (races, wins, Cups) with a badge every 25 races (`career.badgeEvery = 25`).
  - At 100 races a horse is a **Veteran** and may take an opt-in **Legend Retirement**: it moves to the Hall of Fame paddock beside the owner's barn with a plaque and a glow coat, stays rideable and visitable, and frees its stall. Never forced, never prompted more than once per horse. With breeding (D-047), a Legend passes at most +2 starting Potential to one foal (`career.legacyMax = 2`), after the bloodline sim.
  - **Rehome** at the Market Corral: an NPC pays 50% of what you paid, never more (`rehome.share = 0.5`; tamed and gifted horses pay 0 and get a goodbye rosette). Two-tap confirm and a goodbye card: "Comet is joining Sunny Meadow Riding School!" Undo for 72 h at the same price (`rehome.undoHours = 72`). The starter horse and your last horse can't be rehomed; nor can a horse that's ridden, training, queued or racing.
  - **No player trading**, no auctions.
- Consequences: "sold" exists without loss, and the 50% cap stops buy-and-sell farming. Retiring and rehoming both need the in-use check (D-065).
- Alternatives: decline after N races (loss, unreadable cause and effect); 40% buy-back (Competitive's opening; 50% capped at the price paid is just as safe); 24 h or 48 h undo (too short for weekend players); "going to a farm" copy (parents know it as a death euphemism); player trading (scams, paid-item gating, D-037).
- Links: debate 013, docs/plans/horse-life-and-retention.md (stage 7)

## D-060 — Visiting friends' barns
- Date: 2026-10-07
- Status: Accepted (provisional)
- Decided by: team, debate 013 (4/4 after rebuttal)
- Context: David: "People could go around and visit other users' stables". D-042 set the safety rules, but there's no visit button and nothing to do on a visit.
- Decision:
  - **Map → "Friends' barns":** the faces of Roblox friends in this server whose visit setting lets you in. Tap a face to teleport to their gate (never inside the barn).
  - **Things to do:** pat each horse once for a **Tour stamp** (each friend's stamps count once); one free treat a day (D-042); drop a carrot in the post box (the owner sees an anonymous count). Bond from all visitors is capped at 1 per horse per day (`visit.bondPerHorsePerDay = 1`); pats give no bond.
  - **Owner control:** a one-tap gate button in the dock while anyone is visiting; closing it walks visitors out gently to Barn Lane. "Club" stays hidden until Clubs exist.
  - **Show-off:** the Rosette Wall (D-062) and the Legend paddock (D-059) are what visitors see.
  - **Never:** visitor counts, likes, rankings or guestbook text.
- Consequences: only friends are ever listed, so the teleport can't help a stranger follow a kid. The server keeps refusing every care action on another plot except pat, treat and post box.
- Alternatives: walking Barn Lane with golden hoofprints (a long walk for phone kids; kept as the fallback guide); a list of all barns (strangers); pats that give bond (alt accounts farm Rating, D-014); a "Help a friend" chore (later, if visits catch on).
- Links: debate 013, D-042, docs/plans/horse-life-and-retention.md (stage 5)
- Built (stage 5, 2026-10-07; not yet played in Studio): pure rules in `Visits.luau` (Lune-tested, `tests/luau/visit_tests.luau`) and the live checks in `VisitAccess.luau` (Roblox friendship from the `TrainingFriends` cache, the owner's setting, the gate, standing at the barn). Map → **👫 Friends' barns** lists friends' faces (`GetUserThumbnailAsync`) and names, closed gates greyed; a tap lands you on Barn Lane just outside their gate. Visitors get **Pat** and **Treat** prompts on stall doors and **Drop a carrot** at the post box (`VisitClient`); `CareService.VisitCare` and `StableService.PostBox` re-check everything. Build calls: the Tour stamp comes from patting **every** horse in the barn that day (each friend once, ever; at most 200 stamps); the visit treat is free (nothing leaves the bag), one per friend's barn a day, +1 bond inside `visit.bondPerHorsePerDay`; the carrot leaves the visitor's bag and arrives in the owner's (one per friend a day, `postBoxPerDay = 5`), with a carrot pile on the post box that day and an anonymous toast. The owner's **🚪 Close gate** sits over the dock (its own small screen, not a dock slot, so the phone dock keeps its 3 items) while anyone is visiting or the gate is closed; closing it lays a bar across the gate, turns the walls solid and walks visitors out. A once-a-second server sweep walks out anyone inside a plot who isn't let in (until now only the walls on each screen kept strangers out). The Tour stamp card sits under the Friends' barns list until the Horse Book (stage 6). "Club" stays hidden (counts as Friends). Switches: `GameConfig.visit.enabled`, `visit.mapList`. Art: `rosette_wall` (yard, empty until stage 8), `post_box_carrots`, `visitor_bell` (docs/art/ART_REVIEW.md).

## D-061 — One race button and a visible queue
- Date: 2026-10-07
- Status: Accepted (provisional)
- Decided by: team, debate 013 (4/4 after rebuttal)
- Context: David: "how does the queue work for each [race]?" The audit found a **league lockout**: two course cards, each claimed by the first rider's league; a Rookie can't race while a Bronze rider holds one card and a race runs on the other, and the picker preselects the wrong league's card. Bots sit at the human median ± 6, so training barely shows solo.
- Decision:
  - **"Race with Comet ▶"** joins the queue for the active horse's league and kind (Race, Cup or Practice). Each league-and-kind has its own queue; the server sends a queue to whichever course frees first. The course picker stays as "More choices" (pick a horse, Practice, Cup).
  - **A card for another league never takes a rider:** it shows that league's badge and "Watch" (spectate). `bestCourse` and the picker only pick a course the rider can join.
  - **Show the wait:** a countdown ring, the gate filling with names, "Bots join at 0". `lobbyFillSeconds = 15` (was 20). Kids can groom, ride or visit while queued; "Race time!" brings them to the gate.
  - **Bots by league:** rated at a fixed anchor ± 6: Rookie 50, Bronze 63, Silver 73, Gold 83, Champion 90 (`botRatingAnchor`, `botRatingSpread = 6`; Champion is the moderator's extension). Shipped only if the sim shows a solo Rookie wins 20–35% of races; otherwise the anchors are tuned. Bot names come from the horse-name list, never username-like.
- Consequences: no rider is ever locked out by another league; the longest wait is one race plus results plus 15 s. Training shows in solo races. Changes `RaceService` queueing, not race math.
- Alternatives: grey the unjoinable card only (a Rookie can still be locked out); reserve the next card for a league waiting ≥ 8 s (Competitive's opening, superseded by per-league queues); bots at league midpoint ± 8 (fuzzy for Rookie); separate class queues (more lockouts on 2 courses).
- Links: debate 013, D-036, D-011, docs/plans/horse-life-and-retention.md (stages 1 and 2)
- Built, the core (stage 1, 2026-10-07; not yet played in Studio): `RaceQueues.luau` (pure, Lune-tested) keeps one queue per `league|kind`; RaceService puts a joining rider in their queue and `pumpQueues` (on join, leave and every second) moves riders onto a card already theirs with room, else gives an open course with an empty line to the longest-waiting queue, which claims its card. A picked course is only a wish; a claimed card never takes another league or kind. Waiting riders see "In line! next race". The picker preselects only a joinable card, greys other leagues' cards with their badge and "👀 Watch" (hoofprints to the grandstand), and offers "Join the line!" when none fits. `lobbyFillSeconds` 15. `GameConfig.queue.mode = "cards"` restores D-036 claiming. The one race button, the countdown ring and league-anchored bots are stage 2.
- Built, stage 2 (2026-10-07; not yet played in Studio): **the sim came first and the anchors failed the gate.** `python sims/economy.py --solo` (one rider against 7 bots at anchor ± 6, bots' scores as `GameConfig`, kids at slider 60/70/80 and burst 50/60/70) gave a fresh starter (Rating 46.1) with an average kid **12.2%** solo Rookie wins at Rookie 50. Tuned so a horse entering each league with an average kid wins about 24% (new kid 20–21%, skilled 27–28%) and about 35% at the league's ceiling: **`botRatingAnchor = { Rookie = 32, Bronze = 46, Silver = 56, Gold = 69, Champion = 80 }`**, spread 6 (`tests/test_sims.py` asserts the band, the training lift ≥ 8 points in every league, that the debate's anchors fail, and that the sim and `GameConfig` agree). Alternatives: keep 50 and raise the kid's edge (changes race maths), or tune only Rookie (a promoted kid would win ~11% in Bronze). `RaceSession.fillWithBots(..., { league, nameParts = NameGen })` rates bots by the anchor whoever races and names them from the name chips (two words, unique in the race, never a human's horse name); without a league it is the old median rule. **RACE!** reads "🏁 RACE! with Comet ▶" and joins the active horse's league line at once (`queueCard.oneTapRace`): Practice when it naps outside the free leagues, the Cup when it's past its league's ceiling; the picker became "🔀 More choices", opened from the queue card. **Queue card** (`QueueCard.client.luau`, state in the pure `QueueView.luau`): a 20-dot countdown ring with the big number, 8 gate slots (coat dot + horse name, yours gold with ★), "🤖 Bots join at 0", ✕ and 🔀 More; "Finding a race…" in the league line, "You race next!" while the course races. New remotes `QueueGate` (riders' names and coats) and `RaceTime`: "Race time!" with hoofprints stepping to GO fires 3 s before the gate (`queueCard.raceTimeSeconds`) or when it fills, wherever the kid is; the race seats them and the care card closes. Grooming, riding and visiting work while queued (training rides still wait). Lune: `tests/luau/race_button_tests.luau`. After review: a gate that fills early waits the 3 s "Race time!" before seating; ✕ cancels a call already shown; a one-tap "race" on a horse that can't race falls back to Practice on the server (with a toast) instead of a "resting" refusal; the card is 660 px with 16 px names, scaled down to 0.875 at most. Known gaps, left for the playtest: the sim leaves out the steering trip τ (the per-post baseline keeps it near mean zero for Smart Steer kids, D-054) and the crowd boost (spectators only); Cup races use their league's anchor, so a horse past the ceiling wins its Cup about 35% solo (`docs/plans` stage 8 re-sims the Cup).

## D-062 — Class badges, first-win points and the Rosette Wall
- Date: 2026-10-07
- Status: Accepted (provisional). The Silver Cup target is **not changed** until the economy sim.
- Decided by: team, debate 013 (4/4 on badges and the wall; the Silver target split, sim decides)
- Context: David: "Horse classes to qualify for certain races/prestige?" The research suggests real racing's maiden → allowance → stakes ladder, without claiming races. The audit: Silver Cup at 1,400 points takes about 470 Silver races.
- Decision:
  - **Class badges on one queue per league:** First Win (no wins in this league), Rising Star (fewer than 3), Open, then the league's Cup. They're labels on the picker and the horse card, not separate races, and never affect win chance or demotion (there is none, D-046).
  - **A horse's first win in each league earns +10 League Points** (`leagues.firstWinBonus = 10`).
  - **Silver Cup target:** the economy sim aims for a casual player reaching the Silver Cup in 150–200 Silver races (about 600 points). D-013's values stay until the sim is run and logged.
  - **Prestige:** a **Rosette Wall** in each stable shows rosettes, Cups and Legend plaques; visitors see it; no number. It's filled by private **Stable Star** goal cards (care, collection and skill goals such as "3 races with Great taps"). No claiming races; no public ranking.
- Alternatives: separate condition-race queues (splits fields on 2 courses); Silver at 60–90 races (makes the Cup trivial) or 600–700 points without a sim; a public prestige number (D-042).
- Links: debate 013, D-013, D-046, D-048, docs/plans/horse-life-and-retention.md (stage 8)

## D-063 — Reasons to come back
- Date: 2026-10-07
- Status: Accepted (provisional)
- Decided by: team, debate 013 (4/4)
- Context: David: "make them want to come back". Roblox's guidance: fun within 5 minutes (D1), clear goals (D7), updates every 2–4 weeks and social features (D30). The monthly stamps are half built and lead nowhere.
- Decision:
  - **First 5 minutes:** in a race within 2 minutes of joining (the tour's first GO opens "Race with Comet"); the tour ends on a joyful moment.
  - **Monthly stamps pay out:** 8 stamps give the month's saddle cloth (earned, never sold); every month's cloth comes back in the same month next year. Until the cloths exist, "This month" is hidden.
  - **Horse Book:** coats, breeds, rosettes, courses and Cups, each a silhouette until earned.
  - **Welcome Back Hay Bale:** after 3+ days away, the active horse trots up with a flat gift of hay, seeds and a treat (the same size however long you were away).
  - **Personal bests** per distance ("New best!"), private.
  - **Photo Finish:** a camera button on the win card and in the stable, using CaptureService's own share prompt.
  - **Later:** a free-only Ribbon Trail season with no end date or "last chance" anywhere; a weekend Fun Run that always comes back.
  - **Never:** login streaks, resets, countdowns to an offer, guilt copy.
- Alternatives: a paid season pass (D-050); a login calendar with streaks (rule 3); a welcome-back gift that grows with absence (guilt).
- Links: debate 013, D-043, D-050, docs/plans/horse-life-and-retention.md (stages 3 and 6)

## D-064 — One symbol per meaning, phones first
- Date: 2026-10-07
- Status: Accepted (provisional). Reverses part of D-054's results card ("Good trip" row).
- Decided by: team, debate 013 (4/4 on symbols and floors; 3–1 on the 3-item phone dock)
- Context: the audit found stars meaning 8 things, Energy with 3 looks and ⚡ also meaning Sprint, phone dock buttons rendered about 35 px with 8 px labels, panels at about 10 px text, a picker that reads like a test, and two star rows on the results card.
- Decision:
  - **Symbols:** horseshoe = Energy everywhere (5 pips); ★ = how you rode, only; ❤️ = care; 📣 = fans; 🎀 = monthly stamps; 🌱 = good family line in the market; Sprint = 🐇 Short (⚡ removed).
  - **Phone dock:** horse card, RACE!, ☰ More (everything else in More). Rendered floors: buttons ≥ 56 px, main labels ≥ 16 px, nothing below 14 px; panels re-lay out instead of shrinking under the floor (`ui.minTouchPx = 56`, `ui.minTextPx = 14`, `ui.labelPx = 16`, `ui.dockPhoneItems = 3`).
  - **Results:** one row, "You rode ★★☆", plus "Your taps gained Comet N places!" only when positive. No %, no purse (D-055). The trip folds into the one row.
  - **Words:** picker cards one line, ≤ 5 words, plus the league colour; toasts ≤ 10 words; Grade 3 copy.
  - **One "Next thing" pill** at a time, from the Stable Board's advice. Weekly and monthly jobs show inline, not as a burst of toasts.
- Alternatives: floors only with ≤ 5 dock items (Competitive; `ui.dockPhoneItems = 5`); a win-chance line "12% → 19%" (breaks D-055, reads as odds); a tap-closeness bar (more to read).
- Links: debate 013, D-054, D-055, docs/plans/horse-life-and-retention.md (stages 1 and 3)
- Built, the basics (stage 1, 2026-10-07; not yet played in Studio): `GameConfig.ui` (`minTouchPx` 56, `minTextPx` 14, `labelPx` 16, `dockPhoneItems` 3, `phoneShortSide` 500); `DockLayout` keeps the dock's scale at or above the floors (70 px buttons, the 16 px label and the new 64 px ✕ never render under 56 / 14); on a phone (touch, short side ≤ 500 px) the dock is the horse card, RACE! and ☰ More, and Green Cash, My Horses, the Stable Board, the Map and Ride move into the More panel. Energy is one horseshoe row (`Ui.energyPips`) in the dock, the picker and My Horses; Sprint reads 🐇 Short. The dock's care stars are gone (★ is for riding). The rest (results row, one-line cards, toasts, Next-thing pill) is stage 3.

## D-065 — Playtest-safety fixes
- Date: 2026-10-07
- Status: Accepted (engineering, team)
- Decided by: team, debate 013 (4/4) and the systems audit
- Decision:
  - Each `Profiles.decorators` call runs in `pcall`; a failing decorator is logged and skipped, so ProfileSync always reaches the client.
  - A locked save shows "Opening your stable…" and keeps retrying until the lock goes stale (`LOCK_STALE`, 5 min), with a "Try again" button that rejoins; no kick. Leaving and coming back works as before.
  - No retiring or rehoming a horse that's ridden, training, queued or racing (server check).
  - Taming is scored by the server from its own timestamps.
  - Green Cash and Wins leave public `leaderstats` (D-042: no rankings).
  - The race picker's redraw key includes league, kind and Cup state.
  - Stall assignment is stored per horse, so retiring a stalled horse never moves another one silently.
- Links: docs/research/2026-10-07-systems-audit.md (code health risks), docs/plans/horse-life-and-retention.md (stage 1)
- Built (stage 1, 2026-10-07; not yet played in Studio): `Profile.decoratedView` runs each decorator in `pcall` (Profiles warns once per decorator name: races, jobs, market); `Profiles.load` never kicks: a live lock retries every 10 s until released or stale, DataStore errors back off, and after a lock (or 6 failed tries) the client gets `ProfileWaiting` and GrownUps shows "Opening your stable…" with Try again (TeleportService to the same place); leaving cancels the wait and releases any lock taken. `Leagues.retireBlock` refuses Retire while racing, in line, riding that horse or on a training ride. `PlayerData` no longer makes leaderstats. The picker's redraw key has league, open, Cup and Practice. Not in stage 1 (later stages): server-scored taming, stalls stored per horse.
