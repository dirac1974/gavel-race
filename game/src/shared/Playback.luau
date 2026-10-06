--!strict
-- Playback (D-057 N3): the screen's clock for the server's steering samples (RaceOffsets: offsets
-- and lanes, stamped with the server time they were made). RaceView draws the race at a playback
-- time a little behind the newest sample and interpolates between the two samples around it, by
-- their server timestamps, never by when they arrived. A sample that arrives late or early (a
-- jittery link) then changes nothing on screen: every glide takes exactly as long as it did on the
-- server, so the S-curve keeps its shape and no horse stalls or lurches. Pure, so the overlap
-- report (tests/luau/race_overlap.luau) draws races with this same code.
--
-- The delay behind the newest sample: the longest recent lag (arrival minus stamp: the link's
-- one-way latency, its jitter and the clock estimate's error), plus one send interval, plus a
-- margin. A later sample than any before raises it at once; it falls back slowly. The playback
-- clock never jumps: it runs at most `slew` faster or slower than real time to reach a new delay,
-- and changes that rate gradually, so drawn speeds change by a few percent at most (a held horse
-- drawn at 19 ft/s stays under the 20 ft/s jerk line). If a sample is missing when its turn comes
-- (a dropped packet), the screen holds the newest sample and waits for the next instead of
-- guessing ahead, so nothing is ever drawn going back.
--
-- Times are in any one clock (RaceView: workspace:GetServerTimeNow(); the overlap report: race
-- time). Samples are pushed in arrival order; one older than the newest (an unreliable packet
-- overtaken by a later one) is dropped whole, its lanes too. The lag is measured once a frame, from
-- the newest sample that arrived since the last frame: after a client freeze every queued packet
-- arrives at once, and only the newest of them says how late the link really is.

export type Config = {
	interval: number,          -- the server's send interval (1 / steering.sendHz)
	margin: number,            -- extra delay (s): the server's late ticks and a frame
	slew: number,              -- the clock runs at most this much faster or slower than real time
	rateChangePerSecond: number, -- ...and its rate changes at most this fast
	lagReleasePerSecond: number, -- the lag estimate falls back this fast (s per s)
	gain: number,              -- rate change per second of delay error (1/s)
}
export type Sample = { T: number, data: any }
export type Buffer = {
	cfg: Config,
	samples: { Sample },
	delay: number?,  -- now - play
	lag: number?,    -- the lag estimate (fast up, slow down)
	lastLag: number, -- the newest sample's own lag
	fresh: number?,  -- arrival time of the newest sample, until the next advance measures its lag
	rate: number,    -- the playback clock's rate (1 = real time)
	play: number?,   -- the last playback time returned by advance
	held: boolean,   -- the last advance had no sample after the playback time (holding the newest)
}

local Playback = {}

-- From GameConfig: Playback.config(GameConfig) for a race's buffer.
function Playback.config(gameConfig: any): Config
	local pb = gameConfig.raceView.playback
	return {
		interval = 1 / gameConfig.steering.sendHz, margin = pb.marginSeconds, slew = pb.slew,
		rateChangePerSecond = pb.rateChangePerSecond, lagReleasePerSecond = pb.lagReleasePerSecond, gain = pb.gain,
	}
end

function Playback.new(cfg: Config): Buffer
	return { cfg = cfg, samples = {}, delay = nil, lag = nil, lastLag = 0, fresh = nil, rate = 1, play = nil, held = false }
end

local function target(b: Buffer): number
	return (b.lag :: number) + b.cfg.interval + b.cfg.margin
end

-- A sample stamped T (server time) arrives at `now`. Returns false if it is older than the newest
-- (dropped).
function Playback.push(b: Buffer, T: number, now: number, data: any): boolean
	local n = #b.samples
	if n > 0 and T <= b.samples[n].T then return false end
	table.insert(b.samples, { T = T, data = data })
	b.fresh = now
	if b.lag == nil then -- the first sample sets the delay to start from
		b.lag, b.lastLag = now - T, now - T
		b.delay = target(b)
	end
	-- Keep what the playback time can still reach (and a little behind it).
	local keepFrom = now - (b.delay :: number) - 1
	while #b.samples > 2 and b.samples[2].T < keepFrom do table.remove(b.samples, 1) end
	return true
end

-- Move the playback clock to `now` (dt = real seconds since the last call) and return the time to
-- draw, or nil before the first sample.
function Playback.advance(b: Buffer, now: number, dt: number): number?
	local n = #b.samples
	if n == 0 or b.delay == nil then return nil end
	local cfg = b.cfg
	local delay = b.delay :: number
	if b.fresh ~= nil then -- the newest arrival since the last frame: its lag (fast up)
		local lag = (b.fresh :: number) - b.samples[n].T
		b.fresh = nil
		b.lastLag = lag
		if lag > (b.lag :: number) then b.lag = lag end
	end
	if dt > 0 then
		local h = math.min(dt, 0.1) -- (a long frame gap, a window restored, never overshoots the delay)
		b.lag = math.max((b.lag :: number) - cfg.lagReleasePerSecond * h, math.min(b.lastLag, b.lag :: number))
		local want = 1 + math.clamp((delay - target(b)) * cfg.gain, -cfg.slew, cfg.slew)
		local step = cfg.rateChangePerSecond * h
		b.rate += math.clamp(want - b.rate, -step, step)
		delay += (1 - b.rate) * h -- play = now - delay advances at `rate`
	end
	local play = now - delay
	local newest = b.samples[n].T
	b.held = play > newest
	if b.held then -- the next sample is late: hold the newest, never guess ahead
		play = newest
		delay = now - newest
	end
	if b.play ~= nil and play < (b.play :: number) then -- (the clock estimate stepped back) never draw backwards
		play = b.play :: number
		delay = now - play
	end
	b.delay, b.play = delay, play
	return play
end

-- A steering sample (RaceOffsets): offsets, and lanes when they changed; without lanes the newest
-- sample's carry on (or `posts` before any). Returns false if it is stale (dropped whole).
function Playback.pushOffsets(b: Buffer, T: number, now: number, offsets: { number }, lanes: { number }?, posts: { number }): boolean
	local n = #b.samples
	if n > 0 and T <= b.samples[n].T then return false end
	local carried = if lanes then lanes elseif n > 0 then b.samples[n].data.lanes else table.clone(posts)
	return Playback.push(b, T, now, { off = offsets, lanes = carried })
end

-- The two samples around playback time `play` and the fraction between them (a == b at either end).
function Playback.around(b: Buffer, play: number): (Sample, Sample, number)
	local s = b.samples
	local n = #s
	if play <= s[1].T then return s[1], s[1], 0 end
	for k = 2, n do
		if s[k].T >= play then
			local a, c = s[k - 1], s[k]
			return a, c, (play - a.T) / (c.T - a.T)
		end
	end
	return s[n], s[n], 0
end

-- Interpolate arrays a and b (same length) at fraction f into out (exactly b at f = 1).
function Playback.lerp(out: { number }, a: { number }, b: { number }, f: number): { number }
	for i = 1, #a do
		out[i] = if f >= 1 then b[i] elseif f <= 0 then a[i] else a[i] + (b[i] - a[i]) * f
	end
	return out
end

return Playback
