--!nonstrict
-- Ui: one look for every new screen (D-023 County Fair Toy): warm paper cards, thick ink
-- outlines, chunky rounded buttons that squash when pressed, Fredoka One text. Icons come
-- from the UI atlas (UiArt) with an emoji fallback until a sheet loads.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PanelFit = require(Shared:WaitForChild("PanelFit"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local Ui = {}

Ui.font = Enum.Font.FredokaOne
Ui.colors = {
	ink = Color3.fromHex("1D2433"),
	paper = Color3.fromHex("FFF7E6"),
	cream = Color3.fromHex("FFEFD1"),
	orange = Color3.fromHex("FF9F1C"),
	orangeDark = Color3.fromHex("D97A00"),
	gold = Color3.fromHex("FFD23F"),
	teal = Color3.fromHex("17A398"),
	green = Color3.fromHex("46C46A"),
	cash = Color3.fromHex("2E9E5B"),
	sky = Color3.fromHex("BFD7FF"),
	plum = Color3.fromHex("6B5A80"), -- D-067: darkened from 7D6B91 so sublines pass 4.5:1 on paper and cream
	red = Color3.fromHex("E5484D"),
	white = Color3.new(1, 1, 1),
	shade = Color3.fromHex("C9B99A"),
	-- Text colours that pass 4.5:1 on paper, cream, white and the gold "selected" card (AAA Phase 2,
	-- D-067; clarity_tests checks them). The bright green and orange stay for fills only.
	textGood = Color3.fromHex("18692F"),
	textWarn = Color3.fromHex("8F4700"),
}
Ui.coatColors = {
	bay = Color3.fromHex("8B4A2B"), chestnut = Color3.fromHex("B5562B"), grey = Color3.fromHex("B9BCC2"),
	black = Color3.fromHex("2B2B30"), palomino = Color3.fromHex("E3C16F"), pinto = Color3.fromHex("9A5A35"),
	appaloosa = Color3.fromHex("EDE6DA"), buckskin = Color3.fromHex("C9A26B"), dun = Color3.fromHex("C8A97E"),
	roan = Color3.fromHex("A8695A"), white = Color3.fromHex("F4F0E8"), chestnut_blaze = Color3.fromHex("B5562B"),
}

-- League colours (D-064, stage 3): a race card is its league's colour, the badge on it too.
Ui.leagueColors = {
	Rookie = Color3.fromHex("9EDB86"), Bronze = Color3.fromHex("E8B48A"), Silver = Color3.fromHex("D5DCE6"),
	Gold = Color3.fromHex("FFE08A"), Champion = Color3.fromHex("B9B9F0"),
}
-- League badges count with dots, not stars (★ means only how you rode, D-064).
function Ui.badge(league: string?): string
	return "badge_" .. string.lower(league or "Rookie")
end

local player = Players.LocalPlayer

function Ui.corner(obj: GuiObject, px: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 14)
	c.Parent = obj
	return c
end

function Ui.stroke(obj: GuiObject, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Ui.colors.ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function Ui.pad(obj: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	p.Parent = obj
	return p
end

-- Touch layout (D-056): a touch screen whose last input was a touch (a tablet with a keyboard
-- switches to the PC layout while the keyboard is used). Ui.TouchChanged fires when it flips.
local UserInputService = game:GetService("UserInputService")
function Ui.touchLayout(): boolean
	if not UserInputService.TouchEnabled then return false end
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or not UserInputService.KeyboardEnabled
end
Ui.TouchChanged = Instance.new("BindableEvent")
do
	local was = Ui.touchLayout()
	UserInputService.LastInputTypeChanged:Connect(function()
		local now = Ui.touchLayout()
		if now ~= was then
			was = now
			Ui.TouchChanged:Fire(now)
		end
	end)
end

function Ui.screen(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order or 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- A paper card with an ink outline and a chunky darker lip along the bottom (drawn inside the
-- card, so list and grid layouts see exactly one item per card).
function Ui.card(parent: Instance, size: UDim2, pos: UDim2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or Ui.colors.paper
	f.BorderSizePixel = 0
	Ui.corner(f, 18)
	Ui.stroke(f, 3)
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 7)
	lip.BackgroundColor3 = Ui.colors.ink
	lip.BackgroundTransparency = 0.82
	lip.BorderSizePixel = 0
	lip.ZIndex = 0
	Ui.corner(lip, 18)
	lip.Parent = f
	f.Parent = parent
	return f
end

function Ui.text(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.font
	l.TextSize = size
	l.TextColor3 = Ui.colors.ink
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.TextWrapped = true
	for k, v in props or {} do l[k] = v end
	l.Parent = parent
	return l
end

-- A chunky button: coloured face, ink outline, darker lip underneath, squashes on press.
function Ui.button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3?, textSize: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Ui.colors.orange
	b.AutoButtonColor = false
	b.Font = Ui.font
	b.Text = text
	b.TextColor3 = Ui.colors.ink
	b.TextSize = textSize or 22
	b.TextWrapped = true
	b.BorderSizePixel = 0
	Ui.corner(b, 16)
	Ui.stroke(b, 3)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(s: number, t: number)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	b.MouseButton1Down:Connect(function()
		to(0.92, 0.08)
		if Sound and not b:GetAttribute("NoPop") then Sound.play("ui_pop") end -- quiet; game buttons with their own sound opt out
	end)
	b.MouseButton1Up:Connect(function() to(1, 0.18) end)
	b.MouseLeave:Connect(function() to(1, 0.18) end)
	b.Parent = parent
	return b
end

-- An icon from the atlas, or an emoji until the sheet is ready.
function Ui.icon(parent: Instance, name: string, emoji: string, size: UDim2, pos: UDim2?): GuiObject
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Position = pos or UDim2.new()
	holder.Parent = parent
	local fallback = Ui.text(holder, emoji, 22, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ScaleType = Enum.ScaleType.Fit
	art.Visible = false
	art.Parent = holder
	local function try()
		if UiArt.set(art, name) then fallback.Visible = false end
	end
	try()
	if not art.Visible then
		task.spawn(function()
			for _ = 1, 30 do
				task.wait(2)
				if not holder.Parent then return end
				try()
				if art.Visible then return end
			end
		end)
	end
	return holder
end

-- Energy (D-064): one horseshoe icon everywhere, a row of `max` pips with the spent ones faded.
-- "∩" stands in for the horseshoe until the atlas loads (⚡ meant Sprint too, so it's gone).
Ui.ENERGY_ICON, Ui.ENERGY_EMOJI = "energy_shoe", "∩"
function Ui.energyPips(parent: Instance, energy: number, max: number, px: number, pos: UDim2?): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(max * (px + 3), px)
	row.Position = pos or UDim2.new()
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 3)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = row
	for k = 1, max do
		local icon = Ui.icon(row, Ui.ENERGY_ICON, Ui.ENERGY_EMOJI, UDim2.fromOffset(px, px))
		icon.LayoutOrder = k
		Ui.dim(icon, k > energy)
	end
	row.Parent = parent
	return row
end

-- An icon plus one word (D-064): the icon on top, the word (ui.labelPx) under it.
function Ui.iconButton(parent: Instance, icon: string, emoji: string, word: string, size: UDim2, pos: UDim2, color: Color3?): TextButton
	local b = Ui.button(parent, "", size, pos, color)
	local px = GameConfig.ui.labelPx
	Ui.icon(b, icon, emoji, UDim2.fromOffset(36, 36), UDim2.new(0.5, -18, 0, 6))
	local l = Ui.text(b, word, px, { Size = UDim2.new(1, -4, 0, px + 2), Position = UDim2.new(0, 2, 1, -(px + 6)), TextWrapped = false })
	l.Name = "Word"
	return b
end

-- Big panels on small screens (D-064, stage 3): the panel shrinks to fit, but never below the
-- text and touch floors (PanelFit); what still doesn't fit scrolls in a column, or, for a panel
-- with its own list (minHeight), the panel gets shorter and its list scrolls. Returns a function
-- that plays the open slide.
-- minText / minButton: the panel's smallest text and button (unscaled; default ui.panelMinText and
-- ui.panelButtonPx). The panel never shrinks so far that either renders under the floors, so a
-- panel with 16 px text and 56 px buttons doesn't shrink at all: it scrolls (tests/test_clarity_floors.py
-- checks every literal size in the file against these).
-- The returned slide function takes an optional new height, for a card whose height changes.
function Ui.fitPanel(panel: GuiObject, w: number, h: number, minHeight: number?, minText: number?, minButton: number?): (number?) -> ()
	local cfg = GameConfig.ui
	local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = panel
	local column = Instance.new("ScrollingFrame")
	column.Name = "PanelColumn"
	column.BackgroundTransparency = 1
	column.BorderSizePixel = 0
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.fromScale(0.5, 0)
	column.ScrollingDirection = Enum.ScrollingDirection.XY
	column.ScrollBarThickness = 8
	column.ZIndex = 2
	-- The column is only as wide as the panel (+20 px), so on a wide screen taps beside it still
	-- reach the dim, which closes the panel; on a phone the panel's ✕ does.
	column.Parent = panel.Parent
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Parent = column
	-- A hidden panel takes its column with it, so the column never catches taps meant for the world.
	column.Visible = panel.Visible
	panel:GetPropertyChangedSignal("Visible"):Connect(function() column.Visible = panel.Visible end)
	local top = 0
	local centre = UDim.new(0.5, 0)
	local function apply()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		local f = PanelFit.layout(v.X, v.Y, w, h, minText or cfg.panelMinText, minButton or cfg.panelButtonPx, cfg, minHeight)
		scale.Scale = f.scale
		panel.Size = UDim2.fromOffset(w, f.height)
		local colW = math.min(v.X, math.ceil(w * f.scale) + 20)
		column.Size = UDim2.new(0, colW, 1, 0)
		column.CanvasSize = UDim2.fromOffset(if f.scrollX then f.canvasX else 0, f.canvas)
		column.ScrollingEnabled = f.scroll or f.scrollX
		top = math.floor((f.canvas - f.height * f.scale) / 2)
		centre = if f.scrollX then UDim.new(0, math.floor(f.canvasX / 2)) else UDim.new(0.5, 0)
		panel.Position = UDim2.new(centre, UDim.new(0, top))
	end
	apply()
	task.spawn(function()
		while not workspace.CurrentCamera do task.wait(0.1) end
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		apply()
	end)
	return function(newHeight: number?, still: boolean?)
		if newHeight then h = newHeight end
		apply()
		if still then return end -- a re-layout (the card grew), no slide
		column.CanvasPosition = Vector2.zero
		panel.Position = UDim2.new(centre, UDim.new(0, top + 30))
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(centre, UDim.new(0, top)) }):Play()
	end
end

-- The one ✕ (AAA Phase 2, D-067): every panel closes with the same 64 px button (ui.closePx) in its
-- top-right corner. `pos` and `px` move or resize it (the queue card's ✕ sits in its own row).
function Ui.closeButton(parent: Instance, pos: UDim2?, px: number?): TextButton
	local size = px or GameConfig.ui.closePx
	local b = Ui.button(parent, "✕", UDim2.fromOffset(size, size), pos or UDim2.new(1, -(size + 10), 0, 10), Ui.colors.white,
		math.max(22, math.floor(size * 0.45)))
	b.Name = "Close"
	b.ZIndex = math.max(b.ZIndex, 4)
	return b
end

-- Fade an icon (a spent Energy pip) or bring it back.
function Ui.dim(icon: Instance, faded: boolean)
	for _, d in icon:GetDescendants() do
		if d:IsA("ImageLabel") then d.ImageTransparency = if faded then 0.75 else 0 end
		if d:IsA("TextLabel") then d.TextTransparency = if faded then 0.75 else 0 end
	end
end

-- A quick bounce to draw the eye.
function Ui.pop(obj: GuiObject)
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- The top-centre spot (AAA Phase 2, D-067): one card at a time. Each card that wants the spot calls
-- its `want(on)` (from Ui.slot) whenever it would like to show, and shows only while that returns
-- true: the highest priority wanting it wins (GameConfig.topSlot: the tour over the queue card,
-- "Race time!" over both). Toasts never take the spot: they stack just below whatever card is up.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local SLOT = GameConfig.topSlot or { gapPx = 8, sideReservePx = 134 }
local slotWants: { [string]: { priority: number, on: boolean, frame: GuiObject? } } = {}

local function slotOwner(): string?
	local best, bestP = nil, -math.huge
	for id, w in slotWants do
		if w.on and (w.priority > bestP or (w.priority == bestP and id < (best or "~"))) then best, bestP = id, w.priority end
	end
	return best
end

function Ui.slot(id: string, priority: number, frame: GuiObject?): (boolean, number?) -> boolean
	slotWants[id] = { priority = priority, on = false, frame = frame }
	return function(on: boolean, newPriority: number?): boolean
		local w = slotWants[id]
		w.on = on
		if newPriority then w.priority = newPriority end
		return on and slotOwner() == id
	end
end

function Ui.slotOwner(): string?
	return slotOwner()
end

-- Where the top-centre card goes: under the Roblox top bar, centred; on a narrow screen it keeps
-- clear of the top-right column (the 💎 pill and the ⚙️ under it). Returns the card's centre x
-- (px from the left), its width (at most `want`) and its top y.
function Ui.topSlotPlace(want: number): (number, number, number)
	local cam = workspace.CurrentCamera
	local vx = if cam then cam.ViewportSize.X else 1280
	local reserve = SLOT.sideReservePx or 134
	local top = GuiService:GetGuiInset().Y + 8
	if want <= vx - 2 * reserve then return vx / 2, want, top end
	local room = vx - reserve - 24
	local w = math.min(want, room)
	return 12 + room / 2, w, top
end

-- The bottom edge of the card now in the spot (or the top bar's), where toasts start.
function Ui.slotBottom(): number
	local id = slotOwner()
	local w = id and slotWants[id]
	local f = w and w.frame
	local top = GuiService:GetGuiInset().Y + 8
	if f and f.Visible and f:FindFirstAncestorOfClass("ScreenGui") and (f:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui).Enabled then
		return math.max(top, f.AbsolutePosition.Y + f.AbsoluteSize.Y + (SLOT.gapPx or 8))
	end
	return top
end

-- Holding toasts (the first minute, D-067): while held, toasts wait in order and show when let go
-- (the newest few only; a kid needn't read a backlog).
local held: { { any } }? = nil
local HOLD_KEEP = 3
-- (AAA Phase 4, D-069; code review N2) A toast that comes soon after a RACE! press is never held: it is
-- the reason the race didn't start ("Both races are full…", a napping horse) and must show at once.
-- Hud calls Ui.racePressed(seconds) as RACE! is pressed.
local holdBypassUntil = -math.huge
function Ui.racePressed(seconds: number)
	holdBypassUntil = math.max(holdBypassUntil, os.clock() + seconds)
end
-- QueueCard sets this while its card shows its own leave ✕ (the dock then hides its ✕: one way to leave).
Ui.queueLeaveShown = false

-- Toasts: short friendly messages that slide in under the top bar and fade away.
local toastGui: ScreenGui? = nil
local toastList: Frame? = nil
local showToast
function Ui.toast(text: string, icon: string?, emoji: string?)
	if held and os.clock() > holdBypassUntil then
		table.insert(held, { text, icon, emoji })
		while #held > HOLD_KEEP do table.remove(held, 1) end
		return
	end
	showToast(text, icon, emoji)
end

function Ui.holdToasts(on: boolean)
	if on then
		held = held or {}
		return
	end
	local waiting = held
	held = nil
	for k, t in waiting or {} do
		task.delay((k - 1) * 0.6, function() showToast(t[1], t[2], t[3]) end)
	end
end

showToast = function(text: string, icon: string?, emoji: string?)
	if not toastGui then
		toastGui = Ui.screen("Toasts", 20)
		local list = Instance.new("Frame")
		list.BackgroundTransparency = 1
		list.AnchorPoint = Vector2.new(0.5, 0)
		list.Position = UDim2.new(0.5, 0, 0, Ui.slotBottom())
		list.Size = UDim2.new(0, 420, 0, 300)
		list.Parent = toastGui
		RunService.Heartbeat:Connect(function()
			local y = Ui.slotBottom()
			if list.Position.Y.Offset ~= y then list.Position = UDim2.new(0.5, 0, 0, y) end
		end)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		toastList = list
	end
	local t = Instance.new("Frame")
	t.Size = UDim2.new(0, 0, 0, 48)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.BackgroundColor3 = Ui.colors.paper
	t.LayoutOrder = math.floor(os.clock() * 100)
	Ui.corner(t, 24)
	Ui.stroke(t, 3)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = t
	local p = Ui.pad(t, 8)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, 14), UDim.new(0, 18)
	if icon or emoji then Ui.icon(t, icon or "", emoji or "💬", UDim2.fromOffset(32, 32)) end
	local label = Ui.text(t, text, 22, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false })
	label.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = toastList
	Ui.pop(t)
	task.delay(3.2, function()
		for _, d in t:GetDescendants() do
			if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end
			if d:IsA("ImageLabel") then TweenService:Create(d, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play() end
			if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play() end
		end
		TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.45)
		t:Destroy()
	end)
end

return Ui
