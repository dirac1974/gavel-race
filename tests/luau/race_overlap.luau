--!strict
-- Runs one all-bot race the way RaceService runs it (10 Hz server: checkpoints, the trip to the
-- far-turn lock, tau, the race shape's offsets and make-room lanes after it, the send rates) and
-- draws it the way RaceView does with steering on (60 fps: the sent offsets interpolated, lanes
-- gliding linearly at most frame/laneSeconds), and counts horses overlapping on screen: closer than
-- half a lane sideways and 6 ft lengthwise (a horse is 8 ft long). Used by trip_tests.luau,
-- steer_controls_tests.luau and tests/luau/overlap_report.luau (D-054 S2, S3).
-- opts.riders = how many lanes are riders pressing ◀ ▶ at random (S3; their presses go through
-- Trip.submit like RaceService's SteerRequest); opts.manual = those riders have Smart Steer off.
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

local SIDE, LENGTH = 0.5, 6 -- overlap: closer than this sideways (lanes) and lengthwise (feet)
local FRAME = 1 / 60

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

export type Stats = { before: number, first5: number, after: number, lastTwo: number, frames: number, orderOk: boolean, lineOrder: { number }, result: { number }, answers: { [string]: number } }

return function(courseId: string, distanceName: string, seed: number, config: any?, opts: any?): Stats
	local cfgGame = config or GameConfig
	local steer = cfgGame.steering
	local track = TrackLayout.courses[courseId]
	local plan = TrackLayout.plan(track, TrackLayout.distances[distanceName])
	local rng = makeRng(seed)
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local humans, manual = {}, {}
	for r = 1, (opts and opts.riders) or 0 do
		table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
		if opts.manual then manual["rider" .. r] = true end
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
	local trip = Trip.start(cfgGame, session, track, plan, TripBaseline[courseId][distanceName], rng, TrackLayout, manual)
	assert(trip, "steering is on")
	-- Riders press at random, 0.4 to 2 s apart, more often in than out (their own generator, so the
	-- race's draws are unchanged).
	local pressRng = makeRng(seed * 31 + 7)
	local nextPress, seqs = {}, {}
	for _, h in humans do
		nextPress[h.id] = pressRng:NextNumber() * 2
		seqs[h.id] = 0
	end
	local n = #session.lanes
	local shownLive = table.clone(session.live)
	-- Client state.
	local offset, from, to = table.create(n, 0), table.create(n, 0), table.create(n, 0)
	local lane, laneTarget = table.create(n, 0), table.create(n, 0)
	for i = 1, n do
		lane[i], laneTarget[i] = i, i
	end
	local sampleAt = 0
	local stats = { before = 0, first5 = 0, after = 0, lastTwo = 0, frames = 0, orderOk = true, lineOrder = {}, result = {}, answers = trip.answers }
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
		for _, h in humans do
			if T >= nextPress[h.id] and T < trip.lockT then
				seqs[h.id] += 1
				Trip.submit(trip, session, h.id, if pressRng:NextNumber() < 0.6 then -1 else 1, seqs[h.id], T)
				nextPress[h.id] = T + 0.4 + 1.6 * pressRng:NextNumber()
			end
		end
		if not trip.locked and Trip.advance(trip, session.live, T) then
			session:setTrip(Trip.raceTau(trip))
			shownLive = table.clone(session.live)
		end
		local w = RaceShape.blendWeight(T, tFar, postEnd, cfgGame.raceShape.blendPower)
		local offsets, sentLanes = Trip.frame(trip, session, shownLive, w, cfgGame.raceShape, T - lastFrame, T)
		lastFrame = T
		-- Client receives (no latency). RaceService skips unchanged lanes, which leaves the
		-- client's lane targets as they are, so taking them every tick is the same.
		for i = 1, n do
			from[i], to[i] = offset[i], offsets[i]
			laneTarget[i] = (sentLanes :: { number })[i]
		end
		sampleAt = T
		-- Client frames until the next server tick.
		local tc = T
		while tc < T + serverDt - 1e-9 do
			tc += FRAME
			local f = math.clamp((tc - sampleAt) / serverDt, 0, 1)
			for i = 1, n do offset[i] = from[i] + (to[i] - from[i]) * f end
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
		end
		k += 1
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
	return stats
end
