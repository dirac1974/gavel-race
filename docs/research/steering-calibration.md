# Race steering calibration (D-054, stage S0)

By the model engineer, 2026-10-05. Python reference `src/trip.py`, calibration `sims/steering.py`, tests `tests/test_trip.py`. Reproduce with `python sims/steering.py --write` (about 4 minutes on 12 cores; `python sims/steering.py` reruns the report against the checked-in baseline).

**Short answer:** every acceptance target passes on both courses and all four distances after two tuning changes: `groundPerLaneTurn` 0.012 → **0.010**, and a new bot share that rides one lane wider, `bots.wideShare = 0.20`. `draftPerSecond` (0.0012) and `smart.homeLane` (2) are unchanged.

## Final values (mirror of `GameConfig.steering` for S2)

```lua
GameConfig.steering = {
	enabled = true, scale = 1,
	floor = -0.02, ceiling = 0.04,
	groundPerLaneTurn = 0.010,     -- was 0.012 in the plan (S0 calibration)
	draftPerSecond = 0.0012, draftCap = 0.016,
	draftNear = 4, draftFar = 24,
	laneSeconds = 0.6, minRequestGap = 0.6, maxQueued = 1,
	clearFeet = 8, holdGap = 10,
	tuckBackMax = 12, outwardWaitSeconds = 1.0,
	tickHz = 10, sendHz = 10,
	gapRampSeconds = 8,
	lockBellSeconds = 3,
	smart = { homeLane = 2, turnLeadSeconds = 8, resumeSeconds = 5 },
	bots = { turnLeadMin = 4, turnLeadMax = 12, railShare = 0.25, wideShare = 0.20 }, -- wideShare new (S0)
	introRaces = 3,
	stars = { 0.015, -0.005 },
	laneBand = 0.9,                -- new (S0): horses closer than this, in lanes, share a lane
	smoothPerSecond = 2.5,         -- new (S0): offsets ease toward their target (the client's lerp rate)
	tuckReleasePerSecond = 4,      -- new (S0): a tuck-back fades this fast once nothing blocks
}
```

The trip also reads `raceSpeedStudsPerSecond` (56), `raceShape.leadFeetPerShare` (320) and `lanes` (8) from `GameConfig`, and the course geometry from `TrackLayout`.

## Report (final config)

Baseline: seed 20261005, 2,000 bot-mix races per course × distance (16,000 races, so 2,000 samples per post). Report: a fresh seed (20261006), 600 races per course × distance; in each race one focal rider at a random post among seven bots, and the same race is replayed for every policy (paired).

Mean τ of the focal rider:

| Course | Distance | Smart Steer | Rail rider | Rail − Smart | Never steers | Wanderer | Casual | All-Smart field | Post bias max | Draft share | In within 3 s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dirt | Sprint | +0.0003 | +0.0203 | +0.0200 | −0.0135 | −0.0021 | +0.0082 | +0.0000 | 0.0008 | 38% | 87% |
| dirt | Mile | −0.0006 | +0.0164 | +0.0170 | −0.0155 | −0.0075 | +0.0037 | +0.0000 | 0.0010 | 29% | 71% |
| dirt | Classic | +0.0007 | +0.0241 | +0.0234 | −0.0140 | −0.0005 | +0.0123 | +0.0006 | 0.0008 | 34% | 78% |
| dirt | Marathon | −0.0014 | +0.0244 | +0.0258 | −0.0161 | −0.0073 | +0.0070 | +0.0000 | 0.0010 | 20% | 75% |
| turf | Sprint | +0.0005 | +0.0173 | +0.0168 | −0.0132 | −0.0030 | +0.0078 | −0.0000 | 0.0009 | 39% | 85% |
| turf | Mile | −0.0003 | +0.0241 | +0.0244 | −0.0152 | −0.0031 | +0.0068 | +0.0005 | 0.0013 | 33% | 69% |
| turf | Classic | +0.0000 | +0.0249 | +0.0249 | −0.0144 | −0.0011 | +0.0111 | +0.0005 | 0.0012 | 34% | 75% |
| turf | Marathon | +0.0025 | +0.0309 | +0.0284 | −0.0145 | +0.0015 | +0.0160 | +0.0012 | 0.0011 | 24% | 77% |

