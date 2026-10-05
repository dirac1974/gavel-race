--!strict
-- Ghost (D-053, T4): a training ride's path, small enough to keep: the server's validated
-- samples resampled at `hz` (4 a second), quantised to `q` studs (0.5), at most `max` points
-- (480 = 120 s, the longest a ride can run), delta-encoded as base64url varints in one string.
--   fromSamples(samples, hz?, max?) -> points { {x, y, z} } at 0, 1/hz, 2/hz, ...
--   encode(points, hz?, q?) -> { v, hz, q, n, d }       decode(g) -> points
--   at(points, hz, t) -> x, y, z, facing x, facing z   (nil after the end)
--   better(a, b): is run a better than run b (score, then time)?
--   mergeStore(old, mine): what to save (keeps anything this version doesn't understand)
--   loadRuns(runs, courses, aliases): what a load keeps (old course keys count for new ones)
-- Pure, tested under Lune.

local Ghost = {}

Ghost.HZ = 4
Ghost.Q = 0.5
Ghost.MAX = 480
Ghost.VERSION = 1

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local INDEX: { [string]: number } = {}
for i = 1, #ALPHABET do INDEX[string.sub(ALPHABET, i, i)] = i - 1 end

local function zigzag(n: number): number
	return if n >= 0 then n * 2 else -n * 2 - 1
end

local function unzig(z: number): number
	return if z % 2 == 0 then z // 2 else -(z + 1) // 2
end

-- 5 data bits per character, the 6th says "more follows".
local function putVarint(out: { string }, n: number)
	local z = zigzag(n)
	repeat
		local chunk = z % 32
		z = z // 32
		if z > 0 then chunk += 32 end
		table.insert(out, string.sub(ALPHABET, chunk + 1, chunk + 1))
	until z == 0
end

function Ghost.fromSamples(samples: { any }, hz: number?, max: number?): { any }
	local rate, limit = hz or Ghost.HZ, max or Ghost.MAX
	local out = {}
	if #samples == 0 then return out end
	local t0 = samples[1].t
	local j = 1
	for k = 0, limit - 1 do
		local t = t0 + k / rate
		if t > samples[#samples].t + 1e-9 then break end
		while j < #samples and samples[j + 1].t < t do j += 1 end
		local a, b = samples[j], samples[math.min(j + 1, #samples)]
		local f = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0
		table.insert(out, { x = a.x + (b.x - a.x) * f, y = (a.y or 0) + ((b.y or 0) - (a.y or 0)) * f, z = a.z + (b.z - a.z) * f })
	end
	return out
end

function Ghost.encode(points: { any }, hz: number?, q: number?)
	local quantum = q or Ghost.Q
	local out = {}
	local px, py, pz = 0, 0, 0
	for _, p in points do
		local ix = math.floor(p.x / quantum + 0.5)
		local iy = math.floor(p.y / quantum + 0.5)
		local iz = math.floor(p.z / quantum + 0.5)
		putVarint(out, ix - px)
		putVarint(out, iy - py)
		putVarint(out, iz - pz)
		px, py, pz = ix, iy, iz
	end
	return { v = Ghost.VERSION, hz = hz or Ghost.HZ, q = quantum, n = #points, d = table.concat(out) }
end

-- Returns nil for anything that isn't a well-formed ghost.
function Ghost.decode(g: any): { any }?
	if typeof(g) ~= "table" or typeof(g.d) ~= "string" or typeof(g.n) ~= "number" or typeof(g.q) ~= "number" or g.q <= 0 then
		return nil
	end
	local s, n, q = g.d, g.n, g.q
	if n > Ghost.MAX or n < 0 then return nil end
	local pos, len = 1, #s
	local function read(): number?
		local z, mult = 0, 1
		while true do
			if pos > len then return nil end
			local v = INDEX[string.sub(s, pos, pos)]
			if v == nil then return nil end
			pos += 1
			z += (v % 32) * mult
			mult *= 32
			if v < 32 then return unzig(z) end
			if mult > 2 ^ 40 then return nil end
		end
	end
	local out = {}
	local ix, iy, iz = 0, 0, 0
	for _ = 1, n do
		local dx, dy, dz = read(), read(), read()
		if not dx or not dy or not dz then return nil end
		ix, iy, iz = ix + dx, iy + dy, iz + dz
		table.insert(out, { x = ix * q, y = iy * q, z = iz * q })
	end
	return out
end

-- Position at t seconds into the ghost's ride (and which way it's going), or nil past the end.
function Ghost.at(points: { any }, hz: number, t: number): (number?, number?, number?, number?, number?)
	if #points == 0 or t < 0 then return nil end
	local f = t * hz
	local i = math.floor(f) + 1
	if i >= #points then
		if i > #points then return nil end
		local p = points[#points]
		return p.x, p.y, p.z, nil, nil
	end
	local a, b = points[i], points[i + 1]
	local u = f - (i - 1)
	return a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u, a.z + (b.z - a.z) * u, b.x - a.x, b.z - a.z
end

function Ghost.better(a: any, b: any?): boolean
	if not b then return true end
	if a.score ~= b.score then return a.score > b.score end
	return (a.seconds or math.huge) < (b.seconds or math.huge)
end

-- Can this version read (and so replace) a stored run?
function Ghost.readable(run: any): boolean
	return typeof(run) == "table" and (tonumber(run.v) or 1) <= Ghost.VERSION and typeof(run.score) == "number"
		and typeof(run.seconds) == "number" and Ghost.decode(run) ~= nil
end

-- The runs a load keeps in memory: well-formed runs on courses this version rides. A run under
-- an old key (`aliases`: T2-T4 saved Mud Splash as "grit", which is layout grit_w1 now) counts
-- for its new key when it's the better one. The stored record isn't changed by this: mergeStore
-- passes the old key through, and the run is written under its new key with the next save.
function Ghost.loadRuns(runs: any, courses: { [string]: boolean }, aliases: { [string]: string }?): { [string]: any }
	local out = {}
	if typeof(runs) ~= "table" then return out end
	for course, run in runs do
		local key = if courses[course] then course elseif aliases and typeof(course) == "string" then aliases[course] else nil
		if key and courses[key] and typeof(run) == "table" and typeof(run.score) == "number" and typeof(run.seconds) == "number"
			and Ghost.decode(run) ~= nil and Ghost.better(run, out[key]) then
			out[key] = run
		end
	end
	return out
end

-- A saved ghost record with my runs merged in: a stored run is replaced only if this version
-- can read it and mine is better. Anything else (newer encodings, courses or keys this version
-- doesn't know) is passed through untouched, so an older server never erases newer ghosts.
function Ghost.mergeStore(old: any, mine: { [string]: any }): any
	local value = if typeof(old) == "table" then table.clone(old) else {}
	local runs = if typeof(value.runs) == "table" then table.clone(value.runs) else {}
	for course, run in mine do
		local stored = runs[course]
		if stored == nil or (Ghost.readable(stored) and Ghost.better(run, stored)) then runs[course] = run end
	end
	value.runs = runs
	value.v = math.max(tonumber(value.v) or 1, 1)
	return value
end

return Ghost
