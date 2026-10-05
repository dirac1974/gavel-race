--!strict
-- All tuning values in one place (D-005, D-010, D-011, D-022). Theme-agnostic.
-- Changing a value here is a tuning change; log design changes in docs/memory/DECISIONS.md.

export type League = {
	name: string,
	T: number,             -- stat temperature
	B: number,             -- base purse
	sweepSeconds: number,  -- Final Burst meter full sweep, there and back
	windowSeconds: number, -- time to tap in the Final Burst
	targetDrift: number,   -- 0 = fixed center; >0 = center drifts this far (fraction of half-width)
	twoTargetFinal: boolean, -- Final Burst shows two half-size targets
	strideIntervalLo: number, -- Giddy-up beat interval range (tempo picked per stretch)
	strideIntervalHi: number,
	strideDrift: number,   -- each stride's interval changes by up to this fraction
	leadChange: boolean,   -- one half-beat lead change mid-stretch
}

local GameConfig = {}

GameConfig.lanes = 8
-- Race segments (D-022): three Giddy-up stretches, then the Final Burst counting double.
GameConfig.segments = { "stride", "stride", "stride", "burst" }
GameConfig.segmentWeights = { 1, 1, 1, 2 }
GameConfig.windowGapSeconds = 4.0    -- running time between segments
GameConfig.stride = {
	beats = 8,                 -- per stretch, ~2 taps a second
	halfWindowSeconds = 0.08,  -- a tap scores if within this of its beat
	leadInSeconds = 1.2,       -- first ring shows this long before the first beat
	maxTapsPerBeat = 2,        -- taps beyond beats * this + 4 are ignored (they'd count against anyway)
}
-- Per-tap labels for Giddy-up feedback, by closeness 1 - |error| / halfWindow.
GameConfig.strideLabels = {
	{ min = 0.75, label = "Perfect" },  -- within 20 ms
	{ min = 0.45, label = "Great" },    -- within 44 ms
	{ min = 0.15, label = "Good" },     -- within 68 ms
	{ min = 0, label = "Okay" },
}
GameConfig.lobbyFillSeconds = 20     -- bots fill remaining lanes after this
GameConfig.kappa = 1.0
GameConfig.qFloor = 0.025
GameConfig.rFloor = -0.5
GameConfig.placePrizes = { 1.2, 0.8, 0.4 }       -- 2nd, 3rd, 4th, in units of B
GameConfig.leaguePoints = { 10, 6, 4, 2 }        -- 1st..4th; everyone else gets finishPoints
GameConfig.finishPoints = 1
-- League Points needed to unlock each league's Stakes race (D-013, from sims/economy.py)
GameConfig.stakesUnlockPoints = { Rookie = 100, Bronze = 110, Silver = 1400, Gold = 3000 }
GameConfig.maxTapRewindSeconds = 0.3             -- cap on the per-player latency allowance (D-021)
GameConfig.tapJitterMarginSeconds = 0.05         -- added to measured one-way latency (D-021)
GameConfig.missedTapScore = 0
-- Bot scores per segment (D-011, recalibrated for D-022; tune from playtests).
GameConfig.botStrideMean = 40
GameConfig.botStrideSd = 15
GameConfig.botBurstMean = 55
GameConfig.botBurstSd = 15
GameConfig.botRatingSpread = 6                   -- bots rated within ± this of the human median

-- Macro detection (D-022). Log only until a month of real data sets the threshold.
GameConfig.integrity = {
	logOnly = true,
	maxSpreadSeconds = 0.012,  -- gap-error spread below this is not humanly realistic
	minBeats = 300,
	minRaces = 5,
	minDays = 2,
	warnAt = 2,                -- private note + taps count as the race average
	averageDays = 7,
	reviewAt = 3,              -- a person reviews, then cash races pause
	pauseDays = { 7, 30 },
	strikeExpiryDays = 90,
}

-- Energy (D-015). Gates entry only; never affects Rating or win chance.
GameConfig.energy = {
	maxPerRacer = 5,
	costPerCashRace = 1,
	regenSeconds = 20 * 60,        -- +1 every 20 minutes, offline too
	careTopUps = { feed = 1, groom = 1 },
	careCooldownSeconds = 2 * 60 * 60,
	freeLeagues = { Rookie = true }, -- Rookie races cost no Energy
}

-- Prize ribbons for the UI (D-016). Never use racing-wager terms in UI text. -- policy-ok
GameConfig.ribbons = { "Blue", "Red", "Yellow", "White" }

GameConfig.scoreLabels = {
	{ min = 95, label = "Perfect" },
	{ min = 80, label = "Great" },
	{ min = 60, label = "Good" },
	{ min = 30, label = "Okay" },
	{ min = 0, label = "Miss" },
}

GameConfig.leagues = {
	Rookie = { name = "Rookie", T = 22, B = 20, sweepSeconds = 2.4, windowSeconds = 4.0, targetDrift = 0, twoTargetFinal = false,
		strideIntervalLo = 0.60, strideIntervalHi = 0.60, strideDrift = 0, leadChange = false },
	Bronze = { name = "Bronze", T = 18, B = 50, sweepSeconds = 2.0, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		strideIntervalLo = 0.55, strideIntervalHi = 0.60, strideDrift = 0.02, leadChange = false },
	Silver = { name = "Silver", T = 18, B = 120, sweepSeconds = 1.6, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false,
		strideIntervalLo = 0.50, strideIntervalHi = 0.56, strideDrift = 0.03, leadChange = false },
	Gold = { name = "Gold", T = 14.4, B = 300, sweepSeconds = 1.3, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = false,
		strideIntervalLo = 0.46, strideIntervalHi = 0.52, strideDrift = 0.03, leadChange = false },
	Champion = { name = "Champion", T = 12, B = 750, sweepSeconds = 1.1, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = true,
		strideIntervalLo = 0.42, strideIntervalHi = 0.48, strideDrift = 0.03, leadChange = true },
} :: { [string]: League }

GameConfig.leagueOrder = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }

-- Labels for a whole Giddy-up stretch (0..100). An average kid scores ~30, so the
-- scale is gentler than the burst's.
GameConfig.stretchLabels = {
	{ min = 70, label = "Perfect stretch" },
	{ min = 45, label = "Great" },
	{ min = 20, label = "Good" },
	{ min = 0, label = "Keep the beat" },
}

function GameConfig.labelFor(score: number, labels: { { min: number, label: string } }?): string
	for _, row in labels or GameConfig.scoreLabels do
		if score >= row.min then return row.label end
	end
	return "Miss"
end

return GameConfig
