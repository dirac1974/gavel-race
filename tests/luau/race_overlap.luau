--!strict
-- Runs one race the way RaceService runs it (10 Hz server: checkpoints, the trip to the far-turn
-- lock, tau, the race shape's offsets and make-room lanes after it, the send rates) and draws it
-- the way RaceView does with steering on (60 fps; with the eased glide the timestamped samples'
-- offsets and lanes played back by their server times, Playback, D-057 N3; with D-054's linear
-- glide, the switch-back, as D-054 drew them: offsets interpolated from each sample's arrival over
-- one send interval, lanes gliding at most frame/laneSeconds), and counts horses overlapping on screen:
-- closer than half a lane sideways and 6 ft lengthwise (a horse is 8 ft long). Used by
-- trip_tests.luau, trip_d057_tests.luau, steer_controls_tests.luau and
-- tests/luau/overlap_report.luau (D-054 S2, S3; D-057 N2, N3).
-- The config is GameConfig's (D-057 in full since N5) unless `config` is given, or opts.d057
-- (D-057 in full from Trip.d057Config, the same since N5) or opts.d054 (the switch-back:
-- Trip.d054Config).
-- opts (all optional):
--   riders = how many lanes are riders pressing ◀ ▶ at random (S3; the presses go through
--     Trip.submit like RaceService's SteerRequest); manual = those riders have Smart Steer off.
--   predict = rider 1 presses from its own screen instead: singles, doubles, mashes and In-then-Out
--     pairs, sent with `latency` (default 0.1 s each way, which then delays every message), its own
--     horse drawn by SteerPredict as RaceView draws it, from SteerLane messages (tgt, destination,
--     last press answered, sent on change as RaceService does). Counts overlaps on that screen and
--     how long its own horse is drawn somewhere else than everyone else sees it.
--   With the eased glide (D-057; the game's config since N3), riders ride in `styles` (default
--     masher, ditherer, casual: 4 presses a second on a random side; In, Out, In, Out every 0.2 s;
--     In about every 5 s and Out about every 20 s). With predict, rider 1 ("own") presses from its
--     screen, where a press shows the look cue (SteerPredict.look) and its horse is drawn where
--     everyone sees it, and three styled riders follow. With D-054's linear glide, riders press at
--     random and rider 1's own glide is predicted as before.
--   Counts (any config): each rider's reversals and the shortest gap between them, the drawn
--     sideways acceleration (every horse, before and after the lock), brushes, how long riders are
--     boxed in, and the moves after the lock (every horse): late full-lane moves (in the last 2 s),
--     late half-lane steps, and reversals after the lock with the gap to the one before.
--   jitter = extra random delay on each message to the client, 0..jitter s (in order, as
--     RemoteEvents arrive), from its own generator. The playback absorbs it.
--   Two finish checks: the order of the drawn offsets at the last frame (orderOk), and the order in
--   which the horses cross the line on the drawn screen (crossOrderOk: each horse's drawn feet,
--   RaceView's pace plus its drawn offset, reaching the race length; the screen keeps drawing until
--   every horse has crossed).
--   ownStyle = "masher" (with predict): rider 1 mashes ◀ ▶ at random, 4 presses a second, instead
--     of the press patterns. With the eased glide rider 1's horse is posed as RaceView poses it
--     (SteerPose with the look cue), and the report counts how often the look cue swings the body
--     from one side to the other, and how far the body ever turns beyond its drift.
--   (D-071) taps = one pace-tap profile per rider ("perfect", "average", "fixed60", "switch",
--     "masher", "streaky"): the slider's passes are scheduled as RaceService does (before the
--     posts), riders tap from their own generator, their checkpoints are scored at each close
--     (the Final Burst by profile), the shown chances refresh after the lock as RaceService does
--     (PacePreview.afterLock, the stretch drive) and also once at the lock, and every rider's own
--     screen draws its 5 ft tap nudge (RaceFx) on top of the received offsets. tapPreview = the
--     draw-only preview layer (TapPreview) on the sent offsets. stats.tp has its numbers.
--     league (default "Silver"), equal (equal Ratings), switchAt (default 15 s: "switch" taps a
--     steady 60 until then, then every pass Perfect), digest (stats.digest: Trip's state every tick,
--     tau, live at each close, the order, the prizes and the sent lanes, as JSON), permuteLuck = a
--     seed: the secret luck shuffled after the gate (stats.tp.drawnBeforeLock records the drawn
--     offsets up to the lock).
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local ThemePack = require("../../game/src/shared/ThemePack")
local BurstMeter = require("../../game/src/shared/BurstMeter")
local PaceMeter = require("../../game/src/shared/PaceMeter")
local RaceShape = require("../../game/src/shared/RaceShape")
local RaceSession = require("../../game/src/shared/RaceSession")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local TripBaseline = require("../../game/src/shared/TripBaseline")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local baselineD054: any = nil -- the D-054 table (the switch-back regenerates TripBaseline to it), loaded once
local SteerPredict = require("../../game/src/shared/SteerPredict")
local SteerPose = require("../../game/src/shared/SteerPose")
local Playback = require("../../game/src/shared/Playback")
local TapPreview = require("../../game/src/shared/TapPreview")
local PacePreview = require("../../game/src/shared/PacePreview")
local RaceFx = require("../../game/src/shared/RaceFx")

local SIDE, LENGTH = 0.5, 6 -- overlap: closer than this sideways (lanes) and lengthwise (feet)
local FRAME = 1 / 60
local APART = 0.05          -- your own horse drawn this far (lanes) from the shared view counts as apart
local JERK = 20             -- a horse drawn falling back faster than this (ft/s, against the pace) jerks

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

-- own (predict only): overlaps = frames your own screen shows your horse overlapping another
-- (before the lock / after it), apartMax = the longest stretch (s) your horse is drawn apart from
-- where everyone sees it (back-to-back presses chain these: each glide leads the shared view by a
-- round trip), apartAtLock = how far apart it is drawn 1 s after the lock, timeouts = predictions
-- ended by SteerPredict's timer (none should: the server answers every press), longestPrediction =
-- the longest a single prediction was drawn (s), presses / predicted = presses sent / presses that
-- started a glide at once.
export type Own = { overlapsBefore: number, overlapsAfter: number, apartMax: number, apartAtLock: number,
	timeouts: number, longestPrediction: number, presses: number, predicted: number, looks: number, lookMax: number,
	cueFlips: number, cueSeconds: number, cueExcess: number }
export type Stats = { before: number, first5: number, after: number, lastTwo: number, frames: number, orderOk: boolean,
	lineOrder: { number }, result: { number }, answers: { [string]: number }, halfSteps: number,
	backBefore: number, backAfter: number, jerks: number, jerksBefore: number, own: Own?,
	reversals: { [string]: { count: number, seconds: number, minGap: number } }, accelBefore: number, accelAfter: number,
	brushes: number, boxedTicks: number, riderTicks: number, afterMoves: number, lateMoves: number, lateHalfSteps: number,
	afterReversals: number, afterReversalsWithin: number, afterMinGap: number, crossOrderOk: boolean, crossOrder: { number },
	brushStyles: { [string]: { riders: number, brushRaces: number, chargedRaces: number, brushes: number } }, strangerCharged: number,
	tp: any?, digest: string? }

-- (D-071) A rider's pace taps by profile, one generator for all riders (the race's draws unchanged).
local function profileTaps(profile: string, passes: { any }, tapRng: any, switchAt: number): { number }
	local taps = {}
	local function at(p: any, dpos: number)
		local ideal = PaceMeter.idealTime(p)
		local off = dpos * (p.t1 - p.t0) / 2
		local t = ideal + off
		if t >= p.t1 - 1e-3 then t = ideal - off end
		table.insert(taps, math.clamp(t, p.t0 + 1e-3, p.t1 - 1e-3))
	end
	for k, p in passes do
		if profile == "perfect" then
			at(p, 0.03 * tapRng:NextNumber())
		elseif profile == "average" then
			at(p, 0.2 + 0.4 * tapRng:NextNumber())
		elseif profile == "fixed60" then
			at(p, 0.4)
		elseif profile == "switch" then
			at(p, if p.t0 >= switchAt then 0 else 0.4)
		elseif profile == "streaky" then
			if math.floor((k - 1) / 5) % 2 == 0 then at(p, 0.03 * tapRng:NextNumber()) end
		elseif profile == "masher" then -- 4 taps a second at random through the pass
			local t = p.t0 - math.log(1 - tapRng:NextNumber()) / 4
			while t < p.t1 do
				table.insert(taps, t)
				t += -math.log(1 - tapRng:NextNumber()) / 4
			end
		end
	end
	table.sort(taps)
	return taps
