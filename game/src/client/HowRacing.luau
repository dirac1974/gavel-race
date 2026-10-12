--!nonstrict
-- HowRacing (Find it, D-075): the queue card's ❓ "how racing works" strip. Three pictures built in
-- code (coat dots, gate slots, bots; no uploads), each with one line:
--   "Join a line" · "Riders fill the gate" · "Bots fill spots at 0"
-- It shows by itself once, the first time a kid is in line (saved in the profile as seen_howRacing,
-- findIt.howRacing.autoOnce), and any time from ❓. Close with ✕ or "Got it!".
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local FindIt = require(Shared:WaitForChild("FindIt"))

local HowRacing = {}

local CFG = GameConfig.findIt.howRacing
local C = Ui.colors
local PW, PH = CFG.pictureW, CFG.picturePx
local GAP = 12
local W = 3 * PW + 2 * GAP + 32
local H = 64 + PH + 12 + 64 + 14

local gui = Ui.screen("HowRacing", 13) -- just above the queue card (12)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
local slideIn = Ui.fitPanel(panel, W, H, nil, 16, 64)
Ui.text(panel, "❓ How racing works", 26, { Position = UDim2.new(0, 80, 0, 14), Size = UDim2.new(1, -160, 0, 34) })
local closeBtn = Ui.closeButton(panel)

local function dot(parent: Instance, color: Color3, px: number, pos: UDim2)
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(px, px)
	d.Position = pos
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	Ui.corner(d, px // 2)
	Ui.stroke(d, 2)
	d.Parent = parent
	return d
end

-- A gate of 8 slots (2 × 4) in `parent`; filled: how many have a rider; bots: how many have 🤖.
local function gate(parent: Instance, filled: number, bots: number)
	local g = Instance.new("Frame")
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromOffset(4 * 34 + 3 * 4, 2 * 34 + 4)
	g.Position = UDim2.new(0.5, -(4 * 34 + 3 * 4) / 2, 0, 16)
	g.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(34, 34)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = g
	local coats = { "bay", "grey", "palomino", "black", "chestnut", "appaloosa", "dun", "roan" }
	for k = 1, 8 do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = k
		cell.BackgroundColor3 = if k <= filled + bots then C.white else C.cream
		cell.BorderSizePixel = 0
		Ui.corner(cell, 8)
		Ui.stroke(cell, 2)
		cell.Parent = g
		if k <= filled then
			dot(cell, Ui.coatColors[coats[k]], 20, UDim2.new(0.5, -10, 0.5, -10))
		elseif k <= filled + bots then
			Ui.text(cell, "🤖", 20, { Size = UDim2.fromScale(1, 1), TextScaled = true })
		end
	end
	return g
end

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.fromOffset(3 * PW + 2 * GAP, PH)
row.Position = UDim2.new(0, 16, 0, 64)
row.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = row

local function picture(order: number, caption: string): Frame
	local f = Ui.card(row, UDim2.fromOffset(PW, PH), UDim2.new(), C.cream)
	f.LayoutOrder = order
	-- (code review S7, UI/UX) the caption wraps to two lines and scales 16-18 px so it always fits
	local cap = Ui.text(f, caption, 18, { Position = UDim2.new(0, 4, 1, -44), Size = UDim2.new(1, -8, 0, 40), TextScaled = true })
	local fit = Instance.new("UITextSizeConstraint")
	fit.MinTextSize, fit.MaxTextSize = 16, 18
	fit.Parent = cap
	return f
end

-- 1. Join a line: riders' coat dots in a row, heading for the flag.
do
	local f = picture(1, "Join a line")
	for k, coat in { "bay", "grey", "palomino" } do
		dot(f, Ui.coatColors[coat], 30, UDim2.new(0, 14 + (k - 1) * 38, 0, 40))
	end
	Ui.text(f, "▶", 22, { Position = UDim2.new(0, 124, 0, 42), Size = UDim2.fromOffset(16, 28), TextWrapped = false })
	Ui.icon(f, "flag_ready", "🏁", UDim2.fromOffset(36, 36), UDim2.new(1, -44, 0, 36))
end
-- 2. Riders fill the gate.
do
	local f = picture(2, "Riders fill the gate")
	gate(f, 5, 0)
end
-- 3. Bots fill spots at 0: the gate topped up with 🤖, and the countdown at 0.
do
	local f = picture(3, "Bots fill spots at 0")
	gate(f, 5, 3)
	local zero = dot(f, C.orange, 30, UDim2.new(1, -36, 0, 4))
	Ui.text(zero, "0", 18, { Size = UDim2.fromScale(1, 1), TextWrapped = false })
end

local gotIt = Ui.button(panel, "Got it!", UDim2.fromOffset(200, 64), UDim2.new(0.5, -100, 1, -78), C.orange, 24)

local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
gotIt.Activated:Connect(close)

local function markSeen()
	ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("SetSetting"):FireServer("seen", "howRacing")
end

function HowRacing.open()
	gui.Enabled = true
	slideIn()
end

function HowRacing.isOpen(): boolean
	return gui.Enabled
end

local autoShown = false
-- The first time in line: once, by itself (the profile remembers).
function HowRacing.maybeAuto()
	if autoShown or not CFG.enabled or not CFG.autoOnce then return end
	local d = PlayerState.data
	if not d or FindIt.seen(d.flags, "howRacing") then return end
	autoShown = true
	markSeen()
	HowRacing.open()
end

-- "Race time!" (the gate filled) and your race starting both close it (UI/UX should-fix): the kid sees the call.
ReplicatedStorage:WaitForChild("RaceRemotes"):WaitForChild("RaceTime").OnClientEvent:Connect(function(_course, cancel)
	if not cancel then close() end
end)
-- Your race starting closes it.
game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Racing"):Connect(function()
	if game:GetService("Players").LocalPlayer:GetAttribute("Racing") then close() end
end)

return HowRacing