| Target | Value | Result |
| --- | --- | --- |
| Rail rider vs Smart Steer | +0.01 to +0.03 | +0.017 to +0.028, every cell: **pass** |
| Never-steer | −0.02 to −0.01 | −0.016 to −0.013, every cell: **pass** |
| Inward request reaching its lane within 3 s | ≥ 70% | 77.2% overall (69–87% by cell; rail rider 97.5%): **pass** |
| Draft share of positive trip | ≤ 40% | 30.3% overall (20–39% by cell): **pass** |
| Residual post bias | < 0.005 | at most 0.0013: **pass** |
| Smart Steer field mean | 0 ± 0.003 | all-Smart fields −0.0000 to +0.0012: **pass**; one Smart Steer rider among seven bots −0.0014 to +0.0025: **pass** |

Other numbers worth knowing:
- Lane at the lock: Smart Steer 1.9–2.4, rail rider 1.0, never-steer 4.4–4.6.
- Never-steer sits on the floor (−0.02) in 51–76% of races. The rail rider hits the ceiling in 34% of turf Marathons and in at most 3% of races elsewhere.
- Clamp shift (the mean τ of a bot-mix field, from the floor clipping wide trips): 0 in Sprints, +0.001 in Miles and Classics, +0.002 in Marathons.
- No two horses sharing a lane were ever closer than `holdGap` (10 ft) at the end of a tick.

### How each number is measured

- **Policies:** Smart Steer = Smart Steer on, no presses. Rail rider = presses ◀ every 0.3 s until on the rail. Never steers = Smart Steer off, no presses. Wanderer = a random arrow about every 3 s. Casual = ◀ about every 5 s and ▶ about every 20 s, Smart Steer on. Bots = Smart Steer with variety.
- **Within 3 s:** every ◀ press from the casual rider that was accepted or queued at least 3 s before the lock; success if the horse is in the lane it asked for within 3 s.
- **Draft share:** each bot's τ is split into a draft part and a ground part (each against its own per-post mean and the field mean). Over lanes with τ > 0, it is the draft part's share of the positive parts.
- **Post bias:** in bot-mix races from a fresh seed, each post's mean τ minus the mean over posts. The mean over posts is the clamp shift, which no per-post table can remove: a shift common to every post cancels in the field mean.

## What changed from the plan, and why

1. **`groundPerLaneTurn` 0.012 → 0.010.** At 0.012 the rail rider beat Smart Steer by +0.030 in both Marathons (three turns count: two live, plus the far turn booked at the lock), the top of the target range. 0.010 centres the range: +0.017 (turf Sprint, one turn) to +0.028 (turf Marathon). The ceiling, the floor and the size statements in D-054 (best trip +0.04 = 2 points of S) are unchanged.
2. **`bots.wideShare = 0.20` (new).** With only "25% ride the rail", the average bot steered better than Smart Steer, so a Smart Steer kid racing seven bots averaged τ = −0.005 (dirt Mile) and −0.007 (dirt Marathon), where the first turn comes straight out of the gate. That is the plan's "bots out-steer new kids" risk. Bots now pick their lane from the same uniform: below 0.25 the rail, from 0.80 one lane wider than Smart Steer (lane 3), otherwise Smart Steer's lane 2. At 0.25 the turf Marathon sat at +0.0030, on the edge of the target, because the 4–12 s turn lead already makes some bots late there. At 0.20 every cell is within −0.0014 to +0.0025.
3. **Tuck-in finds the slot behind the whole group.** In the first build a horse blocked toward the rail eased back by a fixed amount below its skill target. A horse already held behind another in its own lane then never moved, and inward requests reached their lane within 3 s only 63% of the time. Now `_slot` walks down the horses alongside in the target lane to the gap behind the last of them. The horse eases back there if that gap is at most `tuckBackMax` (12 ft) behind where it is now, and otherwise waits for room. Result: 77%.
4. **Baseline calibration passes.** Plain per-post mean trips left posts up to 0.004 apart in mean clamped τ (dirt Marathon, 1,000-race trial), because the floor clips the bad trips of the posts with the widest spread. The generator now runs four fixed-point passes that move each post's mean clamped τ to the mean over posts.
5. **Three keys the plan left implicit:** `laneBand` 0.9, `smoothPerSecond` 2.5 and `tuckReleasePerSecond` 4.

