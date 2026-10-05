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

