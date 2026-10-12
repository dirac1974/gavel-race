# Systems consult: built Phase 3 (2026-10-11, lead)

I read the diff of `Leagues.luau`, `RaceQueues.luau` and `Career.luau`, RaceService's `JoinRace` and `friendPracticeCourse`, `phase3-words.md`, PLAYTEST "AAA Phase 3", and the light-profile sim tests.

## Ladder

The values landed as signed off. The light-player condition I asked for is tested (`test_phase3_light_player_never_stuck`, Champion by week 20). The PLAYTEST note on old saves above the ceiling is what I asked for. Nothing more is needed.

## MUST-FIX

1. **Open Practice runs at the first rider's league difficulty.**
   - `RaceQueues.key` collapses all leagues into `Open|practice`, but the claimed card keeps the first rider's league. `RaceSession` then uses that league's whole spec for everyone: sweep, drifting target, stride tempo, T and bots.
   - So a Rookie who taps "🎈 Race with Maple" behind a Gold friend gets Gold's 1.3 s drifting slider. A Champion friend means two targets in the Final Burst. That ruins the friend race and the kid's first look at the higher leagues.
   - **Fix (config-backed):** add `queue.openPracticeLeague = "Rookie"`. When `openPractice` is on, an Open Practice card is always claimed with that league's spec and bots, whoever came first. It pays nothing, so this has no fairness or economy effect.
   - Update the PLAYTEST line "The card takes the first rider's league" to match.

## SHOULD-FIX

1. **Friend races are decided by the horse.** In Open Practice, a Rating 80 Champion horse against a Rating 47 starter, even at Rookie's T = 22, is close to a foregone result.
   - Add `queue.openPracticeEqualHorses = true`: every lane in an Open Practice race gets the same base chance, so taps and the trip decide it.
   - No prize, no Diamonds, and it changes race math only on prize-free cards. Log it as provisional under D-068 and check Python parity.
2. **"Race with [name]" when the friend isn't in a Practice line.** `friendPracticeCourse` returns nil and the kid joins Open Practice without the friend, with no message.
   - Show "Maple is in a Bronze race. 👀 Watch" instead. Or keep the join, toast "You're in Practice. Maple can join you!", and let the single Open queue bring them together.
3. **Unretire into a full barn.** The horse lands in the pasture and can't race. Toast "Comet is in the pasture. Free a stall to race!" and point the pill at My Horses.
4. **The plaque comes down on unretire.** I accept the team's call: the horse isn't retired, and retiring again puts a plaque back. But it breaks StableStar's "what's earned stays earned" header. Update that comment and log the exception in D-068.
5. **Words left over:** 🎀 monthly stamps should become **bows**, and the goodbye rosettes should hang on the Rosette Wall. I agree with the engineer's suggestions. Queue both as one design call (REVIEW_QUEUE), not more renames now.
6. **The starter as a Legend:** fine now that unretire exists. No change needed.

## For the scribe to log, exactly

1. **STATUS → Launch gates:** "Before any soft launch, a Green Cash sink.
   - First, Green Cash cosmetics in `Style` (`currency = "cash"`, 500–5,000).
   - Then purse flattening (`leagues[*].B`), re-checked with `sims/economy.py --ladder`.
   - Reason: under the D-068 ladder a casual kid earns about 106k Green Cash by week 12, against 7,100 of total sinks."
2. **REVIEW_QUEUE → Champion endgame (D-068, provisional):** "Champion has no ceiling. An average kid's win rate there rises from about 25% (week 12) to about 54% at the plateau (week 26+).
   - Preferred fix: Legend and breeding goals as the Champion aim.
   - Rejected: bots that follow the rider's Rating (makes training invisible, D-061).
   - Revisit after the playtest."
3. **REVIEW_QUEUE → Word meanings:** bows for 🎀 monthly stamps; goodbye rosettes hang on the Wall; Horse Book "Rosettes" page → "Prizes".
4. **DECISIONS D-068:**
   - the Open Practice difficulty rule (must-fix 1);
   - `openPracticeEqualHorses`, if built;
   - unretire removes the plaque;
   - Practice counts toward "race" jobs (Phase 2 consult, should-fix 3).

## Sign-off

**YES**, once must-fix 1 is in. The ladder, `corePlaytest`, Legend undo and the word pass are approved as built.
