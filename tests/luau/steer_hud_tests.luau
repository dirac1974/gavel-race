--!strict
-- D-057 N4: the boxed-in arrows (SteerHud), the chips' rate limit (SteerChips), and what reaches
-- the rider (Trip.riderLane over SteerLane): grey arrows, the wait ring, the wobble, "No room yet"
-- and "Gap!", never for spectators or a rider's first races.
local fs = require("@lune/fs")
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
local SteerHud = require("../../game/src/shared/SteerHud")
local SteerChips = require("../../game/src/shared/SteerChips")

local STEER, SHUD = GameConfig.steering, GameConfig.steerHud

local function lane(inSide: string, outSide: string, wait: number?, waitAt: number?, tucking: boolean?, tgt: number?, t: number?): any
	return { tgt = tgt or 3, dest = tgt or 3, ack = 0, wait = wait or 0, waitAt = waitAt or 0, tucking = tucking == true,
		inSide = inSide, outSide = outSide, t = t or 0 }
end

local function makeRng(seed0: number)
	local seed = seed0
	return { NextNumber = function(_self): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end }
end

-- A copy of a trip state deep enough to step on its own (the config, race and geometry are shared).
local SHARED = { cfg = true, race = true, geo = true, baselineRow = true }
local function copyTrip(v: any, top: boolean): any
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in v do
		if top and SHARED[k] then o[k] = x else o[k] = copyTrip(x, false) end
	end
	return o
end

