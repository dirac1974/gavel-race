# Plan: training rides (D-053) and race steering (D-054)

For the tech lead. Written 2026-10-05 by the design moderator after debates 009 and 010; nothing in the repo was changed.

**Copy map**
- `debate_training.md` → `docs/debates/009-training-rides.md`
- `debate_steering.md` → `docs/debates/010-race-steering.md`
- Section B → `docs/memory/DECISIONS.md` (after D-052, the audio PR) and `docs/memory/REVIEW_QUEUE.md`
- Agenda lines → `docs/debates/README.md`
- Backlog lines → `docs/memory/STATUS.md`

**Prototype scripts** (Python, not for the repo; a starting point for the model-engineer in S0): the session scratchpad holds `trip_effect.py`, `trip_sim2.py`, `trip_sim3.py`, `trip_sim4.py` and `trip_sim5.py`.

---

## B. Decisions (paste-ready)

### D-053 — Training rides

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
- Links: docs/debates/009-training-rides.md, game/src/shared/TrainingCourses.luau, game/src/shared/TrainingRide.luau, game/src/server/TrainingService.server.luau, game/src/client/TrainingRideClient.client.luau, game/src/shared/WorldLayout.luau, game/src/server/WorldScene.luau

### D-054 — Race steering

- Date: 2026-10-05
- Status: Accepted (provisional)
- Decided by: team, debate 010 (4/4 after one rebuttal round; drafting 3–1, Young player wanted ground only); David asked for steering "constrained to look realistic where they can affect the outcome slightly".
- Decision:
  - **When:** riders change lanes from the gate to the far-turn entry. Three soft bell ticks, then "Lanes locked!"; after that lanes are cosmetic, and the stretch is the slider and the Final Burst only.
  - **How a lane change works:**
    - One press moves one lane, with a 0.6 s glide that starts instantly on the rider's screen; at most one change per 0.6 s, one queued.
    - **Tuck-in:** a horse alongside blocking a move toward the rail makes yours ease back (up to ~1.5 lengths) and slot in behind it. This is visual only.
    - A blocked move outward cancels after 1 s.
    - Horses never overlap or bump; the mover gives way; a horse held behind another is drawn there.
  - **The trip:**
    - Ground: 0.012 per lane off the rail per 180° of turn. Earlier turns count live; the far turn is booked from the lane held at the bell.
    - Tucked in: 0.0012 per second while 0.5–3 lengths behind a horse in the same lane, before the lock only, capped at 0.016.
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
    - Bots use Smart Steer with variety (4–12 s lead before turns; 25% ride the rail) drawn after all existing random draws.
    - Posts are drawn at random by the server (no longer humans first), never shown as a draw, and corrected by the per-post baseline.
  - **Feedback:** "Saved ground!" at turn exits, "Tucked in!" with wind lines, a gentle tip when wide into a turn (never "lost a place"), and "Good trip ★★☆" on the results (★★★ at τ ≥ +0.015, ★★ at ≥ −0.005, otherwise ★, never zero). "Your trip gained you N places!" appears only when positive.
  - **Replays** record each horse's lane per frame on this screen and add your line as a ribbon with green chevrons, wind lines and the lock marker; no ideal-line ghost.
  - **Python:** `live_chances(..., extra)` and `src/trip.py` mirror `Trip.luau` exactly (D-012).
- Tuning: in the moderator's prototype a skilled steerer gains +0.011 to +0.023 over Smart Steer, a rider who never steers with Smart Steer off loses 0.014–0.016, and the post baseline cuts post bias from up to ±0.02 to at most 0.003. Without tuck-in most lane changes were refused. All values are in `GameConfig.steering`, and the post baselines are generated into `TripBaseline.luau` by `sims/steering.py`.
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

### REVIEW_QUEUE rows

