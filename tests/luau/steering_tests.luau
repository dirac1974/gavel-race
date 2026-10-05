--!strict
-- Steering stage S1 (D-054): rail coordinates (TrackLayout.railLength, railPoint, phaseA) and
-- drawn posts (RaceSession.drawPosts, assignPosts). Run from run_all.luau.
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local ThemePack = require("../../game/src/shared/ThemePack")
local BurstMeter = require("../../game/src/shared/BurstMeter")
local PaceMeter = require("../../game/src/shared/PaceMeter")
local RaceShape = require("../../game/src/shared/RaceShape")
local RaceSession = require("../../game/src/shared/RaceSession")
local TrackLayout = require("../../game/src/shared/TrackLayout")

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- Rail coordinates ----------------------------------------------------------------------
	for courseId, cfg in TrackLayout.courses do
		local r1 = TrackLayout.laneRadius(cfg, 1)
		local half = cfg.straight / 2
		local _, _, lineZ = TrackLayout.finishLine(cfg)
		for name, distance in TrackLayout.distances do
			local tag = courseId .. " " .. name
			local plan = TrackLayout.plan(cfg, distance)
			local len = TrackLayout.railLength(cfg, plan)
			check(len == plan.lengths[1], tag .. ": railLength is the lane-1 length")
			for i = 1, cfg.lanes do
				-- s = 0 is the lane's own gate stall; s = railLength is on the finish line.
				local gx, gz, gdx, gdz = TrackLayout.railPoint(cfg, plan, 0, i)
				local lx, lz, ldx, ldz = TrackLayout.lanePoint(cfg, plan, i, 0)
				check(close(gx, lx, 1e-6) and close(gz, lz, 1e-6) and close(gdx, ldx, 1e-9) and close(gdz, ldz, 1e-9),
					tag .. ": s = 0 is lane " .. i .. "'s gate stall")
				local fx, fz = TrackLayout.railPoint(cfg, plan, len, i)
				check(close(fz, lineZ, 1e-6) and close(fx, cfg.centerX + TrackLayout.laneRadius(cfg, i), 1e-6),
					tag .. ": every lane reaches the line at s = railLength")
			end
			-- x = 1 is exactly the lane-1 path.
			local same = true
			for k = 0, 200 do
				local s = len * k / 200
				local ax, az = TrackLayout.railPoint(cfg, plan, s, 1)
				local bx, bz = TrackLayout.lanePoint(cfg, plan, 1, s / len)
				if not (close(ax, bx, 1e-6) and close(az, bz, 1e-6)) then same = false end
			end
			check(same, tag .. ": x = 1 follows lane 1")
			-- Along the whole race and past the line: unit headings, no jumps across the joins
			-- (a fractional lane too), turn radius = the lane's radius at integer x (as lanePoint),
			-- and horses at the same s abreast: square to the heading, one lane width apart.
			local steps = 3000
			local span = len + 400
			local ds = span / steps
			local maxStep = ds * TrackLayout.laneRadius(cfg, cfg.lanes) / r1 + 1e-6
			local px, pz = TrackLayout.railPoint(cfg, plan, 0, 3.5)
			local unit, smooth, radius, abreast, turnSamples = true, true, true, true, 0
			for k = 1, steps do
				local s = ds * k
				local x, z, dx, dz = TrackLayout.railPoint(cfg, plan, s, 3.5)
				if not close(dx * dx + dz * dz, 1, 1e-9) then unit = false end
				if math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) > maxStep then smooth = false end
				px, pz = x, z
				local x1, z1, hx, hz = TrackLayout.railPoint(cfg, plan, s, 1)
				for i = 1, cfg.lanes do
					local xi, zi = TrackLayout.railPoint(cfg, plan, s, i)
					local vx, vz = xi - x1, zi - z1
					if not close(vx * hx + vz * hz, 0, 1e-6) or not close(math.sqrt(vx * vx + vz * vz), (i - 1) * cfg.laneWidth, 1e-6) then
						abreast = false
					end
					local dzc = zi - cfg.centerZ
					if math.abs(dzc) > half + 1e-6 then -- on a turn: centred at (cx, cz -+ L/2)
						if i == 1 then turnSamples += 1 end
						local czTurn = cfg.centerZ + (if dzc > 0 then half else -half)
						local rr = math.sqrt((xi - cfg.centerX) ^ 2 + (zi - czTurn) ^ 2)
						if not close(rr, TrackLayout.laneRadius(cfg, i), 1e-6) then radius = false end
					end
				end
			end
			check(unit, tag .. ": unit headings")
			check(smooth, tag .. ": continuous across segment joins")
			check(turnSamples > 0 and radius, tag .. ": on turns, integer x runs on the lane's radius")
			check(abreast, tag .. ": horses at the same s are abreast, straights and turns")

			-- Phase A: contiguous segments from the gate to the far-turn entry; the far turn follows.
			local pa = TrackLayout.phaseA(cfg, plan)
			check(close(pa.lockS, len - cfg.finishFromTop - math.pi * r1, 1e-9), tag .. ": lock at the far-turn entry")
			local s0, live = 0, 0
			for _, seg in pa.segments do
				check(close(seg.start, s0, 1e-9), tag .. ": segments are contiguous")
				s0 += seg.length
				if seg.kind == "T" then
					live += 1
					check(close(seg.length, math.pi * r1, 1e-9), tag .. ": whole 180-degree turns")
				end
			end
			check(close(s0, pa.lockS, 1e-6) and live == #pa.turns, tag .. ": segments reach the lock")
			local wantTurns = ({ Sprint = 0, Mile = 1, Classic = 1, Marathon = 2 })[name]
			check(live == wantTurns, tag .. ": " .. tostring(wantTurns) .. " live turns before the lock")
			local lx, lz = TrackLayout.railPoint(cfg, plan, pa.lockS, 1)
			check(close(lx, cfg.centerX - r1, 1e-6) and close(lz, cfg.centerZ + half, 1e-6), tag .. ": the lock is where the far turn starts")
		end
	end

	-- Drawn posts ------------------------------------------------------------------------------
	local permOk = true
	for seed = 1, 200 do
		local n = (seed % 8) + 1
		local order = RaceSession.drawPosts(n, makeRng(seed))
		local seen = {}
		if #order ~= n then permOk = false end
		for _, v in order do
			if seen[v] or v < 1 or v > n or v % 1 ~= 0 then permOk = false end
			seen[v] = true
		end
	end
	check(permOk, "drawPosts is a permutation")
	-- The switch: GameConfig.steering.drawPosts (on by default); off keeps the lanes as filled
	-- (humans first) and leaves the race's generator alone.
	check(GameConfig.steering ~= nil and GameConfig.steering.drawPosts == true, "posts are drawn by default")
	local calls = 0
	local counting = makeRng(77)
	local countingRng = {
		NextNumber = function(self): number
			calls += 1
			return counting:NextNumber()
		end,
	}
	local off = RaceSession.postOrder({ steering = { drawPosts = false } }, 8, countingRng)
	local identity = calls == 0
	for i = 1, 8 do
		if off[i] ~= i then identity = false end
	end
	check(identity and #off == 8, "drawPosts = false: humans-first lanes, no draws")
	local on = RaceSession.postOrder({ steering = { drawPosts = true } }, 8, makeRng(77))
	local direct = RaceSession.drawPosts(8, makeRng(77))
	local sameDraw = true
	for i = 1, 8 do
		if on[i] ~= direct[i] then sameDraw = false end
	end
	check(sameDraw, "drawPosts = true draws the posts")
	-- Every post is equally likely for the first human (lane 1 before the draw).
	local counts = table.create(8, 0)
	local rng = makeRng(99)
	local trials = 8000
	for _ = 1, trials do
		local order = RaceSession.drawPosts(8, rng)
		for post, old in order do
			if old == 1 then counts[post] += 1 end
		end
	end
	local even = true
	for post = 1, 8 do
		if math.abs(counts[post] - trials / 8) > 150 then even = false end -- about 5 sd
	end
	check(even, "the first human starts from every post about equally often")

	-- assignPosts keeps every horse's race and moves only its post.
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local humans = {
		{ id = "1", name = "Ava", rating = 60, isBot = false },
		{ id = "2", name = "Ben", rating = 55, isBot = false },
	}
	local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
	local function build(seed: number)
		local session = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
		session:setAverageOnly("2", true)
		session:setCrowd(1, 0.02)
		session:paceSchedule({ { 10, 36 } }, { { 10, 22 }, { 22, 34 }, { 34, 46 } })
		return session
	end
	local plain = build(31)
	local posted = build(31)
	local order = RaceSession.drawPosts(8, posted.rng) -- as RaceService: the race's generator, after the gate draws
	posted:assignPosts(order)
	local kept, humansMoved = true, false
	for post, old in order do
		local a, b = plain.lanes[old], posted.lanes[post]
		if a.id ~= b.id or a.rating ~= b.rating or a.averageOnly ~= b.averageOnly then kept = false end
		if plain.q[old] ~= posted.q[post] or plain.purses[old] ~= posted.purses[post] or plain.luck[old] ~= posted.luck[post]
			or plain.live[old] ~= posted.live[post] or (plain.crowd[old] or 0) ~= (posted.crowd[post] or 0) then
			kept = false
		end
		for seg in GameConfig.segments do
			if plain.botScores[seg][old] ~= posted.botScores[seg][post] then kept = false end
		end
		if not a.isBot and post ~= old then humansMoved = true end
	end
	check(kept, "assignPosts moves every per-horse value with its horse, bit for bit")
	check(humansMoved, "humans no longer start on the inside (this draw)")
	check(#plain.passes == #posted.passes, "the slider's passes are drawn before the posts")
	local passesSame = true
	for k, p in plain.passes do
		local o = posted.passes[k]
		if p.t0 ~= o.t0 or p.t1 ~= o.t1 or p.center ~= o.center or p.dir ~= o.dir then passesSame = false end
	end
	check(passesSame, "posts never move the gate draws (bots, luck, bot scores, passes)")
	-- The race plays the same: same scores by horse give the same chances and finish by horse.
	for seg, kind in GameConfig.segments do
		if kind == "pace" then
			for _, s in { plain, posted } do
				local taps = {}
				for _, p in s:pacePasses(seg) do table.insert(taps, PaceMeter.idealTime(p) + 0.03) end
				s:scorePace("1", seg, taps)
			end
		end
		plain:closeSegment(seg)
		posted:closeSegment(seg)
	end
	local liveSame = true
	for post, old in order do
		if not close(plain.live[old], posted.live[post], 1e-12) then liveSame = false end
	end
	check(liveSame, "live chances by horse are the same with drawn posts")
	local ra, rb = plain:finish(), posted:finish()
	local finishSame = #ra.prizes == #rb.prizes
	for k, prize in ra.prizes do
		local o = rb.prizes[k]
		if prize.id ~= o.id or prize.place ~= o.place or prize.cash ~= o.cash or prize.leaguePoints ~= o.leaguePoints then
			finishSame = false
		end
	end
	check(finishSame, "the finish and prizes by horse are the same with drawn posts")
	-- The ride report: each horse's place and the places its riding gained are the same.
	local placeA, placeB = {}, {}
	for place, lane in ra.order do placeA[lane] = place end
	for place, lane in rb.order do placeB[lane] = place end
	local reportSame = true
	for post, old in order do
		if placeA[old] ~= placeB[post] or plain:ridingGain(old) ~= posted:ridingGain(post) then reportSame = false end
	end
	check(reportSame, "ride report places and riding gain by horse are the same with drawn posts")
	local accepted = pcall(function() posted:assignPosts(order) end)
	check(not accepted, "posts can't be drawn after the race has run")
	local midRace = build(7)
	midRace:closeSegment(1)
	check(not pcall(function() midRace:assignPosts(RaceSession.drawPosts(8, makeRng(3))) end),
		"posts can't be drawn once the first checkpoint has closed")
	local bad = build(5)
	check(not pcall(function() bad:assignPosts({ 1, 1, 2, 3, 4, 5, 6, 7 }) end), "assignPosts refuses a non-permutation")
	check(not pcall(function() bad:assignPosts({ 1, 2, 3 }) end), "assignPosts needs one post per lane")
end
