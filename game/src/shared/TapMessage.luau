--!strict
-- TapMessage (D-071, provisional; GameConfig.tapCue): when the tap preview's word over your horse may
-- show on your own screen. Pure, so Lune can test it; client/TapCue draws it.
-- The server sends "up" (TapPreview.message) to the rider alone. Here it waits, at most
-- waitSeconds, behind a steering chip or first-race coaching, then shows; it is dropped in the Final
-- Burst, after the lock, or once it has waited too long, and two never show closer than
-- tapPreview.messageEverySeconds. Gains only, no number, never "leading", "winning" or "pulling away"
-- (the systems consult: a horse drawn 1st at the lock still finishes 4th or worse 44% of the time).
-- The held chip's words (TapPreview.stepCue) live here too, so the copy is in one place: one arrow,
-- toward the side with room (both free: in, which saves ground), never "gap" or "boxed in".

local TapMessage = {}

TapMessage.TEXT = { up = "Giddy-up! Moving up!" }
TapMessage.CHIP = { gapIn = "Room this way! ◀", gapOut = "Room this way! ▶", taps = "Keep tapping! Room soon." }

-- The held chip for stepCue's answer: "gap" -> the side with room (-1 in, 1 out) and its words; "taps"
-- -> its words and 0; nil when no side has room for "gap".
function TapMessage.chip(kind: string?, inSide: string?, outSide: string?): (string?, number)
	if kind == "taps" then return TapMessage.CHIP.taps, 0 end
	if kind ~= "gap" then return nil, 0 end
	if inSide == "free" then return TapMessage.CHIP.gapIn, -1 end
	if outSide == "free" then return TapMessage.CHIP.gapOut, 1 end
	return nil, 0
end

export type Queue = { kind: string?, at: number, shownAt: number }

function TapMessage.new(): Queue
	return { kind = nil, at = -math.huge, shownAt = -math.huge }
end

-- A message arrived at race time `now` (a newer one replaces one still waiting).
function TapMessage.offer(q: Queue, kind: any, now: number)
	if TapMessage.TEXT[kind] == nil then return end
	q.kind, q.at = kind, now
end

-- One frame: the words to show now, or nil. locked = lanes locked, burst = the Final Burst is up,
-- busy = a steering chip or coaching has the moment. Records the message it returns.
function TapMessage.take(q: Queue, now: number, cueCfg: any, previewCfg: any, locked: boolean, burst: boolean,
	busy: boolean): string?
	local kind = q.kind
	if kind == nil then return nil end
	if locked or burst or (cueCfg and cueCfg.enabled == false) or now - q.at > ((cueCfg and cueCfg.waitSeconds) or 2.5) then
		q.kind = nil
		return nil
	end
	if busy or now - q.shownAt < ((previewCfg and previewCfg.messageEverySeconds) or 4) - 1e-6 then return nil end
	q.kind, q.shownAt = nil, now
	return TapMessage.TEXT[kind]
end

return TapMessage
