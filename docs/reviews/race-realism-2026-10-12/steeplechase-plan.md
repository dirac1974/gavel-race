# Plan: the forward jump and a jumping race (D-072 provisional)

Owner: systems designer, 2026-10-12. Source: David's first Studio playtest (brief.md).

- Passing, the rail and the stored "move" belong to racing-plan.md (gameplay). This plan only says where fences and passing must not fight.
- Every new value lives in config, and each decision is logged `Accepted (provisional)`.

## Decision in one line

Fix the jump now. Ship **Hurdles**, a low-brush jumping race on the existing turf course, as a Practice-only slice first, then as rated races from Bronze. Build the **Straightaway Dash** only after passing (racing-plan) lands.

**Why not the Dash first.** It is nearly free to build: the turf home straight is 1,320 ft, a true quarter mile. But it adds no new verb. Today it would be about 24 s of the same slider with nobody passing, which is exactly what David disliked.

**Why Hurdles.** Fences add a new skill and finally give training a race purpose: Mud Splash already teaches hopping logs on Grit. That makes it the one race type that makes the systems more coherent rather than wider.

## 1. The forward jump (free riding and training)

Today the jump is the stock `Humanoid.Jump` (JumpPower 42, `Rides.luau:254`): straight up, legs still cycling.

**Numbers (`GameConfig.riding.hop`):**

| Key | Value | Why |
| --- | --- | --- |
| `jumpPower` | **38** (was 42) | Peak height 38² / (2 × 196.2) = **3.7 studs**, about 45% of the 8-stud horse. 4.5 read as a pogo. |
| `forwardMin` | **14 studs/s** | From a standstill the horse always travels forward. |
| `forwardBoost` | **+4 studs/s** | Added to the current speed while airborne. |
| `forwardCap` | `training.maxSpeed − 2` (51) | Never trips the training ride's 53 studs/s teleport check. |
| `cooldownSeconds` | 0.6 | No bunny-hopping. |
| airtime | 2 × 38 / 196.2 ≈ **0.39 s** | |

**Arc length (forward travel while airborne):**

| From | Speed | Arc |
| --- | --- | --- |
| Standstill | 14 | ~5.5 studs (about 2/3 of a body length) |
| Trot | about 20 + 4 | ~9 studs |
| Arena lope | 28 + 4 | ~12.5 studs |
| Gallop | 46 + 4 | **~19.5 studs (about 2.4 lengths)** |

- **Pose** (`HorseLegs.airPose`): forelegs folded up, hind legs trailing, body pitches 6° nose-up at takeoff and 4° nose-down on the way down. The legs stop cycling in the air. On landing, the body squashes to 0.96 for 80 ms and plays a soft thud and a dust puff.
- **Reduced Motion:** pitch and squash off, the folded legs stay.
- **Mud Splash must still clear.** A log counts at `y ≥ 1.5` within `logWindow` 3 studs (`TrainingRide.luau:415`).
  - At JumpPower 38 the horse is above 1.5 studs from t = 0.045 to 0.343 s. That is 0.30 s × the 28 studs/s lope ≈ **8.3 studs** over the 6-stud log window.
  - Set `TC.RIDE_HOP = 38² / (2 × 196.2) ≈ 3.68`, and **derive it** from `GameConfig.riding.hop.jumpPower` instead of hard-coding it.
- **Tests:**
  - a Lune check that `RIDE_HOP` equals the derived value;
  - a sim of a hop taken 0–2 studs before a log at lope speed that clears it in 100% of takeoffs from 4 studs before to 1 stud before;
  - the training speed check never fires on a hop at gallop.

## 2. Hurdles: the race type

### Course (built in code, 0 Meshy)

- **Course:** the turf course (D-036), Mile and Classic only.
- **Fences on straights only.** On a straight every lane shares the same rail distance `s`, so a fence is fair to every post with no per-post correction. In turns, outer lanes would meet the fence later.
- **Mile: 3 fences on the backstretch**, at 25%, 50% and 75% of it.
- **Classic: those 3 plus 2 on the first pass of the home straight.** None on the final home straight: that's where the Final Burst and the stretch drive live.
- **Fence look:**
  - a brush hurdle spanning all 8 lanes, about 3.5 ft tall at toy scale: a green "brush" box with a white top rail;
  - painted wing posts at each rail;
  - a flag on each wing (reusing the D-069 pennant).
