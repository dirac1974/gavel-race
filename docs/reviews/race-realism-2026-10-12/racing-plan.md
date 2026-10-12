# Race realism plan: filing in, passing, the move, boxed in (D-072, provisional)

Owner: gameplay. Responds to David's first Studio playtest (brief.md). The jump and steeplechase are out of scope here.

## 0. What the architecture allows

The outcome is a draw: `T = L / p_live` (D-033). Positions on screen are choreography over that draw.
- Before the far-turn lock they show skill only.
- After it they blend toward the drawn order.

So "passing" can never be physics that decides the race, and pretending it is would break D-033/D-055 honesty. What we *can* do:
- **Draw** a realistic pack: filing to the rail, flowing, passing, doors shutting. All of it is luck-free.
- **Let the rider's steering and a "move" earn a small, honest τ** before the lock, as the trip already does.

Today's columns are partly our own doing. Smart Steer stops at lane 2 and never moves out. `hold` sits horses 10 ft behind the horse ahead. **The draft term rewards sitting in a column** (`Trip.luau:770-790`). Realism needs passing to be worth something too.

## 1. How the field behaves

### 1a. Filing to the rail (Trip decisions; luck-free)
- `steering.smart.homeLane` 2 → **1**.
- Bot home lanes: `bots.railShare` 0.25 → **0.5** (lane 1), new `bots.secondShare 0.35` (lane 2), `bots.wideShare` 0.20 → **0.15** (lane 3).
- New `smart.fileAfterBreak = { from = 2, by = 12 }` (seconds). Smart Steer and bots head in whenever there's room from 2 s to 12 s after the gate, on straights too. Today they only head in near turns (`Trip.luau:723-728`).
- Every D-057 press, wait, reverse and weave rule still applies.

### 1b. A flowing pack, not columns
New `steering.pack`. Values are drawn at the gate, after every existing draw (so posts, luck, bot scores and passes keep their values, as D-054 did). They enter Trip's skill target as extra feet:
- **Running style per horse:** front 30% `+14 ft`, stalker 40% `0`, closer 30% `−14 ft`, fading linearly to 0 at the lock.
  - Riders get the stalker style. Smart Steer kids are never parked at the back.
- **Drift:** `±6 ft`, a smooth seeded sine with a period of 8–16 s, so neighbours keep swapping by half-lengths.
- **Stagger:** a horse in lane 2 sits `4 ft` off the half-length point of the horse inside it. That gives two-wide pairs, not side-by-side rows.

These are luck-free and skill-free, so they change lanes and therefore ground and draft. That means a **new τ baseline per post *and* per style** (`TripBaseline` gains a style row). The gate is per-style bias ≤ 0.002.

### 1c. Passing when the chance comes (Trip decisions)
New `steering.pass`. A bot, or a Smart Steer rider who has made no press for `resumeSeconds`, moves **out** one lane when all of these hold:
- its target is ≥ `triggerFeet 6` ahead of the horse blocking it in its lane, for ≥ `triggerSeconds 0.8`;
- the outside slot has `clearFeet` room;
- a roll from its own pre-drawn tendency (`straightChance 1.0`, `turnChance 0.25`, so passes happen on the straights) says go.

After `returnClearFeet 10` ahead of the passed horse, it heads back in (1a). At most `maxPassesPerHorse 4` a race.

### 1d. Neighbours shut the door
- Each bot draws `shut ∈ [0, 1]` at the gate.
- When a horse alongside (`brushAlongFeet 8`) tries to move into the bot's lane slot, a bot with `shut < shutChance 0.3` holds its line for `shutSeconds 1.5`: the move waits or drops (the D-057 wait rules).
- Bots never shut on a rider in their first 3 races (kid safety: early races are for learning).
- No brushes come from this. Bots still never brush.

### 1e. The lane lock: stays at the far-turn entry for the outcome
- Luck starts showing at the far turn. Any τ measured after it would see luck-driven positions, which would break D-054's "the trip never sees luck".
- After the lock, lanes keep moving **draw-only**. `Trip.cosmetic` already swings passers out. Tune it to use the outside lane on the stretch straight.
- New key `steering.lockAt = "farTurnEntry"` (the only value for now). Moving the lock and the luck blend later *together* is a later study (§6, D).

