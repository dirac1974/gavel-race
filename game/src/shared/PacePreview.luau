--!strict
-- PacePreview (AAA Phase 2, D-067, the gameplay consult): when the server refreshes the live
-- chances shown on screen while a pace checkpoint is still open, before the stretch drive. Pure, so
-- Lune can test it. After the far-turn lock the trip's tau is fixed (RaceSession:setTrip), and
-- after it Trip.frame draws from the chances shown (displayOffsets), so a preview then moves only
-- what is drawn: the scores, the trip and the result still come from the checkpoints' own closes.
-- Before the lock nothing changes (Trip.advance reads session.live, never the chances shown).

local PacePreview = {}

-- Preview pace checkpoint `seg` now? Only with the config on (GameConfig.pacePreviewAfterLock),
-- once the trip has locked, only the open checkpoint (closed + 1), only up to throughCheckpoint,
-- and never the stretch drive (it has its own preview, stretchPreviewSeconds).
function PacePreview.afterLock(cfg: any, locked: boolean, seg: number, closed: number, stretch: boolean): boolean
	if type(cfg) ~= "table" or cfg.enabled == false or not locked or stretch then return false end
	return seg == closed + 1 and seg <= (cfg.throughCheckpoint or 2)
end

-- (D-071) Steering off (no trip, so no lock and no TapPreview): preview the open pace checkpoint
-- at every pass end from the gate, as the stretch drive does, so taps move horses on screen all
-- race. tapCfg = GameConfig.tapPreview; only with it enabled and steeringOffWholeRace; never the
-- stretch drive (its own preview). With w = 0 before the far turn the shown offsets carry no luck.
function PacePreview.beforeLock(tapCfg: any, steering: boolean, seg: number, closed: number, stretch: boolean): boolean
	if type(tapCfg) ~= "table" or tapCfg.enabled ~= true or tapCfg.steeringOffWholeRace == false then return false end
	if steering or stretch then return false end
	return seg == closed + 1
end

return PacePreview
