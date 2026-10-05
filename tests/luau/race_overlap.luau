--!strict
-- Runs one race the way RaceService runs it (10 Hz server: checkpoints, the trip to the far-turn
-- lock, tau, the race shape's offsets and make-room lanes after it, the send rates) and draws it
-- the way RaceView does with steering on (60 fps: the sent offsets interpolated, lanes gliding
-- linearly at most frame/laneSeconds), and counts horses overlapping on screen: closer than half
-- a lane sideways and 6 ft lengthwise (a horse is 8 ft long). Used by trip_tests.luau,
-- steer_controls_tests.luau and tests/luau/overlap_report.luau (D-054 S2, S3).
-- opts (all optional):
--   riders = how many lanes are riders pressing ◀ ▶ at random (S3; the presses go through
--     Trip.submit like RaceService's SteerRequest); manual = those riders have Smart Steer off.
--   predict = rider 1 presses from its own screen instead: singles, doubles, mashes and In-then-Out
--     pairs, sent with `latency` (default 0.1 s each way, which then delays every message), its own
--     horse drawn by SteerPredict as RaceView draws it, from SteerLane messages (tgt, destination,
--     last press answered, sent on change as RaceService does). Counts overlaps on that screen and
--     how long its own horse is drawn somewhere else than everyone else sees it.
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
local SteerPredict = require("../../game/src/shared/SteerPredict")

local SIDE, LENGTH = 0.5, 6 -- overlap: closer than this sideways (lanes) and lengthwise (feet)
local FRAME = 1 / 60
local APART = 0.05          -- your own horse drawn this far (lanes) from the shared view counts as apart
local JERK = 20             -- after the lock, a horse drawn falling back faster than this (ft/s, against the pace) jerks

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
	timeouts: number, longestPrediction: number, presses: number, predicted: number }
export type Stats = { before: number, first5: number, after: number, lastTwo: number, frames: number, orderOk: boolean,
	lineOrder: { number }, result: { number }, answers: { [string]: number }, halfSteps: number,
	backBefore: number, backAfter: number, jerks: number, own: Own? }

return function(courseId: string, distanceName: string, seed: number, config: any?, opts: any?): Stats
	local cfgGame = config or GameConfig
	local steer = cfgGame.steering
	local track = TrackLayout.courses[courseId]
	local plan = TrackLayout.plan(track, TrackLayout.distances[distanceName])
	local rng = makeRng(seed)
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local predict = opts ~= nil and opts.predict == true
	local latency = if opts and opts.latency then opts.latency elseif predict then 0.1 else 0
	local humans, riders = {}, {}
	for r = 1, (opts and opts.riders) or 0 do
		table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
		riders["rider" .. r] = if opts.manual then "manual" else "smart"
	end
	local lanes = RaceSession.fillWithBots(humans, cfgGame.lanes, cfgGame, ThemePack, rng)
	local session = RaceSession.new({ deps = deps, config = cfgGame, leagueName = "Silver", lanes = lanes, rng = rng })
	local league = cfgGame.leagues.Silver
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
	session:assignPosts(RaceSession.postOrder(cfgGame, #session.lanes, rng))
	local trip = Trip.start(cfgGame, session, track, plan, TripBaseline[courseId][distanceName], rng, TrackLayout, riders)
	assert(trip, "steering is on")
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
	local offset, from, to = table.create(n, 0), table.create(n, 0), table.create(n, 0)
	local lane, laneTarget = table.create(n, 0), table.create(n, 0)
	for i = 1, n do
		lane[i], laneTarget[i] = i, i
	end
	local sampleAt, sampleT = 0, 0 -- when the shown sample arrived, and the server tick that made it
	local stats: Stats = { before = 0, first5 = 0, after = 0, lastTwo = 0, frames = 0, orderOk = true, lineOrder = {}, result = {},
		answers = trip.answers, halfSteps = 0, backBefore = 0, backAfter = 0, jerks = 0, own = nil }
	-- backBefore / backAfter = the fastest any horse is drawn falling back against the pace (ft/s),
	-- from 1 s after the gate to the lock and from the lock on (by the server tick that made the
	-- sample being drawn); jerks = frames after the lock where one
	-- falls back faster than JERK. (Before the lock Trip's own holds can hop a horse arriving in a lane
	-- back up to about 2.5 ft in a tick: it needs clearFeet ahead to move, then sits holdGap back.)
	local lastOffset = table.create(n, 0)
	-- Messages on their way to the client { at, kind, ... } and presses on their way to the server.
	local inbox, outbox = {}, {}
	-- Rider 1's own screen (predict).
	local me = if predict then session:laneIndex("rider1") :: number else 0
	local ownLane, clientLocked = if predict then lane[me] else 0, false
	local state = SteerPredict.new()
	local view = { me = me, lanes = cfgGame.lanes, x = laneTarget, off = offset, srv = nil, cfg = steer }
	local own: Own = { overlapsBefore = 0, overlapsAfter = 0, apartMax = 0, apartAtLock = 0, timeouts = 0, longestPrediction = 0,
		presses = 0, predicted = 0 }
	local apartFor, sentOwn = 0, nil
	local presses, nextPattern, mySeq = {}, if predict then 1 + 2 * pressRng:NextNumber() else math.huge, 0 -- presses = { { at, dir } } still to make
	local seg = 1
	local lastFrame = 0
	local serverDt = 1 / steer.sendHz
	local k = 0
	while k * serverDt < tFinish do
		local T = k * serverDt
		-- Server tick.
		while seg <= #closes and closes[seg] <= T do
			shownLive = session:closeSegment(seg)
			seg += 1
		end
		while #outbox > 0 and outbox[1].at <= T + 1e-9 do -- rider 1's presses that have arrived
			local p = table.remove(outbox, 1)
			Trip.submit(trip, session, "rider1", p.dir, p.seq, p.at)
		end
		for _, h in humans do
			if not (predict and h.id == "rider1") and T >= nextPress[h.id] and T < trip.lockT then
				seqs[h.id] += 1
				Trip.submit(trip, session, h.id, if pressRng:NextNumber() < 0.6 then -1 else 1, seqs[h.id], T)
				nextPress[h.id] = T + 0.4 + 1.6 * pressRng:NextNumber()
			end
		end
		local wasLocked = trip.locked
		if not trip.locked and Trip.advance(trip, session.live, T) then
			session:setTrip(Trip.raceTau(trip))
			shownLive = table.clone(session.live)
		end
		local w = RaceShape.blendWeight(T, tFar, postEnd, cfgGame.raceShape.blendPower)
		local offsets, sentLanes = Trip.frame(trip, session, shownLive, w, cfgGame.raceShape, T - lastFrame, T)
		lastFrame = T
		-- RaceService skips unchanged lanes, which leaves the client's lane targets as they are, so
		-- sending them every tick is the same.
		table.insert(inbox, { at = T + latency, kind = "offsets", offsets = offsets, lanes = sentLanes, T = T })
		if predict and not trip.locked then
			local ownNow = { trip.tgt[me], Trip.laneAfter(trip, me), trip.ack[me] }
			if not sentOwn or sentOwn[1] ~= ownNow[1] or sentOwn[2] ~= ownNow[2] or sentOwn[3] ~= ownNow[3] then
				sentOwn = ownNow
				table.insert(inbox, { at = T + latency, kind = "own", own = ownNow })
			end
		end
		if trip.locked and not wasLocked then table.insert(inbox, { at = T + latency, kind = "locked" }) end
		-- Client frames until the next server tick.
		local tc = T
		while tc < T + serverDt - 1e-9 do
			tc += FRAME
			while #inbox > 0 and inbox[1].at <= tc + 1e-9 do
				local m = table.remove(inbox, 1)
				if m.kind == "offsets" then
					for i = 1, n do
						from[i], to[i] = offset[i], m.offsets[i]
						laneTarget[i] = (m.lanes :: { number })[i]
					end
					-- As RaceView: the glide to the new sample is timed from its arrival (here, just
					-- after the last frame), so a message a frame late never squeezes a glide.
					sampleAt, sampleT = tc - FRAME, m.T
				elseif m.kind == "own" then
					view.srv = { tgt = m.own[1], dest = m.own[2], ack = m.own[3] }
				else
					clientLocked = true
				end
			end
			local f = math.clamp((tc - sampleAt) / serverDt, 0, 1)
			for i = 1, n do offset[i] = from[i] + (to[i] - from[i]) * f end
			if tc > 1 then
				local jerked = false
				local afterLock = sampleT >= trip.lockT - 1e-9 -- drawn from a sample made after the lock
				for i = 1, n do
					local back = (lastOffset[i] - offset[i]) / FRAME
					if afterLock then
						if back > stats.backAfter then stats.backAfter = back end
						if back > JERK then jerked = true end
					elseif back > stats.backBefore then
						stats.backBefore = back
					end
				end
				if jerked then stats.jerks += 1 end
			end
			for i = 1, n do lastOffset[i] = offset[i] end
			local glide = FRAME / steer.laneSeconds
			for i = 1, n do
				local d = laneTarget[i] - lane[i]
				lane[i] += math.clamp(d, -glide, glide)
			end
			stats.frames += 1
			local hits = 0
			for i = 1, n do
				for j = i + 1, n do
					if math.abs(lane[i] - lane[j]) < SIDE and math.abs(offset[i] - offset[j]) < LENGTH then hits += 1 end
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
				if tc >= nextPattern and tc < trip.lockT then
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
						if SteerPredict.press(state, view, p.dir, mySeq, tc) then own.predicted += 1 end
						table.insert(outbox, { at = tc + latency, dir = p.dir, seq = mySeq })
					end
				end
				local laneTo = SteerPredict.laneTo(state, view, tc, clientLocked)
				ownLane += math.clamp(laneTo - ownLane, -glide, glide)
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
	-- The order across the line on screen (offsets at the last frame) against the result.
	local line = table.create(n)
	for i = 1, n do line[i] = i end
	table.sort(line, function(a: number, b: number): boolean
		if offset[a] ~= offset[b] then return offset[a] > offset[b] end
		return a < b
	end)
	local result = RaceShape.order(session.luck, session.live)
	for p = 1, n do
		if line[p] ~= result[p] then stats.orderOk = false end
	end
	stats.lineOrder, stats.result = line, result
	stats.halfSteps = trip.halfSteps or 0
	return stats
end
