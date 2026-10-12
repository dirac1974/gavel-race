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
-- (D-066, AAA Phase 1) The Final Burst arms this long after it opens: a tap before then is ignored
-- (not counted, not used up), so a reflex tap from the slider's rhythm can't spend the burst. The
-- marker still starts at a random point (D-022) and every league's armed window still covers a
-- full sweep. Server (RaceSession:submitBurst), client and src/burst_meter.py agree. 0 = before D-066.
GameConfig.burstArmSeconds = 0.5
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
GameConfig.tapNudgeFeet = 5          -- instant, luck-free nudge on your own screen for a Great or Perfect tap
                                     -- (drawn only; D-066 raised it from 2, capped by raceFx below)
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
	introRaces = 0,                -- D-072 (provisional): the ◀ ▶ buttons from race 1, with the learner floor
	                               -- below (UI/UX staging: steerHud.tipRace, pipsRace); 3 is the switch-back
	stars = { 0.015, -0.005 },     -- trip three-star and two-star thresholds
	laneBand = 0.9,                -- horses closer than this (in lanes) share a lane
	tuckReleasePerSecond = 4,      -- a tuck-back fades this fast once nothing blocks
	requestsPerSecond = 8,         -- S3, game only: a rider's steering requests past this a second are dropped
	-- D-057 natural steering: N3 switched the motion and press rules on, N5 the brushes (src/trip.py's
	-- CONFIG is the same). Back to D-054: glide = "linear", chainWindow = 0, reverseGapSeconds = 0,
	-- weaveGapSeconds = 0, pressBounceSeconds = 0, glideReserveFeet = 0, blockedPress = "d054",
	-- brush = "off" (Trip.d054Config; REVIEW_QUEUE has the whole switch-back).
	glide = "eased",               -- "eased": S-curve lane changes (1.0 s a lane); "linear": D-054's 0.6 s
	laneSpeedMax = 1.5,            -- eased: top sideways speed, lanes/s (9 ft/s)
	laneAccel = 4.5,               -- eased: sideways acceleration and braking, lanes/s^2 (27 ft/s^2)
	chainWindow = 0.3,             -- a same-way change may start this close (lanes) to landing (D-054 0)
	reverseGapSeconds = 0.5,       -- a change the other way starts this long after landing (D-054 0)
	weaveGapSeconds = 2.5,         -- ...or this long, for a second reversal within the window (D-054 0)
	weaveWindowSeconds = 8,        -- (debate 012: 5; 7 since the N1 review; 8 since D-072 ruling 4, 7 in the switch-back)
	pressBounceSeconds = 0.2,      -- a press the same way this soon after the last counts once (D-054 0)
	glideReserveFeet = 6,          -- a horse gliding into a lane keeps this much more room (D-054 0)
	blockedPress = "wait",         -- "wait" (D-057) or "d054": a press into a lane with no room
	gapWaitSeconds = 1.5,          -- wait: an outward press waits this long for room, then drops
	gapWaitInSeconds = 0,          -- wait: an inward press that can't tuck back drops after this (0 = waits)
	tuckAfterSeconds = 0,          -- wait: an inward press tucks back after this long without room
	boxedAheadFeet = 12,           -- boxed in: no room either side and a horse this close ahead (reported)
	brush = "repeat",              -- a second press into a horse alongside brushes it (N5; "off" = none)
	brushAlongFeet = 8,            -- alongside = within this many feet lengthwise in the next lane...
	brushGraceSeconds = 0.3,       -- ...for at least this long
	brushRepeatSeconds = 2,        -- the second press comes within this long of the waiting one (0 = any time)
	brushPresses = 3,              -- the press that brushes is at least the third that way since the first (N5 review)
	brushPays = "mover",           -- "mover" (D-057); "bumped", "both", "none" for the sims
	brushCost = 0.002,             -- tau per charged brush (own term, after the field mean)
	brushFree = 1,                 -- the first brushes cost nothing
	brushMaxCharged = 3,           -- at most this many charged; at most brushFree + this many a race
	brushCheckFeet = 4,            -- the payer steadies this far back (Trip's offsets)...
	brushRecoverPerSecond = 2,     -- ...and comes back at this rate
	steadySeconds = 1,             -- the mover can't steer for this long after a brush
	-- D-072 phase A (race realism, provisional; src/trip.py's CONFIG is the same). Each block switches off
	-- on its own; all off (Trip.d072Off, trip.D072_OFF) is D-057's race exactly. Per race, Hurdles runs
	-- fixed lanes (Trip.new's fixedLanes: nobody changes lane, tau = 0). Sim: docs/reviews/race-realism-2026-10-12/phaseA-sim.md.
	file = { enabled = true,       -- file to the rail after the break
		homeLane = 1,              -- Smart Steer riders' home lane (smart.homeLane while off)
		railShare = 0.5, secondShare = 0.35, -- bots' home lane 1, 2, the rest (0.15) lane 3
		fromSeconds = 2, bySeconds = 12, -- Smart Steer and bots head in whenever there's room in this window
		riderRoomFeet = 6 },       -- a Smart Steer rider heads in only with this much clear run ahead (boxed share)
	pack = { enabled = true,       -- running styles and drift (extra feet on the skill target)
		frontShare = 0.3, closerShare = 0.3, -- bots only; riders are stalkers
		frontFeet = 14, closerFeet = -14, -- ramped in from the gate, faded to 0 at the lock
		driftFeet = { 3.5, 2 },    -- two waves (Trip.wave, a C1 parabolic sine): amplitudes...
		driftPeriod1 = { 11, 17 }, driftPeriod2 = { 5, 7 }, -- ...and period ranges, seconds
		driftMaxFeetPerSecond = 1.5, -- each horse's drift moves at most this fast (3 ft/s between two)
		driftFadeSeconds = 4 },    -- drift fades out over the last this-many seconds to the lock
	pass = { enabled = true,       -- bots and idle Smart Steer riders move out to pass
		triggerFeet = 6,           -- a bot held at least this far behind its target by a horse ahead in its lane...
		riderTriggerFeet = 0,      -- ...a Smart Steer rider this far (0: looks for room behind any horse)...
		aheadFeet = 12,            -- ...at most this far ahead...
		triggerSeconds = 0.8,      -- ...for this long
		straightChance = 1, turnChance = 0.25, -- each horse's pre-drawn tendency, straight / turn
		riderTurnChance = 0.25,    -- a Smart Steer rider's, on a turn
		returnClearFeet = 10,      -- heads back in once this far clear of the horse passed...
		giveUpSeconds = 8,         -- ...or after this long out
		maxPasses = 4,             -- moves out at most this many times a race
		closingFeetPerSecond = 6,  -- while alongside the horse it passes, gains on it no faster than this...
		alongFeet = 8 },           -- ...alongside = within this many feet lengthwise (every pass side by side ~0.8 s+)
	doors = { enabled = true,      -- a bot can shut the door on a horse moving into its lane
		shutChance = 0.3,          -- bots whose pre-drawn shut is under this...
		reachFeet = 16,            -- ...within this many feet lengthwise, in the lane being moved to...
		shutSeconds = 1.5,         -- ...hold their line this long...
		gapSeconds = 5 },          -- ...and can't shut again for this long after
	learner = { races = 3, tauFloor = 0 }, -- first races: no shut doors; own presses never lower tau (vs its passive race)
	lockAt = "farTurnEntry",       -- the outcome lock (only value); lanes move draw-only after it
}
-- The steering controls on screen (D-054 S3; RaceController). Chips and tips only show to riders
-- who have the buttons (from their introRaces + 1-th race).
GameConfig.steerHud = {
	buttonPx = 104,          -- ◀ In / Out ▶ size on big screens...
	minButtonPx = 88,        -- ...never smaller (phones)
	tipSeconds = 5,          -- the ghost-thumb tip (once)...
	tipRace = 2,             -- ...from this counted race (D-072 staging: race 1 shows the buttons only)
	padHaloPx = 16,          -- (D-072 consult) a see-through halo this wide round the pad takes stray touches
	pipsRace = 3,            -- the move pips from this race (D-072 hook for phase B; nothing draws them yet)
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
	greyArrows = true,       -- Out ▶ greys while a horse leaves no room; ◀ In only when tuck-back can't help...
	greyAfterSeconds = 0.2,  -- ...once its side has been blocked this long on screen (no blinking); back at once
	greyRgb = { 172, 166, 158 }, -- the grey: soft and warm, about 2:1 against the button's bone white (never red)
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
	-- Brushes (D-057 N5): the mover leans toward the other horse and nods; the other only nods.
	brushLeanFeet = 1,       -- the mover's lean, drawn only (never in the lanes that rank the race)...
	brushLeanSeconds = 0.4,  -- ...out and back over this long (the nods too)
	brushNodDeg = 2,         -- a small nod, both horses
	brushVolume = 0.5,       -- bump_soft at half volume, at the mover's horse (silent until uploaded)
	brushLateSeconds = 1 / 30, -- a brush first drawn later than this into it starts from the beginning then
	-- Shut doors (D-072, votes-feel R3): the bot that shuts the door turns toward the mover, drawn only.
	shutYawDeg = 6,          -- this far toward the mover (D-072 consult: 3 didn't read)...
	shutEaseSeconds = 0.25,  -- ...eased in and out over this long, held for steering.doors.shutSeconds
	shutLeanFeet = 0.6,      -- ...leaning this far toward it, drawn only (a brush leans 1)
	shutPumpScale = 1.5,     -- ...its jockey pumping this much harder while it holds the door
	shutVolume = 0.4,        -- bump_soft at the shutting bot...
	shutSoundSpeed = 0.9,    -- ...pitched down a little
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
	-- (D-066) The body bob follows the legs: lowest as the leading forefoot lands, once a gallop
	-- stride (HorseLegs.bob). false = the old 1.8 Hz clock, which drifted against the legs.
	bobFromLegs = true,
	bobStuds = 0.3,           -- how high the body rises between plants
	bobPitchDeg = 1.5,        -- ...and how far it rocks, nose down on the plant (0 = no rock)
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
-- Race feel (D-066, AAA Phase 1): what a tap looks and sounds like on your own screen. All of it is
-- drawn or heard only, on your screen only: nothing here changes a score, the order or the trip.
-- Reduced Motion turns off the camera kicks, the surge's rock, the trails and the dust; the label
-- still shows (without its pop) and the nudge still moves your horse.
GameConfig.raceFx = {
	enabled = true,               -- false: no pop, surge, dust, kicks or tap tick (the nudge stays)
	-- The tap nudge (tapNudgeFeet) never moves faster than the race view lets a gap move (D-055)...
	nudgeFeetPerSecond = 10,      -- (raceView.maxGapFeetPerSecond)
	nudgeClearFeet = 10,          -- ...nor closer than this behind a horse ahead in your lane (steering.holdGap);
	nudgeSlackFeet = 1,           -- a horse cutting in eases the nudge back, pulled in at once only past this
	labelPop = true,              -- the tap word pops in...
	labelPopScale = 1.3,          -- ...from this size...
	labelPopSeconds = 0.18,       -- ...over this long
	surge = true,                 -- a Perfect pace tap: your horse rocks forward, with trails and a dust burst
	surgeOnGreatStreak = 3,       -- ...and every 3rd Great-or-better tap in a row (0 = Perfect only)
	surgeSeconds = 0.4,
	surgePitchDeg = 3,
	trails = true,                -- two short white streaks off the flanks during the surge
	dust = true,                  -- dust from your horse's hooves: one puff a stride, a burst on a surge
	dustPerStride = 1,
	dustPerSurge = 6,
	dustTexture = "rbxasset://textures/particles/smoke_main.dds", -- built in; fx_dust_puff isn't uploaded
	dustRgb = { 227, 185, 133 },  -- dirt (ART_DIRECTION)
	-- One owner for camera kicks (RaceController): the total stays at or under fovMaxDeg.
	perfectFovDeg = 1.5,          -- a Perfect pace tap widens the view this much...
	perfectFovEverySeconds = 0.8, -- ...at most this often
	burstFovDeg = 4,              -- a Great or Perfect Final Burst: the big kick
	fovRiseSeconds = 0.06,
	fovFallSeconds = 0.3,         -- (the burst's eases back twice as slowly)
	fovMaxDeg = 6,
	tapTick = true,               -- a soft tick on every counted pace tap, a step higher for each label
	tickSpeeds = { Miss = 0.9, Okay = 0.95, Good = 1.05, Great = 1.17, Perfect = 1.3 },
	tickVolume = 1.6,             -- x tap_ok's own level (0.25): about 0.4, over the hoofbeats
	gallopDuck = 0.67,            -- the hoofbeats (gallop_loop, 0.45) at this x while the slider runs: about 0.3
	perfectChimeVolume = 0.6,     -- with the tick on, a Perfect also chimes (tap_good) at this volume; Great just ticks
	-- Hoofbeats in step with the legs: gallop_loop plays at (race speed / gallop stride) / this, the
	-- strides a second the loop was rendered at (2 now: about 1.55x). Re-tune when the loop is re-rendered.
	gallopLoopStridesPerSecond = 2,
	-- First-race coaching (AAA Phase 2, D-067): a player's first coachRaces races (profile
	-- totals.races below it) show the rule "Tap once every time the marker passes the glow" for
	-- coachHintPasses passes, the ghost thumb tapping over the glow and "NOW!" as the marker
	-- enters it for coachPasses passes, and coachBurstHint as the Final Burst title comes up.
	coachRaces = 1,
	coachPasses = 4,
	coachHintPasses = 3,
	coachHint = "Tap once every time the marker passes the glow", -- (D-069: the glow is Gold now, not green)
	coachBurstHint = "Big tap coming!",
	judgeAtMarker = true,         -- every race: the tap's word also pops small at the marker, where you tapped
	judgeSeconds = 0.6,
	coachNowZone = 0.2,           -- "NOW!" while the marker is within this of the glow's centre (-1..1 units; the glow is 0.2 each side)
}
GameConfig.gateCountdownSeconds = 3 -- "3, 2, 1" over the gate, then "GO!" with the bell (D-055)
-- Race screen (D-055).
GameConfig.hud = {
	missedPassLabel = "",        -- a pass with no tap shows no word ("Miss" = before D-055)
	earlyLateBelow = 30,         -- a tap scoring under this says "Early" or "Late"
	riderBoardInRace = false,    -- riders see the running-order board in the race (true = D-030)
	boardShowsChance = false,    -- win % and purse on the board, and the rider's live win chance line
	spectatorBoardRowsPhone = 4, -- spectators on phones: the top 3 plus their cheered rider
	-- (D-066) The bar under the slider is the mean of your last few passes: how well you ride, not
	-- how fast your horse goes, so it is "RIDING" (★ means riding, D-064), gold over slate.
	rideMeterLabel = "RIDING",
	-- (D-066) Phones with the ◀ ▶ pad: the slider and the bar under it sit right of the pad, the
	-- whole race, so a thumb on Out ▶ never hides the glow. false = centred, as before.
	sliderClearOfPad = true,
	-- (D-066) A tap on the Final Burst while it's still grey (not armed) shows this, no sound, and the
	-- grey bar gives a small shake (none under Reduced Motion). "" = nothing.
	burstEarlyHint = "Wait for the rainbow!",
	burstEarlyShakePx = 6,
	-- (D-067) The chance arrow on your place badge (and a spectator's cheered rider): only when a
	-- checkpoint closes, never on the once-a-second previews, so it doesn't flicker. true: previews
	-- may show it too, on a change over arrowPreviewMinChange at most every arrowPreviewEverySeconds.
	arrowOnPreview = false,
	arrowPreviewMinChange = 0.01,
	arrowPreviewEverySeconds = 3,
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
	gearBelowGem = true,  -- AAA Phase 2 (D-067): the ⚙️ sits under the 💎 pill, not on top of it
}
-- Phones first (D-064, stage 1): rendered floors for the dock, whatever the screen. fitDock never
-- scales a button below minTouchPx or a label below minTextPx; on a phone the dock is the horse
-- card, RACE! and ☰ More (dockPhoneItems = 3), and everything else moves into More.
-- dockPhoneItems = 5 (D-075) is the five-item phone dock; 6 or more keeps the full dock on phones too.
GameConfig.ui = {
	minTouchPx = 56,
	minTextPx = 14,
	labelPx = 16,
	dockPhoneItems = 5,   -- Find it (D-075): horse, RACE! with 🔀 Pick, Map, Jobs, ☰ More (3 = the D-064 short dock)
	pickStripPx = 64,     -- Find it: the 🔀 Pick strip beside RACE!, unscaled
	phonePortraitPx = 70, -- Find it: the phone dock's horse portrait (coat dot over Energy pips), unscaled
	dockShrinkOrder = { "jobs", "map" }, -- Find it: on a phone too narrow for five, these go into ☰ More, in order
	portraitTap = true,   -- Find it: tap the portrait for My Horses (a thumbstick drag from it still walks); false = display-only (D-056)
	portraitTapMovePx = 10, -- a touch that moves further than this is a drag, not a tap
	portraitTapSeconds = 0.5, -- a touch held longer than this is not a tap
	phoneShortSide = 500, -- a screen whose shorter side is at most this many px is a phone
	toastMaxWords = 10,   -- stage 3 (D-064): every toast at most this many words (Words.toastOk)
	panelMinText = 16,    -- stage 3: the smallest text on the big panels (picker, Stable Board, My Horses), unscaled
	panelButtonPx = 64,   -- stage 3: the smallest button on those panels, unscaled (PanelFit keeps both at the floors)
	pickerLineWords = 5,  -- stage 3: a race card's one line, at most this many words
	closePx = 64,         -- AAA Phase 2 (D-067): every panel's ✕ (Ui.closeButton), unscaled
	starterCompactBelowPx = 500, -- AAA Phase 2 fixes: the Starter on a shorter screen gets 104 px horse pictures (Next ▶ shows whole)
}
-- The results card (D-064): one row; tripRow = true brings back D-054's "Good trip ★★☆" row.
-- AAA Phase 2 (D-067): the card is rebuilt at the panel floors (16 px text, 64 px buttons
-- unscaled; it scrolls rather than shrink past them) under the Roblox top bar, with a place
-- headline and kind words for every place (ResultsText.headline, .cheer). raceAgain: a 64 px
-- "🏁 Race again" that does what RACE! does (the same league's line; Practice while napping, and
-- it says so). riderRank: "Best ride in the race!", "2nd best ride!" or "3rd best ride!" from the
-- ride score, top 3 only and only on your own card (never a board). false = the D-064 card's rows.
-- Phase 2 fixes: rankMinStars (the gameplay consult): "Best ride" only with at least this many
-- stars, so "★☆☆" never sits beside "3rd best ride!". feedWhenNapping (the systems consult): a
-- napping horse with no other horse ready gets "🌾 Feed Comet" (to the stall) instead of Practice.
-- twoColumnBelowPx (the UI/UX consult): on a landscape screen shorter than this the card is two
-- columns, cardWideW px wide, so Race again, the replays and Done fit without scrolling.
GameConfig.results = { tripRow = false, raceAgain = true, riderRank = true, headline = true, rankMinStars = 2,
	feedWhenNapping = true, twoColumnBelowPx = 500, cardWideW = 720 }
-- AAA Phase 2 (D-067): the finish moment, on the rider's own screen only and drawn only (no score,
-- order or result reads any of it). Horses gallop on past the line and ease down over about
-- gallopOutFeet (0.04 of a Short race; 0.012 before, a near dead stop). As your horse crosses, the
-- camera arcs from behind it to the replay's side view (orbitSeconds, never more than 2.5), with
-- confetti and a gold outline for 1st and the ribbon stamping onto the screen for 1st to 4th. Any
-- tap skips to the card, and the card is up at the latest cardWithinSeconds after the leader
-- reaches the line. Reduced Motion: no orbit and no confetti; the card fades in over fadeSeconds.
-- enabled = false: the card after runInSeconds with no finish moment (horses still gallop out;
-- gallopOutFeet = 46 is the old near stop).
GameConfig.finish = {
	enabled = true,
	gallopOutFeet = 155,
	orbit = true,
	orbitSeconds = 2.5,
	cardWithinSeconds = 4,
	crossWaitSeconds = 1.5, -- your horse's crossing not seen this long after the leader's: start anyway
	confetti = true,
	confettiCount = 70,
	stamp = true,
	stampSeconds = 0.35,
	fadeSeconds = 0.4,
	dim = 0.75,             -- the world behind the card tints Ink to this transparency (warm, not black; the consult)
	skipAfterSeconds = 1.0, -- (the feel consult) taps in the first second after the crossing don't skip: a reflex
	                        -- tap from the stretch drive's rhythm never throws the moment away
	stampAt = { 0.22, 0.30 }, -- the stamp's centre (screen x, y): the upper-left third, clear of your horse; scaled with the HUD
	-- AAA Phase 4 (D-069): paper confetti (the confetti_square image once uploaded; the built-in sparkle
	-- until then) in the art direction's colours, and the card's stars counting in one by one: the first
	-- starDelaySeconds after the card shows, then every starStepSeconds, each with starTick at the next
	-- of starTickSpeeds (a rising tick). Reduced Motion: the stars show at once, no ticks.
	confettiFallback = "rbxasset://textures/particles/sparkles_main.dds",
	starDelaySeconds = 0.3,
	starStepSeconds = 0.2,
	starTickSpeeds = { 1.0, 1.15, 1.3 },
	starTick = "count_tick",
	starTickVolume = 0.8,
}
-- AAA Phase 2 (D-067, the gameplay consult): after the far-turn lock the live chances shown on
-- screen refresh every `seconds` from the open checkpoint's finished passes (as the stretch drive
-- does), through checkpoint `throughCheckpoint`, so taps move horses on screen sooner. Drawn only:
-- the trip's tau is already fixed at the lock and nothing before the lock changes; the result and
-- the scores come from the checkpoints as before. Needs steering (no lock without it).
GameConfig.pacePreviewAfterLock = { enabled = true, seconds = 1, throughCheckpoint = 2 }
-- D-071 (provisional): the draw-only pre-lock preview (shared/TapPreview). Before the lock a rider's
-- drawn offset leads Trip's by lead * leadFeetPerShare * (preview - live) * ramp * n / (n + shrinkPasses),
-- from pass minPasses of the open checkpoint (previewBots: bots too), at most capFeet ahead and
-- capBackFeet behind, moving at most maxSpeed ft/s and maxAccel ft/s^2 on top of Trip's own motion.
-- Lane room: laneGapFeet clear of horses in or gliding into its lane, never inside hardGapFeet once
-- within hardLaneBand lanes, eased back or on at most pullPerSecond; a horse in the next lane stays
-- within joinSlackFeet of where Trip puts it once they are joinClearFeet apart (steering.clearFeet),
-- so a lane change never meets a horse drawn too close. At a close or the lock the drawn horse holds
-- while Trip's catches up (for fadeSeconds after the lock), then the residual eases out.
-- Never reads luck; decides nothing. steeringOffWholeRace: with steering off the shown chances
-- preview at every pass end instead (PacePreview.beforeLock). The message ("Giddy-up! Moving up!",
-- TapPreview.message; never "away"/"lead"/"win" before luck can reorder the field) shows on a messageFeet gain over the field's mean while the
-- rider's own taps score at least messageMinScore over messageMinPasses passes, at most every messageEverySeconds, never on a loss.
-- enabled = false is the race before D-071 exactly. Tuned in docs/reviews/aaa-2026-10-11/tapgap-results.md.
GameConfig.tapPreview = { enabled = true, lead = 1.2, minPasses = 2, shrinkPasses = 2, capFeet = 12, capBackFeet = 6,
	maxSpeed = 10, maxAccel = 20, laneGapFeet = 10, hardGapFeet = 7.5, hardLaneBand = 0.55, pullPerSecond = 19,
	joinClearFeet = 8, joinSlackFeet = -4, settleFeetPerSecond = 2, fadeSeconds = 1, previewBots = false, steeringOffWholeRace = true,
	messageEnabled = true, messageFeet = 8, messageEverySeconds = 4, messageMinScore = 60, messageMinPasses = 6, messageMinClean = 0.8,
	-- (D-071 rulings) Held by lane room (TapPreview.held, TapPreview.stepCue): a pressure cue on your own
	-- screen at minFeet for minSeconds; the chip at chipMinFeet for chipMinSeconds, "Room this way! ◀/▶" at most
	-- every chipEverySeconds (buttons), "Keep tapping! Room soon." once a race (Smart Steer). Copy: TapMessage.
	heldCue = { minFeet = 4, minSeconds = 1.0, chipMinFeet = 6, chipMinSeconds = 1.5, chipEverySeconds = 10 },
	-- (review N6) TapHeld sends (TapPreview.heldSendDue): a 1 ft change, at least 0.5 s apart, a resend
	-- each second while held; dropping to 0 or crossing a cue threshold goes at once.
	heldSend = { feet = 1, minGapSeconds = 0.5, resendSeconds = 1 },
	-- (feel review) a drawn lead given back at a close or the lock eases back at most this fast
	pullBackFeetPerSecond = 6 }
-- The tap preview on the rider's own screen (D-071, provisional; client/TapCue, shared/TapMessage).
-- enabled = false hides the message, the pressure cue and the held chip (the server still sends).
-- The message ("Giddy-up! Moving up!", gains only, never "pulling away") is silent, over your saddle at
-- studsAbove for messageSeconds (text minTextPx..maxTextPx; on the hint line in first person; the YOU
-- marker steps aside meanwhile); it waits up to waitSeconds behind a steering chip or coaching, else is
-- dropped, and never shows in the Final Burst or after the lock. The place badge pops by badgePopScale
-- with it (not under Reduced Motion). The pressure cue (tapPreview.heldCue) multiplies your horse's bob
-- by bobScale, leans it forward leanDeg and adds pressureDust puffs a stride (none under Reduced
-- Motion). The held chip ("Room this way! ◀/▶") lights that button's ring for ringSeconds. (When the
-- server sends TapHeld: tapPreview.heldSend, TapPreview.heldSendDue.)
GameConfig.tapCue = { enabled = true, messageSeconds = 1.6, waitSeconds = 2.5, studsAbove = 6.5, badgePopScale = 1.15,
	minTextPx = 14, maxTextPx = 24, bobScale = 1.3, leanDeg = 2, pressureDust = 1, ringSeconds = 1.5 }
-- The "Next thing" pill (D-064, stage 3): one suggestion above the dock from Advice.nextThing, with
-- GO; Pip gives a hint when the same suggestion has been up this long and you haven't moved.
-- raceFirstUntilRaces (AAA Phase 2, D-067): until a player has run this many races, the pill puts
-- "Race with Comet!" before feeding, brushing and jobs (0 = the stage 3 order).
GameConfig.nextThing = { enabled = true, pipHintSeconds = 20, stillStuds = 6, raceFirstUntilRaces = 3 }
-- Find it (fun-and-return phase 1, D-075, provisional). FindIt.luau holds the rules; Lune tests them.
--   map: the Map's 5 × 3 grid of tiles (WorldLayout.MAP), each tileW × tileH px with an iconPx icon
--     over a wordPx word and one plum "what to do here" line (hintPx, at most hintWords words).
--   goTo: GO walks with hoofprints when the place is at most walkMaxStuds away, else fades to Paper
--     over fadeSeconds, travels there (the Map's own trip) and opens the feature. In a race line or a
--     race it only draws hoofprints. arriveStuds: a walk opens the feature this close to the place.
--     travelWaitSeconds: the most a teleport waits for the trip before it opens anyway.
--   pointers: "New!" first-time pointers, at most one per gapSeconds, never on the tour, in line,
--     racing or within afterRaceSeconds of your race. showSeconds on screen (or its GO) marks it seen
--     (saved in the profile). ringSeconds: the gold ring round the dock button, pulsing at ringHz.
--     The *Races keys are how many races a player has run before that pointer can show.
--   howRacing: the queue card's ❓ strip (3 pictures), shown by itself once, the first time in line.
--   signpost: the Fair Street signpost past the fountain, in view as a new player arrives (WorldLayout
--     .arrival("plaza") faces east), built from parts (no uploads), one arm per place, each pointing at it.
GameConfig.findIt = {
	map = { tileW = 116, tileH = 96, gapPx = 8, headerPx = 64, iconPx = 48, wordPx = 18, hintPx = 16, hintWords = 2, columns = 5 },
	goTo = { walkMaxStuds = 120, fadeSeconds = 0.3, arriveStuds = 14, travelWaitSeconds = 1.5, openDelaySeconds = 0.2 },
	pointers = { enabled = true, gapSeconds = 180, afterRaceSeconds = 120, showSeconds = 20, ringSeconds = 6, ringHz = 1,
		pickRaces = 3, bookRaces = 2, trainRaces = 3, builderRaces = 4, marketRaces = 6, visitRaces = 10 },
	howRacing = { enabled = true, autoOnce = true, picturePx = 150, pictureW = 180 },
	signpost = { enabled = true, x = 745, zOffset = 14, postHeight = 22, armLength = 15, armStep = 2.6,
		arms = { "track", "stable", "feedStore", "vet", "market", "paddock" } },
}
-- Green Cash sink (D-070, provisional): Barn Builder at Feed & Seed (BarnCatalog, Green Cash only).
-- enabled = false hides the counter and its pill (owned things stay in the yard). wishChip: the wished
-- item's icon and bar on the cash card. pillAfterRaceSeconds: no "You can build" pill or shelf note this
-- long after your race (DiamondProducts.afterRaceSeconds too). pillShowSeconds: the pill counts as shown
-- for an item after this long on screen (or its GO), then never again for that item. returnHours: a
-- build can be returned for all its Green Cash. buildFx: the drop-in (false or Reduced Motion: a fade).
-- newBuildHours: ✨ by your name on Friends' barns. buyGapSeconds: the server's gap between two buys.
-- pendingBuildSeconds: a build waits this long for you to walk home to see it, then just shows.
GameConfig.greenCash = { enabled = true, wishChip = true, pillAfterRaceSeconds = 120, pillShowSeconds = 45, returnHours = 24,
	buildFx = true, newBuildHours = 48, buyGapSeconds = 1, shelfNote = true, pendingBuildSeconds = 900 }
-- Your horse's stall while it's out (D-056): empty, with a plaque on the door.
GameConfig.stable = { awaySign = true }
-- Visiting friends' barns (D-060, D-042): only Roblox friends in this server, never a count.
GameConfig.visit = {
	enabled = true,
	mapList = true,           -- the Map's Friends' barns list and its trip to the gate (false: walk Barn Lane only)
	bondPerHorsePerDay = 1,   -- bond a horse can get from all visitors together in a day
	treatsPerFriendPerDay = 1, -- free treats a visitor can give at one friend's barn a day
	treatBond = 1,            -- bond a visitor's treat gives (inside the cap above)
	carrotsPerFriendPerDay = 1, -- carrots a visitor can drop in one friend's post box a day
	postBoxPerDay = 5,        -- carrots a post box takes a day from all visitors together
	nearStuds = 30,           -- how far outside a friend's plot still counts as "at their barn"
	travelGapSeconds = 3,     -- between two visits by the Friends' barns list
	listMax = 12,             -- faces on the Friends' barns list
	-- Visiting other stables (D-079). everyone: owners may choose "Everyone here" (false: it reads as
	-- Friends). askOnce: "Let other riders visit?" the first time the barns list opens. Strangers may
	-- look, walk the tour, pat and cheer; treats and the post box stay friends-only (Visits.may).
	everyone = true,
	askOnce = true,
	helloGapSeconds = 0.5,    -- the server's gap between two pats, cheers or tour stops from one visitor
	cheersPerBarnPerDay = 3,  -- preset cheers one visitor can send one barn a day
	ownerCheerGapSeconds = 30, -- the owner's anonymous "A visitor cheered!" toast, at most this often
	arriveCheckSeconds = 1,   -- how often the server looks for visitors walking into a barn
	bannerSeconds = 2.5,      -- the arrival banner, then it fades
	bellVolume = 0.4,         -- gate_bell on arrival (existing SoundSheet clip)
	bellSpeed = 1.3,
	stopStuds = 16,           -- the server: this near a tour stop counts as there
	stopArriveStuds = 10,     -- the client: this near a stop sends it (inside stopStuds)
	-- The walkaround's stops as (inward from the lane, across) on the plot (StableService's plotCF), where
	-- you stand, and lookIn/lookAcross, the thing it features (outlined when you get there): the Rosette
	-- Wall (52, 12), the stall fronts (barn front 88), the yard props where Barn Builder pieces stand
	-- (82, 35), and the 4th: the Legend paddock's arch (62, -22) with a Legend, else the garden beds
	-- (inward 26-54, across -35). Visits.stopsFor picks the 4.
	tourStops = {
		{ id = "wall", inward = 44, across = 12, lookIn = 52, lookAcross = 12 },
		{ id = "horses", inward = 78, across = 0, lookIn = 88, lookAcross = 0 },
		{ id = "decor", inward = 72, across = 28, lookIn = 82, lookAcross = 35 },
		{ id = "paddock", inward = 56, across = -22, lookIn = 71, lookAcross = -22 },
		{ id = "garden", inward = 40, across = -26, lookIn = 40, lookAcross = -35 },
	},
	lookStuds = 14,           -- the featured object is the barn piece nearest the look point, this near
	-- PolicyService (VisitAccess): one retry this long after a failed read; until then strangers are out.
	policyRetrySeconds = 10,
	arriveRepeatSeconds = 20, -- walking back into the same barn this soon: no second bell or banner (N1)
	-- Ask to leave (code review S3): the owner walks one visitor out; they can't come back in for this long.
	askLeaveSeconds = 120,
	askLeaveGapSeconds = 1,   -- the server's gap between two of one owner's asks
	-- A tour stop in the world (feel consult): a gold sparkle and a gold outline on the featured thing.
	stopFx = { sparkles = 12, sparkleLife = 0.8, sparkleSpeed = 6, color = "FFD23F", highlightSeconds = 1.2, fadeSeconds = 0.3 },
	-- A sent cheer (feel consult): its emoji floats up from the barn door (door at plot inward 88, across 0).
	cheerFx = { px = 64, startStuds = 4, riseStuds = 3, seconds = 1.2, fadeSeconds = 0.4, volume = 0.4, yaySpeed = 1.2,
		doorIn = 88, doorAcross = 0 },
}
-- Riding your own horse (D-056).
GameConfig.riding = {
	hopButton = true,   -- touch: a Hop button at Roblox's own jump spot while you ride
	bobAmp = 0.15,      -- body bob, in step with the legs (hooves stay on the ground)
	legLength = 2.45,   -- hip to hoof, for the hoof-lift correction
	-- The forward hop (D-074, race realism; HorseJump): free riding and training rides. A hop always
	-- goes forward: at least forwardMin, else the speed along the facing + forwardBoost, never over
	-- forwardCap (set below from training.maxSpeed) nor, on a training course, over the course's own
	-- pace, and never forward at all where the course says so (TC.hopCap: the Gate Break stall), so a
	-- hop never beats the course or makes an early go. Peak = jumpPower² /
	-- (2 × 196.2) = 3.68 studs (TC.RIDE_HOP); airtime 2 × 38 / 196.2 = 0.39 s.
	-- In the air the legs stop cycling and fold (tuckLegs), the body pitches pitchUpDeg nose-up while
	-- rising and pitchDownDeg nose-down falling, and squashes to landSquash of squashHeight for
	-- landSeconds on landing, with a soft thud (bump_soft at thudSpeed) and a dust puff (pitch,
	-- squash and dust off under Reduced Motion; the folded legs and the thud stay). Other players'
	-- horses count as airborne past remoteAirVy studs/s up or down when their state lags.
	-- While a hop flies, WalkSpeed is the hop's own speed, so the Humanoid's air control holds it.
	hop = { jumpPower = 38, forwardMin = 14, forwardBoost = 4, movingFrom = 2, forwardCap = 51, cooldownSeconds = 0.6,
		holdSeconds = 1.2, tuckLegs = true, airDelaySeconds = 0.06, tuckRate = 10, untuckRate = 6,
		pitchUpDeg = 9, pitchDownDeg = 7, pitchRate = 20, landSquash = 0.96, squashHeight = 4, landSeconds = 0.08,
		thudVolume = 0.6, thudSpeed = 0.8, dustPuff = 8, remoteAirVy = 6 },
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
GameConfig.lobbyFillSeconds = 15     -- bots fill remaining lanes after this (D-061: was 20)
-- Race queues (D-061 core, stage 1): one queue per league and kind (Race, Cup, Practice); a
-- course whose card is open goes to the longest-waiting queue, and a card claimed by one league
-- never takes a rider of another. mode = "cards" restores the D-036 claiming (first rider's
-- league claims a card; RACE! picks the busiest course).
-- openPractice (AAA Phase 3, D-068): every league's Practice shares one "Open" queue, so friends in
-- different leagues can race together. Practice pays nothing and earns no League Points, so mixed
-- Ratings are harmless. false = one Practice queue per league (D-061).
-- openPracticeLeague: every Open Practice card runs at this league's settings (sweep, burst,
-- distances, bots), never the first rider's league. practiceEqualHorses: in every Practice race
-- each lane gets the same Rating (base chance 1/8), so taps, the trip and luck decide. Both are
-- Practice-only (no purse, no points); false / nil restore the first Phase 3 build.
GameConfig.queue = { mode = "leagues", openPractice = true, openPracticeLeague = "Rookie", practiceEqualHorses = true }
GameConfig.kappa = 1.0
GameConfig.qFloor = 0.025
GameConfig.rFloor = -0.5
GameConfig.placePrizes = { 1.2, 0.8, 0.4 }       -- 2nd, 3rd, 4th, in units of B
GameConfig.leaguePoints = { 10, 6, 4, 2 }        -- 1st..4th; everyone else gets finishPoints
GameConfig.finishPoints = 1
-- League Points needed to unlock each league's Stakes race (D-013, from sims/economy.py).
-- History (before D-068): Silver 750 (was 1,400; D-062 stage 8): `python sims/economy.py --silver` gave a casual player
-- (new kid, Silver-entry horse 68, against the league-anchored bots) the Cup in about 167 Silver
-- races (target 150-200); 600 gave 133 and 1,400 about 313.
-- AAA Phase 3 (D-068): retuned with botRatingAnchor and leagueCeiling in one sim on realistic
-- Ratings (training cap), `python sims/economy.py --ladder phase3`: a casual kid opens each Cup in
-- about 20 / 40 / 90 / 180 races (docs/reviews/aaa-2026-10-11/phase3-sim.md). Before: 100/110/750/3000.
GameConfig.stakesUnlockPoints = { Rookie = 100, Bronze = 200, Silver = 450, Gold = 900 }
-- Class badges and first wins (D-062 stage 8): a horse's first win in each league earns
-- firstWinBonus League Points once; its badge is First Win (no wins in this league), Rising Star
-- (fewer than risingStarBelow), Open, or Cup when its Cup is open. Labels only: one queue per
-- league, no demotion, never a change to win chance.
GameConfig.firstWinBonus = 10
GameConfig.classes = { risingStarBelow = 3,
	-- Visible progress (fun-and-return phase 2, D-076): the class path on the horse card and the results
	-- card, First Win -> Rising Star -> Open -> Top Horse -> Cup. topWins: wins in the league for the
	-- Top Horse step. starIsRace = true (once the named prestige races exist) calls that step Big Race.
	-- path = false hides the path and the Cup bar.
	path = true, topWins = 5, starIsRace = false }
-- The Cup bar (D-076): League Points shown as a bar, never a number (D-064 hid "pts"). On the results
-- card the bar fills from before to after with one tick per point (at most ticksMax, speeds rising
-- tickSpeeds[1] -> [2]) over fillSeconds; under Reduced Motion it just shows. results = false: horse card only.
GameConfig.cupBar = { enabled = true, results = true, ticksMax = 10, tickSpeeds = { 1.0, 1.3 }, fillSeconds = 0.6, tick = "tap_ok" }
-- The class-up ceremony at the Rosette Wall (D-076): when a horse's class path step rises, the next time
-- you're within nearStuds of your Rosette Wall (never racing, in line or on the results card) a sparkle
-- bursts on the wall with sound (tap_good, then clap x claps) and one line, for at most seconds; any tap skips.
-- It never touches Race again. enabled = false: no ceremony (the path still moves).
GameConfig.classUp = { enabled = true, seconds = 3.5, nearStuds = 40, sound = "tap_good", clap = "clap", claps = 3, sparkles = 40 }
-- League ceilings (D-046): a horse whose best base Rating passes this has its Cup opened and
-- its league's regular races closed. The Cup winner gets cupPurseB × B (D-048).
-- AAA Phase 3 (D-068): an average kid wins about 36% at each ceiling, and they rise league to
-- league. Before: 58/68/78/88.
GameConfig.leagueCeiling = { Rookie = 55, Bronze = 57, Silver = 60, Gold = 66 }
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
-- Bots by league (D-061 stage 2): every bot is rated anchor ± botRatingSpread (uniform), whoever
-- is in the race. The debate's anchors (Rookie 50, Bronze 63, Silver 73, Gold 83, Champion 90)
-- failed the gate: a fresh starter ridden by an average kid won 12% of solo Rookie races. The D-061
-- anchors (32/46/56/69/80, tuned by `--solo` on the old fixed entry Ratings) are history now.
-- botRatingAnchor = nil restores bots rated around the human median (before D-061).
-- AAA Phase 3 (D-068): anchored to the Rating a casual horse really has on entering each league
-- (an average kid wins about 25% on entry, Gold 22%). Before: 32/46/56/69/80.
GameConfig.botRatingAnchor = { Rookie = 32, Bronze = 35, Silver = 38, Gold = 48, Champion = 56 }
GameConfig.botRatingSpread = 6                   -- bots rated within ± this of the anchor (or the human median)
-- The one race button and the queue card (D-061 stage 2). oneTapRace: RACE! joins the line for
-- your active horse at once ("More choices" on the queue card opens the picker); false = RACE!
-- opens the picker (stage 1). raceTimeSeconds: how long "Race time!" shows as the gate fills.
-- AAA Phase 2 (D-067): compactPhone draws the card on a phone as one 64 px row (ring, "Race in 12 ·
-- 3 riders", ✕); tap it to see the gate. warmUp adds a "Warm up" button to that row for a player's
-- first warmUpRaces races: a practice slider on the card that counts nothing and sends nothing.
GameConfig.queueCard = { enabled = true, oneTapRace = true, raceTimeSeconds = 3,
	compactPhone = true, compactHeight = 64, warmUp = true, warmUpRaces = 3 }

-- The first minute (AAA Phase 2, D-067): one voice. While the tour runs it owns the screen.
GameConfig.firstMinute = {
	tourOwnsScreen = true, -- the Next-thing pill steps aside while the tour runs, and the Starter's toast is dropped
	holdToastSeconds = 60, -- during the tour's race step, toasts wait (at most this long), then show
	tourGoOnRace = false,  -- the race step points at the real RACE! button (true: the tour card has its own GO)
	pulseRace = true,      -- ...which pulses under a hoofprint arrow (Reduced Motion: the arrow only)
	skipConfirm = true,    -- the tour's ✕ (far from GO) asks once before skipping
	hideGemPill = true,    -- no 💎 door until the tour's race step is done
	-- AAA Phase 4 (D-069, Phase 2 should-fixes): the tour's ✕ ignores a second tap this soon after the
	-- first (a quick double tap never skips); a toast that comes within raceReasonSeconds of a RACE! press
	-- (or, when RACE! opened the picker, of the picker closing on its join) is never held, so the reason a
	-- race didn't start always shows.
	skipGuardSeconds = 0.6,
	raceReasonSeconds = 4,
}
-- One card at a time at the top centre (Ui.slot): the highest priority that wants the spot shows;
-- toasts stack below whatever card is up. raceTime: the queue card's "Race time!" outranks the tour.
GameConfig.topSlot = { tour = 30, queueCard = 20, raceTime = 40, visit = 10, gapPx = 8, sideReservePx = 134 } -- visit: the visitor bar (D-079), under every other card

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
	restingLabelAt = 0,              -- D-058: "Napping" only at this Energy or less; "Ready" above it
	yawnAt = 1,                      -- D-058: the horse yawns in its stall at this Energy (above restingLabelAt)
}

-- Spa Day at the Vet (D-058, stage 4): hose, brush and towel, tapping only. Free, perDay times per
-- horse per server day; then "Spa opens again tomorrow" (no countdown). +energy (never above the
-- cap), a Health Passport stamp, and a cosmetic shine on the next race. Never bond, Rating or win chance.
GameConfig.spa = {
	enabled = true,
	perDay = 1,
	energy = 1,
	minSeconds = 8,                  -- the server takes a Spa only this long after it started (a real wash)
	lagAllowance = 1.5,              -- seconds off minSeconds for the trip SpaStart takes to the server
	taps = { hose = 6, brush = 6, towel = 4 }, -- taps per step (about 30 s in all)
	shine = true,                    -- sparkle on the horse in its next race
	muddyLook = false,               -- D-058 minority view ("Muddy & happy"), off
	napLowerStuds = 1.8,             -- no lying model for this coat: the standing horse sinks into a straw bed
}

-- Reasons to come back (D-063, stage 6). The Welcome Back Hay Bale: after awayDays or more whole
-- days away, one flat gift (never bigger for a longer absence, never on two days in a row, no
-- streak). The Horse Book, personal bests ("New best!") and the Photo Finish camera can each be
-- switched off. Studio only, for the parent checks without editing a save: studioAwayDays pretends
-- the last visit was this many days ago; studioMonthStamps starts this month's stamps at that count.
GameConfig.comeback = {
	welcome = { enabled = true, awayDays = 3, gift = { hay = 5, seed_carrot = 2, treat = 1 } },
	horseBook = true,
	bests = true,
	photo = true,
	studioAwayDays = 0,
	studioMonthStamps = 0,
}

-- Careers (D-059, stage 7; stats never drop, ageing below only changes the raced Rating). A career badge every badgeEvery races; a
-- Veteran at veteranAt races may take an opt-in Legend Retirement (two taps; suggested once per
-- horse): it moves to the Hall of Fame paddock beside the barn, keeps its stats, can still be
-- ridden, and frees its stall. legacyMax is the most Potential a Legend passes to one foal once
-- breeding exists (D-047); unused until then. retireNeedsVeteran = false brings back retiring
-- any horse at any time (as before stage 7).
-- AAA Phase 3 (D-068): suggest = false stops the one-time Legend card until breeding exists (the
-- 👑 Legend button on the horse's card stays), and a Legend can come back to the races
-- (Leagues.unretire, "🏁 Back to races" on its card). true = the stage 7 suggestion at veteranAt.
GameConfig.career = {
	enabled = true,
	suggest = true,                  -- (D-080) on with breeding.enabled: Legends can be parents
	badgeEvery = 25,
	veteranAt = 350,                 -- = ageing.veteranAt (one "Veteran", fun-and-return ruling 3; was 100, D-059)
	legacyMax = 2,
	retireNeedsVeteran = true,
	paddockShown = 4,                -- Legends standing in the paddock (the Hall of Fame list keeps them all)
	sparkle = true,                  -- the gold sparkle on a Legend (off on screens with Reduced Motion)
}

-- Rehoming (D-059, stage 7): at the Market Corral a horse joins Sunny Meadow Riding School. The
-- school pays share of what you paid for it, never more (tamed and gifted horses: 0 and a goodbye
-- rosette); undo for undoHours at the same price. The starter, your last racing horse, a Legend
-- and a horse that's busy can't go. No trading between players.
GameConfig.rehome = {
	enabled = true,
	share = 0.5,
	undoHours = 72,
	maxWaiting = 10,                 -- horses waiting at the school for an undo (then it's full until one settles in or comes back)
	school = "Sunny Meadow Riding School",
}

-- Ageing (fun-and-return 2026-10-12; David asked for horses that age; numbers provisional). Counted
-- races only, never Practice. Young: training × youngTrainMult for the first youngRaces races. Veteran
-- at veteranAt (= career.veteranAt, a test checks). Decline counts from h.ageing.declineFrom, stored
-- once when the horse first has veteranAt races and stats at peakShare of Potential (never un-set):
-- −declineScale Race Rating per declinePer races, at most declineCap steps; rated races only, never
-- League Points, ceilings or stats.
-- Warned warnAhead races before each step. declineScale 0 = stages only. Mirrors src/life_arc.py
-- (Ageing.luau; tests/test_life_arc.py checks these values).
GameConfig.ageing = {
	veteranAt = 350,
	declinePer = 50,
	declineCap = 4,
	declineScale = 1,                -- 1 = real decline (sims/lifearc.py --ageing, provisional); 0 = stages only
	youngRaces = 30,
	youngTrainMult = 1.25,
	warnAhead = 10,
	peakShare = 0.90,                -- decline waits for stats at this share of Potential (h.ageing.declineFrom)
}

-- Selling at the Riding School (fun-and-return 2026-10-12): rehome.share of the price paid plus
-- min(perWin × wins + perCup × Cups, recordBonusCap). recordBonusCap from `python sims/lifearc.py
-- --sell` (no buy-race-sell loop). Mirrors src/life_arc.py SELL.
GameConfig.sell = {
	perWin = 5,
	perCup = 100,
	recordBonusCap = 100,            -- < half the cheapest Market horse (250): a sale never pays more than the price
}

-- Lending to the Riding School (fun-and-return phase 4, D-078): free, take back any time. A lent horse
-- stays yours (never deleted) but leaves your racing roster: no stall, no races, shown at the school
-- by the Market Corral (at most shownMax horses from this server stand there).
GameConfig.lend = { enabled = true, shownMax = 6 }

-- Breeding (D-080 provisional, amends D-047; docs/reviews/breeding-2026-10-12/plan.md). Two of your own
-- horses (Prime, Veteran or Legend: minParentRaces counted races; one at needLeague or higher) make a
-- foal for fee[higher parent league] Green Cash (never Diamonds). Foal Potential per stat =
-- clamp(round(parentShare x parents' average + (1 - parentShare) x breedAnchor + U(-noise, noise)) + legacy,
-- potMin, potMax), legacy = career.legacyMax on each Legend parent's best stat. Start stats =
-- min(round(startShare x Potential), startMax). Coat: each parent's coat coatParentEach, a named Surprise
-- coatSurprise from the `surprise` families (a pair with no family splits it back to the parents).
-- The foal is rolled once at confirm and stored. One foal per foalEveryRaces owner races, stable-wide,
-- counted from confirm ("Next foal in N races"); the foal
-- arrives after foalAfterRaces owner races or the next UTC day you play. stableCap = Market.MAX_HORSES.
-- Mirrors src/breeding.py (tests/test_breeding.py, tests/fixtures/breeding.json). enabled = false
-- hides it all (the Foal Barn, its Map tile, the Family page); keep career.suggest the same.
GameConfig.breeding = {
	enabled = true,                  -- on with career.suggest (BreedingService, D-080)
	minParentRaces = 30,
	needLeague = "Bronze",
	foalEveryRaces = 60,             -- one foal per 60 owner races, stable-wide, from confirm (systems ruling 1)
	maxWaiting = 1,
	foalAfterRaces = 8,
	foalAfterNewDay = true,
	fee = { Bronze = 400, Silver = 800, Gold = 1500, Champion = 2500 },
	parentShare = 0.75,              -- systems ruling 3 (was 0.7)
	breedAnchor = 80.5,              -- systems ruling 3 said 80 (was 75); 80.5 keeps a pure top-tier line >= 83 (sims/breeding.py, flagged)
	noise = 5,
	potMin = 55,
	potMax = 100,
	startShare = 0.60,
	startMax = 50,                   -- gameplay vote: a 90-Potential foal still plays Rookie
	coatParentEach = 0.45,
	coatSurprise = 0.10,
	youngScaleFrom = 0.80,
	stableCap = 20,
	bond = 10,
	familyLevels = { 76, 84 },       -- Market.stars: expected mean Potential for 2 and 3 sprouts
	surprise = {
		bay = { "buckskin", "dun" }, chestnut = { "buckskin", "dun" }, black = { "buckskin", "dun" },
		chestnut_blaze = { "buckskin", "dun" }, grey = { "white", "roan" }, palomino = { "buckskin" },
		pinto = { "appaloosa" }, appaloosa = { "pinto" },
		buckskin = { "dun", "palomino" }, dun = { "buckskin" }, roan = { "grey" }, white = { "grey" },
	},
}

-- Legs and the vet (fun-and-return phase 3, D-077; David's decision: over-running can need the vet).
-- Counted races in a row on one horse (Practice never counts). warnAt: the "🧣 Worked hard! Cool-down soon" chip;
-- runLimit: RACE! becomes 🩺 VET CHECK for rated races (Practice stays open) and the server turns rated
-- joins away. Feed or groom: -careLowers, once per kind per horse per careCooldownSeconds
-- (= energy.careCooldownSeconds). restSeconds without a counted race on that horse, the Spa, a training
-- session or the Cool-down Check reset it. The run only grows after the horse's first fromRaces counted
-- races. Never Rating, bond, Energy or cash. Mirrors src/life_arc.py LEGS (tests/test_life_arc.py).
-- enabled = false: no run, no chip, no VET CHECK.
GameConfig.legs = {
	enabled = true,
	runLimit = 6,
	warnAt = 5,
	careLowers = 2,
	restSeconds = 1800,
	fromRaces = 26,
	careCooldownSeconds = 7200,
	wrapRaces = 3,                   -- the Cool-down Check's wraps show on the horse for this many races
}
-- The Cool-down Check at the Vet (D-077, the feel lead's B1): about 30 s in 4 tap steps (check each leg,
-- cold hose hoseTaps per leg, soft wraps in a colour, a carrot). Free: no Green Cash, no Diamonds, no
-- timer. The server takes it only minSeconds (less lagAllowance) after it started, at the Vet, not racing.
-- wraps: the four wrap colours (hex). Sky-blue UI.
GameConfig.vetCheck = { enabled = true, minSeconds = 12, lagAllowance = 1.5, hoseTaps = 3,
	wraps = { "FF7EB6", "5BC0EB", "FFD23F", "7ED957" }, wrapNames = { "Pink", "Blue", "Gold", "Green" } }

-- Studio test block (playtest 2026-10-12, game/TONIGHT.md): sets the active horse's long-horizon state on
-- join so ageing, the legs run, the class path and the Cup bar can be seen without hundreds of races.
-- Applied by Profiles on profile load ONLY when RunService:IsStudio() is true (StudioTest.luau); a live
-- server never applies it. It writes the save, so set everything back to off after testing.
-- Off by default: 0 / false. horseRaces: counted races; horseWins: wins (also in its own league);
-- nearPotential: stats to ageing.peakShare of Potential; legsRun: the legs run; leaguePoints: points;
-- legsFromRaces: a number overrides legs.fromRaces on this server (e.g. 0), false keeps it.
GameConfig.studioTest = {
	horseRaces = 0,
	horseWins = 0,
	nearPotential = false,
	legsRun = 0,
	leaguePoints = 0,
	legsFromRaces = false :: number | boolean,
	-- (D-080) breedReady: two eligible parents (the active horse and a second one, added if needed, at
	-- breeding.minParentRaces races, one in breeding.needLeague), the Bronze fee in hand, no wait, and a
	-- foal already on the way arrives at once. Off by default.
	breedReady = false,
}

-- How a horse looks (D-077, D-078), built in code (0 Meshy): the Cool-down Check's leg wraps, and the
-- Veteran look, a frosted muzzle and brows plus a silver-and-blue bridle rosette (gold on a Legend).
-- The model faces -Z; positions are fractions of its bounding box (x across, y up from the ground, z
-- along, - = front), tuned in Studio. veteranLook = false: no frost or rosette. wrapsInRace = false:
-- wraps only in the stall and on rides (if race legs don't carry them).
GameConfig.horseLook = { veteranLook = true, wrapsInRace = true, legendRosette = true,
	frost = "E9ECEF", frostTransparency = 0.25, silver = "C0C7D4", blue = "2F6FDE", gold = "FFD23F",
	muzzle = { x = 0, y = 0.70, z = -0.48, size = 0.11 }, brow = { x = 0.07, y = 0.86, z = -0.40, size = 0.05 },
	rosette = { x = -0.09, y = 0.95, z = -0.36, size = 0.07 }, wrap = { from = 0.08, to = 0.38, grow = 1.18 } }

-- A bred foal's look and life (D-080, the feel vote F2 and F7; 0 Meshy). Out of races the rig is scaled
-- unevenly: body and head x body, legs x legY tall, both growing to 1 by growRaces counted races
-- (smoothstep). In races a foal is one uniform scale, never under raceMinScale. For its first
-- tagAlongRaces races it tags along behind its parent (followStuds behind, sideStuds aside, at most
-- the parent's speed + catchUp studs/s) and hops (hopStuds high) every hopEvery seconds, with the
-- young nicker on at most 1 hop in nickerEvery. Client only, never in a race or a training ride.
GameConfig.foalLook = { enabled = true, body = 0.70, legY = 0.92, growRaces = 30, raceMinScale = 0.94,
	tagAlongRaces = 10, followStuds = 6, sideStuds = 2, catchUp = 4, hopStuds = 0.6, hopEvery = { 8, 14 }, nickerEvery = 3,
	nickerSpeed = 1.45, parentSpeed = 0.9 }

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
-- A hop's forward push stays under the training ride's speed check (D-074).
GameConfig.riding.hop.forwardCap = GameConfig.training.maxSpeed - 2

-- Prize ribbons for the UI (D-016). Never use racing-wager terms in UI text. -- policy-ok
GameConfig.ribbons = { "Blue", "Red", "Yellow", "White" }

GameConfig.scoreLabels = {
	{ min = 95, label = "Perfect" },
	{ min = 80, label = "Great" },
	{ min = 60, label = "Good" },
	{ min = 30, label = "Okay" },
	{ min = 0, label = "Miss" },
}

-- B (D-070, provisional): flattened from 20/50/120/300/750 so Barn Builder stays in reach (sims/economy.py --greencash).
GameConfig.leagues = {
	Rookie = { name = "Rookie", T = 22, B = 20, sweepSeconds = 2.4, windowSeconds = 4.0, targetDrift = 0, twoTargetFinal = false,
		distances = { "Sprint", "Mile" }, -- shorter races for new players (D-027)
		strideIntervalLo = 0.60, strideIntervalHi = 0.60, strideDrift = 0, leadChange = false },
	Bronze = { name = "Bronze", T = 18, B = 30, sweepSeconds = 2.0, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		distances = { "Sprint", "Mile", "Classic" }, -- Bronze adds the Classic; Silver and up run every distance (D-046)
		strideIntervalLo = 0.55, strideIntervalHi = 0.60, strideDrift = 0.02, leadChange = false },
	Silver = { name = "Silver", T = 18, B = 45, sweepSeconds = 1.6, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		strideIntervalLo = 0.50, strideIntervalHi = 0.56, strideDrift = 0.03, leadChange = false },
	Gold = { name = "Gold", T = 14.4, B = 65, sweepSeconds = 1.3, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = false,
		strideIntervalLo = 0.46, strideIntervalHi = 0.52, strideDrift = 0.03, leadChange = false },
	Champion = { name = "Champion", T = 12, B = 85, sweepSeconds = 1.1, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = true,
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

-- AAA Phase 4, Dev A (D-069): world and jockey. All drawn only: nothing here reads or changes a score,
-- the order, the trip or a purse.
-- Jockey crouch-and-pump (client/JockeyPose): degrees in the plan's convention (+ = flex forward for the
-- waist, shoulders and elbows; hips -70 lift the thigh forward; knees +100 fold the shin back; neck -15
-- lifts the head). pelvisDeg tips the hips forward too, so the back sits under 45 degrees from
-- horizontal (90 - pelvis - waist). The pump (once a stride, on the lead forefoot's landing, the same
-- beat as the hoof dust): waist +-pumpDeg, shoulders +-shoulderPumpDeg, a rise of riseStuds between
-- landings. seatDropStuds: tune in Studio if feet sink into the horse. R6 rigs keep the sit.
GameConfig.jockeyPose = { enabled = true, waistDeg = 35, pelvisDeg = 15, hipDeg = -70, kneeDeg = 100, shoulderDeg = 55,
	elbowDeg = 70, neckDeg = -15, pumpDeg = 4, shoulderPumpDeg = 10, riseStuds = 0.12, seatDropStuds = 0, refreshHz = 4 }
-- County Fair dressing (server/TrackDressing, built once with the venue). Budget: maxParts new parts and
-- maxBeams Beams. The rail bunting stands railPostOffset studs outside the outer rail, behind the replay
-- and finish-orbit side camera (outer rail + 12), so it never crosses that shot. Crowd tiles are 16 x 6
-- studs: one row of fans per 6-stud stand riser. buntingFlip swaps the Beams' ends if the pennants read
-- upside down in Studio.
GameConfig.trackDressing = { enabled = true, bunting = true, flags = true, crowd = true, maxParts = 350, maxBeams = 80,
	roofSpacing = 40, railSpacing = 40, railPostStuds = 8, railPostOffset = 14.5, railFromFeet = 660, railPastFeet = 200,
	flagSpacing = 80, flagClearOfSpires = 50, buntingWidth = 2.5, buntingTileStuds = 10, sag = 1.5, buntingFlip = false,
	crowdTileU = 16, crowdTileV = 6 }
-- Track life (client/TrackLife): the crowd bounces (calm in the lobby; cheering from the burst, or once
-- the leader passes cheerFromProgress, until the card shows) and the flags flutter. Both stop under
-- Reduced Motion, and only tick while you're within spectate.keepStuds of a course (phoneHz on phones).
GameConfig.trackLife = { enabled = true, crowdBounce = true, calmStuds = 0.12, calmHz = 1.5, cheerStuds = 0.3, cheerHz = 3,
	cheerFromProgress = 0.8, flagFlutter = true, flutterDeg = 6, flutterHz = 0.8, updateHz = 30, phoneHz = 15 }
-- The Big Board shows the followed race's top 4 (lane chip, number, horse name), refreshed at refreshHz;
-- "GIDDY-UP!" when no race runs. Never a win %, purse or any number but places and lanes (rule 1, D-055).
GameConfig.bigBoard = { live = true, rows = 4, refreshHz = 4 }
-- Practice with a friend (AAA Phase 3 should-fix): a small friends mark under a friend's lane badge,
-- on the riders' screens only.
GameConfig.friendRace = { badge = true }

-- AAA Phase 4, Dev B (D-069): HUD, camera, music and finish polish. Drawn and heard only: nothing here
-- reads or changes a score, the order, the trip or a purse (RacePresent holds the timing and levels).
-- The gate line-up (client/GateIntro): in the countdown, never in the lobby wait (D-061), and the
-- countdown stays at gateCountdownSeconds. As you're seated the camera dollies in front of the gate
-- from the outside lane to lane 1 at heightStuds, frontStuds out, looking at the horses' faces, over
-- dollySeconds (eased); then handOff "cut" (default, the feel consult): a cutFadeSeconds Paper fade to the
-- chase shot; "blend" (the switch-back) glides behind your horse over blendSeconds. The Follow camera is
-- back by handBackBefore seconds before GO. Riders only, never spectators, never under Reduced Motion; a seat
-- later than lateSeatSeconds into the countdown goes straight to the chase view.
GameConfig.gateIntro = { enabled = true, dollySeconds = 1.6, blendSeconds = 0.4, handBackBefore = 1.0, lateSeatSeconds = 0.3,
	handOff = "cut", cutFadeSeconds = 0.12, heightStuds = 7, frontStuds = 16, chaseBackStuds = 14, chaseUpStuds = 5 }
-- The race HUD in the art direction's colours (client/RaceHudStyle): Paper panels with an Ink outline,
-- Fredoka One labels, Builder Sans Bold numbers, the Gold count with an Ink outline, the slider on Slate
-- with a Gold glow. enabled = false keeps the colours the code builds (Paper panels either way).
-- youMarker: riderShown = false (the UI/UX consult) hides it in your own chase view and the gate pass (the
-- place badge says where you are); true shows it small and low there (riderStuds, riderPx x riderPxTall).
-- Hidden in first person (camera zoom under firstPersonZoom) and during the finish orbit; replays and
-- spectators keep the big one.
GameConfig.raceHud = { enabled = true,
	youMarker = { riderShown = false, riderStuds = 7, riderPx = 56, riderPxTall = 72, otherStuds = 12, otherPx = 90, otherPxTall = 120, firstPersonZoom = 2 } }
-- Audio. music (client/MusicBed): one beatless bed from Roblox's licensed music library (no upload; the
-- last audio upload this window is kept for an emergency). id = 0: no music at all (David picks the
-- track). Levels: lobby, race (your slider runs: far under the tap tick), spectate (watching a race),
-- finish (the finish moment and the card); duckUnderVoice while an announcer line plays; fades over
-- fadeSeconds. The Sound setting mutes it with everything else. If the chosen track has a steady beat, set
-- race = 0 (kids must tap to the marker, never to a beat; CONSENSUS).
GameConfig.audio = {
	music = { id = 0, lobby = 0.35, race = 0.12, spectate = 0.08, finish = 0.4, fadeSeconds = 0.6, duckUnderVoice = 0.5 },
}

-- Core-playtest switch (AAA Phase 3, D-068): true turns the meta off so the core race loop can be
-- playtested alone: the Spa, friends' barn visits, careers (badges and Legends), rehoming, the
-- Photo Finish camera and the Horse Book. It works only through each feature's own flag, applied
-- once here when this module loads, so every feature still checks one place. false (the default)
-- changes nothing. See game/PLAYTEST.md.
GameConfig.corePlaytest = false
GameConfig.CORE_PLAYTEST_OFF = {
	{ "spa", "enabled" }, { "visit", "enabled" }, { "career", "enabled" }, { "rehome", "enabled" },
	{ "comeback", "photo" }, { "comeback", "horseBook" },
}
-- Returns the flags it switched off ("spa.enabled", ...), or none when corePlaytest is false.
function GameConfig.applyCorePlaytest(cfg: any): { string }
	local off = {}
	if not cfg.corePlaytest then return off end
	for _, path in GameConfig.CORE_PLAYTEST_OFF do
		local t = cfg[path[1]]
		if type(t) == "table" then
			t[path[2]] = false
			table.insert(off, path[1] .. "." .. path[2])
		end
	end
	return off
end
GameConfig.applyCorePlaytest(GameConfig)

return GameConfig
