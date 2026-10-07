--!strict
-- DockLayout (D-064, stage 1): the dock's size rules, pure so Lune can test them.
-- The dock shrinks to fit the screen, but never so far that a button renders under
-- ui.minTouchPx or a label under ui.minTextPx; on a phone it shows only the horse card,
-- RACE! and ☰ More (ui.dockPhoneItems = 3) so it fits at full size.

local DockLayout = {}

DockLayout.BUTTON_PX = 70 -- the dock's smallest button (Map, Board, My Horses, More), unscaled
DockLayout.LABEL_PX = 16  -- the dock's smallest label (Ready / Napping), unscaled
DockLayout.LEAVE_PX = 64  -- the ✕ that leaves the line, on the RACE! button

export type UiConfig = { minTouchPx: number, minTextPx: number, dockPhoneItems: number, phoneShortSide: number }

-- The smallest scale that keeps every button and label at or above the floors.
function DockLayout.floor(cfg: UiConfig): number
	return math.min(1, math.max(cfg.minTouchPx / math.min(DockLayout.BUTTON_PX, DockLayout.LEAVE_PX), cfg.minTextPx / DockLayout.LABEL_PX))
end

-- The dock's scale for `room` px of space and a dock `width` px wide at scale 1.
function DockLayout.scale(room: number, width: number, cfg: UiConfig): number
	return math.clamp(room / math.max(1, width), DockLayout.floor(cfg), 1)
end

-- A phone: a touch screen whose shorter side is at most phoneShortSide px, with the short dock on.
function DockLayout.isPhone(touch: boolean, viewX: number, viewY: number, cfg: UiConfig): boolean
	return touch and cfg.dockPhoneItems <= 3 and math.min(viewX, viewY) <= cfg.phoneShortSide
end

return DockLayout
