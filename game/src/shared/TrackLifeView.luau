--!strict
-- TrackLifeView (AAA Phase 4, D-069): the pure parts of client/TrackLife, tested under Lune.
--   Big Board rows: the followed race's top places from RaceState.order (place -> lane) with each
--   lane's horse name. Only places, lane numbers and names: never a win %, a purse or a prize
--   (rule 1, D-055).
--   Crowd bounce and flag flutter: small sines, calm in the lobby and cheering from the burst.

local TrackLifeView = {}

-- Lane colours (docs/art/ART_DIRECTION.md, the colour-blind-safe set); dark numbers on the light ones.
TrackLifeView.LANE_HEX = { "D55E00", "56B4E9", "F0E442", "009E73", "CC79A7", "E69F00", "0072B2", "3A3F4B" }
TrackLifeView.LIGHT_LANES = { [2] = true, [3] = true, [6] = true }
TrackLifeView.NAME_MAX = 18
TrackLifeView.IDLE_TITLE = "GIDDY-UP!"
TrackLifeView.LIVE_TITLE = "🏁 Top 4"

export type Row = { place: number, lane: number, name: string }

local SUFFIX = { "st", "nd", "rd" }
function TrackLifeView.ordinal(n: number): string
	local teen = n % 100 >= 11 and n % 100 <= 13
	return tostring(n) .. (if not teen and SUFFIX[n % 10] then SUFFIX[n % 10] else "th")
end

-- A name short enough for the board.
function TrackLifeView.shortName(name: string?): string
	local s = if type(name) == "string" and name ~= "" then name else "Horse"
	if utf8.len(s) and (utf8.len(s) :: number) > TrackLifeView.NAME_MAX then
		local cut = utf8.offset(s, TrackLifeView.NAME_MAX)
		s = string.sub(s, 1, (cut or #s + 1) - 1) .. "…"
	end
	return s
end

-- The top `n` places: rows[k] = { place, lane, name }, reusing `rows`' tables. Returns how many.
function TrackLifeView.boardRows(order: { number }, names: { string }?, n: number, rows: { Row }): number
	local count = 0
	for place = 1, n do
		local lane = order[place]
		if lane == nil then break end
		count += 1
		local row = rows[count]
		if not row then
			row = { place = 0, lane = 0, name = "" }
			rows[count] = row
		end
		row.place, row.lane = place, lane
		row.name = TrackLifeView.shortName(names and names[lane])
	end
	return count
end

-- What the board says for a row (the lane number is drawn on its own chip).
function TrackLifeView.rowText(row: Row): string
	return TrackLifeView.ordinal(row.place) .. "  " .. row.name
end

-- "cheer" from the burst (or once the leader is past cheerFromProgress) until the results card shows;
-- "calm" otherwise (the lobby, the early race, no race).
export type LifeState = { active: boolean, burstShowing: boolean, resultsOpen: boolean, leaderProgress: number }
function TrackLifeView.crowdMode(s: LifeState, L): string
	if not s.active or s.resultsOpen then return "calm" end
	if s.burstShowing or s.leaderProgress >= L.cheerFromProgress then return "cheer" end
	return "calm"
end

-- The crowd's vertical offset (studs) at time t for a riser row; 0 under Reduced Motion.
function TrackLifeView.crowdOffset(t: number, mode: string, L, row: number, still: boolean): number
	if still or not L.crowdBounce then return 0 end
	local amp = if mode == "cheer" then L.cheerStuds else L.calmStuds
	local hz = if mode == "cheer" then L.cheerHz else L.calmHz
	return amp * math.sin(2 * math.pi * hz * t + row * 0.9)
end

-- A flag's flutter (radians of yaw) at time t; 0 under Reduced Motion.
function TrackLifeView.flagYaw(t: number, L, i: number, still: boolean): number
	if still or not L.flagFlutter then return 0 end
	return math.rad(L.flutterDeg) * math.sin(2 * math.pi * L.flutterHz * t + i * 1.3)
end

return TrackLifeView