| Piece | Draw-only or outcome |
| --- | --- |
| Styles, drift, stagger, filing, bot passes, shut doors | Trip decisions → lanes → ground and draft τ (outcome, recalibrated, luck-free) |
| Everything after the lock | Draw-only |
| Rider presses | Outcome (τ) |
| The move | Outcome, small (§3) |

## 2. Steering from race 1

- `steering.introRaces` 3 → **0**: the ◀ ▶ buttons show from the first race, with Smart Steer on.
  - Riders' τ counts from race 1 (Smart Steer kids already earn a fair τ through the per-post baseline).
  - The ghost-thumb tip moves to race 2. Race 1 belongs to the slider coaching.
- **Keys always bound while riding** (`steering.keysAlways = true`): A/D, the arrows and the D-pad are sunk from the gate to the finish, so they never turn the camera. That's the fix already in progress.
- **Response within one frame:**
  - the existing 3° look cue on press;
  - the glide starting on the next server tick (≤ 0.1 s);
  - a wait shows the ring and wobble.
- After the lock, presses get the look cue plus "Lanes locked!" once. No fake glide.

## 3. The move ("save some for the move")

Rename: it's a **move**, never "energy". D-015's horse Energy stays out of speed, and the two must not share a word.

- **Banking:** `steering.move.pipEveryClean = 4`. Every 4 single-tapped pace passes scoring ≥ `pipMinScore 80` bank one pip, up to `maxPips 3`.
  - A masher's doubled passes earn nothing.
  - Pips come from taps only, reset every race, can't be bought or kept, and Diamonds never touch them.
- **Lit:** a pip ready, a horse ahead in your lane within `aheadFeet 20`, and a side with room → that arrow glows gold.
- **Spend:** a press toward room with a pip is a move.
  - The lane change uses the D-057 glide.
  - Trip gives the horse `surgeFeet 9` extra target, ramped over `surgeSeconds 1.2`, kept until the lock. Trip state changes, so it's in parity.
  - The pip is spent only when the glide starts.
- **Denied:** the slot fails `clearFeet`, or a neighbour shuts the door (§1d), at the moment of the press.
  - The pip is **kept**, "Door shut! Try again" shows, and a retry is allowed after `deniedRetrySeconds 1.0`.
  - Target: 20–35% of attempts denied for a kid who presses when lit; ≤ 50% for a kid who presses any time.
- **Outcome:** an own term, like the brush charge: `tauMove_i = min(movesDone_i, maxCounted 2) · tauPerMove 0.008`, clamped to `[0, ceiling 0.016]`.
  - It's added after the trip clamp, giving a total τ range of −0.02 … +0.056.
  - It's worth at most about 0.8 S points: about a third of the best trip, about 1/40 of the tap edge.
  - Upsets stay alive, and solo win rates move by under half a point. The sim confirms (§4).
- **Final Burst:** no stacking. Moves end at the lock. Unspent pips are drawn as extra sparkle on a Great+ burst and nothing more.
- **Smart Steer riders:** Smart Steer spends **one** pip a race, only on a straight with clear room (never denied). It counts once. Manual riders can count 2.
- **Griefing:** a move press is one press, and brushes still need the third press. A human never shuts the door (only bots draw `shut`). The D-057 griefing gates are re-run.

## 4. Python model, parity and simulations

**Code changes**
- **`src/trip.py`:** pack (styles, drift, stagger), filing, the pass rule, shut doors, the move (pips from a pass-score list, surge, denial, `tau_move`), the style baseline. `CONFIG` mirrors `GameConfig.steering`.
- **`src/gavel_race_v2.py`:** no change. τ still enters as `extra`. Add a comment that `extra` includes `tauMove`.
- **Fixtures:** `make_fixtures.py --d072` → `trip_d072.json`. `Trip.luau` must match to 1e-9 on 50 runs plus 12 edge runs (move denied, move at the lock tick, a masher, shut doors).
- **`sims/steering.py --profile d072`:** regenerate `TripBaseline.luau` (post × style).