Trials, for the record (smaller runs, same seeds):

| groundPerLaneTurn | bots.wideShare | Rail − Smart (range) | Smart among bots (range) |
| --- | --- | --- | --- |
| 0.012 | 0 | +0.018 to +0.030 | −0.0073 to +0.0006 |
| 0.010 | 0 | +0.017 to +0.029 | −0.0063 to −0.0000 |
| 0.010 | 0.25 | +0.017 to +0.028 | −0.0003 to +0.0030 |
| **0.010** | **0.20** | **+0.017 to +0.028** | **−0.0014 to +0.0025** |

## The model in one tick (for the Luau mirror)

`step(state, live, intents, t, dt)`, in this order:
1. Skill target = 320 × (live − 1/n) × min(1, t / 8), minus the lane's tuck-back; offsets ease toward it at 2.5/s.
2. Hold: in the order "leader first, then the inside horse, then the lower index", nobody sits closer than 10 ft behind a horse within 0.9 lanes.
3. Lane changes: this tick's presses in arrival order (`accept_intent`), then every other lane in the same leader-first order. A lane that is not gliding and has waited `minRequestGap` takes its waiting press (or its queued one). Otherwise, Smart Steer heads in one lane when the lane is in a turn or within its turn lead of the next one (the far turn at the lock counts), if the lane is wider than its home lane. A move is clear when no horse in or gliding into the target lane is within ±8 ft. When blocked toward the rail the horse tucks back to the slot (see above). A blocked outward press cancels after 1 s.
4. Glide 1/0.6 lanes per second, then hold again, so a horse arriving in a lane never overlaps.
5. Ground: 0.010 × (x − 1) per 180° of each live turn crossed this tick. Draft: 0.0012 per second while 4–24 ft behind a horse within 0.9 lanes, up to 0.016, clipped at the lock time.

`lock` books the far turn from each horse's lane position at the bell; `tau(trip, posts, baseline row)` = clamp(scale × (trip − baseline[post] − field mean), −0.02, +0.04).

**Mirror rules** (D-012): only +, −, ×, ÷, comparisons, min, max and abs inside `step`, `lock` and `tau`. Python's float `%` differs from Luau's, so `trip._lmod` uses Luau's `a − floor(a/b)·b`. Every sort uses a total key, and "never" times are −1e9. Bots' two uniforms per lane (rail, lead) are drawn from the race generator after all existing draws; every lane consumes them, bot or not. `tests/fixtures/trip.json` (200 runs, generated by `make_fixtures.py`) holds per-tick intents, the answers, x/off/tgt snapshots every 5 s, the trip and τ; six runs use other configs (scale 0.5 and 0, steering off, no queue, Smart Steer on the rail, no gap ramp).

## Observations for S2–S4 and playtests

- **Draft caps quickly.** At 0.0012/s the 0.016 cap fills in about 13 s, so in Classics and Marathons nearly every horse that spends time behind another caps, and the draft mainly separates horses that were never tucked in (the leaders of each line). A front-runner's τ is therefore slightly below the field's. The share target still holds (30%), but if playtests show "Tucked in!" means little, a lower rate with the same cap would spread it.
- **Lines of horses.** Smart Steer fills lane 2 first, so lane 2 often becomes a line of 3–5 horses 10 ft apart, and horses outside it wait. That is realistic, and it is where most of the 23% of slow inward presses come from (the Miles are 69–71%: the turn comes straight out of the gate, when the field is still level).
- **Held horses sit well behind their skill target** until the lock. After the lock the S2 server hands the offsets back to RaceShape, so expect the surge the risk table mentions; ease it with the client lerp or a short blend.
- **Posts.** Trip assumes posts are lane positions 1–8. After S1's shuffle each lane index is its post, which is what the sims use.