-- WCAG relative luminance of an sRGB colour 0..255.
local function luminance(rgb: { number }): number
	local function ch(c: number): number
		local x = c / 255
		return if x <= 0.03928 then x / 12.92 else ((x + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(rgb[1]) + 0.7152 * ch(rgb[2]) + 0.0722 * ch(rgb[3])
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	check(SHUD.greyArrows == true and SHUD.waitRing == true and SHUD.greyAfterSeconds == 0.2 and SHUD.noRoomChipAfter == 1
		and SHUD.noRoomChipEvery == 10 and SHUD.gapChipAfterWait == 0.5 and SHUD.chipMinGap == 2 and SHUD.wobbleDeg == 4
		and SHUD.wobbleSeconds == 0.2, "GameConfig.steerHud holds D-057's boxed-in values")
	local bone = { 0xF4, 0xEF, 0xE6 } -- RaceController's BUTTON_COLOUR
	local ratio = (luminance(bone) + 0.05) / (luminance(SHUD.greyRgb) + 0.05)
	check(ratio >= 2 and ratio < 3 and SHUD.greyRgb[1] < 200 and not (SHUD.greyRgb[1] > SHUD.greyRgb[2] + 40),
		string.format("the grey arrow stands out from the bone-white one (%.2f:1, at least 2:1) and stays soft (never red)", ratio))

	-- The arrow states ---------------------------------------------------------------------------
	local h = SteerHud.new()
	local function arrows(l: any, now: number?, shown: boolean?, cfg: any?): (any, any)
		local a, b = SteerHud.arrows(h, l, now or 10, STEER, cfg or SHUD, if shown == nil then true else shown)
		return { grey = a.grey, ring = a.ring }, { grey = b.grey, ring = b.ring }
	end
	local function settled(l: any, now: number?): (any, any) -- the same state, held past greyAfterSeconds
		h = SteerHud.new()
		arrows(l, (now or 10) - SHUD.greyAfterSeconds)
		return arrows(l, now)
	end
	local i1, o1 = settled(lane("free", "free"))
	check(not i1.grey and not o1.grey and i1.ring == -1 and o1.ring == -1, "room both sides: both arrows normal, no ring")
	local _, o2 = settled(lane("free", "blocked"))
	check(o2.grey, "a horse leaves no room outside: Out ▶ greys")
	local i3 = settled(lane("tuck", "free"))
	check(not i3.grey, "no room inside but tuck-back finds a slot: ◀ In stays normal (it still works at once)")
	local i4 = settled(lane("blocked", "free"))
	check(i4.grey, "no room inside and no tuck slot (trapped): ◀ In greys")
	local i5, o5 = settled(lane("edge", "edge"))
	check(not i5.grey and not o5.grey, "at the rail or the outside nothing greys: no horse is there")
	h = SteerHud.new()
	local _, b1 = arrows(lane("free", "blocked"), 20)
	local _, b2 = arrows(lane("free", "blocked"), 20.1)
	local _, b3 = arrows(lane("free", "free"), 20.15)
	local _, b4 = arrows(lane("free", "blocked"), 20.2)
	local _, b5 = arrows(lane("free", "blocked"), 20.2 + SHUD.greyAfterSeconds)
	local _, b6 = arrows(lane("free", "free"), 20.5)
	check(not b1.grey and not b2.grey and not b3.grey and not b4.grey and b5.grey and not b6.grey,
		"Out ▶ greys only once its side has stayed blocked greyAfterSeconds (a horse sweeping past never blinks it), and comes back at once")
	local i6 = settled(lane("free", "free", -1, 8))
	check(i6.ring == 1, "an inward press waiting for room: its ring is lit (it waits until room)")
	local _, o7 = settled(lane("free", "blocked", 1, 9.25), 10)
	check(close(o7.ring, 0.75 / STEER.gapWaitSeconds, 1e-12), "an outward press waiting: its ring fills over gapWaitSeconds")
	local _, o8 = settled(lane("free", "blocked", 1, 5), 10)
	check(o8.ring == 1, "...and stops full")
	local _, o8b = settled(lane("free", "blocked", 1, 10.6), 10)
	check(o8b.ring == 0, "a press still held by a reverse gap (its wait starts later) shows an empty ring")
	local back = Trip.d054Config(STEER)
	h = SteerHud.new()
	local _, o8c = SteerHud.arrows(h, lane("free", "blocked", 1, 9.5), 10, back, SHUD, true)
	check(close(o8c.ring, 0.5 / STEER.outwardWaitSeconds, 1e-12) and SteerHud.waitLimit(back, 1) == STEER.outwardWaitSeconds
		and SteerHud.waitLimit(back, -1) == 0 and SteerHud.waitLimit(STEER, 1) == STEER.gapWaitSeconds,
		"the switch-back (blockedPress = \"d054\") times the ring and the wobble by D-054's outward wait")
	local i9, o9 = arrows(lane("blocked", "blocked", -1, 8), 10, false)
	check(not i9.grey and not o9.grey and i9.ring == -1 and o9.ring == -1,
		"shown = false (a spectator, or a rider's first races): no grey arrow, no ring")
	local i10, o10 = arrows(nil)
	check(not i10.grey and not o10.grey, "before the server has said anything: normal arrows")
	local off = table.clone(SHUD)
	off.greyArrows, off.waitRing = false, false
	h = SteerHud.new()
	arrows(lane("blocked", "blocked", 1, 9), 9, true, off)
	local a11, b11 = arrows(lane("blocked", "blocked", 1, 9), 10, true, off)
	check(not a11.grey and not b11.grey and b11.ring == -1, "greyArrows = false, waitRing = false: the switch-back to plain arrows")

	-- The arrows mean what a press would do, in real fields (varied chances, riders pressing) --------
	-- On every tick a rider could press at once, a copy of the trip takes the press and steps a tick:
	-- ◀ In "works" if the horse moves in or tuck-back starts, Out ▶ if it moves out. The arrow shown
	-- is the server's state one tick old (what reached the screen), mapped by SteerHud with no
	-- delay: grey must mean the press wouldn't act, normal that it would.
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local plain = table.clone(SHUD)
	plain.greyAfterSeconds = 0
	local styles = { "masher", "ditherer", "casual", "railseek" }
	local inN, inBad, inGrey, inTuck, outN, outBad, outGrey = 0, 0, 0, 0, 0, 0, 0
	for ci, courseId in { "dirt", "turf" } do
		for di, distanceName in { "Sprint", "Mile", "Marathon" } do
			for sd = 1, 2 do
				local track = TrackLayout.courses[courseId]
				local plan = TrackLayout.plan(track, TrackLayout.distances[distanceName])
				local rng = makeRng(sd * 7919 + ci * 31 + di)
				local humans, riders, style = {}, {}, {}
				for r, st in styles do
					table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 44 + 4 * r, isBot = false })
					riders["rider" .. r] = if sd == 2 then "manual" else "smart"
					style["rider" .. r] = st
				end
				local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng)
				local session = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Silver", lanes = lanes, rng = rng })
				session:assignPosts(RaceSession.postOrder(GameConfig, #session.lanes, rng))
				local trip = Trip.start(GameConfig, session, track, plan, TripBaseline[courseId][distanceName], rng, TrackLayout, riders)
				local pressRng = makeRng(sd * 131 + ci * 7 + di)
				local seqs, idx, flips, prevInfo, nextRail = {}, {}, {}, {}, {}
				for _, hm in humans do
					seqs[hm.id], idx[hm.id], flips[hm.id], nextRail[hm.id] = 0, session:laneIndex(hm.id), 1, 1 + 2 * pressRng:NextNumber()
				end
				local k = 0
				local hudProbe = SteerHud.new()
				while not trip.locked do
					local t = k * trip.dt
					for _, hm in humans do
						local i = idx[hm.id]
						local shown = prevInfo[hm.id]
						local ready = shown ~= nil and t > 0.5 and t < trip.lockT - 0.2 and trip.want[i] == 0 and trip.queued[i] == 0
							and trip.x[i] == trip.tgt[i] and t - trip.lastChange[i] >= STEER.minRequestGap and t >= trip.steadyUntil[i]
						if ready then
							local inA, outA = SteerHud.arrows(hudProbe, shown, t, STEER, plain, true)
							for _, d in { -1, 1 } do
								local edge = trip.tgt[i] + d < 1 or trip.tgt[i] + d > GameConfig.lanes
								local held = trip.lastDir[i] == -d and t - trip.arrivedAt[i] < Trip.reverseGap(trip, i, t)
								local bounce = trip.lastPressDir[i] == d and t - trip.lastPressAt[i] < STEER.pressBounceSeconds
								if not (edge or held or bounce) then
									local c = copyTrip(trip, true)
									c.recent[i] = {}
									Trip.submit(c, session, hm.id, d, 1e9, t)
									Trip.advance(c, session.live, t)
									local works = (c.tgt[i] - trip.tgt[i]) * d > 0 or (d < 0 and c.tucking[i] == true)
									local grey = if d < 0 then inA.grey else outA.grey
									if d < 0 then
										inN += 1
										if grey then inGrey += 1 end
										if shown.inSide == "tuck" then inTuck += 1 end
										if grey == works then inBad += 1 end
									else
										outN += 1
										if grey then outGrey += 1 end
										if grey == works then outBad += 1 end
									end
								end
							end
						end
					end
					for _, hm in humans do -- the riders press
						local i = idx[hm.id]
						local d, st = 0, style[hm.id]
						if st == "masher" then
							if pressRng:NextNumber() < 0.4 then d = if pressRng:NextNumber() < 0.5 then -1 else 1 end
						elseif st == "ditherer" then
							if k % 2 == 0 then
								flips[hm.id] = -flips[hm.id]
								d = flips[hm.id]
							end
						elseif st == "casual" then
							local u = pressRng:NextNumber()
							if u < 0.02 and Trip.laneAfter(trip, i) > 1 then d = -1 elseif u < 0.025 then d = 1 end
						elseif t >= nextRail[hm.id] and Trip.laneAfter(trip, i) > 1 then
							d = -1
							nextRail[hm.id] = t + 1 + 2 * pressRng:NextNumber()
						end
						if d ~= 0 and t < trip.lockT then
							seqs[hm.id] += 1
							Trip.submit(trip, session, hm.id, d, seqs[hm.id], t)
						end
					end
					Trip.advance(trip, session.live, t)
					for _, hm in humans do
						prevInfo[hm.id] = Trip.riderLane(trip, idx[hm.id], prevInfo[hm.id] or {}, trip.tick * trip.dt)
					end
					k += 1
				end
			end
		end
	end
	check(inN > 2000 and inGrey > 0 and inTuck > 0 and inBad / inN < 0.01,
		string.format("◀ In, behaviourally: grey when an inward press wouldn't move or tuck back, normal when it would (%d presses tried, %d grey, %d tuck-back states, %.2f%% wrong with the state one tick old)",
			inN, inGrey, inTuck, 100 * inBad / math.max(inN, 1)))
	check(outN > 2000 and outGrey > 0 and outBad / outN < 0.01,
		string.format("Out ▶, behaviourally: grey when an outward press wouldn't move, normal when it would (%d presses tried, %d grey, %.2f%% wrong)",
			outN, outGrey, 100 * outBad / math.max(outN, 1)))

	-- Messages: the wobble and "Gap!", on the server's clock --------------------------------------
	local m = SteerHud.new()
	SteerHud.message(m, lane("free", "blocked", 1, 20, false, 3, 20), STEER, SHUD)
	local w1, g1 = SteerHud.message(m, lane("free", "blocked", 0, 0, false, 3, 20 + STEER.gapWaitSeconds), STEER, SHUD, 1, 20)
	check(w1 == 1 and not g1, "an outward press that waited gapWaitSeconds (server time) and dropped: Out ▶ wobbles")
	local c = SteerHud.new()
	SteerHud.message(c, lane("free", "blocked", 1, 20, false, 3, 20), STEER, SHUD)
	local w2 = SteerHud.message(c, lane("free", "blocked", 0, 0, false, 3, 20.4), STEER, SHUD, -1, 20.35)
	check(w2 == 0, "a wait you cancel by pressing the other way doesn't wobble")
	local c2 = SteerHud.new()
	SteerHud.message(c2, lane("free", "blocked", 1, 20, false, 3, 20), STEER, SHUD)
	local w3 = SteerHud.message(c2, lane("free", "blocked", 0, 0, false, 3, 21.6), STEER, SHUD, -1, 21.45)
	check(w3 == 0, "...even near the end of its wait")
	local gq = SteerHud.new()
	SteerHud.message(gq, lane("blocked", "free", -1, 30, false, 4, 30), STEER, SHUD)
	local w4, g4 = SteerHud.message(gq, lane("free", "free", 0, 0, false, 3, 30.6), STEER, SHUD)
	check(w4 == 0 and g4, "a wait of at least gapChipAfterWait (server time) that ends in the move: \"Gap!\"")
	local gs = SteerHud.new()
	SteerHud.message(gs, lane("blocked", "free", -1, 30, false, 4, 30), STEER, SHUD)
	local _, g5 = SteerHud.message(gs, lane("free", "free", 0, 0, false, 3, 30.3), STEER, SHUD)
	check(not g5, "...not after a short one, however late its message arrives")
	local gt = SteerHud.new()
	SteerHud.message(gt, lane("tuck", "free", -1, 30, false, 4, 30), STEER, SHUD)
	SteerHud.message(gt, lane("tuck", "free", -1, 30, true, 4, 30.2), STEER, SHUD)
	local _, g6 = SteerHud.message(gt, lane("free", "free", 0, 0, false, 3, 31.5), STEER, SHUD)
	check(not g6, "...nor after a wait that saw a tuck-back (\"Tucked in!\" says that one)")
	local wi = SteerHud.new()
	SteerHud.message(wi, lane("blocked", "free", -1, 30, false, 4, 30), STEER, SHUD)
	local w6 = SteerHud.message(wi, lane("blocked", "free", 0, 0, false, 4, 60), STEER, SHUD)
	check(w6 == 0, "an inward wait (gapWaitInSeconds 0: it waits until room) never drops, so never wobbles")

	-- The chips' rate limit -----------------------------------------------------------------------
	local ch = SteerChips.new()
	local waiting = lane("free", "blocked", 1, 50)
	check(not SteerChips.noRoom(ch, waiting, 50.9, SHUD), "\"No room yet\" not before a press has waited noRoomChipAfter")
	check(SteerChips.noRoom(ch, waiting, 51.0, SHUD), "...then once")
	check(not SteerChips.noRoom(ch, waiting, 51.5, SHUD), "...once per wait")
	local again = lane("free", "blocked", 1, 53)
	check(not SteerChips.noRoom(ch, again, 55, SHUD), "...and at most once per noRoomChipEvery")
	local later = lane("free", "blocked", 1, 60)
	check(SteerChips.noRoom(ch, later, 61.1, SHUD), "...after which a new wait may say it again")
	local tuck = SteerChips.new()
	check(not SteerChips.noRoom(tuck, lane("tuck", "free", -1, 70, true), 72, SHUD), "never while a tuck-back is under way")
	check(not SteerChips.noRoom(SteerChips.new(), lane("free", "blocked", 1, 80.5), 80.6, SHUD),
		"never while a reverse gap still holds the press (its wait for room hasn't started)")
	local crowd = SteerChips.new()
	SteerChips.shown(crowd, 80.5)
	check(not SteerChips.noRoom(crowd, lane("free", "blocked", 1, 79), 81, SHUD)
		and SteerChips.noRoom(crowd, lane("free", "blocked", 1, 79), 82.6, SHUD),
		"never within chipMinGap of another steering chip (good news always shows first)")
	check(not SteerChips.noRoom(SteerChips.new(), nil, 99, SHUD) and not SteerChips.noRoom(SteerChips.new(), lane("free", "free"), 99, SHUD),
		"nothing to say with no wait")

	-- What reaches the rider, and who sees it ----------------------------------------------------
	local track = TrackLayout.courses.dirt
	local geo = TrackLayout.phaseA(track, TrackLayout.plan(track, TrackLayout.distances.Mile))
	local st = Trip.new({ 1, 2 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, geo, STEER, { "manual", "manual" }, Trip.raceParams(GameConfig))
	local out = Trip.riderLane(st, 1, {}, 0)
	check(out.inSide == "edge" and out.wait == 0 and out.waitAt == 0 and out.tucking == false and out.tgt == 1 and out.dest == 1 and out.t == 0,
		"Trip.riderLane: on the rail the inside is the edge; nothing waiting, no tuck-back; the state's race time")
	-- A press held by a reverse gap: its wait for room starts when the gap ends, steadily.
	local hold = Trip.new({ 4 }, { 1 }, { 0.5, 0.5 }, geo, STEER, { "manual" }, Trip.raceParams(GameConfig))
	local DT = 1 / STEER.tickHz
	Trip.step(hold, { 1 }, { { 1, -1 } }, 1.0, DT)
	local tick = 11
	while hold.x[1] ~= hold.tgt[1] do
		Trip.step(hold, { 1 }, {}, tick * DT, DT)
		tick += 1
	end
	Trip.step(hold, { 1 }, { { 1, 1 } }, tick * DT, DT) -- the other way, at once: queued behind the gap
	tick += 1
	local starts = {}
	for _ = 1, 3 do
		Trip.step(hold, { 1 }, {}, tick * DT, DT)
		tick += 1
		local info = Trip.riderLane(hold, 1, {}, tick * DT)
		if info.wait ~= 0 then table.insert(starts, info.waitAt) end
	end
	check(#starts == 3 and starts[1] == starts[2] and starts[2] == starts[3]
		and close(starts[1], hold.arrivedAt[1] + Trip.reverseGap(hold, 1, tick * DT), 1e-9),
		"a press held by a reverse gap: its reported wait starts when the gap ends, the same every tick (no resend, no flicker)")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	check(string.find(rs, "for p in steers do", 1, true) ~= nil and string.find(rs, "Trip.riderLane(trip, i, scratchOwn, trip.tick * trip.dt)", 1, true) ~= nil
		and string.find(rs, "own.outSide, own.t, c.id)", 1, true) ~= nil,
		"RaceService sends SteerLane (the state's time, then the course id last) only to riders with the buttons")
	check(string.find(rc, "or s.race ~= cueRace or not s.shown or s.locked then return end", 1, true) ~= nil
		and string.find(rc, "SteerHud.arrows(s.hud, s.lane, raceNow, STEER, SHUD, s.shown)", 1, true) ~= nil,
		"RaceController paints the boxed-in arrows only for a rider with the buttons, up to the lock")
	check(string.find(rv, "_inSide, _outSide, _t, courseId)", 1, true) ~= nil, "RaceView reads SteerLane's course id where it now sits (last)")
	local chips = {}
	for text in string.gmatch(rc, "showChip%(\"([^\"]+)\"") do table.insert(chips, string.lower(text)) end
	local kind = #chips >= 6
	for _, text in chips do
		for _, word in { "boxed", "penalty", "cost", "lost", "lose", "hurry", "quick", "fail", "wrong", "bet", "odds" } do
			if string.find(text, word, 1, true) then kind = false end
		end
	end
	check(kind and table.find(chips, "no room yet") ~= nil and table.find(chips, "gap!") ~= nil,
		`the steering chips are kind: no blame, cost, hurry or wagering words ({#chips} chips, "No room yet" and "Gap!" among them)`)
	local grownUps = fs.readFile("game/src/client/GrownUps.client.luau")
	check(string.find(grownUps, "There's no penalty for being boxed in; a horse held wide just runs a little farther.", 1, true) ~= nil
		and string.find(grownUps, "never costs points", 1, true) == nil,
		"the grown-ups page: no penalty for being boxed in (and no promise about points: brushes cost the mover in N5)")
	local order = {}
	local tab = string.match(grownUps, "local function grownUpsTab%(%)(.-)\nend") :: string
	for n in string.gmatch(tab, ", (%d+)%)\r?\n") do table.insert(order, tonumber(n) :: number) end
	local sorted = #order >= 10
	for k = 2, #order do
		if order[k] <= order[k - 1] then sorted = false end
	end
	check(sorted, "the grown-ups paragraphs sort in the order they're written (steering after how races work, before Diamonds)")
end
