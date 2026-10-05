--!strict
-- All tuning values in one place (D-005, D-010, D-011). Theme-agnostic.
-- Changing a value here is a tuning change; log design changes in docs/memory/DECISIONS.md.

export type League = {
	name: string,
	T: number,             -- stat temperature
	B: number,             -- base purse
	sweepSeconds: number,  -- meter full sweep, there and back
	windowSeconds: number, -- time to tap in each gavel window
	targetDrift: number,   -- 0 = fixed center; >0 = center drifts this far (fraction of half-width)
	twoTargetFinal: boolean, -- final window shows two half-size targets
}

local GameConfig = {}

GameConfig.lanes = 8
GameConfig.windowsPerRace = 3
GameConfig.windowGapSeconds = 4.0    -- running time between gavel windows
GameConfig.lobbyFillSeconds = 20     -- bots fill remaining lanes after this
GameConfig.kappa = 1.0
GameConfig.qFloor = 0.025
GameConfig.rFloor = -0.5
GameConfig.placePrizes = { 1.2, 0.8, 0.4 }       -- 2nd, 3rd, 4th, in units of B
GameConfig.leaguePoints = { 10, 6, 4, 2 }        -- 1st..4th; everyone else gets finishPoints
GameConfig.finishPoints = 1
-- League Points needed to unlock each league's Stakes race (D-013, from sims/economy.py)
GameConfig.stakesUnlockPoints = { Rookie = 100, Bronze = 110, Silver = 1400, Gold = 3000 }
GameConfig.maxTapRewindSeconds = 0.3             -- D-010 latency allowance
GameConfig.missedTapScore = 0
GameConfig.botScoreMean = 50
GameConfig.botScoreSd = 15
GameConfig.botRatingSpread = 6                   -- bots rated within ± this of the human median

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
	Rookie = { name = "Rookie", T = 22, B = 20, sweepSeconds = 2.4, windowSeconds = 4.0, targetDrift = 0, twoTargetFinal = false },
	Bronze = { name = "Bronze", T = 18, B = 50, sweepSeconds = 2.0, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false },
	Silver = { name = "Silver", T = 18, B = 120, sweepSeconds = 1.6, windowSeconds = 3.0, targetDrift = 0, twoTargetFinal = false },
	Gold = { name = "Gold", T = 14.4, B = 300, sweepSeconds = 1.3, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = false },
	Champion = { name = "Champion", T = 12, B = 750, sweepSeconds = 1.1, windowSeconds = 3.0, targetDrift = 0.3, twoTargetFinal = true },
} :: { [string]: League }

GameConfig.leagueOrder = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }

function GameConfig.labelFor(score: number): string
	for _, row in GameConfig.scoreLabels do
		if score >= row.min then return row.label end
	end
	return "Miss"
end

return GameConfig
