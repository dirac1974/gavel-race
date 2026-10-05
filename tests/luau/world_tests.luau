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
	check(close(ac.flag.ax - ac.stall[3], TCfg.accel.dash, 1e-9), "the flag is the dash length from the gate")

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
	check(maxA > 30 and maxA <= 36 * 1.1 + 1e-6, "gallop swings big but never past its limit")
	check(okDiag, "trot moves diagonal pairs together")
	check(close(HorseLegs.advance(0.9, "gallop", 22 * 0.25), 0.15, 1e-9), "phase follows distance (one stride per stride length)")
	check(HorseLegs.angle("stand", "LegFL", 0.3) == 0, "standing horses don't swing")
	check(HorseLegs.gaitFor(16) == "walk" and HorseLegs.gaitFor(46) == "gallop", "riding walks at walk speed, gallops on Gallop")
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
	check(worst <= steady * 1.05, string.format("legs never jump when the gait changes (worst step %.1f° vs %.1f° galloping)", worst, steady))
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

end
