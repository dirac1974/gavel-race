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
-- The config is GameConfig's (since N3: D-057's motion and press rules, brushes off) unless
-- `config` is given, or opts.d057 (D-057 in full, brushes on: Trip.d057Config) or opts.d054 (the
-- switch-back: Trip.d054Config).
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
local Playback = require("../../game/src/shared/Playback")

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
	timeouts: number, longestPrediction: number, presses: number, predicted: number, looks: number, lookMax: number }
export type Stats = { before: number, first5: number, after: number, lastTwo: number, frames: number, orderOk: boolean,
	lineOrder: { number }, result: { number }, answers: { [string]: number }, halfSteps: number,
	backBefore: number, backAfter: number, jerks: number, jerksBefore: number, own: Own?,
	reversals: { [string]: { count: number, seconds: number, minGap: number } }, accelBefore: number, accelAfter: number,
	brushes: number, boxedTicks: number, riderTicks: number, afterMoves: number, lateMoves: number, lateHalfSteps: number,
	afterReversals: number, afterReversalsWithin: number, afterMinGap: number }

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
	for r = 1, (opts and opts.riders) or #styles do
		table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
		riders["rider" .. r] = if opts and opts.manual then "manual" else "smart"
		style["rider" .. r] = styles[r] or "random"
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
	local baseline = TripBaseline
	if d054 then -- the switch-back's own baseline (tests/fixtures/trip_baseline_d054.json)
		baselineD054 = baselineD054 or serde.decode("json", fs.readFile("tests/fixtures/trip_baseline_d054.json")).baseline
		baseline = baselineD054
	end
	local trip = Trip.start(cfgGame, session, track, plan, baseline[courseId][distanceName], rng, TrackLayout, riders)
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
		afterMoves = 0, lateMoves = 0, lateHalfSteps = 0, afterReversals = 0, afterReversalsWithin = 0, afterMinGap = math.huge }
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
		presses = 0, predicted = 0, looks = 0, lookMax = 0 }
	local lookSince: number? = nil
	local apartFor, sentOwn = 0, nil
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
				shownLive = session:closeSegment(seg)
				seg += 1
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
						Playback.push(pb, m.T, tc, { off = table.clone(m.offsets), lanes = table.clone(m.lanes :: { number }) })
					else -- D-054: the glide to the new sample is timed from its arrival (just after the last frame)
						for i = 1, n do from[i], to[i] = offset[i], m.offsets[i] end
						sampleAt, sampleT = tc - FRAME, m.T
					end
				elseif m.kind == "own" then
					view.srv = { tgt = m.own[1], dest = m.own[2], ack = m.own[3] }
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
			local hits = 0
			for i = 1, n do
				for j = i + 1, n do
					if math.abs(lane[i] - lane[j]) < SIDE and math.abs(offset[i] - offset[j]) < LENGTH then
						hits += 1
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
					if SteerPredict.lookDir(state, view, tc, clientLocked) == 0 then
						if lookSince then own.lookMax = math.max(own.lookMax, tc - (lookSince :: number)) end
						lookSince = nil
					end
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
	stats.brushes = #trip.events
	for _, h in humans do stats.reversals[style[h.id]].seconds += trip.lockT end -- per rider
	return stats
end
