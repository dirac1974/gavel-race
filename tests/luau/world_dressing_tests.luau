--!strict
-- AAA Phase 4, Dev A (D-069): world and jockey. The jockey pose stays bounded (back under 45 degrees,
-- arms forward, never raised, both sides the same, pump on the stride's landing); the track dressing
-- stays inside its budget and its config switches work; the Big Board shows only places, lanes and
-- names; the crowd and flags are still under Reduced Motion; and none of it is read by the race.
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local HorseLegs = require("../../game/src/shared/HorseLegs")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local TrackLifeView = require("../../game/src/shared/TrackLifeView")
local JockeyPose = require("../../game/src/client/JockeyPose")
local TrackDressing = require("../../game/src/server/TrackDressing")

local BANNED = { "bet", "bets", "betting", "wager", "odds", "stake", "stakes", "payout", "bookie", "house", "purse",
	"prize", "chance", "win %", "%" }

local function clean(s: string): boolean
	local lower = string.lower(s)
	for _, w in BANNED do
		if w == "%" or w == "win %" then
			if string.find(lower, w, 1, true) then return false end
		elseif string.find(" " .. lower .. " ", "[^%a]" .. w .. "[^%a]") then
			return false
		end
	end
	return true
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- Config: the plan's numbers, every item behind a switch.
	local J = GameConfig.jockeyPose
	check(J.enabled == true and J.waistDeg == 35 and J.hipDeg == -70 and J.kneeDeg == 100 and J.shoulderDeg == 55
		and J.elbowDeg == 70 and J.neckDeg == -15 and J.pumpDeg == 4 and J.riseStuds == 0.12, "jockeyPose has the plan's angles")
	local D = GameConfig.trackDressing
	check(D.enabled == true and D.bunting == true and D.flags == true and D.crowd == true, "trackDressing switches on")
	check(D.maxParts <= 350 and D.maxBeams <= 80, "trackDressing budget: <= 350 parts, <= 80 Beams")
	local L = GameConfig.trackLife
	check(L.enabled == true and close(L.calmStuds, 0.12, 1e-9) and close(L.calmHz, 1.5, 1e-9)
		and close(L.cheerStuds, 0.3, 1e-9) and close(L.cheerHz, 3, 1e-9) and L.flutterDeg == 6, "trackLife has the plan's bounce and flutter")
	check(GameConfig.bigBoard.live == true and GameConfig.bigBoard.rows == 4, "bigBoard.live, top 4")
	check(GameConfig.friendRace.badge == true, "friendRace.badge")

	-- JockeyPose: the crouch over a whole gallop stride, and at rest.
	local pose = JockeyPose.newPose()
	local worstBack, minBack = 0, 90
	local maxUpper, maxFore, minUpper = -math.huge, -math.huge, math.huge
	local maxRise, minRise = -math.huge, math.huge
	local base = JockeyPose.solve(J, 0, 0, JockeyPose.newPose())
	local maxPump, maxShoulderPump = 0, 0
	local plantWaist, plantPhase = math.huge, -1
	for k = 0, 99 do
		local phase = k / 100
		local lift, nose = HorseLegs.bob("gallop", phase)
		JockeyPose.solve(J, lift, nose, pose)
		local back = JockeyPose.backDeg(pose)
		worstBack, minBack = math.max(worstBack, back), math.min(minBack, back)
		local upper, fore = JockeyPose.armDeg(pose)
		maxUpper, minUpper, maxFore = math.max(maxUpper, upper), math.min(minUpper, upper), math.max(maxFore, fore)
		maxRise, minRise = math.max(maxRise, pose.rise), math.min(minRise, pose.rise)
		maxPump = math.max(maxPump, math.abs(pose.waist - base.waist))
		maxShoulderPump = math.max(maxShoulderPump, math.abs(pose.shoulder - base.shoulder))
		if pose.waist < plantWaist then plantWaist, plantPhase = pose.waist, phase end
	end
	check(worstBack < 45 and minBack > 20, `the back stays under 45 degrees from horizontal ({minBack}..{worstBack})`)
	check(minUpper >= -10 and maxUpper <= 45, `upper arms forward and down ({minUpper}..{maxUpper})`)
	check(maxFore <= 110, `forearms reach forward along the neck, never raised overhead ({maxFore})`)
	check(maxRise <= J.riseStuds + 1e-9 and minRise >= -(J.seatDropStuds or 0) - 1e-9, "the rise stays within riseStuds")
	check(maxPump <= J.pumpDeg + 1e-9 and maxPump > 0.9 * J.pumpDeg, "the waist pumps +-pumpDeg")
	check(maxShoulderPump <= J.shoulderPumpDeg + 1e-9, "the shoulders pump +-shoulderPumpDeg")
	local plant = HorseLegs.BOB.gallop.plant
	check(math.abs(plantPhase - plant) <= 0.02 or math.abs(plantPhase - plant) >= 0.98,
		`the deepest reach lands on the lead forefoot's landing (the hoof dust beat): {plantPhase} vs {plant}`)
	check(HorseLegs.crossedPlant("gallop", plant - 0.01, plant + 0.01), "that landing is the one the dust puffs on")
	local rest = JockeyPose.solve(J, 0, 0, JockeyPose.newPose())
	check(rest.waist == base.waist and rest.rise == -(J.seatDropStuds or 0), "standing still (or Reduced Motion): the crouch, no pump")
	-- Both sides always take the same field: no one-arm (whip or crop) pose exists.
	local fields: { [string]: string } = {}
	for _, j in JockeyPose.JOINTS do fields[j.motor] = j.field end
	for motor, field in fields do
		local side = string.match(motor, "^Left(.+)$")
		if side then check(fields["Right" .. side] == field, `{motor} and Right{side} take the same pose`) end
	end
	check(fields.LeftShoulder == "shoulder" and fields.LeftElbow == "elbow" and fields.Root == "pelvis", "the joints the plan names")
	local jsrc = fs.readFile("game/src/client/JockeyPose.luau")
	check(string.find(jsrc, "RigType ~= Enum.HumanoidRigType.R15", 1, true) ~= nil, "R6 rigs keep the sit")
	check(string.find(jsrc, "PreSimulation", 1, true) ~= nil, "posed in PreSimulation (after the Animator)")

	-- TrackDressing: the plan on the real venue's geometry (TrackScene.buildVenue's numbers).
	local cfg = TrackLayout.churchill
	local rOut = TrackLayout.outerRadius(cfg)
	local _, _, lineZ = TrackLayout.finishLine(cfg)
	local apron, tiers = rOut + 18, 7
	local backX, roofY = apron + 14 * tiers, 6 + tiers * 6 + 24
	local geom = {
		roofEdgeX = apron + 24, roofTopY = roofY + 1.5, roofUnderY = roofY - 1.5, z0 = lineZ - 300, z1 = lineZ + 600,
		finials = { { x = backX - 18, y = roofY + 1.5 + 68, z = lineZ - 32 }, { x = backX - 18, y = roofY + 1.5 + 68, z = lineZ + 32 } },
		tiers = 2 * tiers,
	}
	local plan = TrackDressing.plan(geom, D, TrackLayout, cfg)
	check(plan.parts <= 350 and plan.beams <= 80, `dressing within budget ({plan.parts} parts, {plan.beams} Beams)`)
	check(plan.parts > 0 and plan.beams > 30 and plan.textures == 14, "bunting, flags and a crowd on every stand riser")
	check(#plan.roof >= 2 and close(plan.roof[1].z, geom.z0, 1e-6) and close(plan.roof[#plan.roof].z, geom.z1, 1e-6),
		"roof bunting runs the whole stand")
	local camR = rOut + 12 -- the replay and finish-orbit side camera (RaceState.sideRig)
	local railOk, nearLine = true, false
	for _, p in plan.rail do
		local along = math.max(0, math.abs(p.z - cfg.centerZ) - cfg.straight / 2)
		local r = math.sqrt((p.x - cfg.centerX) ^ 2 + along ^ 2)
		if r < camR + 1 then railOk = false end
		if math.abs(p.z - lineZ) <= 3 and math.abs(p.x - cfg.centerX - r) < 1 then nearLine = true end
	end
	check(#plan.rail >= 10 and railOk, "rail bunting stands behind the side camera, never across its shot")
	check(not nearLine, "no bunting post on the finish line")
	local first, last = plan.rail[1], plan.rail[#plan.rail]
	check(first.z > lineZ + 600 and last.z < lineZ - 100, "rail bunting from a furlong out to past the line")
	for _, f in plan.roofFlags do
		check(math.abs(f.z - geom.finials[1].z) >= D.flagClearOfSpires and math.abs(f.z - geom.finials[2].z) >= D.flagClearOfSpires,
			"roof flags stand clear of the spires")
	end
	check(#plan.spireFlags == 2 and #plan.spireLinks == 5, "the Twin Spires get pennants")
	-- Switches and caps.
	local function with(over: { [string]: any })
		local d = table.clone(D)
		for k, v in over do d[k] = v end
		return TrackDressing.plan(geom, d, TrackLayout, cfg)
	end
	local noBunting = with({ bunting = false })
	check(#noBunting.roof == 0 and #noBunting.rail == 0 and #noBunting.spireLinks == 0 and #noBunting.roofFlags > 0, "bunting = false")
	local noFlags = with({ flags = false })
	check(#noFlags.roofFlags == 0 and #noFlags.spireFlags == 0 and #noFlags.roof > 0, "flags = false")
	check(with({ crowd = false }).textures == 0, "crowd = false")
	local tight = with({ maxBeams = 20, maxParts = 10 })
	check(tight.beams <= 20 and tight.parts <= 10, `a tighter budget is kept ({tight.parts} parts, {tight.beams} Beams)`)
	local dsrc = fs.readFile("game/src/server/TrackDressing.luau")
	check(string.find(dsrc, "a.Parent = parent\n\ta.WorldCFrame", 1, true) ~= nil, "bunting attachments: parent first, then place")
	check(string.find(dsrc, "WorldArt.whenReady", 1, true) ~= nil and string.find(dsrc, "b.Color = fallback", 1, true) ~= nil,
		"plain colours until the images load")

	-- The Big Board: places, lane numbers and names only.
	local rows = {}
	local names = { "Biscuit", "Clover", "Pepper", "Maple", "Juniper", "Sunny", "Rocket", "A Very Long Horse Name Indeed" }
	local n = TrackLifeView.boardRows({ 8, 3, 1, 5, 2, 4, 6, 7 }, names, GameConfig.bigBoard.rows, rows)
	check(n == 4 and rows[1].lane == 8 and rows[2].lane == 3 and rows[4].lane == 5 and rows[4].place == 4, "top 4 in RaceState.order")
	check(utf8.len(rows[1].name) :: number <= TrackLifeView.NAME_MAX + 1, "long names are cut short")
	check(TrackLifeView.boardRows({ 2 }, nil, 4, rows) == 1 and rows[1].name == "Horse", "a field of one, no names yet")
	check(TrackLifeView.rowText({ place = 1, lane = 3, name = "Clover" }) == "1st  Clover", "row text: place and name")
	for _, s in { TrackLifeView.LIVE_TITLE, TrackLifeView.IDLE_TITLE, TrackLifeView.rowText(rows[1]) } do
		check(clean(s), `board text has no wagering, prize or chance words: {s}`)
	end
	local life = fs.readFile("game/src/client/TrackLife.client.luau")
	local code = string.gsub(life, "%-%-[^\n]*", "") -- comments may explain the rule
	check(string.find(code, "%.chance") == nil and string.find(code, "%.purse") == nil and string.find(code, "%.cash") == nil
		and string.find(code, "%%") == nil, "TrackLife never reads a chance, purse or cash, and shows no %")
	check(string.find(code, "RaceState.order", 1, true) ~= nil, "the board reads the same order as the place badge")

	-- Crowd and flags: bounded, cheering only from the burst to the card, still under Reduced Motion.
	local s = { active = false, burstShowing = false, resultsOpen = false, leaderProgress = 0 }
	check(TrackLifeView.crowdMode(s, L) == "calm", "lobby: calm")
	s.active, s.leaderProgress = true, 0.3
	check(TrackLifeView.crowdMode(s, L) == "calm", "early race: calm")
	s.burstShowing = true
	check(TrackLifeView.crowdMode(s, L) == "cheer", "from the burst: cheer")
	s.burstShowing, s.leaderProgress = false, 1.01
	check(TrackLifeView.crowdMode(s, L) == "cheer", "spectators: cheer down the stretch")
	s.resultsOpen = true
	check(TrackLifeView.crowdMode(s, L) == "calm", "card up: calm")
	local maxCalm, maxCheer, maxYaw = 0, 0, 0
	for k = 0, 400 do
		local t = k / 97
		maxCalm = math.max(maxCalm, math.abs(TrackLifeView.crowdOffset(t, "calm", L, k % 7, false)))
		maxCheer = math.max(maxCheer, math.abs(TrackLifeView.crowdOffset(t, "cheer", L, k % 7, false)))
		maxYaw = math.max(maxYaw, math.abs(TrackLifeView.flagYaw(t, L, k % 13, false)))
		check(TrackLifeView.crowdOffset(t, "cheer", L, 1, true) == 0 and TrackLifeView.flagYaw(t, L, 1, true) == 0,
			"Reduced Motion: no bounce, no flutter")
	end
	check(maxCalm <= L.calmStuds + 1e-9 and maxCheer <= L.cheerStuds + 1e-9 and maxCheer > maxCalm, "bounce sizes")
	check(maxYaw <= math.rad(L.flutterDeg) + 1e-9, "flutter within +-flutterDeg")
	check(TrackLifeView.crowdOffset(1, "cheer", { crowdBounce = false }, 1, false) == 0, "crowdBounce = false")

	-- Drawn only: no score, order, trip or server race module reads any of it.
	for _, path in { "game/src/shared/RaceSession.luau", "game/src/shared/Trip.luau", "game/src/server/RaceService.server.luau",
		"src/RaceMath.luau" } do
		local ok, src = pcall(fs.readFile, path)
		if ok then
			check(string.find(src, "JockeyPose", 1, true) == nil and string.find(src, "TrackDressing", 1, true) == nil
				and string.find(src, "TrackLifeView", 1, true) == nil and string.find(src, "trackLife", 1, true) == nil,
				path .. " never reads the world dressing")
		end
	end
end
