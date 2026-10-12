--!strict
-- Race feel (D-066, AAA Phase 1): RaceFx's caps, the leg-driven bob (HorseLegs.bob, phaseOf), the
-- config budget, and that the effects stay drawn-only (no score, order or trip module reads them).
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local RaceFx = require("../../game/src/shared/RaceFx")
local HorseLegs = require("../../game/src/shared/HorseLegs")

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local FX = GameConfig.raceFx
	check(GameConfig.tapNudgeFeet == 5, "the tap nudge is 5 ft (D-066)")

	-- Camera budget: one Perfect kick at most 1.5 degrees, at most once every 0.8 s; the burst's
	-- kick is the big one; every kick together stays at or under +6 degrees.
	check(FX.perfectFovDeg <= 1.5 and FX.perfectFovEverySeconds >= 0.8, "Perfect kick: <= 1.5 deg, <= once per 0.8 s")
	check(FX.burstFovDeg > FX.perfectFovDeg and FX.fovMaxDeg <= 6, "the burst has the bigger kick; total <= 6 deg")
	check(not RaceFx.canKickPerfect(10, 10.5, FX) and RaceFx.canKickPerfect(10, 10.8, FX), "Perfect kicks are rate-limited")
	local kicks = {}
	local worst, t = 0, 0
	for k = 0, 40 do -- a Perfect every 0.8 s plus three burst kicks in a row: still capped
		if k % 8 == 0 then table.insert(kicks, { at = t, deg = FX.perfectFovDeg, fall = FX.fovFallSeconds }) end
		if k == 20 or k == 21 or k == 22 then table.insert(kicks, { at = t, deg = FX.burstFovDeg, fall = 2 * FX.fovFallSeconds }) end
		for _ = 1, 6 do
			t += 1 / 60
			worst = math.max(worst, RaceFx.fov(kicks, t, FX))
		end
	end
	check(worst <= FX.fovMaxDeg + 1e-9 and worst > FX.perfectFovDeg, "stacked kicks never pass fovMaxDeg")
	check(RaceFx.fov(kicks, t + 10, FX) == 0 and #kicks == 0, "finished kicks end exactly at 0 and are dropped")
	check(close(RaceFx.kickAt(FX.fovRiseSeconds, 1.5, 0.3, FX), 1.5, 1e-9) and RaceFx.kickAt(-0.1, 1.5, 0.3, FX) == 0,
		"a kick rises to its size, nothing before it starts")

	-- The tap tick: one clear step up per label, 0.9 to 1.3; louder than the ducked hoofbeats.
	local lastSpeed = 0
	for _, row in { "Miss", "Okay", "Good", "Great", "Perfect" } do
		local v = RaceFx.tickSpeed(row, FX)
		check(v > lastSpeed, `tick pitch steps up at {row}`)
		lastSpeed = v
	end
	check(close(RaceFx.tickSpeed("Miss", FX), 0.9, 1e-9) and close(RaceFx.tickSpeed("Perfect", FX), 1.3, 1e-9)
		and RaceFx.tickSpeed("Early", FX) == RaceFx.tickSpeed("Miss", FX), "tick pitch from 0.9 to 1.3")
	check(0.25 * FX.tickVolume > 0.45 * FX.gallopDuck, "the tick (tap_ok 0.25 x tickVolume) sits over the ducked hoofbeats")
	check(close(0.25 * FX.tickVolume, 0.4, 0.02) and close(0.45 * FX.gallopDuck, 0.3, 0.02), "about 0.4 over 0.3")
	-- Every 3rd Great-or-better in a row surges.
	check(not RaceFx.streakSurges(2, FX) and RaceFx.streakSurges(3, FX) and not RaceFx.streakSurges(4, FX)
		and RaceFx.streakSurges(6, FX) and not RaceFx.streakSurges(3, { surgeOnGreatStreak = 0 }), "a surge every 3 Greats in a row")

	-- The nudge: never faster than a gap may move (D-055), never into the horse ahead in your lane.
	check(FX.nudgeFeetPerSecond <= GameConfig.raceView.maxGapFeetPerSecond, "the nudge moves no faster than a gap")
	check(FX.nudgeClearFeet >= GameConfig.steering.holdGap, "the nudge keeps a held horse's room")
	local drawn, fastest, dt = 0, 0, 1 / 60
	for f = 1, 120 do
		local nextFeet = RaceFx.stepNudge(drawn, if f < 30 then GameConfig.tapNudgeFeet else 0, math.huge, dt, FX)
		fastest = math.max(fastest, math.abs(nextFeet - drawn) / dt)
		drawn = nextFeet
	end
	check(fastest <= FX.nudgeFeetPerSecond + 1e-9 and drawn == 0, "the nudge eases in and out at the capped rate")
	local ahead = { 0, 14, 40, 3 }
	local lanes = { 2, 2.3, 2, 5 }
	check(close(RaceFx.nudgeRoom(1, ahead, lanes, GameConfig.steering.laneBand, 10), 4, 1e-9), "room: 14 ft ahead in lane, 10 clear")
	check(RaceFx.nudgeRoom(4, ahead, lanes, GameConfig.steering.laneBand, 10) == math.huge, "room: nobody ahead in your lane")
	check(close(RaceFx.stepNudge(2, 5, 1.5, dt, FX), 2 - FX.nudgeFeetPerSecond * dt, 1e-9),
		"a horse cutting in eases the nudge back (no snap)")
	check(close(RaceFx.stepNudge(4, 5, 1.5, dt, FX), 1.5 + FX.nudgeSlackFeet, 1e-9),
		"...but never leaves it more than nudgeSlackFeet past the room")
	check(FX.nudgeClearFeet - FX.nudgeSlackFeet >= 8, "even at the slack, a horse length (8 ft) stays between them")
	local eased, worstPast = 3, 0
	for _ = 1, 60 do
		eased = RaceFx.stepNudge(eased, 5, 2.5, dt, FX)
		worstPast = math.max(worstPast, eased - 2.5)
	end
	check(close(eased, 2.5, 1e-9) and worstPast <= FX.nudgeSlackFeet, "the nudge settles at the room")
	check(RaceFx.stepNudge(0, 5, 0, dt, FX) == 0, "no room: no nudge")
	check(RaceFx.surge(-0.01, FX) == 0 and RaceFx.surge(FX.surgeSeconds, FX) == 0
		and close(RaceFx.surge(FX.surgeSeconds / 2, FX), 1, 1e-9), "the surge is a short up-and-back")

	-- Bob from the legs (D-066): lowest at the plant, one rise a gallop stride, cadence unchanged.
	for gait, b in HorseLegs.BOB do
		local lift, nose = HorseLegs.bob(gait, b.plant)
		check(close(lift, 0, 1e-12) and close(nose, -1, 1e-12), gait .. ": lowest and nose down at the plant")
		local midLift = HorseLegs.bob(gait, b.plant + 0.5 / b.bobs)
		check(close(midLift, 1, 1e-12), gait .. ": highest halfway between plants")
	end
	check(HorseLegs.bob("stand", 0.3) == 0, "a standing horse doesn't bob")
	-- A change of gait cross-fades the bob with the legs (no jump out of the gate or pulling up).
	local cs = HorseLegs.newState()
	local jump, lastLift = 0, nil
	for f = 1, 240 do
		local v = if f <= 60 then 20 else 56 -- trot, then gallop
		HorseLegs.step(cs, v / 60, 1 / 60, v)
		local lift = HorseLegs.bodyBob(cs)
		if lastLift and f > 30 then jump = math.max(jump, math.abs(lift - lastLift)) end
		lastLift = lift
	end
	check(jump < 0.35, `the bob never jumps at a gait change (largest frame step {jump})`)
	check(HorseLegs.bodyBob(HorseLegs.newState()) == 0, "a fresh (standing) horse has no bob")
	local plants, phase = 0, 0.0
	local s = HorseLegs.newState()
	for _ = 1, 600 do -- 10 s at race pace, 60 fps
		local before = s.phase
		HorseLegs.step(s, 56 / 60, 1 / 60, 56)
		phase = s.phase
		if HorseLegs.crossedPlant("gallop", before, phase) then plants += 1 end
	end
	local strides = 560 / HorseLegs.GAITS.gallop.stride
	check(math.abs(plants - strides) <= 1, `one dust puff a gallop stride ({plants} vs {strides})`)
	check(HorseLegs.GAITS.gallop.stride == 18, "leg cadence unchanged (a gallop stride is still 18 studs)")
	check(not HorseLegs.crossedPlant("gallop", 0.5, 0.6) and HorseLegs.crossedPlant("gallop", 0.6, 0.7),
		"crossing the gallop plant (0.66) is seen once")

	-- Drawn only: no scoring, order or trip module reads the race-feel config or RaceFx.
	for _, name in { "RaceSession", "Trip", "RaceShape", "PaceMeter", "Playback" } do
		local src = fs.readFile("game/src/shared/" .. name .. ".luau")
		check(string.find(src, "raceFx", 1, true) == nil and string.find(src, "RaceFx", 1, true) == nil
			and string.find(src, "tapNudge", 1, true) == nil, name .. " never reads the race-feel effects")
	end
	local server = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(server, "raceFx", 1, true) == nil and string.find(server, "RaceFx", 1, true) == nil,
		"the server never reads the race-feel effects")

	-- B1: the effect attachments are parented before they are placed (an unparented Attachment's
	-- world position is its local one, which would put the dust far from the hooves).
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	local parentAt = string.find(rv, "a.Parent = body", 1, true)
	local placeAt = string.find(rv, "a.CFrame = body.CFrame:ToObjectSpace(box * CFrame.new(offset))", 1, true)
	check(parentAt ~= nil and placeAt ~= nil and parentAt < placeAt, "dust and trail attachments: parent first, then place")
	check(string.find(rv, "WorldPosition", 1, true) == nil, "no attachment is placed by WorldPosition")

	-- Hoofbeats at the legs' cadence; the burst's wait hint is short and kind.
	check(close(GameConfig.raceSpeedStudsPerSecond / HorseLegs.GAITS.gallop.stride / FX.gallopLoopStridesPerSecond, 1.5556, 1e-3),
		"gallop_loop plays about 1.55x (3.1 strides a second over a 2-stride loop)")
	local Words = require("../../game/src/shared/Words")
	local wait = GameConfig.hud.burstEarlyHint
	check(type(wait) == "string" and Words.count(wait) <= 10 and Words.banned(wait) == nil, "the burst wait hint: <= 10 words")
	check(FX.perfectChimeVolume > 0 and FX.perfectChimeVolume < 1, "a Perfect chimes, a little under full")

	-- The tap tick call matches Sound.play(name, volume?, at?, speed?).
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	check(string.find(rc, 'pcall(Sound.play, "tap_ok", FX.tickVolume, nil, RaceFx.tickSpeed(GameConfig.labelFor(score), FX))', 1, true) ~= nil,
		"every counted tap ticks, pitched by its score")
	check(string.find(rc, 'Sound.loop("gallop_loop", volume, rate)', 1, true) ~= nil
		and string.find(rc, 'pcall(Sound.play, "tap_good", FX.perfectChimeVolume)', 1, true) ~= nil,
		"hoofbeats at the legs' rate; a Perfect chimes over the tick")
end
