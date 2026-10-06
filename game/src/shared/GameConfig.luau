--!strict
-- All tuning values in one place (D-005, D-010, D-011, D-022). Theme-agnostic.
-- Changing a value here is a tuning change; log design changes in docs/memory/DECISIONS.md.

export type League = {
	name: string,
	T: number,             -- stat temperature
	B: number,             -- base purse
	sweepSeconds: number,  -- Final Burst meter full sweep, there and back
	windowSeconds: number, -- time to tap in the Final Burst
	targetDrift: number,   -- 0 = fixed center; >0 = center drifts this far (fraction of half-width)
	twoTargetFinal: boolean, -- Final Burst shows two half-size targets
	strideIntervalLo: number, -- Giddy-up beat interval range (tempo picked per stretch)
	strideIntervalHi: number,
	strideDrift: number,   -- each stride's interval changes by up to this fraction
	leadChange: boolean,   -- one half-beat lead change mid-stretch
	distances: { string }?, -- race distances this league runs (default: all)
}

local GameConfig = {}

GameConfig.lanes = 8
-- Race segments (D-026, D-031): the pace slider from the gate to the final turn (two
-- checkpoints), the Final Burst entering the homestretch (counts double), then the slider
-- again for the stretch drive.
GameConfig.segments = { "pace", "pace", "burst", "pace" }
GameConfig.segmentWeights = { 1, 1, 2, 1 }
-- The slider (D-026). Target moves every 2-3 passes and speed drifts +-15% so a
-- fixed-interval clicker scores below an average kid (simulated 59 vs 75; good human 93).
GameConfig.pace = {
	speedDrift = 0.15,
	shiftMin = 2,
	shiftMax = 3,
	centerRange = 0.6,
	speedFillPasses = 5,       -- the speed meter shows the mean of the last few passes
	bounceSeconds = 0.15,      -- a tap this soon after the last counted tap is a finger bounce: ignored (D-055; 0 = D-026)
}
-- Race length (D-027): distance on the Churchill-style track at a gallop. Real times:
-- Sprint ~69 s, Mile ~94 s, Classic (the Derby) ~1:57, Marathon ~2:21.
GameConfig.raceSpeedStudsPerSecond = 56
GameConfig.burstLeadSeconds = 1.5    -- pace pauses and "FINAL BURST" shows this long before the burst
GameConfig.burstAfterTurnSeconds = 0.5 -- the burst opens this long after the field enters the homestretch
GameConfig.stretchGapSeconds = 1.0   -- after the burst, the slider resumes for the stretch drive
GameConfig.finishMarginSeconds = 1.5 -- the stretch drive's slider stops this long before the line
-- Race shape (D-033): skill shows until the far turn, luck blends in to the last tap.
GameConfig.raceShape = {
	leadFeetPerShare = 320, -- skill: feet ahead per unit of (win chance - fair share)
	leaderFeet = 20,        -- luck: projected leader's lead over the pace
	feetPerLog = 24,        -- luck: margin per unit of log(T ratio), clamped below
	minGap = 2,
	maxGap = 40, blendPower = 2,
}
GameConfig.offsetsPerSecond = 4      -- how often the server sends on-screen gaps
GameConfig.stretchPreviewSeconds = 1 -- how often live chances refresh during the stretch drive
GameConfig.tapNudgeFeet = 2          -- instant, luck-free nudge on your own screen for a Great or Perfect tap
GameConfig.dismountTimeoutSeconds = 60 -- riders stay on their horse for results and replay until Done
GameConfig.windowGapSeconds = 4.0    -- (unused by the race since D-026; kept for tools)
GameConfig.runInSeconds = 3.5        -- after the result: horses cross the line in finish order (D-025)
-- Race steering (D-054). Mirrors CONFIG in src/trip.py (the Python reference; tests/luau checks
-- the two match). Values after the S0 calibration: docs/research/steering-calibration.md. The
-- per-post baselines are generated into TripBaseline.luau by sims/steering.py.
GameConfig.steering = {
	drawPosts = true,              -- posts drawn at random at the gate; false = the old humans-first lanes
	enabled = true,                -- false: today's fixed lanes and offsets, exactly
	scale = 1,                     -- 0: steering is cosmetic (lanes move, chances don't). S2 shipped 0;
	                               -- 1 from S3, when the rider controls went live (src/trip.py's value)
	floor = -0.02, ceiling = 0.04, -- clamp on tau (1 point of S = 0.02)
	groundPerLaneTurn = 0.010,     -- per lane off the rail per 180 degrees of turn
	draftPerSecond = 0.0010, draftCap = 0.016,
	draftNear = 4, draftFar = 24,  -- feet behind the horse ahead in your lane (0.5-3 lengths)
	laneSeconds = 0.6, minRequestGap = 0.6,
	maxQueued = 1,                 -- 0 or 1: one press can wait behind the one in progress
	clearFeet = 8,                 -- a lane change needs this much room ahead in the new lane...
	holdGap = 10,                  -- ...and this much behind; a held horse sits this far back
	holdPullPerSecond = 19,        -- a hold settles a horse back no faster than this (no hop on screen)
	tuckBackMax = 24,              -- ease back up to 3 lengths to slot in behind horses
	outwardWaitSeconds = 1.0,      -- a blocked move outward cancels after this long
	tickHz = 10, sendHz = 10,
	gapRampSeconds = 8,            -- skill gaps grow in over this long (replaces RaceView's 30% ramp)
	lockBellSeconds = 3,
	smart = { homeLane = 2, turnLeadSeconds = 8, resumeSeconds = 5 },
	bots = { turnLeadMin = 4, turnLeadMax = 12, railShare = 0.25, wideShare = 0.20 },
	introRaces = 3,
	stars = { 0.015, -0.005 },     -- trip three-star and two-star thresholds
	laneBand = 0.9,                -- horses closer than this (in lanes) share a lane
	tuckReleasePerSecond = 4,      -- a tuck-back fades this fast once nothing blocks
	requestsPerSecond = 8,         -- S3, game only: a rider's steering requests past this a second are dropped
	-- D-057 natural steering: N3 switched the motion and press rules on (src/trip.py's CONFIG is
	-- the same). Back to D-054: glide = "linear", chainWindow = 0, reverseGapSeconds = 0,
	-- weaveGapSeconds = 0, pressBounceSeconds = 0, glideReserveFeet = 0, blockedPress = "d054"
	-- (Trip.d054Config; REVIEW_QUEUE has the whole switch-back). Brushes stay off until N5.
	glide = "eased",               -- "eased": S-curve lane changes (1.0 s a lane); "linear": D-054's 0.6 s
	laneSpeedMax = 1.5,            -- eased: top sideways speed, lanes/s (9 ft/s)
	laneAccel = 4.5,               -- eased: sideways acceleration and braking, lanes/s^2 (27 ft/s^2)
	chainWindow = 0.3,             -- a same-way change may start this close (lanes) to landing (D-054 0)
	reverseGapSeconds = 0.5,       -- a change the other way starts this long after landing (D-054 0)
	weaveGapSeconds = 2.5,         -- ...or this long, for a second reversal within the window (D-054 0)
	weaveWindowSeconds = 7,        -- (debate 012: 5; 7 since the N1 review)
	pressBounceSeconds = 0.2,      -- a press the same way this soon after the last counts once (D-054 0)
	glideReserveFeet = 6,          -- a horse gliding into a lane keeps this much more room (D-054 0)
	blockedPress = "wait",         -- "wait" (D-057) or "d054": a press into a lane with no room
	gapWaitSeconds = 1.5,          -- wait: an outward press waits this long for room, then drops
	gapWaitInSeconds = 0,          -- wait: an inward press that can't tuck back drops after this (0 = waits)
	tuckAfterSeconds = 0,          -- wait: an inward press tucks back after this long without room
	boxedAheadFeet = 12,           -- boxed in: no room either side and a horse this close ahead (reported)
	brush = "off",                 -- "repeat" (D-057, N5): a second press into a horse alongside brushes it
	brushAlongFeet = 8,            -- alongside = within this many feet lengthwise in the next lane...
	brushGraceSeconds = 0.3,       -- ...for at least this long
	brushRepeatSeconds = 2,        -- the second press comes within this long of the waiting one (0 = any time)
	brushPays = "mover",           -- "mover" (D-057); "bumped", "both", "none" for the sims
	brushCost = 0.002,             -- tau per charged brush (own term, after the field mean)
	brushFree = 1,                 -- the first brushes cost nothing
	brushMaxCharged = 3,           -- at most this many charged; at most brushFree + this many a race
	brushCheckFeet = 4,            -- the payer steadies this far back (Trip's offsets)...
	brushRecoverPerSecond = 2,     -- ...and comes back at this rate
	steadySeconds = 1,             -- the mover can't steer for this long after a brush
}
-- The steering controls on screen (D-054 S3; RaceController). Chips and tips only show to riders
-- who have the buttons (from their introRaces + 1-th race).
GameConfig.steerHud = {
	buttonPx = 104,          -- ◀ In / Out ▶ size on big screens...
	minButtonPx = 88,        -- ...never smaller (phones)
	tipSeconds = 5,          -- the ghost-thumb tip on the first race with the buttons
	chipSeconds = 1.8,       -- "Saved ground!", "Tucked in!", the turn tip and "Lanes locked!"
	railLane = 1.5,          -- "Saved ground!": through a turn on the rail (mean lane under this)...
	belowField = 0.25,       -- ...or at least this many lanes inside the field's mean
	tuckedSeconds = 1,       -- "Tucked in!" after this long tucked in (wind lines from 0.3 s)
	tuckedAgainSeconds = 10, -- and not again within this long...
	tuckedPerRace = 3,       -- ...nor more than this often a race (none once the draft credit is full)
	wideLanes = 1,           -- the turn tip: this many lanes or more outside Smart Steer's home lane...
	tipsPerRace = 2,         -- ...at most this often a race
	hideAfterLockSeconds = 2.5, -- the greyed buttons fade this long after "Lanes locked!"
	-- Boxed in (D-057 N4; SteerHud, SteerChips): from the server's word on your own lane.
	greyArrows = true,       -- Out ▶ greys while a horse leaves no room; ◀ In only when tuck-back can't help
	waitRing = true,         -- a ring on the arrow of a press waiting for room (lit inward, filling outward)
	noRoomChipAfter = 1,     -- "No room yet" once a press has waited this long with no move or tuck-back...
	noRoomChipEvery = 10,    -- ...at most this often
	gapChipAfterWait = 0.5,  -- "Gap!" when a press that waited at least this long starts its move
	chipMinGap = 2,          -- "No room yet" never comes this soon after another steering chip
	wobbleDeg = 4,           -- a dropped press's arrow wobbles this far...
	wobbleSeconds = 0.2,     -- ...for this long (none under Reduced Motion)
}
-- How a race horse's body moves through a lane change (D-057 N3; SteerPose). Every horse in a
-- steering race, on every screen; the look cue only on your own horse, on your screen.
GameConfig.steerView = {
	yawGain = 1,             -- the body turns with its true drift (atan of sideways / forward speed) x this
	yawMaxDeg = 10,          -- ...at most this far (a 9 ft/s glide at 56 ft/s is 9 degrees)
	yawSmoothSeconds = 0.15, -- sideways speed and acceleration are smoothed over this long
	leanDegPerFtps2 = 0.12,  -- the body leans into the move: degrees per ft/s^2 of sideways acceleration...
	leanMaxDeg = 3,          -- ...at most this far
	lookDeg = 3,             -- your own press: turn this far toward it at once...
	lookRelaxSeconds = 0.3,  -- ...and relax over this long if the press waits
}
-- How the horses move on screen (D-055). Every lane's progress is timed on lane 1 (the race
-- clock), so the order on screen is the race order in every lane.
GameConfig.raceView = {
	easePerSecond = 2.5,      -- gaps ease toward their target at this rate (Trip mirrors it, D-054)...
	maxGapFeetPerSecond = 10, -- ...a horse gains or loses ground on the pace at most this fast...
	catchUpMarginSeconds = 0.3, -- ...unless it must go faster to reach its place by the line
	gateEaseSeconds = 0.6,    -- horses reach full gallop out of the gate over about this long
	nudgeRiseSeconds = 0.15,  -- a good tap's nudge on your own horse eases in...
	nudgeFallSeconds = 0.6,   -- ...and back out
	settleSeconds = 0.6,      -- after the line, legs ease to standing before the race ends
	-- Steering races (D-057 N3; Playback): the screen draws the server's samples a little behind
	-- the newest, by their server timestamps, so a jittery link never stalls or lurches a horse.
	playback = {
		marginSeconds = 0.05,      -- delay beyond the longest recent lag and one send interval
		slew = 0.04,               -- the playback clock runs at most 4% fast or slow to change its delay
		rateChangePerSecond = 0.2, -- ...and changes its rate at most this fast
		lagReleasePerSecond = 0.02, -- a lag spike's extra delay drains this fast
		gain = 2,                  -- clock rate change per second of delay error
	},
}
GameConfig.gateCountdownSeconds = 3 -- "3, 2, 1" over the gate, then "GO!" with the bell (D-055)
-- Race screen (D-055).
GameConfig.hud = {
	missedPassLabel = "",        -- a pass with no tap shows no word ("Miss" = before D-055)
	earlyLateBelow = 30,         -- a tap scoring under this says "Early" or "Late"
	riderBoardInRace = false,    -- riders see the running-order board in the race (true = D-030)
	boardShowsChance = false,    -- win % and purse on the board, and the rider's live win chance line
	spectatorBoardRowsPhone = 4, -- spectators on phones: the top 3 plus their cheered rider
}
-- Watching a race you're not in (D-055): the race HUD, cheer strip and results card appear only
-- within rangeStuds of the course's outer edge (the same range as race sound, D-052), stay until
-- keepStuds, and never over a training ride, a care or training game, or a full-screen panel.
GameConfig.spectate = { rangeStuds = 250, keepStuds = 300 }
-- Cheering on screen (D-056): CLAP one column left of the movement buttons (Gallop, Hop); the
-- cheer strip sits at the top centre under the status line, never mid-screen.
-- Touch screens (D-056): the 💎 button leaves the dock for a quiet pill at the top right
-- ("dock" = the D-050 layout), and the dock leaves the bottom-right column to the movement
-- buttons (Hop, Gallop).
GameConfig.touchLayout = {
	gemPlacement = "topRight",
	movementColumn = 176, -- px kept free at the right edge for Hop (up to 170 px in) and Gallop
}
-- Your horse's stall while it's out (D-056): empty, with a plaque on the door.
GameConfig.stable = { awaySign = true }
-- Riding your own horse (D-056).
GameConfig.riding = {
	hopButton = true,   -- touch: a Hop button at Roblox's own jump spot while you ride
	bobAmp = 0.15,      -- body bob, in step with the legs (hooves stay on the ground)
	legLength = 2.45,   -- hip to hoof, for the hoof-lift correction
}
GameConfig.fans = {
	clapOffset = { -170, -230 },  -- from the bottom-right corner (UDim2 1, x, 1, y), anchored bottom-right
	clapSizeOnFoot = { 170, 90 },
	clapSizeRiding = { 120, 70 },
	cheerStripTop = true,
}
-- The only keys and buttons that tap the slider and the Final Burst (D-055), besides a click or
-- touch. Steering, camera, clap, prompt and menu keys are not taps.
GameConfig.tapKeys = { "Space", "Return", "KeypadEnter", "ButtonA", "ButtonR2" }
GameConfig.stride = {
	beats = 8,                 -- per stretch, ~2 taps a second
	halfWindowSeconds = 0.08,  -- a tap scores if within this of its beat
	leadInSeconds = 1.2,       -- stretch opens this long before the first beat
	ringLeadSeconds = 0.9,     -- every ring takes this long to close (tempo shows as spacing)
	maxTapsPerBeat = 2,        -- taps beyond beats * this + 4 are ignored (they'd count against anyway)
}
-- Per-tap labels for Giddy-up feedback, by closeness 1 - |error| / halfWindow.
GameConfig.strideLabels = {
	{ min = 0.75, label = "Perfect" },  -- within 20 ms
	{ min = 0.45, label = "Great" },    -- within 44 ms
	{ min = 0.15, label = "Good" },     -- within 68 ms
	{ min = 0, label = "Okay" },
}
GameConfig.lobbyFillSeconds = 20     -- bots fill remaining lanes after this
GameConfig.kappa = 1.0
GameConfig.qFloor = 0.025
GameConfig.rFloor = -0.5
GameConfig.placePrizes = { 1.2, 0.8, 0.4 }       -- 2nd, 3rd, 4th, in units of B
GameConfig.leaguePoints = { 10, 6, 4, 2 }        -- 1st..4th; everyone else gets finishPoints
GameConfig.finishPoints = 1
-- League Points needed to unlock each league's Stakes race (D-013, from sims/economy.py)
GameConfig.stakesUnlockPoints = { Rookie = 100, Bronze = 110, Silver = 1400, Gold = 3000 }
-- League ceilings (D-046): a horse whose best base Rating passes this has its Cup opened and
-- its league's regular races closed. The Cup winner gets cupPurseB × B (D-048).
GameConfig.leagueCeiling = { Rookie = 58, Bronze = 68, Silver = 78, Gold = 88 }
GameConfig.cupPurseB = 3
GameConfig.maxTapRewindSeconds = 0.3             -- cap on the per-player latency allowance (D-021)
GameConfig.tapJitterMarginSeconds = 0.05         -- added to measured one-way latency (D-021)
GameConfig.missedTapScore = 0
-- Bot scores per segment (D-011, recalibrated for D-022; tune from playtests).
GameConfig.botPaceMean = 60          -- D-026 slider; simulated average kid ~66-75, good player ~90
GameConfig.botPaceSd = 15
GameConfig.botStrideMean = 40        -- Giddy-up stretches (D-022), kept for Clap Along tuning
GameConfig.botStrideSd = 15
GameConfig.botBurstMean = 55
GameConfig.botBurstSd = 15
GameConfig.botRatingSpread = 6                   -- bots rated within ± this of the human median

-- Macro detection (D-022). Log only until a month of real data sets the threshold.
GameConfig.integrity = {
	logOnly = true,
	maxSpreadSeconds = 0.012,  -- gap-error spread below this is not humanly realistic
	minBeats = 300,
	minRaces = 5,
	minDays = 2,
	warnAt = 2,                -- private note + taps count as the race average
	averageDays = 7,
	reviewAt = 3,              -- a person reviews, then cash races pause
	pauseDays = { 7, 30 },
	strikeExpiryDays = 90,
}

-- Energy (D-015). Gates entry only; never affects Rating or win chance.
GameConfig.energy = {
	maxPerRacer = 5,
	costPerCashRace = 1,
	regenSeconds = 20 * 60,        -- +1 every 20 minutes, offline too
	careTopUps = { feed = 1, groom = 1 },
	careCooldownSeconds = 2 * 60 * 60,
	freeLeagues = { Rookie = true }, -- Rookie races cost no Energy
}

-- Training rides (D-053): ride-through courses on your own horse at the Training Ground and
-- the paddock arena, scored by the server from 10 Hz samples of the ride rig. Geometry is in
-- TrainingCourses.luau; scoring in TrainingRide.luau.
GameConfig.training = {
	mode = "rides",                 -- "rides" | "meters" (paddock games only, as before D-053)
	-- Courses that can be ridden now; the others show "Coming soon" on the picker (T3).
	courses = { speed = true, grit = true, accel = true, stamina = true },
	quickTrain = true,              -- show the 10-second games as "Quick train"
	quickQualityCap = 0.85,         -- Quick train gains at most this quality (score 70)
	sampleHz = 10,
	maxSpeed = 53,                  -- studs/s horizontal: gallop 46 + 15%
	maxStep = 12,                   -- studs between samples (teleport)
	maxBadShare = 0.10,             -- more discarded than this: score at the floor
	enforceFloor = false,           -- log-only for the first two weeks
	sessionGapSeconds = 4,
	maxSessionsPerHour = 40,
	maxSessionSeconds = 120,        -- a ride still going after this ends and counts what it has
	leaveSeconds = 2,               -- outside the course area this long ends the session (no gain)
	countdownSeconds = 3,
	stars = { 60, 90 },             -- 2 and 3 stars
	ribbons = { silver = 75, gold = 90 },
	parFactor = 1.15,               -- par = ideal time × this; gold needs under par
	magnetStuds = 4,
	gallop = 46, canter = 20,
	oval = { cx = 800, cz = 0, straight = 160, radius = 55, width = 24 },
	speed = { laps = 3, hoopsPerLap = 6, hoopWidth = 10 },
	-- Gate Break: standing still in the stall for settleSeconds readies a break; moving goStuds
	-- (or leaving the stall) is a go, early if it's before the bell.
	accel = { breaks = 3, bellMin = 1.5, bellMax = 3.5, dash = 120, fullReact = 0.5, zeroReact = 2.0, breakFloor = 40, goSpeed = 20,
		settleSeconds = 0.5, goStuds = 2 },
	stamina = { laps = 2, ringNear = 8, ringFar = 24, ringHalfWidth = 6, ponyMin = 30, ponyMax = 42, grace = 3, hill = 6 },
	-- Mud Splash is ridden at an arena lope (`pace`), and the bending poles at a canter. A log
	-- counts when the horse is `airborne` studs above its riding height within `logWindow`
	-- studs of it (logs don't collide, so a horse that doesn't hop just runs through).
	-- layoutPin (T5): 0 = "This week's course" (four layouts, one a week in turn); 1-4 = always
	-- that layout (a playtest, or 1 to switch the weekly course off).
	grit = { mud = 4, logs = 3, poles = 4, logHeight = 2, pace = 28, airborne = 1.5, logWindow = 3,
		points = { mud = 7.5, log = 12, pole = 8.5 }, layoutPin = 0 },
	ghostHz = 4, ghostMaxPoints = 480, ghostQuantum = 0.5, -- 480 points at 4 Hz = 120 s, a whole ride
}

-- Prize ribbons for the UI (D-016). Never use racing-wager terms in UI text. -- policy-ok
GameConfig.ribbons = { "Blue", "Red", "Yellow", "White" }

GameConfig.scoreLabels = {
	{ min = 95, label = "Perfect" },
	{ min = 80, label = "Great" },
	{ min = 60, label = "Good" },
	{ min = 30, label = "Okay" },
	{ min = 0, label = "Miss" },
}

GameConfig.leagues = {
	Rookie = { name = "Rookie", T = 22, B = 20, sweepSeconds = 2.4, windowSeconds = 4.0, targetDrift = 0, twoTargetFinal = false,
		distances = { "Sprint", "Mile" }, -- shorter races for new players (D-027)
		strideIntervalLo = 0.60, strideIntervalHi = 0.60, strideDrift = 0, leadChange = false },
	Bronze = { name = "Bronze", T = 18, B = 50, sweepSeconds = 2.0, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		distances = { "Sprint", "Mile", "Classic" }, -- Bronze adds the Classic; Silver and up run every distance (D-046)
		strideIntervalLo = 0.55, strideIntervalHi = 0.60, strideDrift = 0.02, leadChange = false },
	Silver = { name = "Silver", T = 18, B = 120, sweepSeconds = 1.6, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		strideIntervalLo = 0.50, strideIntervalHi = 0.56, strideDrift = 0.03, leadChange = false },
	Gold = { name = "Gold", T = 14.4, B = 300, sweepSeconds = 1.3, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = false,
		strideIntervalLo = 0.46, strideIntervalHi = 0.52, strideDrift = 0.03, leadChange = false },
	Champion = { name = "Champion", T = 12, B = 750, sweepSeconds = 1.1, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = true,
		strideIntervalLo = 0.42, strideIntervalHi = 0.48, strideDrift = 0.03, leadChange = true },
} :: { [string]: League }

GameConfig.leagueOrder = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }

-- Labels for a whole Giddy-up stretch (0..100). An average kid scores ~30, so the
-- scale is gentler than the burst's.
GameConfig.stretchLabels = {
	{ min = 70, label = "Perfect stretch" },
	{ min = 45, label = "Great" },
	{ min = 20, label = "Good" },
	{ min = 0, label = "Keep the beat" },
}

function GameConfig.labelFor(score: number, labels: { { min: number, label: string } }?): string
	for _, row in labels or GameConfig.scoreLabels do
		if score >= row.min then return row.label end
	end
	return "Miss"
end

return GameConfig