| Decision | Summary | How to reverse |
| --- | --- | --- |
| D-053 | Training rides: four 35–50 s courses on your own horse (Sprint Lane hoops on a training oval, Gate Break practice gate, Hill Climb following a lead pony, Mud Splash gymkhana with canter-only poles); scored by the server from 10 Hz samples; no failure states, no Energy cost, weekly cap unchanged; courses stay open after the cap for stars and ribbons; private ghost; friends ride together without ranked times; Quick Train keeps the old games | `GameConfig.training.mode = "meters"` brings back the paddock games only; course values in `GameConfig.training` |
| D-054 | Race steering: lane changes from the gate to the far turn, then a bell locks lanes; ground on turns plus "tucked in" credit, scored against the field and a per-post baseline; worth −1 to +2 points of riding score (clamp −0.02/+0.04); no boxed-in penalty; Smart Steer on by default; ◀ ▶ buttons, A/D, D-pad | `GameConfig.steering.scale = 0` (cosmetic) or `enabled = false` (today's fixed lanes) |

### Debates README agenda lines

```
8. ~~009 — Training rides~~: decided as D-053. Record: [009](009-training-rides.md).
9. ~~010 — Race steering~~: decided as D-054. Record: [010](010-race-steering.md).
```

### STATUS backlog (suggested placement)

After "Studio playtest of the world" and "Sound and voice":

```
3. **Training rides** (D-053): Training Ground and oval (T1), server-scored Sprint Lane + Mud Splash (T2), Gate Break + Hill Climb (T3), ghosts / Ride together / server Quick Train (T4). Plan: docs/debates/009.
4. **Race steering** (D-054): Python trip model + calibration (S0), rail coordinates + random posts (S1), Smart Steer on the server (S2), rider controls (S3), replays and results (S4). Plan: docs/debates/010.
```

---

## C. Implementation plans

Each stage is sized for one engineer and one PR, and passes `python -m pytest -q && bash scripts/policy_guard.sh`. Everything new sits behind config.

### Training rides (D-053)

**Config: `GameConfig.training` (new)**

```lua
GameConfig.training = {
	mode = "rides",                 -- "rides" | "meters" (paddock games only, as before D-053)
	quickTrain = true,              -- show the 10-second games as "Quick train"
	quickQualityCap = 0.85,
	sampleHz = 10,
	maxSpeed = 53,                  -- studs/s horizontal: gallop 46 + 15%
	maxStep = 12,                   -- studs between samples (teleport)
	maxBadShare = 0.10,             -- more discarded than this: score at the floor
	enforceFloor = false,           -- log-only for the first two weeks
	sessionGapSeconds = 4,
	maxSessionsPerHour = 40,
	maxSessionSeconds = 120,
	countdownSeconds = 3,
	stars = { 60, 90 },             -- 2 and 3 stars
	ribbons = { silver = 75, gold = 90 },
	parFactor = 1.15,               -- par = ideal time × this; gold needs under par
	magnetStuds = 4,
	gallop = 46, canter = 20,
	oval = { cx = 800, cz = 0, straight = 160, radius = 55, width = 24 },
	speed = { laps = 3, hoopsPerLap = 6, hoopWidth = 10 },
	accel = { breaks = 3, bellMin = 1.5, bellMax = 3.5, dash = 120, fullReact = 0.5, zeroReact = 2.0, breakFloor = 40, goSpeed = 20 },
	stamina = { laps = 2, ringNear = 8, ringFar = 24, ringHalfWidth = 6, ponyMin = 30, ponyMax = 42, grace = 3, hill = 6 },
	grit = { mud = 4, logs = 3, poles = 4, logHeight = 2, points = { mud = 7.5, log = 12, pole = 8.5 } },
	ghostHz = 4, ghostMaxPoints = 300, ghostQuantum = 0.5,
}
```

**T1. Training Ground build** (roblox-engineer)
- `game/src/shared/WorldLayout.luau`:
  - `places.trainingGround = { x = 800, z = -70, fx = 0, fz = -1, label = "Training Ground", w = 300, d = 140 }`. Its rect is x 650–950, z −70 to 70, so trees keep out automatically.
  - `WorldLayout.trainingOval` and the link path from the paddock's south gate (x 760, z −150).
- New `game/src/shared/TrainingCourses.luau` (pure):
  - `ovalPoint(d, lateral)`;
  - course definitions built from config: hoops (centre, normal, width), gate box and flag line, the gymkhana elements inside the paddock rect (mud rects, log lines, poles with their required side), start points;
  - `idealSeconds(course)` and `ponyAt(seed, t)` (deterministic speed profile and weave).
- `game/src/server/WorldScene.luau`:
  - oval rails and dirt, a gentle berm on one straight, hoops (parts plus a ring; glow is client-side per session);
  - the practice gate (reuse the uploaded gate-stall model), the south paddock gate, gymkhana props (`log_jump` model, poles, mud), picture signs.
  - No Meshy credits.
- Tests (`tests/luau/world_tests.luau`):
  - every element sits inside its area; no overlap with places, plots or the Trail;
  - hoops lie on the track surface;
  - each course's ideal time is 35–50 s at the configured speeds;
  - log height < rig hop height (JumpPower 42 ≈ 4.5 studs);
  - `ponyAt` is deterministic and stays on the track.

**T2. Server-scored rides: Sprint Lane and Mud Splash**
- New `game/src/shared/TrainingRide.luau` (pure):
  - `validate(samples, bounds, cfg)` → kept samples and bad share;
  - `crossings(samples, gate)`: segment-plane crossings with direction and order;
  - `scoreSpeed`, `scoreGrit`: puddle = sample inside the rect; log = crossing with an airborne sample (root y ≥ ground + 1.5 within ±3 studs); pole = side test;
  - `finalize(raw, badShare, cfg)` → score, stars, ribbon.
- `game/src/server/TrainingService.server.luau`:
  - remotes `TrainStart(horseId, course)`, `TrainBegin` (course, seed, t0), `TrainEnd` (result), `TrainAbort`;
  - session table; a 10 Hz Heartbeat sampler on `Rides.horseOf(player).PrimaryPart`;
  - checks: horse yours and stalled, riding it, inside the ground, not Racing, gap and hourly limit;
  - then `Training.train(h, stat, serverScore, now)`, `Progress.record("train")`, ribbons and best saved;
  - abort on the Racing attribute, dismount or leaving.
  - Validation failures are logged while `enforceFloor = false`.
- `game/src/server/Rides.luau`: register two collision groups. `RideHorses` holds every ride rig. `TrainingRiders` still collides with the world (ground, rails, logs) but not with `RideHorses` or with itself. Do not simply make it non-colliding with Default, or course riders would fall through the ground. Move a rig into `TrainingRiders` for a session and back afterwards. Make sure the chosen horse is the active, called horse.
- `game/src/client/RideClient.client.luau`: course mode (auto-gallop at the start, canter cap in the pole zone, hoop magnet) and an R2 gallop binding.
- New `game/src/client/TrainingRideClient.client.luau`:
  - course picker (four picture signs plus "Quick train"), 3-2-1, next-hoop glow, hoofprints, three lap dots, no timer;
  - end card: stars, then the stat bar grows ("+1.4 Speed!"), then the ribbon; "Ride again" and "Done"; the after-cap line.
- `game/src/client/PaddockClient.client.luau`: the menu opens the picker; the old games move behind "Quick train" (still client-scored until T4).
- `game/src/shared/Profile.luau`: per horse `ribbons[course]` and `trainingBest[course] = { score, seconds }`, repaired on load.
- Tests (Lune):
  - synthetic paths: perfect run → 100; missed hoops; reversed or out-of-order crossings don't count;
  - a teleport sample and samples over 53 studs/s are discarded;
  - >10% bad → floor when enforcing, a normal score when log-only;
  - each puddle, log and pole case;
  - Profile repair of the new fields; the session rate-limit helper.

**T3. Gate Break and Hill Climb, plus Easy Rein**
- `TrainingRide.scoreAccel`:
  - bell time from the seed;
  - reaction = first sample over `goSpeed` after the bell, minus the player's one-way latency allowance (`TapTime.rewindAllowance`, capped 0.3 s);
  - an early go reruns that break once; a start counts only from inside the stall box.
- `TrainingRide.scoreStamina`: ring membership against `ponyAt(seed, t)`.
- Client:
  - the Pip NPC is a horse model at 0.85 scale with a lead-pony cloth (no new models), seen by its rider and riding friends;
  - inside the ring the client sets the rig's speed to Pip's.
- Easy Rein: a `settings.easyRein` flag (SettingsService, Profile, a GrownUps settings toggle), with a strong client-side steering assist.
- Tests: reaction scoring with an early go and the latency allowance; ring scoring with lagging and weaving paths; the server's and client's pony positions agree for the same seed.

**T4. Ghosts, rosettes, Ride together, Quick Train on the server**
- Ghosts:
  - a separate DataStore key per player (`ghosts_<userId>`) keeps profiles small;
  - the best validated run per course, at 4 Hz, quantized to 0.5 studs, ≤ 300 points;
  - client playback as a see-through horse; a "Share my ghost with friends" toggle, off by default.
- Ride together: friendship checked with `Player:IsFriendsWith` (pcall, cached at join); a shared countdown; each rider scored alone; a shared card with stars and ribbons only.
- `StableService.server.luau`: rosettes on the stall wall for gold ribbons.
- Quick Train on the server:
  - the server seeds each meter game; the client sends tap times resolved with `TapTime.resolve`;
  - quality capped at 0.85; the `Train` remote no longer takes a client score.
- Tests: ghost encode/decode round trip and size bound; friend gating; Quick Train scoring for a given seed matches the client's preview functions.

**T5. This week's course (later)**
- Four Mud Splash layouts chosen by `Training.week(now) % 4`, named "This week's course".
- No countdown or "last chance" text; ribbons are per layout and can be earned whenever it comes back.

### Race steering (D-054)

**Config: `GameConfig.steering` (new)** — final values after the S0 calibration (`trip.CONFIG` in `src/trip.py`; docs/research/steering-calibration.md):

```lua
GameConfig.steering = {
	enabled = true,                -- false: today's fixed lanes
	scale = 1,                     -- 0: steering is cosmetic (no effect on chance)
	floor = -0.02, ceiling = 0.04, -- clamp on τ (1 point of S = 0.02)
	groundPerLaneTurn = 0.010,     -- per lane off the rail per 180° of turn (0.012 before S0)
	draftPerSecond = 0.0010,       -- 0.0012 before S0
	draftCap = 0.016,
	draftNear = 4, draftFar = 24,  -- feet behind the horse ahead in your lane (0.5–3 lengths)
	laneSeconds = 0.6, minRequestGap = 0.6,
	maxQueued = 1,                 -- 0 or 1 (one press waits behind the one in progress)
	clearFeet = 8,                 -- a lane change needs 1 length clear ahead in the new lane...
	holdGap = 10,                  -- ...and this much behind; a held horse sits this far back
	tuckBackMax = 24,              -- ease back up to 3 lengths to slot in (12 before S0)
	outwardWaitSeconds = 1.0,
	tickHz = 10, sendHz = 10,
	gapRampSeconds = 8,            -- gaps grow in over 8 s (replaces 30% of the race while steering is on)
	lockBellSeconds = 3,
	smart = { homeLane = 2, turnLeadSeconds = 8, resumeSeconds = 5 },
	bots = { turnLeadMin = 4, turnLeadMax = 12, railShare = 0.25, wideShare = 0.20 }, -- wideShare added in S0
	introRaces = 3,
	stars = { 0.015, -0.005 },     -- trip ★★★ and ★★ thresholds
	laneBand = 0.9,                -- S0: horses closer than this (in lanes) share a lane
	tuckReleasePerSecond = 4,      -- S0: a tuck-back fades this fast once nothing blocks
}
```

Before the lock, Trip moves gaps exactly as `RaceView` does (D-055: eased at 2.5/s, no faster than `GameConfig.raceView.maxGapFeetPerSecond` unless a horse must hurry to its place by the line), so server clearances match the screen.

**S0. Python reference and calibration** (model-engineer; no game changes)
- `src/gavel_race_v2.py`: `live_chances(q, R, cfg, extra=None)`, exponent κR + extra; identical output when extra is None.
- New `src/trip.py` (stdlib only, mirrors the coming `Trip.luau` step by step):
  - phase-A geometry per course and distance (segments with turn angles, lock distance; from the TrackLayout numbers);
  - `new_state(posts, q, uniforms)`;
  - `step(state, live, intents, t, dt)`: skill targets with the gap ramp, smoothing, hold, tuck-back, lateral glide with clearance, Smart Steer for lanes without a recent intent, accrual;
  - `lock(state)`, `trip_values`, `tau(trip, posts, baseline, cfg)`.
  - Fixed iteration order (lane index) and explicit tie rules.
- New `sims/steering.py`:
  - policies: Smart Steer, bot mix, rail rider, never-steer, wanderer, scripted human;
  - writes `game/src/shared/TripBaseline.luau` and `tests/fixtures/trip_baseline.json` from a fixed seed (≥ 2,000 bot-mix races per course × distance × post);
  - prints the calibration report.
- `tests/fixtures/make_fixtures.py`: append 100 `race_math` cases with `extra` vectors (existing cases unchanged); write `tests/fixtures/trip.json` (200 scripted phase-A runs with per-tick intents and uniforms; expected lanes at fixed ticks, trip, τ).
- New `tests/test_trip.py`:
  - τ always within [floor, ceiling];
  - `scale = 0` or all-equal trips → p identical to today (the 300 existing fixtures unchanged);
  - more ground saved never lowers your own p;
  - draft ≤ cap and stops at the lock;
  - the trip takes no luck input, so swapping luck leaves p unchanged;
  - nothing changes after the lock;
  - residual post bias < 0.005;
  - the Smart Steer field mean is 0 ± 0.003.
- **Acceptance targets** (sims, all courses and distances; if they miss, tune `groundPerLaneTurn`, `draftPerSecond` or `smart.homeLane` and log the change):

  | Target | Value |
  | --- | --- |
  | Rail-rider policy vs Smart Steer | +0.01 to +0.03 |
  | Never-steer (Smart Steer off) | between −0.02 and −0.01 |
  | Inward request reaching its lane within 3 s | ≥ 70% |
  | Draft share of positive trip | ≤ 40% |
  | Residual post bias | < 0.005 |

  S0 applied every target per course × distance, measured post bias per post for a Smart Steer kid among bots and in all-Smart lobbies, and added "a Smart Steer kid among bots averages 0 ± 0.003" (results: docs/research/steering-calibration.md).

- Docs: V2_PROPOSAL step 5, "exponent κR + c + τ, τ from steering (D-054), fixed at the far turn".

**S1. Rail coordinates and random posts** (roblox-engineer; looks the same, plays the same)
- `game/src/shared/TrackLayout.luau`:
  - `railLength(cfg, plan)`;
  - `railPoint(cfg, plan, s, x)`: s = feet from the gate along the lane-1 path; x = lane position 1–8, fractional allowed;
  - `phaseA(cfg, plan)`: segments and the lock distance, shared with Trip.
  - Horses at the same s are abreast on turns too.
- Client:
  - `RaceView.client.luau` places horses by (s, x), with x = post for now;
  - `RaceState.luau`: progress = s / railLength, plus `RaceState.lane`;
  - `Minimap.client.luau` and `Replay.client.luau` use railLength;
  - `TrackScene.luau` `laneCFrame` uses railPoint.
- `RaceService.server.luau`: shuffle the lane list with the race's random generator after `fillWithBots` (posts are drawn, no longer humans first).
  - As built (PR #41): the draw comes after the session and the slider's passes, so the earlier draws keep their order. `RaceSession:assignPosts` renumbers the lanes, and `GameConfig.steering.drawPosts` switches it.
- Tests: `railPoint` at integer x matches `lanePoint`'s radius on turns and is continuous across segment joins; abreast at equal s; post shuffle is a permutation; existing race tests unchanged.

**S2. Trip on the server, Smart Steer for everyone** (no rider input yet)
- New `game/src/shared/Trip.luau` (pure; exact parity with `src/trip.py`) and generated `game/src/shared/TripBaseline.luau`.
- `src/RaceMath.luau`: `liveChances(q, R, cfg, extra?)`.
- `game/src/shared/RaceSession.luau`:
  - `self.tau` (zeros) and `setTrip(tau)`;
  - `tilts` adds τ/κ (as the crowd's c/κ);
  - `tripGain(i)`, like `ridingGain` with τ_i = 0.
- `game/src/server/RaceService.server.luau`:
  - Trip state at the gate; a 10 Hz loop until the lock calls `Trip.step(state, session.live, intents, t)`;
  - before the lock, the phase-A offsets come from Trip (skill target + hold); `RaceOffsets` sends `(offsets, lanes, courseId)` with the course id still last;
  - new `TripInfo` remote at the start (lock time, enabled);
  - at the lock: `Trip.lock` → τ → `session:setTrip(τ)` → recompute `shownLive`; send a lock event;
  - after the lock, the existing RaceShape offsets, with cosmetic make-room lanes from `Trip.cosmetic` (no τ);
  - `RideReport` gains trip stars and `tripGain`.
- Clients: `RaceView.client.luau` (the only `RaceOffsets` listener today) reads and lerps lanes.
- Tests:
  - Luau parity of `Trip` with `trip.json` (1e-9) and of `RaceMath.liveChances` with `extra`;
  - `RaceSession`: zero τ gives identical live chances and finish to before; τ applies only after `setTrip`;
  - `steering.enabled = false` gives today's offsets path;
  - syntax check, policy guard.

**S3. Rider controls**
- `game/src/client/RaceController.client.luau`:
  - ◀ ▶ buttons (≥ 88 px, bottom-left, above the default thumbstick zone, ZIndex over `tapArea`), hidden for a player's first `introRaces` races;
  - carve A, D, Left, Right, DPadLeft, DPadRight and Thumbstick1 out of the any-key/any-button tap handler; a left-stick flick through `InputChanged` (fires at |x| > 0.6, re-arms below 0.3);
  - `SteerRequest:FireServer(dir, seq)`; disable PlayerModule controls while racing;
  - lock UI (three soft bell ticks, "Lanes locked!", greyed buttons); chips; the wide-into-a-turn tip.
- `RaceView.client.luau`: predict your own glide and ease to the server lane.
- `RaceService.server.luau`: the `SteerRequest` remote. `Trip.acceptIntent` checks the rider is in this race, before the lock, dir ∈ {−1, 1}, the request gap and the queue; Smart Steer pauses and resumes and never moves a rider outward.
- Settings and copy:
  - `Profile.luau` and `SettingsService.server.luau`: `settings.smartSteer` (default true);
  - `GrownUps.client.luau`: the toggle, plus a For grown-ups line ("Riders can steer a little: the best trip is worth about 2 points of a 100-point ride, and nothing buys it").
- Tests: `Trip.acceptIntent` (rate limit, after lock, bounds, queue); a pure `RaceInput.isSteerInput(keyCode)` helper and its table; resume never moves outward.

**S4. Replays, results, docs**
- `game/src/client/Replay.client.luau`:
  - record `x` per lane per frame and the trip events (lock, saved-ground turn exits, tucked-in spans, your lane changes);
  - place by (s, x);
  - overlays: your line as a ribbon with green chevrons, wind lines, the lock marker.
- `RaceController.client.luau` results: "Good trip ★★☆" under "You rode ★★☆"; "Your trip gained you N places!" only when positive.
- Docs:
  - `docs/GAME_DESIGN.md` race section;
  - `game/PLAYTEST.md` steering checklist (section D below);
  - the For grown-ups copy.
- Tests: replay frames carry lanes; the RideReport fields; the results text never shows a negative trip line.

### Ordering

Both features wait for David's Studio playtest of the world (STATUS backlog 1) and land after the audio PR (D-052). The two features are independent.
1. **T1 and S0 in parallel:** the world build and the Python calibration need different engineers.
2. **T2:** answers David's first ask with two courses.
3. **S1:** a safe refactor with no gameplay change.
4. **S2:** steering looks real (Smart Steer for all) before anyone can press a button, so trip numbers can be checked in Studio logs.
5. **T3.**
6. **S3:** buttons go live.
7. **S4.**
8. **T4**, then **T5** later.

T2 and S2 are the largest (roughly 600–900 lines with tests). The rest are smaller.

---

## D. Risks and what to playtest

### Training rides

| Risk | Mitigation | Watch for |
| --- | --- | --- |
| Kids can't steer a horse at a gallop on a phone | Hoops three horses wide, the next one glowing, a 4-stud magnet, Easy Rein, no fail states, canter-only poles | Finish rates by age (below) |
| Replication jitter marks honest phone riders as cheating | The floor is log-only for two weeks; thresholds in config | Honest phones discarding > 2% of samples (Competitive's line) means retuning before enforcing |
| Ride rig physics on berms and logs (Humanoid hops, slope, canter override) | Low logs (2 studs) under the ~4.5-stud hop; gentle 6-stud berm | Horses snagging on logs or rails; jumps not detected as airborne |
| Free riders and other course riders get in the way | `TrainingRiders` collision group; hoops glow only for their rider | Bumps or blocking at course starts |
| Quick Train wins over courses | Courses own stars, ribbons and ghosts | Quick Train above 60% of sessions after week 2 means fixing the courses (Engagement's line) |
| A race starts mid-ride | The session aborts with no gain or penalty: "Your race is starting! Training paused." | Kids losing a ride they nearly finished |
| Ghost data bloats saves | Separate DataStore key; ≤ 300 points per course | Save size and throttle warnings |
| Training pace drifts | Formula and cap unchanged | Economy sim v2 (backlog) |

**Playtests**
1. **Finish rate:** at least 80% of 8–10-year-olds finish each course on the first or second try without help (Young player: below two-thirds keeps meters primary; Child safety: two failed tries with Easy Rein).
2. **Where kids look:** can they find the next hoop without reading? Do they understand "stay in Pip's ring"?
3. **Choice:** given the picker, do kids choose courses over Quick Train? Do they replay a course after the cap "for stars"?
4. **Length:** do 50 s rides feel short or long? (The Young player and Child safety thresholds differ: 60–70 s vs 90 s.)
5. **Friends:** does riding together with stars-only results feel fun, not like ranking? Watch a sibling pair (Child safety's test).
6. **Studio logs:** discard rates on phones, sessions per hour, gains per week.

### Race steering

| Risk | Mitigation | Watch for |
| --- | --- | --- |
| Too much to do next to the slider | Arrows hidden for 3 races; Smart Steer default; lanes lock before the Final Burst | Slider S with arrows vs without (the first 3 races give a natural A/B). A drop > 3 points means Smart Steer only (all panel lines are 1–3 points; Child safety's is 1) |
| Steering inputs counted as taps, or taps eaten | Buttons above `tapArea`; key and button carve-outs; touch thumbstick off during races | ◀ ▶ presses producing "Too fast!"; left-half taps missing (check the dynamic thumbstick now, it may already eat taps) |
| Kids can't tell steering mattered | "Saved ground!", "Tucked in!", "Good trip ★★☆", "gained you N places" | After 5 races, can a kid say what ◀ ▶ did? If not, raise the ceiling to 0.06 (Competitive) or go ground-only (Young player) |
| Jams and "no room" frustration | Tuck-in; 0.6 s glide | Refused-request rate in logs; kids pressing repeatedly with nothing happening |
| Post baseline goes stale when constants change | Generated table plus a test that regenerating matches the checked-in file | Residual post bias > 0.005 in sims, or kids blaming "lane 8" (Young player: then zero post effect) |
| Held horses look boxed, then surge after the lock | Held = tucked in (credit), shown with wind lines | Kids saying "I got boxed so I lost" (they weren't penalized) |
| Bandwidth and jitter (2 courses × 8 horses × offset + lane at 10 Hz, unreliable) | Small payload; client lerp; drops harmless | Lateral snapping on phones; network graph in Studio |
| Python/Luau drift in clearance comparisons | Fixed iteration order, explicit ties, tolerances in the parity test | Parity failures on edge ticks |
| Bots out-steer new kids | Bot variety; baseline from bot-mix fields | Smart Steer kids averaging below 0 in logs |
| The lock bell feels abrupt or stressful | Soft bell, greyed arrows, no countdown numbers on screen | Kids startled; Reduced Motion: no shake |
| The 0.6 s glide looks like a swerve (~10°) | `laneSeconds` in config | Looks unrealistic in chase camera → 0.8–0.9 s (Competitive's value) |

**Playtests**
1. **Load:** compare slider scores in the first 3 races (arrows hidden) and races 4–8 (arrows shown), on phones, ages 8–11.
2. **Understanding:** after 5 races, ask "What do the arrows do?" and "What does Tucked in mean?"
3. **Smart Steer:** do kids who never touch the arrows end with τ ≈ 0? Does anyone get stranded wide?
4. **Realism:** in chase and replay, do the field's moves to the rail, tuck-ins and the lock read like real racing? Any overlap or pop?
5. **Fairness feel:** do losers blame their post or "getting blocked"? (Child safety and Young player lines.)
6. **Controls:** phone two thumbs, keyboard (A/D while tapping Space), gamepad (D-pad plus face buttons); confirm no steering press ever scores as a tap.
7. **Logs:** distribution of τ by policy and post, refused requests, lock timing per distance, and how often τ binds the clamp.

**Studio checklist additions** (`game/PLAYTEST.md`):
- Horses take the rail before the first turn and tuck in without overlapping.
- The bell and "Lanes locked!" come at far-turn entry on every distance.
- The trip line appears on the results.
- The replay shows lanes.
- The training courses start from the picker, score on the server, and stay open after the weekly cap.