end
local BURST_BY_PROFILE = { perfect = 92, average = 65, fixed60 = 60, switch = 92, masher = 15, streaky = 70 }
local RISE_N, FALL_N = GameConfig.raceView.nudgeRiseSeconds, GameConfig.raceView.nudgeFallSeconds
local NUDGE_PEAK = FALL_N / (RISE_N + FALL_N) * (RISE_N / (RISE_N + FALL_N)) ^ (RISE_N / FALL_N)
local function nudgeFeet(age: number): number -- RaceView's tap nudge curve
	if age < 0 or age > 6 * FALL_N then return 0 end
	return GameConfig.tapNudgeFeet * (1 - math.exp(-age / RISE_N)) * math.exp(-age / FALL_N) / NUDGE_PEAK
end

return function(courseId: string, distanceName: string, seed: number, config: any?, opts: any?): Stats
	local d057 = opts ~= nil and opts.d057 == true
	local d054 = opts ~= nil and opts.d054 == true
	local cfgGame = config or GameConfig
	if config == nil and (d057 or d054) then
		cfgGame = table.clone(GameConfig)
		cfgGame.steering = if d057 then Trip.d057Config(GameConfig.steering) else Trip.d054Config(GameConfig.steering)
	end
	local steer = cfgGame.steering
	local eased = steer.glide == "eased"
	local track = TrackLayout.courses[courseId]
	local plan = TrackLayout.plan(track, TrackLayout.distances[distanceName])
	local rng = makeRng(seed)
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local predict = opts ~= nil and opts.predict == true
	local latency = if opts and opts.latency then opts.latency elseif predict then 0.1 else 0
	local jitter = (opts and opts.jitter) or 0
	local jitterRng = makeRng(seed * 17 + 5)
	local function arrival(T: number): number -- when a message sent at T reaches the client
		if jitter > 0 then return T + latency + jitter * jitterRng:NextNumber() end
		return T + latency
	end
	local humans, riders = {}, {}
	local styles = (opts and opts.styles)
		or (if eased and predict then { "own", "masher", "ditherer", "casual" } elseif eased then { "masher", "ditherer", "casual" } else {})
	local style = {}
	for r = 1, (opts and opts.riders) or (if opts and opts.taps then #opts.taps else #styles) do
		table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
		riders["rider" .. r] = if opts and opts.manual then "manual" else "smart"
		style["rider" .. r] = styles[r] or (if opts and opts.taps then "casual" else "random")
	end
	local tapProfiles: { string }? = opts and opts.taps
	if tapProfiles then
		for r = #humans + 1, #(tapProfiles :: { string }) do -- one rider per tap profile
			table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
			riders["rider" .. r] = if opts and opts.manual then "manual" else "smart"
			style["rider" .. r] = styles[r] or "casual"
		end
	end
	local leagueName = (opts and opts.league) or "Silver"
	if opts and opts.riderRating then -- (D-071) e.g. a league's anchor: a rider on an equal horse
		for _, h in humans do h.rating = opts.riderRating end
	end
	-- (D-071) botAnchor: bots rated the league's anchor ± botRatingSpread, as RaceService fills them
	local lanes = RaceSession.fillWithBots(humans, cfgGame.lanes, cfgGame, ThemePack, rng,
		if opts and opts.botAnchor then { league = (opts and opts.league) or "Silver" } else nil)
	if opts and opts.equal then RaceSession.equalizeRatings(lanes) end
	local session = RaceSession.new({ deps = deps, config = cfgGame, leagueName = leagueName, lanes = lanes, rng = rng })
	local league = cfgGame.leagues[leagueName]
	if opts and opts.permuteLuck then -- (D-071) a different secret luck, every other draw the same
		local prng = makeRng(opts.permuteLuck)
		for i = #session.luck, 2, -1 do
			local j = 1 + math.floor(prng:NextNumber() * i)
			session.luck[i], session.luck[j] = session.luck[j], session.luck[i]
		end
	end
	-- RaceService's timeline (race time: 0 at the gate).
	local speed = cfgGame.raceSpeedStudsPerSecond
	local tFinish = plan.lengths[1] / speed
	local tTop = tFinish - track.finishFromTop / speed
	local burstOpen = tTop + cfgGame.burstAfterTurnSeconds
	local burstClose = burstOpen + league.windowSeconds
	local preEnd = burstOpen - cfgGame.burstLeadSeconds
	local postEnd = tFinish - cfgGame.finishMarginSeconds
	local mid = preEnd / 2
	local tFar = tFinish - (track.finishFromTop + math.pi * TrackLayout.laneRadius(track, 1)) / speed
	local closes = { mid + 0.35, preEnd + 0.35, burstClose + 0.35, postEnd + 0.35 }
	local postStart = burstClose + cfgGame.stretchGapSeconds
	if tapProfiles then -- RaceService's schedule, before the posts
		local longestPass = league.sweepSeconds / 2 * (1 + cfgGame.pace.speedDrift)
		session:paceSchedule({ { 0, preEnd - longestPass }, { postStart, postEnd - postStart - longestPass } },
			{ { 0, mid }, { mid, preEnd }, { postStart, postEnd } })
	end
	session:assignPosts(RaceSession.postOrder(cfgGame, #session.lanes, rng))
	local baseline = TripBaseline
	if d054 then -- the switch-back's own baseline (tests/fixtures/trip_baseline_d054.json)
		baselineD054 = baselineD054 or serde.decode("json", fs.readFile("tests/fixtures/trip_baseline_d054.json")).baseline
		baseline = baselineD054
	end
	local trip = Trip.start(cfgGame, session, track, plan, baseline[courseId][distanceName], rng, TrackLayout, riders)
	assert(trip, "steering is on")
	-- (D-071) Pace taps, the preview layer and its numbers.
	local tapsOf: { [string]: { number } }, goodOf: { [string]: { number } }, profileOf: { [string]: string } = {}, {}, {}
	local tp: any = nil
	local tpStats: any = nil
	local digest: any = nil
	if tapProfiles then
		local tapRng = makeRng(seed * 53 + 11)
		local switchAt = (opts and opts.switchAt) or 15
		for r, profile in tapProfiles :: { string } do
			local id = "rider" .. r
			profileOf[id] = profile
			tapsOf[id] = profileTaps(profile, session.passes, tapRng, switchAt)
			local good = {} -- Great or Perfect taps (one counted tap in a pass): the own-screen nudge
			local counted = PaceMeter.debounce(tapsOf[id], cfgGame.pace.bounceSeconds)
			for _, t in counted do
				local kk = PaceMeter.passIndex(session.passes, t)
				if kk then
					local p = session.passes[kk]
					local count = 0
					for _, u in counted do if u >= p.t0 and u < p.t1 then count += 1 end end
					if count == 1 and PaceMeter.tapScore(p, t) >= 80 then table.insert(good, t) end
				end
			end
			goodOf[id] = good
		end
		if opts and opts.tapPreview then
			tp = TapPreview.new(#session.lanes, cfgGame.tapPreview, trip.lead, steer.gapRampSeconds, steer.laneBand)
			for i, l in session.lanes do TapPreview.setRider(tp, i, not l.isBot) end
		end
		tpStats = { residualMax = 0, residualSpeedMax = 0, residualAccelMax = 0, drawnBackMax = 0,
			lockResidualSeconds = 0, extraDrop = {}, firstDrawn = 0, firstDrawnPlace = 0, gainMax = {}, gainMin = {},
			messages = {}, messageLoss = 0, ownOverlaps = 0, ownJerks = 0, series = {}, hardClamps = 0,
			drawnBeforeLock = {}, residualAtLock = 0, profiles = profileOf, freeSpeedMax = 0, freeAccelMax = 0,
			messageGapMin = math.huge, taps = tapsOf, laneOf = {}, cues = {}, messageKeys = {}, pullBackSpeed = 0 }
		if opts and opts.digest then digest = { ticks = {}, closes = {} } end
	end
	-- Riders' provisional scores over the open checkpoint's finished passes, the passes, and each
	-- rider's share of them tapped exactly once (RaceService computes the same at a pass end).
	local function partialFor(seg: number, T: number): ({ [number]: number }, number, { [number]: number })
		local done = {}
		for _, p in session:pacePasses(seg) do
			if p.t1 <= T + 1e-9 then table.insert(done, p) end
		end
		local partial, clean = {}, {}
		if #done == 0 then return partial, 0, clean end
		for i, l in session.lanes do
			if not l.isBot then
				local score, _, single = PaceMeter.score(done, tapsOf[l.id] or {}, cfgGame.pace.bounceSeconds)
				partial[i], clean[i] = score, single / #done
			end
		end
		return partial, #done, clean
	end
	local passEnds = 0 -- passes whose end has been seen
	local nextShownPreview = math.huge
	local lastE, lastU = table.create(#session.lanes, 0), table.create(#session.lanes, 0)
	local lastRoomed, lastRoomed2 = table.create(#session.lanes, false), table.create(#session.lanes, false)
	local lastDrawn: { number }? = nil
	local events = {} -- pull-back windows: { at, kind, drawn0, base0, extra, roomed }
	local lockSettled = false
	local cueScratch = {}
	-- Each rider's own screen: its tap nudge (RaceView) drawn on the received offsets.
	local nudges = {}
	if tapProfiles then
		for _, h in humans do
			nudges[h.id] = { lane = session:laneIndex(h.id) :: number, drawn = 0, last = -math.huge, prev = -math.huge, ptr = 1 }
		end
	end
	-- Riders press at random, 0.4 to 2 s apart, more often in than out (their own generator, so the
	-- race's draws are unchanged). With predict, rider 1 presses from its screen instead.
	local pressRng = makeRng(seed * 31 + 7)
	local nextPress, seqs = {}, {}
	for _, h in humans do
		nextPress[h.id] = pressRng:NextNumber() * 2
		seqs[h.id] = 0
	end
	local n = #session.lanes
	local shownLive = table.clone(session.live)
	-- Client state (what every screen shows).
	local offset = table.create(n, 0)
	local lane, laneTarget = table.create(n, 0), table.create(n, 0) -- as drawn; the newest sample's
	for i = 1, n do lane[i], laneTarget[i] = i, i end
	local pb = Playback.new(Playback.config(cfgGame)) -- (eased) RaceView's playback of the timestamped samples
	local play: number? = nil
	-- (linear, D-054) the offsets glide from where they are to the newest sample, timed from its
	-- arrival; sampleT = the server tick that made it.
	local from, to = table.create(n, 0), table.create(n, 0)
	local sampleAt, sampleT = 0, 0
	local stats: Stats = { before = 0, first5 = 0, after = 0, lastTwo = 0, frames = 0, orderOk = true, lineOrder = {}, result = {},
		answers = trip.answers, halfSteps = 0, backBefore = 0, backAfter = 0, jerks = 0, jerksBefore = 0, own = nil,
		reversals = {}, accelBefore = 0, accelAfter = 0, brushes = 0, boxedTicks = 0, riderTicks = 0,
		afterMoves = 0, lateMoves = 0, lateHalfSteps = 0, afterReversals = 0, afterReversalsWithin = 0, afterMinGap = math.huge,
		crossOrderOk = true, crossOrder = {}, brushStyles = {}, strangerCharged = 0 }
	-- Each horse's crossing on the drawn screen: RaceView's pace (a quick ease out of the gate, then a
	-- steady gallop reaching the race length at tFinish) plus its drawn offset.
	local len1 = plan.lengths[1]
	local gateTau = cfgGame.raceView.gateEaseSeconds
	local paceV = len1 / (tFinish - gateTau * (1 - math.exp(-tFinish / gateTau)))
	local function paceFeet(t: number): number
		if t <= 0 then return 0 end
		return paceV * (t - gateTau * (1 - math.exp(-t / gateTau)))
	end
	local crossAt, lastFeet = table.create(n, math.huge), table.create(n, -math.huge)
	local function watchLine(t: number)
		local base = paceFeet(t)
		for i = 1, n do
			local feet = base + offset[i]
			if crossAt[i] == math.huge and feet >= len1 and lastFeet[i] > -math.huge then
				crossAt[i] = t - FRAME * (feet - len1) / math.max(feet - lastFeet[i], 1e-9)
			end
			lastFeet[i] = feet
		end
	end
	-- Every horse's lane moves (the trip's before the lock, the shown lanes' after it): direction,
	-- lane, and when it last turned, for the after-lock counts.
	local moveTgt, moveDir, moveRev = table.clone(trip.tgt), table.create(n, 0), table.create(n, -math.huge)
	-- D-057 counts: each rider's lane-change starts (from the server's tgt), boxed-in ticks, and the
	-- drawn sideways speed per frame (for the acceleration: lanes interpolate the 10 Hz samples, so
	-- the drawn speed changes once a sample interval and the change over that interval is the
	-- acceleration).
	local riderLane, lastTgt, lastDir, lastRev, flips = {}, {}, {}, {}, {}
	for _, h in humans do
		local i = session:laneIndex(h.id) :: number
		riderLane[h.id], lastTgt[h.id], lastDir[h.id], lastRev[h.id], flips[h.id] = i, trip.tgt[i], 0, -math.huge, 1
		stats.reversals[style[h.id]] = stats.reversals[style[h.id]] or { count = 0, seconds = 0, minGap = math.huge }
	end
	local laneWidth = track.laneWidth
	local lastLane, lastVel = table.create(n, 0), table.create(n, 0)
	for i = 1, n do lastLane[i] = i end
	-- backBefore / backAfter = the fastest any horse is drawn falling back against the pace (ft/s),
	-- from 1 s after the gate to the lock and from the lock on (by the server tick that made the
	-- sample being drawn); jerks / jerksBefore = frames after / before the lock where one falls back
	-- faster than JERK. (Before the hop fix, Trip's own holds snapped a horse arriving in a lane back
	-- up to 5 ft in a tick; holds now settle at most holdPullPerSecond.)
	local lastOffset = table.create(n, 0)
	-- Messages on their way to the client { at, kind, ... } and presses on their way to the server.
	local inbox, outbox = {}, {}
	-- Rider 1's own screen (predict).
	local me = if predict then session:laneIndex("rider1") :: number else 0
	local ownLane, clientLocked = if predict then lane[me] else 0, false
	local state = SteerPredict.new()
	-- (as RaceView: with the eased glide SteerPredict sees the lanes as played back, with D-054's
	-- linear glide the newest sample's)
	local view = { me = me, lanes = cfgGame.lanes, x = if eased then lane else laneTarget, off = offset, srv = nil, cfg = steer }
	local own: Own = { overlapsBefore = 0, overlapsAfter = 0, apartMax = 0, apartAtLock = 0, timeouts = 0, longestPrediction = 0,
		presses = 0, predicted = 0, looks = 0, lookMax = 0, cueFlips = 0, cueSeconds = 0, cueExcess = 0 }
	local lookSince: number? = nil
	-- (eased) rider 1's body on its own screen (RaceView's SteerPose with the look cue): cueFlips =
	-- times the look cue swung the body from one side to the other (its cue amount past half on the
	-- other side), cueSeconds = time it could (gate to lock), cueExcess = the most the body ever
	-- turned beyond its drift (radians).
	local ownPose, cueSide = SteerPose.new(), 0
	local masher = opts ~= nil and opts.ownStyle == "masher"
	local apartFor, sentOwn, sentEvents = 0, nil, 0
	local presses, nextPattern, mySeq = {}, if predict then 1 + 2 * pressRng:NextNumber() else math.huge, 0 -- presses = { { at, dir } } still to make
	local seg = 1
	local lastFrame = 0
	local serverDt = 1 / steer.sendHz
	local k = 0
	-- (eased) The client keeps drawing until it has played the last samples (the server stops at the
	-- line; its last messages land `latency` (and jitter) later and play back a delay behind), so the
	-- order across the line is judged on what the screen finally shows. D-054 runs stop at the line
	-- as D-054's did.
	local drain = if eased then latency + jitter + 2 * serverDt + pb.cfg.margin else 0
	while k * serverDt < tFinish + drain do
		local T = k * serverDt
		if T < tFinish then
			-- Server tick.
			while seg <= #closes and closes[seg] <= T do
				if tapProfiles then
					for _, l in session.lanes do
						if not l.isBot then
							if session:kind(seg) == "pace" then
								session:scorePace(l.id, seg, tapsOf[l.id] or {})
							else
								l.scores[seg] = BURST_BY_PROFILE[profileOf[l.id]] or 60
							end
						end
					end
				end
				shownLive = session:closeSegment(seg)
				if tp then TapPreview.closed(tp) end
				if digest then table.insert(digest.closes, table.clone(session.live)) end
				if tpStats and not trip.locked and seg <= 2 then table.insert(events, { at = T, kind = "close" }) end
				seg += 1
				if tapProfiles and trip.locked then nextShownPreview = T + 1 end
			end
			-- (D-071) Pass ends: the open checkpoint's preview chances for the layer, before the lock.
			if tapProfiles then
				local seen = passEnds
				while passEnds < #session.passes and session.passes[passEnds + 1].t1 <= T + 1e-9 do passEnds += 1 end
				local open = session.closed + 1
				if tp and passEnds > seen and not trip.locked and open <= #cfgGame.segments and session:kind(open) == "pace" then
					local partial, done, clean = partialFor(open, T)
					if done > 0 then TapPreview.setPreview(tp, session.live, session:previewOwn(open, partial), done, partial, clean) end
				end
			end
			while #outbox > 0 and outbox[1].at <= T + 1e-9 do -- rider 1's presses that have arrived
				local p = table.remove(outbox, 1)
				Trip.submit(trip, session, "rider1", p.dir, p.seq, p.at)
			end
			for _, h in humans do
				if predict and h.id == "rider1" then continue end
				if style[h.id] == "random" then
					if T >= nextPress[h.id] and T < trip.lockT then
						seqs[h.id] += 1
						Trip.submit(trip, session, h.id, if pressRng:NextNumber() < 0.6 then -1 else 1, seqs[h.id], T)
						nextPress[h.id] = T + 0.4 + 1.6 * pressRng:NextNumber()
					end
				elseif style[h.id] == "still" then -- (D-071) never presses: Smart Steer rides
					continue
				elseif T < trip.lockT then
					local i = riderLane[h.id]
					local d = 0
					if style[h.id] == "masher" then
						if pressRng:NextNumber() < 0.4 then d = if pressRng:NextNumber() < 0.5 then -1 else 1 end
					elseif style[h.id] == "ditherer" then
						if k % 2 == 0 then
							flips[h.id] = -flips[h.id]
							d = flips[h.id]
						end
					else -- casual
						local u = pressRng:NextNumber()
						local after = Trip.laneAfter(trip, i)
						local idle = trip.want[i] == 0 and trip.queued[i] == 0 and trip.x[i] == trip.tgt[i]
						if u < 0.02 and after > 1 then
							d = -1
						elseif u >= 0.02 and u < 0.025 and idle and after < cfgGame.lanes then
							d = 1
						end
					end
					if d ~= 0 then
						seqs[h.id] += 1
						Trip.submit(trip, session, h.id, d, seqs[h.id], T)
					end
				end
			end
			local wasLocked = trip.locked
			if not trip.locked and Trip.advance(trip, session.live, T) then
				session:setTrip(Trip.raceTau(trip))
				shownLive = table.clone(session.live)
				if tapProfiles then nextShownPreview = T end -- (D-071) refresh the shown chances at the lock too
			end
			-- After the lock the shown chances refresh each second (RaceService: PacePreview.afterLock and
			-- the stretch drive), from the open checkpoint's finished passes.
			if tapProfiles and trip.locked and T >= nextShownPreview - 1e-9 then
				nextShownPreview = T + (cfgGame.pacePreviewAfterLock.seconds or 1)
				local open = session.closed + 1
				if open <= #cfgGame.segments and session:kind(open) == "pace" then
					local stretch = open > 1 and cfgGame.segments[open - 1] == "burst"
					local segPasses = session:pacePasses(open)
					local lastEnd = if #segPasses > 0 then segPasses[#segPasses].t1 else 0
					if T < lastEnd and (stretch or PacePreview.afterLock(cfgGame.pacePreviewAfterLock, true, open, session.closed, false)) then
						local partial, done = partialFor(open, T)
						if done > 0 then shownLive = session:previewLive(open, partial) end
					end
				end
			end
			if not wasLocked then -- each rider's lane-change starts and boxed-in time, up to the lock
				for _, h in humans do
					local i = riderLane[h.id]
					if trip.tgt[i] ~= lastTgt[h.id] then
						local dir = if trip.tgt[i] > lastTgt[h.id] then 1 else -1
						if lastDir[h.id] ~= 0 and dir ~= lastDir[h.id] then
							local r = stats.reversals[style[h.id]]
							r.count += 1
							r.minGap = math.min(r.minGap, T - lastRev[h.id])
							lastRev[h.id] = T
						end
						lastDir[h.id], lastTgt[h.id] = dir, trip.tgt[i]
					end
					if not trip.locked then
						stats.riderTicks += 1
						if Trip.boxedIn(trip, i) then stats.boxedTicks += 1 end
					end
				end
			end
			local w = RaceShape.blendWeight(T, tFar, postEnd, cfgGame.raceShape.blendPower)
			local offsets, sentLanes = Trip.frame(trip, session, shownLive, w, cfgGame.raceShape, T - lastFrame, T)
			lastFrame = T
			if tpStats then -- (D-071) the layer on the sent offsets, and its numbers
				local base = offsets
				local laneX = if trip.locked then trip.shown else trip.x
				local laneTgt = if trip.locked then trip.shownTgt else trip.tgt
				if tp then
					offsets = table.clone(TapPreview.step(tp, base, laneX, laneTgt, T, trip.locked))
				end
				local s = tpStats
				for i = 1, n do
					local e = offsets[i] - base[i]
					s.residualMax = math.max(s.residualMax, math.abs(e))
					if k > 0 then
						local spd = (e - lastE[i]) / serverDt
						s.residualSpeedMax = math.max(s.residualSpeedMax, math.abs(spd))
						s.residualAccelMax = math.max(s.residualAccelMax, math.abs(spd - lastU[i]) / serverDt)
						-- The layer's own limits, on samples where lane room didn't move it (this one or the last)
						if tp and not tp.roomed[i] and not tp.slowed[i] and not lastRoomed[i] then
							s.freeSpeedMax = math.max(s.freeSpeedMax, math.abs(spd))
							if not lastRoomed2[i] then s.freeAccelMax = math.max(s.freeAccelMax, math.abs(spd - lastU[i]) / serverDt) end
						end
						if lastDrawn then s.drawnBackMax = math.max(s.drawnBackMax, ((lastDrawn :: { number })[i] - offsets[i]) / serverDt) end
						lastU[i] = spd
					end
					lastE[i] = e
					lastRoomed2[i] = lastRoomed[i]
					lastRoomed[i] = tp ~= nil and (tp.roomed[i] or tp.slowed[i])
				end
				lastDrawn = table.clone(offsets)
				if not trip.locked then table.insert(s.drawnBeforeLock, table.clone(offsets)) end
				if trip.locked and s.firstDrawn == 0 then -- drawn 1st at the lock (the trust check)
					local best = 1
					for i = 2, n do if offsets[i] > offsets[best] then best = i end end
					s.firstDrawn = best
					for i = 1, n do s.residualAtLock = math.max(s.residualAtLock, math.abs(offsets[i] - base[i])) end
					table.insert(events, { at = T, kind = "lock" })
				end
				if trip.locked and not lockSettled then
					local most = 0
					for i = 1, n do most = math.max(most, math.abs(offsets[i] - base[i])) end
					if most < 1e-3 then
						lockSettled = true
						s.lockResidualSeconds = math.max(0, T - trip.lockT)
					end
				end
				for _, ev in events do -- pull-back windows: 3 s from each close before the lock, and the lock
					if T >= ev.at - 1e-9 and T <= ev.at + 3 + 1e-9 then
						-- extra[i] = how far the drawn horse fell back beyond Trip's own fall, tick by tick
						if not ev.drawn0 then
							ev.drawn0, ev.base0, ev.extra = table.clone(offsets), table.clone(base), table.create(n, 0)
						end
						for i = 1, n do
							local fellDrawn = math.max(0, ev.drawn0[i] - offsets[i])
							local fellBase = math.max(0, ev.base0[i] - base[i])
							ev.extra[i] += math.max(0, fellDrawn - fellBase)
							-- (feel review) how fast a drawn lead is given back, away from lane room
							if tp and not tp.roomed[i] and T > ev.at + 1e-9 then
								s.pullBackSpeed = math.max(s.pullBackSpeed, math.max(0, fellDrawn - fellBase) / serverDt)
							end
						end
						ev.drawn0, ev.base0 = table.clone(offsets), table.clone(base)
						if tp then
							ev.roomed = ev.roomed or {}
							for i = 1, n do if tp.roomed[i] then ev.roomed[i] = true end end
						end
					end
				end
				for _, h in humans do
					local i = session:laneIndex(h.id) :: number
					local profile = profileOf[h.id] or "none"
					local e = offsets[i] - base[i]
					if not trip.locked then
						s.gainMax[profile] = math.max(s.gainMax[profile] or -math.huge, e)
						s.gainMin[profile] = math.min(s.gainMin[profile] or math.huge, e)
					end
					-- (D-071 rulings) boxed share: of the samples where its taps have heldCue.minFeet or more
					-- to show, how many lane room holds back by that much
					if tp and not trip.locked and tp.aimFeet[i] >= cfgGame.tapPreview.heldCue.minFeet then
						s.aimSamples = (s.aimSamples or 0) + 1
						if TapPreview.held(tp, i) >= cfgGame.tapPreview.heldCue.minFeet then s.heldSamples = (s.heldSamples or 0) + 1 end
					end
					-- (D-071 ruling 2) The held cue, as the rider's screen runs it: TapPreview.stepCue on the value
					-- the server last sent (TapPreview.heldSendDue), once with the steering buttons (the "gap" chip,
					-- when SteerLane shows a side free) and once as a rider without them (the "taps" chip).
					if tp and not trip.locked then
						local hc = cfgGame.tapPreview.heldCue
						local held = TapPreview.held(tp, i)
						local c = s.cues[h.id]
						if not c then
							c = { smart = TapPreview.newCue(), manual = TapPreview.newCue(), send = TapPreview.newHeldSend(), run4 = 0,
								run6 = 0, eligible4 = false, pressure = false, eligibleGap = false, gap = false, chips = 0, texts = {}, sends = 0 }
							s.cues[h.id] = c
						end
						Trip.riderLane(trip, i, cueScratch, T)
						local sideRoom = cueScratch.inSide == "free" or cueScratch.outSide == "free"
						c.run4 = if held >= hc.minFeet then c.run4 + serverDt else 0
						c.run6 = if held >= hc.chipMinFeet then c.run6 + serverDt else 0
						if c.run4 >= hc.minSeconds - 1e-9 then c.eligible4 = true end
						if c.run6 >= hc.chipMinSeconds - 1e-9 and sideRoom then c.eligibleGap = true end
						if TapPreview.heldSendDue(c.send, held, T, cfgGame.tapPreview) then c.sends += 1 end
						local seen = c.send.last -- what the rider's screen has
						local pressure, gapChip = TapPreview.stepCue(c.manual, cfgGame.tapPreview, seen, serverDt, T, false, false, sideRoom)
						local _, chip = TapPreview.stepCue(c.smart, cfgGame.tapPreview, seen, serverDt, T, false, true, sideRoom)
						if pressure then c.pressure = true end
						if gapChip == "gap" then c.gap = true end
						for _, ch in { chip, gapChip } do
							if ch then
								c.chips += 1
								table.insert(c.texts, if ch == "gap" then "Find a gap! ◀ ▶" else "Your taps still count!")
							end
						end
					end
					if h.id == "rider1" then table.insert(s.series, { T, e, if tp then TapPreview.held(tp, i) else 0 }) end
					if tp and not trip.locked then
						local m = TapPreview.message(tp, i, T)
						if m then
							if s.lastMessage and s.lastMessage[i] then s.messageGapMin = math.min(s.messageGapMin, T - s.lastMessage[i]) end
							s.lastMessage = s.lastMessage or {}
							s.lastMessage[i] = T
							s.messages[profile] = (s.messages[profile] or 0) + 1
							s.messageKeys[m] = true
							if e <= 0 then s.messageLoss += 1 end
						end
					end
				end
				if tp then s.hardClamps = tp.hardClamps end
			end
			if digest then
				table.insert(digest.ticks, { T, table.clone(trip.off), table.clone(trip.x), table.clone(trip.tgt),
					table.clone(session.live), table.clone(session.tau), if sentLanes then table.clone(sentLanes) else false, trip.locked })
			end
			-- RaceService skips unchanged lanes, which leaves the client's lane targets as they are, so
			-- sending them every tick is the same.
			table.insert(inbox, { at = arrival(T), kind = "offsets", offsets = offsets, lanes = sentLanes, T = T })
			local laneNow = if trip.locked then trip.shownTgt else trip.tgt
			for i = 1, n do
				if laneNow[i] ~= moveTgt[i] then
					local dir = if laneNow[i] > moveTgt[i] then 1 else -1
					if trip.locked then
						stats.afterMoves += 1
						if tFinish - T <= 2 + 1e-9 then
							if math.abs(laneNow[i] - moveTgt[i]) >= 1 - 1e-9 then stats.lateMoves += 1 else stats.lateHalfSteps += 1 end
						end
					end
					if moveDir[i] ~= 0 and dir ~= moveDir[i] then
						if trip.locked then
							local gap = T - moveRev[i]
							stats.afterReversals += 1
							stats.afterMinGap = math.min(stats.afterMinGap, gap)
							if gap < 3.5 - 1e-6 then stats.afterReversalsWithin += 1 end
						end
						moveRev[i] = T
					end
					moveDir[i], moveTgt[i] = dir, laneNow[i]
				end
			end
			if predict then -- (N5 review) your own brushes, before that tick's lane: RaceView steadies the look cue
				while sentEvents < #trip.events do
					sentEvents += 1
					local e = trip.events[sentEvents]
					if e[2] == "brush" and e[3] == me then
						table.insert(inbox, { at = arrival(T), kind = "brush", T = e[1] + trip.dt })
					end
				end
			end
			if predict and not trip.locked then
				local ownNow = { trip.tgt[me], Trip.laneAfter(trip, me), trip.ack[me] }
				if not sentOwn or sentOwn[1] ~= ownNow[1] or sentOwn[2] ~= ownNow[2] or sentOwn[3] ~= ownNow[3] then
					sentOwn = ownNow
					table.insert(inbox, { at = arrival(T), kind = "own", own = ownNow })
				end
			end
			if trip.locked and not wasLocked then table.insert(inbox, { at = arrival(T), kind = "locked" }) end
		end
		-- Client frames until the next server tick.
		local tc = T
		while tc < T + serverDt - 1e-9 do
			tc += FRAME
			while #inbox > 0 and inbox[1].at <= tc + 1e-9 do
				local m = table.remove(inbox, 1)
				if m.kind == "offsets" then
					for i = 1, n do laneTarget[i] = (m.lanes :: { number })[i] end
					if eased then -- as RaceView: pushed with its stamp, played back by it (never by arrival)
						Playback.pushOffsets(pb, m.T, tc, m.offsets, m.lanes, laneTarget)
					else -- D-054: the glide to the new sample is timed from its arrival (just after the last frame)
						for i = 1, n do from[i], to[i] = offset[i], m.offsets[i] end
						sampleAt, sampleT = tc - FRAME, m.T
					end
				elseif m.kind == "own" then
					view.srv = { tgt = m.own[1], dest = m.own[2], ack = m.own[3] }
				elseif m.kind == "brush" then -- as RaceView: no look cue while your horse steadies
					view.steadyUntil = math.max(tc, m.T + steer.steadySeconds)
				else
					clientLocked = true
				end
			end
			local glide = FRAME / steer.laneSeconds
			local afterLock -- drawn from a sample made after the lock
			if eased then
				play = Playback.advance(pb, tc, FRAME)
				if play then
					local a, b, f = Playback.around(pb, play :: number)
					Playback.lerp(offset, a.data.off, b.data.off, f)
					Playback.lerp(lane, a.data.lanes, b.data.lanes, f)
				end
				afterLock = play ~= nil and (play :: number) >= trip.lockT - 1e-9
			else
				local f = math.clamp((tc - sampleAt) / serverDt, 0, 1)
				for i = 1, n do
					offset[i] = from[i] + (to[i] - from[i]) * f
					lane[i] += math.clamp(laneTarget[i] - lane[i], -glide, glide)
				end
				afterLock = sampleT >= trip.lockT - 1e-9
			end
			if tc > 1 then
				local jerked = false
				for i = 1, n do
					local back = (lastOffset[i] - offset[i]) / FRAME
					if afterLock then
						if back > stats.backAfter then stats.backAfter = back end
					elseif back > stats.backBefore then
						stats.backBefore = back
					end
					if back > JERK then jerked = true end
				end
				if jerked and afterLock then
					stats.jerks += 1
				elseif jerked then
					stats.jerksBefore += 1
				end
			end
			for i = 1, n do lastOffset[i] = offset[i] end
			-- (not once the stream has ended: after the last sample the drawn lanes just stop; with the
			-- eased glide a late sample mid-race holds them too, and that counts)
			local streaming = if eased then play ~= nil and (not pb.held or tc < tFinish) else tc - sampleAt <= serverDt + 1e-9
			for i = 1, n do
				local vel = (lane[i] - lastLane[i]) * laneWidth / FRAME
				if tc > 1 and streaming then
					local acc = math.abs(vel - lastVel[i]) / serverDt
					if afterLock then
						stats.accelAfter = math.max(stats.accelAfter, acc)
					else
						stats.accelBefore = math.max(stats.accelBefore, acc)
					end
				end
				lastVel[i], lastLane[i] = vel, lane[i]
			end
			stats.frames += 1
			watchLine(tc)
			local hits = 0
			for i = 1, n do
				for j = i + 1, n do
					if math.abs(lane[i] - lane[j]) < SIDE and math.abs(offset[i] - offset[j]) < LENGTH then
						hits += 1
					end
				end
			end
			if tpStats then -- (D-071) each rider's own screen: its tap nudge on top of the received offsets
				for id, nd in nudges do
					local good = goodOf[id]
					while nd.ptr <= #good and good[nd.ptr] <= tc + 1e-9 do
						nd.prev, nd.last = nd.last, good[nd.ptr]
						nd.ptr += 1
					end
					local goal = math.max(nudgeFeet(tc - nd.last), nudgeFeet(tc - nd.prev))
					local room = RaceFx.nudgeRoom(nd.lane, offset, lane, steer.laneBand, cfgGame.raceFx.nudgeClearFeet)
					-- (opts.nudgeFallCap: RaceView passes its horse's fall this frame, RaceFx.stepNudge's baseFall)
					local baseFall = if opts and opts.nudgeFallCap and nd.lastBase then math.max(0, nd.lastBase - offset[nd.lane]) else nil
					nd.lastBase = offset[nd.lane]
					nd.drawn = RaceFx.stepNudge(nd.drawn, goal, room, FRAME, cfgGame.raceFx, baseFall)
					local mineAt = offset[nd.lane] + nd.drawn
					if tc > 1 and nd.seen and (nd.seen - mineAt) / FRAME > JERK then tpStats.ownJerks += 1 end
					nd.seen = mineAt
					for j = 1, n do
						if j ~= nd.lane and math.abs(lane[nd.lane] - lane[j]) < SIDE and math.abs(mineAt - offset[j]) < LENGTH then
							tpStats.ownOverlaps += 1
						end
					end
				end
			end
			if hits > 0 then
				if tc < trip.lockT then
					stats.before += 1
				else
					stats.after += 1
					if tc < trip.lockT + 5 then stats.first5 += 1 end
					if tc > tFinish - 2 then stats.lastTwo += 1 end
				end
			end
			if predict then
				-- Rider 1 presses (as RaceController: from the gate to the lock it knows from TripInfo).
				if masher then -- 4 presses a second at random, either side
					if tc > 1 and tc < trip.lockT and pressRng:NextNumber() < 4 * FRAME then
						table.insert(presses, { at = tc, dir = if pressRng:NextNumber() < 0.5 then -1 else 1 })
					end
				elseif tc >= nextPattern and tc < trip.lockT then
					local dir = if pressRng:NextNumber() < 0.6 then -1 else 1
					local u = pressRng:NextNumber()
					if u < 0.4 then
						table.insert(presses, { at = tc, dir = dir })
					elseif u < 0.6 then -- double press
						table.insert(presses, { at = tc, dir = dir })
						table.insert(presses, { at = tc + 0.15, dir = dir })
					elseif u < 0.8 then -- mash
						for m = 0, 4 do table.insert(presses, { at = tc + 0.08 * m, dir = dir }) end
					else -- In then Out (or Out then In)
						table.insert(presses, { at = tc, dir = dir })
						table.insert(presses, { at = tc + 0.2, dir = -dir })
					end
					nextPattern = tc + 1 + 1.5 * pressRng:NextNumber()
				end
				while #presses > 0 and presses[1].at <= tc + 1e-9 do
					local p = table.remove(presses, 1)
					if tc < trip.lockT and not clientLocked then
						mySeq += 1
						own.presses += 1
						if eased then
							if SteerPredict.look(state, view, p.dir, mySeq, tc) then
								own.looks += 1
								lookSince = tc
							end
						elseif SteerPredict.press(state, view, p.dir, mySeq, tc) then
							own.predicted += 1
						end
						table.insert(outbox, { at = tc + latency, dir = p.dir, seq = mySeq })
					end
				end
				if eased then -- drawn where everyone sees it; the look cue holds until it starts over
					ownLane = lane[me]
					local lookNow = SteerPredict.lookDir(state, view, tc, clientLocked)
					if lookNow == 0 then
						if lookSince then own.lookMax = math.max(own.lookMax, tc - (lookSince :: number)) end
						lookSince = nil
					end
					local poseCfg = cfgGame.steerView
					local yaw = SteerPose.step(ownPose, poseCfg, ownLane, FRAME, cfgGame.raceSpeedStudsPerSecond, laneWidth, lookNow)
					local maxYaw = math.rad(poseCfg.yawMaxDeg)
					local drift = math.clamp(math.atan2(ownPose.v, math.max(cfgGame.raceSpeedStudsPerSecond, SteerPose.MIN_FORWARD))
						* poseCfg.yawGain, -maxYaw, maxYaw)
					own.cueExcess = math.max(own.cueExcess, math.abs(yaw - drift))
					if math.abs(ownPose.look) >= 0.5 then
						local side = if ownPose.look > 0 then 1 else -1
						if cueSide ~= 0 and side ~= cueSide then own.cueFlips += 1 end
						cueSide = side
					end
					if tc > 1 and tc < trip.lockT then own.cueSeconds += FRAME end
				else
					local laneTo = SteerPredict.laneTo(state, view, tc, clientLocked)
					ownLane += math.clamp(laneTo - ownLane, -glide, glide)
				end
				local mine = false
				for j = 1, n do
					if j ~= me and math.abs(ownLane - lane[j]) < SIDE and math.abs(offset[me] - offset[j]) < LENGTH then mine = true end
				end
				if mine then
					if tc < trip.lockT then own.overlapsBefore += 1 else own.overlapsAfter += 1 end
				end
				if math.abs(ownLane - lane[me]) > APART then
					apartFor += FRAME
					if apartFor > own.apartMax then own.apartMax = apartFor end
				else
					apartFor = 0
				end
				if tc >= trip.lockT + 1 and tc < trip.lockT + 1 + FRAME then own.apartAtLock = math.abs(ownLane - lane[me]) end
			end
		end
		k += 1
	end
	if predict then
		own.timeouts = state.timeouts
		own.longestPrediction = state.longest
		stats.own = own
	end
	local lastFrameOffset = table.clone(offset) -- (the order check below judges the last frame)
	-- The screen keeps drawing (no new samples) until every horse has crossed the line on it.
	local tc = k * serverDt
	local function allCrossed(): boolean
		for i = 1, n do
			if crossAt[i] == math.huge then return false end
		end
		return true
	end
	while not allCrossed() and tc < tFinish + 6 do
		tc += FRAME
		while #inbox > 0 and inbox[1].at <= tc + 1e-9 do
			local m = table.remove(inbox, 1)
			if m.kind == "offsets" then
				if eased then
					Playback.pushOffsets(pb, m.T, tc, m.offsets, m.lanes, laneTarget)
				else
					for i = 1, n do from[i], to[i] = offset[i], m.offsets[i] end
					sampleAt = tc - FRAME
				end
			end
		end
		if eased then
			local playAt = Playback.advance(pb, tc, FRAME)
			if playAt then
				local a, b, f = Playback.around(pb, playAt :: number)
				Playback.lerp(offset, a.data.off, b.data.off, f)
			end
		else
			local f = math.clamp((tc - sampleAt) / serverDt, 0, 1)
			for i = 1, n do offset[i] = from[i] + (to[i] - from[i]) * f end
		end
		watchLine(tc)
	end
	local crossing = table.create(n)
	for i = 1, n do crossing[i] = i end
	table.sort(crossing, function(a: number, b: number): boolean
		if crossAt[a] ~= crossAt[b] then return crossAt[a] < crossAt[b] end
		return a < b
	end)
	stats.crossOrder = crossing
	-- The order across the line on screen (offsets at the last frame) against the result.
	local line = table.create(n)
	for i = 1, n do line[i] = i end
	table.sort(line, function(a: number, b: number): boolean
		if lastFrameOffset[a] ~= lastFrameOffset[b] then return lastFrameOffset[a] > lastFrameOffset[b] end
		return a < b
	end)
	local result = RaceShape.order(session.luck, session.live)
	for p = 1, n do
		if line[p] ~= result[p] then stats.orderOk = false end
		if crossing[p] ~= result[p] or crossAt[crossing[p]] == math.huge then stats.crossOrderOk = false end
	end
	stats.lineOrder, stats.result = line, result
	if tpStats then
		local place = table.create(n, 0)
		for p = 1, n do place[result[p]] = p end
		tpStats.firstDrawnPlace = if tpStats.firstDrawn > 0 then place[tpStats.firstDrawn] else 0
		tpStats.places = place
		for _, h in humans do tpStats.laneOf[profileOf[h.id] or h.id] = session:laneIndex(h.id) end
		local byProfile = {}
		for id, c in tpStats.cues do byProfile[profileOf[id] or id] = c end
		tpStats.cues = byProfile
		-- Pull-back: how much further each rider's drawn horse fell back in a window than Trip's own did.
		for _, ev in events do
			if ev.drawn0 then
				for _, h in humans do
					local i = session:laneIndex(h.id) :: number
					local extra = ev.extra[i]
					local key = (profileOf[h.id] or "none") .. ":" .. ev.kind .. (if ev.roomed and ev.roomed[i] then "(room)" else "")
					tpStats.extraDrop[key] = math.max(tpStats.extraDrop[key] or 0, extra)
				end
			end
		end
		stats.tp = tpStats
	end
	if digest then
		local fin = session:finish()
		digest.order = fin.order
		digest.prizes = fin.prizes
		digest.tau = table.clone(session.tau)
		stats.digest = serde.encode("json", digest)
	end
	stats.halfSteps = trip.halfSteps or 0
	stats.brushes = #trip.events
	-- Brushes by rider style (D-057 N5), and the mover-pays check: a horse charged for a brush it
	-- never made (it was only ever the one bumped) would count in strangerCharged.
	local moved = {}
	for _, e in trip.events do moved[e[3]] = true end
	for i = 1, n do
		if Trip.brushCharge(trip, i) > 0 and not moved[i] then stats.strangerCharged += 1 end
	end
	for _, h in humans do
		local i = riderLane[h.id]
		local b = stats.brushStyles[style[h.id]] or { riders = 0, brushRaces = 0, chargedRaces = 0, brushes = 0 }
		b.riders += 1
		b.brushes += trip.brushes[i]
		if trip.brushes[i] > 0 then b.brushRaces += 1 end
		if Trip.brushCharge(trip, i) > 0 then b.chargedRaces += 1 end
		stats.brushStyles[style[h.id]] = b
	end
	for _, h in humans do stats.reversals[style[h.id]].seconds += trip.lockT end -- per rider
	return stats
end
