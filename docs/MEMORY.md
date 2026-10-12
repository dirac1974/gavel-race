# Memory — Gavel Race

Durable summary of the concept, discussion, and solution. Written so a later session can resume without the original chat.

Date of design session: 2026-07-16. Repo created 2026-10-03.

## Concept

An 8-horse race game. Each horse has fair win probability `q_i` (sum 1). The house posts win odds with a 7% edge, then rounds them. During the race a player may boost their horse by hitting a moving meter while it is in the green zone (the gavel). The boost is not free probability: it is taken from underperforming horses so the house’s expected return on the locked odds stays the same.

An average performer (`S = 50`) always performs at the expected (base) win probability, aside from small ripples caused by other players’ skill.

## Hard rules (final)

1. Payout odds for win and quinella are computed before the race and **cannot change once the race begins**.
2. The house edge must still be maintained after gavel results.
3. Quinella means 1st and 2nd in **either order** (unordered pair).
4. Rounding for posted odds:
   - 5:1 or higher: nearest whole number
   - greater than 2:1 and under 5:1: nearest 0.5
   - 2:1 or under: nearest 1/5 (0.2)
5. Skill should be scaled so a strong player can have expected value over 100% about 20–30% of the time, without moving the posted odds.

Earlier in the session, win odds were specified as rounded **down** to the nearest 0.2 and shown as fifths or halves. The later rounding rule above supersedes that for both win and quinella.

## Solution in one paragraph

Lock decimal odds `o_i` from `q_i` with a 7% overround and the tiered round. Map performance `S_i` to skill `(S_i - 50) / 50`. Desired probability shift is `gamma * skill_i * q_i`. Add an affine correction `a + b * o_i` solved so the sum of shifts is 0 and the sum of shifts times locked odds is 0. Then `p'_i = q_i + delta_i` and win EV is `p'_i * o_i` with `o_i` unchanged. Quinella probabilities are the either-order top-two formula on `p'`, but quinella **payouts** stay at the values computed from base `q` before the race. With `gamma = 0.80` and realized-skill noise `sigma ≈ 0.65`, a high-S horse’s win bet is +EV in roughly a quarter of realizations.

## Decisions

- Equal-stake book on the eight win bets is the invariant: if 1 unit is bet on each horse, expected total payout stays at the pre-race constant `C = sum(q_i * o_i)`.
- Underperformers are horses with skill below 0. Mass is taken in proportion to `q_i` (relative win probability) plus the odds-space correction, which accounts for different payout liabilities.
- Quinella house edge is approximate, not a second exact invariant. Exact win-book invariance is required; quinella odds are locked from base probabilities so they cannot move mid-race.
- `gamma = 0.35` was the first illustrative scale (almost all bets stayed −EV). `gamma = 0.80` is the scale aimed at the 20–30% +EV target.
- Example base field: `q = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04]`.

## Open / not built

- Live race simulation (positions, multiple gavel windows, meter physics).
- Bet-distribution-independent house edge (fixed-odds edge depends on where money lands; the invariant assumes balanced action or is the odds-weighted moment).
- Ordered exacta (specific 1st then 2nd) was discussed and deferred; product is either-order.
- Jurisdiction / gaming-license framing was not part of this design.

## v2 — no-wager game model (2026-10-04)

The model is being used for a kid-friendly Roblox horse racing game. Roblox prohibits simulated and actual gambling, including betting free currency, so the game has no stakes: entry is free and the winner receives a purse locked before the race. v2 replaces the v1 probability adjustment; v1 stays as history. Full detail: [V2_PROPOSAL.md](V2_PROPOSAL.md).

### Why v1 was changed

- The `Σ p'·o = C` constraint rewarded longshots regardless of play (repo example: S = 18 horse 4% → 7.95%).
- The linear shift went negative in about 49% of random races.
- Skill noise blurred the gavel, and it only averages out in a linear model.
- Tiered rounding paid favorites less (expected return 0.875 vs. 0.90–0.96).
- Margin and the "+EV 20–30%" target require a stake.

### v2 decisions

1. Base chance `q = softmax(Rating / T)`, floored at 2.5%; `T` by league (Rookie 22 … Champion 12).
2. Win purse `round(B / q)` in whole cash (D-017; first written as rounding to 5): every horse expects `B` at average play. No margin, no tiered rounding.
3. Window score `100 (1 − d)`, constant-speed meter; `S` = mean of 3 windows.
4. Skill measured against **this race's average**: `R = clamp((S − mean S) / 50, −0.5, 1)`. Same chances as a league median (the tilt is shift-invariant) except at clamp edges; chosen for clarity, no gameable statistic, and lower collusion gain.
5. Exponential tilt `p' ∝ q · e^{κR}`, `κ = 1.0`. Always positive; better timing never lowers your own chance.
6. Finish order by sequential draw (Harville). Flat place prizes 2nd 1.2B, 3rd 0.8B, 4th 0.4B.
7. Quinella dropped (a pair prediction for a payout is a bet).
8. `T` controls how often upsets happen; `κ` controls who earns them.
9. Exact per-race cash invariance traded for ~0.2–0.5% drift, absorbed by `B`.
10. Party members never share a cash race.

