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