**Sim gates.** Bots at anchor ± 6, scores sd 15, 2,000 races per course × distance.

| Gate | Target |
| --- | --- |
| Win rate by skill (solo, Rookie) | new kid ≥ 19%, average 24–27%, perfect ≤ 38% (today 35%) |
| Upsets | bottom-half winners and longest-shot wins within ±1 pt of today |
| Post fairness | per-post τ bias ≤ 0.002; per-style ≤ 0.002 |
| D-054 τ targets, D-057 targets | every cell passes |
| Boxed share (realistic Rookie Mile, D-071 harness) | **≤ 35%** (today 48.6–53%) |
| Move denied | 20–35% of attempts (press-when-lit kid); masher gets 0 pips and 0 moves |
| Passes per race | 3–10 drawn passes, ≥ 60% of them on straights |
| Overlap report d057 and the tap-preview report | 0 overlaps, 0 jerks, every D-071 gate |
| Economy | `sims/economy.py --solo` and `--ladder phase3` within ±1 pt; no retune needed |

## 5. Phone UX

**Layout**
- ◀ In and Out ▶ stay bottom-left at 88 px.
- Three 20 px gold horseshoe pips sit in a row above the pad, filling one by one as the tap word lands ("Great!").

**When a move is lit**
- The arrow toward room gets a gold rim and a 2 Hz pulse (static gold under Reduced Motion).
- The button reads "Go! ▶".

**What the move looks and sounds like**

| Moment | Look | Sound |
| --- | --- | --- |
| Pip fills | pip fills | `move_ready` soft chime |
| Move | 3° lean into the lane, a dust burst, a 1.5° FOV kick inside the D-066 budget | `move_go` whoosh |
| Denied | the arrow wobbles | `move_shut` soft wooden tock |

There's never anything red.

**Copy** (6 words at most)

| When | Words |
| --- | --- |
| First pip ever | "Good taps fill your move!" |
| Pip filled | "Move ready!" |
| Lit | "Make your move! ▶" (replaces D-071's "Find a gap!" when a pip is ready) |
| Success | "Moved up!" |
| Denied | "Door shut! Try again" |
| Results, when the move's τ gained a place | "Your move gained Comet 1 place!" (`ResultsText.gainedLine` gains "move") |

Never the words "blocked", "boxed" or "energy".

## 6. Phasing

- **A. Playtestable slice (first):**
  - keys always bound;
  - buttons from race 1;
  - filing to the rail;
  - pack styles, drift and stagger;
  - bot passing on straights;
  - shut doors.

  Recalibrate the baseline. Gates: §4 minus the move rows.
  - **David's check:** "they file in and pass."
- **B. The move, cosmetic:** `move.scale = 0`. Pips, lit arrows, the surge, denial and copy all work, with no τ. Playtest the feel and the denial rate.
- **C. The move, counting:** `move.scale = 1`, `tauPerMove 0.008` after the parity and sim gates. Needs David's approval.
- **D. Studies:**
  - the lock and the luck blend moved later together;
  - a steeplechase or straight course (a separate plan).

## 7. Risks and hard rules

- **No wagering:** no rule is touched.
- **Diamonds:** they buy no move, pip or style.
- **Kid safety:**
  - no shaming copy;
  - doors are never shut on first-race riders;
  - no red;
  - no timers.
- **Honesty:**
  - the results card credits a move only when its τ flipped a place (`tripGain` logic);
  - the pre-lock pack is luck-free;
  - the order at the line is still the result.
- **Biggest risk: overselling.** Kids may believe steering decides more than it does. Keep the move small and the copy factual, and let "Best ride" plus the taps stay the hero.
- Every key above is `Accepted (provisional)` under D-072. The switch-back is `pack.enabled = false`, `pass.enabled = false`, `move.enabled = false`, `introRaces = 3` and `homeLane = 2`, which together give today's race exactly.
