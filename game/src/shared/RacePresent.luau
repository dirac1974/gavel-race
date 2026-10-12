--!strict
-- RacePresent (AAA Phase 4 Dev B, D-069): the pure timing and levels behind the race's presentation, so
-- tests can read them. Drawn and heard only: nothing here reads or changes a score, the order or a result.
--   gateRuns / gateFrame: the gate line-up camera pass in the countdown (client/GateIntro). It dollies
--     in front of the gate from the outside lane to lane 1, blends behind your horse and hands back to
--     the Follow camera handBackBefore seconds before GO. Riders only, never under Reduced Motion, and a
--     late seat skips it.
--   youMarker: the YOU marker's size and height (client/RaceHudStyle): small and low in your own chase
--     view, hidden in first person and during the finish orbit, the big one for replays.
--   musicLevel / musicStep: the music bed's level (client/MusicBed), under the tap tick and the voice.
--   starSteps: the results card's stars counting in one by one with a rising tick (client/ResultsCard).

local RacePresent = {}

export type GateCfg = {
	enabled: boolean?,
	dollySeconds: number?,
	blendSeconds: number?,
	handBackBefore: number?,
	lateSeatSeconds: number?,
}

local function num(v: any, default: number): number
	if type(v) == "number" and v == v and v > -math.huge and v < math.huge then return v end
	return default
end

-- When the pass's parts start and end (server-clock seconds) for a race starting (GO) at `start`.
function RacePresent.gateTimes(cfg: GateCfg, start: number): (number, number, number)
	local handBack = start - num(cfg.handBackBefore, 1)
	local blendFrom = handBack - num(cfg.blendSeconds, 0.4)
	local dollyFrom = blendFrom - num(cfg.dollySeconds, 1.6)
	return dollyFrom, blendFrom, handBack
end

