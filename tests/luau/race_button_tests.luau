--!strict
-- Stage 2 of docs/plans/horse-life-and-retention.md (D-061): league-anchored bots named from the
-- horse-name chips, and the queue card's state from the server's queue events (QueueView).
local RaceSession = require("../../game/src/shared/RaceSession")
local QueueView = require("../../game/src/shared/QueueView")
local NameGen = require("../../game/src/shared/NameGen")
local ThemePack = require("../../game/src/shared/ThemePack")
local GameConfig = require("../../game/src/shared/GameConfig")

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Bots by league -----------------------------------------------------------------
	do
		local A = GameConfig.botRatingAnchor
		check(A ~= nil and GameConfig.botRatingSpread == 6, "botRatingAnchor set, spread 6")
		for _, league in GameConfig.leagueOrder do
			check(A[league] ~= nil, "an anchor for " .. league)
		end
		check(A.Rookie < A.Bronze and A.Bronze < A.Silver and A.Silver < A.Gold and A.Gold < A.Champion,
			"anchors rise with the league")
		local inBand, named, unique, notHuman, pattern, words = true, true, true, true, true, true
		local lo, hi = math.huge, -math.huge
		for _, league in GameConfig.leagueOrder do
			for seed = 1, 150 do
				-- Humans far from the anchor: the bots don't follow them.
				local humans = {}
				for k = 1, (seed % 4) do
					table.insert(humans, { id = tostring(k), name = if k == 1 then "Lucky Star" else "Comet " .. k, rating = 20 + seed % 70, isBot = false })
				end
				local field = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, makeRng(seed),
					{ league = league, nameParts = NameGen })
				if #field ~= GameConfig.lanes then inBand = false end
				local seen = {}
				for _, l in field do
					if seen[l.name] then unique = false end
					seen[l.name] = true
					if l.isBot then
						local off = l.rating - A[league]
						if math.abs(off) > GameConfig.botRatingSpread + 1e-9 then inBand = false end
						if league == "Rookie" then lo, hi = math.min(lo, off), math.max(hi, off) end
						if string.find(l.name, "^[A-Za-z]+[0-9_][0-9_]") then pattern = false end
						if string.find(l.name, "[0-9_]") then pattern = false end
						if l.name == "" then named = false end
						for _, h in humans do if h.name == l.name then notHuman = false end end
						-- Every word is a horse-name chip.
						local first, second = string.match(l.name, "^(%a+) (%a+)$")
						if first then
							if not table.find(NameGen.FIRST, first) or not table.find(NameGen.SECOND, second) then words = false end
						elseif not table.find(NameGen.FIRST, l.name) then
							words = false
						end
					end
				end
			end
		end
		check(inBand, "every bot is rated within its league's anchor ± 6, whatever the humans' ratings")
		check(lo < -4 and hi > 4, "bots spread across the band (not all on the anchor)")
		check(named and pattern, "bot names never look like usernames (^[A-Za-z]+[0-9_]{2,}) and have no digits")
		check(words, "bot names are built from NameGen's horse-name chips")
		check(unique and notHuman, "no two horses in a race share a name")

		-- Without a league (tools, old callers): rated around the humans' median, as before.
		local humans = { { id = "1", name = "Ava", rating = 60, isBot = false }, { id = "2", name = "Ben", rating = 55, isBot = false } }
		local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
		local ok = true
		for _, l in field do
			if l.isBot and math.abs(l.rating - 55) > GameConfig.botRatingSpread + 1e-9 then ok = false end
		end
		check(ok, "no league: bots stay around the human median (unchanged)")
		-- A league with no anchor falls back to the median too.
		local cfg = table.clone(GameConfig)
		cfg.botRatingAnchor = nil
		local f2 = RaceSession.fillWithBots(humans, 8, cfg, ThemePack, makeRng(2), { league = "Rookie" })
		ok = true
		for _, l in f2 do
			if l.isBot and math.abs(l.rating - 55) > cfg.botRatingSpread + 1e-9 then ok = false end
		end
		check(ok, "botRatingAnchor = nil restores the median bots")
	end

	-- The queue card from server events ------------------------------------------------
	do
		local LANES, TOTAL = GameConfig.lanes, GameConfig.lobbyFillSeconds
		check(TOTAL == 15 and GameConfig.queueCard.oneTapRace == true and GameConfig.queueCard.raceTimeSeconds == 3,
			"queue card config: 15 s fill, one-tap RACE!, 3 s race-time call")
		local s = QueueView.new(LANES, TOTAL)
		local me = 42
		check(QueueView.view(s, me, 0).phase == "hidden", "not in line: no card")

		-- Waiting in the league line (no course yet).
		QueueView.status(s, true, 1, nil, nil, 0)
		QueueView.gate(s, nil, { { name = "Comet", coat = "bay", user = me } }, LANES, nil, false, 0)
		local v = QueueView.view(s, me, 0)
		check(v.phase == "waiting" and v.seconds == nil and v.showLeave, "league line: waiting, no countdown, can leave")
		check(v.slots[1].filled and v.slots[1].you and v.slots[1].name == "Comet", "your horse fills the first slot")
		check(#v.slots == LANES and not v.slots[2].filled, "eight slots, the rest open")

		-- On a course whose race is running: you race next.
		QueueView.status(s, true, 1, nil, "dirt", 1)
		QueueView.gate(s, "dirt", { { name = "Comet", coat = "bay", user = me } }, LANES, nil, true, 1)
		check(QueueView.view(s, me, 1).phase == "next", "course racing: you race next")

		-- The countdown: ring full at 15 s, half at 7.5 s; slots fill as riders join.
		QueueView.gate(s, "dirt", { { name = "Comet", coat = "bay", user = me } }, LANES, TOTAL, false, 10)
		v = QueueView.view(s, me, 10)
		check(v.phase == "countdown" and v.seconds == TOTAL and math.abs(v.ring - 1) < 1e-9, "countdown starts at 15 with a full ring")
		check(string.find(v.subtitle, "Bots join at 0") ~= nil, "it says Bots join at 0")
		QueueView.gate(s, "dirt", {
			{ name = "Comet", coat = "bay", user = me },
			{ name = "Lucky Star", coat = "grey", user = 7 },
		}, LANES, 8, false, 17)
		v = QueueView.view(s, me, 17.5)
		check(v.seconds == 8 and math.abs(v.ring - 7.5 / TOTAL) < 0.01, "the ring empties with the time left (smooth between updates)")
		check(v.slots[2].filled and v.slots[2].name == "Lucky Star" and v.slots[2].coat == "grey" and not v.slots[2].you,
			"another rider's horse name and coat in the next slot")
		-- A server update within a second of the local deadline keeps the smooth clock.
		QueueView.status(s, true, 2, 7, "dirt", 18.2)
		check(math.abs(QueueView.view(s, me, 18.2).ring - 6.8 / TOTAL) < 0.01, "whole-second updates don't make the ring jump")
		check(QueueView.view(s, me, 30).seconds == 0, "the number stops at 0")

		-- A full gate says so instead of bots.
		local full = {}
		for k = 1, LANES do table.insert(full, { name = "Horse" .. string.rep("a", k), coat = "bay", user = k }) end
		QueueView.gate(s, "dirt", full, LANES, 5, false, 20)
		check(string.find(QueueView.view(s, me, 20).subtitle, "Full gate") ~= nil, "a full gate: no bots line")

		-- Race time: shows for 3 s even after the server takes you out of the line to race.
		QueueView.raceTime(s, "dirt", 3, 25)
		QueueView.status(s, false, 0, nil, "dirt", 25.1)
		v = QueueView.view(s, me, 26)
		check(v.phase == "racetime" and v.title == "Race time!" and not v.showLeave, "Race time! when the gate fills")
		check(QueueView.view(s, me, 28.1).phase == "hidden", "then the card goes")

		-- Leaving the line hides the card and empties the gate.
		local s2 = QueueView.new(LANES, TOTAL)
		QueueView.status(s2, true, 1, 12, "turf", 0)
		QueueView.gate(s2, "turf", { { name = "Comet", coat = "bay", user = me } }, LANES, 12, false, 0)
		QueueView.status(s2, false, 0, nil, "turf", 1)
		check(QueueView.view(s2, me, 1).phase == "hidden" and #s2.riders == 0, "leaving: no card, gate cleared")
		-- Your race starting clears it at once.
		QueueView.status(s2, true, 1, 12, "turf", 2)
		QueueView.raceTime(s2, "turf", 3, 3)
		QueueView.clear(s2)
		check(QueueView.view(s2, me, 3.5).phase == "hidden", "seated in the race: the card goes")
	end
end
