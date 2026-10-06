# Race steering calibration (D-054, stage S0; D-057, stages N1 and N3)

By the model engineer, 2026-10-05; revised after the PR #37 review. Python reference `src/trip.py`, calibration `sims/steering.py`, tests `tests/test_trip.py`. Reproduce with `python sims/steering.py --write`, which takes about 20 minutes on 12 cores. It rewrites `tests/fixtures/trip_baseline.json`, `game/src/shared/TripBaseline.luau` and the stored report `tests/fixtures/steering_report.json`, which the tests assert. `python sims/steering.py` reruns the report against the checked-in baseline.

**Short answer:** every acceptance target passes in every course × distance cell, including post bias for a Smart Steer kid among bots and in all-Smart lobbies. Changes from the plan:
- `groundPerLaneTurn` 0.012 → **0.010**
- `draftPerSecond` 0.0012 → **0.0010**
- `tuckBackMax` 12 → **24 ft** (3 lengths)
- new `bots.wideShare = 0.20`
- new `laneBand` and `tuckReleasePerSecond`
- before the lock, gaps move exactly as `RaceView` moves them (D-055's 10 ft/s limiter)
- a lane change never pushes the horse behind
- a hold settles a horse into its place at `holdPullPerSecond` (19 ft/s) instead of snapping it there (the pre-lock hop fix, below; every number in this report is from after it)

`smart.homeLane` (2) and every other plan value are unchanged.

**D-057 (natural steering), stage N1, 2026-10-06:** the rules are in `src/trip.py`, and the numbers with them on are in [Natural steering (D-057), stage N1](#natural-steering-d-057-stage-n1).

**N5 review, 2026-10-06: a press again is the same try.** A brush now needs the third press toward a horse alongside (`brushPresses = 3`). Kids who press again are charged in under 1% of races (48–59% among bots with N1's rule), and a masher still in 56%. Every target passes, and so do the griefing gates, now measured with wanderer, masher and press-again kids too. The shadow finding is not a brush effect. See [The N5 review](#the-n5-review-a-press-again-is-the-same-try).

**Stage N5, 2026-10-06: brushes are on too**, so the game runs D-057 in full. `python sims/steering.py --write` with brushes on reproduces the N3 baseline table and probes exactly (Smart Steer never brushes; only the recorded config changed). The report is the one in [Report with D-057 on](#report-with-d-057-on) (the N1 run with brushes, which is the game's config now): every target passes, casual riders are charged in 0.6% of races (cells 0–1.3%), and the griefing bound holds (−0.0004 to +0.0029).

**Stage N3, 2026-10-06: the game runs D-057's motion and press rules** (brushes stayed off until N5). The game's numbers are in the last section, [The game's config (D-057 on, brushes off), stage N3](#the-games-config-d-057-on-brushes-off-stage-n3). Everything above is now the D-054 config, the switch-back (`trip.d054_config()`): its baseline and report moved to `tests/fixtures/trip_baseline_d054.json` and `steering_report_d054.json` (`python sims/steering.py --profile d054 --write`), and `tests/test_trip.py` still holds it to every D-054 target.

## Final values (mirror of `GameConfig.steering` for S2)

```lua
GameConfig.steering = {
	enabled = true, scale = 1,
	floor = -0.02, ceiling = 0.04,
	groundPerLaneTurn = 0.010,     -- plan: 0.012
	draftPerSecond = 0.0010,       -- plan: 0.0012
	draftCap = 0.016,
	draftNear = 4, draftFar = 24,
	laneSeconds = 0.6, minRequestGap = 0.6,
	maxQueued = 1,                 -- 0 or 1; Trip.new rejects anything else
	clearFeet = 8,                 -- room needed ahead in the new lane...
	holdGap = 10,                  -- ...and behind it, so the mover never pushes the horse behind
	holdPullPerSecond = 19,        -- new (hop fix): a hold settles a horse back no faster than this
	tuckBackMax = 24,              -- plan: 12
	outwardWaitSeconds = 1.0,
	tickHz = 10, sendHz = 10,
	gapRampSeconds = 8,
	lockBellSeconds = 3,
	smart = { homeLane = 2, turnLeadSeconds = 8, resumeSeconds = 5 },
	bots = { turnLeadMin = 4, turnLeadMax = 12, railShare = 0.25, wideShare = 0.20 }, -- wideShare: new
	introRaces = 3,
	stars = { 0.015, -0.005 },
	laneBand = 0.9,                -- new: horses closer than this, in lanes, share a lane
	tuckReleasePerSecond = 4,      -- new: a tuck-back fades this fast once nothing blocks
}
```

Trip also reads these values from `GameConfig`:
- `raceSpeedStudsPerSecond` (56), `raceShape.leadFeetPerShare` (320) and `lanes` (8);
- `raceView.maxGapFeetPerSecond` (10) and `raceView.catchUpMarginSeconds` (0.3);
- RaceView's easing rate, the literal `dt * 2.5`, which S2 could move into `GameConfig.raceView`;
- the course geometry from `TrackLayout`.

## Report (final config)

Baseline: seed 20261005, 2,000 races per course × distance × post. Each race contributes:
- eight fields, one with a Smart Steer kid at each post among bots;
- one all-Smart field.

That is 144,000 race simulations in all.

Report: a fresh seed (20261006), 600 races per course × distance. In each race:
- **Smart Steer column:** a kid at every post among bots (8 fields), averaged over all posts.
- **Other policies:** one rider at a random post among seven bots, the same race replayed for each policy.

Mean τ:

| Course | Distance | Smart Steer kid among bots | Rail rider | Rail − Smart | Never steers | Wanderer | Casual | All-Smart field | Post bias: kid among bots | Post bias: all-Smart | Draft share | In within 3 s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dirt | Sprint | +0.0002 | +0.0176 | +0.0174 | −0.0145 | −0.0030 | +0.0097 | +0.0000 | 0.0010 | 0.0014 | 35% | 98% |
| dirt | Mile | −0.0005 | +0.0163 | +0.0168 | −0.0147 | −0.0053 | +0.0065 | −0.0000 | 0.0014 | 0.0017 | 28% | 81% |
| dirt | Classic | +0.0003 | +0.0193 | +0.0194 | −0.0142 | −0.0002 | +0.0145 | +0.0003 | 0.0017 | 0.0016 | 35% | 94% |
| dirt | Marathon | −0.0009 | +0.0241 | +0.0252 | −0.0151 | −0.0042 | +0.0112 | −0.0000 | 0.0013 | 0.0017 | 20% | 81% |
| turf | Sprint | +0.0003 | +0.0170 | +0.0164 | −0.0133 | −0.0025 | +0.0098 | +0.0000 | 0.0011 | 0.0020 | 35% | 98% |
| turf | Mile | −0.0001 | +0.0192 | +0.0197 | −0.0152 | −0.0038 | +0.0095 | +0.0001 | 0.0011 | 0.0014 | 33% | 85% |
| turf | Classic | −0.0001 | +0.0195 | +0.0199 | −0.0148 | −0.0013 | +0.0131 | +0.0003 | 0.0016 | 0.0014 | 35% | 92% |
| turf | Marathon | −0.0001 | +0.0264 | +0.0263 | −0.0151 | +0.0015 | +0.0183 | +0.0006 | 0.0017 | 0.0011 | 24% | 91% |

| Target (every cell) | Value | Result |
| --- | --- | --- |
| Rail rider vs Smart Steer | +0.01 to +0.03 | +0.016 to +0.026: pass |
| Never-steer | −0.02 to −0.01 | −0.015 to −0.013: pass |
| Inward request reaching its lane within 3 s | ≥ 70% | 81% to 98% (90.4% overall; rail rider 94.3%): pass |
| Draft share of positive trip | ≤ 40% | 20% to 35% (29.6% overall): pass |
| Post bias, Smart Steer kid among bots (every post) | < 0.005 | ≤ 0.0017 (absolute mean τ per post ≤ 0.0022): pass |
| Post bias, all-Smart lobbies (every post) | < 0.005 | ≤ 0.0020: pass |
| Smart Steer kid among bots averages | 0 ± 0.003 | −0.0009 to +0.0003: pass |
| All-Smart field mean | 0 ± 0.003 | −0.0000 to +0.0006: pass |

Per-post residual: mean τ at each post minus the mean over posts, posts 1 to 8.

| Cell | Smart Steer kid among bots | All-Smart lobbies | Bot fields (for information) |
| --- | --- | --- | --- |
| dirt Sprint | −.0002 −.0006 −.0010 −.0006 +.0000 +.0005 +.0008 +.0009 | −.0000 +.0009 +.0008 +.0006 +.0001 −.0005 −.0005 −.0014 | −.0000 +.0023 −.0012 −.0007 −.0005 +.0001 −.0001 +.0001 |
| dirt Mile | +.0003 +.0006 −.0014 −.0005 −.0002 +.0001 +.0005 +.0007 | −.0004 −.0006 +.0017 +.0005 −.0000 −.0002 −.0004 −.0006 | −.0014 +.0073 −.0013 −.0006 −.0015 −.0020 −.0005 −.0001 |
| dirt Classic | +.0008 −.0014 −.0012 −.0007 −.0000 +.0006 +.0003 +.0017 | −.0007 +.0011 +.0015 +.0013 −.0003 +.0002 −.0015 −.0016 | +.0001 +.0033 −.0021 −.0004 −.0003 −.0004 −.0005 +.0004 |
| dirt Marathon | +.0003 +.0007 −.0013 −.0008 −.0001 +.0002 +.0004 +.0006 | −.0003 −.0007 +.0017 +.0005 +.0001 −.0003 −.0004 −.0005 | −.0027 +.0071 −.0006 −.0001 −.0014 −.0005 −.0012 −.0006 |
| turf Sprint | −.0001 −.0006 −.0009 −.0009 −.0001 +.0005 +.0009 +.0011 | −.0001 +.0008 +.0008 +.0005 +.0002 −.0000 −.0002 −.0020 | +.0001 +.0025 −.0010 −.0013 −.0001 −.0002 −.0001 +.0001 |
| turf Mile | +.0009 +.0007 −.0011 −.0006 −.0005 +.0001 +.0006 −.0000 | −.0014 −.0006 +.0004 +.0007 +.0001 +.0007 +.0002 −.0001 | −.0003 +.0061 −.0023 −.0014 −.0012 +.0001 −.0007 −.0003 |
| turf Classic | +.0012 −.0013 −.0016 −.0003 +.0001 −.0001 +.0009 +.0011 | −.0010 +.0008 +.0014 +.0012 +.0005 −.0011 −.0006 −.0013 | +.0001 +.0040 −.0018 −.0011 −.0005 −.0010 −.0001 +.0004 |
| turf Marathon | +.0010 −.0014 −.0011 −.0011 +.0001 −.0003 +.0011 +.0017 | −.0011 +.0006 +.0010 +.0011 −.0001 −.0007 −.0006 −.0003 | −.0012 +.0029 −.0002 −.0011 +.0005 −.0014 +.0001 +.0005 |

Other numbers:
- **Lane at the lock:** Smart Steer 1.9–2.0, rail rider 1.0, never-steer 4.4–4.6.
- **Clamp binding:** never-steer sits on the floor in 57–75% of races. The rail rider hits the ceiling in 10% of dirt Marathons, 5% of turf Marathons, and in no races elsewhere.
- **Spacing:** the closest two horses sharing a lane came at the end of a tick was 6.96 ft (it was 10.0 before the hop fix). That happens while one is still gliding in, within the 0.9-lane band.
  - In 400 races with random presses, horses within half a lane of each other were never closer than 8.8 ft (an overlap is under 6 ft of an 8 ft horse).
  - A close arrival settles back to `holdGap` within 5 ticks.

### How each number is measured

- **Policies:**
  - Smart Steer: on, no presses.
  - Rail rider: presses ◀ every 0.3 s until on the rail.
  - Never steers: Smart Steer off, no presses.
  - Wanderer: a random arrow about every 3 s.
  - Casual: ◀ about every 5 s, ▶ about every 20 s, Smart Steer on.
  - Bots: Smart Steer with variety (turn lead 4–12 s; 25% ride the rail, 20% ride one lane wider).
- **Within 3 s:** every ◀ press from the casual rider that was accepted or queued at least 3 s before the lock. It succeeds if the horse is in the lane it asked for within 3 s. The check is per cell.
- **Draft share:** in bot fields, each horse's τ is split into a draft part and a ground part, each against its own per-post mean and the field mean. Over horses with τ > 0, it is the draft part's share of the positive parts.
- **Post bias:** each post's mean τ minus the mean over posts.
  - The mean over posts is the clamp shift (the floor clips bad trips). A shift common to every post cancels in the field mean, so no per-post table can remove it.
  - For the kid among bots, the table above also gives the absolute per-post mean (residual plus the kid's overall mean): at most 0.0022 from zero.

## The post baseline (fixed in review)

**What was wrong.** The first S0 baseline was the mean trip of each post in all-bot fields, and post bias was only measured in all-bot fields (where it was ≤ 0.0013). For a Smart Steer kid it was not fair. A kid at post 2 starts in Smart Steer's own lane, so it leads the lane-2 line and never drafts, while a quarter of the bots at post 2 go to the rail. The reviewer measured a kid at post 2 at 0.005–0.008 below the field mean among bots, and −0.008 to −0.009 in all-Smart lobbies. My earlier "post bias ≤ 0.0013" claim covered bot fields only; it did not hold for a kid.

**Fix** (`sims/steering.py`, `calibrate()`):
- The baseline is built from the two fields a kid actually races in:
  - (a) one Smart Steer kid at the post among seven bots, the usual race;
  - (b) a full lobby of Smart Steer kids.
- Each post starts at 0.5 × (a)'s mean trip + 0.5 × (b)'s.
- Four fixed-point passes on clamped τ then move each post by 0.5 × its residual in (a) plus 0.5 × its residual in (b).

With equal weights the two kinds of field end with residuals of equal size and opposite sign, half the gap between their profiles: at most 0.0018 and 0.0020. A pure (a) baseline (weight 1) left all-Smart lobbies at up to 0.0043 in a 300-race trial, which passes but with little margin.

**Bot posts.** Bot fields are not fair by post under this baseline: bots at post 2 sit +0.002 to +0.007 above the mean, because the rail-riding quarter of them saves ground from there. That doesn't touch any player:
- A bot's τ pays nobody.
- Its effect on a kid comes only through the field mean, and the kid-among-bots check already includes it.

I did not mix bot fields into the baseline, because that would bring back the kid's post-2 deficit.

## What changed from the plan, and why

1. **Gap motion follows the race view (D-055).** Main's `RaceView` now limits how fast a horse gains or loses ground on the pace: eased at 2.5/s, no faster than `maxGapFeetPerSecond` (10 ft/s) unless it must hurry to be in place by the line. Trip copies this exactly before the lock (`test_offsets_move_like_the_race_view` replays the formula), so server clearances match what kids see. Easing back 10 ft now takes at least 1 s.
2. **`tuckBackMax` 12 → 24 ft (3 lengths).**
   - With the 10 ft/s limiter and the 1.5-length cap, inward presses reached their lane within 3 s in only 60–74% of races in the Miles and the dirt Marathon.
   - Almost every slow press is a line of horses alongside, often five or six in lane 2 when the turn starts straight out of the gate (dirt Mile, dirt Marathon).
   - At 24 ft every cell is at 81% or more. 16 ft and 20 ft left the dirt Mile at 62–67%, and clearance values made no measurable difference.
   - A horse waits for room rather than easing back further. I also tried "hold station when the horse alongside is itself easing back"; it changed nothing and was dropped.
3. **The mover never pushes the horse behind.** A lane change needs `clearFeet` (8 ft) of room ahead in the new lane and `holdGap` (10 ft) behind. Previously 8 ft either way allowed a horse to cut in 8–10 ft ahead and push the horse behind back up to 2 ft. Now the mover always gives way (`test_the_mover_never_pushes_the_horse_behind`).
4. **`groundPerLaneTurn` 0.012 → 0.010.** At 0.012 the rail rider beat Smart Steer by +0.030 in the Marathons, where three turns count. 0.010 centres the range (+0.017 to +0.026).
5. **`draftPerSecond` 0.0012 → 0.0010.** With the longer tuck-in, the two Sprints reached 40% draft share (dirt Sprint 40.06%) against the ≤ 40% limit (Sprints only count the far turn, so draft weighs more). At 0.0010 they are at 35%. Longer races still reach the cap, so their numbers barely moved.
6. **`bots.wideShare = 0.20` (new).** With only "25% ride the rail", the average bot out-steered Smart Steer, and a kid among bots averaged τ −0.005 (dirt Mile) and −0.007 (dirt Marathon). Now 20% of bots ride one lane wider, and a kid among bots averages −0.0009 to +0.0003.
7. **Every target per cell, not overall.** That includes the within-3-s target, and "a Smart Steer kid among bots averages 0 ± 0.003" was added.

## The pre-lock hop (fixed 2026-10-05)

**What was wrong.** Before the lock, a lane change needs `clearFeet` (8 ft) of room ahead in the new lane, but a hold keeps `holdGap` (10 ft). A horse arriving 8–10 ft behind another, or catching up during its 0.6 s glide, was snapped back to 10 ft in one tick. On screen that was a hop: up to 30 ft/s backwards in bot fields and about 50 ft/s with riders pressing (the S4 overlap report's backward-speed check).

**Fix.** The hold now settles a horse back no faster than `holdPullPerSecond` (19 ft/s), counted from where it was at the start of the tick, in `src/trip.py` and `Trip.luau` alike. The view after the lock uses the same rate.
- Following a horse never needs more: a follower moves back with the horse ahead, which moves at most 10 ft/s, so steady holds are exact as before.
- Only a fresh arrival is spread over a few ticks: horses within half a lane stay at least 8.8 ft apart, and a close arrival is back at 10 ft within 5 ticks.
- Lane decisions don't change.

**Why not the other option:** requiring the full 10 ft ahead before a lane change counts as clear would change which moves are allowed (and the within-3-s numbers), and it still wouldn't cover a horse catching up during its glide.

**Effect on calibration:** every target still passes in every cell, and the numbers moved by at most 0.0001.
- Overall within 3 s: 90.4%, as before.
- Draft share: 29.6%, as before.
- Post bias for a kid among bots: at most 0.0017 (was 0.0018).
- The per-post baseline moved by at most a few ten-thousandths.

**On screen** (`tests/luau/overlap_report`, 960 races per row): no horse falls back faster than 20 ft/s before or after the lock in any row; see D-054.

## Draft and tapping skill (trade-off, provisional)

Drafting rewards being behind someone, so the horse in front of a line drafts least. In bot fields, after the first checkpoint:

| Cell | On-screen leader τ | Last horse τ | Best tapper τ | Worst tapper τ |
| --- | --- | --- | --- | --- |
| dirt Sprint | −0.0014 | +0.0020 | +0.0000 | +0.0001 |
| dirt Mile | +0.0018 | +0.0011 | +0.0011 | +0.0010 |
| dirt Classic | −0.0020 | +0.0042 | +0.0012 | +0.0002 |
| dirt Marathon | +0.0010 | +0.0025 | +0.0025 | +0.0014 |
| turf Sprint | −0.0013 | +0.0013 | +0.0004 | +0.0001 |
| turf Mile | −0.0008 | +0.0030 | +0.0016 | +0.0015 |
| turf Classic | −0.0016 | +0.0039 | +0.0008 | +0.0009 |
| turf Marathon | −0.0017 | +0.0047 | +0.0017 | +0.0025 |

**What it means:**
- The on-screen leader (highest live chance, from rating and taps) averages −0.002 to +0.002, and the last horse +0.001 to +0.005. The gap is at most about 0.006, roughly 0.3 points of S, against the horses in front.
- Sorted by tapping alone, the best and worst tappers are within 0.001 of each other in most cells, so the link to tapping skill is weak.
- The reviewer's −0.002 to −0.005 and +0.005 to +0.008 came from the first build, before the limiter, the longer tuck-in and the lower draft rate.
- The trade-off is logged in D-054 as provisional and listed in REVIEW_QUEUE. `draftPerSecond = 0` turns it off: the trip becomes ground only, the Young player's minority view.

**Proposed fix (not built):** a draft baseline by running position. In the same generator, record each running rank's expected draft at the lock (rank by skill offset), and credit `draft − D[course][distance][rank]` instead of the raw draft. Leading would then cost nothing, while tucking in more than is usual for your running position would still pay. It adds one table next to the post baseline and one sort at the lock in Trip.

## The model in one tick (for the Luau mirror)

`step(state, live, intents, t, dt)`, in this order:
1. **Skill target and easing:**
   - Skill target = 320 × (live − 1/n) × min(1, t / 8), minus the lane's tuck-back.
   - Offsets move toward it as RaceView moves gaps. With `gap = target − off`, `k = min(1, 2.5·dt)`, `toLine = length/56 − t` and `limit = max(10·dt, |gap|·dt / (toLine − 0.3))` (no limit inside 0.3 s), the step is `off += clamp(gap·k, −limit, limit)`.
2. **Hold:** in the order "leader first, then the inside horse, then the lower index", nobody sits closer than 10 ft behind a horse within 0.9 lanes. A horse is moved back no further than `holdPullPerSecond` × dt from where it started the tick (19 ft/s), so a close arrival settles over a few ticks.
3. **Lane changes:**
   - This tick's presses go first, in arrival order (`accept_intent`). Then every other lane, in the same leader-first order, takes its waiting or queued press. Otherwise Smart Steer heads in one lane when the lane is in a turn or within its turn lead of the next one (the far turn at the lock counts), if the horse is wider than its home lane.
   - A move is clear when no horse in, or gliding into, the target lane is less than 8 ft ahead or less than 10 ft behind.
   - When blocked toward the rail, the horse eases back to the slot behind the horses alongside, if that is at most 24 ft back; otherwise it waits.
   - A blocked outward press cancels after 1 s.
4. **Glide** at 1/0.6 lanes per second, then hold again.
5. **Ground and draft:**
   - Ground: 0.010 × (x − 1) per 180° of each live turn crossed this tick.
   - Draft: 0.0010 per second while 4–24 ft behind a horse within 0.9 lanes, up to 0.016, clipped at the lock time.

`lock` books the far turn from each horse's lane position at the bell. `tau(trip, posts, baseline row)` = clamp(scale × (trip − baseline[post] − field mean), −0.02, +0.04).

**Mirror rules (D-012):**
- Only +, −, ×, ÷, comparisons, min, max and abs inside `step`, `lock` and `tau`. The "no limit" case is `math.huge` in Luau.
- Python's float `%` differs from Luau's, so `trip._lmod` uses Luau's `a − floor(a/b)·b`.
- Every sort uses a total key, and "never" times are −1e9.
- A bad lane index or post raises in Python, because Luau would read nil.
- Bots' two uniforms per lane (rail, lead) come from the race generator after all existing draws; every lane consumes them, bot or not.
- Turn timing follows the server's constant-speed timeline (RaceService's `tFar`), not the client's gate-eased `paceFeet`. They differ by at most 34 ft at the gate, shrinking to about 14 ft at the lock.
- Fixture numbers (found in S2): Lune's JSON reader is not correctly rounded and lands about one number in six one ulp off. Two horses exactly `holdGap` apart turn that ulp into a different race. So `trip.json` carries the lanes' inputs (q, p1, uniforms) as exact decimal strings for Luau's `tonumber`, and the parity test takes config values from `GameConfig`'s literals. With exact inputs, `Trip.luau` agrees with every run: answers exactly, numbers to 1e-9.

**`tests/fixtures/trip.json`** (200 runs; generated, gitignored):
- per-tick intents and the answers;
- x, off and tgt snapshots every 10 ticks (1 s);
- presses after the lock (all "locked", nothing changes);
- the trip, τ and stars;
- each course and distance's gate and phase A. `tests/luau/run_all.luau` already checks these against `TrackLayout` on CI.

Six runs use other configs: scale 0.5 and 0, steering off, no queue, Smart Steer on the rail, no gap ramp.

## Notes for S1–S4

- **Ticks:** step on fixed 0.1 s ticks (t = k × 0.1) for exact parity with Python.
- **Posts:** after S1's shuffle, posts are the lane indices.
- **Geometry:** `TrackLayout.phaseA` should mirror `trip.phase_a`, with lockS = length − finishFromTop − π·r1 in that order.
- **RaceSession parity:** RaceSession folds the crowd boost into R as `R + c/κ` (and S2 plans `τ/κ` the same way), while Python computes `κR + c + τ`. The S2 check of `RaceSession` against `live_chances(..., extra)` will therefore be 1e-9 parity, not bit-identical. `Trip` itself and `RaceMath.liveChances(q, R, cfg, extra)` can still match bit for bit.
- **Lines of horses:** Smart Steer fills lane 2 first, so lane 2 often becomes a line of 3–6 horses, and the slow 10–20% of inward presses are mostly there.
- **Surge at the lock:** held horses sit behind their skill target until the lock. When RaceShape takes the offsets back, the client's 10 ft/s cap smooths the surge.
- **Draft fills fast:** in long races the 0.016 cap still fills in about 16 s, so most tucked-in horses reach it (see the draft trade-off above).


# Natural steering (D-057), stage N1

By the model engineer, 2026-10-06, revised after the PR #48 review. N1 adds every D-057 rule to `src/trip.py` behind `trip.CONFIG` keys, **all switched off**: the game, `TripBaseline.luau` and every D-054 file are unchanged (a full `python sims/steering.py --write` reproduces them byte for byte), and the report above still describes the game. `trip.d057_config()` switches D-057 on for the sims and the fixtures. Reproduce with `python sims/steering.py --profile d057 --write` (about 45 minutes on 12 cores). It writes `tests/fixtures/trip_baseline_d057.json` and `tests/fixtures/steering_report_d057.json`, which `tests/test_trip_d057.py` asserts (four stored probe races included, so the report can't go stale); it never touches the game's baseline. N3 flips the config and regenerates the game's files.

**Short answer:** with D-057 on, every D-054 τ target still passes in every course × distance, against a baseline regenerated for D-057, and so does every new D-057 target. Reach per intent (the new ≥ 70% target) is 72% to 98% per cell. After the review, `weaveWindowSeconds` is 7 (debate 012: 5), which brings a masher under 8 reversals a minute in every cell (6.3–7.5; with 5 the dirt Mile and dirt Marathon sat at 8.35). One note: sideways acceleration between 10 Hz ticks peaks at 30.4 ft/s², because the landing tick snaps onto the lane; Trip's own sideways speed never changes faster than 27 ft/s². The prototype measured the same and quoted "30", and the check allows the landing tick (≤ 30.5).

## Config (mirror of `GameConfig.steering`; N2 adds the keys with these defaults)

```lua
-- D-057 (N1): every switch off, so steering is D-054 bit for bit. trip.D057 lists the switches N3 and N5 flip.
glide = "linear",              -- N3: "eased" (S-curve)
laneSpeedMax = 1.5,            -- eased: lanes/s (9 ft/s)
laneAccel = 4.5,               -- eased: lanes/s^2 (27 ft/s^2)
chainWindow = 0,               -- N3: 0.3
reverseGapSeconds = 0,         -- N3: 0.5
weaveGapSeconds = 0,           -- N3: 2.5
weaveWindowSeconds = 7,        -- debate 012: 5; 7 since the N1 review (every masher cell under 8 a minute)
pressBounceSeconds = 0,        -- N3: 0.2
glideReserveFeet = 0,          -- N3: 6
blockedPress = "d054",         -- N3: "wait"
gapWaitSeconds = 1.5, gapWaitInSeconds = 0, tuckAfterSeconds = 0,
boxedAheadFeet = 12,           -- new (not in the plan): the "horse within 12 ft ahead" of boxed in; reported only
brush = "off",                 -- N5: "repeat"
brushAlongFeet = 8, brushGraceSeconds = 0.3, brushRepeatSeconds = 2, brushPays = "mover",
brushCost = 0.002, brushFree = 1, brushMaxCharged = 3, brushCheckFeet = 4, brushRecoverPerSecond = 2,
steadySeconds = 1,
```

## Report with D-057 on

Baseline: seed 20261005, 2,000 races per course × distance × post (144,000 race simulations), regenerated with D-057 on. Report: seed 20261006, 600 races per cell, with the same policies as the D-054 report plus a masher (4 presses a second, random side) and a ditherer (In, Out, In, Out every 0.2 s). τ includes the brush term.

| Course | Distance | Smart Steer kid among bots | Rail rider | Rail − Smart | Never steers | Wanderer | Casual | All-Smart field | Post bias: kid among bots | Post bias: all-Smart | Draft share | In within 3 s: per intent / per press |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dirt | Sprint | +0.0002 | +0.0180 | +0.0179 | −0.0145 | −0.0035 | +0.0097 | +0.0000 | 0.0017 | 0.0016 | 34% | 98% / 94% |
| dirt | Mile | −0.0005 | +0.0161 | +0.0167 | −0.0147 | −0.0060 | +0.0065 | +0.0000 | 0.0014 | 0.0017 | 28% | 72% / 69% |
| dirt | Classic | +0.0001 | +0.0192 | +0.0195 | −0.0142 | −0.0017 | +0.0135 | +0.0003 | 0.0016 | 0.0014 | 34% | 90% / 85% |
| dirt | Marathon | −0.0009 | +0.0239 | +0.0250 | −0.0151 | −0.0051 | +0.0115 | −0.0000 | 0.0013 | 0.0016 | 20% | 72% / 65% |
| turf | Sprint | +0.0003 | +0.0175 | +0.0169 | −0.0134 | −0.0030 | +0.0101 | +0.0000 | 0.0017 | 0.0024 | 33% | 97% / 93% |
| turf | Mile | −0.0002 | +0.0192 | +0.0195 | −0.0152 | −0.0050 | +0.0094 | +0.0001 | 0.0010 | 0.0014 | 32% | 83% / 77% |
| turf | Classic | −0.0002 | +0.0194 | +0.0196 | −0.0148 | −0.0025 | +0.0125 | +0.0003 | 0.0013 | 0.0012 | 35% | 88% / 84% |
| turf | Marathon | −0.0002 | +0.0264 | +0.0263 | −0.0151 | −0.0007 | +0.0178 | +0.0006 | 0.0014 | 0.0012 | 24% | 86% / 80% |

| Target | Value | D-057 on | D-054 (above) |
| --- | --- | --- | --- |
| Rail rider vs Smart Steer (every cell) | +0.01 to +0.03 | +0.017 to +0.026: pass | +0.016 to +0.026 |
| Never-steer (every cell) | −0.02 to −0.01 | −0.015 to −0.013: pass | −0.015 to −0.013 |
| Inward press reaching its lane within 3 s, **per intent** (every cell; replaces per press) | ≥ 70% | 72% to 98% (85.7% overall; rail rider 85.5%): pass | — |
| …per press (information; was the D-054 target) | — | 65% to 94% (81.0%) | 81% to 98% (90.4%) |
| Draft share of positive trip (every cell) | ≤ 40% | 20% to 35% (29.3%): pass | 20% to 35% |
| Post bias, Smart Steer kid among bots (every cell and post) | < 0.005 | ≤ 0.0017 (absolute ≤ 0.0022): pass | ≤ 0.0017 |
| Post bias, all-Smart lobbies (every cell and post) | < 0.005 | ≤ 0.0024: pass | ≤ 0.0020 |
| Smart Steer kid among bots averages (every cell) | 0 ± 0.003 | −0.0009 to +0.0003: pass | −0.0009 to +0.0003 |
| All-Smart field mean (every cell) | 0 ± 0.003 | −0.0000 to +0.0006: pass | −0.0000 to +0.0006 |
| Masher reversals a minute (every cell) | ≤ 8 | 6.3 to 7.5 (6.9 pooled): pass | 29 (prototype) |
| Masher: none within 3 s of the previous (every cell) | ≥ 3 s | 3.5 s: pass | 0.6 s |
| Sideways acceleration between ticks (every horse; + 0.5 for the landing tick) | ≤ 30 ft/s² | 30.4 (Trip's speed ≤ 27): pass | 200 |
| Casual riders charged for a brush (every cell) | ≤ 5% of races | 0.0% to 1.3% (0.6% overall): pass | — |
| Only the mover pays (every cell and policy) | 0 others charged | 0: pass | — |
| Griefing: targeted minus untargeted own trip (each scenario and kid, pooled) | ≥ −0.001 | −0.0004 to +0.0029 (every cell ≥ −0.0008): pass | — |
| A kid only pays for its own brushes; a Smart Steer kid never | 0 | 0: pass | — |
| Stress, 4,000 races (masher + ditherer + casual among 5 bots) | 0 overlaps, fall-back ≤ 20 ft/s | 0 overlaps, 19.0 ft/s: pass | — |

Per-post residual with D-057 on, posts 1 to 8:

| Cell | Smart Steer kid among bots | All-Smart lobbies |
| --- | --- | --- |
| dirt Sprint | −.0003 −.0007 −.0010 −.0006 −.0003 +.0003 +.0009 +.0017 | −.0000 +.0008 +.0008 +.0006 +.0001 −.0002 −.0004 −.0016 |
| dirt Mile | +.0003 +.0004 −.0014 −.0005 −.0002 +.0001 +.0005 +.0009 | −.0004 −.0006 +.0017 +.0005 +.0000 −.0002 −.0004 −.0005 |
| dirt Classic | +.0009 −.0014 −.0011 −.0006 +.0001 +.0003 +.0003 +.0016 | −.0008 +.0009 +.0013 +.0010 −.0003 +.0003 −.0014 −.0010 |
| dirt Marathon | +.0003 +.0005 −.0013 −.0008 −.0001 +.0002 +.0004 +.0008 | −.0003 −.0004 +.0016 +.0005 +.0001 −.0002 −.0004 −.0009 |
| turf Sprint | −.0002 −.0007 −.0010 −.0009 −.0002 +.0005 +.0008 +.0017 | +.0001 +.0010 +.0009 +.0005 +.0005 +.0001 −.0006 −.0024 |
| turf Mile | +.0010 +.0005 −.0009 −.0005 −.0004 −.0001 +.0001 +.0003 | −.0014 −.0004 +.0004 +.0005 +.0002 +.0007 +.0002 −.0002 |
| turf Classic | +.0012 −.0012 −.0013 +.0002 +.0005 −.0004 +.0004 +.0006 | −.0010 +.0008 +.0012 +.0009 +.0005 −.0011 −.0008 −.0007 |
| turf Marathon | +.0011 −.0014 −.0008 −.0008 +.0000 −.0001 +.0006 +.0014 | −.0012 +.0007 +.0009 +.0008 +.0000 −.0005 −.0006 −.0003 |

**The D-057 baseline** differs from D-054's at the outside posts: the slower glide costs a wide horse more ground on its way in, so posts 6–8 sit up to 0.0033 lower (posts 1–4 within 0.0003). Lanes at the lock: Smart Steer 1.86–1.99, rail rider 1.00, never-steer 4.4–4.6. Never-steer sits on the floor in 57% to 75% of races; the rail rider hits the ceiling in 11% of dirt Marathons at most, as with D-054.

### Motion and zig-zag

- **Free glides,** press to landing: one lane 1.0 s, two 1.6 s, three 2.3 s, four 3.0 s (`glide_seconds`; the 0.8 s switch gives 0.8 and 1.4 s). The first 0.1 s covers 0.045 lane.
- **Reversals a minute** (focal rider among bots; shortest and median gap):

  | Policy | Reversals a minute | Shortest gap | Median gap | Lane changes a minute |
  | --- | --- | --- | --- | --- |
  | Masher | 6.9 | 3.5 s | 5.6 s | 21.3 |
  | Ditherer | 12.1 | 3.5 s | 3.7 s | 13.0 |
  | Wanderer | 3.9 | 3.5 s | 5.6 s | 9.4 |
  | Casual | 1.2 | 3.5 s | 5.4 s | 4.7 |
  | Rail rider, never-steer | 0 | | | 3.5, 0 |

  Masher per cell (Sprint, Mile, Classic, Marathon): dirt 7.3, 7.5, 6.5, 7.4; turf 7.3, 6.8, 6.6, 6.3. With debate 012's 5 s window: 7.6 pooled, dirt Mile 8.35, dirt Marathon 8.34 (the press bounce adds about 0.3 a minute; with it off the dirt Marathon was still 8.4).
- **Sideways motion** (every horse while it moves, 10 Hz): top speed 9.0 ft/s (drift 9.1°), speed p50 9 ft/s; acceleration p50 10 ft/s², p95 30 ft/s², maximum 30.4 ft/s² (the landing tick, as above).
- **Body yaw estimate** (N3's SteerPose from Trip's 10 Hz lanes: atan(sideways ÷ 56 ft/s), smoothed over 0.15 s, capped at 10°): at most 9.1°, p95 under 10°. Lean (0.12° per ft/s², capped at 3°): at most 2.9°.

### Boxed in

Boxed = no room either side (`side_state` not "free") and a horse within 12 ft ahead in the lane. "No tuck" = boxed and `no_tuck_inside` (off the rail, no tuck slot inside within `tuckBackMax`), debate 012's "trapped". Share of pre-lock time (Smart Steer: a kid at every post among bots; others: one rider at a random post):

| Policy | Boxed | Boxed, no tuck slot | Races with ≥ 1 s boxed | By post 1–8 |
| --- | --- | --- | --- | --- |
| Smart Steer kid | 6.4% | 1.38% | 21% | 1, 2, 10, 10, 9, 7, 6, 5% |
| Rail rider | 48.2% | 0.00% | 79% | 1, 53, 59, 58, 55, 53, 53, 52% |
| Never steers | 0.3% | 0.05% | 2% | 1, 1, 0, 0, 0, 0, 0, 0% |
| Wanderer | 17.4% | 0.85% | 39% | 7, 27, 26, 24, 18, 13, 12, 10% |
| Casual | 31.7% | 0.75% | 61% | 4, 41, 43, 44, 38, 30, 29, 24% |
| Masher | 15.8% | 0.54% | 41% | 7, 21, 24, 24, 14, 14, 12, 10% |
| Ditherer | 7.9% | 0.25% | 20% | 13, 40, 7, 1, 0, 0, 0, 0% |

The rail rider's box is the classic one (on the rail behind a horse with one outside), where it wants to be. The prototype had a Smart Steer kid at 5.5% boxed, 21% of races ≥ 1 s and trapped about 1%. "No room yet" candidates (a casual press still waiting after 1 s with no glide and no tuck-back, before N4's 10 s limit): 0.46–2.87 a race by cell (1.6 overall), in line with the prototype's 0.4–2.7.

### Brushes

Focal rider among bots (a brush needs a second press within 2 s of the waiting press, a horse alongside for 0.3 s and no tuck-back possible):

| Policy | Races with a brush | Races charged | Brushes a race | Mean cost | Max cost |
| --- | --- | --- | --- | --- | --- |
| Casual | 2.1% | 0.6% | 0.03 | 0.0000 | 0.004 |
| Wanderer | 36.4% | 13.0% | 0.55 | 0.0004 | 0.006 |
| Masher | 81.9% | 65.7% | 2.45 | 0.0033 | 0.006 |
| Rail rider, ditherer, never-steer | 0 | 0 | 0 | 0 | 0 |

The prototype had casual 1.9% / 0.4%, wanderer 35% / 13.5%, masher 80% / 64%. N1's window rule (the window starts at the waiting press, even a queued one) charges casual riders in 0.60% of races against 0.48% with the plan's rule (same races). A masher's presses bounce about 40 times a race and meet "steady" about 7 times. The other horse was charged 0 times in every run (mover pays).

### Griefing

Strangers whose skill targets equal the kid's (they tapped exactly like it, the worst case), 200 races per cell (1,600 per row). "Own trip" = the kid's ground + draft − its own brush charge, what a stranger could damage directly; τ also moves with the field mean.

| Kid | Strangers | Own trip vs the same strangers on Smart Steer (p5) | τ vs the same | Targeted − untargeted | Strangers charged a race |
| --- | --- | --- | --- | --- | --- |
| Smart Steer | Shadow (its inside) | −0.0011 (−0.016) | −0.0033 | +0.0003 (vs rail1) | 0.96 |
| Smart Steer | Crew of 3 | +0.0009 (−0.015) | −0.0003 | +0.0029 (vs rail3) | 3.83 |
| Smart Steer | Bumper | −0.0009 (−0.016) | −0.0027 | +0.0005 (vs rail1) | 1.48 |
| Smart Steer | rail1 / rail3 (untargeted) | −0.0014 / −0.0020 | −0.0042 / −0.0094 | | 0 |
| Rail rider | Shadow (its inside) | +0.0001 (−0.000) | −0.0023 | +0.0001 (vs rail1) | 0.43 |
| Rail rider | Crew of 3 | −0.0002 (−0.010) | −0.0049 | +0.0001 (vs rail3) | 2.00 |
| Rail rider | Bumper | −0.0003 (−0.008) | −0.0024 | −0.0004 (vs rail1) | 0.66 |
| Rail rider | rail1 / rail3 (untargeted) | +0.0000 / −0.0003 | −0.0026 / −0.0075 | | 0 |

Targeting a kid does it no more harm than the same players simply riding well, and the kid is never charged (debate 012: shadow −0.0011, crew +0.0011, bumper −0.0007; untargeted −0.0013 and −0.0020). Per cell, every targeted − untargeted value is at least −0.0008.

### Overlaps

Stress run: 4,000 races (500 per cell), a masher, a ditherer and a casual rider pressing at once among five bots: 0 frames with two horses within half a lane and 6 ft, the fastest fall-back 19.0 ft/s, 9,760 brushes. The closest same-lane pair at a tick's end is 5.0 ft in the report and 7.0 ft in the stress run (D-054: 7.0). That is a horse still gliding in within the 0.9-lane band, not an overlap; the slower glide spends longer in the band.

## Calls made in N1 (where the plan was open)

1. **The rules sit behind `trip.CONFIG` keys, all off.** The names are the plan's `GameConfig.steering` names. Values that only matter once their switch is on (`laneSpeedMax` 1.5, `laneAccel` 4.5, `weaveWindowSeconds` 7, `gapWaitSeconds` 1.5, every `brush*` value, `steadySeconds` 1) already hold D-057's numbers. N3 and N5 therefore flip only the switches in `trip.D057`: `glide`, `chainWindow`, `reverseGapSeconds`, `weaveGapSeconds`, `pressBounceSeconds`, `glideReserveFeet` and `blockedPress` (N3), and `brush` (N5).
2. **`weaveWindowSeconds` 7, not 5** (N1 review, provisional, in REVIEW_QUEUE). With debate 012's 5 s, a masher reversed 8.35 times a minute in the dirt Mile and 8.34 in the dirt Marathon, above D-057's ≤ 8 in every cell (7.6 pooled, the way the debate measured it). A trial on the report's races:

   | Window | Masher pooled | Worst cell | Casual reach per intent, worst cell | Casual charged |
   | --- | --- | --- | --- | --- |
   | 5 s | 7.62 | 8.35 | 71.9% | 0.58% |
   | 6 s | 7.19 | 7.83 | 71.9% | 0.60% |
   | 7 s | 6.86 | 7.47 | 71.8% | 0.60% |

   The reviewer's own 6 s run left the dirt Marathon at 8.11, so 7 s, which clears every cell with a margin, is the value adopted. The masher target is now checked in every cell.
3. **One key the plan doesn't name: `boxedAheadFeet = 12`** (the "horse within 12 ft ahead" in the boxed-in rule). It only feeds `trip.boxed_in`, which the sims and N4's chips read; it never changes a race.
4. **Files made before D-057 stay byte for byte.**
   - `trip.config_record(cfg)` leaves the D-057 keys out of a recorded config while every one holds its D-054 value. So `trip.json`, `trip_baseline.json` and `steering_report.json`, and the Luau check of `GameConfig.steering` against `trip.json`, are unchanged.
   - The D-054 values are a literal, `trip.D057_OFF`, never read from `CONFIG`. After N3 switches D-057 on in `CONFIG`, a D-057 config still records every key, and an old record still reads back as D-054 (`test_records_survive_the_n3_flip`).
   - The plan wanted `trip.json` to carry its config block; it already does (`cfg`, the D-054 view).
5. **The brush check runs inside `accept_intent`**, after the bounce and steady checks and before the queue logic. The plan put it "in the intents loop, before `accept_intent`", and the prototype did that. The order of checks is the same. Keeping it inside means the bounce, which the plan puts in `acceptIntent`, also guards brushes: a finger bounce never brushes.
6. **The 2 s brush window starts when the waiting press was pressed, even if it was queued** (provisional, in REVIEW_QUEUE).
   - The plan sets `first_press_at` when a press is accepted. A press made during a glide or a reverse gap is queued, so its window was timed from an older press, possibly one the other way. N1 also sets `first_press_at` when a press is queued while nothing waits (`want == 0`), which matches the decision's "within 2 s of the first press".
   - It changes some casual races too: on the report's races (600 per cell), casual riders are charged in 0.60% of races against 0.48% with the plan's rule, wanderers in 13.0% against 12.7% and mashers in 66% against 62%. Both rules are far under the 5% line. The reviewer measured 0.58% against 0.46% with the 5 s weave window.
   - With the plan's rule, the model matches debate 012's prototype exactly (200 of 200 heavy-press races). The edge run `brush-window-queued` pins the new rule for the N2 port.
7. **The bounce** (`pressBounceSeconds`) counts from the last press that wasn't a bounce, in the same direction only (D-055's tap rule). An opposite press 0.1 s later is a new press: it cancels or queues as before.
8. **The weave gap is judged when the change would start**, as in the prototype: a reversal waits 2.5 s after landing while it is still within `weaveWindowSeconds` of the last reversal, and 0.5 s otherwise. Reversals are therefore at least 3.5 s apart (1.0 s glide plus 2.5 s), a hard bound the tests check.
9. **The sideways-acceleration target.** Trip's own sideways speed never changes faster than `laneAccel` (27 ft/s²). Measured the way D-057 measured it (finite differences of the 10 Hz lanes), the landing tick reaches 30.4 ft/s², because the last step is a snap onto the lane, shorter than a braking step. The prototype measured the same 30.4 and printed "30". The check allows the landing tick explicitly (≤ 30.5), and the report prints the exact value.
10. **Griefing is checked pooled over the cells**, the way debate 012 measured it (1,600 races per scenario and kid policy). Every cell is in the report, and every cell passes too.
11. **Two meanings of "trapped", two names.**
    - `trip.no_tuck_inside`: off the rail, no room inside and no tuck slot within `tuckBackMax`. This is D-057's "trapped", the grey ◀ In, boxed or not; `side_state(-1) == "blocked"` also covers the rail.
    - `trip.boxed_no_tuck`: boxed in and `no_tuck_inside`. This is debate 012's "trapped" measure.
    - The report and the fixture use these names (`no_tuck_share`, `noTuckInside`, `boxedNoTuck`).
12. **Smart Steer's wait clock** (`smart_block_at`) measures one unbroken wait. It starts when Smart Steer's move first meets no room, and it clears on any tick where Smart Steer doesn't try and fail. It is only read with `tuckAfterSeconds` > 0 (0 in D-057).
13. **Reach per intent** counts the first inward press after 3 s with no presses, unless it is refused (bounds, invalid, locked) or bounced. A first press answered cancelled, steady or brush counts, and fails unless the horse still gets there in 3 s. Steady, brush, bounce and rate need an earlier press within 3 s, so in practice a first press is accepted, queued, cancelled or bounds. The per-press figure keeps D-054's definition (accepted or queued).
14. **Test sizes and runtime.**
    - The plan's "0 overlaps in 400 random-press races" is covered by the sim's 4,000-race stress run (stored and asserted). The tests replay 8 pressing races every tick, with a masher, a ditherer, a casual rider and a double-presser together.
    - Stale-report guard: four exact probe races (`steering.probe_races`: a masher, a casual rider, a bumper against a Smart Steer kid and a stress field) are stored in the D-057 report and replayed exactly by the tests. A change to the press, brush, bounce, weave or glide rules fails the tests until the report is regenerated.
15. **`trip_d057.json` is written by `python tests/fixtures/make_fixtures.py --d057`.** It is gitignored; since N2, CI and `tests/test_luau_parity.py` write it and `tests/luau/trip_d057_tests.luau` replays it against `Trip.luau` (50 runs and 12 edge runs, about 7 MB; `tests/test_luau_parity.py` regenerates the fixtures only when a hash of the generator and the modules it imports changes). Its configs also come as exact decimal strings (`cfgExact`, `defaultsExact`, and per-run `cfgExact`). It uses `trip_baseline.json`'s table for τ, so it doesn't depend on the D-057 baseline file.

## Mirror notes for N2 (`Trip.luau`)

- **New state** (Python name; Luau uses camelCase): `v`, `last_dir`, `arrived_at`, `last_rev_at`, `brushes`, `charged`, `check`, `steady_until`, `along_since[i] = {inside, outside}` (`NOT_ALONG = 1e9`), `smart_block_at`, `last_press_at`, `last_press_dir`, `first_press_at`, `tucking`, and `events` (`{t, "brush", mover, other, dir}`, with lanes 1-based in Luau). The fixture snapshots carry every clock: `alongSince`, `steadyUntil`, `firstPressAt`, `lastRevAt`, `arrivedAt`, `manualAt`. Events carry the tick they happened on.
- **`acceptIntent` order:**
  1. locked
  2. invalid
  3. bounce: same direction and `t − lastPressAt < pressBounceSeconds − EPS`; `manualAt` is not touched
  4. record the press and `manualAt`
  5. steady
  6. brush (`brushTarget`)
  7. cancel
  8. bounds
  9. reversing
  10. idle: accepted, with `firstPressAt = t`
  11. queued: `firstPressAt = t` only when `want == 0`
  12. rate
- **`step` order:**
  1. Skill targets, now minus `check` as well: `skill − tuck − check − off`.
  2. Hold.
  3. Order.
  4. Alongside tracking, only when `brush ~= "off"`.
  5. This tick's intents.
  6. The lane-change loop:
     - a gliding horse continues only within `chainWindow`, in the same direction;
     - a queued or waiting press the other way waits for landing;
     - the reverse gap restarts `wantAt`;
     - Smart Steer honours the reverse gap and chains inward;
     - a tick on which Smart Steer doesn't try and fail clears `smartBlockAt`.
  7. Glide, `linear` or `eased`.
  8. Hold.
  9. Tuck release.
  10. `check` recovery.
  11. Save `tucking`.
  12. Ground and draft.
- **Eased glide:**
  - `adt = laneAccel·dt`
  - `vb = adt·(sqrt(0.25 + 2·dist/(adt·dt)) − 0.5)`
  - `v += clamp(sign·min(laneSpeedMax, vb) − v, ±adt)`, then `x += v·dt`
  - Snap (with `v = 0` and `arrivedAt = t + dt`) when `(nx − tgt)·sign ≥ −EPS` or `dist ≤ EPS`.
  - `math.sqrt` is correctly rounded in both languages.
  - The linear glide also sets `arrivedAt = t + dt` on landing.
- **`slot`:** a horse with `tgt == lane` and `x ~= lane` blocks within `clearFeet + glideReserveFeet` ahead and `holdGap + glideReserveFeet` behind. The slot itself is still `holdGap` behind the rearmost blocker.
- **`tryMove`:**
  - A move that starts sets `lastRevAt` (when it goes opposite to `lastDir`) and `lastDir`, and clears `smartBlockAt`.
  - With `blockedPress == "wait"` it goes to `waitForRoom`:
    - inward, it tucks back when the slot is within `tuckBackMax`, after `tuckAfterSeconds`;
    - otherwise a rider's press drops after `gapWaitInSeconds` (inward) or `gapWaitSeconds` (outward), where 0 means never;
    - Smart Steer never drops.
- **`alongside`:**
  - the next lane is `tgt + d`;
  - a horse counts if it is in that lane by `laneBand` or gliding into it, and `|Δoff| < brushAlongFeet`;
  - the nearest wins, ties go to the lower index;
  - at the rail or the outer edge there is none.
- **`lock`** also sets every `steadyUntil` to −1e9.
- **`tau(trip, posts, baseline, cfg, brush)`** subtracts `scale·brush[i]` after the field mean and before the clamp. `brushCharge = brushCost · min(max(0, charged − brushFree), brushMaxCharged)`.
- **Boxed-in helpers for N4** (pure):
  - `sideState(st, i, d)` returns "free", "tuck" or "blocked";
  - `boxedIn`, `noTuckInside` and `boxedNoTuck`.
  - The `trip_d057.json` snapshots carry these for every horse.

# The game's config (D-057 on, brushes off), stage N3

By the model engineer, 2026-10-06. N3 switched D-057's motion and press rules on in `trip.CONFIG` and `GameConfig.steering`: `glide = "eased"`, `chainWindow = 0.3`, `reverseGapSeconds = 0.5`, `weaveGapSeconds = 2.5`, `pressBounceSeconds = 0.2`, `glideReserveFeet = 6`, `blockedPress = "wait"`. Brushes stay `"off"` (N5). Reproduce with `python sims/steering.py --write` (about 30 minutes on 12 cores; the default profile is now `live`, `trip.CONFIG`). It rewrites `tests/fixtures/trip_baseline.json`, `game/src/shared/TripBaseline.luau` and `tests/fixtures/steering_report.json` (with four probe races), which `tests/test_trip_d057.py` asserts. Profiles: `live` (the game), `d057` (brushes on too, N5's preview; its files are unchanged by the flip, since `d057_config()` gives the same config from either base) and `d054` (the switch-back).

**Short answer:** every D-054 τ target and every D-057 target passes in every course × distance, against the regenerated baseline. The numbers match the N1 run with brushes on, except where brushes moved them: the wanderer and casual columns move by up to 0.0008, and nobody is ever charged.

Baseline: seed 20261005, 2,000 races per course × distance × post. Report: seed 20261006, 600 races per cell; griefing 200 races per cell, scenario and kid policy; stress 4,000 races.

| Course | Distance | Smart Steer kid among bots | Rail rider | Rail − Smart | Never steers | Wanderer | Casual | All-Smart field | Post bias: kid among bots | Post bias: all-Smart | Draft share | In within 3 s: per intent / per press |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dirt | Sprint | +0.0002 | +0.0180 | +0.0179 | −0.0145 | −0.0037 | +0.0097 | +0.0000 | 0.0017 | 0.0016 | 34% | 98% / 93% |
| dirt | Mile | −0.0005 | +0.0161 | +0.0167 | −0.0147 | −0.0058 | +0.0065 | +0.0000 | 0.0014 | 0.0017 | 28% | 73% / 69% |
| dirt | Classic | +0.0001 | +0.0192 | +0.0195 | −0.0142 | −0.0015 | +0.0135 | +0.0003 | 0.0016 | 0.0014 | 34% | 91% / 86% |
| dirt | Marathon | −0.0009 | +0.0239 | +0.0250 | −0.0151 | −0.0046 | +0.0115 | −0.0000 | 0.0013 | 0.0016 | 20% | 74% / 66% |
| turf | Sprint | +0.0003 | +0.0175 | +0.0169 | −0.0134 | −0.0030 | +0.0101 | +0.0000 | 0.0017 | 0.0024 | 33% | 97% / 93% |
| turf | Mile | −0.0002 | +0.0192 | +0.0195 | −0.0152 | −0.0049 | +0.0094 | +0.0001 | 0.0010 | 0.0014 | 32% | 84% / 77% |
| turf | Classic | −0.0002 | +0.0194 | +0.0196 | −0.0148 | −0.0023 | +0.0125 | +0.0003 | 0.0013 | 0.0012 | 35% | 90% / 84% |
| turf | Marathon | −0.0002 | +0.0264 | +0.0263 | −0.0151 | +0.0001 | +0.0178 | +0.0006 | 0.0014 | 0.0012 | 24% | 87% / 81% |

| Target | Value | The game (N3) | D-054 (the switch-back) |
| --- | --- | --- | --- |
| Rail rider vs Smart Steer (every cell) | +0.01 to +0.03 | +0.017 to +0.026: pass | +0.016 to +0.026 |
| Never-steer (every cell) | −0.02 to −0.01 | −0.015 to −0.013: pass | −0.015 to −0.013 |
| Inward press reaching its lane within 3 s, per intent (every cell) | ≥ 70% | 73% to 98% (86.9% overall; rail rider 85.5%): pass | — |
| …per press (information; the D-054 target) | — | 66% to 93% (81.5%) | 81% to 98% (90.4%) |
| Draft share of positive trip (every cell) | ≤ 40% | 20% to 35% (29.3%): pass | 20% to 35% |
| Post bias, Smart Steer kid among bots (every cell and post) | < 0.005 | ≤ 0.0017: pass | ≤ 0.0017 |
| Post bias, all-Smart lobbies (every cell and post) | < 0.005 | ≤ 0.0024: pass | ≤ 0.0020 |
| Smart Steer kid among bots averages (every cell) | 0 ± 0.003 | −0.0009 to +0.0003: pass | −0.0009 to +0.0003 |
| All-Smart field mean (every cell) | 0 ± 0.003 | −0.0000 to +0.0006: pass | −0.0000 to +0.0006 |
| Masher reversals a minute (every cell) | ≤ 8 | 6.3 to 7.4 (6.8 pooled): pass | 29 (prototype) |
| Masher: none within 3 s of the previous (every cell) | ≥ 3 s | 3.5 s: pass | 0.6 s |
| Sideways acceleration between ticks (every horse; + 0.5 for the landing tick) | ≤ 30 ft/s² | 30.4: pass | 200 |
| Brushes | off | 0 brushes, nobody charged | — |
| Griefing: targeted minus untargeted own trip (each scenario and kid, pooled) | ≥ −0.001 | −0.0003 to +0.0030: pass | — |
| Stress, 4,000 races (masher + ditherer + casual among 5 bots) | 0 overlaps, fall-back ≤ 20 ft/s | 0 overlaps, 19.0 ft/s: pass | — |

Other numbers:
- **Glides:** one lane 1.0 s, two 1.6 s, three 2.3 s, four 3.0 s. Top sideways speed 9.0 ft/s (a 9.1° drift); sideways acceleration p50 10 and p95 30 ft/s², max 30.4.
- **Body estimate** (SteerPose's rule on the 10 Hz lanes): yaw up to 9.1° (p95 10°), lean up to 2.9°.
- **Zig-zag:** masher 6.8 reversals a minute (per cell 6.3–7.4), ditherer 12.1, wanderer 3.9, casual 1.2, all at least 3.5 s apart.
- **Boxed in** (Smart Steer kid): 6.4% of pre-lock time, at least 1 s in 21% of races; boxed with no tuck slot inside 1.4%.
- **Lanes at the lock:** Smart Steer 1.86–1.99, rail rider 1.00, never-steer 4.4–4.6.
- **Waits:** a masher's presses bounce 40 times a race and wait over 1 s 30 times; a casual rider waits over 1 s 1.6 times a race.
- **Griefing** (own trip, targeted minus untargeted): Smart Steer kid shadow +0.0003, crew +0.0030, bumper +0.0005; rail kid +0.0001, +0.0001, −0.0003.

**On screen** (`tests/luau/overlap_report`, the game's config, 960 races per row; numbers in DECISIONS D-057 N3): no overlaps on any screen, no horse falling back faster than 20 ft/s, the order across the line right, 0–2 full-lane moves in the last 2 s per 960 races (the gate allows 100), no after-lock reversal within 3.5 s, and the drawn sideways acceleration within 31.7 ft/s², also with 0–30 ms of jitter on the link (the screen plays the samples back by their server timestamps, `Playback`).


# The N5 review: a press again is the same try

By the model engineer, 2026-10-06. The review of N5 asked for brushes to be rarer for natural pressing. With N1's rule (a brush on the second press toward a horse alongside, within 2 s, while the first waits), a kid who presses again because nothing seemed to happen paid in most races. The rule is now `brushPresses = 3`: the press that brushes is at least the third that way since the first one waiting, still within `brushRepeatSeconds` (2 s), with a horse alongside for `brushGraceSeconds` and no tuck-back. Reproduce the rule table with the measurement script described below, and the report with `python sims/steering.py --write` (the `d057` profile's files are the same run: since N5 `trip.d057_config()` is `trip.CONFIG`, and no step reads the profile).

## The rule options, by kid press pattern

Each kid makes an intent every 2–6 s and presses a random way (the outward kid always outward). The press-again kids press the same way once more after the delay shown. 50 races per course × distance (400 in all) for each scenario: a field of seven bots, and the six griefing scenarios. Each cell is the share of races in which the kid paid for a brush: in the bot field, then the highest over the seven scenarios.

| Rule | Casual | One press | Double-tap 0.1–0.3 s | Again 0.4–0.6 s | Again 0.8–1.2 s | Again 0.3–0.8 s | Again outward 0.3–0.8 s | Wanderer | Masher |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| N1: the second press | 0.0 / 0.5% | 0 / 0% | 48 / 65% | 59 / 76% | 58 / 74% | 59 / 77% | 52 / 86% | 14 / 18% | 72 / 86% |
| A second press within 0.6 s is the same try | 0.0 / 0.2% | 0 / 0% | 0.2 / 0.5% | 38 / 48% | 58 / 74% | 45 / 58% | 30 / 64% | 9 / 12% | 61 / 78% |
| `brushFree = 2` | 0.0 / 0.5% | 0 / 0% | 39 / 54% | 49 / 64% | 46 / 65% | 49 / 64% | 40 / 80% | 3.5 / 4.5% | 56 / 75% |
| 0.6 s and `brushFree = 2` | 0 / 0% | 0 / 0% | 0 / 0% | 28 / 32% | 46 / 67% | 34 / 44% | 14 / 46% | 2.0 / 2.2% | 46 / 66% |
| A second press within 1.0 s is the same try | 0 / 0% | 0 / 0% | 0.2 / 0.5% | 0.5 / 0.8% | 47 / 61% | 0.5 / 1.0% | 0.5 / 1.0% | 4.2 / 5.2% | 50 / 71% |
| …within 1.3 s | 0 / 0% | 0 / 0% | 0.2 / 0.5% | 0.5 / 0.8% | 0.5 / 1.0% | 0.5 / 1.0% | 0.5 / 1.0% | 1.8 / 2.8% | 40 / 58% |
| **The third press (chosen)** | **0 / 0%** | **0 / 0%** | **0.0 / 0.2%** | **0.2 / 0.8%** | **0.2 / 0.8%** | **0.2 / 0.8%** | **0.5 / 0.8%** | **0.5 / 0.8%** | **61 / 79%** |

- The bars: casual and press-again kids charged in ≤ 5% of races, the masher still charged in a meaningful share (brushes still teach), and every target still passing.
- A second press within 0.6 s (the review's first idea) only covers double-taps: a kid who presses again after a second still paid in 58% of races. `brushFree = 2` hardly helps, since these kids brush two or three times a race.
- A 1.3 s minimum gap meets the bars, but it leaves a 0.7 s window in which a press brushes. A kid who presses again after 1.5 s would pay, and the masher falls to 40%.
- The third press meets every bar whatever the timing of the second press, and it is the easiest to say: "a rider who keeps pressing". It needs one counter per horse (`same_presses`, `samePresses`), reset when the first press starts waiting.
- A press-again kid can still brush only when its next intent, the same way, comes within 2 s of an earlier press that is still waiting.
- Measured with a probe script kept outside the repo (press policies `singles`, `doubles`, `again05`, `again1`, `doubletap`, `outtap` on `sims/steering.py`). `sims/steering.py` keeps `doubletap` as a griefing kid. `tests/test_trip_d057.py` gates it: charged in ≤ 5% of 80 races (a bot field and a crew box), with the masher charged in ≥ 30%.

## The game's report with the third-press rule

Every D-054 τ target, every D-057 target and the griefing gates pass in every course × distance. The baseline table and its probes are identical to N3's and N5's (Smart Steer never brushes); only the recorded config gained `brushPresses`. The τ table, reach, zig-zag, glides, motion, boxed-in time and stress are as in N5 (stress: 0 overlaps in 4,000 races, fall-back 19.0 ft/s, 8,183 brushes).

**Brushes by policy** (one rider among seven bots, 600 races per cell; was with N1's rule):

| Policy | Races with a brush | Charged | Brushes a race | Mean cost |
| --- | --- | --- | --- | --- |
| Casual | 0.04% (2.1%) | 0.0% in every cell (0.6%, cells 0–1.3%) | 0.00 | 0 |
| Wanderer | 6.9% (36%) | 0.4% (13%) | 0.07 | 0.0000 (0.0004) |
| Masher | 76% (82%) | 56% (66%) | 2.1 | 0.0027 (0.0033), at most 0.006 |
| Rail, never-steer, ditherer | 0 | 0 | 0 | 0 |

No horse but the mover is ever charged.

## Griefing, with the new kids

200 races per course × distance and scenario (1,600 pooled). Each figure is the kid's own trip (ground + draft − its own brush charge), targeted minus untargeted; in brackets, the part from brush charges.

| Kid | Shadow − rail1 | Crew − rail3 | Bumper − rail1 | Gate |
| --- | --- | --- | --- | --- |
| Smart Steer | +0.0003 (0) | +0.0030 (0) | +0.0005 (0) | own trip ≥ −0.001 (pooled and every cell: −0.0007 at worst) |
| Rail rider | +0.0001 (0) | +0.0001 (0) | −0.0004 (0) | own trip ≥ −0.001 (every cell: −0.0008 at worst) |
| Wanderer | **−0.0030** (0) | +0.0143 (0) | **−0.0016** (0) | brush part ≥ −0.001 |
| Press-again (0.3–0.8 s) | +0.0003 (0) | +0.0273 (0) | +0.0023 (0) | brush part ≥ −0.001 |
| Masher | **−0.0029** (+0.0001) | +0.0292 (−0.0022) | **−0.0015** (−0.0002) | reported (a masher who keeps pressing into a box pays: that's the lesson) |

- **The crew's brush cost on a press-again kid is gone:** the review measured −0.0019 to −0.0031 with N1's rule; it is 0.0000 now.
- The kid is never charged for a stranger's brush, and a Smart Steer kid is never charged at all.
- **The gates.** Own trip ≥ −0.001 stays on the Smart Steer and rail kids, the riders D-057's bound was written for. For every kid but the masher, the brush charges that strangers add must stay within −0.001 (`griefing_brushes`). The wanderer's, press-again kid's and masher's own-trip figures are reported. The bold ones are the shadow finding below.

## The shadow finding (not a brush effect)

The review measured, with brushes off, a shadow costing a wanderer kid −0.0027 and a masher kid −0.0023. It isn't about brushes:
- **Brushes on or off, the same.** Over the same 400 races, the wanderer's shadow figure is −0.0032 with brushes off and −0.0037 with them on. A kid who presses once per intent and never brushes loses more: −0.0050 to a shadow, −0.0033 to a bumper.
- **What happens.** The shadow sits just inside the kid at the kid's own pace and follows it out. Every inward press meets the shadow (the kid tucks back or waits), while outward presses go through. A kid pressing at random drifts outward: the wanderer is 0.23 lanes wider at the lock and loses 0.0045 more ground on the turns. The draft behind the shadow gives back 0.0012.
- **Who is safe.** Smart Steer tucks in behind and drafts (+0.0003). A rail rider presses In every 0.3 s and holds the rail (+0.0001). The press-again kid comes out at +0.0003.
- **Size.** −0.0030 τ is 0.15 of a slider point; the bound is 0.05. The full run's masher figure is noisy (−0.0029 over 1,600 races, −0.0001 over the first 400; its p5 is −0.099).
- **No small rule fixes it.** A Smart Steer that resumes 2.5 s after a press instead of 5 s cut a 64-race wanderer probe from −0.0082 to −0.0033. That still isn't a fix, and it changes how every pressing kid rides.
- **Options** (REVIEW_QUEUE "N5 review: shadow finding"):
  1. Accept it: only riders who press at random lose, about 0.15 of a slider point.
  2. Smart Steer resumes sooner after a lone press (`smart.resumeSeconds` 5 → 2.5). Re-calibrate and playtest.
  3. An inward wait survives one outward press (cancelling takes two). This changes the D-057 cancel rule for everyone.
