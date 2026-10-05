--!strict
-- Your lines on the results card (D-033, D-054 S4), pure so tests can read every wording. Stars
-- need no reading; gains show only when they're real gains (never a lost place, never a strange
-- number); the trip line only with steering that counts and the ◀ ▶ buttons, and only with one to
-- three stars.

local ResultsText = {}

local function finite(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

-- Three star slots, filled n (0..3; anything else counts as none).
function ResultsText.stars(n: number): string
	local k = if finite(n) then math.clamp(math.floor(n), 0, 3) else 0
	return string.rep("★", k) .. string.rep("☆", 3 - k)
end

function ResultsText.rideLine(stars: number): string
	return "You rode " .. ResultsText.stars(stars)
end

-- "Good trip ★★☆" for 1 to 3 trip stars (Trip.stars); nil when there's no trip line: no trip
-- stars (steering off, or a rider without the buttons), a value that isn't 1, 2 or 3, or steering
-- that doesn't count (scale 0: lanes move, chances don't).
function ResultsText.tripLine(tripStars: number?, scale: number?): string?
	if scale == 0 or not finite(tripStars) then return nil end
	local n = tripStars :: number
	if n ~= 1 and n ~= 2 and n ~= 3 then return nil end
	return "Good trip " .. ResultsText.stars(n)
end

-- "Your riding gained you 2 places!" / "Your trip gained you 1 place!", only for a gain of at least
-- one place ("" for nil, zero, a loss, NaN or infinity).
function ResultsText.gainLine(what: string, gain: number?): string
	if not finite(gain) or (gain :: number) < 1 then return "" end
	local n = math.floor(gain :: number)
	return string.format("Your %s gained you %d place%s!", what, n, if n == 1 then "" else "s")
end

-- RideReport's arguments, built by RaceService: (stars, gain, place, course), or for a rider who had
-- the steering buttons (stars, gain, place, trip stars, places the trip gained, course). The course
-- id is always last.
function ResultsText.reportArgs(stars: number, gain: number, place: number, course: string, tripStars: number?, tripGain: number?): { any }
	if tripStars ~= nil then return { stars, gain, place, tripStars, tripGain or 0, course } end
	return { stars, gain, place, course }
end

-- ...and read back on the client.
function ResultsText.rideReport(stars: any, gain: any, place: any, a: any, b: any): { [string]: any }
	local report = { stars = stars, gain = gain, place = place }
	if type(a) == "number" then report.tripStars, report.tripGain = a, b end
	return report
end

return ResultsText
