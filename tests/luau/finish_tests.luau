--!strict
-- AAA Phase 2 (D-067): the finish moment, the results card's words, first-race coaching and the
-- post-lock pace preview. The finish moment's caps (orbit at most 2.5 s, the card within 4 s of
-- the line, a gallop-out of 0.04 of a Short race, drawn only), every results line short and kind
-- (no near miss, no wagering word, "Best ride" only for the top 3), and that the post-lock preview
-- changes nothing before the lock and nothing in the scores, the order or the prizes. Run from
-- run_all.luau.
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
local RaceFx = require("../../game/src/shared/RaceFx")
local ResultsText = require("../../game/src/shared/ResultsText")
local PacePreview = require("../../game/src/shared/PacePreview")
local PickerText = require("../../game/src/shared/PickerText")
local Words = require("../../game/src/shared/Words")

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

local function code(path: string): string
	local out = {}
	for _, line in string.split(fs.readFile(path), "\n") do
		local cut = string.find(line, "--", 1, true)
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local FIN = GameConfig.finish
	local FX = GameConfig.raceFx

	-- The finish moment's caps (CONSENSUS: at most 2.5 s, skippable, the card within 4 s) -----------
	check(FIN.enabled == true and FIN.orbitSeconds <= 2.5 and FIN.cardWithinSeconds <= 4, "finish: orbit <= 2.5 s, card <= 4 s")
	local short = TrackLayout.plan(TrackLayout.courses.dirt, TrackLayout.distances.Sprint).lengths[1]
	check(close(RaceFx.pastLine(short, FIN), 0.04, 0.002), "the gallop-out is about 0.04 of a Short race (was 0.012)")
	local feetSame = true
	for _, d in { "Sprint", "Mile", "Classic", "Marathon" } do
		for _, course in { "dirt", "turf" } do
			local len1 = TrackLayout.plan(TrackLayout.courses[course], TrackLayout.distances[d]).lengths[1]
			if not close(RaceFx.pastLine(len1, FIN) * len1, FIN.gallopOutFeet, 1e-6) then feetSame = false end
		end
	end
	check(feetSame, "every race gallops out the same distance past the line")
	check(RaceFx.pastLine(1000, nil) == 0.012, "no finish config: the old pull-up")
	local tau = FIN.gallopOutFeet / GameConfig.raceSpeedStudsPerSecond
	check(tau > 1.5 and tau < 4, `a smooth pull-up: speed halves about every {math.floor(tau * 0.69 * 10) / 10} s, no dead stop`)

	-- When the card shows: after the orbit from your crossing, never later than 4 s after the leader's.
	local worst, worstStill = -math.huge, -math.huge
	for k = 0, 40 do
		local cross = 100 - 0.5 + k * 0.1 -- from half a second before to 3.5 s after the leader
		worst = math.max(worst, RaceFx.cardAt(cross, 100, FIN, false) - 100)
		worstStill = math.max(worstStill, RaceFx.cardAt(cross, 100, FIN, true) - 100)
	end
	check(worst <= FIN.cardWithinSeconds + 1e-9 and worstStill <= FIN.cardWithinSeconds + 1e-9, "the card is up within 4 s of the line")
	check(close(RaceFx.cardAt(100, 100, FIN, false), 100 + FIN.orbitSeconds, 1e-9), "the leader's card comes as the orbit ends")
	check(close(RaceFx.cardAt(100, 100, FIN, true), 100 + FIN.fadeSeconds, 1e-9), "Reduced Motion: the card after the fade")
	check(RaceFx.cardAt(100, 100, { orbit = true, orbitSeconds = 9, cardWithinSeconds = 99, fadeSeconds = 0.4 }, false) == 102.5,
		"the orbit is never longer than 2.5 s, whatever the config says")

	-- The orbit: from the chase camera to the side view, eased, the short way round.
	local a0, r0, h0 = RaceFx.orbit(3, 14, 7, -1.5, 30, 6, 0)
	local a1, r1, h1 = RaceFx.orbit(3, 14, 7, -1.5, 30, 6, 1)
	check(close(a0, 3, 1e-9) and close(r0, 14, 1e-9) and close(h0, 7, 1e-9), "the orbit starts where the camera was")
	check(close(math.cos(a1), math.cos(-1.5), 1e-9) and close(math.sin(a1), math.sin(-1.5), 1e-9) and close(r1, 30, 1e-9)
		and close(h1, 6, 1e-9), "...and ends on the replay's side view")
	local am = RaceFx.orbit(3, 14, 7, -3, 30, 6, 0.5)
	check(am > 3 and am < 3 + math.pi, "it turns the short way round (through pi, not back through 0)")
	local last, smooth = -math.huge, true
	for k = 0, 20 do
		local a = RaceFx.orbit(0, 10, 5, 1.5, 30, 6, k / 20)
		if a < last then smooth = false end
		last = a
	end
	check(smooth and RaceFx.orbit(0, 10, 5, 1.5, 30, 6, 2) == 1.5, "it eases one way and holds at the end")

	-- Drawn only: the finish moment and the card never reach a score, the order or the trip.
	for _, name in { "RaceSession", "Trip", "RaceShape", "PaceMeter", "Playback" } do
		local src = fs.readFile("game/src/shared/" .. name .. ".luau")
		check(string.find(src, "[Cc]onfig%.finish[^%w]") == nil -- (finishPoints is the prize table, not this)
			and string.find(src, "FinishMoment", 1, true) == nil, name .. " never reads the finish moment")
	end
	local rc = code("game/src/client/RaceController.client.luau")
	local fm = code("game/src/client/FinishMoment.luau")
	check(string.find(rc, "RaceState.setFinal", 1, true) == nil and string.find(fm, "RaceState.setFinal", 1, true) == nil
		and string.find(fm, "FireServer", 1, true) == nil, "the finish moment never changes the order or tells the server anything")
	check(string.find(rc, "seq.skip = true", 1, true) ~= nil and string.find(rc, "Finish.orbitFrame(seq, t)", 1, true) ~= nil
		and string.find(rc, "RaceFx.cardAt(t, seq.leaderAt, FIN, still)", 1, true) ~= nil, "skippable by any tap; the card on time")
	check(string.find(rc, "if FIN.orbit ~= false and not still", 1, true) ~= nil and string.find(fm, "if still or FIN.confetti == false then return end", 1, true) ~= nil,
		"Reduced Motion: no orbit, no confetti")
	-- The orbit ends on the replay's own rig.
	local rp = code("game/src/client/Replay.client.luau")
	check(string.find(rp, "RaceState.sideRig(", 1, true) ~= nil and string.find(fm, "RaceState.sideRig(", 1, true) ~= nil,
		"the orbit and the replay share one side-view rig")

	-- The results card's words ---------------------------------------------------------------------
	local NEAR_MISS = { "close", "almost", "nearly", "unlucky", "lost", "lose", "beaten", "last" }
	local function kind(text: string, what: string)
		local ok, why = Words.toastOk(text, GameConfig.ui.toastMaxWords)
		check(ok, `{what}: "{text}" ({why})`)
		local lower = string.lower(text)
		for _, w in NEAR_MISS do
			check(string.find(" " .. lower .. " ", "%W" .. w .. "%W") == nil, `{what}: "{text}" has no near-miss word "{w}"`)
		end
	end
	check(ResultsText.headline(1) == "1st! You won!" and ResultsText.headline(2) == "2nd place!"
		and ResultsText.headline(3) == "3rd place!" and ResultsText.headline(4) == "4th place!", "the place headline, 1st to 4th")
	check(ResultsText.headline(8, 2) == "Great riding!" and ResultsText.headline(5, 0) == "Home safe and sound!"
		and ResultsText.headline(6, 3) == "Brilliant riding!", "5th to 8th lead with praise for the ride, not the place")
	check(ResultsText.headline(nil) == "Race done!" and ResultsText.headline(0 / 0) == "Race done!", "a strange place: no number")
	for place = 1, 8 do
		for stars = 0, 3 do kind(ResultsText.headline(place, stars), "headline") end
		for stars = 0, 3 do
			local line = ResultsText.cheer(place, stars, "Comet")
			kind(line, `cheer {place} {stars}`)
			if place <= 4 then
				check(string.find(line, "ribbon", 1, true) ~= nil, `1st-4th get their ribbon ({line})`)
			else
				check(string.find(line, "Comet came " .. place, 1, true) == 1, `5th-8th: the place, kindly, under the praise ({line})`)
			end
		end
	end
	check(ResultsText.cheer(6, nil, nil) == "Your horse came 6th and loved the run!" and ResultsText.cheer(2, 3, "") == "Red ribbon for your horse!",
		"no name, no stars: still kind")
	check(ResultsText.rankLine(1) == "Best ride in the race!" and ResultsText.rankLine(2) == "2nd best ride!"
		and ResultsText.rankLine(3) == "3rd best ride!", "the ride rank lines")
	for _, r in { 4, 5, 8, 0, -1, 1.5 } do
		check(ResultsText.rankLine(r) == "", `rank {r}: nothing (never a leaderboard)`)
	end
	check(ResultsText.rankLine(nil) == "", "no rank: nothing")
	for r = 1, 3 do kind(ResultsText.rankLine(r), "rank line") end
	check(ResultsText.rideRank({ 50, 80, 80, 20 }, 2) == 1 and ResultsText.rideRank({ 50, 80, 80, 20 }, 3) == 1
		and ResultsText.rideRank({ 50, 80, 80, 20 }, 1) == 3 and ResultsText.rideRank({ 50, 80, 80, 20 }, 4) == 4,
		"ride rank: the best score is 1st, equal scores share a rank, bots included")
	check(ResultsText.rideRank({ 50, 0 / 0 }, 2) == nil and ResultsText.rideRank({ 50, 0 / 0 }, 1) == 1, "a strange score never ranks")
	-- Race again: what RACE! joins (Hud's oneTapKind), and it says Practice when it's Practice.
	local energy = GameConfig.energy
	check(ResultsText.nextKind({ energy = 3, league = "Bronze" }, energy) == "race", "a horse with Energy: a race")
	check(ResultsText.nextKind({ energy = 0, league = "Bronze" }, energy) == "practice", "a napping horse: Practice")
	check(ResultsText.nextKind({ energy = 0, league = "Rookie" }, energy) == (if energy.freeLeagues.Rookie then "race" else "practice"),
		"free leagues race at 0 Energy")
	check(ResultsText.nextKind({ overCeiling = true, cupOpen = true }, energy) == "cup"
		and ResultsText.nextKind({ overCeiling = true }, energy) == "practice", "past the ceiling: the Cup, or Practice")
	check(ResultsText.nextKind(nil, energy) == "race", "no horse yet: RACE! decides")
	-- (the systems consult) Napping with no other horse ready: "🌾 Feed Comet" instead of Practice.
	local tired, fresh = { id = "a", name = "Comet", energy = 0, league = "Bronze" }, { id = "b", energy = 4, league = "Bronze" }
	check(ResultsText.nextKind(tired, energy, { tired }, true) == "feed", "napping, nothing else ready: feed")
	check(ResultsText.nextKind(tired, energy, { tired, fresh }, true) == "practice", "another horse is ready: Practice (RACE! as ever)")
	check(ResultsText.nextKind(tired, energy, { tired }, false) == "practice", "feedWhenNapping off: Practice")
	check(ResultsText.nextKind(fresh, energy, { tired, fresh }, true) == "race", "a horse with Energy races")
	check(ResultsText.raceAgainLabel("feed", "Comet") == "🌾 Feed Comet" and ResultsText.raceAgainLabel("feed") == "🌾 Feed your horse",
		"the feed button names the horse")
	check(GameConfig.results.feedWhenNapping == true and string.find(rc, "Card.goStable()", 1, true) ~= nil, "it walks you to the stall")
	-- "Best ride" never beside one star (the gameplay consult).
	check(GameConfig.results.rankMinStars == 2 and string.find(rc, "(rideReport.stars or 0) >= (GameConfig.results.rankMinStars or 0)", 1, true) ~= nil,
		"Best ride only with 2 stars or more")
	local hud = code("game/src/client/Hud.client.luau")
	check(string.find(hud, "if h.overCeiling then return if h.cupOpen then \"cup\" else \"practice\" end", 1, true) ~= nil
		and string.find(hud, "(h.energy or 0) < GameConfig.energy.costPerCashRace and not GameConfig.energy.freeLeagues[h.league or \"Rookie\"]", 1, true) ~= nil,
		"ResultsText.nextKind mirrors the Hud's one-tap rule")
	check(ResultsText.raceAgainLabel("race") == "🏁 Race again" and string.find(ResultsText.raceAgainLabel("practice"), "Practice", 1, true) ~= nil
		and ResultsText.raceAgainLabel(nil) == "🏁 Race again", "Race again says what it joins")
	for _, k in { "race", "practice", "cup", "feed" } do kind(ResultsText.raceAgainLabel(k, "Comet"), "race again") end
	check(GameConfig.results.raceAgain == true and GameConfig.results.riderRank == true, "results: raceAgain and riderRank on")
	check(string.find(rc, "press:Fire()", 1, true) ~= nil and string.find(rc, "PressRace", 1, true) ~= nil,
		"Race again presses RACE! (the same league's line)")
	-- The server sends the rank to the rider alone, only for the top 3.
	local rs = code("game/src/server/RaceService.server.luau")
	check(string.find(rs, "if rank and rank <= 3 then RideRank:FireClient(p, rank, c.id) end", 1, true) ~= nil
		and string.find(rs, "RideRank:FireAllClients", 1, true) == nil, "RideRank: one rider, top 3 only")
	check(string.find(rs, "ResultsText.rideRank(S, i)", 1, true) ~= nil, "ranked from the ride score the server already has")
	-- The card: at the floors (16 px text, 64 px buttons unscaled), under the top bar, no shop door.
	local card = code("game/src/client/ResultsCard.luau")
	check(string.find(card, "Card.TEXT_PX, Card.BUTTON_PX = 16, 64", 1, true) ~= nil
		and string.find(card, "PanelFit.layout(", 1, true) ~= nil and string.find(card, "GuiService:GetGuiInset()", 1, true) ~= nil,
		"the card fits through PanelFit at 16 px / 64 px, clear of the top bar")
	for size in string.gmatch(card, "cardText%((%d+)") do
		check(tonumber(size) :: number >= 16, `card text {size} px >= 16`)
	end
	for size in string.gmatch(card, "Ui%.button%(card, [^\n]-, (%d+)%)\n") do
		check(tonumber(size) :: number >= 16, `card button text {size} px >= 16`)
	end
	check(select(2, string.gsub(card, "UDim2.fromOffset%(thirdW, 64%)", "")) == 3 and string.find(card, "UDim2.new(1, -36, 0, 64)", 1, true) ~= nil,
		"every card button is 64 px high")
	for _, banned in { "Diamond", "💎", "Purchase", "Prompt", "MarketplaceService" } do
		check(string.find(card, banned, 1, true) == nil and string.find(fm, banned, 1, true) == nil, `no {banned} on the card or in the finish moment`)
	end

	-- The race screen speaks the picker's words ("🐇 Short", never "Sprint").
	check(string.find(rc, "PickerText.cardLine(", 1, true) ~= nil, "the race status line uses the picker's words")
	check(string.find(PickerText.cardLine({ league = "Bronze", distance = "Sprint", surface = "Dirt", weather = "Sunny" }), "Sprint", 1, true) == nil,
		"no \"Sprint\" on the race screen")

	-- First-race coaching ----------------------------------------------------------------------------
	check(RaceFx.coached(0, FX) and not RaceFx.coached(1, FX) and RaceFx.coached(nil, FX), "the first race is coached, the second isn't")
	check(not RaceFx.coached(0, { coachRaces = 0 }), "coachRaces = 0: never")
	kind(FX.coachHint, "coach hint")
	kind(FX.coachBurstHint, "burst heads-up")
	check(string.find(FX.coachHint, "once", 1, true) ~= nil and string.find(FX.coachHint, "glow", 1, true) ~= nil,
		"the rule says one tap and names the glow (Gold since D-069, not green)")
	check(FX.coachPasses == 4 and FX.coachHintPasses == 3, "the thumb for 4 passes, the rule for 3")
	local coachSrc = code("game/src/client/RaceCoach.luau")
	check(string.find(coachSrc, "thumb.Text, thumb.AnchorPoint = \"👇\"", 1, true) ~= nil
		and string.find(rc, "Coach.frame(coached, pace, passes,", 1, true) ~= nil, "coaching reuses the steering tip's ghost thumb")
	check(string.find(rc, "Coach.judge(labelText, PaceMeter.position(pass, t))", 1, true) ~= nil, "the tap's word at the marker")
	check(FX.coachNowZone == 0.2 and string.find(coachSrc, "FX.coachNowZone", 1, true) ~= nil, "NOW! uses raceFx.coachNowZone (N12)")

	-- The post-lock pace preview (gameplay consult) ---------------------------------------------------
	local P = GameConfig.pacePreviewAfterLock
	check(P.enabled == true and P.seconds == 1 and P.throughCheckpoint == 2, "pacePreviewAfterLock: every second through checkpoint 2")
	for seg = 1, 4 do
		for closed = 0, 3 do
			check(not PacePreview.afterLock(P, false, seg, closed, false), `before the lock: never (seg {seg})`)
		end
	end
	check(PacePreview.afterLock(P, true, 1, 0, false) and PacePreview.afterLock(P, true, 2, 1, false), "after the lock: the open checkpoint")
	check(not PacePreview.afterLock(P, true, 2, 0, false) and not PacePreview.afterLock(P, true, 2, 2, false), "only the open checkpoint")
	check(not PacePreview.afterLock(P, true, 4, 3, false) and not PacePreview.afterLock(P, true, 4, 3, true), "never the stretch drive (its own preview)")
	check(not PacePreview.afterLock({ enabled = false }, true, 2, 1, false) and not PacePreview.afterLock(nil, true, 2, 1, false), "off: never")
	check(string.find(rs, "PacePreview.afterLock(PREVIEW_AFTER_LOCK, trip.locked, seg, session.closed, false)", 1, true) ~= nil,
		"the server previews only through PacePreview, with the trip's lock")
	check(string.find(rs, "Trip.advance(trip, session.live, t - tStart)", 1, true) ~= nil,
		"the trip (and its tau) steps on session.live, never on the chances shown")

	-- Before the lock, what the screen shows doesn't depend on the chances shown at all.
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local humans = { { id = "1", name = "Ava", rating = 60, isBot = false }, { id = "2", name = "Ben", rating = 55, isBot = false } }
	local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
	local track = TrackLayout.courses.dirt
	local plan = TrackLayout.plan(track, TrackLayout.distances.Mile)
	local function session(seed: number): any
		local s = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
		s:assignPosts(RaceSession.postOrder(GameConfig, 8, makeRng(seed + 17)))
		return s
	end
	local s0 = session(5)
	local trip = Trip.start(GameConfig, s0, track, plan, TripBaseline.dirt.Mile, makeRng(6), TrackLayout)
	Trip.advance(trip, s0.live, 3)
	local skewed = table.clone(s0.live)
	skewed[1], skewed[2] = skewed[2], skewed[1]
	local offA, lanesA = Trip.frame(trip, s0, s0.live, 0, GameConfig.raceShape, 0, 3)
	local offB, lanesB = Trip.frame(trip, s0, skewed, 0, GameConfig.raceShape, 0, 3)
	local same = not trip.locked
	for i = 1, 8 do
		if offA[i] ~= offB[i] or (lanesA :: any)[i] ~= (lanesB :: any)[i] then same = false end
	end
	check(same, "before the lock the screen draws Trip's own state: the chances shown change nothing")

	-- After the lock: previews every second change no score, chance, prize or place.
	local identical, gainsSame = true, true
	for seed = 1, 12 do
		local runs = {}
		for run = 1, 2 do
			local s = session(100 + seed)
			local function score(seg: number)
				for i, lane in s.lanes do
					if not lane.isBot then lane.scores[seg] = 20 + ((seed * 13 + i * 7 + seg * 5) % 80) end
				end
			end
			score(1)
			s:closeSegment(1)
			local tau = {}
			for i = 1, 8 do tau[i] = ((seed + i) % 5 - 2) * 0.01 end
			s:setTrip(tau)
			if run == 2 then -- the preview, as the server runs it: the open checkpoint, partial scores
				for k = 1, 10 do
					local partial = {}
					for i, lane in s.lanes do
						if not lane.isBot then partial[i] = (k * 11 + i * 3) % 100 end
					end
					local shown = s:previewLive(2, partial)
					check(#shown == 8, "a preview gives every horse a chance to show")
				end
			end
			score(2)
			s:closeSegment(2)
			score(3)
			s:closeSegment(3)
			score(4)
			s:closeSegment(4)
			local result = s:finish()
			local gains = {}
			for i = 1, 8 do gains[i] = s:ridingGain(i) .. ":" .. s:tripGain(i) end
			runs[run] = { order = table.concat(result.order, ","), live = table.concat(s.live, ","),
				S = table.concat(s:scoresSoFar(), ","), prizes = result.prizes, gains = table.concat(gains, ",") }
		end
		if runs[1].order ~= runs[2].order or runs[1].live ~= runs[2].live or runs[1].S ~= runs[2].S then identical = false end
		for k, prize in runs[1].prizes do
			local other = runs[2].prizes[k]
			if prize.cash ~= other.cash or prize.place ~= other.place or prize.leaguePoints ~= other.leaguePoints then identical = false end
		end
		if runs[1].gains ~= runs[2].gains then gainsSame = false end
	end
	check(identical, "post-lock previews leave every score, chance, place and prize as they were")
	check(gainsSame, "...and the ride and trip gains on the results card")
	-- Phase 2 fixes ------------------------------------------------------------------------------
	-- B1: previews are marked, and the cheer window closes only on checkpoint 1's real close.
	check(string.find(rs, "LiveChances:FireAllClients(seg, shownLive, c.id, true)", 1, true) ~= nil, "a preview's LiveChances says so")
	local fan = code("game/src/client/FanClient.client.luau")
	check(string.find(fan, "remotes.LiveChances.OnClientEvent:Connect(function(seg, _live, courseId, preview)", 1, true) ~= nil
		and string.find(fan, "if preview == true then return end", 1, true) ~= nil, "FanClient never closes the cheer strip on a preview")
	-- The chance arrow: checkpoint closes only (hud.arrowOnPreview off), so it doesn't flicker.
	local HUD = GameConfig.hud
	check(HUD.arrowOnPreview == false, "no arrow on previews")
	check(RaceFx.arrowShows(0.004, false, 0, HUD) and not RaceFx.arrowShows(0.002, false, 0, HUD), "a checkpoint close: any real change")
	check(not RaceFx.arrowShows(0.5, true, 99, HUD), "a preview: never, with arrowOnPreview off")
	local on = { arrowOnPreview = true, arrowPreviewMinChange = 0.01, arrowPreviewEverySeconds = 3 }
	check(RaceFx.arrowShows(0.02, true, 3, on) and not RaceFx.arrowShows(0.02, true, 2.9, on) and not RaceFx.arrowShows(0.009, true, 9, on),
		"with arrows on previews: over 0.01, at least 3 s apart")
	check(not RaceFx.arrowShows(0 / 0, false, 0, HUD), "a strange change never shows")
	check(string.find(rc, "RaceFx.arrowShows(live[i] - from[i], preview == true, since, HUD)", 1, true) ~= nil, "the badge arrow uses the rule")
	-- A reflex tap never skips the finish moment (the feel consult).
	check(FIN.skipAfterSeconds == 1.0 and string.find(rc, "if serverNow() - (seq.crossAt or 0) < (FIN.skipAfterSeconds or 0) then return end", 1, true) ~= nil,
		"no skip in the first second after the crossing")
	-- The stamp sits clear of your horse and scales with the HUD; its own sound; YOU hides in the orbit.
	check(FIN.stampAt[1] <= 0.34 and FIN.stampAt[2] <= 0.34, "the stamp in the upper-left third")
	check(string.find(fm, "RaceState.hudScale()", 1, true) ~= nil and string.find(fm, "Sound.play(\"job_done\"", 1, true) ~= nil
		and string.find(fm, "\"ui_pop\"", 1, true) == nil, "the stamp scales with the HUD and has its own sound")
	check(string.find(rc, "Finish.hideYou(horse)", 1, true) ~= nil and string.find(fm, "hiddenYou.Enabled = true", 1, true) ~= nil,
		"the YOU marker hides in the orbit and comes back")
	check(string.find(fm, "if place >= 3 then INK", 1, true) ~= nil, "ink on the yellow and white ribbons (N6)")
	-- N4: the Reduced Motion dim never stays up without the card; a warm Ink tint, not black.
	check(string.find(rc, "if not results.Visible then Card.dim.Visible = false end", 1, true) ~= nil, "the dim goes with the moment")
	check(FIN.dim >= 0.7 and string.find(card, "dim.BackgroundColor3 = Ui.colors.ink", 1, true) ~= nil, "a light Ink dim")
	-- Two columns on a short landscape screen: the whole card without scrolling (the UI/UX consult).
	local PanelFit = require("../../game/src/shared/PanelFit")
	check(GameConfig.results.twoColumnBelowPx == 500 and GameConfig.results.cardWideW == 720, "two columns under 500 px, 720 wide")
	local leftH = 18 + 70 + 6 + 28 + 28 + 34 + 26 + 8 + 64 + 18 -- headline, cheer, best ride, stars, a gain line, Race again
	local rightH = 18 + 5 * 32 + 12 + 64 + 18 -- five places, the replay and Done row
	for _, phone in { { 667, 375 }, { 844, 390 }, { 736, 414 } } do
		local inset = 36 + 6
		local fit = PanelFit.layout(phone[1], phone[2] - inset, 720, math.max(leftH, rightH), 16, 64, GameConfig.ui)
		check(not fit.scroll and not fit.scrollX, `two columns fit {phone[1]}x{phone[2]} under the top bar without scrolling`)
	end
	check(string.find(card, "v.Y < (RESULTS.twoColumnBelowPx or 0) and scrolls(width, height)", 1, true) ~= nil,
		"the card picks two columns only when one would scroll")
	-- The Starter's Next shows whole on a short phone (the UI/UX consult).
	local starter = code("game/src/client/Starter.client.luau")
	check(string.find(starter, "local W, H = 720, if COMPACT then 404 else 470", 1, true) ~= nil
		and string.find(starter, "local VP = if COMPACT then 104 else 150", 1, true) ~= nil, "the compact Starter")
	local sfit = PanelFit.layout(667, 375, 720, 404, 18, 64, GameConfig.ui)
	check(not sfit.scroll, "404 px fits a 375 px phone unscrolled (Next at its foot)")
	-- N9: RaceController keeps room for more locals (tests/test_compile_all.py checks >= 30).
	check(string.find(rc, "require(script.Parent:WaitForChild(\"RaceCamera\"))", 1, true) ~= nil
		and string.find(rc, "require(script.Parent:WaitForChild(\"RaceCoach\"))", 1, true) ~= nil, "camera and coaching moved out")

end
