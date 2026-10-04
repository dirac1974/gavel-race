--!strict
-- One race from lobby lock to results. Pure state machine: no Roblox services,
-- no clocks of its own (callers pass times), randomness only through the rng
-- passed in. Dependencies are injected so it runs under Lune tests.
--
-- Flow: RaceSession.new -> (submitTap / dropWindow ...) -> closeWindow(w) x3 -> finish()

export type Rng = { NextNumber: (self: any) -> number }

export type LaneInput = {
	id: string,          -- player UserId as string, or "bot:<n>"
	name: string,
	rating: number,
	isBot: boolean,
}

export type Lane = LaneInput & {
	scores: { number? },   -- per window
	droppedUsed: boolean,
}

export type Payout = { id: string, place: number, cash: number, leaguePoints: number, isBot: boolean }

local RaceSession = {}
RaceSession.__index = RaceSession

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
	while #field < lanes do
		n += 1
		local spread = config.botRatingSpread
		local name = theme.botNames[((n - 1) % #theme.botNames) + 1]
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
	deps: { RaceMath: any, GavelMeter: any },
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
		self.lanes[i] = { id = l.id, name = l.name, rating = l.rating, isBot = l.isBot, scores = {}, droppedUsed = false }
		ratings[i] = l.rating
	end
	local RaceMath = self.deps.RaceMath
	self.q = RaceMath.baseChances(ratings, self.mathCfg)
	self.purses = RaceMath.lockPurses(self.q, self.mathCfg)
	self.live = table.clone(self.q)
	self.closedWindows = 0
	self.finished = false
	return self
end

function RaceSession:meterSpec(window: number)
	local league = self.league
	return {
		sweepSeconds = league.sweepSeconds,
		targetDrift = league.targetDrift,
		twoTargets = league.twoTargetFinal and window == self.config.windowsPerRace,
	}
end

function RaceSession:laneIndex(id: string): number?
	for i, l in self.lanes do
		if l.id == id then return i end
	end
	return nil
end

-- A tap `t` seconds after window `w` opened (already resolved by the caller
-- with GavelMeter.resolveTapTime). One tap per lane per window.
function RaceSession:submitTap(id: string, window: number, t: number): number?
	local i = self:laneIndex(id)
	if not i or self.finished or window ~= self.closedWindows + 1 then return nil end
	local lane = self.lanes[i]
	if lane.isBot or lane.scores[window] ~= nil then return nil end
	local s = self.deps.GavelMeter.score(t, self:meterSpec(window))
	lane.scores[window] = s
	return s
end

-- A disconnect during window `w`: scored at the window's race average once per race.
function RaceSession:dropWindow(id: string, window: number): boolean
	local i = self:laneIndex(id)
	if not i then return false end
	local lane = self.lanes[i]
	if lane.droppedUsed or lane.scores[window] ~= nil then return false end
	lane.droppedUsed = true
	lane.scores[window] = -1 -- placeholder, replaced in closeWindow
	return true
end

local function averageScore(lane: Lane, upTo: number): number
	local sum = 0
	for w = 1, upTo do sum += lane.scores[w] or 0 end
	return sum / upTo
end

-- Close window `w`: bots tap, missing humans score missedTapScore, dropped
-- lanes get the window average. Returns live chances.
function RaceSession:closeWindow(window: number): { number }
	assert(window == self.closedWindows + 1, "windows must close in order")
	local config = self.config
	local played, sum = 0, 0
	for _, lane in self.lanes do
		if lane.isBot then
			lane.scores[window] = math.clamp(gauss(self.rng, config.botScoreMean, config.botScoreSd), 0, 100)
		elseif lane.scores[window] == nil then
			lane.scores[window] = config.missedTapScore
		end
		local s = lane.scores[window] :: number
		if s >= 0 then
			played += 1
			sum += s
		end
	end
	local windowAverage = if played > 0 then sum / played else 50
	for _, lane in self.lanes do
		if lane.scores[window] == -1 then lane.scores[window] = windowAverage end
	end
	self.closedWindows = window
	local S = {}
	for i, lane in self.lanes do S[i] = averageScore(lane, window) end
	local RaceMath = self.deps.RaceMath
	self.live = RaceMath.liveChances(self.q, RaceMath.skills(S, self.mathCfg), self.mathCfg)
	return self.live
end

-- Draw the finish order and compute payouts. Bots are never paid.
function RaceSession:finish(): { order: { number }, payouts: { Payout } }
	assert(self.closedWindows == self.config.windowsPerRace, "close all windows first")
	assert(not self.finished, "already finished")
	self.finished = true
	local order = self.deps.RaceMath.drawFinish(self.live, self.rng)
	local B = self.league.B
	local payouts = {}
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
		table.insert(payouts, { id = lane.id, place = place, cash = cash, leaguePoints = points, isBot = lane.isBot })
	end
	return { order = order, payouts = payouts }
end

return RaceSession