- **Never solid timber.** Brush bends on a clumsy jump (`brushFlex`) and never stops a horse.
- **Meshy:** only if the code version reads badly in Studio. In that case, one `hurdle_brush` text-to-3D at 30 credits (cap 37).

### The skill check: one tap per fence

**No extra button.** The tap button (Space or a screen tap) does the jump.
- From `fence.leadSeconds` (1.6 s) before each fence to 0.4 s after it, the pace slider pauses, as it does before the burst.
- The **takeoff ring** closes around your horse's front hooves, in the world, not on a HUD bar. That puts eyes on the horse, which also answers the feel review.

**Timing is set by the server.**
- The ring closes when the *server's* rider reaches the takeoff point. That is `TapTime`-resolved with the D-021 latency allowance, exactly as for stride beats.
- The drawn horse can be up to about 17 ft ahead on your own screen (tap preview plus nudge), so the ring is anchored to the horse, never to a strip on the ground.

**Score:**
- The score uses the stride rule: a window around the ring's close (`fence.halfWindowSeconds`).
- Window widths by league: Rookie practice 0.18 s, Bronze 0.16, Silver 0.14, Gold 0.12, Champion 0.11.
- Score is 100 × closeness. One tap per fence. It arms at ring start. A tap before the ring is ignored and doesn't use up the fence.
- To blunt a fixed-delay macro, the ring's close time is randomised per fence (1.0–1.4 s, `fence.ringMin`/`ringMax`).

**What the horse does:**

| Tap | Score | On screen |
| --- | --- | --- |
| Clean | 70 and up | "Clean jump!" A full arc. |
| Okay | 30–69 | "Bumpy jump!" A lower arc, the brush flicks. |
| Missed or no tap | 0 | "Hop!" The horse still jumps on its own, a small hop. |

- **Never:** a fall, a refusal, an unseated rider, a stumble, a limp, or the words fall, crash, refuse or unseat (add them to the copy test).
- A clumsy jump costs only score, plus a drawn slow-down of at most 3 ft that eases back, inside the D-071 limits.

### Outcome math (Python model and parity)

- **A new segment kind, `fence`, in `RaceSession`.** Each fence is its own segment, so live chances update after every fence (a visible reward).
- **Mile Hurdles segments:** `pace, fence, fence, fence, pace, burst, pace`.
- **Weights:** pace 1, **fence 1/3 each** (the fences together weigh one pace segment), burst 2.
- **Total weight 6** (5 on flat), so the burst stays at a third of the score instead of 40%. That's a deliberate small dilution, and κ is unchanged. The sim checks the premium.
- **Rating weights for the Hurdles condition:** shift `grit +0.15, accel +0.05` (like Rain). Training Grit in Mud Splash now matters in races.
- **Bots:** fence scores `Normal(botFenceMean 55, sd 15)` like the burst, drawn at the gate. The drawn arc follows their score.
- **Python side:**
  - add `src/fence_meter.py`, mirroring `FenceMeter.luau` (window scoring and arming);
  - `segments` and `weights` become per-course in both the Python model and Luau;
  - parity fixtures get 200 Hurdles races (scores, live chances at every close, finish order, purses).
- **τ and the lock:** see "Passing" below.

### Passing and steering (align with racing-plan)

- **Fence zones:** from 60 ft before a fence to 30 ft after, a horse holds its lane. No lane changes, no "move", no brushes. Real jockeys straighten for a fence.
- A press in a fence zone waits until the zone ends (D-057 wait rules) and is never dropped silently.
- The fence zones take about 4 s from each straight. **The racing-plan owner must confirm** that the passing windows and the stored "move" exclude fence zones. This is the one coupling between the plans.

### Controls

- **Phone:** the tap is anywhere outside the ◀ ▶ pad, as today. There is no new jump button, so nothing collides.
- **Keyboard:** Space or Enter taps; A/D or the arrows steer.
- **Gamepad:** A or R2 taps; the D-pad steers.
- Steering buttons grey out inside fence zones (the D-057 grey and wait ring).
- In free riding, the jump stays on Roblox's own jump button (Space). Races never use `Humanoid.Jump`.

