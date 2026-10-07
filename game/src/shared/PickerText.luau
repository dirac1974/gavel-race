--!strict
-- PickerText (D-064, stage 3): the race picker's words, pure so tests can read them. A race card
-- is one line of at most ui.pickerLineWords words (the league is the card's colour and badge), a
-- short status chip, and a horse card says how today's race suits it in a few words, never a
-- number.

local PickerText = {}

PickerText.DIST_WORD = { Sprint = "Short", Mile = "Mile", Classic = "Long", Marathon = "Longest" }
PickerText.DIST_EMOJI = { Sprint = "🐇", Mile = "🏇", Classic = "🛤️", Marathon = "🛤️" } -- 🐇 Short (D-064: ⚡ looked like Energy)
PickerText.WEATHER_EMOJI = { Sunny = "☀️", Rain = "🌧️", Wind = "🌬️" }

-- "Bronze Cup · 🐇 Short · Dirt ☀️"
function PickerText.cardLine(c: any): string
	local kind = if c.cup then (c.league or "") .. " Cup" elseif c.practice then "Practice"
		elseif c.open then "Open" else (c.league or "Race")
	local dist = (PickerText.DIST_EMOJI[c.distance] or "🏇") .. " " .. (PickerText.DIST_WORD[c.distance] or "Race")
	local surface = if c.course == "turf" or c.surface == "Turf" then "Turf" else "Dirt"
	return string.format("%s · %s · %s %s", kind, dist, surface, PickerText.WEATHER_EMOJI[c.weather] or "")
end

-- The status chip: one or two words.
function PickerText.status(c: any, watch: boolean): string
	if watch then return "👀 Watch" end
	if c.racing then return "🏇 Racing now" end
	if c.seconds then return string.format("⏱ %ds", c.seconds) end
	if (c.riders or 0) > 0 then return "Filling up" end
	return "Be first!"
end

-- How today's race suits a horse (its Rating today minus its average), in words only.
function PickerText.suits(diff: number?, napping: boolean): string
	if napping then return "😴 Napping" end
	if not diff or diff ~= diff then return "" end
	if diff > 0.5 then return "👍 Loves this race" end
	if diff < -0.5 then return "Not its best" end
	return "An okay day"
end

-- A horse's class badge (D-062): icon + word, a label only (one queue per league, no demotion).
PickerText.CLASS_BADGE = {
	FirstWin = "🐣 First Win", RisingStar = "🚀 Rising Star", Open = "🎽 Open class", Cup = "🏆 Cup",
}
function PickerText.classBadge(class: string?): string
	return PickerText.CLASS_BADGE[class or ""] or ""
end

return PickerText
