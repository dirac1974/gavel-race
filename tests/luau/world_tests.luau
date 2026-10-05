--!strict
-- Tests for the world modules: Horse, Profile, NameGen (Stage 1), WorldLayout (Stage 2), the
-- Training Ground and training rides (D-053).
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local NameGen = require("../../game/src/shared/NameGen")
local RaceRating = require("../../game/src/shared/RaceRating")
local GameConfig = require("../../game/src/shared/GameConfig")
local WorldLayout = require("../../game/src/shared/WorldLayout")
local TrackLayout = require("../../game/src/shared/TrackLayout")

local function makeRng(seed0: number)
	local seed = seed0
	local function nextNumber(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	return {
		NextNumber = function(_self): number return nextNumber() end,
		NextInteger = function(_self, lo: number, hi: number): number
			return lo + math.floor(nextNumber() * (hi - lo + 1))
		end,
	}
end

-- Training Ground (D-053, T1): its own function, as the main test function is near Luau's
-- local-register limit.
local function trainingGroundTests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local W = WorldLayout
	local street = { W.STREET_X0, W.STREET_Z - W.STREET_WIDTH / 2, W.STREET_X1, W.STREET_Z + W.STREET_WIDTH / 2 }
	local lane = { W.LANE_X - W.LANE_WIDTH / 2, W.LANE_Z0, W.LANE_X + W.LANE_WIDTH / 2, W.LANE_Z1 }
	local course = { -1000, -2000, 640, 2000 }
	local TC = require("../../game/src/shared/TrainingCourses")
	local TCfg = GameConfig.training
	local ground = W.placeRect("trainingGround") :: { number }
	local paddockR = W.placeRect("paddock") :: { number }
	local link = W.trainingLink
	local function inside(r: { number }, x: number, z: number, m: number?): boolean
		local mm = m or 0
		return x >= r[1] + mm and x <= r[3] - mm and z >= r[2] + mm and z <= r[4] - mm
	end
	check(ground[1] == 650 and ground[3] == 950 and ground[2] == -70 and ground[4] == 70, "Training Ground covers x 650-950, z -70 to 70")
	-- No overlap with other places, plots, the street, the lane or the Trail.
	local tgOk = true
	for _, rect in { ground, link } do
		if not W.inBounds(rect) or W.overlaps(rect, street) or W.overlaps(rect, lane) or W.overlaps(rect, course) then tgOk = false end
		for i = 1, W.PLOT_COUNT do
			if W.overlaps(rect, W.plotRect(i)) then tgOk = false end
		end
		for key in W.places do
			local pr = W.placeRect(key)
			if pr and key ~= "trainingGround" and W.overlaps(rect, pr) then tgOk = false end
		end
		local pts = W.trail
		for k = 1, #pts - 1 do
			for s = 0, 20 do
				local x = pts[k].x + (pts[k + 1].x - pts[k].x) * s / 20
				local z = pts[k].z + (pts[k + 1].z - pts[k].z) * s / 20
				if inside(rect, x, z, -60) then tgOk = false end
			end
		end
		local m = W.meadow
		if inside(rect, m.x, m.z, -(m.radius + 20)) then tgOk = false end
	end
	check(tgOk, "Training Ground and its path clear of places, plots, streets, the racecourse and the Trail")
	check(link[1] < W.PADDOCK_SOUTH_GATE.x - W.TRAINING_PATH_WIDTH / 2 and link[3] > W.PADDOCK_SOUTH_GATE.x + W.TRAINING_PATH_WIDTH / 2
		and link[2] == paddockR[4] and link[4] == ground[2], "the path runs from the paddock's south fence to the Training Ground")
	local gateX = W.PADDOCK_SOUTH_GATE.x
	check(gateX - W.PADDOCK_SOUTH_GATE.width / 2 > paddockR[1] + 10 and gateX + W.PADDOCK_SOUTH_GATE.width / 2 < paddockR[3] - 10
		and TC.ENTRY.x0 < gateX - W.TRAINING_PATH_WIDTH / 2 and TC.ENTRY.x1 > gateX + W.TRAINING_PATH_WIDTH / 2,
		"south gate in the paddock fence lines up with the gap in the oval's rails")

	-- The oval: geometry round trip, fits the ground, rails clear of the edge.
	local O = TCfg.oval
	check(close(TC.LAP, 2 * O.straight + 2 * math.pi * O.radius, 1e-9) and close(TC.LAP, 665.575, 0.01), "oval lap ~666 studs")
	local roundTrip, fits = true, true
	for k = 0, 199 do
		local d = TC.LAP * k / 200
		for _, lat in { -TC.RAIL_LATERAL, -6, 0, 7, TC.RAIL_LATERAL } do
			local x, z, tx, tz, nx, nz = TC.ovalPoint(d, lat)
			local d2, l2 = TC.ovalProject(x, z)
			if math.abs(TC.wrap(d2 - d)) > 1e-6 or math.abs(l2 - lat) > 1e-6 then roundTrip = false end
			if math.abs(tx * tx + tz * tz - 1) > 1e-9 or math.abs(tx * nx + tz * nz) > 1e-9 then roundTrip = false end
			if not inside(ground, x, z, 1) then fits = false end
		end
	end
	check(roundTrip, "ovalPoint and ovalProject agree; tangent and normal are unit and square")
	check(fits, "oval rails sit inside the Training Ground")
	-- Counter-clockwise like the racecourse: the north straight heads west, then the turn bends south.
	local _, _, tx0, _ = TC.ovalPoint(10, 0)
	local _, _, _, tz1 = TC.ovalPoint(O.straight + 30, 0)
	check(tx0 < 0 and tz1 > 0, "the oval runs counter-clockwise (left turns)")
	check(TC.surfaceHeight(TC.courses.speed.posts[4].d) == TCfg.stamina.hill and TC.surfaceHeight(50) == 0
		and TC.surfaceHeight(O.straight + math.pi * O.radius + 40) > 0, "the hill rises on the south straight only")
	local gentle = true
	for k = 0, 400 do
		local d = TC.LAP * k / 400
		if math.abs(TC.surfaceHeight(d + 0.5) - TC.surfaceHeight(d - 0.5)) > 0.2 then gentle = false end -- under ~11°
	end
	check(gentle, "the hill is gentle (slope under 0.2)")

	-- Sprint Lane hoops lie on the track surface, inside the rails, spaced round the lap.
	local sp = TC.courses.speed
	local hoopsOk = #sp.posts == TCfg.speed.hoopsPerLap and #sp.hoops == TCfg.speed.laps * TCfg.speed.hoopsPerLap
	for _, p in sp.posts do
		local d2, l2 = TC.ovalProject(p.x, p.z)
		if math.abs(TC.wrap(d2 - p.d)) > 1e-6 or math.abs(l2 - p.lateral) > 1e-6 then hoopsOk = false end
		if math.abs(p.lateral) + p.width / 2 > O.width / 2 then hoopsOk = false end
		if p.y ~= TC.surfaceHeight(p.d) or p.y ~= TC.groundHeight(p.x, p.z) then hoopsOk = false end
		local gw = math.sqrt((p.gate.bx - p.gate.ax) ^ 2 + (p.gate.bz - p.gate.az) ^ 2)
		if math.abs(gw - TCfg.speed.hoopWidth) > 1e-9 then hoopsOk = false end
	end
	for i = 2, #sp.hoops do
		if sp.hoops[i].s <= sp.hoops[i - 1].s then hoopsOk = false end
	end
	if sp.hoops[1].s <= 0 or sp.hoops[#sp.hoops].s >= sp.finish then hoopsOk = false end
	check(hoopsOk, "18 hoops, 10 studs wide, on the track surface, in order between start and finish")
	check(sp.posts[4].y == TCfg.stamina.hill, "one hoop sits on top of the hill")

	-- Gate Break: the practice gate, its lane and loop stay in the infield.
	local ac = TC.courses.accel
	local infieldOk = true
	for _, pt in ac.route.points do
		local _, lat = TC.ovalProject(pt.x, pt.z)
		if lat > -O.width / 2 - 4 or not inside(ground, pt.x, pt.z, 5) then infieldOk = false end
	end
	if not (ac.stall[1] < ac.start.x and ac.start.x < ac.stall[3]) then infieldOk = false end
	check(infieldOk, "practice gate, lane and loop inside the infield")
	check(close(ac.flag.ax - ac.doorX, TCfg.accel.dash, 1e-9), "the flag is the dash length from the gate")

	-- Hill Climb: Pip is deterministic, keeps to the track and to its pace range.
	local p1, p2 = TC.ponyAt(42, 12.3), TC.ponyAt(42, 12.3)
	local p3 = TC.ponyAt(43, 12.3)
	check(p1.x == p2.x and p1.z == p2.z and p1.speed == p2.speed, "ponyAt is deterministic for a seed")
	check(p1.x ~= p3.x or p1.lateral ~= p3.lateral, "different seeds weave differently")
	local ponyOk, last = true, -math.huge
	for _, seed in { 1, 7, 99, 123456, 2147483000 } do
		last = -math.huge
		for k = 0, 600 do
			local t = k * 0.1
			local pp = TC.ponyAt(seed, t)
			if not TC.onOval(pp.x, pp.z, -2) then ponyOk = false end
			if pp.speed < TCfg.stamina.ponyMin - 1e-9 or pp.speed > TCfg.stamina.ponyMax + 1e-9 then ponyOk = false end
			if pp.s < last then ponyOk = false end
			if math.abs(pp.y - TC.surfaceHeight(pp.d)) > 1e-9 then ponyOk = false end
			last = pp.s
		end
	end
	check(ponyOk, "Pip stays on the track, between 30 and 42 studs/s, always going forward")
	local s0 = TC.ponyAt(5, 0)
	local _, sl = TC.ovalProject(s0.x, s0.z)
	check(close(s0.s, (TCfg.stamina.ringNear + TCfg.stamina.ringFar) / 2, 1e-9) and math.abs(sl) < 1e-6, "Pip starts in the middle of the ring ahead of you")

	-- Mud Splash: every gymkhana piece inside the arena, on the route, logs low and clear of the walkway.
	local gr = TC.courses.grit
	local counts = { mud = 0, log = 0, pole = 0 }
	local points, gymOk = 0, true
	local function nearRoute(x: number, z: number): number
		local best = math.huge
		local pts = gr.route.points
		for k = 2, #pts do
			local ax, az, bx, bz = pts[k - 1].x, pts[k - 1].z, pts[k].x, pts[k].z
			local dx, dz = bx - ax, bz - az
			local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
			best = math.min(best, math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2))
		end
		return best
	end
	for _, e in gr.elements do
		counts[e.kind] += 1
		points += e.points
		if not inside(paddockR, e.x, e.z, 8) then gymOk = false end
		if e.rect and not (inside(paddockR, e.rect[1], e.rect[2], 5) and inside(paddockR, e.rect[3], e.rect[4], 5)) then gymOk = false end
		if e.gate and not (inside(paddockR, e.gate.ax, e.gate.az, 5) and inside(paddockR, e.gate.bx, e.gate.bz, 5)) then gymOk = false end
		if e.kind == "pole" then
			if math.abs(nearRoute(e.x, e.z) - TC.POLE_REACH.weave) > 1 then gymOk = false end -- the route weaves round it
		elseif nearRoute(e.x, e.z) > 0.5 then
			gymOk = false
		end
		if e.kind == "log" and math.abs(e.x - gateX) < W.PADDOCK_SOUTH_GATE.width / 2 + 5 then gymOk = false end
	end
	for _, pt in gr.route.points do
		if not inside(paddockR, pt.x, pt.z, 3) then gymOk = false end
	end
	check(gymOk, "gymkhana pieces inside the arena and on the route; logs clear of the gate-to-gate walkway")
	check(counts.mud == TCfg.grit.mud and counts.log == TCfg.grit.logs and counts.pole == TCfg.grit.poles and close(points, 100, 1e-9),
		"4 puddles, 3 logs, 4 poles worth 100 points")
	check(TCfg.grit.logHeight < TC.RIDE_HOP and close(TC.RIDE_HOP, 42 * 42 / (2 * 196.2), 0.01), "logs are lower than the ride horse's hop")
	check(TCfg.grit.airborne < TC.RIDE_HOP - 1, "a hop clears the log-height test")
	local slowOk = true
	for _, e in gr.elements do
		local inZone = TC.inRect(gr.slowZone, e.x, e.z)
		if (e.kind == "pole") ~= inZone then slowOk = false end
	end
	check(slowOk and TC.speedAt("grit", gr.elements[5].x, gr.elements[5].z) == TCfg.canter
		and TC.speedAt("grit", gr.elements[1].x, gr.elements[1].z) == TCfg.grit.pace
		and TC.speedAt("speed", 800, -55) == TCfg.gallop, "poles (only) sit in the canter zone")
	check(TC.onCourse("grit", gr.start.x, gr.start.z) and TC.onCourse("speed", sp.start.x, sp.start.z)
		and not TC.onCourse("speed", 800, 0) and TC.inArea("speed", 800, 0) and not TC.inArea("speed", 760, -200),
		"course bounds: the infield is off the Sprint Lane course but inside its area")

	-- Ideal times at the configured speeds (35-50 s per D-053).
	for _, key in TC.ORDER do
		local ideal = TC.idealSeconds(key)
		check(ideal >= 35 and ideal <= 50, string.format("%s ideal time %.1f s is 35-50 s", key, ideal))
		check(close(TC.parSeconds(key), ideal * TCfg.parFactor, 1e-9), key .. " par")
	end
	local stamOk = true
	for seed = 1, 40 do
		local ideal = TC.idealSeconds("stamina", seed * 7919)
		if ideal < 35 or ideal > 50 then stamOk = false end
	end
	check(stamOk, "Hill Climb is 35-50 s for any seed")

	-- Picture signs: one per course, standing in the path's rect, the ground or the arena.
	local seen = {}
	local signsOk = true
	for _, s in TC.signs do
		seen[s.course] = true
		local half = TC.SIGN_SIZE.w / 2
		local r = { s.x - half, s.z - half, s.x + half, s.z + half }
		local okIn = inside(link, r[1], s.z, 0) and inside(link, r[3], s.z, 0)
			or inside(ground, s.x, s.z, 1) or inside(paddockR, r[1], s.z, 1) and inside(paddockR, r[3], s.z, 1)
		if not okIn then signsOk = false end
		if math.abs(s.x - gateX) < W.TRAINING_PATH_WIDTH / 2 + half and inside(link, s.x, s.z, 0) then signsOk = false end -- not on the path
	end
	for _, key in TC.ORDER do
		if not seen[key] then signsOk = false end
	end
	check(signsOk, "a picture sign for every course, off the path, inside the training areas")
end

-- Training rides (D-053, T2): server scoring from synthetic sample paths.
local function trainingRideTests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local TC = require("../../game/src/shared/TrainingCourses")
	local TR = require("../../game/src/shared/TrainingRide")
	local Training = require("../../game/src/shared/Training")
	local CFG = GameConfig.training
	local HZ = CFG.sampleHz
	local T0 = 20000 * 86400 + 3600
	local sp = TC.courses.speed
	local gr = TC.courses.grit

	-- Sprint Lane paths: ride the oval from the start at `speed`, with `latAt(progress)`.
	local function hoopLateral(p: number): number
		-- through the middle of every hoop: straight lines between consecutive hoops
		local prevS, prevL = 0, sp.posts[#sp.posts].lateral
		for _, hp in sp.hoops do
			local l = sp.posts[hp.post].lateral
			if p <= hp.s then
				return prevL + (l - prevL) * (p - prevS) / (hp.s - prevS)
			end
			prevS, prevL = hp.s, l
		end
		return prevL
	end
	local function latByD(d: number): number
		local posts = sp.posts
		for k = 1, #posts do
			local a, b = posts[k], posts[(k % #posts) + 1]
			local span = (b.d - a.d) % TC.LAP
			local into = (d - a.d) % TC.LAP
			if into <= span then return a.lateral + (b.lateral - a.lateral) * into / span end
		end
		return 0
	end
	local function ovalRide(latAt: (number) -> number, opts: any?)
		local o = opts or {}
		local speed = o.speed or CFG.gallop
		local dirn = o.backwards and -1 or 1
		local out = {}
		local k = 0
		local total = o.distance or (sp.finish + 8)
		while true do
			local p = speed * k / HZ
			if p > total then break end
			local x, z = TC.ovalPoint(sp.startD + dirn * p + (o.from or 0), latAt(p))
			table.insert(out, { t = k / HZ, x = x, y = 0, z = z })
			k += 1
		end
		return out
	end

	local perfect = ovalRide(hoopLateral)
	local kept, bad = TR.validate(perfect, function(x, z) return TC.onCourse("speed", x, z) end, CFG)
	check(bad == 0 and #kept == #perfect, "an honest gallop keeps every sample")
	local raw, detail = TR.scoreSpeed(kept, CFG)
	check(raw == 100 and detail.hoops == 18, string.format("perfect Sprint Lane scores 100 (%d hoops)", detail.hoops))
	check(detail.finishT ~= nil and close(detail.finishT, sp.finish / CFG.gallop, 0.05), "finish time at three laps")
	local tr = TR.tracker("speed")
	local finishedAt = nil
	for _, s in perfect do
		if TR.feed(tr, s, CFG) and not finishedAt then finishedAt = s.t end
	end
	check(tr.finished and close(tr.finishT :: number, sp.finish / CFG.gallop, 0.05) and finishedAt ~= nil, "the live tracker finishes after three laps")
	check(TR.laps(tr) == 3 and TR.nextHoop(tr) == nil, "three lap dots, no hoop left")
	local tr2 = TR.tracker("speed")
	check(TR.nextHoop(tr2) == sp.hoops[1] and TR.laps(tr2) == 0, "the first hoop glows first")
	local res = TR.run("speed", perfect, CFG, tr.finishT)
	check(res.score == 100 and res.stars == 3 and res.ribbon == "gold" and res.underPar and not res.flagged, "perfect ride: 3 stars, gold")
	local slow = TR.finalize(100, 0, res.par + 1, TC.idealSeconds("speed"), CFG)
	check(slow.ribbon == "silver" and slow.stars == 3, "gold needs under par; over par is silver")

	-- Missed hoops: the first lap on the inside edge misses all six.
	local missLap = ovalRide(function(p: number): number
		local f = math.clamp((p - TC.LAP) / 40, 0, 1)
		return -11 * (1 - f) + hoopLateral(p) * f
	end)
	local mk = TR.validate(missLap, function(x, z) return TC.onCourse("speed", x, z) end, CFG)
	local mraw, md = TR.scoreSpeed(mk, CFG)
	check(md.hoops == 12 and close(mraw, 100 * 12 / 18, 1e-9), "missed hoops just don't count (12 of 18)")
	local mres = TR.finalize(mraw, 0, 44, TC.idealSeconds("speed"), CFG)
	check(mres.stars == 2 and mres.ribbon == "bronze", "66.7: two stars and a bronze ribbon for finishing")
	check(TR.finalize(20, 0, 44, 43, CFG).stars == 1 and TR.finalize(60, 0, 44, 43, CFG).stars == 2
		and TR.finalize(90, 0, 44, 43, CFG).stars == 3 and TR.finalize(75, 0, 44, 43, CFG).ribbon == "silver", "star and ribbon thresholds")

	-- Reversed and out-of-order crossings don't count.
	local back = ovalRide(function(p: number): number return latByD(sp.startD - p) end, { backwards = true, distance = TC.LAP })
	local bk = TR.validate(back, nil, CFG)
	local braw = TR.scoreSpeed(bk, CFG)
	local reversed = 0
	for _, post in sp.posts do
		for _, x in TR.crossings(bk, post.gate) do
			if x.dir < 0 then reversed += 1 end
		end
	end
	check(braw == 0 and reversed == 6, "riding the oval backwards crosses every hoop in reverse and scores 0")
	local h2 = sp.posts[2]
	local skip = {}
	for k = 0, 12 do
		local x, z = TC.ovalPoint(h2.d - 30 + k * 4.6, h2.lateral)
		table.insert(skip, { t = k / HZ, x = x, y = 0, z = z })
	end
	local sraw = TR.scoreSpeed(TR.validate(skip, nil, CFG), CFG)
	local fwd = TR.crossings(skip, h2.gate)
	check(#fwd == 1 and fwd[1].dir == 1 and sraw == 0, "hoop 2 ridden before hoop 1 (out of order) doesn't count")
	local twice = {}
	local h1 = sp.posts[1]
	for k, step in { -10, -5, 0, 5, 10, 5, 0, -5, -10, -5, 0, 5, 10 } do
		local x, z = TC.ovalPoint(h1.d + step, 0)
		table.insert(twice, { t = (k - 1) / HZ, x = x, y = 0, z = z })
	end
	local tw = TR.validate(twice, nil, CFG)
	local _, twd = TR.scoreSpeed(tw, CFG)
	check(twd.hoops == 1, "back and forth through a hoop counts it once")
	-- Round the outside of hoop 1, then back through it the wrong way: right place, wrong way.
	local wrongWay = {}
	local function addAt(d: number, lat: number)
		local x, z = TC.ovalPoint(d, lat)
		table.insert(wrongWay, { t = #wrongWay / HZ, x = x, y = 0, z = z })
	end
	for d = sp.startD, h1.d + 6, 4 do addAt(d, 9) end
	for lat = 9, 0, -3 do addAt(h1.d + 6, lat) end
	for d = h1.d + 4, h1.d - 8, -4 do addAt(d, 0) end
	local _, wwd = TR.scoreSpeed(TR.validate(wrongWay, nil, CFG), CFG)
	local wwx = TR.crossings(wrongWay, h1.gate)
	check(#wwx == 1 and wwx[1].dir == -1 and wwd.hoops == 0, "a hoop ridden through backwards doesn't count")

	-- Validation: teleports and anything over 53 studs/s are discarded.
	local line = {}
	for k = 0, 19 do table.insert(line, { t = k / HZ, x = 850 - k * 4.6, y = 0, z = -55 }) end
	local spike = table.clone(line)
	spike[10] = { t = spike[10].t, x = spike[10].x, y = 0, z = -55 + 30 }
	local vk, vb = TR.validate(spike, nil, CFG)
	check(#vk == 18 and close(vb, 2 / 20, 1e-9), "a teleport spike drops it and the sample after")
	check(vk[10].gap == false, "a plausible move over dropped samples (jitter) still counts")
	local jump = table.clone(line)
	for k = 11, 20 do jump[k] = { t = line[k].t, x = line[k].x - 40, y = 0, z = -55 } end
	local jk, jb = TR.validate(jump, nil, CFG)
	check(close(jb, 1 / 20, 1e-9) and jk[11].gap == true, "a teleport ahead is dropped and marks a gap")
	check(#TR.crossings(jk, { ax = 785, az = -100, bx = 785, bz = 100, nx = -1, nz = 0 }) == 0, "nothing counts across a teleport")
	local hop = table.clone(line)
	hop[10] = { t = hop[10].t, x = hop[10].x, y = 13, z = -55 }
	local _, hb = TR.validate(hop, nil, CFG)
	check(close(hb, 2 / 20, 1e-9), "a 13-stud jump between samples is a teleport")
	local fast = {}
	for k = 0, 19 do table.insert(fast, { t = k / HZ, x = 850 - k * 5.4, y = 0, z = -55 }) end
	local _, fb = TR.validate(fast, nil, CFG)
	check(close(fb, 19 / 20, 1e-9), "54 studs/s is too fast: every step dropped")
	local okFast = {}
	for k = 0, 19 do table.insert(okFast, { t = k / HZ, x = 850 - k * 5.2, y = 0, z = -55 }) end
	local _, ob = TR.validate(okFast, nil, CFG)
	check(ob == 0, "52 studs/s is fine")
	local offk, offb, offc = TR.validate(line, function(x, z) return x > 820 end, CFG)
	check(#offk == 7 and offc.off == 13 and offb == 0, "samples off the course don't score and don't count toward the floor")
	check(#TR.crossings(vk, { ax = 805, az = -100, bx = 805, bz = 100, nx = -1, nz = 0 }) == 1, "a crossing over a jitter drop still counts")

	-- More than 10% dropped: the floor when enforcing, a normal score while log-only.
	local jittery = table.clone(perfect)
	for k = 7, #jittery - 1, 14 do
		local s = jittery[k]
		jittery[k] = { t = s.t, x = s.x + 25, y = 0, z = s.z }
	end
	local enforce = table.clone(CFG)
	enforce.enforceFloor = true
	local logOnly = TR.run("speed", jittery, CFG, 43.5)
	local floored = TR.run("speed", jittery, enforce, 43.5)
	check(logOnly.flagged and not logOnly.floored and logOnly.score > 80, string.format("log-only: flagged (%.0f%% dropped) but scored %.0f", logOnly.badShare * 100, logOnly.score))
	check(floored.flagged and floored.floored and floored.score == 0 and floored.stars == 1 and floored.ribbon == "bronze",
		"enforcing: scored at the 0.5 floor with a normal end card")
	local fewDrops = table.clone(perfect)
	fewDrops[50] = { t = fewDrops[50].t, x = fewDrops[50].x + 25, y = 0, z = fewDrops[50].z }
	local fd = TR.run("speed", fewDrops, enforce, 43.5)
	check(not fd.flagged and fd.score == 100, "a couple of drops are harmless even when enforcing")

	-- Mud Splash: walk the route (lope, canter in the pole lane), hopping each log.
	local function gritRide(opts: any?)
		local o = opts or {}
		local pts = table.clone(gr.route.points)
		local last, prev = pts[#pts], pts[#pts - 1]
		local dx, dz = last.x - prev.x, last.z - prev.z
		local len = math.sqrt(dx * dx + dz * dz)
		table.insert(pts, { x = last.x + dx / len * 6, z = last.z + dz / len * 6 }) -- ride on past the finish
		local out = {}
		local x, z = pts[1].x, pts[1].z
		local seg, t = 2, 0
		local function yAt(px: number, pz: number): number
			if not o.hop then return 0 end
			for _, e in gr.elements do
				if e.kind == "log" and math.abs(pz - e.z) < 3 and math.abs(px - e.x) < 6.5 then
					return TC.RIDE_HOP * (1 - ((px - e.x) / 6.5) ^ 2)
				end
			end
			return 0
		end
		local function offset(px: number, pz: number): number
			return if o.shift then o.shift(px, pz) else 0
		end
		table.insert(out, { t = 0, x = x, y = yAt(x, z), z = z })
		while seg <= #pts do
			local remaining = (o.speed or TC.speedAt("grit", x, z)) / HZ
			while remaining > 0 and seg <= #pts do
				local bx, bz = pts[seg].x, pts[seg].z
				local ddx, ddz = bx - x, bz - z
				local l = math.sqrt(ddx * ddx + ddz * ddz)
				if l <= remaining then
					x, z, remaining, seg = bx, bz, remaining - l, seg + 1
				else
					x, z, remaining = x + ddx / l * remaining, z + ddz / l * remaining, 0
				end
			end
			t += 1 / HZ
			table.insert(out, { t = t, x = x, y = yAt(x, z), z = z + offset(x, z) })
		end
		return out
	end
	local clean = gritRide({ hop = true })
	local gk, gb = TR.validate(clean, function(x, z) return TC.onCourse("grit", x, z) end, CFG)
	local graw, gd = TR.scoreGrit(gk, CFG)
	check(gb == 0 and graw == 100 and gd.mud == 4 and gd.logs == 3 and gd.poles == 4,
		string.format("perfect Mud Splash scores 100 (%d mud, %d logs, %d poles)", gd.mud, gd.logs, gd.poles))
	check(gd.finishT ~= nil and close(gd.finishT, TC.idealSeconds("grit"), 1.0), "finishes at about its ideal time")
	local gtr = TR.tracker("grit")
	for _, s in clean do TR.feed(gtr, s, CFG) end
	check(gtr.finished and gtr.next == #gr.elements + 1, "the live tracker passes every piece and finishes")
	local gres = TR.run("grit", clean, CFG, gtr.finishT)
	check(gres.score == 100 and gres.ribbon == "gold" and gres.stars == 3, "clean gymkhana: gold")
	local grounded = gritRide({ hop = false })
	local graw2, gd2 = TR.scoreGrit(TR.validate(grounded, nil, CFG), CFG)
	check(gd2.logs == 0 and gd2.mud == 4 and gd2.poles == 4 and close(graw2, 64, 1e-9), "logs ridden through without a hop don't score (no penalty)")
	-- Wrong side of the poles: mirror the weave.
	local poleZ = gr.laneZ(4)
	local wrong = gritRide({ hop = true, shift = function(px: number, pz: number): number
		if math.abs(pz - poleZ) < 6 and px > gr.laneX[1] and px < gr.laneX[2] then return 2 * (poleZ - pz) end
		return 0
	end })
	local _, gd3 = TR.scoreGrit(TR.validate(wrong, nil, CFG), CFG)
	check(gd3.poles == 0 and gd3.mud == 4 and gd3.logs == 3, "poles passed on the wrong side don't count")
	-- Wide of a puddle: lane 1 ridden 8 studs north misses Mud1 only.
	local wide = gritRide({ hop = true, shift = function(px: number, pz: number): number
		if math.abs(pz - gr.laneZ(1)) < 0.01 and px > gr.laneX[1] then return -8 end
		return 0
	end })
	local _, gd4 = TR.scoreGrit(TR.validate(wide, nil, CFG), CFG)
	check(gd4.mud == 3 and not gd4.got.Mud1 and gd4.got.Mud2, "a puddle ridden round doesn't count; the rest do")
	-- Individual cases: a hop seen only between samples still counts; a pole through its middle doesn't.
	local log = gr.elements[2]
	local hopPath = {
		{ t = 0, x = log.x + 4.2, y = 0.5, z = log.z },
		{ t = 0.1, x = log.x + 1.4, y = 2.8, z = log.z },
		{ t = 0.2, x = log.x - 1.4, y = 2.9, z = log.z },
		{ t = 0.3, x = log.x - 4.2, y = 0.4, z = log.z },
	}
	local hx = TR.crossings(hopPath, log.gate)
	check(#hx == 1 and hx[1].dir == 1 and TR.cleared(hopPath, hx[1], log, CFG.grit), "airborne over the log: clean hop")
	local lowPath = table.clone(hopPath)
	for i, s in lowPath do lowPath[i] = { t = s.t, x = s.x, y = 0.2, z = s.z } end
	check(not TR.cleared(lowPath, TR.crossings(lowPath, log.gate)[1], log, CFG.grit), "on the ground over the log: no hop")
	local early = { { t = 0, x = log.x + 9, y = 3, z = log.z }, { t = 0.1, x = log.x + 6, y = 2, z = log.z },
		{ t = 0.2, x = log.x + 3.1, y = 0, z = log.z }, { t = 0.3, x = log.x - 0.2, y = 0, z = log.z } }
	check(not TR.cleared(early, TR.crossings(early, log.gate)[1], log, CFG.grit), "a hop that lands before the log doesn't count")
	local pole = gr.elements[5]
	local through = { { t = 0, x = pole.x + 3, y = 0, z = pole.z }, { t = 0.1, x = pole.x - 3, y = 0, z = pole.z } }
	local sideZ = pole.weaveZ
	local around = { { t = 0, x = pole.x + 3, y = 0, z = sideZ }, { t = 0.1, x = pole.x - 3, y = 0, z = sideZ } }
	local otherZ = 2 * pole.z - sideZ
	local wrongSide = { { t = 0, x = pole.x + 3, y = 0, z = otherZ }, { t = 0.1, x = pole.x - 3, y = 0, z = otherZ } }
	check(#TR.crossings(through, pole.gate) == 0 and #TR.crossings(around, pole.gate) == 1 and #TR.crossings(wrongSide, pole.gate) == 0,
		"a pole counts only when passed on its side, not through it")
	local mud = gr.elements[1]
	local splash = { { t = 0, x = mud.x - 9, y = 0, z = mud.z + 5 }, { t = 0.1, x = mud.x - 6.5, y = 0, z = mud.z + 5 } }
	local _, sd = TR.scoreGrit(splash, CFG)
	check(sd.mud == 1 and sd.got.Mud1, "one sample inside a puddle splashes it")
	-- The finish only counts after a fair part of the course.
	local f = gr.finish
	local rush = { { t = 1, x = f.ax + 3, y = 0, z = (f.az + f.bz) / 2 }, { t = 1.1, x = f.ax - 1, y = 0, z = (f.az + f.bz) / 2 } }
	local _, rd = TR.scoreGrit(rush, CFG)
	local rtr = TR.tracker("grit")
	for _, s in rush do TR.feed(rtr, s, CFG) end
	check(rd.finishT == nil and not rtr.finished, "crossing the finish early doesn't end the ride")

	-- Session limits.
	local hist = {}
	local ok1 = TR.rateCheck(hist, 1000, CFG)
	table.insert(hist, 1000)
	local ok2, why2 = TR.rateCheck(hist, 1000 + CFG.sessionGapSeconds - 0.5, CFG)
	local ok3 = TR.rateCheck(hist, 1000 + CFG.sessionGapSeconds, CFG)
	check(ok1 and not ok2 and why2 == "gap" and ok3, "sessions at least 4 s apart")
	local full = {}
	for k = 1, CFG.maxSessionsPerHour do table.insert(full, 5000 + k * 10) end
	local ok4, why4 = TR.rateCheck(full, 5000 + CFG.maxSessionsPerHour * 10 + 30, CFG)
	local ok5 = TR.rateCheck(full, 5000 + 10 + 3600 + 1, CFG)
	check(not ok4 and why4 == "hour" and ok5 and #full == CFG.maxSessionsPerHour - 1, "at most 40 an hour; old ones drop off")

	-- Gain: the D-040 formula and weekly cap, quality = 0.5 + 0.5 × score / 100, no Energy.
	local gh = Horse.starter("h1", "Pepper", "black", makeRng(11), T0)
	local energy = gh.energy
	local expect = math.floor(Training.gain(gh, "speed", 100, T0) * 10 + 0.5) / 10
	local qh = Horse.starter("h6", "Dot", "bay", makeRng(16), T0)
	qh.training = { week = -1, gained = 0, lastAt = T0 }
	qh.stats.speed = qh.potential.speed - 10
	local half = Training.gain(qh, "speed", 0, T0) / Training.gain(qh, "speed", 100, T0)
	local g1 = TR.applyGain(gh, "speed", 100, T0)
	check(close(half, 0.5, 1e-9) and close(g1.gained, expect, 1e-9) and g1.rested and g1.capped == nil
		and close(g1.after, g1.before + g1.gained, 1e-9), "a ride gains through the training formula (rested)")
	check(gh.energy == energy, "training rides cost no Energy")
	local guard = 0
	local last = g1
	while last.capped == nil and guard < 20 do
		guard += 1
		last = TR.applyGain(gh, "accel", 100, T0 + guard * 60)
	end
	local speedNow = gh.stats.speed
	local capped = TR.applyGain(gh, "speed", 100, T0 + 3600)
	check(last.capped == "week" and capped.capped == "week" and capped.gained == 0 and gh.stats.speed == speedNow
		and close(Training.gainedThisWeek(gh, T0), Training.WEEKLY_CAP, 1e-9), "after the weekly cap rides gain nothing")
	local fullH = Horse.starter("h2", "Comet", "grey", makeRng(12), T0)
	fullH.stats.grit = fullH.potential.grit
	check(TR.applyGain(fullH, "grit", 100, T0).capped == "full", "at Potential: as high as it goes")
	check(TR.quickScore(100, CFG) == 70 and 0.5 + 0.5 * TR.quickScore(100, CFG) / 100 == CFG.quickQualityCap
		and TR.quickScore(40, CFG) == 40, "Quick train quality capped at 0.85")

	-- Ribbons and best runs on the horse, saved and repaired.
	local rh = Horse.starter("h3", "Biscuit", "bay", makeRng(13), T0)
	local nr1 = TR.record(rh, "speed", { ribbon = "silver", score = 80, seconds = 47.04 })
	local nr2 = TR.record(rh, "speed", { ribbon = "bronze", score = 50, seconds = 45 })
	local nr3, nb3 = TR.record(rh, "speed", { ribbon = "silver", score = 80, seconds = 46 })
	check(nr1 and not nr2 and not nr3 and nb3 and rh.ribbons.speed == "silver" and rh.trainingBest.speed.score == 80
		and rh.trainingBest.speed.seconds == 46, "best ribbon kept; best run by score, then time")
	local saved = Profile.new(T0)
	Profile.addHorse(saved, rh)
	local bare = Horse.starter("h4", "Maple", "chestnut", makeRng(14), T0)
	bare.ribbons = { speed = "gold", grit = "platinum", luck = "gold" }
	bare.trainingBest = { speed = { score = 120, seconds = "41.5" }, grit = "junk", accel = { score = 0 / 0, seconds = 3 } }
	Profile.addHorse(saved, bare)
	local plain = Horse.starter("h5", "Pip", "grey", makeRng(15), T0)
	Profile.addHorse(saved, plain)
	local loaded = Profile.migrate(saved, T0)
	local a, b, c = loaded.horses[1], loaded.horses[2], loaded.horses[3]
	check(a.ribbons.speed == "silver" and a.trainingBest.speed.seconds == 46, "ribbons and best runs survive a save")
	check(b.ribbons.speed == "gold" and b.ribbons.grit == nil and b.ribbons.luck == nil and b.trainingBest.speed.score == 100
		and b.trainingBest.speed.seconds == 41.5 and b.trainingBest.grit == nil and b.trainingBest.accel == nil, "migration repairs bad ribbons and runs")
	check(typeof(c.ribbons) == "table" and next(c.ribbons) == nil and typeof(c.trainingBest) == "table", "older horses get empty records")
	local view = Horse.view(a, T0, GameConfig.energy)
	check(view.ribbons.speed == "silver" and view.trainingBest.speed.score == 80, "the owner's view shows ribbons and best runs")
end

-- Training rides: network freezes, catch-ups and timeouts (PR #35 review).
local function trainingJitterTests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local TC = require("../../game/src/shared/TrainingCourses")
	local TR = require("../../game/src/shared/TrainingRide")
	local CFG = GameConfig.training
	local HZ = CFG.sampleHz
	local sp = TC.courses.speed

	local function hoopLateral(p: number): number
		local prevS, prevL = 0, sp.posts[#sp.posts].lateral
		for _, hp in sp.hoops do
			local l = sp.posts[hp.post].lateral
			if p <= hp.s then return prevL + (l - prevL) * (p - prevS) / (hp.s - prevS) end
			prevS, prevL = hp.s, l
		end
		return prevL
	end
	-- A perfect gallop seen through the network: observed(k) is the sample time whose true
	-- position the server sees at sample k (a freeze repeats an earlier one). The ride carries
	-- on 30 studs past the line, as a real horse does.
	local function ride(observed: (number) -> number)
		local out = {}
		local k = 0
		while CFG.gallop * k / HZ <= sp.finish + 30 do
			local p = CFG.gallop * observed(k) / HZ
			local x, z = TC.ovalPoint(sp.startD + p, hoopLateral(p))
			table.insert(out, { t = k / HZ, x = x, y = 0, z = z })
			k += 1
		end
		return out
	end
	local function judge(samples)
		local tr = TR.tracker("speed")
		for _, s in samples do TR.feed(tr, s, CFG) end
		local res = TR.run("speed", samples, CFG, tr.finishT)
		return res, tr
	end
	local ideal = sp.finish / CFG.gallop

	-- One freeze then a catch-up, right on a hoop crossing and between hoops.
	local hoopK = math.floor(sp.hoops[3].s / CFG.gallop * HZ + 0.5)
	for _, at in { hoopK, hoopK + 1, 57, 200 } do
		for _, len in { 1, 2 } do
			local res, tr = judge(ride(function(k: number): number
				if k >= at and k < at + len then return at - 1 end
				return k
			end))
			check(res.detail.hoops == 18 and res.counts.bad == 0 and res.counts.stale == len and tr.finished
				and close(tr.finishT :: number, ideal, 0.1),
				string.format("freeze of %d00 ms at sample %d, then a catch-up: 18/18 and done at the line (%d hoops)", len, at, res.detail.hoops))
		end
	end
	-- Ten 100 ms freezes (the review's repro).
	local res10, tr10 = judge(ride(function(k: number): number
		if k >= 40 and k <= 400 and k % 40 == 0 then return k - 1 end
		return k
	end))
	check(res10.detail.hoops == 18 and res10.score == 100 and tr10.finished and close(tr10.finishT :: number, ideal, 0.1)
		and res10.ribbon == "gold", "ten 100 ms freezes: 18/18, gold, finished at the line")

	-- A lag-then-burst catch-up (too fast for one sample, no teleport) over a hoop.
	local burst, burstTr = judge(ride(function(k: number): number
		if k == hoopK - 1 or k == hoopK then return hoopK - 2 end
		if k == hoopK + 1 then return hoopK end
		return k
	end))
	check(burst.detail.hoops == 18 and burstTr.finished, "a burst after lag still counts the hoop it crossed")
	-- A forward jump bigger than a sample allows is clamped, then re-synced at the next hoop.
	local jumpRes, jumpTr = judge(ride(function(k: number): number
		if k >= 100 then return k + 4 end
		return k
	end))
	check(jumpRes.detail.hoops == 18 and jumpTr.finished, "an over-large jump loses only a little, back in step at the next hoop")

	-- Freezes whose replica wobbles a hair (so not exactly stale): the catch-up is clamped,
	-- not thrown away, and progress snaps back onto each hoop.
	local wobble, wobbleTr = judge(ride(function(k: number): number
		if k >= 20 and k <= 420 and k % 10 == 0 then return k - 1 + 0.0003 end
		return k
	end))
	check(wobble.detail.hoops == 18 and wobbleTr.finished and close(wobbleTr.finishT :: number, ideal, 0.25),
		string.format("40 wobbly freezes: 18/18 and the live tracker ends at the line (%d hoops, %.2f s vs %.2f)",
			wobble.detail.hoops, wobbleTr.finishT or -1, ideal))

	-- Wobbly freezes on the run-in after the last hoop (nothing to snap back onto): clamped.
	local lastK = math.floor(sp.hoops[#sp.hoops].s / CFG.gallop * HZ) + 2
	local runIn, runInTr = judge(ride(function(k: number): number
		if k == lastK + 2 or k == lastK + 6 or k == lastK + 10 then return k - 1 + 0.0003 end
		return k
	end))
	check(runIn.detail.hoops == 18 and runInTr.finished and close(runInTr.finishT :: number, ideal, 0.25),
		"freezes on the run-in to the line still end the ride at the line")

	-- 1% random 100-200 ms freezes, back-to-back ones included, on 100 rides.
	local seed = 7
	local function rnd(): number
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local all18, allLine, worstBad = true, true, 0
	for _ = 1, 100 do
		local frozen: { [number]: number } = {}
		local left, at = 0, 0
		for k = 0, 500 do
			if left > 0 then
				frozen[k] = at
				left -= 1
			elseif k > 5 and rnd() < 0.01 then
				at = k - 1
				frozen[k] = at
				left = if rnd() < 0.5 then 0 else 1
			end
		end
		local res, tr = judge(ride(function(k: number): number return frozen[k] or k end))
		if res.detail.hoops ~= 18 then all18 = false end
		if not tr.finished or math.abs((tr.finishT :: number) - ideal) > 0.25 then allLine = false end
		worstBad = math.max(worstBad, res.badShare)
	end
	check(all18, "1% random 100-200 ms freezes: every perfect ride scores 18/18")
	check(allLine, "1% random freezes: every ride ends at the line")
	check(worstBad <= CFG.maxBadShare / 2, string.format("freezes stay well under the floor (worst %.3f)", worstBad))

	-- Stale and stopped: a frozen replica is skipped; a horse standing still stays.
	local line = {}
	for k = 0, 9 do table.insert(line, { t = k / HZ, x = 850 - k * 4.6, y = 0, z = -55 }) end
	for k = 10, 19 do table.insert(line, { t = k / HZ, x = line[10].x, y = 0, z = -55 }) end
	local kept, bad, counts = TR.validate(line, nil, CFG)
	check(counts.stale == TR.MAX_STALE and #kept == 20 - TR.MAX_STALE and bad == 0, "a short freeze is skipped; a real stop is kept")
	local tr = TR.tracker("speed")
	local fed = 0
	for _, s in line do
		TR.feed(tr, s, CFG)
		if tr.last == s then fed += 1 end
	end
	check(fed == 10, "the live tracker skips unchanged positions")

	-- Timeouts need real riding: something scored or more than a quarter of the course.
	local still = {}
	for k = 0, 1200 do table.insert(still, { t = k / HZ, x = sp.start.x, y = 0, z = sp.start.z }) end
	local stillTr = TR.tracker("speed")
	for _, s in still do TR.feed(stillTr, s, CFG) end
	local stillRes = TR.run("speed", still, CFG, 120)
	check(stillRes.scored == 0 and not TR.timeoutCounts(stillRes, stillTr), "standing still until time runs out earns nothing")
	local wander = ride(function(k: number): number return math.min(k, 120) end) -- one lap and a bit, then stops
	local wTr = TR.tracker("speed")
	for _, s in wander do TR.feed(wTr, s, CFG) end
	local wRes = TR.run("speed", wander, CFG, 120)
	check(TR.timeoutCounts(wRes, wTr) and wRes.scored > 0, "riding part of the course before time runs out counts")
	local outside = {}
	for k = 0, 50 do
		local x, z = TC.ovalPoint(sp.startD + k * 4.6, -11) -- the inside edge: misses every hoop
		table.insert(outside, { t = k / HZ, x = x, y = 0, z = z })
	end
	local oTr = TR.tracker("speed")
	for _, s in outside do TR.feed(oTr, s, CFG) end
	local oRes = TR.run("speed", outside, CFG, 120)
	check(oRes.scored == 0 and not TR.timeoutCounts(oRes, oTr), "a little riding with nothing scored doesn't count")
	local gTr = TR.tracker("grit")
	gTr.next = 4
	check(TR.timeoutCounts({ scored = 0 }, gTr) and not TR.timeoutCounts({ scored = 0 }, TR.tracker("grit"))
		and TR.timeoutCounts({ scored = 1 }, TR.tracker("grit")), "Mud Splash timeouts: past three pieces or one scored")
end

-- Training rides T3: Gate Break, Hill Climb, Easy Rein (D-053).
local function trainingT3Tests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local TC = require("../../game/src/shared/TrainingCourses")
	local TR = require("../../game/src/shared/TrainingRide")
	local TapTime = require("../../game/src/shared/TapTime")
	local CFG = GameConfig.training
	local HZ = CFG.sampleHz
	local ac = TC.courses.accel
	local A = CFG.accel
	local gz = ac.start.z
	local SEED = 4242

	-- Gate Break rides from a script: each break waits for the bell (or not), gallops to the
	-- flag and canters round the loop back into the stall. `react[b]` is the delay after the
	-- bell before setting off (negative = early). Samples every 0.1 s on the server clock.
	local function gateRide(react: { number }, opts: any?)
		local o = opts or {}
		local samples = {}
		local t = 0
		local x, z = ac.start.x, gz
		local function push()
			local sx, sz = x, z
			if o.freeze and o.freeze(#samples) and #samples > 0 then
				local last = samples[#samples]
				sx, sz = last.x, last.z
			end
			table.insert(samples, { t = t, x = sx, y = 0, z = sz })
			t = math.floor((t + 1 / HZ) * 1000 + 0.5) / 1000
		end
		local function stand(seconds: number)
			local n = math.floor(seconds * HZ + 0.5)
			for _ = 1, n do push() end
		end
		local function gallopTo(tx: number, speed: number)
			while math.abs(tx - x) > 1e-6 do
				local step = math.min(speed / HZ, math.abs(tx - x))
				x += if tx > x then step else -step
				push()
			end
		end
		local function loopBack()
			local pts = ac.route.points
			local k = 1
			-- from the flag, follow the loop (canter) back to the start
			while k < #pts and pts[k].x < x - 0.5 do k += 1 end
			for i = k, #pts do
				local px, pz = pts[i].x, pts[i].z
				local dx, dz = px - x, pz - z
				local len = math.sqrt(dx * dx + dz * dz)
				local steps = math.max(1, math.ceil(len / (CFG.canter / HZ)))
				for _ = 1, steps do
					x += dx / steps
					z += dz / steps
					push()
				end
			end
			x, z = ac.start.x, gz
			push()
		end
		local tr = TR.tracker("accel", { seed = SEED, allowance = o.allowance or 0 })
		local sc = TR.screener(nil) -- fed as the server feeds it: screened samples
		local function feed(i: number)
			local kind, k = TR.screen(sc, samples[i], CFG)
			if kind == "ok" then TR.feed(tr, k, CFG) end
		end
		local b, attempt = 1, 1
		local guard = 0
		while b <= #react and guard < 20 do
			guard += 1
			-- stand in the stall until armed
			local armedAt = nil
			local feedFrom = #samples + 1
			local waits = 0
			while not armedAt and waits < 100 do
				waits += 1
				stand(0.1)
				for i = feedFrom, #samples do feed(i) end
				feedFrom = #samples + 1
				for _, e in tr.events do
					if e.kind == "armed" then armedAt = tr.bellT end
				end
				table.clear(tr.events)
			end
			if not armedAt then break end
			local bellT = armedAt :: number
			local r = react[b]
			if r < 0 and attempt == 1 and o.rerunReact then
				-- go early, then come back for the rerun
				while t < bellT + r do stand(0.1) end
				gallopTo(x + 30, CFG.gallop)
				gallopTo(ac.start.x, CFG.canter)
				attempt = 2
				react[b] = o.rerunReact[b]
			else
				while t < bellT + r do stand(0.1) end
				gallopTo(ac.flag.ax + 6, CFG.gallop)
				loopBack()
				b += 1
				attempt = 1
			end
			for i = feedFrom, #samples do feed(i) end
			table.clear(tr.events)
		end
		return samples, tr
	end

	-- Bell times come from the seed.
	local bellsOk = true
	for n = 1, 50 do
		local d = TC.bellDelay(SEED, n)
		if d < A.bellMin or d > A.bellMax or d ~= TC.bellDelay(SEED, n) then bellsOk = false end
	end
	check(bellsOk and TC.bellDelay(SEED, 1) ~= TC.bellDelay(SEED, 2) and TC.bellDelay(1, 1) ~= TC.bellDelay(2, 1),
		"bell delays: 1.5-3.5 s, the same for a seed, different per break and seed")

	-- Reaction scores.
	check(TR.breakScore(0.3, CFG) == 100 and TR.breakScore(A.fullReact, CFG) == 100 and TR.breakScore(A.zeroReact, CFG) == A.breakFloor
		and TR.breakScore(5, CFG) == A.breakFloor and close(TR.breakScore(1.25, CFG), 70, 1e-9), "break score: 100 to 0.5 s, 40 at 2 s and after")
	local samples, tr = gateRide({ 0.2, 0.3, 0.4 })
	local raw, detail = TR.scoreAccel(TR.validate(samples, function(x, z) return TC.onCourse("accel", x, z) end, CFG), SEED, 0, CFG)
	check(tr.finished and detail.scored == 3 and raw == 100 and detail.quick == 3, string.format("three quick starts score 100 (%.1f)", raw))
	check(detail.finishT ~= nil and detail.finishT > 30 and detail.finishT < TC.parSeconds("accel"), string.format("Gate Break under par (%.1f s)", detail.finishT or -1))
	local res = TR.run("accel", samples, CFG, tr.finishT, { bellSeed = SEED, allowance = 0 })
	check(res.score == 100 and res.ribbon == "gold" and res.stars == 3 and res.scored == 3, "a quick Gate Break: gold")
	check(close(res.par, TR.accelIdeal(res.detail.breaks, CFG) * CFG.parFactor, 1e-9)
		and math.abs(res.par - TC.parSeconds("accel")) > 0.01, "Gate Break par uses this ride's bell waits")
	local slowS = gateRide({ 1.25, 1.25, 3 })
	local slowRaw, slowD = TR.scoreAccel(TR.validate(slowS, nil, CFG), SEED, 0, CFG)
	-- (a scripted start lands on the 0.1 s sample grid, so a reaction reads within 0.1 s of it)
	local r1 = slowD.breaks[1].reaction
	check(r1 >= 1.15 - 1e-9 and r1 <= 1.35 + 1e-9 and close(slowD.breaks[1].score, TR.breakScore(r1, CFG), 1e-9)
		and slowD.breaks[3].score == A.breakFloor and slowRaw < 70, string.format("slow starts score less, no fail (reaction %.2f s)", r1))

	-- The latency allowance comes off each reaction, capped at 0.3 s.
	local lagS = gateRide({ 0.75, 0.75, 0.75 })
	local noAllow = TR.scoreAccel(TR.validate(lagS, nil, CFG), SEED, 0, CFG)
	local allowance = TapTime.rewindAllowance(2 * 0.12, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	local withAllow, wd = TR.scoreAccel(TR.validate(lagS, nil, CFG), SEED, allowance, CFG)
	local _, nd = TR.scoreAccel(TR.validate(lagS, nil, CFG), SEED, 0, CFG)
	local shifted = true
	for b = 1, A.breaks do
		if not close(nd.breaks[b].reaction - wd.breaks[b].reaction, allowance, 1e-9) then shifted = false end
	end
	check(withAllow > noAllow and shifted, string.format("the latency allowance comes off every reaction (%.0f -> %.0f)", noAllow, withAllow))
	check(TapTime.rewindAllowance(2 * 2, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds) == 0.3, "allowance capped at 0.3 s")

	-- Going early reruns the break once; early again scores the floor.
	local earlyS, earlyTr = gateRide({ -0.6, 0.3, 0.3 }, { rerunReact = { 0.3 } })
	local earlyRaw, earlyD = TR.scoreAccel(TR.validate(earlyS, nil, CFG), SEED, 0, CFG)
	check(earlyTr.finished and earlyD.scored == 3 and earlyRaw == 100, "an early go reruns the break, and the rerun counts")
	local early2S = gateRide({ -0.6, 0.3, 0.3 }, { rerunReact = { -0.4 } })
	local _, early2D = TR.scoreAccel(TR.validate(early2S, nil, CFG), SEED, 0, CFG)
	check(early2D.breaks[1].early == true and early2D.breaks[1].score == A.breakFloor and early2D.scored == 3, "early twice: that break scores 40")
	local evTr = TR.tracker("accel", { seed = SEED })
	local kinds = {}
	for _, s in TR.validate(earlyS, nil, CFG) do
		TR.feed(evTr, s, CFG)
		for _, e in evTr.events do table.insert(kinds, e.kind) end
		table.clear(evTr.events)
	end
	check(kinds[1] == "armed" and kinds[2] == "early" and kinds[3] == "armed" and kinds[4] == "go" and kinds[5] == "flag",
		"events: Ready, Wait for the bell!, Ready, go, flag")

	-- A start only counts from inside the stall: a horse waiting outside is never readied.
	local outside = {}
	for k = 0, 80 do table.insert(outside, { t = k / HZ, x = ac.start.x, y = 0, z = gz + 10 }) end
	local outTr = TR.tracker("accel", { seed = SEED })
	for _, s in outside do TR.feed(outTr, s, CFG) end
	check(outTr.arms == 0 and outTr.results[1] == nil and outTr.phase == "settle", "no Ready outside the stall")
	-- Drifting out of the stall before the bell is an early go.
	local drift = {}
	for k = 0, 8 do table.insert(drift, { t = k / HZ, x = ac.start.x, y = 0, z = gz }) end
	for k = 1, 12 do table.insert(drift, { t = (8 + k) / HZ, x = ac.start.x, y = 0, z = gz + k * 0.45 }) end
	local driftTr = TR.tracker("accel", { seed = SEED })
	local sawEarly = false
	for _, s in drift do
		TR.feed(driftTr, s, CFG)
		for _, e in driftTr.events do if e.kind == "early" then sawEarly = true end end
		table.clear(driftTr.events)
	end
	check(sawEarly and driftTr.attempt == 2, "leaving the stall slowly before the bell is early too")

	-- Network freezes (the Sprint Lane fix): frozen samples around the bell and on the dash.
	local frozenS = gateRide({ 0.2, 0.3, 0.4 }, { freeze = function(i: number): boolean return i % 9 == 4 end })
	local fk, fbad, fcounts = TR.validate(frozenS, nil, CFG)
	local fraw, fd = TR.scoreAccel(fk, SEED, 0, CFG)
	check(fcounts.stale > 10 and fbad <= CFG.maxBadShare and fd.scored == 3 and fraw >= 95,
		string.format("freezes don't spoil Gate Break (%.0f, %d stale, %.2f bad)", fraw, fcounts.stale, fbad))
	-- The live screener and a replay see the same kept samples.
	local sc = TR.screener(nil)
	local live = TR.tracker("accel", { seed = SEED })
	for _, s in frozenS do
		local kind, k = TR.screen(sc, s, CFG)
		if kind == "ok" then TR.feed(live, k, CFG) end
	end
	local liveTotal = 0
	for b = 1, A.breaks do liveTotal += (live.results[b] and live.results[b].score or 0) end
	check(close(liveTotal / A.breaks, fraw, 1e-9) and close(TR.badShare(sc), fbad, 1e-12), "live screening matches the replay")
	check(TR.progressShare(TR.tracker("accel")) == 0, "Gate Break progress starts at 0")

	-- Hill Climb: ring scoring against ponyAt.
	local ST = CFG.stamina
	local endT = TC.idealSeconds("stamina", SEED)
	local function follow(behind: number, latFn: ((number, any) -> number)?, delay: number?)
		local out = {}
		local k = 0
		while k / HZ <= endT + 0.5 do
			local t = k / HZ
			local pony = TC.ponyAt(SEED, t - (delay or 0))
			local lat = if latFn then latFn(t, pony) else pony.lateral
			local x, z = TC.ovalPoint(pony.d - behind, lat)
			table.insert(out, { t = t, x = x, y = 0, z = z })
			k += 1
		end
		return out
	end
	local perfectH = follow(16)
	local hraw, hd = TR.scoreStamina(TR.validate(perfectH, nil, CFG), SEED, 0, CFG)
	check(hraw == 100 and hd.samples > 300, "staying in the middle of Pip's ring scores 100")
	local hres = TR.run("stamina", perfectH, CFG, endT, { seed = SEED, lag = 0 })
	check(hres.score == 100 and hres.ribbon == "gold" and hres.badShare == 0, "a perfect Hill Climb: gold")
	local lagRaw = TR.scoreStamina(TR.validate(follow(30), nil, CFG), SEED, 0, CFG)
	check(lagRaw == 0, "lagging 30 studs behind Pip is outside the ring")
	local closeRaw = TR.scoreStamina(TR.validate(follow(5), nil, CFG), SEED, 0, CFG)
	check(closeRaw == 0, "too close behind Pip is outside the ring too")
	local straightRaw = TR.scoreStamina(TR.validate(follow(16, function() return 0 end), nil, CFG), SEED, 0, CFG)
	local wideRaw = TR.scoreStamina(TR.validate(follow(16, function(_, pony) return -pony.lateral end), nil, CFG), SEED, 0, CFG)
	check(straightRaw > 50 and straightRaw < 100 and wideRaw < straightRaw,
		string.format("weaving with Pip beats riding straight (%.0f), which beats weaving the wrong way (%.0f)", straightRaw, wideRaw))
	local graceRaw = TR.scoreStamina(TR.validate(follow(16, function(t, pony) return if t < ST.grace then 11 else pony.lateral end), nil, CFG), SEED, 0, CFG)
	check(graceRaw == 100, "the first 3 s don't count")
	-- The rider's screen shows Pip a little late; the allowance makes up for it.
	local laggy = follow(16, nil, 0.3)
	local lagNo = TR.scoreStamina(TR.validate(laggy, nil, CFG), SEED, 0, CFG)
	local lagYes = TR.scoreStamina(TR.validate(laggy, nil, CFG), SEED, 0.3, CFG)
	check(lagYes == 100 and lagNo < lagYes, string.format("Pip's clock allowance (%.0f -> %.0f)", lagNo, lagYes))
	-- Freezes don't spoil it.
	local frozenH = follow(16)
	for i = 30, #frozenH, 23 do
		frozenH[i] = { t = frozenH[i].t, x = frozenH[i - 1].x, y = 0, z = frozenH[i - 1].z }
	end
	local fh = TR.scoreStamina(TR.validate(frozenH, nil, CFG), SEED, 0, CFG)
	check(fh == 100, "freezes are skipped, not counted out of the ring")

	-- Server and client agree on Pip: no hidden state, any order, any seed.
	local agree = true
	for _, seed in { 1, SEED, 99999 } do
		local forward = {}
		for k = 0, 400 do forward[k] = TC.ponyAt(seed, k * 0.1) end
		for k = 400, 0, -7 do
			local p2 = TC.ponyAt(seed, k * 0.1)
			if p2.x ~= forward[k].x or p2.z ~= forward[k].z or p2.speed ~= forward[k].speed then agree = false end
		end
		local inA = TR.inRing(seed, 12.3, forward[123].x, forward[123].z, 0, CFG)
		local inB = TR.inRing(seed, 12.3, forward[123].x, forward[123].z, 0, CFG)
		if inA ~= inB then agree = false end
	end
	check(agree, "ponyAt gives the same Pip on server and client, in any order")

	-- Ideal times stay 35-50 s with Gate Break's settle.
	check(TC.idealSeconds("accel") >= 35 and TC.idealSeconds("accel") <= 50, string.format("Gate Break ideal %.1f s", TC.idealSeconds("accel")))

	-- Easy Rein aims: a point ahead on the track, or along a route without jumping lanes.
	local ox, oz = TC.ovalCarrot(800, -55, 14, 3)
	local od, ol = TC.ovalProject(ox, oz)
	check(close(TC.wrap(od - TC.ovalProject(800, -55)), 14, 1e-6) and close(ol, 3, 1e-6), "oval aim: 14 studs on, at the lateral asked")
	local gr = TC.courses.grit
	local lane2 = gr.laneZ(2)
	local cx, cz, hint = TC.routeCarrot(gr.route, gr.laneX[1] + 40, gr.laneZ(1), 1, 12)
	check(math.abs(cz - gr.laneZ(1)) < 0.5 and cx > gr.laneX[1] + 40 and hint >= 1, "route aim stays in your lane, ahead of you")
	local _, cz2 = TC.routeCarrot(gr.route, gr.laneX[1] + 40, gr.laneZ(1) + 9, hint, 12)
	check(math.abs(cz2 - lane2) > 5, "a lane next door is never mistaken for yours")
	local ax, az = TC.routeCarrot(ac.route, ac.flag.ax - 30, gz, 1, 12)
	check(close(az, gz, 1e-6) and close(ax, ac.flag.ax - 18, 1e-6), "Gate Break aim runs down the lane")

	-- The practice gate never stops a horse (#38 gave ride rigs a shins collider): WorldScene
	-- puts every part of it in CourseProps with collisions off. (A source check: WorldScene
	-- needs Roblox to run.)
	local fs = require("@lune/fs")
	local scene = fs.readFile("game/src/server/WorldScene.luau")
	local a = string.find(scene, "Gate Break: the practice gate", 1, true)
	local b = a and string.find(scene, "FlagLine", a, true)
	local block = if a and b then string.sub(scene, a, b) else ""
	check(string.find(block, "\"gate_stall\"", 1, true) ~= nil and string.find(block, "CollisionGroups.set(gate, CollisionGroups.PROPS)", 1, true) ~= nil
		and string.find(block, "d.CanCollide, d.CanQuery, d.CanTouch = false, false, false", 1, true) ~= nil,
		"the practice gate is CourseProps with collisions off")
	local groups = fs.readFile("game/src/server/CollisionGroups.luau")
	check(string.find(groups, "collidable(CollisionGroups.PROPS, CollisionGroups.TRAINING, false)", 1, true) ~= nil
		and string.find(groups, "collidable(CollisionGroups.PROPS, CollisionGroups.RIDE, false)", 1, true) ~= nil,
		"CourseProps never collides with ride horses")

	-- Easy Rein setting: off by default, repaired to a boolean.
	local P = Profile.new(20000 * 86400)
	check(P.settings.easyRein == false, "Easy Rein is off by default")
	local junk = Profile.migrate({ settings = { visits = "Friends", easyRein = "yes" } }, 20000 * 86400)
	local on = Profile.migrate({ settings = { visits = "Friends", easyRein = true } }, 20000 * 86400)
	local old = Profile.migrate({ settings = { visits = "Friends" } }, 20000 * 86400)
	check(junk.settings.easyRein == false and on.settings.easyRein == true and old.settings.easyRein == false, "Easy Rein repaired on load")
	check(Profile.view(on, 20000 * 86400, GameConfig.energy).settings.easyRein == true, "the owner sees Easy Rein")
end

-- Training rides T3 review (PR #39): off-course time, Pip's clock, standing-start freezes,
-- the secret bell and par per ride.
local function trainingT3ReviewTests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local TC = require("../../game/src/shared/TrainingCourses")
	local TR = require("../../game/src/shared/TrainingRide")
	local CFG = GameConfig.training
	local HZ = CFG.sampleHz
	local ST = CFG.stamina
	local SEED = 777
	local endT = TC.idealSeconds("stamina", SEED)
	local mid = (ST.ringNear + ST.ringFar) / 2

	-- B1: time off the track is time out of Pip's ring.
	local function ride(where: (number) -> (number, number))
		local out = {}
		local k = 0
		while k / HZ <= endT + 0.5 do
			local x, z = where(k / HZ)
			table.insert(out, { t = k / HZ, x = x, y = 0, z = z })
			k += 1
		end
		return out
	end
	local inRingAt = function(t: number): (number, number)
		local pony = TC.ponyAt(SEED, t)
		local x, z = TC.ovalPoint(pony.d - mid, pony.lateral)
		return x, z
	end
	local camper = ride(function(t: number): (number, number)
		if t >= 10 and t < 12 then return inRingAt(t) end
		return TC.courses.stamina.start.x, 0 -- standing in the middle of the infield
	end)
	local camp = TR.run("stamina", camper, CFG, endT, { seed = SEED, lag = 0 })
	check(camp.score < 15 and camp.ribbon == "bronze", string.format("camping in the infield scores low (%.0f), not gold", camp.score))
	-- An honest kid who gets lost in the infield for ten seconds scores the share they rode with Pip.
	local lostFrom, lostTo = 15, 25
	local lost = ride(function(t: number): (number, number)
		if t >= lostFrom and t < lostTo then
			local pony = TC.ponyAt(SEED, t)
			return TC.ovalPoint(pony.d - mid, -30) -- well inside the inner rail
		end
		return inRingAt(t)
	end)
	local lostRes = TR.run("stamina", lost, CFG, endT, { seed = SEED, lag = 0 })
	local expect = 100 * (1 - (lostTo - lostFrom) / (endT - ST.grace))
	check(math.abs(lostRes.score - expect) < 4, string.format("lost in the infield: %.0f, about the share ridden with Pip (%.0f)", lostRes.score, expect))
	check(lostRes.badShare <= 2 / 300, "riding in and out of the infield isn't cheating")

	-- B2: the rider's screen runs Pip on the server's clock (anchored on the server's go time),
	-- and the server sees the rider one trip late. With the one-way allowance an honest
	-- follower stays in the ring for any ping up to the cap.
	local function followSeen(oneWay: number, clientLate: number)
		return ride(function(t: number): (number, number)
			-- what the server sees at t: the rider at t - oneWay, following the Pip on their screen
			local tc = TR.rideClock(t - oneWay, clientLate)
			return inRingAt(tc)
		end)
	end
	local anchoredOk = true
	for _, oneWay in { 0.03, 0.08, 0.15, 0.25 } do
		local seen = followSeen(oneWay, 0)
		local r = TR.run("stamina", seen, CFG, endT, { seed = SEED, lag = TR.lagAllowance(2 * oneWay) })
		if r.score < 99 then anchoredOk = false end
	end
	check(anchoredOk, "Pip on the server's clock + the one-way allowance: an honest follower stays in the ring")
	check(close(TR.lagAllowance(0.2), 0.1 + GameConfig.tapJitterMarginSeconds, 1e-9) and TR.lagAllowance(5) == GameConfig.maxTapRewindSeconds,
		"Hill Climb allowance: one way + margin, capped")
	check(close(TR.bellAllowance(0.2), 0.2 + GameConfig.tapJitterMarginSeconds, 1e-9), "Gate Break allowance: the whole round trip + margin")
	-- (Why the anchor matters: a screen whose clock started at the end of its own countdown runs
	-- late by one way plus the countdown's overshoot, and the follower drifts out of the ring.)
	local late = followSeen(0.1, 0.1 + 0.3)
	local lateRes = TR.run("stamina", late, CFG, endT, { seed = SEED, lag = TR.lagAllowance(0.2) })
	check(lateRes.score < 50, string.format("a late local clock would fall out of the ring (%.0f)", lateRes.score))
	check(TR.rideClock(105.25, 100) == 5.25, "ride clock = server time - the server's go time")

	-- S3: a freeze at a standing start doesn't make the start look slow.
	local ac = TC.courses.accel
	local gz = ac.start.z
	local function standingStart(freeze: number, react: number): number?
		local sc = TR.screener(nil)
		local tr = TR.tracker("accel", { seed = SEED })
		local t = 0
		local goTrue: number? = nil
		local function at(time: number): (number, number)
			if not goTrue or time < goTrue then return ac.start.x, gz end
			return ac.start.x + CFG.gallop * (time - goTrue), gz
		end
		local reaction: number? = nil
		for _ = 1, 200 do
			local x, z = at(t)
			if goTrue and t >= goTrue and t < goTrue + freeze then x, z = ac.start.x, gz end -- the replica froze
			local kind, k = TR.screen(sc, { t = t, x = x, y = 0, z = z }, CFG)
			if kind == "ok" then TR.feed(tr, k, CFG) end
			for _, e in tr.events do
				if e.kind == "armed" then goTrue = (tr.bellT :: number) + react end
				if e.kind == "go" then reaction = e.reaction end
			end
			table.clear(tr.events)
			if reaction then break end
			t = math.floor((t + 1 / HZ) * 1000 + 0.5) / 1000
		end
		return reaction
	end
	local freezeOk = true
	local worst = 0
	for _, freeze in { 0, 0.2, 0.3, 0.4 } do
		local r = standingStart(freeze, 0.26)
		if not r or math.abs(r - 0.26) > 0.01 then freezeOk = false end
		worst = math.max(worst, if r then math.abs(r - 0.26) else 99)
	end
	check(freezeOk, string.format("a 0.26 s start reads 0.26 s through 0.2-0.4 s freezes (worst off by %.3f)", worst))

	-- S1: events never carry the bell time, and the bell comes from the server's own seed.
	local tr1 = TR.tracker("accel", { seed = 11 })
	local tr2 = TR.tracker("accel", { seed = 12 })
	for k = 0, 10 do
		local s = { t = k / HZ, x = ac.start.x, y = 0, z = gz }
		TR.feed(tr1, s, CFG)
		TR.feed(tr2, s, CFG)
	end
	local leaked = false
	for _, e in tr1.events do
		for key in e do
			if key == "bellT" or key == "bell" or key == "delay" then leaked = true end
		end
	end
	check(#tr1.events == 1 and tr1.events[1].kind == "armed" and not leaked, "the Ready event doesn't say when the bell rings")
	check(tr1.bellT ~= tr2.bellT, "the bell time follows the tracker's (server-only) seed")

	-- Par per ride: the bell waits it really had.
	local mean = (CFG.accel.bellMin + CFG.accel.bellMax) / 2
	local quickBells = { { wait = CFG.accel.bellMin }, { wait = CFG.accel.bellMin }, { wait = CFG.accel.bellMin } }
	local slowBells = { { wait = CFG.accel.bellMax }, { wait = CFG.accel.bellMax }, { wait = CFG.accel.bellMax } }
	check(close(TR.accelIdeal(quickBells, CFG), TC.idealSeconds("accel") - 3 * (mean - CFG.accel.bellMin), 1e-9)
		and close(TR.accelIdeal(slowBells, CFG), TC.idealSeconds("accel") + 3 * (CFG.accel.bellMax - mean), 1e-9)
		and close(TR.accelIdeal({}, CFG), TC.idealSeconds("accel"), 1e-9), "Gate Break par follows the ride's own bell waits")
end

-- Training rides T4: ghosts, Ride together, Quick train on the server (D-053).
local function trainingT4Tests(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local TC = require("../../game/src/shared/TrainingCourses")
	local Ghost = require("../../game/src/shared/Ghost")
	local RT = require("../../game/src/shared/RideTogether")
	local QT = require("../../game/src/shared/QuickTrain")
	local TapTime = require("../../game/src/shared/TapTime")
	local CFG = GameConfig.training

	-- Ghosts: resampled at 4 Hz, quantised to 0.5 studs, at most 300 points, small. ------------
	local samples = {}
	for k = 0, 1200 do -- a 120 s ride at 10 Hz, galloping round the oval with hops
		local t = k / 10
		local x, z = TC.ovalPoint(30 + CFG.gallop * t, 4 * math.sin(t))
		table.insert(samples, { t = t, x = x, y = if k % 37 < 4 then 3.3 else 0, z = z })
	end
	local pts = Ghost.fromSamples(samples)
	check(#pts == Ghost.MAX and Ghost.HZ == CFG.ghostHz and Ghost.Q == CFG.ghostQuantum and Ghost.MAX == CFG.ghostMaxPoints,
		"a long ride keeps at most 300 points at 4 Hz (config values)")
	local g = Ghost.encode(pts)
	local back = Ghost.decode(g)
	local exact = back ~= nil and #back == #pts
	local worst = 0
	for i, p in pts do
		local b = back and back[i]
		if not b then exact = false break end
		worst = math.max(worst, math.abs(b.x - p.x), math.abs(b.y - p.y), math.abs(b.z - p.z))
	end
	check(exact and worst <= Ghost.Q / 2 + 1e-9, string.format("ghost round trip within half a quantum (worst %.3f)", worst))
	check(#g.d <= Ghost.MAX * 5 and #g.d >= Ghost.MAX * 3, string.format("a full ghost is about 5 characters a point (%d for %d)", #g.d, g.n))
	local again = Ghost.encode(back :: any)
	check(again.d == g.d, "decoding and encoding again gives the same string")
	check(Ghost.decode({ v = 1, hz = 4, q = 0.5, n = 3, d = "AB" }) == nil and Ghost.decode({ d = "!!", n = 1, q = 0.5 }) == nil
		and Ghost.decode("junk") == nil and Ghost.decode({ v = 1, hz = 4, q = 0.5, n = 999, d = "" }) == nil, "bad ghost data is refused")
	local gx, _, gz, fx = Ghost.at(back :: any, 4, 0.125)
	check(gx ~= nil and close(gx :: number, ((back :: any)[1].x + (back :: any)[2].x) / 2, 1e-9) and fx ~= nil
		and Ghost.at(back :: any, 4, 1000) == nil and gz ~= nil, "ghost position between points; nothing after the end")
	check(Ghost.better({ score = 90, seconds = 50 }, { score = 80, seconds = 40 }) and Ghost.better({ score = 90, seconds = 40 }, { score = 90, seconds = 41 })
		and not Ghost.better({ score = 70, seconds = 30 }, { score = 90, seconds = 60 }) and Ghost.better({ score = 1, seconds = 1 }, nil),
		"the best run: score, then time")
	check(#Ghost.fromSamples({}) == 0 and #Ghost.fromSamples({ samples[1] }) == 1, "tiny rides still make a ghost")

	-- Ride together: friends only, privacy respected, accept-only invites that lapse. ---------
	local base: RT.Ctx = { friends = true, fromVisits = "Friends", toVisits = "Friends", toNear = true, toBusy = false }
	local function with(k: string, v: any): RT.Ctx
		local c = table.clone(base) :: any
		c[k] = v
		return c
	end
	check(RT.canInvite(base), "a free friend nearby can be invited")
	check(select(2, RT.canInvite(with("friends", false))) == "friends", "only Roblox friends")
	check(select(2, RT.canInvite(with("toVisits", "Nobody"))) == "private" and select(2, RT.canInvite(with("fromVisits", "Nobody"))) == "private",
		"visits set to Nobody (either side) means no invites")
	check(select(2, RT.canInvite(with("toNear", false))) == "far" and select(2, RT.canInvite(with("toBusy", true))) == "busy"
		and select(2, RT.canInvite(with("same", true))) == "self", "far away, busy or yourself: no")
	local book = RT.book()
	local id1 = RT.invite(book, 1, 2, "speed", 100)
	check(id1 ~= nil, "an invite goes out")
	local none, why = RT.invite(book, 1, 3, "speed", 103)
	check(none == nil and why == "gap", "invites are spaced out")
	local none2, why2 = RT.invite(book, 4, 2, "grit", 103)
	check(none2 == nil and why2 == "pending", "a friend with an invite waiting can't get another")
	local wrong, whyW = RT.reply(book, id1, 3, 105)
	check(wrong == nil and whyW == "notyou", "only the invited friend can answer")
	local ok1 = RT.reply(book, id1, 2, 105)
	check(ok1 ~= nil and ok1.from == 1 and ok1.course == "speed" and RT.reply(book, id1, 2, 106) == nil, "an answer closes the invite")
	local id2 = RT.invite(book, 1, 2, "grit", 120)
	local lapsed = RT.sweep(book, 120 + RT.INVITE_SECONDS)
	check(id2 ~= nil and #lapsed == 1 and lapsed[1].id == id2 and RT.reply(book, id2, 2, 141) == nil, "invites lapse after 20 s")
	local count = 0
	for k = 0, 9 do
		local id = RT.invite(book, 7, 100 + k, "speed", 1000 + k * RT.GAP)
		if id then
			count += 1
			RT.reply(book, id, 100 + k, 1000 + k * RT.GAP + 1)
		end
	end
	check(count == RT.PER_WINDOW, string.format("at most %d invites in five minutes (%d)", RT.PER_WINDOW, count))
	check(RT.invite(book, 7, 200, "speed", 1000 + RT.WINDOW + 1) ~= nil, "the window moves on")
	RT.forget(book, 7)
	check(RT.pendingFor(book, 200) == nil, "leaving clears your invites")

	-- Quick train on the server: seeded games, scored from tap times. ------------------------
	local SEED = 31337
	-- Sprint Lane: tap each round when the runner is on the zone's centre.
	local function speedPerfect(seed: number): { any }
		local ev = {}
		local t = 0
		for _ = 1, QT.SPEED.rounds do
			local hit = nil
			for k = 1, 6000 do
				local tt = t + k * 0.001
				local x, c = QT.speedView(seed, ev, tt)
				if math.abs(x - c) < 0.003 then
					hit = tt
					break
				end
			end
			if not hit then break end
			table.insert(ev, { t = hit, kind = "tap" })
			t = hit + QT.SPEED.lock
		end
		return ev
	end
	local sev = speedPerfect(SEED)
	local sres = QT.play("speed", SEED, sev, 60)
	check(#sev == 5 and sres.done and sres.score >= 99, string.format("Sprint Lane: five taps on the zone score %.1f", sres.score))
	check(QT.speedCenter(SEED, 1) ~= QT.speedCenter(SEED + 1, 1) and QT.speedCenter(SEED, 1) == QT.speedCenter(SEED, 1), "the server's seed sets the zones")
	local double = { sev[1], { t = sev[1].t + 0.1, kind = "tap" } }
	local dres = QT.play("speed", SEED, double, sev[1].t + 0.2)
	check(dres.taps[1] ~= nil and dres.taps[2] == nil, "a second tap right after a hit doesn't count (as before)")
	local idle = QT.play("speed", SEED, {}, 5 * QT.SPEED.roundMax + 0.1)
	check(idle.done and idle.score == 0 and not QT.play("speed", SEED, {}, 3).done, "no taps: the rounds pass by themselves")
	-- Gate Break.
	local aev = {}
	local at = 0
	for r = 1, QT.ACCEL.rounds do
		local green = at + QT.accelDelay(SEED, r)
		table.insert(aev, { t = green + 0.2, kind = "tap" })
		at = green + 0.2 + QT.ACCEL.nextPause
	end
	local ares = QT.play("accel", SEED, aev, 60)
	check(ares.done and ares.score == 100, "Gate Break: quick taps after green score 100")
	local early = { { t = 0.3, kind = "tap" } }
	local eres = QT.play("accel", SEED, early, 0.5)
	check(eres.taps[1] == 0 and not eres.done, "tapping on red counts 0 for that round")
	-- Mud Splash.
	local gev = {}
	for _, p in QT.puddles(SEED) do table.insert(gev, { t = p, kind = "tap" }) end
	local gres = QT.play("grit", SEED, gev, 60)
	check(gres.done and gres.score == 100, "Mud Splash: a tap on every puddle scores 100")
	-- Hill Climb: deterministic from the hold and release times.
	local hev = { { t = 0.5, kind = "down" }, { t = 1.4, kind = "up" }, { t = 2.6, kind = "down" }, { t = 3.1, kind = "up" } }
	local h1, h2 = QT.play("stamina", SEED, hev, 9), QT.play("stamina", SEED, hev, 9)
	check(h1.done and h1.score == h2.score and h1.score > 0 and h1.score <= 100, "Hill Climb scores the same for the same holds")

	-- The server resolves each tap's claimed time (TapTime.resolve, D-021); the screen's preview
	-- uses the claimed times. Within the allowance they agree exactly.
	local function serverEvents(ev: { any }, oneWay: number, startAt: number)
		local out = {}
		local allowance = TapTime.rewindAllowance(2 * oneWay, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
		for _, e in ev do
			local claimed = startAt + e.t
			local resolved = TapTime.resolve(claimed, claimed + oneWay, startAt, startAt + QT.MAX_GAME, allowance)
			if resolved then QT.addEvent(out, resolved - startAt, e.kind) end
		end
		return out
	end
	local matchOk = true
	for _, game in { { "speed", sev }, { "accel", aev }, { "grit", gev }, { "stamina", hev } } do
		local preview = QT.play(game[1], SEED, game[2], 60)
		local server = QT.play(game[1], SEED, serverEvents(game[2], 0.12, 5000), 60)
		-- (the same to rounding: server times are counted from its start time)
		if not close(preview.score, server.score, 1e-6) then matchOk = false end
		for i in game[2] do
			local a, b = preview.taps[i], server.taps[i]
			if (a == nil) ~= (b == nil) or (a and b and QT.label(a) ~= QT.label(b)) then matchOk = false end
		end
	end
	check(matchOk, "the server's score and each tap's label match the screen's preview")
	-- A claimed time from too far back is scored when it arrived.
	local cheat = {}
	local allowance = TapTime.rewindAllowance(0.1, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	for _, e in gev do
		local claimed = 5000 + e.t
		local resolved = TapTime.resolve(claimed, claimed + 1.2, 5000, 5000 + QT.MAX_GAME, allowance)
		QT.addEvent(cheat, (resolved :: number) - 5000, e.kind)
	end
	check(QT.play("grit", SEED, cheat, 60).score < 50, "a tap claimed from too far back counts when it arrived")
	-- Quick train quality stays capped at 0.85.
	local TR = require("../../game/src/shared/TrainingRide")
	check(TR.quickScore(gres.score, CFG) == 70, "Quick train's server score is capped (quality 0.85)")
	local many = {}
	for k = 1, 200 do QT.addEvent(many, k * 0.01, "tap") end
	check(#many == QT.MAX_EVENTS, "a flood of taps is cut off")
	check(QT.play("speed", SEED, {}, QT.MAX_GAME).done, "a game never runs past 40 s")

	-- No client score anywhere any more; rosettes for gold ribbons; the ghost-sharing setting.
	local fs = require("@lune/fs")
	local service = fs.readFile("game/src/server/TrainingService.server.luau")
	local paddock = fs.readFile("game/src/client/PaddockClient.client.luau")
	check(string.find(service, 'remote("Train")', 1, true) == nil and string.find(paddock, 'WaitForChild("Train")', 1, true) == nil
		and string.find(service, "TapTime.resolve", 1, true) ~= nil, "Quick train sends tap times only; the old score remote is gone")
	local stable = fs.readFile("game/src/server/StableService.server.luau")
	check(string.find(stable, 'h.ribbons[course] == "gold"', 1, true) ~= nil and string.find(stable, '"rosette_ribbon"', 1, true) ~= nil,
		"a rosette on the stall for each gold ribbon")
	local P = Profile.new(20000 * 86400)
	local on = Profile.migrate({ settings = { visits = "Friends", shareGhost = true } }, 20000 * 86400)
	local junk = Profile.migrate({ settings = { visits = "Friends", shareGhost = 1 } }, 20000 * 86400)
	check(P.settings.shareGhost == false and on.settings.shareGhost == true and junk.settings.shareGhost == false,
		"sharing your ghost is off by default and repaired to a yes/no")
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local E = GameConfig.energy
	local T0 = 20000 * 86400 + 3600 -- a fixed day, 01:00 UTC

	-- Horse: starters --------------------------------------------------------------
	local rng = makeRng(7)
	local a = Horse.starter("h1", "Lucky Star", "bay", rng, T0)
	local b = Horse.starter("h2", "Comet", "grey", rng, T0)
	local equal = true
	for _, k in Horse.STATS do
		if a.stats[k] ~= Horse.STARTER_STAT or b.stats[k] ~= Horse.STARTER_STAT then equal = false end
		if a.potential[k] < 70 or a.potential[k] > 85 then equal = false end
	end
	check(equal, "starters have equal stats and Potential 70-85")
	check(#Horse.STARTERS == 3 and a.energy == E.maxPerRacer and a.league == "Rookie", "three starters, full energy, Rookie")

	-- Energy: spend, regen while away, cap ---------------------------------------------
	local h = Horse.starter("h3", "Pepper", "black", rng, T0)
	check(Horse.spendEnergy(h, 1, T0, E) and h.energy == 4, "spend 1 energy")
	check(Horse.syncEnergy(h, T0 + E.regenSeconds - 1, E) == 4, "no regen before the interval")
	check(Horse.syncEnergy(h, T0 + E.regenSeconds, E) == 5, "+1 after the interval")
	check(Horse.nextEnergyIn(h, T0 + E.regenSeconds, E) == 0, "full: nothing to wait for")
	for _ = 1, 5 do Horse.spendEnergy(h, 1, T0 + 100, E) end
	check(h.energy == 0 and not Horse.spendEnergy(h, 1, T0 + 100, E), "can't spend below zero")
	check(Horse.syncEnergy(h, T0 + 100 + 2 * E.regenSeconds + 10, E) == 2, "regen counts while away")
	check(Horse.nextEnergyIn(h, T0 + 100 + 2 * E.regenSeconds + 10, E) == E.regenSeconds - 10, "partial interval carries over")
	check(Horse.syncEnergy(h, T0 + 100 + 50 * E.regenSeconds, E) == E.maxPerRacer, "regen stops at the cap")

	-- Care: half each, resets to baseline next day, top-ups on cooldown --------------------
	local c = Horse.starter("h4", "Maple", "chestnut", rng, T0)
	c.energy = 3
	check(Horse.care(c, T0) == 0, "no care yet")
	local first, topUp = Horse.tend(c, "feed", T0, E, E.careTopUps)
	check(first and topUp and close(Horse.care(c, T0), 0.5, 1e-12) and c.energy == 4, "feeding fills half and tops up energy")
	first, topUp = Horse.tend(c, "feed", T0 + 60, E, E.careTopUps)
	check(not first and not topUp and c.energy == 4, "feeding again: no extra care, top-up on cooldown")
	Horse.tend(c, "groom", T0 + 60, E, E.careTopUps)
	check(close(Horse.care(c, T0 + 60), 1, 1e-12) and c.bond == 2, "full care after grooming; bond +1 each")
	check(Horse.care(c, T0 + 86400) == 0, "care back to baseline the next day, never below")
	first, topUp = Horse.tend(c, "feed", T0 + 86400, E, E.careTopUps)
	check(first, "can feed again on a new day")

	-- Rating: care and bond help, matching RaceRating ------------------------------------
	local cond = { distance = "Mile", surface = "Dirt", weather = "Sunny" }
	local r0 = Horse.rating(a, cond, T0, RaceRating)
	check(close(r0, RaceRating.rating(a.stats, cond, 0, 0, "Stalker", 0), 1e-9), "rating matches RaceRating")
	Horse.tend(a, "feed", T0, E, E.careTopUps)
	Horse.tend(a, "groom", T0, E, E.careTopUps)
	check(Horse.rating(a, cond, T0, RaceRating) > r0, "full care raises the rating")

	-- Records ------------------------------------------------------------------------
	Horse.recordRace(b, 1, 20, 10, T0)
	Horse.recordRace(b, 5, 0, 1, T0)
	check(b.record.races == 2 and b.record.wins == 1 and b.record.places == 1 and b.points == 11 and b.record.cash == 20,
		"race record")

	-- View hides Potential until revealed ------------------------------------------------
	local v = Horse.view(b, T0, E)
	check(v.potential == nil and v.stats.speed == Horse.STARTER_STAT, "Potential hidden")
	b.stamps.potential = true
	check(Horse.view(b, T0, E).potential ~= nil, "Potential shown after the vet stamp")

	-- Repair ---------------------------------------------------------------------------
	local fixed = Horse.repair({ id = "h9", coat = "zebra", stats = { speed = 300 }, energy = 99 }, T0)
	check(fixed.coat == "bay" and fixed.stats.speed == 100 and fixed.energy == 5 and fixed.name == "Comet"
		and fixed.potential.speed >= fixed.stats.speed, "repair clamps and fills a bad record")

	-- Profile ------------------------------------------------------------------------
	local p = Profile.new(T0)
	check(p.cash == Profile.START_CASH and Profile.itemCount(p, "hay") == 10 and Profile.itemCount(p, "seed_carrot") == 2 and #p.horses == 0, "new profile")
	check(Profile.touchDay(p, T0) and not Profile.touchDay(p, T0 + 60) and p.days.played == 1, "first visit of the day counts once")
	check(Profile.touchDay(p, T0 + 3 * 86400) and p.days.played == 2, "a missed day never resets the count")
	check(Profile.spendCash(p, 20) and p.cash == 30 and not Profile.spendCash(p, 31) and p.cash == 30, "can't overspend")
	check(not Profile.spendCash(p, -5), "no negative spends")
	check(Profile.takeItem(p, "carrot", 3) and p.items.carrot == nil and not Profile.takeItem(p, "carrot", 1), "items run out cleanly")
	Profile.addItem(p, "seed_oats", 2)
	check(Profile.itemCount(p, "seed_oats") == 2, "add items")

	local h1 = Horse.starter(Profile.newHorseId(p), "Lucky Star", "bay", rng, T0)
	Profile.addHorse(p, h1)
	check(p.activeHorse == "h1" and Profile.activeHorse(p) == h1, "first horse becomes active")
	local h2 = Horse.starter(Profile.newHorseId(p), "Comet", "grey", rng, T0)
	local h3 = Horse.starter(Profile.newHorseId(p), "Pepper", "black", rng, T0)
	Profile.addHorse(p, h2)
	Profile.addHorse(p, h3)
	check(Profile.isStalled(p, "h2") and not Profile.isStalled(p, "h3"), "third horse goes to the pasture")
	check(not Profile.setActive(p, "h3"), "pasture horses can't be active")
	check(Profile.swapStall(p, "h1", "h3") and p.activeHorse == "h3" and Profile.isStalled(p, "h3"), "swap a pasture horse in")

	Profile.recordRace(p, "h3", 1, 24, 10, T0)
	check(p.cash == 30 + 24 and p.totals.wins == 1 and h3.record.wins == 1, "race pays into the profile")

	local view = Profile.view(p, T0, E)
	check(#view.horses == 3 and view.horses[3].stalled == false and view.horses[1].potential == nil, "profile view")

	-- Migration: nil, junk, and an old record ------------------------------------------
	check(Profile.migrate(nil, T0).cash == Profile.START_CASH, "new player")
	local junk = Profile.migrate({ cash = -40, items = { hay = "5", diamond = 9 }, horses = { 5, { id = "h1" } }, stalls = 99 }, T0)
	check(junk.cash == 0 and junk.items.hay == 5 and junk.items.diamond == nil and #junk.horses == 1
		and junk.activeHorse == "h1" and junk.stalls == Profile.MAX_STALLS and junk.nextHorseId == 2, "migrate repairs junk")
	local round = Profile.migrate(p, T0)
	check(#round.horses == 3 and round.activeHorse == "h3", "migrate keeps a good profile")

	-- Names ------------------------------------------------------------------------
	check(NameGen.build("Lucky", "Star") == "Lucky Star" and NameGen.build(nil, "Star") == "Star", "names from chips")
	check(NameGen.build("Lucky", "Bad") == nil and NameGen.build("Nope", nil) == nil and NameGen.build(nil, nil) == nil,
		"only listed words")
	local f, s = NameGen.offer(makeRng(3), 6)
	local distinct = #f == 6 and #s == 6
	for i = 1, #f do
		for j = i + 1, #f do if f[i] == f[j] then distinct = false end end
	end
	check(distinct, "offer gives distinct chips")

	-- WorldLayout (Stage 2) ----------------------------------------------------------
	local W = WorldLayout
	local street = { W.STREET_X0, W.STREET_Z - W.STREET_WIDTH / 2, W.STREET_X1, W.STREET_Z + W.STREET_WIDTH / 2 }
	local lane = { W.LANE_X - W.LANE_WIDTH / 2, W.LANE_Z0, W.LANE_X + W.LANE_WIDTH / 2, W.LANE_Z1 }
	-- Everything on the grandstand side stays clear of the racecourse and grandstand (x < 640).
	local course = { -1000, -2000, 640, 2000 }
	local plotsOk = true
	for i = 1, W.PLOT_COUNT do
		local r = W.plotRect(i)
		if not W.inBounds(r) or W.overlaps(r, street) or W.overlaps(r, lane) or W.overlaps(r, course) then plotsOk = false end
		for j = i + 1, W.PLOT_COUNT do
			if W.overlaps(r, W.plotRect(j)) then plotsOk = false end
		end
		for key in W.places do
			local pr = W.placeRect(key)
			if pr and W.overlaps(r, pr) then plotsOk = false end
		end
		-- the plot's front edge touches the lane
		local p = W.plot(i)
		if math.abs(math.abs(p.x - W.LANE_X) - W.LANE_WIDTH / 2) > 1e-9 then plotsOk = false end
	end
	check(plotsOk, "20 plots in bounds, on the lane, clear of streets, buildings and each other")
	local placesOk = true
	local keys = {}
	for key in W.places do table.insert(keys, key) end
	for a = 1, #keys do
		local ra = W.placeRect(keys[a])
		if ra then
			if not W.inBounds(ra) or W.overlaps(ra, street) or W.overlaps(ra, course) then placesOk = false end
			for b = a + 1, #keys do
				local rb = W.placeRect(keys[b])
				if rb and W.overlaps(ra, rb) then placesOk = false end
			end
		end
	end
	check(placesOk, "Fair Street buildings clear of the street, the course and each other")
	-- The tunnel lines up with the grandstand: the street meets the stand's back wall.
	local cfg = TrackLayout.churchill
	local _, _, lineZ = TrackLayout.finishLine(cfg)
	check(W.STREET_Z > lineZ - 300 and W.STREET_Z < lineZ + 600, "Fair Street meets the grandstand")
	-- Every map destination has an arrival point in bounds; the stable needs a plot.
	local arriveOk = true
	for _, dest in W.MAP do
		local x, z = W.arrival(dest, 3)
		if x < W.BOUNDS.x0 or x > W.BOUNDS.x1 or z < W.BOUNDS.z0 or z > W.BOUNDS.z1 then arriveOk = false end
		if not W.MAP_LABELS[dest] or not W.MAP_EMOJI[dest] then arriveOk = false end
	end
	local sx, sz = W.arrival("stable", 3)
	local r3 = W.plotRect(3)
	check(arriveOk and sx >= r3[1] and sx <= r3[3] and sz >= r3[2] and sz <= r3[4], "map arrivals, stable arrival inside your plot")
	-- Within about a 20-second gallop (48 studs/s) of the grandstand tunnel.
	local far = 0
	for i = 1, W.PLOT_COUNT do
		local p = W.plot(i)
		far = math.max(far, math.sqrt((p.x - W.STREET_X0) ^ 2 + (p.z - W.STREET_Z) ^ 2))
	end
	check(far / 48 <= 20, "every plot within a 20 s gallop of the grandstand")

	-- Care (Stage 3) -------------------------------------------------------------------
	local Care = require("../../game/src/shared/Care")
	local cp = Profile.new(T0)
	local ch = Horse.starter(Profile.newHorseId(cp), "Biscuit", "bay", rng, T0)
	Profile.addHorse(cp, ch)
	ch.energy = 3
	local ok, msg = Care.feed(cp, ch, "hay", T0, E)
	check(ok and cp.items.hay == 9 and ch.care.fed and ch.energy == 4 and string.find(msg, "Energy") ~= nil, "feeding uses hay, fills care, tops up energy")
	ok = Care.feed(cp, ch, "hay", T0 + 10, E)
	check(not ok and cp.items.hay == 9, "one meal a day, no hay wasted")
	ok = Care.feed(cp, ch, "carrot", T0 + 86400, E)
	check(not ok, "carrots are treats, not meals")
	cp.items.hay = nil
	ok, msg = Care.feed(cp, ch, "hay", T0 + 86400, E)
	check(not ok and string.find(msg, "Muck out") ~= nil, "out of hay points to chores")
	ok = Care.groom(cp, ch, T0, E)
	check(ok and ch.care.groomed and not Care.groom(cp, ch, T0 + 5, E), "groom once a day")

	-- Treats: bond, a few a day.
	cp.items.carrot = 10
	local bond0 = ch.bond
	for _ = 1, Care.TREATS_PER_DAY do Care.treat(cp, ch, "carrot", T0) end
	check(ch.bond == bond0 + 2 * Care.TREATS_PER_DAY and cp.items.carrot == 10 - Care.TREATS_PER_DAY, "treats add bond")
	ok = Care.treat(cp, ch, "carrot", T0 + 60)
	check(not ok and cp.items.carrot == 10 - Care.TREATS_PER_DAY, "treat limit per day keeps carrots")
	check(Care.treat(cp, ch, "carrot", T0 + 86400), "treats again tomorrow")
	check(not Care.treat(cp, ch, "hay", T0 + 86400), "hay isn't a treat")
	local b1 = ch.bond
	Care.pet(cp, ch, T0 + 86400)
	local ok2 = Care.pet(cp, ch, T0 + 86400 + 60)
	check(ch.bond == b1 + 1 and ok2, "petting: bond once a day, always allowed")
	local _, _, counted3 = Care.pet(cp, ch, T0 + 86400 + 120)
	check(counted3 == false, "only the first pets of the day count toward jobs")

	-- Garden: plant, grow offline, harvest, never wither.
	cp.items.seed_carrot = 1
	check(Care.plant(cp, 1, "seed_carrot", T0) and cp.items.seed_carrot == nil, "plant uses a seed")
	check(not Care.plant(cp, 1, "seed_carrot", T0), "one crop per bed")
	check(not Care.plant(cp, 4, "seed_carrot", T0) and not Care.plant(cp, 1.5, "seed_carrot", T0), "only beds 1-3")
	check(not Care.harvest(cp, 1, T0 + 60), "not ready early")
	check(close(Care.cropProgress(cp.garden[1], T0 + 1800), 0.5, 1e-9), "half grown at half time")
	local carrots = cp.items.carrot or 0
	check(Care.harvest(cp, 1, T0 + 10 * 86400) and cp.items.carrot == carrots + 3 and cp.garden[1].seed == "", "harvest days later: never withers")
	check(not Care.plant(cp, 2, "seed_apple", T0), "need the seed")

	-- Chores: always hay, cooldown per stall.
	local hay0, cash0 = cp.items.hay or 0, cp.cash
	check(Care.chore(cp, 1, T0) and cp.items.hay == hay0 + 1 and cp.cash == cash0 + 2, "chore pays hay and cash")
	check(not Care.chore(cp, 1, T0 + 60), "stall stays clean for a while")
	check(Care.chore(cp, 2, T0 + 60), "other stall is fine")
	check(not Care.chore(cp, 3, T0) and not Care.chore(cp, 0, T0), "only your stalls")
	check(Care.chore(cp, 1, T0 + Care.CHORE.cooldownSeconds), "clean again later")

	-- Shop: buy within cash, sell crops only.
	cp.cash = 20
	check(Care.buy(cp, "hay", 5) and cp.cash == 10, "buy hay")
	check(not Care.buy(cp, "grain", 5) and cp.cash == 10, "can't overspend")
	check(not Care.buy(cp, "diamond", 1) and not Care.buy(cp, "hay", 0) and not Care.buy(cp, "hay", 2.5) and not Care.buy(cp, "hay", 999),
		"only listed items, sane amounts")
	cp.items.apple = 3
	check(Care.sell(cp, "apple", 3) and cp.cash == 16 and cp.items.apple == nil, "sell apples")
	check(not Care.sell(cp, "hay", 1), "hay isn't bought back")
	cp.items.carrot, cp.items.oats = 8, 2
	local cashS = cp.cash
	check(Care.sellAll(cp, 5) and cp.items.carrot == 5 and cp.items.oats == 2 and cp.cash == cashS + 3, "sell all keeps 5 of each")
	check(not Care.sellAll(cp, 5), "nothing left to sell")
	local bad = Profile.migrate({ garden = { { seed = "seed_moon", at = 5 }, { seed = "seed_oats", at = 7 } } }, T0)
	check(bad.garden[1].seed == "" and bad.garden[2].seed == "seed_oats", "unknown seeds are cleared on load")

	-- Garden and chores survive migration.
	cp.garden[2] = { seed = "seed_oats", at = T0 }
	local mig = Profile.migrate(cp, T0)
	check(mig.garden[2].seed == "seed_oats" and #mig.garden == Profile.BEDS and mig.chores["1"] ~= nil, "garden and chores saved")
	check(#Profile.migrate(nil, T0).garden == Profile.BEDS, "new profile has empty beds")

	-- Jobs (Stage 5) --------------------------------------------------------------------
	local Jobs = require("../../game/src/shared/Jobs")
	local Advice = require("../../game/src/shared/Advice")
	local PaceMeter = require("../../game/src/shared/PaceMeter")
	local jp = Profile.new(T0)
	Jobs.refresh(jp, 12345, T0)
	check(#jp.jobs.daily == 3 and #jp.jobs.weekly == 5 and #jp.jobs.monthly == 5, "3 daily, 5 weekly, 5 monthly")
	local again = Profile.new(T0)
	Jobs.refresh(again, 12345, T0 + 3600)
	local same = true
	for i = 1, 3 do if again.jobs.daily[i].id ~= jp.jobs.daily[i].id then same = false end end
	check(same, "same jobs on any server the same day")
	local noWin, noSpend = true, true
	for _, pool in { Jobs.DAILY, Jobs.WEEKLY, Jobs.MONTHLY } do
		for _, d in pool do
			if string.find(string.lower(d.text), "win") then noWin = false end
			if d.event == "buy" or d.event == "spend" or d.event == "invite" then noSpend = false end
			if d.reward.items then
				for item in d.reward.items do if not table.find(Profile.ITEMS, item) then noSpend = false end end
			end
		end
	end
	check(noWin and noSpend, "no win, spend or invite jobs; rewards are real items")
	local dailyCash = 0
	for _, d in Jobs.DAILY do dailyCash = math.max(dailyCash, d.reward.cash or 0) end
	check(dailyCash * 3 <= 30, "daily job cash stays small (about 10% of a day's races)")
	-- Progress, claim, rollover auto-claim.
	local first = jp.jobs.daily[1]
	local def = Jobs.def(first.id)
	local finished = Jobs.record(jp, 12345, def.event, def.target, T0)
	local found = false
	for _, d in finished do if d.id == first.id then found = true end end
	check(found and first.progress == def.target, "recording finishes a job")
	Jobs.record(jp, 12345, def.event, 50, T0)
	check(first.progress == def.target, "progress caps at the target")
	local cashBefore = jp.cash
	check(Jobs.claim(jp, 12345, "daily", 1, T0) and jp.cash == cashBefore + (def.reward.cash or 0), "claim pays the reward")
	check(not Jobs.claim(jp, 12345, "daily", 1, T0), "claim once")
	local second = jp.jobs.daily[2]
	local def2 = Jobs.def(second.id)
	Jobs.record(jp, 12345, def2.event, def2.target, T0)
	local cash2 = jp.cash
	local auto = Jobs.refresh(jp, 12345, T0 + 86400)
	check(auto >= 1 and jp.cash >= cash2 + (def2.reward.cash or 0) and jp.jobs.daily[1].progress == 0, "rollover auto-claims finished jobs")
	-- Reroll once a day, only unfinished jobs.
	local before = jp.jobs.daily[3].id
	check(Jobs.reroll(jp, 12345, 3, T0 + 86400) and jp.jobs.daily[3].id ~= before, "free swap")
	check(not Jobs.reroll(jp, 12345, 2, T0 + 86400), "one swap a day")
	-- All done today.
	for i = 1, 3 do
		local d = Jobs.def(jp.jobs.daily[i].id)
		Jobs.record(jp, 12345, d.event, d.target, T0 + 86400)
		Jobs.claim(jp, 12345, "daily", i, T0 + 86400)
	end
	check(Jobs.allDoneToday(jp), "all done today")
	-- A server whose clock is behind can't roll the jobs back.
	local before2 = jp.jobs.daily[1].id
	Jobs.refresh(jp, 12345, T0)
	check(jp.jobs.daily[1].id == before2 and jp.jobs.daily[1].claimed, "jobs only roll forward")
	-- Claim all in one set.
	local wk = jp.jobs.weekly
	for i = 1, 2 do
		local d = Jobs.def(wk[i].id)
		Jobs.record(jp, 12345, d.event, d.target, T0 + 86400)
	end
	check(Jobs.claimAllIn(jp, 12345, "weekly", T0 + 86400) >= 2, "claim all in a set")
	local jv = Jobs.view(jp)
	check(#jv.daily == 3 and jv.daily[1].text ~= nil and jv.rerollUsed, "jobs view for the board")

	-- Advice: facts, never guilt.
	local tipA = Advice.forHorse({ name = "Comet", fed = false, groomed = false, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipA.go == "stable" and string.find(tipA.next, "hay") ~= nil, "unfed: a meal is next")
	local tipB = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipB.go == "raceBoard", "cared for and rested: race next")
	local tipS = Advice.forHorse({ name = "Comet", league = "Rookie", fed = true, groomed = true, resting = false, cupOpen = true, stats = {} }, { garden = {} }, T0)
	check(string.find(tipS.next, "Cup") ~= nil and tipS.go == "raceBoard", "Cup open: win it to move up")
	local tipC = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = true, stats = {} }, { garden = {} }, T0)
	local guilt = false
	for _, tip in { tipA, tipB, tipC } do
		local text = string.lower(tip.fact .. " " .. tip.next)
		for _, w in { "miss", "hungry", "sad", "lonely", "neglect" } do
			if string.find(text, w) then guilt = true end
		end
	end
	check(not guilt and string.find(tipC.fact, "napping") ~= nil, "tips state facts, never guilt")
	check(Advice.trainNext({ stats = { speed = 50, accel = 60, stamina = 40, grit = 70 }, potential = { speed = 80, accel = 70, stamina = 85, grit = 75 } }) == "stamina",
		"train the stat with the most room")

	-- PaceMeter.countAtLeast: single good taps only.
	local passes = { { t0 = 0, t1 = 1, dir = 1, center = 0 }, { t0 = 1, t1 = 2, dir = -1, center = 0 } }
	check(PaceMeter.countAtLeast(passes, { 0.5, 1.5 }, 80) == 2, "two centred taps are Great")
	check(PaceMeter.countAtLeast(passes, { 0.5, 0.51, 1.5 }, 80) == 1, "a doubled pass doesn't count")
	check(PaceMeter.countAtLeast(passes, { 0.05 }, 80) == 0, "an edge tap isn't Great")

	-- Training and the vet (Stage 6) ------------------------------------------------------
	local Training = require("../../game/src/shared/Training")
	local th = Horse.starter("h7", "Clover", "bay", rng, T0)
	th.potential.speed = 85
	local okT, g1, msgT = Training.train(th, "speed", 100, T0)
	-- never trained = rested: 0.12 × 40 × 1.0 × 1.5 = 7.2, capped at 6 for the week
	check(okT and close(g1, 6, 1e-9) and close(th.stats.speed, 51, 1e-9) and string.find(msgT, "Rested") ~= nil, "first session: rested bonus, weekly cap")
	check(not Training.train(th, "accel", 100, T0 + 60), "weekly cap stops more training")
	check(not Training.ready(th, T0 + 60) and Training.ready(th, T0 + 8 * 86400), "cap resets next week")
	local th2 = Horse.starter("h8", "Daisy", "grey", rng, T0)
	th2.potential.stamina = 75
	local _, ga = Training.train(th2, "stamina", 0, T0)                    -- rested, poor score: 0.12 × 30 × 0.5 × 1.5 = 2.7
	local _, gb = Training.train(th2, "stamina", 100, T0 + 600)            -- not rested: 0.12 × 27.3 × 1.0 = 3.276 → capped at 3.3 (6 − 2.7)
	check(close(ga, 2.7, 1e-9) and close(gb, 3.3, 1e-9), "gain follows room left, score and rest; cap total")
	local th3 = Horse.starter("h9", "Pebble", "black", rng, T0)
	th3.potential.grit = th3.stats.grit
	check(not Training.train(th3, "grit", 100, T0), "no training past Potential")
	check(not Training.train(th3, "luck", 100, T0) and not Training.train(th3, "speed", 0 / 0, T0), "only real stats and scores")
	-- gains slow near Potential
	local near = Horse.starter("h10", "Sunny", "palomino", rng, T0)
	near.potential.accel, near.stats.accel = 80, 78
	local _, gn = Training.train(near, "accel", 100, T0)
	check(gn <= 2 and near.stats.accel <= 80, "never above Potential")
	-- vet
	local vh = Horse.starter("h11", "Biscuit", "bay", rng, T0)
	local okV, msgV, stamp = Training.checkup(vh, 80, T0)
	check(okV and stamp == "checkup" and vh.bond == 1 and string.find(msgV, "stamp") ~= nil, "first check-up: stamp and bond")
	local _, _, stamp2 = Training.checkup(vh, 80, T0 + 60)
	check(stamp2 == nil and vh.bond == 1, "one check-up a day counts")
	local _, _, stamp3 = Training.checkup(vh, 20, T0 + 86400)
	check(stamp3 == "potential" and vh.stamps.potential and Horse.view(vh, T0 + 86400, E).potential ~= nil, "second visit reveals Potential")

	-- Two courses (Stage 4) -------------------------------------------------------------
	local dirtCfg, turfCfg = TrackLayout.churchill, TrackLayout.churchillTurf
	local _, _, dz = TrackLayout.finishLine(dirtCfg)
	local _, _, tz = TrackLayout.finishLine(turfCfg)
	check(close(dz, tz, 1e-9), "both courses finish on the same line")
	check(TrackLayout.outerRadius(turfCfg) < dirtCfg.railRadius - 10, "turf course sits inside the dirt rail")
	local okLen = true
	for _, d in { "Sprint", "Mile", "Classic", "Marathon" } do
		local plan = TrackLayout.plan(turfCfg, TrackLayout.distances[d])
		if math.abs(plan.lengths[1] - TrackLayout.distances[d]) > 800 then okLen = false end -- gates snap forward to a straight
		for i = 2, 8 do
			if plan.lengths[i] < plan.lengths[1] - 1 then okLen = false end -- outer lanes run at least as far
		end
	end
	check(okLen, "turf races run about their distance in every lane")
	check(TrackLayout.courses.dirt == dirtCfg and TrackLayout.courses.turf == turfCfg, "course table")
	-- Spectator sound range (D-052): distance from a course's outer edge.
	local outer = TrackLayout.outerRadius(dirtCfg)
	check(TrackLayout.distanceToTrack(dirtCfg, 0, 0) == 0, "infield counts as at the track")
	check(TrackLayout.distanceToTrack(dirtCfg, outer - 1, 300) == 0, "on the home straight")
	check(close(TrackLayout.distanceToTrack(dirtCfg, outer + 100, -200), 100, 1e-9), "beside a straight")
	check(close(TrackLayout.distanceToTrack(dirtCfg, 0, dirtCfg.straight / 2 + outer + 60), 60, 1e-9), "beyond a turn")
	local grand = WorldLayout.places.track
	check(TrackLayout.distanceToTrack(dirtCfg, grand.x, grand.z) < 250, "the grandstand is within earshot")
	local plot1 = WorldLayout.plot(1)
	check(TrackLayout.distanceToTrack(dirtCfg, plot1.x, plot1.z) > 250, "the stables are out of earshot")
	check(TrackLayout.distanceToTrack(turfCfg, grand.x, grand.z) > TrackLayout.distanceToTrack(dirtCfg, grand.x, grand.z),
		"the turf course is further from the grandstand")

	-- Spectators (Stage 7) -------------------------------------------------------------
	local Fans = require("../../game/src/shared/Fans")
	check(Fans.raceXp({ 100, 100, 100, 100 }, true, 0) == Fans.XP_PER_RACE, "fan XP capped per race")
	check(Fans.raceXp({ 85, 62, 10 }, false, 0) == 3, "Great 2 + Good 1")
	check(Fans.raceXp({ 100, 100 }, true, 95) == 5, "daily cap")
	check(Fans.level(0) == 1 and Fans.level(250) == 3, "fan levels every 100 XP")
	local beats = {}
	for k = 1, 60 do beats[k] = k * 0.55 end
	local perfect = table.clone(beats)
	check(close(Fans.clapScore(beats, perfect), 100, 1e-9), "perfect claps score 100")
	local mash = {}
	for k = 1, 400 do mash[k] = k * 0.08 end
	check(Fans.clapScore(beats, mash) == 0, "mashing scores 0")
	local human = {}
	local hr = makeRng(5)
	for k, b in beats do human[k] = b + (hr:NextNumber() - 0.5) * 0.08 end
	local hs = Fans.clapScore(beats, human)
	check(hs > 40 and hs < 90 and not Fans.flagged(beats, human), "a human fan scores well and isn't flagged")
	check(Fans.flagged(beats, perfect), "perfectly steady claps are flagged")
	check(close(Fans.crowd({ 100 }), 1, 1e-9) and close(Fans.crowd({ 50, 50, 50 }), 0.625, 1e-9) and close(Fans.crowd({}), 0, 1e-9),
		"crowd: best fan full, assists small")
	check(Fans.crowd({ 60, 40 }) >= Fans.crowd({ 60 }) and Fans.crowd({ 60, 40, 30, 90 }) == Fans.crowd({ 90, 60, 40 }),
		"another fan never lowers the crowd; the fourth adds nothing")
	check(close(Fans.boost(1), 0.03, 1e-12), "full crowd boost")
	local fb = Fans.beats(makeRng(9), 10, 30, 0.55, 0.03)
	local okBeats = #fb > 30
	for k = 2, #fb do
		local g = fb[k] - fb[k - 1]
		if g < 0.55 * 0.85 - 1e-9 or g > 0.55 * 1.15 + 1e-9 then okBeats = false end
	end
	check(okBeats, "clap beats drift within ±15%")
	local entries = {
		{ id = "a", name = "A", score = 80, flagged = false }, { id = "b", name = "B", score = 95, flagged = true },
		{ id = "c", name = "C", score = 60, flagged = false }, { id = "d", name = "D", score = 0, flagged = false },
	}
	local top = Fans.topFans(entries)
	check(#top == 2 and top[1].id == "a" and Fans.rankOf(entries, "c") == 2 and Fans.rankOf(entries, "d") == nil
		and Fans.rankOf(entries, "b") == 1, "top fans skip flagged and zero; flagged fans still see their own rank")

	-- More horses (Stage 8) ---------------------------------------------------------------
	local Market = require("../../game/src/shared/Market")
	local stockA, stockB = Market.stock(T0), Market.stock(T0 + 3600)
	check(#stockA == Market.STOCK_SIZE and stockA[1].id == stockB[1].id and stockA[1].price == stockB[1].price, "same stock all week, every server")
	local nextWeek = Market.stock(T0 + 7 * 86400)
	check(nextWeek[1].id ~= stockA[1].id, "new stock next week")
	local priced = true
	for _, l in stockA do
		if l.price < 250 or l.stars < 1 or l.stars > 3 or not table.find(Market.MARKET_COATS, l.coat) then priced = false end
		for _, k in Horse.STATS do if l.potential[k] < l.stats[k] then priced = false end end
	end
	check(priced, "listings are sane")
	local cheap = { stats = { speed = 40, accel = 40, stamina = 40, grit = 40 }, potential = { speed = 66, accel = 66, stamina = 66, grit = 66 } }
	local fancy = { stats = { speed = 40, accel = 40, stamina = 40, grit = 40 }, potential = { speed = 92, accel = 92, stamina = 92, grit = 92 } }
	check(Market.price(fancy) > Market.price(cheap) * 2 and Market.stars(fancy.potential) == 3 and Market.stars(cheap.potential) == 1, "price and stars follow bloodline")
	check(Market.viewListing(stockA[1], false).potential == nil, "listing hides Potential numbers")
	local mp = Profile.new(T0)
	Profile.addHorse(mp, Horse.starter(Profile.newHorseId(mp), "Lucky", "bay", rng, T0))
	Profile.addHorse(mp, Horse.starter(Profile.newHorseId(mp), "Pip", "grey", rng, T0))
	mp.cash = 100000
	local l1 = stockA[1]
	local okB, msgB, hb = Market.buy(mp, l1.id, T0)
	check(okB and hb and #mp.horses == 3 and mp.cash == 100000 - l1.price and string.find(msgB, "pasture") ~= nil, "buy: pays, goes to the pasture when stalls are full")
	check(not Market.buy(mp, l1.id, T0), "each listing once per player")
	check(not Market.buy(mp, "m1_1", T0), "old listings can't be bought")
	mp.cash = 0
	check(not Market.buy(mp, stockA[2].id, T0) and #mp.horses == 3, "can't buy without the cash")
	-- stalls
	mp.cash = 300
	check(Market.nextStallPrice(mp) == 300 and Market.buyStall(mp) and mp.stalls == 3 and mp.cash == 0, "third stall")
	check(Profile.isStalled(mp, hb.id), "the pasture horse now has a stall")
	mp.cash = 100000
	for _ = 1, 3 do Market.buyStall(mp) end
	check(mp.stalls == 6 and not Market.buyStall(mp), "six stalls at most")
	-- taming
	local tp = Profile.new(T0)
	tp.items.carrot = nil
	check(not Market.canTame(tp, T0), "need a treat to tame")
	tp.items.apple = 2
	local okT2, _, th2 = Market.tame(tp, "appaloosa", makeRng(4), T0)
	check(okT2 and th2.coat == "appaloosa" and tp.items.apple == 1 and #tp.horses == 1, "taming uses a treat, keeps the wild coat")
	check(not Market.tame(tp, "dun", makeRng(5), T0 + 60), "one new friend a day")
	check(Market.tame(tp, "zebra", makeRng(6), T0 + 86400), "tomorrow again (unknown coats become a wild one)")
	check(table.find(Market.WILD_COATS, tp.horses[2].coat) ~= nil, "wild coats only")
	local mx, mz = Market.wildPosition(WorldLayout.meadow, 2, 12345.6)
	local mx2, mz2 = Market.wildPosition(WorldLayout.meadow, 2, 12345.6)
	local inMeadow = true
	for k = 0, 40 do
		local x, z = Market.wildPosition(WorldLayout.meadow, 3, k * 3.7)
		if (x - WorldLayout.meadow.x) ^ 2 + (z - WorldLayout.meadow.z) ^ 2 > WorldLayout.meadow.radius ^ 2 then inMeadow = false end
	end
	check(mx == mx2 and mz == mz2 and inMeadow, "wild horses: same place for everyone, always in the meadow")
	-- full stable
	local fp = Profile.new(T0)
	for k = 1, Market.MAX_HORSES do Profile.addHorse(fp, Horse.starter(Profile.newHorseId(fp), "H" .. k, "bay", rng, T0)) end
	fp.items.treat = 3
	fp.cash = 100000
	check(not Market.canTame(fp, T0) and not Market.buy(fp, stockA[3].id, T0), "stable full at 20 horses")
	check(Market.rename(fp, fp.horses[1].id, "Sunny", "Moon") and fp.horses[1].name == "Sunny Moon" and not Market.rename(fp, fp.horses[1].id, "Bad", nil),
		"rename with word chips only")

	-- Leagues (Stage 9) ---------------------------------------------------------------------
	local Leagues = require("../../game/src/shared/Leagues")
	check(Leagues.UNLOCK.Rookie == GameConfig.stakesUnlockPoints.Rookie and Leagues.UNLOCK.Gold == GameConfig.stakesUnlockPoints.Gold,
		"Cup thresholds match the D-013 points")
	local lh = Horse.starter("h30", "Rocket", "bay", rng, T0)
	check(Leagues.pointsToCup(lh) == 100 and not Leagues.cupOpen(lh, 50), "Cup closed at first")
	check(Leagues.canEnter(lh, { league = "Rookie" }, 50) and not Leagues.canEnter(lh, { league = "Bronze" }, 50), "own league only")
	check(not Leagues.canEnter(lh, { league = "Rookie", cup = true }, 50), "no Cup before the points")
	lh.points = 100
	check(Leagues.cupOpen(lh, 50) and Leagues.canEnter(lh, { league = "Rookie", cup = true }, 50), "Cup open at 100 points")
	local strong = Horse.starter("h31", "Mighty", "grey", rng, T0)
	check(Leagues.cupOpen(strong, 60) and not Leagues.canEnter(strong, { league = "Rookie" }, 60)
		and Leagues.canEnter(strong, { league = "Rookie", practice = true }, 60), "over-strong: Cup open, regular closed, Practice open")
	check(Leagues.promote(lh) == "Bronze" and lh.league == "Bronze" and lh.points == 0, "a Cup win promotes and resets points")
	local champ = Horse.starter("h32", "Star", "black", rng, T0)
	champ.league = "Champion"
	check(Leagues.promote(champ) == nil and not Leagues.cupOpen(champ, 99) and Leagues.pointsToCup(champ) == nil, "Champion is the top")
	local rp = Profile.new(T0)
	local r1 = Horse.starter(Profile.newHorseId(rp), "Old Timer", "bay", rng, T0)
	local r2 = Horse.starter(Profile.newHorseId(rp), "Young One", "grey", rng, T0)
	Profile.addHorse(rp, r1)
	Profile.addHorse(rp, r2)
	r1.record.races, r1.record.wins = 40, 9
	local plaque = Leagues.retire(rp, r1.id, T0)
	check(plaque and plaque.wins == 9 and #rp.horses == 1 and rp.activeHorse == r2.id and rp.hallOfFame[1].name == "Old Timer",
		"retiring keeps a Hall of Fame plaque")
	check(Leagues.retire(rp, "nope", T0) == nil, "only your horses retire")

	-- First ten minutes (Stage 10) -------------------------------------------------------
	local Tour = require("../../game/src/shared/Tour")
	local flags = {}
	check(Tour.current(flags) == 1 and Tour.STEPS[1].event == "race", "tour starts with a race")
	local _, moved = Tour.advance(flags, "feed")
	check(not moved and Tour.current(flags) == 1, "doing something else doesn't skip the current step")
	Tour.advance(flags, "race")
	check(Tour.current(flags) == 3, "a step done early (feeding before racing) is skipped later")
	for _, step in Tour.STEPS do Tour.advance(flags, step.event) end
	check(Tour.current(flags) == nil and flags.tourDone, "doing each step finishes the tour")
	local f2 = {}
	Tour.skip(f2)
	check(Tour.current(f2) == nil, "the tour can be skipped")
	check(Tour.text(Tour.STEPS[2], "Comet") == "Great ride! Head to your barn and give Comet some hay.", "horse name in the text")

	-- Diamond store (D-050) ---------------------------------------------------------------
	local Style = require("../../game/src/shared/Style")
	local DiamondProducts = require("../../game/src/shared/DiamondProducts")
	local flat = true
	for _, pack in DiamondProducts.packs do
		if pack.diamonds ~= pack.robux or pack.robux % 25 ~= 0 then flat = false end
	end
	check(flat, "1 Diamond = 1 Robux in every pack")
	local sane = true
	for _, it in Style.ITEMS do
		if it.price % 25 ~= 0 then sane = false end
		if it.fanLevel and Style.forSale(it) then sane = false end
		local lower = string.lower(it.name)
		for _, w in { "lucky", "coat", "horse ", "cash", "energy", "speed", "trophy", "rosette", "reroll" } do
			if string.find(lower, w, 1, true) then sane = false end
		end
	end
	check(sane, "shop sells looks only (no luck, coats, cash, speed, trophies or rerolls); prices in steps of 25")
	local sp = Profile.new(T0)
	check(sp.diamonds == 0 and Style.worn(sp, "cloth").id == "cloth_plain" and Style.worn(sp, "paint").id == "paint_classic", "free starters worn")
	check(not Style.buy(sp, "cloth_stars", T0) and sp.diamonds == 0, "can't buy without Diamonds")
	sp.diamonds = 100
	local okB = Style.buy(sp, "cloth_stars", T0)
	check(okB and sp.diamonds == 25 and Style.worn(sp, "cloth").id == "cloth_stars", "buy and wear")
	check(not Style.buy(sp, "cloth_stars", T0) and not Style.buy(sp, "fan_star", T0), "no double buys; fan gear isn't sold")
	check(Style.canReturn(sp, "cloth_stars", T0 + 3600) and not Style.canReturn(sp, "cloth_stars", T0 + 86400), "return window is a day")
	check(Style.giveBack(sp, "cloth_stars", T0 + 60) and sp.diamonds == 100 and Style.worn(sp, "cloth").id == "cloth_plain", "a return gives every Diamond back")
	sp.diamonds = 200
	Style.buy(sp, "yard_bench", T0)
	Style.buy(sp, "yard_lanterns", T0)
	check(#Style.yard(sp) == 2 and Style.unequip(sp, "yard_bench") and #Style.yard(sp) == 1, "yard pieces placed one by one")
	check(not Style.owns(sp, "fan_star"), "star flag needs Fan level 3")
	sp.fan = { xp = 250 }
	check(Style.owns(sp, "fan_star") and Style.equip(sp, "fan_star"), "earned at Fan level 3")
	sp.diamonds = 75
	Style.buy(sp, "helmet_star", T0)
	check(not Style.hasSet(sp, "star"), "Star Set needs the cloth too")
	sp.diamonds = 75
	Style.buy(sp, "cloth_stars", T0)
	check(Style.hasSet(sp, "star"), "Star Set complete")
	local migrated = Profile.migrate(sp, T0)
	check(migrated.diamonds == sp.diamonds and migrated.style.owned.cloth_stars, "Diamonds and looks saved")

	-- Running legs (D-051) ---------------------------------------------------------------
	local HorseLegs = require("../../game/src/shared/HorseLegs")
	check(HorseLegs.gaitFor(0) == "stand" and HorseLegs.gaitFor(8) == "walk" and HorseLegs.gaitFor(20) == "trot"
		and HorseLegs.gaitFor(56) == "gallop", "gait by speed (race pace gallops)")
	local maxA, okDiag = 0, true
	for k = 0, 99 do
		local p = k / 100
		for _, leg in HorseLegs.LEGS do maxA = math.max(maxA, math.abs(HorseLegs.angle("gallop", leg, p))) end
		if math.abs(HorseLegs.angle("trot", "LegFL", p) / 1.1 - HorseLegs.angle("trot", "LegBR", p) / 0.9) > 1e-9 then okDiag = false end
	end
	check(maxA > 30 and maxA <= HorseLegs.GAITS.gallop.amp * 1.1 + 1e-6, "gallop swings big but never past its limit")
	check(okDiag, "trot moves diagonal pairs together")
	check(close(HorseLegs.advance(0.9, "gallop", HorseLegs.GAITS.gallop.stride * 0.25), 0.15, 1e-9), "phase follows distance (one stride per stride length)")
	check(HorseLegs.angle("stand", "LegFL", 0.3) == 0, "standing horses don't swing")
	check(HorseLegs.gaitFor(16) == "trot" and HorseLegs.gaitFor(46) == "gallop", "riding trots at riding speed, gallops on Gallop (D-056)")
	check(HorseLegs.gaitFor(10) == "walk", "slow walking is a walk")
	-- The body drops by the lowest hoof's lift, so a hoof is always planted (D-056).
	local lift = HorseLegs.newState()
	check(HorseLegs.lowestLift(lift, 2.45) == 0, "standing: no hoof is lifted")
	local maxLift = 0
	for _ = 1, 600 do
		HorseLegs.step(lift, 46 / 60, 1 / 60, 46)
		local l = HorseLegs.lowestLift(lift, 2.45)
		check(l >= 0, "a hoof lift is never negative")
		maxLift = math.max(maxLift, l)
	end
	check(maxLift < 2.45 * (1 - math.cos(math.rad(HorseLegs.GAITS.gallop.amp * 1.1))),
		"the lowest hoof is never lifted as high as one leg's full swing")
	-- A planted hoof keeps up with the ground: stride over the hoof's sweep (D-056).
	for _, g in { "walk", "trot" } do
		check(HorseLegs.GAITS[g].stride <= 7, g .. " stride is short enough that hooves don't skate")
	end
	-- Gait changes cross-fade: no leg jumps more than a few degrees in a frame.
	local st = HorseLegs.newState()
	local worst, steady, dt = 0, 0, 1 / 60
	local last = {}
	local speeds = {}
	for f = 1, 240 do speeds[f] = 56 end           -- gallop
	for f = 241, 300 do speeds[f] = 56 - (f - 240) * 0.6 end -- slow through trot
	for f = 301, 420 do speeds[f] = 14 end          -- walk
	for f = 1, #speeds do
		HorseLegs.step(st, speeds[f] * dt, dt, speeds[f])
		for _, leg in HorseLegs.LEGS do
			local a = HorseLegs.poseAngle(st, leg)
			if last[leg] and f > 30 then
				local d = math.abs(a - last[leg])
				if f <= 240 then steady = math.max(steady, d) else worst = math.max(worst, d) end
			end
			last[leg] = a
		end
	end
	-- The fastest a leg moves in any steady gait on this speed profile (a short-stride trot near its
	-- top speed swings faster per frame than a gallop, D-056): a cross-fade must never beat it.
	for _, top in { 56, HorseLegs.GALLOP_FROM - 0.1, HorseLegs.WALK_BELOW - 0.1 } do
		local s2, prev = HorseLegs.newState(), {}
		for f = 1, 120 do
			HorseLegs.step(s2, top * dt, dt, top)
			for _, leg in HorseLegs.LEGS do
				local a = HorseLegs.poseAngle(s2, leg)
				if prev[leg] and f > 60 then steady = math.max(steady, math.abs(a - prev[leg])) end
				prev[leg] = a
			end
		end
	end
	check(worst <= steady * 1.05, string.format("legs never jump when the gait changes (worst step %.1f° vs %.1f° in a steady gait)", worst, steady))
	for f = 1, 60 do HorseLegs.step(st, 0, dt, 0) end
	check(math.abs(HorseLegs.poseAngle(st, "LegFL")) < 1e-6, "a horse that stops eases back to standing")
	-- Gallop toggled on a ride: speed jumps 16 -> 46 (and back) in three frames, crossing two gaits.
	for _, ramp in { { 16, 46 }, { 46, 16 } } do
		local s2 = HorseLegs.newState()
		local w2, last2 = 0, {}
		for f = 1, 300 do
			local sp = if f <= 120 then ramp[1] elseif f <= 123 then ramp[1] + (ramp[2] - ramp[1]) * (f - 120) / 3 else ramp[2]
			HorseLegs.step(s2, sp * dt, dt, sp)
			for _, leg in HorseLegs.LEGS do
				local a = HorseLegs.poseAngle(s2, leg)
				if last2[leg] and f > 30 then w2 = math.max(w2, math.abs(a - last2[leg])) end
				last2[leg] = a
			end
		end
		-- A few fast-trot frames while the fade finishes run a little quicker than a steady gallop;
		-- a snap (the bug) was 20-42°.
		check(w2 <= steady * 1.15, string.format("Gallop toggle %d->%d doesn't snap the legs (worst %.1f°)", ramp[1], ramp[2], w2))
	end

	trainingGroundTests(check, close)
	trainingRideTests(check, close)
	trainingJitterTests(check, close)
	trainingT3Tests(check, close)
	trainingT3ReviewTests(check, close)
	trainingT4Tests(check, close)

end