### Picker, leagues, purses, queues

- **A condition, not a new queue.** Splitting queues again would empty fields. Hurdles is a turf-card condition, like weather, at `steeple.share = 0.25` of rated turf cards from **Bronze** up.
- **Rookie:** never rated Hurdles. **Practice Hurdles** is open to everyone (Open Practice, Rookie settings).
- **Card and queue card:** a 🐎 fence icon and "Hurdles".
- **First time:** a kid's first Hurdles race shows coaching ("Tap when the ring closes!") over the first fence.
- **Rewards are the same as flat races:** same B, League Points and Energy cost. **Cups stay flat.**
- **The Horse Book** gets a Hurdles course page entry, and the Stable Star goal "Clear 10 clean jumps" goes in as a collection or skill goal.
- **No new currency or item.** Nothing jump-related is ever sold for 💎 or 💵.

### Camera and sound

- **Camera:** on a fence approach the chase camera rises 1.5 studs and the FOV opens +2° inside the D-066 6° cap. No slow motion. Replays and spectators get a side camera at each fence. Under Reduced Motion: none of this.
- **Sound** (stand-ins on the sound sheet): `fence_takeoff` whoosh, `brush_swish`, `fence_land` soft thud, and a crowd "ooh" on a clean jump within earshot. No new upload is needed.

### Test gates and sims

**`sims/steeple.py`, plus `--ladder`/`--solo` with the Hurdles condition:**
- **Skill premium:** perfect vs new rider wins and cash per race within ±10% of flat Mile.
- **Upset rate:** the lowest-q winner share within ±1 point of flat.
- **Per-post win rate:** bias ≤ 0.002, which needs fences on straights.
- **Solo entry win rate:** 20–35% in every league.
- **Macros:** a fixed-delay clicker scores at or below an average kid on fences.
- **Grit:** +5 Grit raises Hurdles Rating by about 1 point and has no effect on flat Sprint.

**Lune:**
- `fence` scoring and arming parity;
- one tap per fence, a pre-ring tap ignored, no tap scores 0 and still jumps on screen;
- overlap report with jumps: jumps are vertical-only drawing, with 0 overlaps and 0 jerks;
- the fence-zone lane hold;
- the copy test with the new banned words.

**PLAYTEST:**
- a kid on a phone clears 3 fences and can say what a clean jump is;
- nothing looks like a fall;
- `steeple.enabled = false` removes every fence.

## 3. Phasing

| Phase | What | Size |
| --- | --- | --- |
| **0 (now)** | Forward jump, air pose, `RIDE_HOP` derived, Mud Splash check | S |
| **1: smallest playtestable slice** | **Practice Hurdles only.** Turf Mile, 3 brush fences, the takeoff ring, `fence` segment scoring with Python parity, bots, coaching, sounds. `steeple.enabled`, `steeple.rated = false`. No purse or point effect. Lets David feel fences inside a week. | M |
| 2 | Rated Hurdles from Bronze (`share` 0.25), Grit weighting, sims passing all gates, picker icon, Horse Book, Classic with 5 fences | M |
| 3 | **Straightaway Dash** on the turf home straight (1,320 ft, about 24 s, segments `pace, burst`), only once racing-plan's passing works on straights. A Rookie intro race candidate. | S–M |
| Later, only if Hurdles plays well | Water jump or cross-country course (needs art and a debate) | L |

## Hard-rule and honesty flags

- **No hard rule breaks.** Nothing is sold, nothing is a wager, no fall or injury, no timers. "Steeplechase" and "hurdles" are not wagering words.
- **Risk: a second timing game inside a timing game.** That could feel like more QTE wallpaper. The in-world ring on the horse, the paused slider and the per-fence live-chance update are the mitigations. If playtesters still watch the HUD instead of the horse, cut Hurdles back to Practice and rethink before rating it.
- **Risk: fences crowd the only steering window.** The backstretch is the steering window today. The lane hold in fence zones must be checked against racing-plan's passing gates before Phase 2.
- **Server cost:** small. At most 5 extra segment closes per race, and scheduling comes from the existing stride path.
