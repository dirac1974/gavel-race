--!strict
-- D-071 wiring: the tap preview in RaceService, RaceView and the rider's own screen (TapCue,
-- TapMessage). Pure rules for the message queue and the held cue, and source checks for the
-- Roblox-only wiring: computed on the server only for races with a human, the message and the held
-- feet go to the rider alone, the chip's rules and limits, no "boxed in", enabled = false is today's
-- race, and nothing per frame allocates. Run from run_all.luau.
local fs = require("@lune/fs")

local GameConfig = require("../../game/src/shared/GameConfig")
local TapPreview = require("../../game/src/shared/TapPreview")
local TapMessage = require("../../game/src/shared/TapMessage")
local PacePreview = require("../../game/src/shared/PacePreview")

local function code(path: string): string
	local out = {}
	for _, line in string.split((string.gsub(fs.readFile(path), "\r", "")), "\n") do
		local cut = string.find(line, "--", 1, true)
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

local function count(src: string, s: string): number
	local n, at = 0, 1
	while true do
		local i = string.find(src, s, at, true)
		if not i then return n end
		n += 1
		at = i + #s
	end
end

-- The text between two markers (exclusive), or "" when either is missing.
local function between(src: string, a: string, b: string): string
	local i = string.find(src, a, 1, true)
	if not i then return "" end
	local j = string.find(src, b, i + #a, true)
	if not j then return "" end
	return string.sub(src, i + #a, j - 1)
end

local function words(s: string): number
	local n = 0
	for _ in string.gmatch(s, "%S+") do n += 1 end
	return n
end

local BANNED = { "bet", "bets", "betting", "wager", "odds", "stake", "stakes", "payout", "house", "bookie" }

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local server = code("game/src/server/RaceService.server.luau")
	local cue = code("game/src/client/TapCue.luau")
	local view = code("game/src/client/RaceView.client.luau")
	local ctrl = code("game/src/client/RaceController.client.luau")
	local P = GameConfig.tapPreview
	local C = GameConfig.tapCue

	-- 1. Server compute only for races with a human ---------------------------------------------------
	check(has(server, "local uid = if lane.isBot then nil else tonumber(lane.id)"), "tap riders are human lanes only")
	check(has(server, "if trip and #tapRiders > 0 then\n\t\ttp = TapPreview.new("), "the layer is made only with a trip and a human")
	check(count(server, "TapPreview.new(") == 1, "one TapPreview per race")
	check(has(server, "local tapWholeRace = trip == nil and #tapRiders > 0"), "steering off: the pass-end preview needs a human too")
	check(has(server, "local tapOn = TapPreview.enabled(tapCfg)") and has(server, "if tapOn then"),
		"no tap riders (so no layer, no pass-end work) with the layer off")
	check(has(server, "if tp then TapPreview.closed(tp) end"), "closed() after the checkpoint closes")
	check(count(server, "session:closeSegment(") == count(server, "TapPreview.closed(tp)"), "closed() after every closeSegment")
	-- step in send(), after Trip.frame, before the offsets are fired
	local send = between(server, "local function send(stamp: number, frameDt: number)", "while alive() do")
	local frameAt = string.find(send, "Trip.frame(", 1, true) or 0
	local stepAt = string.find(send, "TapPreview.step(tp, offsets,", 1, true) or 0
	local fireAt = string.find(send, "RaceOffsets:FireAllClients(offsets", 1, true) or 0
	check(frameAt > 0 and stepAt > frameAt and fireAt > stepAt, "TapPreview.step runs after Trip.frame and before the offsets go out")
	check(has(send, "if trip.locked then trip.shown else trip.x") and has(send, "if trip.locked then trip.shownTgt else trip.tgt"),
		"step reads Trip's lanes before the lock and the shown lanes after")
	check(has(send, "debug.profilebegin(\"RaceSend\")") and has(send, "debug.profileend()"), "the send step is in the microprofiler")
	-- pass ends: before the lock, the open checkpoint, previewOwn
	local passEnd = between(server, "local function tapPassEnd(seg: number, segPasses)", "local errors")
	check(has(passEnd, "if trip.locked or seg ~= session.closed + 1 then return end"), "pass ends feed the layer only before the lock")
	check(has(passEnd, "session:previewOwn(seg, tapPartial)") and not has(passEnd, "previewLive"), "the layer's preview is previewOwn")
	check(has(passEnd, "PacePreview.beforeLock(tapCfg, false, seg, session.closed, false) then\n\t\t\tpreviewStretch(seg, true)"),
		"steering off: previewStretch at pass ends, with previewOwn")
	check(has(server, "shownLive = if own then session:previewOwn(seg, partial) else session:previewLive(seg, partial)"),
		"steering off previews with previewOwn (the field's scores arrive at the close)")
	-- late taps: a pass counts once its late taps can be in (maxTapRewindSeconds), in every preview
	check(has(server, "local TAP_GRACE = if tapOn then GameConfig.maxTapRewindSeconds or 0 else 0"), "the late-tap grace (layer on)")
	check(has(passEnd, "if p.t1 + TAP_GRACE <= t then table.insert(tapDone, p) end"), "pass ends wait for late taps")
	check(has(server, "if segPasses[k + 1] then wake = math.min(wake, segPasses[k + 1].t1 + TAP_GRACE) end")
		and has(server, "while segPasses[k + 1] and segPasses[k + 1].t1 + TAP_GRACE <= t do"), "the pass-end wake waits for late taps")
	local stretch = between(server, "previewStretch = function(seg: number, own: boolean?)", "local function tapPassEnd")
	check(has(stretch, "if p.t1 + TAP_GRACE <= now() then table.insert(done, p) end"), "previewStretch waits for late taps too")
	check(not has(passEnd, "p.t1 <= t") and not has(stretch, "p.t1 <= now()"), "no pass counted before its late taps")
	check((GameConfig.maxTapRewindSeconds or 0) > 0, "a late-tap grace exists")
	-- the after-lock previews count from the lock
	check(has(server, "nextAfter = (tapLockAt or now()) + every") and has(server, "tapLockAt = now()"), "after-lock timer starts at the lock")
	check(has(server, "if ended then tapPassEnd(seg, segPasses) end"), "the segment loop wakes at each pass end")
	check(has(server, "elseif tp or tapWholeRace then"), "the pass-end loop runs only with the layer (or steering off) in a human race")
	-- the lock refreshes the shown chances once
	local adv = between(server, "local function advanceTrip(t: number)", "task.spawn(function()")
	check(has(adv, "if tp and cur.seg and PacePreview.afterLock(PREVIEW_AFTER_LOCK, true, cur.seg, session.closed, false) then"),
		"the lock refreshes the shown chances once (layer on only)")
	check(has(adv, "if now() < lastEnd then previewStretch(cur.seg) end"), "only while the checkpoint's passes still run")
	-- nothing per frame allocates
	local notes = between(server, "local function tapNotes(stamp: number)", "local function send(")
	check(#notes > 0 and not has(notes, "{") and not has(notes, "table.") and not has(notes, "string.")
		and not has(notes, "function"), "tapNotes allocates nothing")
	local stepCall = between(send, "if tp then", "end\n")
	check(not has(stepCall, "table.clone") and not has(stepCall, "{"), "the step's result is sent as it is (no copy)")

	-- 2. The message and the held feet go to the rider alone ------------------------------------------
	check(has(server, "local TapNote = makeRemote(\"TapNote\")"), "TapNote remote")
	check(has(server, "local TapHeld = Instance.new(\"UnreliableRemoteEvent\")"), "TapHeld is unreliable")
	check(not has(server, "TapNote:FireAllClients") and not has(server, "TapHeld:FireAllClients"), "never sent to every screen")
	check(count(server, "TapNote:FireClient(") == 1 and has(server, "TapNote:FireClient(r.p, kind, c.id)"), "TapNote to the rider only")
	check(count(server, "TapHeld:FireClient(") == 1 and has(server, "TapHeld:FireClient(r.p, r.hs.last, c.id)"), "TapHeld to the rider only")
	check(has(notes, "if TapPreview.heldSendDue(r.hs, TapPreview.held(tp, r.i), stamp, tapCfg) then"), "TapHeld when TapPreview.heldSendDue says")
	check(has(server, "hs = TapPreview.newHeldSend()"), "one send state per rider per race")
	check(type(P.heldSend) == "table" and P.heldSend.minGapSeconds >= 0.5 and P.heldSend.feet >= 1, "TapHeld rate limits")
	-- the client listens only for the race it rides (RaceController's steer exists only for riders)
	check(has(cue, "s ~= nil and s == st.steer"), "TapCue keys on your ride")
	check(has(ctrl, "steer = function() return steer end"), "RaceController hands TapCue the race you ride")
	check(not has(cue, "FireServer"), "TapCue sends nothing to the server")
	check(not has(cue, "Sound"), "the message is silent")

	-- 3. Message rules (TapMessage) -------------------------------------------------------------------
	check(TapMessage.TEXT.up == "Giddy-up! Moving up!", "message copy")
	for kind, text in TapMessage.TEXT do
		local low = string.lower(text)
		check(not has(low, "away") and not has(low, "lead") and not has(low, "win"), "no away, lead or win: " .. kind)
	end
	local qa = TapMessage.new()
	TapMessage.offer(qa, "away", 0)
	check(qa.kind == nil, "no \"Pulling away!\" (the systems consult)")
	local q = TapMessage.new()
	check(TapMessage.take(q, 0, C, P, false, false, false) == nil, "nothing to show")
	TapMessage.offer(q, "up", 10)
	check(TapMessage.take(q, 10, C, P, false, false, true) == nil, "waits behind a chip or coaching")
	check(TapMessage.take(q, 11, C, P, false, false, false) == "Giddy-up! Moving up!", "then shows")
	check(TapMessage.take(q, 11.1, C, P, false, false, false) == nil, "once")
	TapMessage.offer(q, "up", 14)
	check(TapMessage.take(q, 14, C, P, false, false, false) == nil, "never closer than messageEverySeconds")
	check(TapMessage.take(q, 11 + P.messageEverySeconds, C, P, false, false, false) == "Giddy-up! Moving up!", "after the gap")
	TapMessage.offer(q, "up", 30)
	check(TapMessage.take(q, 30, C, P, false, true, false) == nil and q.kind == nil, "dropped in the Final Burst")
	TapMessage.offer(q, "up", 40)
	check(TapMessage.take(q, 40, C, P, true, false, false) == nil and q.kind == nil, "dropped after the lock")
	TapMessage.offer(q, "up", 50)
	check(TapMessage.take(q, 50 + C.waitSeconds + 0.1, C, P, false, false, false) == nil and q.kind == nil, "dropped when it waited too long")
	TapMessage.offer(q, "leading", 60)
	check(q.kind == nil, "unknown kinds are ignored")
	local off = TapMessage.new()
	TapMessage.offer(off, "up", 0)
	check(TapMessage.take(off, 0, { enabled = false }, P, false, false, false) == nil, "tapCue.enabled = false shows nothing")

	-- 4. The held cue and chip (TapPreview.stepCue as TapCue calls it) --------------------------------
	local H = P.heldCue
	check(type(H) == "table" and H.minFeet == 4 and H.minSeconds == 1 and H.chipMinFeet == 6 and H.chipMinSeconds == 1.5
		and H.chipEverySeconds == 10, "heldCue as ruled")
	check(has(cue, "TapPreview.stepCue(st.cue, PCFG, st.held, dt, now, s.locked == true, not s.shown, room)"),
		"buttons: \"Room this way!\"; no buttons: \"Keep tapping! Room soon.\"")
	check(has(cue, "lane.inSide == \"free\" or lane.outSide == \"free\""), "\"Room this way!\" only when SteerLane shows a side with room")
	-- one arrow, toward the free side (both free: in, which saves ground), and that button's ring
	check(TapMessage.chip("gap", "free", "free") == "Room this way! ◀" and select(2, TapMessage.chip("gap", "free", "free")) == -1, "both free: in")
	check(TapMessage.chip("gap", "blocked", "free") == "Room this way! ▶" and select(2, TapMessage.chip("gap", "blocked", "free")) == 1, "out free: ▶")
	check(TapMessage.chip("gap", "free", "edge") == "Room this way! ◀", "in free: ◀")
	check(TapMessage.chip("gap", "tuck", "blocked") == nil, "no room: no chip")
	check(TapMessage.chip("taps", nil, nil) == "Keep tapping! Room soon." and select(2, TapMessage.chip("taps", nil, nil)) == 0, "Smart Steer copy")
	for _, text in TapMessage.CHIP do
		check(not (has(text, "◀") and has(text, "▶")), "one arrow only: " .. text)
	end
	check(has(cue, "s.roomRing, s.roomRingUntil = dir, os.clock()") and has(ctrl, "if s.roomRing < 0 then inArrow.ring = 1 else outArrow.ring = 1 end"),
		"the matching button's ring lights briefly")
	check(has(cue, "RaceState.tapPressure = pressure and not still()"), "no pressure cue under Reduced Motion")
	check(has(view, "if RaceState.tapPressure then surgeDeg +="), "the pressure cue's forward lean (tapPressure is off under Reduced Motion)")
	check((C.leanDeg or 0) > 0 and (C.leanDeg or 0) <= 3, "a small lean")
	-- the billboards render: an Adornee on the message and on the YOU marker
	check(has(cue, "bb.Adornee = (horse:IsA(\"Model\") and horse.PrimaryPart) or horse:FindFirstChildWhichIsA(\"BasePart\", true)"),
		"the message's billboard has an Adornee")
	check(has(ctrl, "bb.Adornee = (horse:IsA(\"Model\") and horse.PrimaryPart) or horse:FindFirstChildWhichIsA(\"BasePart\", true)"),
		"the YOU marker has an Adornee")
	check(has(cue, "you:SetAttribute(\"TapHidden\"") and has(code("game/src/client/RaceHudStyle.luau"), "if bb:GetAttribute(\"TapHidden\") then shown = false end"),
		"the YOU marker steps aside while the message shows")
	check(has(cue, "YOU.riderShown == true"), "...only where riderShown puts it over your horse")
	check(has(cue, "if firstPerson() then") and has(cue, "h.hintLine(text, seconds)") and has(ctrl, "hintLine = function(text: string, seconds: number)"),
		"first person: the hint line")
	check(has(cue, "size.MinTextSize, size.MaxTextSize = CFG.minTextPx or 14, CFG.maxTextPx or 24") and C.minTextPx >= 14,
		"the message's text stays 14 to 24 px")
	check(has(ctrl, "local quiet = RaceState.tapMessageUp and labelText ~= \"Perfect\" and labelText ~= \"Early\" and labelText ~= \"Late\""),
		"while the message shows, only Perfect, Early and Late tap words")
	check(has(view, "if mine and RaceState.tapPressure then bob *="), "the pressure cue's bob, your horse only")
	check(has(view, "FX.dustPerStride + (if RaceState.tapPressure"), "the pressure cue's dust puff")
	-- buttons, room: a chip at 1.5 s held >= 6 ft, then no more for chipEverySeconds; never after the lock
	local c1 = TapPreview.newCue()
	local dt = 0.1
	local pressureAt, gaps, t = nil, {}, 0
	for _ = 1, 300 do
		t += dt
		local pressure, chip = TapPreview.stepCue(c1, P, 7, dt, t, false, false, true)
		if pressure and not pressureAt then pressureAt = t end
		if chip then
			check(chip == "gap", "a rider with buttons gets \"Room this way!\"")
			table.insert(gaps, t)
		end
	end
	check(pressureAt ~= nil and pressureAt >= H.minSeconds - 1e-6 and pressureAt <= H.minSeconds + dt + 1e-6, "pressure after minSeconds")
	check(#gaps >= 2 and gaps[1] >= H.chipMinSeconds - 1e-6, "first chip after chipMinSeconds")
	for k = 2, #gaps do check(gaps[k] - gaps[k - 1] >= H.chipEverySeconds - 1e-6, "\"Room this way!\" at most every chipEverySeconds") end
	local c2 = TapPreview.newCue()
	local any = false
	for k = 1, 100 do
		local _, chip = TapPreview.stepCue(c2, P, 9, dt, k * dt, false, false, false)
		if chip then any = true end
	end
	check(not any, "no \"Room this way!\" without room on a side")
	local c3 = TapPreview.newCue()
	local after = false
	for k = 1, 100 do
		local pressure, chip = TapPreview.stepCue(c3, P, 9, dt, k * dt, true, false, true)
		if chip or pressure then after = true end
	end
	check(not after, "nothing after the lock")
	local c4 = TapPreview.newCue()
	local taps = 0
	for k = 1, 600 do
		local _, chip = TapPreview.stepCue(c4, P, 9, dt, k * dt, false, true, false)
		if chip == "taps" then taps += 1 end
	end
	check(taps == 1, "\"Keep tapping! Room soon.\" once a race")
	local c5 = TapPreview.newCue()
	local small = false
	for k = 1, 100 do
		local pressure, chip = TapPreview.stepCue(c5, P, 3.9, dt, k * dt, false, false, true)
		if pressure or chip then small = true end
	end
	check(not small, "nothing under minFeet")
	-- a chip that would crowd another waits (it isn't spent)
	check(has(cue, "st.cue.chipAt, st.cue.tapsShown = chipAt, tapsShown"), "a crowded chip waits, unspent")

	-- 5. Copy: short, no wagering words, no "boxed in", never "leading" or "winning" -----------------
	local all = {}
	for _, s in TapMessage.TEXT do table.insert(all, s) end
	for _, s in TapMessage.CHIP do table.insert(all, s) end
	for _, s in all do
		check(words(s) <= 10, "at most 10 words: " .. s)
		local low = string.lower(s)
		for _, w in BANNED do check(string.find(low, "%f[%a]" .. w .. "%f[%A]") == nil, "no wagering word in " .. s) end
		check(not has(low, "leading") and not has(low, "winning") and not has(low, "boxed"), "no leading, winning or boxed in: " .. s)
	end
	for _, src in { server, cue, ctrl, code("game/src/shared/TapMessage.luau") } do
		check(not has(string.lower(src), "boxed in"), "no \"boxed in\" on screen")
	end

	-- 6. enabled = false is today's race ---------------------------------------------------------------
	local offCfg = table.clone(P)
	offCfg.enabled = false
	check(not TapPreview.enabled(offCfg), "off")
	check(not PacePreview.beforeLock(offCfg, false, 1, 0, false), "no steering-off pass-end preview with it off")
	local stOff = TapPreview.new(3, offCfg, 40, 8, 0.9)
	local base = { 3, -2, 5 }
	local out = TapPreview.step(stOff, base, { 1, 2, 3 }, { 1, 2, 3 }, 1, false)
	check(out[1] == 3 and out[2] == -2 and out[3] == 5, "the layer passes Trip's offsets through")
	local cOff = TapPreview.newCue()
	local p0, ch0 = TapPreview.stepCue(cOff, offCfg, 12, 5, 5, false, false, true)
	check(not p0 and ch0 == nil, "no cue or chip with it off")
	check(has(view, "local TAP_PREVIEW = GameConfig.tapPreview ~= nil and GameConfig.tapPreview.enabled == true")
		and has(view, "if TAP_PREVIEW and race.nudgeBase then"), "RaceView's baseFall only with the layer on")
	check(has(view, "RaceFx.stepNudge(nudgeDrawn, goal, room, dt, FX, baseFall)"), "RaceView passes baseFall into stepNudge")
	check(has(cue, "if not s or CFG.enabled == false or not TapPreview.enabled(PCFG) then"), "TapCue idles with it off")
	-- the old after-lock loop is kept for a race without the layer
	check(has(server, "elseif trip and PREVIEW_AFTER_LOCK and PREVIEW_AFTER_LOCK.enabled ~= false then"), "D-067's loop unchanged")
end
