--!strict
-- Your lines on the results card (D-033, D-054 S4), pure so tests can read every wording. Stars
-- need no reading; gains show only when they're gains (never a lost place); the trip line only
-- with steering and the ◀ ▶ buttons, and never with zero stars.

local ResultsText = {}

-- Three star slots, filled n (0..3).
function ResultsText.stars(n: number): string
	local k = math.clamp(math.floor(n), 0, 3)
	return string.rep("★", k) .. string.rep("☆", 3 - k)
end

function ResultsText.rideLine(stars: number): string
	return "You rode " .. ResultsText.stars(stars)
end

-- "Good trip ★★☆" (1 to 3 stars, from Trip.stars); "" when there's no trip line.
function ResultsText.tripLine(tripStars: number?): string
	if type(tripStars) ~= "number" then return "" end
	return "Good trip " .. ResultsText.stars(math.clamp(tripStars, 1, 3))
end

-- "Your riding gained you 2 places!" / "Your trip gained you 1 place!", only for a gain.
function ResultsText.gainLine(what: string, gain: number?): string
	if type(gain) ~= "number" or gain < 1 then return "" end
	local n = math.floor(gain)
	return string.format("Your %s gained you %d place%s!", what, n, if n == 1 then "" else "s")
end

-- RideReport's arguments: (stars, gain, place, course), or with steering and the buttons
-- (stars, gain, place, trip stars, places the trip gained, course). The course id is last.
function ResultsText.rideReport(stars: any, gain: any, place: any, a: any, b: any): { [string]: any }
	local report = { stars = stars, gain = gain, place = place }
	if type(a) == "number" then report.tripStars, report.tripGain = a, b end
	return report
end

return ResultsText
