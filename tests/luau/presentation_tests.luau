--!strict
-- AAA Phase 4 Dev B (D-069): the gate line-up camera pass, the race HUD restyle and the YOU marker, the
-- music bed's levels and the finish polish (paper confetti, ribbon colours, stars counting in), plus the
-- leftover Phase 2 should-fixes (a RACE! refusal is never held, the tour's ✕ double-tap guard, one leave
-- ✕). Pure timing from RacePresent, and source checks for the Roblox-only wiring. Run from run_all.luau.
local fs = require("@lune/fs")

local GameConfig = require("../../game/src/shared/GameConfig")
local RacePresent = require("../../game/src/shared/RacePresent")
local ResultsText = require("../../game/src/shared/ResultsText")

local function code(path: string): string
	local out = {}
	for _, line in string.split(fs.readFile(path), "\n") do
		local cut = string.find(line, "--", 1, true)
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

-- WCAG contrast of two hex colours.
local function luminance(hex: string): number
	local function ch(i: number): number
		local c = tonumber(string.sub(hex, i, i + 1), 16) / 255
		return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(1) + 0.7152 * ch(3) + 0.0722 * ch(5)
end
local function contrast(a: string, b: string): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- B1. The gate line-up pass -------------------------------------------------------------------------
	local G = GameConfig.gateIntro
	local COUNT = GameConfig.gateCountdownSeconds
	check(COUNT == 3, "the countdown stays at 3 s")
	check(G.enabled == true and G.dollySeconds == 1.6 and G.blendSeconds == 0.4 and G.handBackBefore == 1.0,
		"gateIntro: a 1.6 s dolly, a 0.4 s blend, the Follow camera back 1 s before GO")
	check(G.handBackBefore >= 0.8, "the Follow camera is live at least 0.8 s before GO")
	check(G.dollySeconds + G.blendSeconds + G.handBackBefore <= COUNT + 1e-9, "the pass fits inside the countdown")
	local start = 1000
	local seat = start - COUNT
	check(RacePresent.gateRuns(G, seat, start, COUNT, true, false), "a rider seated at 3 gets the pass")
	check(not RacePresent.gateRuns(G, seat, start, COUNT, false, false), "never for spectators")
	check(not RacePresent.gateRuns(G, seat, start, COUNT, true, true), "never under Reduced Motion")
	check(not RacePresent.gateRuns({ enabled = false }, seat, start, COUNT, true, false), "gateIntro.enabled = false: none")
	check(not RacePresent.gateRuns(nil, seat, start, COUNT, true, false), "no config: none")
	check(not RacePresent.gateRuns(G, seat + 0.5, start, COUNT, true, false), "a late seat goes straight to the chase view")
	check(not RacePresent.gateRuns(G, start - 0.5, start, COUNT, true, false), "a seat after the hand-back: none")
	check(RacePresent.gateRuns(G, seat + 0.2, start, COUNT, true, false), "a seat a moment late still gets it")
	local p0, f0 = RacePresent.gateFrame(G, seat, start)
	check(p0 == "dolly" and close(f0, 0, 1e-9), "the dolly starts at the seat, at the outside lane")
	local pMid, fMid = RacePresent.gateFrame(G, seat + 0.8, start)
	check(pMid == "dolly" and close(fMid, 0.5, 1e-9), "half way along the gate at the dolly's middle")
	local pB = RacePresent.gateFrame(G, start - 1.2, start)
	check(pB == "blend", "then the blend to behind your horse")
	local pD = RacePresent.gateFrame(G, start - G.handBackBefore, start)
	check(pD == "done", "handed back at start - handBackBefore")
	local mono, last, lastPhase = true, -1, "dolly"
	for k = 0, 40 do
		local t = seat + k * 0.05
		local ph, f = RacePresent.gateFrame(G, t, start)
		if ph ~= lastPhase then last, lastPhase = -1, ph end
		if f < last - 1e-9 or f < 0 or f > 1 then mono = false end
		last = f
	end
	check(mono, "the pass moves one way, eased, within 0..1")
	local gate = code("game/src/client/GateIntro.luau")
	check(not has(gate, "FieldOfView") and not has(gate, "CameraSubject"), "GateIntro never touches the FOV (RaceCamera owns it) or the subject")
	check(has(gate, "RacePresent.gateRuns(CFG, now, start, GameConfig.gateCountdownSeconds or 3, true, still())"),
		"GateIntro asks gateRuns with Reduced Motion")
	check(has(gate, "camera.CameraType = if Cam.on then Enum.CameraType.Follow else Enum.CameraType.Custom")
		and has(gate, "if mineToken == token then stop() end"), "the camera is always handed back, on a timer too")
	local rc = code("game/src/client/RaceController.client.luau")
	local gateCall = string.find(rc, "require(script.Parent:WaitForChild(\"GateIntro\")).run(", 1, true)
	local ridingBlock = string.find(rc, "The camera moves into the saddle at", 1, true) or string.find(rc, "Cam.ride(true)", 1, true)
	check(gateCall ~= nil and ridingBlock ~= nil, "RaceController runs the pass once seated (riders only)")

	-- B2. The HUD restyle and the YOU marker ------------------------------------------------------------
	check(not has(rc, "fromRGB(20, 30, 25)"), "no dark green boxes left in the race HUD")
	check(not has(rc, "fromRGB(60, 200, 90)"), "the glow is Gold, not green")
	check(has(rc, "require(script.Parent:WaitForChild(\"RaceHudStyle\")).apply(")
		and has(rc, "require(script.Parent:WaitForChild(\"RaceHudStyle\")).youMarker(bb)"), "RaceController wires RaceHudStyle")
	local style = code("game/src/client/RaceHudStyle.luau")
	check(has(style, "\"1D2433\"") and has(style, "\"FFF7E6\"") and has(style, "\"FFD23F\"") and has(style, "\"2A3247\""),
		"the HUD uses Ink, Paper, Gold and Slate")
	check(has(style, "Enum.Font.FredokaOne") and has(style, "BuilderSans"), "Fredoka One words, Builder Sans numbers")
	check(contrast("1D2433", "FFF7E6") >= 4.5 and contrast("8F4700", "FFF7E6") >= 4.5, "board and badge text pass 4.5:1 on Paper")
	check(has(rc, "Color3.fromHex(\"8F4700\") else Color3.fromHex(\"1D2433\")"), "board rows: Ink, yours dark orange")
	local Y = GameConfig.raceHud.youMarker
	local s1, st1, w1, h1 = RacePresent.youMarker(Y, true, 14, false)
	check(s1 and st1 == 7 and w1 == 56 and h1 == 72, "the chase view: 7 studs up, 56 x 72 px")
	check(not (RacePresent.youMarker(Y, true, 1, false)), "hidden in first person")
	check(not (RacePresent.youMarker(Y, true, 14, true)), "hidden during the finish orbit")
	local s2, st2, w2 = RacePresent.youMarker(Y, false, 30, false)
	check(s2 and st2 == 12 and w2 == 90, "replays and other views keep 12 studs and 90 px")
	check(56 >= GameConfig.ui.minTouchPx, "the small marker is still at least a tap-target wide")
	check(has(code("game/src/client/FinishMoment.luau"), "SetAttribute(\"OrbitHidden\", true)") and has(style, "GetAttribute(\"OrbitHidden\")"),
		"the orbit's hidden marker stays hidden until the moment clears")

	-- B3. The music bed ----------------------------------------------------------------------------------
	local M = GameConfig.audio.music
	check(M.id == 0, "no music until David picks a library track (no upload)")
	for _, mode in { "lobby", "race", "spectate", "finish" } do
		check(RacePresent.musicLevel(M, mode, false) == 0, `id 0: silent in {mode}`)
	end
	local on = table.clone(M)
	on.id = 123
	local lobby, race, spect, fin = RacePresent.musicLevel(on, "lobby", false), RacePresent.musicLevel(on, "race", false),
		RacePresent.musicLevel(on, "spectate", false), RacePresent.musicLevel(on, "finish", false)
	check(close(lobby, 0.35, 1e-9) and close(race, 0.12, 1e-9) and close(fin, 0.4, 1e-9), "lobby 0.35, race 0.12, finish 0.4")
	check(spect <= race and spect > 0, "spectators hear it lower still")
	check(close(RacePresent.musicLevel(on, "race", true), race * M.duckUnderVoice, 1e-9), "ducked further under the announcer")
	check(RacePresent.musicLevel(on, "off", false) == 0, "off is off")
	local tick = 0.25 * GameConfig.raceFx.tickVolume -- tap_ok's level x the race's tick volume
	check(race <= tick * 0.5, "while the slider runs the bed is at most half the tap tick's level")
	local level, t = lobby, 0
	while level ~= race and t < 5 do
		level = RacePresent.musicStep(on, level, race, 1 / 60)
		t += 1 / 60
	end
	check(level == race and t <= M.fadeSeconds + 1e-6, "a change lands within fadeSeconds")
	local music = code("game/src/client/MusicBed.luau")
	check(has(music, "CFG.id == 0 then return end") and has(music, "Sound.speaking()"), "MusicBed: nothing without a track; ducks under voices")
	check(has(code("game/src/client/Sound.luau"), "m.SoundGroup = group"), "the bed plays in Sound's group (Sound Off mutes it)")
	check(has(rc, "require(script.Parent:WaitForChild(\"MusicBed\")).start()"), "RaceController starts the bed")

	-- B4. Finish polish ----------------------------------------------------------------------------------
	local FIN = GameConfig.finish
	check(FIN.dim == 0.75, "the dim is Ink at 0.75")
	local fm = code("game/src/client/FinishMoment.luau")
	local card = code("game/src/client/ResultsCard.luau")
	for _, src in { fm, card } do
		check(has(src, "\"2F6FDE\"") and has(src, "\"E0474C\"") and has(src, "\"FFD23F\"") and has(src, "\"FFFFFF\"")
			and not has(src, "3B7BD9") and not has(src, "F2C230"), "ribbon colours from ART_DIRECTION")
	end
	check(has(fm, "GetAttribute(\"UiSheet_confetti_square\")") and has(fm, "FIN.confettiFallback"),
		"confetti uses confetti_square once uploaded, the built-in texture until then")
	local steps = RacePresent.starSteps(FIN, 3, false)
	check(#steps == 3 and close(steps[1].at, FIN.starDelaySeconds, 1e-9) and close(steps[2].at - steps[1].at, 0.2, 1e-9)
		and close(steps[3].at - steps[2].at, 0.2, 1e-9), "three stars count in 0.2 s apart")
	check(steps[1].speed == 1.0 and steps[2].speed == 1.15 and steps[3].speed == 1.3, "each tick a little higher")
	check(steps[3].stars == 3 and ResultsText.rideLine(steps[3].stars) == "You rode ★★★", "the count ends on the stars you rode")
	check(#RacePresent.starSteps(FIN, 2, true) == 0, "Reduced Motion: the stars show at once")
	check(#RacePresent.starSteps(FIN, 0, false) == 0, "no stars: no ticks (the kind line still shows)")
	check(#RacePresent.starSteps(FIN, 0 / 0, false) == 0 and #RacePresent.starSteps(FIN, 9, false) == 3, "strange star counts are safe")
	check(FIN.starTick == "count_tick" and has(card, "Sound.play(FIN.starTick or \"count_tick\", FIN.starTickVolume or 0.8, nil, step.speed)"),
		"the rising tick is count_tick at the step's speed")
	check(has(rc, "Card.setRide(ResultsText.rowStars(rideReport.stars, rideReport.tripStars, STEER.scale, TRIP_ROW))"),
		"the card's star row still comes from ResultsText")

	-- Phase 2 should-fixes ---------------------------------------------------------------------------
	local ui = code("game/src/client/Ui.luau")
	local hud = code("game/src/client/Hud.client.luau")
	check(has(ui, "if held and os.clock() > holdBypassUntil then") and has(hud, "Ui.racePressed(FM.raceReasonSeconds or 4)"),
		"N2: a toast right after RACE! is never held (the reason always shows)")
	check(GameConfig.firstMinute.raceReasonSeconds >= 3, "the reason window is at least 3 s")
	local gu = code("game/src/client/GrownUps.client.luau")
	check(has(gu, "os.clock() - skipAsked < (FM.skipGuardSeconds or 0.6) then return end") and GameConfig.firstMinute.skipGuardSeconds == 0.6,
		"the tour's ✕ ignores a second tap within 0.6 s")
	check(has(hud, "local leaveShown = inLine and not Ui.queueLeaveShown")
		and has(code("game/src/client/QueueCard.client.luau"), "Ui.queueLeaveShown = show and v.showLeave"),
		"one ✕ to leave the line: the dock's hides while the queue card shows its own")
end
