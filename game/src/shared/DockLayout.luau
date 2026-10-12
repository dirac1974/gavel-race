--!strict
-- DockLayout (D-064, stage 1): the dock's size rules, pure so Lune can test them.
-- The dock shrinks to fit the screen, but never so far that a button renders under
-- ui.minTouchPx or a label under ui.minTextPx; on a phone it shows only the horse card,
-- RACE! and ☰ More (ui.dockPhoneItems = 3) so it fits at full size.
-- Find it (D-075): ui.dockPhoneItems = 5 is the phone dock of five: the horse portrait (tap: My
-- Horses), RACE! with its 🔀 Pick strip, Map, Jobs and ☰ More (Ride, Book, Cash, Horses).

local DockLayout = {}

DockLayout.BUTTON_PX = 70 -- the dock's smallest button (Map, Board, My Horses, More), unscaled
DockLayout.LABEL_PX = 16  -- the dock's smallest label (Ready / Napping), unscaled
DockLayout.LEAVE_PX = 64  -- the ✕ that leaves the line, on the RACE! button

DockLayout.RACE_PX = 210   -- the RACE! slot, unscaled: RACE! (one tap) and, beside it, the 🔀 Pick strip (ui.pickStripPx)
DockLayout.GAP_PX = 10     -- between dock slots

-- One LayoutOrder each (Find it fixed Map and Book both at 4). PHONE: the five-item phone dock's order.
DockLayout.ORDER = { cash = 0, horse = 1, horses = 2, jobs = 3, map = 4, book = 5, race = 6, ride = 7, more = 8 }
DockLayout.PHONE_ORDER = { horse = 1, race = 2, map = 3, jobs = 4, more = 5 }

export type UiConfig = { minTouchPx: number, minTextPx: number, dockPhoneItems: number, phoneShortSide: number,
	pickStripPx: number?, phonePortraitPx: number? }

-- The smallest scale that keeps every button and label at or above the floors.
function DockLayout.floor(cfg: UiConfig): number
	local smallest = math.min(DockLayout.BUTTON_PX, DockLayout.LEAVE_PX, cfg.pickStripPx or DockLayout.BUTTON_PX)
	return math.min(1, math.max(cfg.minTouchPx / smallest, cfg.minTextPx / DockLayout.LABEL_PX))
end

-- The five-item phone dock's width at scale 1: portrait, RACE! plus Pick, Map, Jobs, More.
function DockLayout.phoneWidth(cfg: UiConfig): number
	return (cfg.phonePortraitPx or DockLayout.BUTTON_PX) + DockLayout.RACE_PX + 3 * DockLayout.BUTTON_PX + 4 * DockLayout.GAP_PX
end

-- What the five-item phone dock moves into ☰ More on a narrow screen (consult: UI/UX must-fix 1), in
-- ui.dockShrinkOrder ("jobs", then "map"), until it fits viewX − 24 − movementColumn at the floor scale.
-- Both moved leaves the D-064 three-item dock.
function DockLayout.phoneMoves(viewX: number, cfg: UiConfig, movementColumn: number): { string }
	local room = viewX - 24 - movementColumn
	local floor = DockLayout.floor(cfg)
	local width = DockLayout.phoneWidth(cfg)
	local out = {}
	for _, item in (cfg :: any).dockShrinkOrder or {} do
		if width * floor <= room then break end
		table.insert(out, item)
		width -= DockLayout.BUTTON_PX + DockLayout.GAP_PX
	end
	return out
end

-- The phone dock's rendered width once `moves` are in More.
function DockLayout.phoneRendered(cfg: UiConfig, moves: { string }): number
	return (DockLayout.phoneWidth(cfg) - #moves * (DockLayout.BUTTON_PX + DockLayout.GAP_PX)) * DockLayout.floor(cfg)
end

-- The dock's scale for `room` px of space and a dock `width` px wide at scale 1.
function DockLayout.scale(room: number, width: number, cfg: UiConfig): number
	return math.clamp(room / math.max(1, width), DockLayout.floor(cfg), 1)
end

-- A phone: a touch screen whose shorter side is at most phoneShortSide px, with the short dock on
-- (dockPhoneItems 3 or 5; more means the full dock everywhere).
function DockLayout.isPhone(touch: boolean, viewX: number, viewY: number, cfg: UiConfig): boolean
	return touch and cfg.dockPhoneItems <= 5 and math.min(viewX, viewY) <= cfg.phoneShortSide
end

return DockLayout
