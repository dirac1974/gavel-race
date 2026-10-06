--!strict
-- D-057 N4: the boxed-in arrows (SteerHud), the chips' rate limit (SteerChips), and what reaches
-- the rider (Trip.riderLane over SteerLane): grey arrows, the wait ring, the wobble, "No room yet"
-- and "Gap!", never for spectators or a rider's first races.
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local SteerHud = require("../../game/src/shared/SteerHud")
local SteerChips = require("../../game/src/shared/SteerChips")

local STEER, SHUD = GameConfig.steering, GameConfig.steerHud
local DT = 1 / GameConfig.steering.tickHz

local function lane(inSide: string, outSide: string, wait: number?, waitAt: number?, tucking: boolean?, tgt: number?): any
	return { tgt = tgt or 3, dest = tgt or 3, ack = 0, wait = wait or 0, waitAt = waitAt or 0, tucking = tucking == true,
		inSide = inSide, outSide = outSide }
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	check(SHUD.greyArrows == true and SHUD.waitRing == true and SHUD.noRoomChipAfter == 1 and SHUD.noRoomChipEvery == 10
		and SHUD.gapChipAfterWait == 0.5 and SHUD.chipMinGap == 2 and SHUD.wobbleDeg == 4 and SHUD.wobbleSeconds == 0.2,
		"GameConfig.steerHud holds D-057's boxed-in values")

	-- The arrow states ---------------------------------------------------------------------------
	local h = SteerHud.new()
	local function arrows(l: any, now: number?, shown: boolean?): (any, any)
		local a, b = SteerHud.arrows(h, l, now or 10, STEER, SHUD, if shown == nil then true else shown)
		return { grey = a.grey, ring = a.ring }, { grey = b.grey, ring = b.ring }
	end
	local i1, o1 = arrows(lane("free", "free"))
	check(not i1.grey and not o1.grey and i1.ring == -1 and o1.ring == -1, "room both sides: both arrows normal, no ring")
	local _, o2 = arrows(lane("free", "blocked"))
	check(o2.grey, "a horse leaves no room outside: Out ▶ greys")
	local i3 = arrows(lane("tuck", "free"))
	check(not i3.grey, "no room inside but tuck-back finds a slot: ◀ In stays normal (it still works at once)")
	local i4 = arrows(lane("blocked", "free"))
	check(i4.grey, "no room inside and no tuck slot (trapped): ◀ In greys")
	local i5, o5 = arrows(lane("edge", "edge"))
	check(not i5.grey and not o5.grey, "at the rail or the outside nothing greys: no horse is there")
	local i6 = arrows(lane("free", "free", -1, 8))
	check(i6.ring == 1, "an inward press waiting for room: its ring is lit (it waits until room)")
	local _, o7 = arrows(lane("free", "blocked", 1, 9.25), 10)
	check(close(o7.ring, 0.75 / STEER.gapWaitSeconds, 1e-12), "an outward press waiting: its ring fills over gapWaitSeconds")
	local _, o8 = arrows(lane("free", "blocked", 1, 5), 10)
	check(o8.ring == 1, "...and stops full")
	local i9, o9 = arrows(lane("blocked", "blocked", -1, 8), 10, false)
	check(not i9.grey and not o9.grey and i9.ring == -1 and o9.ring == -1,
		"shown = false (a spectator, or a rider's first races): no grey arrow, no ring")
	local i10, o10 = arrows(nil)
	check(not i10.grey and not o10.grey, "before the server has said anything: normal arrows")
	local off = table.clone(SHUD)
	off.greyArrows, off.waitRing = false, false
	local a11, b11 = SteerHud.arrows(SteerHud.new(), lane("blocked", "blocked", 1, 9), 10, STEER, off, true)
	check(not a11.grey and not b11.grey and b11.ring == -1, "greyArrows = false, waitRing = false: the switch-back to plain arrows")

	-- ◀ In never greys while tuck-back can help, over whole fields of pressing horses ---------------
	local track = TrackLayout.courses.dirt
	local plan = TrackLayout.plan(track, TrackLayout.distances.Mile)
	local geo = TrackLayout.phaseA(track, plan)
	local race = Trip.raceParams(GameConfig)
	local seed = 7
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local hud, info = SteerHud.new(), {}
	local wrongIn, wrongOut, greyIns, tucks, greyOuts, rings, edges = 0, 0, 0, 0, 0, 0, 0
	for _ = 1, 6 do
		local posts = { 1, 2, 3, 4, 5, 6, 7, 8 }
		local kinds = { "manual", "manual", "smart", "bot", "manual", "bot", "manual", "smart" }
		local st = Trip.new(posts, table.create(8, 1 / 8), table.create(16, 0.5), geo, STEER, kinds, race)
		local lockT = Trip.lockTime(geo, race)
		local k = 0
		while k * DT < lockT - 1e-9 do
			local intents = {}
			for _, i in { 1, 2, 5, 7 } do
				if rnd() < 0.15 then table.insert(intents, { i, if rnd() < 0.6 then -1 else 1 }) end
			end
			Trip.step(st, table.create(8, 1 / 8), intents, k * DT, DT)
			for i = 1, 8 do
				Trip.riderLane(st, i, info)
				local inA, outA = SteerHud.arrows(hud, info, k * DT, STEER, SHUD, true)
				local inside = Trip.sideState(st, i, -1)
				if inA.grey then
					greyIns += 1
					if not Trip.noTuckInside(st, i) or inside == "tuck" then wrongIn += 1 end
				end
				if inside == "tuck" then
					tucks += 1
					if inA.grey then wrongIn += 1 end
				end
				if outA.grey then greyOuts += 1 end
				if outA.grey ~= (info.outSide == "blocked") or (info.outSide == "edge" and outA.grey) then wrongOut += 1 end
				if info.inSide == "edge" or info.outSide == "edge" then edges += 1 end
				if inA.ring >= 0 or outA.ring >= 0 then rings += 1 end
			end
			k += 1
		end
	end
	check(wrongIn == 0 and greyIns > 0 and tucks > 0,
		`◀ In greys only when trapped (Trip.noTuckInside), never while tuck-back can help: {greyIns} grey, {tucks} tuck-back states, {wrongIn} wrong`)
	check(wrongOut == 0 and greyOuts > 0 and edges > 0 and rings > 0,
		`Out ▶ greys exactly while a horse leaves no room outside (never at the edge): {greyOuts} grey, {rings} rings, {wrongOut} wrong`)

	-- Messages: the wobble and "Gap!" -------------------------------------------------------------
	local m = SteerHud.new()
	SteerHud.message(m, lane("free", "blocked", 1, 20), 20.1, STEER, SHUD)
	local w1, g1 = SteerHud.message(m, lane("free", "blocked", 0, 0), 20 + STEER.gapWaitSeconds + 0.1, STEER, SHUD, 1, 20)
	check(w1 == 1 and not g1, "an outward press that waited gapWaitSeconds and dropped: Out ▶ wobbles")
	local c = SteerHud.new()
	SteerHud.message(c, lane("free", "blocked", 1, 20), 20.1, STEER, SHUD)
	local w2 = SteerHud.message(c, lane("free", "blocked", 0, 0), 20.5, STEER, SHUD, -1, 20.4)
	check(w2 == 0, "a wait you cancel by pressing the other way doesn't wobble")
	local c2 = SteerHud.new()
	SteerHud.message(c2, lane("free", "blocked", 1, 20), 20.1, STEER, SHUD)
	local w3 = SteerHud.message(c2, lane("free", "blocked", 0, 0), 21.45, STEER, SHUD, -1, 21.4)
	check(w3 == 0, "...even near the end of its wait")
	local gq = SteerHud.new()
	SteerHud.message(gq, lane("blocked", "free", -1, 30, false, 4), 30.1, STEER, SHUD)
	local w4, g4 = SteerHud.message(gq, lane("free", "free", 0, 0, false, 3), 30.8, STEER, SHUD)
	check(w4 == 0 and g4, "a wait of at least gapChipAfterWait that ends in the move: \"Gap!\"")
	local gs = SteerHud.new()
	SteerHud.message(gs, lane("blocked", "free", -1, 30, false, 4), 30.1, STEER, SHUD)
	local _, g5 = SteerHud.message(gs, lane("free", "free", 0, 0, false, 3), 30.3, STEER, SHUD)
	check(not g5, "...not after a short one")
	local wi = SteerHud.new()
	SteerHud.message(wi, lane("blocked", "free", -1, 30), 30.1, STEER, SHUD)
	local w6 = SteerHud.message(wi, lane("blocked", "free", 0, 0), 60, STEER, SHUD)
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
	local crowd = SteerChips.new()
	SteerChips.shown(crowd, 80.5)
	check(not SteerChips.noRoom(crowd, lane("free", "blocked", 1, 79), 81, SHUD)
		and SteerChips.noRoom(crowd, lane("free", "blocked", 1, 79), 82.6, SHUD),
		"never within chipMinGap of another steering chip (good news always shows first)")
	check(not SteerChips.noRoom(SteerChips.new(), nil, 99, SHUD) and not SteerChips.noRoom(SteerChips.new(), lane("free", "free"), 99, SHUD),
		"nothing to say with no wait")

	-- What reaches the rider, and who sees it ----------------------------------------------------
	local st = Trip.new({ 1, 2 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, geo, STEER, { "manual", "manual" }, race)
	local out = Trip.riderLane(st, 1, {})
	check(out.inSide == "edge" and out.wait == 0 and out.waitAt == 0 and out.tucking == false and out.tgt == 1 and out.dest == 1,
		"Trip.riderLane: on the rail the inside is the edge; nothing waiting, no tuck-back")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	check(string.find(rs, "for p in steers do", 1, true) ~= nil and string.find(rs, "Trip.riderLane(trip, i, scratchOwn)", 1, true) ~= nil
		and string.find(rs, "own.outSide, c.id)", 1, true) ~= nil,
		"RaceService sends SteerLane (course id last) only to riders with the buttons: spectators and first races hear nothing")
	check(string.find(rc, "or s.race ~= cueRace or not s.shown or s.locked then return end", 1, true) ~= nil
		and string.find(rc, "SteerHud.arrows(s.hud, s.lane, raceNow, STEER, SHUD, s.shown)", 1, true) ~= nil,
		"RaceController paints the boxed-in arrows only for a rider with the buttons, up to the lock")
	check(string.find(rv, "OnClientEvent:Connect(function(tgt, dest, ack, _wait, _waitAt, _tucking, _inSide, _outSide, courseId)", 1, true) ~= nil,
		"RaceView reads SteerLane's course id where it now sits (last)")
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
	check(string.find(grownUps, "Horses can get boxed in, like in real racing. They wait for a gap or ease back to find one. Being boxed in never costs points.", 1, true) ~= nil,
		"the grown-ups page says boxed in never costs points")
end
