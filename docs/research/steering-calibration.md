# Race steering calibration (D-054, stage S0)

By the model engineer, 2026-10-05; revised after the PR #37 review. Python reference `src/trip.py`, calibration `sims/steering.py`, tests `tests/test_trip.py`. Reproduce with `python sims/steering.py --write`, which takes about 30 minutes on 12 cores. It rewrites `tests/fixtures/trip_baseline.json`, `game/src/shared/TripBaseline.luau` and the stored report `tests/fixtures/steering_report.json`, which the tests assert. `python sims/steering.py` reruns the report against the checked-in baseline.

**Short answer:** every acceptance target passes in every course × distance cell, including post bias for a Smart Steer kid among bots and in all-Smart lobbies. Changes from the plan:
- `groundPerLaneTurn` 0.012 → **0.010**
- `draftPerSecond` 0.0012 → **0.0010**
- `tuckBackMax` 12 → **24 ft** (3 lengths)
- new `bots.wideShare = 0.20`
- new `laneBand` and `tuckReleasePerSecond`
- before the lock, gaps move exactly as `RaceView` moves them (D-055's 10 ft/s limiter)
- a lane change never pushes the horse behind

`smart.homeLane` (2) and every other plan value are unchanged.

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
| dirt | Classic | +0.0003 | +0.0193 | +0.0194 | −0.0142 | −0.0001 | +0.0145 | +0.0003 | 0.0018 | 0.0016 | 35% | 94% |
| dirt | Marathon | −0.0009 | +0.0241 | +0.0252 | −0.0151 | −0.0042 | +0.0112 | +0.0000 | 0.0013 | 0.0017 | 20% | 81% |
| turf | Sprint | +0.0003 | +0.0170 | +0.0165 | −0.0133 | −0.0025 | +0.0098 | +0.0000 | 0.0011 | 0.0020 | 35% | 98% |
| turf | Mile | −0.0001 | +0.0193 | +0.0197 | −0.0152 | −0.0039 | +0.0095 | +0.0001 | 0.0012 | 0.0014 | 33% | 85% |
| turf | Classic | −0.0001 | +0.0195 | +0.0199 | −0.0148 | −0.0012 | +0.0132 | +0.0003 | 0.0016 | 0.0014 | 35% | 92% |
| turf | Marathon | −0.0001 | +0.0264 | +0.0263 | −0.0151 | +0.0015 | +0.0183 | +0.0006 | 0.0018 | 0.0011 | 24% | 91% |

| Target (every cell) | Value | Result |
| --- | --- | --- |
| Rail rider vs Smart Steer | +0.01 to +0.03 | +0.017 to +0.026: pass |
| Never-steer | −0.02 to −0.01 | −0.015 to −0.013: pass |
| Inward request reaching its lane within 3 s | ≥ 70% | 81% to 98% (90.4% overall; rail rider 94.3%): pass |
| Draft share of positive trip | ≤ 40% | 20% to 35% (29.6% overall): pass |
| Post bias, Smart Steer kid among bots (every post) | < 0.005 | ≤ 0.0018 (absolute mean τ per post ≤ 0.0022): pass |
| Post bias, all-Smart lobbies (every post) | < 0.005 | ≤ 0.0020: pass |
| Smart Steer kid among bots averages | 0 ± 0.003 | −0.0009 to +0.0003: pass |
| All-Smart field mean | 0 ± 0.003 | −0.0000 to +0.0006: pass |

Per-post residual: mean τ at each post minus the mean over posts, posts 1 to 8.

| Cell | Smart Steer kid among bots | All-Smart lobbies | Bot fields (for information) |
| --- | --- | --- | --- |
| dirt Sprint | −.0002 −.0006 −.0010 −.0005 +.0000 +.0005 +.0008 +.0009 | −.0000 +.0009 +.0008 +.0006 +.0001 −.0005 −.0005 −.0014 | −.0000 +.0023 −.0012 −.0007 −.0005 +.0001 −.0001 +.0001 |
| dirt Mile | +.0003 +.0006 −.0014 −.0005 −.0002 +.0001 +.0005 +.0007 | −.0004 −.0006 +.0017 +.0005 −.0000 −.0002 −.0004 −.0006 | −.0014 +.0073 −.0013 −.0006 −.0015 −.0020 −.0005 −.0001 |
| dirt Classic | +.0008 −.0014 −.0012 −.0007 −.0001 +.0005 +.0003 +.0018 | −.0007 +.0010 +.0015 +.0013 −.0002 +.0002 −.0015 −.0016 | +.0001 +.0033 −.0021 −.0005 −.0003 −.0005 −.0005 +.0004 |
| dirt Marathon | +.0003 +.0007 −.0013 −.0008 −.0001 +.0002 +.0004 +.0006 | −.0003 −.0007 +.0017 +.0005 +.0001 −.0003 −.0004 −.0005 | −.0027 +.0071 −.0006 −.0001 −.0014 −.0005 −.0012 −.0006 |
| turf Sprint | −.0001 −.0006 −.0009 −.0008 −.0000 +.0005 +.0009 +.0011 | −.0001 +.0008 +.0008 +.0005 +.0002 −.0001 −.0002 −.0020 | +.0001 +.0025 −.0010 −.0013 −.0001 −.0002 −.0001 +.0001 |
| turf Mile | +.0009 +.0007 −.0012 −.0006 −.0005 +.0001 +.0006 +.0001 | −.0014 −.0006 +.0004 +.0007 +.0001 +.0007 +.0002 −.0001 | −.0003 +.0061 −.0023 −.0014 −.0012 +.0000 −.0008 −.0002 |
| turf Classic | +.0012 −.0013 −.0016 −.0003 +.0001 −.0001 +.0009 +.0012 | −.0010 +.0009 +.0014 +.0012 +.0005 −.0011 −.0006 −.0013 | +.0001 +.0040 −.0018 −.0010 −.0005 −.0010 −.0001 +.0004 |
| turf Marathon | +.0009 −.0014 −.0011 −.0011 +.0001 −.0002 +.0011 +.0018 | −.0011 +.0006 +.0010 +.0011 −.0000 −.0007 −.0006 −.0003 | −.0012 +.0029 −.0002 −.0011 +.0004 −.0014 +.0001 +.0005 |

Other numbers:
- **Lane at the lock:** Smart Steer 1.9–2.0, rail rider 1.0, never-steer 4.4–4.6.
- **Clamp binding:** never-steer sits on the floor in 57–75% of races. The rail rider hits the ceiling in 10% of dirt Marathons, 5% of turf Marathons, and in no races elsewhere.
- **Spacing:** no two horses sharing a lane were ever closer than `holdGap` (10 ft) at the end of a tick.

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

## Draft and tapping skill (trade-off, provisional)

Drafting rewards being behind someone, so the horse in front of a line drafts least. In bot fields, after the first checkpoint:

| Cell | On-screen leader τ | Last horse τ | Best tapper τ | Worst tapper τ |
| --- | --- | --- | --- | --- |
| dirt Sprint | −0.0014 | +0.0020 | +0.0000 | +0.0001 |
| dirt Mile | +0.0018 | +0.0011 | +0.0011 | +0.0010 |
| dirt Classic | −0.0020 | +0.0042 | +0.0012 | +0.0002 |
| dirt Marathon | +0.0010 | +0.0025 | +0.0025 | +0.0014 |
| turf Sprint | −0.0013 | +0.0013 | +0.0004 | +0.0001 |
| turf Mile | −0.0008 | +0.0029 | +0.0016 | +0.0014 |
| turf Classic | −0.0017 | +0.0039 | +0.0008 | +0.0009 |
| turf Marathon | −0.0016 | +0.0047 | +0.0018 | +0.0025 |

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
2. **Hold:** in the order "leader first, then the inside horse, then the lower index", nobody sits closer than 10 ft behind a horse within 0.9 lanes.
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
