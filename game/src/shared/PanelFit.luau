--!strict
-- PanelFit (D-064, stage 3): how a big panel (Race picker, Stable Board, My Horses) fits a small
-- screen, pure so Lune can test it. A panel shrinks to fit, but never so far that its smallest
-- text renders under ui.minTextPx or its buttons under ui.minTouchPx; what still doesn't fit
-- scrolls (or, for a panel with its own list, gets shorter and the list scrolls).

local PanelFit = {}

PanelFit.MARGIN = 20 -- px kept free around a panel

export type UiConfig = { minTouchPx: number, minTextPx: number }
export type Fit = { scale: number, height: number, scroll: boolean, canvas: number, scrollX: boolean, canvasX: number }

-- The smallest scale that keeps text of `minText` px and buttons of `minButton` px at the floors.
function PanelFit.floor(minText: number, minButton: number, cfg: UiConfig): number
	return math.min(1, math.max(cfg.minTextPx / math.max(1, minText), cfg.minTouchPx / math.max(1, minButton)))
end

-- The panel's scale on a viewX × viewY screen: as big as fits, at most 1, never under the floor.
function PanelFit.scale(viewX: number, viewY: number, w: number, h: number, minText: number, minButton: number, cfg: UiConfig): number
	local fit = math.min(1, (viewX - PanelFit.MARGIN) / w, (viewY - PanelFit.MARGIN) / h)
	return math.max(fit, PanelFit.floor(minText, minButton, cfg))
end

-- The whole layout. `minHeight` > 0: the panel has its own scrolling list, so it may get shorter
-- (down to minHeight, unscaled) instead of scrolling. Else `scroll` says the panel scrolls inside
-- a column `canvas` px tall (scaled px).
function PanelFit.layout(viewX: number, viewY: number, w: number, h: number, minText: number, minButton: number, cfg: UiConfig, minHeight: number?): Fit
	local s = PanelFit.scale(viewX, viewY, w, h, minText, minButton, cfg)
	local room = (viewY - PanelFit.MARGIN) / s -- unscaled px of height that fit
	local height = h
	if minHeight and minHeight > 0 and h > room then height = math.max(minHeight, math.floor(room)) end
	local scaled = height * s
	local scroll = scaled > viewY - PanelFit.MARGIN
	-- A panel still wider than the screen at the floor scrolls sideways too (never cut off).
	local wide = w * s
	local scrollX = wide > viewX - PanelFit.MARGIN
	return { scale = s, height = height, scroll = scroll, canvas = math.max(viewY, scaled + PanelFit.MARGIN),
		scrollX = scrollX, canvasX = math.max(viewX, wide + PanelFit.MARGIN) }
end

return PanelFit