### Open

- Set `κ` and `T` from playtests.
- Reserve dial `α` (`Purse ∝ q^(−α)`) if training needs to pay more win cash.

## Agent team and game build (2026-10-04)

David delegated design decisions to the team for later review (D-009). Claude Code agents now carry the project: an engineering team (model, Roblox, test, review, economy, scribe) and a design council (moderator, four designers, researcher). Rules and the build loop are in `CLAUDE.md`; decisions in `docs/memory/DECISIONS.md`; provisional ones awaiting David in `docs/memory/REVIEW_QUEUE.md`.

Built so far: Python and Luau race math with exact parity, a Rojo Phase 1 prototype (meter, race session, server loop, client UI; not yet run in Studio), Race Rating from stats and conditions, an economy simulator that set Stakes thresholds, and debate 001 on gavel feel.

## AAA review (2026-10-11)

Four reviewers (gameplay, UI/UX, systems, feel) reviewed the race and UI blind, then voted on every fix; only fixes all four backed are built, in four phases (`docs/reviews/aaa-2026-10-11/CONSENSUS.md`, D-066 to D-069). The ground rules: effects are draw-only and never touch the score, order or trip; one owner for camera kicks; no longer races; kind copy; no new systems.

Phase 1 (D-066, race feel and sound) is built: a tap now ticks, nudges your horse, and on a Perfect surges with dust; the hoofbeats and body bob follow the legs; the Final Burst ignores taps for its first half second so a reflex tap can't spend it; the HUD clears the phone steering pad and says RIDING. Sound comes from synthesized stand-ins in one uploaded sheet until the ElevenLabs key gets Sound Effects access. Live pace previews were deferred because they'd change the steering calibration. Nothing has been played or listened to in Studio yet.

Phase 2 (D-067, results, finish and the first minute) is built: horses gallop out past the line, the camera swings to the side view, 1st gets confetti and 1st–4th a ribbon stamp, and the card comes up within 4 s with kind words for every place, a 🏁 Race again button and "Best ride" for the top 3. The first race coaches the tap rule, the tour owns the first minute (one card at a time, toasts and the 💎 pill wait), the phone queue card is one row with a Warm up slider, and every panel keeps the size and contrast floors. After the far-turn lock, taps move horses on screen once a second. Still open: previews before the lock (so the "do taps change the result?" playtest question has a known gap) and whether Practice races should count toward race jobs. Nothing has been played in Studio yet.

Phase 3 (D-068, progression and friends) is built: the league ladder was retuned on realistic training (weaker bots in the upper leagues, Cups at 100/200/450/900 points), so a casual kid reaches Champion in about 12 weeks instead of 37. Practice is one open queue for every league, run at Rookie settings with equal horses, and "🎈 Race with [friend]" follows a Roblox friend into their Practice race without sending them anything. A Legend can come back to racing, the game no longer suggests retiring at 100 races, and one switch (`corePlaytest`) turns off the meta systems for a race-only playtest. Words now mean one thing each (career patch, training medals, Tour pins). Still open: a Green Cash sink before any soft launch (players earn far more than they can spend), the Champion endgame (win rates climb toward 54% as horses keep training), per-league bot tapping scores, and whether Practice counts toward race jobs. Nothing has been played in Studio yet.

Phase 4 (D-069, presentation and world) is built: jockeys crouch and pump in time with the stride, the track is dressed for a county fair (bunting, flags, a bouncing painted crowd) from four small images and code, with no Meshy credits spent, and the Big Board shows the top 4 names. A short camera pass along the gate plays inside the 3-second countdown and cuts to the chase view. The race HUD uses the art direction's paper, ink and gold, so the tap copy says "the glow". Your own YOU marker is hidden in the chase view. The stars count in with rising ticks and the confetti is paper. The music bed is built but silent until David picks a beatless track from Roblox's free library. The stand-in sound sheet is now approved, so the race has sound.

Where the run ended (2026-10-11): all four phases are built, reviewed and signed off by the four reviewers for David's Studio playtest, which should start with `corePlaytest = true`. Still open: previews before the far-turn lock (the "do my taps matter?" question), a Green Cash sink before any soft launch, the burst bar sitting over the horse, per-league bot tapping scores, the Champion endgame, a handful of word meanings, and Studio tuning of the jockey pose, gate framing and bunting. Process note: two commits on the branch (bed9d9e, 67f503f) named a specific Claude model in their trailer; history stays as it is, and the policy guard now checks commit messages.

## Green Cash sink (2026-10-11)

After the run, two plans followed on branch `claude/green-cash-and-taps`: a Green Cash sink (D-070) and previews before the far-turn lock (D-071). For Green Cash, the faster ladder meant a casual kid had about 106k by week 12 with only 7,100 of stalls to buy. Now purses are flatter (B 20/30/45/65/85, was 20/50/120/300/750), and a new 💵-only Barn Builder counter at Feed & Seed sells 35 yard and barn cosmetics (250–6,000, about 45k in all) on five shelves that open by the best league a stable has ever reached. Nothing for sale looks like a win, Tack & Paint stays 💎 only, builds get a small "go see it" moment, a wish shows as a fill bar, and nothing is suggested or sold near a race. The sim shows the next item affordable every session and no pile before Champion. Still open: engaged kids pile up cash after Champion (accepted for launch; a milestone Champion Workshop and breeding fees later), and a multi-horse sim before soft launch.

