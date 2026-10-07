--!strict
-- Your lines on the results card (D-033, D-054 S4, D-064), pure so tests can read every wording.
-- One row (D-064): "You rode ★★☆", the trip folded into the same stars, then "Your taps gained
-- Comet 2 places!" only when it's a real gain (never a lost place, never a strange number). The
-- trip only counts with steering that counts (scale ≠ 0) and the ◀ ▶ buttons (1 to 3 trip stars).

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

-- Trip stars that count: 1, 2 or 3 with steering that counts; nil otherwise (no buttons, steering
-- off or cosmetic, a strange value).
function ResultsText.tripStars(tripStars: number?, scale: number?): number?
	if scale == 0 or not finite(tripStars) then return nil end
	local n = tripStars :: number
	if n ~= 1 and n ~= 2 and n ~= 3 then return nil end
	return n
end

-- The stars on the one row: the ride's, or with a trip that counts, the ride and the trip
-- together (their average, halves rounded up).
function ResultsText.rowStars(stars: number, tripStars: number?, scale: number?): number
	local ride = if finite(stars) then math.clamp(math.floor(stars), 0, 3) else 0
	local trip = ResultsText.tripStars(tripStars, scale)
	if not trip then return ride end
	return math.clamp(math.floor((ride + trip) / 2 + 0.5), 0, 3)
end

-- The one row: "You rode ★★☆".
function ResultsText.oneRow(stars: number, tripStars: number?, scale: number?): string
	return ResultsText.rideLine(ResultsText.rowStars(stars, tripStars, scale))
end

local function places(v: number?): number
	if not finite(v) or (v :: number) < 1 then return 0 end
	return math.floor(v :: number)
end

-- "Your taps gained Comet 2 places!", only for a gain of at least one place ("" otherwise). With a
-- trip that counts and gained places too: "Your taps and steering gained Comet 3 places!" (or "Your
-- steering gained …" when only the trip gained). A loss is never added in or shown.
function ResultsText.gainedLine(horse: string, gain: number?, tripGain: number?, scale: number?): string
	local taps = places(gain)
	local trip = if scale == 0 then 0 else places(tripGain)
	local n = taps + trip
	if n < 1 then return "" end
	local who = if taps > 0 and trip > 0 then "taps and steering" elseif trip > 0 then "steering" else "taps"
	local name = if type(horse) == "string" and horse ~= "" then horse else "your horse"
	return string.format("Your %s gained %s %d place%s!", who, name, n, if n == 1 then "" else "s")
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