-- Does the pass run for a rider seated at `now`? Riders only, never under Reduced Motion, and a
-- late seat (past the countdown's first second by more than lateSeatSeconds) goes straight to the
-- chase view.
function RacePresent.gateRuns(cfg: GateCfg?, now: number, start: number, countFrom: number, riding: boolean, still: boolean): boolean
	if not cfg or cfg.enabled == false or not riding or still then return false end
	local _, blendFrom = RacePresent.gateTimes(cfg, start)
	if now > start - countFrom + num(cfg.lateSeatSeconds, 0.3) then return false end
	return now < blendFrom
end

-- Where the pass is at `now`: "dolly" (f 0..1 from the outside lane to lane 1), "blend" (f 0..1 to the
-- chase view) or "done" (hand back to the Follow camera). f is eased (smoothstep).
function RacePresent.gateFrame(cfg: GateCfg, now: number, start: number): (string, number)
	local dollyFrom, blendFrom, handBack = RacePresent.gateTimes(cfg, start)
	local function ease(x: number): number
		local c = math.clamp(x, 0, 1)
		return c * c * (3 - 2 * c)
	end
	if now >= handBack then return "done", 1 end
	if now >= blendFrom then return "blend", ease((now - blendFrom) / math.max(0.01, handBack - blendFrom)) end
	return "dolly", ease((now - dollyFrom) / math.max(0.01, blendFrom - dollyFrom))
end

-- The gate pass's cut (handOff = "cut"): the Paper's opacity `elapsed` seconds into a fade of `seconds`,
-- clear to 0.4 at the middle (where the chase shot is set) and back to clear.
function RacePresent.cutFade(elapsed: number, seconds: number): number
	local half = math.max(0.005, num(seconds, 0.12) / 2)
	local e = num(elapsed, 0)
	if e <= 0 or e >= 2 * half then return 0 end
	return 0.4 * (if e <= half then e / half else (2 * half - e) / half)
end

export type YouCfg = {
	riderShown: boolean?,
	riderStuds: number?,
	riderPx: number?,
	riderPxTall: number?,
	otherStuds: number?,
	otherPx: number?,
	otherPxTall: number?,
	firstPersonZoom: number?,
}

-- The YOU marker: (shown, studs above the horse, width px, height px). `chase`: your own chase view
-- (the Follow camera while you ride, or the gate pass before it). riderShown = false (the UI/UX consult:
-- it sat in the sightline and repeats the place badge) hides it there; replays and spectators keep it. `zoom`: the camera's distance to its focus. `orbit`: the finish
-- moment's orbit is on.
function RacePresent.youMarker(cfg: YouCfg?, chase: boolean, zoom: number, orbit: boolean): (boolean, number, number, number)
	local c: YouCfg = cfg or {}
	if orbit then return false, num(c.otherStuds, 12), num(c.otherPx, 90), num(c.otherPxTall, 120) end
	if chase then
		local shown = c.riderShown ~= false and num(zoom, 99) >= num(c.firstPersonZoom, 2)
		return shown, num(c.riderStuds, 7), num(c.riderPx, 56), num(c.riderPxTall, 72)
	end
	return true, num(c.otherStuds, 12), num(c.otherPx, 90), num(c.otherPxTall, 120)
end

export type MusicCfg = {
	id: number?,
	lobby: number?,
	race: number?,
	spectate: number?,
	finish: number?,
	fadeSeconds: number?,
	duckUnderVoice: number?,
}

-- The music bed's level for a mode: "lobby", "race" (your slider runs), "spectate" (watching a race),
-- "finish" (the finish moment and the results card) or "off". The announcer ducks it further. With no
-- track (id 0) there is no music at all.
function RacePresent.musicLevel(cfg: MusicCfg?, mode: string, voice: boolean): number
	if not cfg or num(cfg.id, 0) == 0 or mode == "off" then return 0 end
	local base = if mode == "race" then num(cfg.race, 0.12)
		elseif mode == "spectate" then num(cfg.spectate, 0.08)
		elseif mode == "finish" then num(cfg.finish, 0.4)
		else num(cfg.lobby, 0.35)
	local level = if voice then base * num(cfg.duckUnderVoice, 0.5) else base
	return math.clamp(level, 0, 1)
end

-- One frame of the fade: from `current` toward `target` at a rate that crosses the whole range (0 to the
-- loudest level) in fadeSeconds, so any change lands within fadeSeconds.
function RacePresent.musicStep(cfg: MusicCfg?, current: number, target: number, dt: number): number
	local c: MusicCfg = cfg or {}
	local top = math.max(num(c.lobby, 0.35), num(c.finish, 0.4), num(c.race, 0.12), num(c.spectate, 0.08))
	local step = top * math.max(0, dt) / math.max(0.05, num(c.fadeSeconds, 0.6))
	if target > current then return math.min(target, current + step) end
	return math.max(target, current - step)
end

export type StarCfg = { starDelaySeconds: number?, starStepSeconds: number?, starTickSpeeds: { number }? }
export type StarStep = { at: number, stars: number, speed: number }

-- The card's stars counting in: one step per earned star, starStepSeconds apart after
-- starDelaySeconds (the card's rise), each with its tick a little higher. Reduced Motion: none (they
-- show at once).
function RacePresent.starSteps(cfg: StarCfg?, stars: number, still: boolean): { StarStep }
	local c: StarCfg = cfg or {}
	local n = math.clamp(math.floor(num(stars, 0)), 0, 3)
	local out: { StarStep } = {}
	if still then return out end
	local speeds = c.starTickSpeeds or { 1.0, 1.15, 1.3 }
	local delay, step = num(c.starDelaySeconds, 0.3), num(c.starStepSeconds, 0.2)
	for k = 1, n do
		table.insert(out, { at = delay + (k - 1) * step, stars = k, speed = num(speeds[k], speeds[#speeds] or 1) })
	end
	return out
end

return RacePresent