## Tap preview (2026-10-11)

The AAA review's biggest gameplay gap was that taps didn't visibly move your horse until a checkpoint closed or the far-turn lock. D-071 adds a draw-only layer on the server: from the gate, good taps edge your horse ahead on every screen within about 2 s, at most about a length and a half, and the race itself is exactly the same with it on or off (same scores, lanes, order and prizes; it never shows luck). Only your own taps move your horse; the others' real scores arrive at each checkpoint as before. A silent "Giddy-up! Moving up!" floats over your horse for gains only, never "pulling away" or "winning". About half the time your gain is held behind a horse in your lane (Smart Steer keeps riders in tight columns); then your horse leans and kicks up dust, and a chip says "Room this way! ◀/▶" or "Keep tapping! Room soon.". Sixteen automated gates run in CI. Both features are built, reviewed and signed off by the four designers and wait on David's Studio playtest. Still open: a study of Smart Steer finding room on its own, which changes steering and needs David's approval (OPEN_QUESTIONS 8), and a lock fade with little headroom.

## Race realism (2026-10-12)

David played the race in Studio for the first time and found the jump went straight up, the arrow keys turned the camera, and the horses kept their lanes all race. He asked for horses that file in to the rail and pass when they get the chance, a stored "move" to pass, neighbours who can block you in, and a jumping race. D-074 makes a hop always go forward with a tucked-leg air pose (never forward in the Gate Break stall). D-072 makes the field race: riders and bots file to the rail, run in styles with drift, pass mostly on the straights, and bots sometimes shut the door; the ◀ ▶ buttons show from race 1 and the keys never turn the camera. Phase A is built but its baseline calibration ran out of memory, so it can't be played until the full sim write runs. The move (phase B, counting behind `steering.move.scale`) and Hurdles (D-073, Practice-only first) are deferred until after the next playtest. David decided that in Hurdles nobody passes and every horse keeps its post lane.

## Fun and return (2026-10-12)

David asked for a pass to make the game more fun for kids and make them come back, and he decided four things himself: over-running can need the vet (but never sick), horses age and get less effective and can be sold, players can visit other users' stables, and the queue must be explained. Much of what he asked about already existed but he hadn't found it, so finding things came first. D-075 puts all 13 places on the Map, makes GO open the feature, gives phones a 5-item dock, names the queue line with a 3-picture "how racing works" strip, and adds paced "New!" pointers and a signpost built in code. D-076 shows progress: a class path (First Win, Rising Star, Open, Top Horse, Cup), a Cup bar and a small class-up ceremony; "Stakes" was dropped as a wagering word, and Top Horse becomes "Big Race" when named races exist. D-077: after 6 counted races in a row on one horse (from its 26th race), rated races wait for a free 30-second Cool-down Check at the vet with leg wraps and a carrot; feeding, grooming, rest, the Spa or training lower the count, and no game text says hurt or sick. D-078: horses are Young, Prime, Veteran (350 races) and Legend; decline starts only once a horse has 350 races and is near its peak, at most −4 Rating, and the sims say very few players will ever see it; the Riding School lets kids lend a horse for free or sell it for half its price plus a small capped bonus, so selling never makes money. D-079: owners choose Friends, Everyone here or Nobody; strangers may only look, take a tour, pat and send preset cheers, only where Roblox's content-sharing policy allows, and owners can ask one visitor to leave. All five phases are built and reviewed, with 0 Meshy credits spent; nothing has been played in Studio. Derby Day was not built (mild FOMO), and named races, the winner's circle, rivals, the retirement ceremony and breeding wait for the next build. Next is David's playtest.

## Breeding (2026-10-12)

David said "Build the breeding now." D-080 adds the 💞 Foal Barn: two of your own horses (30+ races each, one at Bronze or higher, Legends welcome) can have a foal for 400 to 2,500 Green Cash, never Diamonds. There are no genders, just "parents" (a question for David after the playtest). Before paying, the card shows every coat the foal can have and its chance (each parent's coat 45%, a named Surprise 10%); the foal is rolled once on the server when you confirm. A stable gets one foal per 60 races, and the foal arrives after 8 races or the next day you play, with no clock. It steps out and nuzzles its parent (nothing birth-like), gets a name from word chips, and starts as a small 🍼 Young horse in Rookie at 60% of its Potential, capped at 50 so it still plays the Rookie ladder. A foal sold at once always returns less than its fee. This changes D-047's numbers (35% start, 0.7/75 mix) after the sims: bloodlines settle between the Market middle and top tier and never run away. Words like mare, stallion, birth and blood are banned in game copy. Built and reviewed, 0 Meshy credits; the foal-legs fix and a few review fixes remain, then the test run and David's playtest.
