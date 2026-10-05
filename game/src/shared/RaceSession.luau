--!strict
-- One race from lobby lock to results. Pure state machine: no Roblox services,
-- no clocks of its own (callers pass times), randomness only through the rng
-- passed in. Dependencies are injected so it runs under Lune tests.
--
-- Segments (D-026, D-031): the pace slider runs from the gate to the final turn (two
-- checkpoints), the Final Burst comes as the field straightens into the homestretch and
-- counts double, then the slider resumes for the stretch drive (one checkpoint).
-- S = weighted mean of segment scores, so the race maths is unchanged.
--
-- Flow: RaceSession.new -> paceSchedule(spans, ranges)
--   pace:  scorePace(id, seg, taps) ... -> closeSegment(seg)
--   burst: burstSpec() -> submitBurst(id, seg, t) ... -> closeSegment(seg)
--   (segments close in config order) -> finish()
--
-- The finish (D-033): each horse gets a secret luck number at the gate; the order is by
-- luck / live chance (RaceShape), which is the same Harville distribution as before.
-- Bot scores are drawn at the gate too, so live chances can be previewed mid-segment.

export type Rng = { NextNumber: (self: any) -> number }

export type LaneInput = {
	id: string,          -- player UserId as string, or "bot:<n>"
	name: string,
	rating: number,
	isBot: boolean,
}

export type Lane = LaneInput & {
	scores: { number? },   -- per segment
	droppedUsed: boolean,
	averageOnly: boolean,  -- D-022 flag 2: scores count as the segment average
}

export type Prize = { id: string, place: number, cash: number, leaguePoints: number, isBot: boolean }

export type PaceResult = { score: number, errors: { number }, matched: number }

local RaceSession = {}
RaceSession.__index = RaceSession

local DROPPED = -1

-- Box-Muller normal from two uniforms.
local function gauss(rng: Rng, mean: number, sd: number): number
	local u1 = math.max(rng:NextNumber(), 1e-12)
	local u2 = rng:NextNumber()
	return mean + sd * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Fill a lobby to `lanes` with bots rated around the humans' median rating.
