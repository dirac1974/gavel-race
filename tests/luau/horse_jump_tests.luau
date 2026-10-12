--!strict
-- D-074 (race realism): the forward hop (HorseJump), its airborne pose (HorseLegs.AIR_POSE), the
-- derived TC.RIDE_HOP, Mud Splash logs still clearing, the training speed check never firing on a
-- hop, and steer keys in a race saddle (RaceInput.saddleKey) never reaching the camera.
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local HorseJump = require("../../game/src/shared/HorseJump")
local HorseLegs = require("../../game/src/shared/HorseLegs")
local TC = require("../../game/src/shared/TrainingCourses")
local TR = require("../../game/src/shared/TrainingRide")
local RaceInput = require("../../game/src/shared/RaceInput")

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local H = GameConfig.riding.hop
	local TCfg = GameConfig.training
	local g = HorseJump.GRAVITY

	-- Config ------------------------------------------------------------------------------------
	check(H.landSquash == 0.96 and H.remoteAirVy > 0 and H.jumpPower == 38 and H.forwardMin == 14 and H.forwardBoost == 4 and H.forwardCap == TCfg.maxSpeed - 2
		and H.forwardCap == 51 and H.cooldownSeconds == 0.6 and H.tuckLegs == true,
		"riding.hop: jumpPower 38, forward 14 min, +4, cap 51 (training maxSpeed - 2), 0.6 s cooldown, folded legs")
	check(close(TC.RIDE_HOP, H.jumpPower ^ 2 / (2 * g), 1e-9) and close(TC.RIDE_HOP, 3.68, 0.01),
		"TC.RIDE_HOP is derived from riding.hop.jumpPower (3.68)")
	check(close(HorseJump.peak(H.jumpPower), TC.RIDE_HOP, 1e-9) and close(HorseJump.airtime(H.jumpPower), 0.387, 0.002),
		"peak 3.68 studs, airtime 0.39 s")

	-- Launch speed -----------------------------------------------------------------------------
	local ls = HorseJump.launchSpeed
	check(ls(0) == 14 and ls(-10) == 14 and ls(1) == 14, "a standing (or backing) horse hops forward at 14")
	check(ls(16) == 20 and ls(20) == 24 and ls(28) == 32 and ls(46) == 50, "a moving horse gets +4")
	check(ls(47) == 51 and ls(60) == 51, "never over the 51 cap")
	check(ls(28, nil, 28) == 28 and ls(46, nil, 46) == 46 and ls(10, nil, 20) == 14 and ls(0, nil, 0) == 0,
		"on a course never over its pace; a stopped course (the Gate Break stall) hops straight up")
	local vx, vz, sp = HorseJump.launch(3, 5, 0, -2)
	check(close(vx, 0, 1e-9) and close(vz, -14, 1e-9) and sp == 14, "launch goes along the flat facing, sideways drift dropped")
	local vx2, vz2, sp2 = HorseJump.launch(30, 40, 0.6, 0.8)
	check(sp2 == 51 and close(vx2, 0.6 * 51, 1e-9) and close(vz2, 0.8 * 51, 1e-9),
		"a fast diagonal launch is capped along the facing")
	local vx3, vz3, sp3 = HorseJump.launch(4, 5, 0, 0)
	check(vx3 == 4 and vz3 == 5 and sp3 == 0, "no flat facing: no push")

	-- Arc ----------------------------------------------------------------------------------------
	check(close(HorseJump.reach(ls(0), H.jumpPower), 5.4, 0.15), "from a standstill the arc is about 5.5 studs")
	check(close(HorseJump.reach(ls(46), H.jumpPower), 19.4, 0.2), "at a gallop the arc is about 19.5 studs")
	local above = HorseJump.timeAbove(H.jumpPower, TCfg.grit.airborne)
	check(close(above, 0.298, 0.003) and above * TCfg.grit.pace > 2 * TCfg.grit.logWindow,
		"above 1.5 studs for 0.30 s: 8.3 studs at the lope, wider than the 6-stud log window")

	-- Mud Splash (spec: 4 to 1 studs before a log): a hop at the lope clears the log under the sample
	-- rule of TrainingRide.cleared (a 10 Hz sample within logWindow of the log at y >= 1.5) at every
	-- sample phase from 4 to 1.1 studs before. At exactly 1.0 studs before, about 2% of sample phases
	-- miss: the 10 Hz sampling, not the arc (the horse is above 1.5 there). Reported, not hidden.
	local pace = HorseJump.launchSpeed(TCfg.grit.pace, nil, TCfg.grit.pace)
	local function missShare(before: number): number
		local miss = 0
		for ph = 0, 99 do
			local hit = false
			local t = ph / 1000
			while t <= HorseJump.airtime(H.jumpPower) do
				local x = pace * t - before
				local y = H.jumpPower * t - g / 2 * t * t
				if math.abs(x) <= TCfg.grit.logWindow and y >= TCfg.grit.airborne then hit = true end
				t += 1 / TCfg.sampleHz
			end
			if not hit then miss += 1 end
		end
		return miss / 100
	end
	local allClear, worst = true, ""
	for before10 = 11, 40 do
		if missShare(before10 / 10) > 0 then
			allClear = false
			worst = ` (misses at {before10 / 10} studs before)`
		end
	end
	check(allClear, "Mud Splash: a hop 4 to 1.1 studs before a log clears it at every sample phase" .. worst)
	local atOne = missShare(1.0)
	check(atOne > 0 and atOne <= 0.03, `Mud Splash: at exactly 1.0 stud before, {atOne * 100}% of 10 Hz sample phases miss (sampling, known)`)
	print(`NOTE (D-074): a hop exactly 1.0 stud before a Mud Splash log misses {atOne * 100}% of 10 Hz sample phases; 100% from 1.1 to 4 studs`)

	-- Gate Break (review B1): a hop in the stall, before the bell or answering it, settling or stopped
	-- on the way back, has no forward push, so it can never move goStuds and count as a go.
	local AC = TCfg.accel
	local stallOk = true
	for _, gate in { "countdown", "settle", "ready", "bell", "back" } do
		local cap = math.min(TCfg.gallop, TC.hopCap(gate, true) or math.huge) -- a released stick: WalkSpeed is the gallop
		local fwd = HorseJump.reach(HorseJump.launchSpeed(0, nil, cap), H.jumpPower)
		if cap ~= 0 or fwd ~= 0 or fwd >= AC.goStuds then stallOk = false end
	end
	check(stallOk and TC.hopCap("ready", false) == 0 and TC.hopCap("bell", false) == 0,
		"Gate Break: a hop in the stall (or waiting for the bell) goes straight up, 0 studs forward, never past goStuds")
	check(TC.hopCap("dash", true) == nil and TC.hopCap("back", false) == nil and TC.hopCap(nil, false) == nil,
		"Gate Break: the dash and the loop back hop forward as usual")
	local trc = fs.readFile("game/src/client/TrainingRideClient.client.luau")
	local rdc = fs.readFile("game/src/client/RideClient.client.luau")
	check(string.find(trc, "TrainingState.hopCap = TC.hopCap(s.gate", 1, true) ~= nil
		and string.find(trc, "TrainingState.hopCap or math.huge", 1, true) ~= nil
		and string.find(rdc, "TrainingState.hopCap or math.huge", 1, true) ~= nil,
		"both hop sites take the course's hop cap (gateFrame sets it every frame)")

	-- The training speed check never fires on a hop at the cap (51 studs/s through the whole arc).
	local sc = TR.screener(nil)
	local fired = false
	local x0 = 0
	for i = 0, 30 do
		local t = i / TCfg.sampleHz
		local inHop = t < 0.4
		local y = if inHop then math.max(0, H.jumpPower * t - g / 2 * t * t) else 0
		x0 = H.forwardCap * t
		local kind = TR.screen(sc, { t = t, x = x0, y = y, z = 0 }, TCfg)
		if kind == "bad" then fired = true end
	end
	check(not fired and H.forwardCap < TCfg.maxSpeed, "a hop at 51 studs/s never trips the training speed or teleport check")

	-- Airborne pose ------------------------------------------------------------------------------
	local p = HorseJump.newPose()
	for _ = 1, 3 do HorseJump.poseStep(p, true, 10, 0.01) end
	HorseJump.poseStep(p, false, 0, 0.01)
	check(p.tuck == 0 and math.abs(p.pitch) < math.rad(1) and p.dip == 0, "a 0.03 s bump never folds the legs, dips, or tips the nose more than 1°")
	p = HorseJump.newPose()
	local maxUp, maxDown = 0, 0
	local t = 0
	while t < HorseJump.airtime(H.jumpPower) do
		HorseJump.poseStep(p, true, H.jumpPower - g * t, 1 / 60)
		maxUp, maxDown = math.max(maxUp, p.pitch), math.min(maxDown, p.pitch)
		t += 1 / 60
	end
	check(p.tuck == 1, "the legs are folded in the air")
	check(maxUp > math.rad(3) and maxUp <= math.rad(H.pitchUpDeg) + 1e-9 and maxDown < -math.rad(2) and maxDown >= -math.rad(H.pitchDownDeg) - 1e-9,
		"nose up (at most 6°) on the way up, nose down (at most 4°) on the way down")
	local landed = HorseJump.poseStep(p, false, 0, 1 / 60)
	check(landed and close(p.dip, (1 - H.landSquash) * H.squashHeight, 1e-9) and H.landSquash == 0.96 and p.tuck < 1,
		"touchdown: the thud and dust signal, a 0.96 squash, the legs unfolding")
	check(not HorseJump.poseStep(p, false, 0, 1 / 60), "the thud plays once a landing")
	for _ = 1, 30 do HorseJump.poseStep(p, false, 0, 1 / 60) end
	check(p.dip == 0 and p.tuck == 0 and math.abs(p.pitch) < 1e-3, "back to the gallop after landing")
	local still = HorseJump.newPose()
	for _ = 1, 20 do HorseJump.poseStep(still, true, 20, 1 / 60, true) end
	local stillLanded = HorseJump.poseStep(still, false, 0, 1 / 60, true)
	check(still.pitch == 0 and still.dip == 0 and still.tuck > 0 and stillLanded,
		"Reduced Motion: no pitch, no squash; the folded legs and the thud stay")
	check(HorseJump.remoteAirborne(true, 0) and HorseJump.remoteAirborne(false, 20) and HorseJump.remoteAirborne(false, -20)
		and not HorseJump.remoteAirborne(false, 3),
		"another player's horse: airborne from its state, or past remoteAirVy when the state lags")
	check(string.find(rdc, "HorseJump.remoteAirborne(", 1, true) ~= nil and string.find(rdc, "hh.WalkSpeed = flightSpeed", 1, true) ~= nil
		and string.find(rdc, "if flight then flightSpeed elseif galloping", 1, true) ~= nil,
		"RideClient: remote fallback; WalkSpeed is the hop's own speed in flight (air control agrees with the push)")
	local s = HorseLegs.newState()
	s.gait, s.blend, s.phase = "gallop", 1, 0.3
	s.tuck = 1
	local folded = true
	for _, leg in HorseLegs.LEGS do
		if not close(HorseLegs.poseAngle(s, leg), HorseLegs.AIR_POSE[leg], 1e-9) then folded = false end
	end
	s.tuck = 0
	check(folded and HorseLegs.AIR_POSE.LegFL > 0 and HorseLegs.AIR_POSE.LegBL < 0
		and close(HorseLegs.poseAngle(s, "LegFL"), HorseLegs.angle("gallop", "LegFL", 0.3), 1e-9),
		"HorseLegs: tuck 1 is the air pose (forelegs forward, hind legs back); tuck 0 the gallop")

	-- Both ride clients hop through HorseJump (never the bare Humanoid.Jump).
	local ride = fs.readFile("game/src/client/RideClient.client.luau")
	local train = fs.readFile("game/src/client/TrainingRideClient.client.luau")
	check(string.find(ride, "HorseJump.hop(", 1, true) ~= nil and string.find(train, "HorseJump.hop(", 1, true) ~= nil
		and string.find(ride, "hh.Jump = true", 1, true) == nil and string.find(train, "hh.Jump = true", 1, true) == nil,
		"RideClient and TrainingRideClient hop through HorseJump")
	check(string.find(fs.readFile("game/src/server/Rides.luau"), "JumpPower = GameConfig.riding.hop.jumpPower", 1, true) ~= nil,
		"Rides reads JumpPower from riding.hop")

	-- Steer keys in a race saddle ----------------------------------------------------------------
	local sk = RaceInput.saddleKey
	check(sk(true, true, false, false, false) == "steer" and sk(true, true, false, true, false) == "steer", "with the buttons, before the lock: steer")
	check(sk(true, false, false, false, true) == "hint" and sk(true, false, false, true, true) == "sink",
		"Smart Steer (no buttons): the chip once a race, then nothing")
	check(sk(true, false, false, false, false) == "sink", "no steering in this race (off, or fixed lanes): silent")
	check(sk(true, true, true, false, false) == "sink" and sk(true, false, true, false, true) == "sink" and sk(false, true, false, false, true) == "sink",
		"after the lock or outside the race: sunk, nothing sent")
	local ss = RaceInput.smartSteering
	check(ss(true, false, true) and not ss(false, false, true) and not ss(true, true, true) and not ss(true, false, false),
		"Smart Steer only when the race sent controls that hide the buttons with Smart Steer on")
	local words = 0
	for _ in string.gmatch(RaceInput.SMART_HINT, "%S+") do words += 1 end
	check(words <= 6, "the Smart Steer chip is at most 6 words")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	check(string.find(rc, "saddleKeys.on = not enabled", 1, true) ~= nil and string.find(rc, "saddleKeys.wanted or saddleKeys.on", 1, true) ~= nil
		and string.find(rc, "RaceInput.saddleKey(", 1, true) ~= nil
		and string.find(rc, "RaceInput.smartSteering(s.controls == true", 1, true) ~= nil
		and string.find(rc, "GuiService.SelectedObject = if Card.againBtn.Visible then Card.againBtn else Card.doneBtn", 1, true) ~= nil
		and select(2, string.gsub(rc, "GuiService.SelectedObject = nil", "")) >= 2 and string.find(rc, "Enum.ContextActionPriority.High.Value + 1", 1, true) ~= nil,
		"RaceController binds and sinks the steer keys at High+1 for the whole saddle span")
end