function RaceSession.fillWithBots(humans: { LaneInput }, lanes: number, config: any, theme: any, rng: Rng): { LaneInput }
	local field = table.clone(humans)
	local ratings = {}
	for _, h in humans do table.insert(ratings, h.rating) end
	table.sort(ratings)
	local median = if #ratings > 0 then ratings[math.ceil(#ratings / 2)] else 50
	local n = 0
	local offset = math.floor(rng:NextNumber() * #theme.botNames) -- different bot names each race
	while #field < lanes do
		n += 1
		local spread = config.botRatingSpread
		local name = theme.botNames[((n - 1 + offset) % #theme.botNames) + 1]
		table.insert(field, {
			id = "bot:" .. n,
			name = name,
			rating = median + (rng:NextNumber() * 2 - 1) * spread,
			isBot = true,
		})
	end
	return field
end

function RaceSession.new(params: {
	deps: { RaceMath: any, BurstMeter: any, PaceMeter: any, RaceShape: any },
	config: any,
	leagueName: string,
	lanes: { LaneInput },
	rng: Rng,
})
	local config = params.config
	local league = config.leagues[params.leagueName]
	assert(league, "unknown league " .. params.leagueName)
	local self = setmetatable({}, RaceSession)
	self.deps = params.deps
	self.config = config
	self.league = league
	self.rng = params.rng
	self.mathCfg = { T = league.T, qFloor = config.qFloor, kappa = config.kappa, rFloor = config.rFloor, B = league.B }
	self.lanes = {} :: { Lane }
	local ratings = {}
	for i, l in params.lanes do
		self.lanes[i] = {
			id = l.id, name = l.name, rating = l.rating, isBot = l.isBot,
			scores = {}, droppedUsed = false, averageOnly = false,
		}
		ratings[i] = l.rating
	end
	local RaceMath = self.deps.RaceMath
	self.q = RaceMath.baseChances(ratings, self.mathCfg)
	self.purses = RaceMath.lockPurses(self.q, self.mathCfg)
	self.live = table.clone(self.q)
	self.luck = self.deps.RaceShape.drawLuck(self.rng, #self.lanes) -- secret; never sent to clients
	self.botScores = {} :: { [number]: { [number]: number } }
	for seg, kind in config.segments do
		local isBurst = kind == "burst"
		local mean = if isBurst then config.botBurstMean else config.botPaceMean
		local sd = if isBurst then config.botBurstSd else config.botPaceSd
		self.botScores[seg] = {}
		for i, lane in self.lanes do
			if lane.isBot then self.botScores[seg][i] = math.clamp(gauss(self.rng, mean, sd), 0, 100) end
		end
	end
	self.crowd = {} :: { [number]: number } -- Clap Along boost per lane (D-020), 0..0.03
	self.closed = 0
	self.passes = nil :: any
	self.paceRanges = {} :: { [number]: { number } }
	self.burst = nil :: any
	self.finished = false
	return self
end

function RaceSession:segmentCount(): number
	return #self.config.segments
end

function RaceSession:kind(seg: number): string
	return self.config.segments[seg]
end

function RaceSession:laneIndex(id: string): number?
	for i, l in self.lanes do
		if l.id == id then return i end
	end
	return nil
end

-- Pace meter (D-026) ------------------------------------------------------------

function RaceSession:paceSpec()
	local p = self.config.pace
	return {
		sweepSeconds = self.league.sweepSeconds,
		speedDrift = p.speedDrift,
		shiftMin = p.shiftMin,
		shiftMax = p.shiftMax,
		centerRange = p.centerRange,
	}
end

function RaceSession:paceCount(): number
	local n = 0
	for _, kind in self.config.segments do
		if kind == "pace" then n += 1 end
	end
	return n
end

-- The marker's passes for the race, shared by all lanes. Call once, at the gate.
-- `spans` = { {start, duration}, ... }: continuous runs of the slider (one schedule each).
-- `ranges` = one {t0, t1} per pace segment, in segment order; a pass belongs to the
-- checkpoint whose range contains its start.
function RaceSession:paceSchedule(spans: { { number } }, ranges: { { number } })
	assert(self.passes == nil, "pace already scheduled")
	local passes = {}
	for _, span in spans do
		for _, p in self.deps.PaceMeter.schedule(self.rng, span[1], span[2], self:paceSpec()) do
			table.insert(passes, p)
		end
	end
	self.passes = passes
	local k = 0
	for seg, kind in self.config.segments do
		if kind == "pace" then
			k += 1
			self.paceRanges[seg] = assert(ranges[k], "a range for every pace segment")
		end
	end
	return passes
end

-- Time range of pace checkpoint `seg`.
function RaceSession:paceRange(seg: number): (number, number)
	local r = self.paceRanges[seg]
	return r[1], r[2]
end

function RaceSession:pacePasses(seg: number)
	local t0, t1 = self:paceRange(seg)
	local out = {}
	for _, p in self.passes do
		if p.t0 >= t0 - 1e-9 and p.t0 < t1 - 1e-9 then table.insert(out, p) end
	end
	return out
end

-- Score one rider's taps (server times, already resolved) for pace checkpoint `seg`.
-- Once per lane per checkpoint; bots and unknown ids return nil.
function RaceSession:scorePace(id: string, seg: number, taps: { number }): PaceResult?
	local i = self:laneIndex(id)
	if not i or self.finished or seg ~= self.closed + 1 or self:kind(seg) ~= "pace" or self.passes == nil then return nil end
	local lane = self.lanes[i]
	if lane.isBot or lane.scores[seg] ~= nil then return nil end
	local s, errors, matched = self.deps.PaceMeter.score(self:pacePasses(seg), taps)
	lane.scores[seg] = s
	return { score = s, errors = errors, matched = matched }
end

-- Final Burst ------------------------------------------------------------------

-- The burst meter, with a random start picked once and shared by every lane.
function RaceSession:burstSpec()
	if self.burst == nil then
		local league = self.league
		self.burst = {
			sweepSeconds = league.sweepSeconds,
			targetDrift = league.targetDrift,
			twoTargets = league.twoTargetFinal,
			phase = self.deps.BurstMeter.randomPhase(self.rng),
		}
	end
	return self.burst
end

-- One tap `t` seconds after the burst opened (already resolved by the caller).
function RaceSession:submitBurst(id: string, seg: number, t: number): number?
	local i = self:laneIndex(id)
	if not i or self.finished or seg ~= self.closed + 1 or self:kind(seg) ~= "burst" then return nil end
	local lane = self.lanes[i]
	if lane.isBot or lane.scores[seg] ~= nil then return nil end
	local s = self.deps.BurstMeter.score(t, self:burstSpec())
	lane.scores[seg] = s
	return s
end

-- Shared ---------------------------------------------------------------------------

-- A disconnect during segment `seg`: scored at the segment's race average once per race.
function RaceSession:dropSegment(id: string, seg: number): boolean
	local i = self:laneIndex(id)
	if not i then return false end
	local lane = self.lanes[i]
	if lane.droppedUsed or lane.scores[seg] ~= nil then return false end
	lane.droppedUsed = true
	lane.scores[seg] = DROPPED
	return true
end

-- D-022 flag 2 (only when Integrity is out of log-only mode).
function RaceSession:setAverageOnly(id: string, on: boolean)
	local i = self:laneIndex(id)
	if i then self.lanes[i].averageOnly = on end
end

local function weightedScore(lane: Lane, upTo: number, weights: { number }): number
	local sum, wsum = 0, 0
	for seg = 1, upTo do
		local w = weights[seg] or 1
		sum += w * (lane.scores[seg] or 0)
		wsum += w
	end
	return if wsum > 0 then sum / wsum else 0
end

-- Close segment `seg`: bots score, missing humans score missedTapScore, dropped and
-- average-only lanes get the segment average. Returns live chances.
function RaceSession:closeSegment(seg: number): { number }
	assert(seg == self.closed + 1, "segments must close in order")
	local config = self.config
	local played, sum = 0, 0
	for i, lane in self.lanes do
		if lane.isBot then
			lane.scores[seg] = self.botScores[seg][i]
		elseif lane.scores[seg] == nil then
			lane.scores[seg] = config.missedTapScore
		end
		local s = lane.scores[seg] :: number
		if s ~= DROPPED and not lane.averageOnly then
			played += 1
			sum += s
		end
	end
	local average = if played > 0 then sum / played else 50
	for _, lane in self.lanes do
		if lane.scores[seg] == DROPPED or lane.averageOnly then lane.scores[seg] = average end
	end
	self.closed = seg
	local RaceMath = self.deps.RaceMath
	self.live = RaceMath.liveChances(self.q, self:tilts(self:scoresSoFar()), self.mathCfg)
	return self.live
end

-- Live chances if segment `seg` closed now with these provisional scores for riders
-- (`partial[laneIndex]`); bots use their drawn scores. Nothing is stored. Used to keep the
-- stretch drive live (D-033).
function RaceSession:previewLive(seg: number, partial: { [number]: number }): { number }
	assert(seg == self.closed + 1, "preview the open segment")
	local weights = self.config.segmentWeights
	local S = {}
	local played, sum = 0, 0
	local now = {}
	for i, lane in self.lanes do
		local s = if lane.isBot then self.botScores[seg][i] else (partial[i] or self.config.missedTapScore)
		now[i] = s
		if not lane.averageOnly and lane.scores[seg] ~= DROPPED then
			played += 1
			sum += s
		end
	end
	local average = if played > 0 then sum / played else 50
	for i, lane in self.lanes do
		local total, wsum = 0, 0
		for k = 1, seg do
			local w = weights[k] or 1
			local v = if k == seg then (if lane.averageOnly or lane.scores[seg] == DROPPED then average else now[i]) else (lane.scores[k] or 0)
			total += w * v
			wsum += w
		end
		S[i] = total / wsum
	end
	local RaceMath = self.deps.RaceMath
	return RaceMath.liveChances(self.q, self:tilts(S), self.mathCfg)
end

-- On-screen offsets (feet ahead of the pace) for blend weight w (RaceShape).
function RaceSession:displayOffsets(live: { number }, w: number, shapeCfg: any): { number }
	return self.deps.RaceShape.offsets(live, self.luck, w, shapeCfg)
end

-- Where lane `i` would have finished riding at the race average (R = 0), all else the same.
-- Positive gain = their riding won them places (D-033 "Your ride" card).
-- Skills R from scores, plus each lane's crowd boost as κR + c (D-020): R + c / κ.
function RaceSession:tilts(S: { number }): { number }
	local R = self.deps.RaceMath.skills(S, self.mathCfg)
	for i, c in self.crowd do
		if R[i] then R[i] += c / self.mathCfg.kappa end
	end
	return R
end

-- Set lane i's crowd boost (Fans.boost of its crowd), used from the next segment close.
function RaceSession:setCrowd(i: number, c: number)
	self.crowd[i] = math.clamp(c, 0, 0.03)
end

function RaceSession:ridingGain(i: number): number
	local RaceMath, RaceShape = self.deps.RaceMath, self.deps.RaceShape
	local R = self:tilts(self:scoresSoFar())
	R[i] = (self.crowd[i] or 0) / self.mathCfg.kappa -- riding at the race average, crowd unchanged
	local liveAvg = RaceMath.liveChances(self.q, R, self.mathCfg)
	return RaceShape.placeIn(self.luck, liveAvg, i) - RaceShape.placeIn(self.luck, self.live, i)
end

-- Each lane's S over the closed segments (weighted; the Final Burst counts double).
function RaceSession:scoresSoFar(): { number }
	local S = {}
	for i, lane in self.lanes do S[i] = weightedScore(lane, self.closed, self.config.segmentWeights) end
	return S
end

-- Draw the finish order and compute prizes. Bots are never paid.
function RaceSession:finish(): { order: { number }, prizes: { Prize } }
	assert(self.closed == self:segmentCount(), "close all segments first")
	assert(not self.finished, "already finished")
	self.finished = true
	local order = self.deps.RaceShape.order(self.luck, self.live) -- exponential race (D-033)
	local B = self.league.B
	local prizes = {}
	for place, laneIdx in order do
		local lane = self.lanes[laneIdx]
		local cash = 0
		if place == 1 then
			cash = self.purses[laneIdx]
		elseif place <= 1 + #self.config.placePrizes then
			cash = math.floor(B * self.config.placePrizes[place - 1] + 0.5)
		end
		local points = self.config.leaguePoints[place] or self.config.finishPoints
		if lane.isBot then cash = 0 end
		table.insert(prizes, { id = lane.id, place = place, cash = cash, leaguePoints = points, isBot = lane.isBot })
	end
	return { order = order, prizes = prizes }
end

return RaceSession
