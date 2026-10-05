--!nonstrict
-- Ui: one look for every new screen (D-023 County Fair Toy): warm paper cards, thick ink
-- outlines, chunky rounded buttons that squash when pressed, Fredoka One text. Icons come
-- from the UI atlas (UiArt) with an emoji fallback until a sheet loads.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiArt = require(script.Parent:WaitForChild("UiArt"))
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
	plum = Color3.fromHex("7D6B91"),
	red = Color3.fromHex("E5484D"),
	white = Color3.new(1, 1, 1),
	shade = Color3.fromHex("C9B99A"),
}
Ui.coatColors = {
	bay = Color3.fromHex("8B4A2B"), chestnut = Color3.fromHex("B5562B"), grey = Color3.fromHex("B9BCC2"),
	black = Color3.fromHex("2B2B30"), palomino = Color3.fromHex("E3C16F"), pinto = Color3.fromHex("9A5A35"),
	appaloosa = Color3.fromHex("EDE6DA"), buckskin = Color3.fromHex("C9A26B"), dun = Color3.fromHex("C8A97E"),
	roan = Color3.fromHex("A8695A"), white = Color3.fromHex("F4F0E8"), chestnut_blaze = Color3.fromHex("B5562B"),
}

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

-- A quick bounce to draw the eye.
function Ui.pop(obj: GuiObject)
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Toasts: short friendly messages that slide in under the top bar and fade away.
local toastGui: ScreenGui? = nil
local toastList: Frame? = nil
function Ui.toast(text: string, icon: string?, emoji: string?)
	if not toastGui then
		toastGui = Ui.screen("Toasts", 20)
		local list = Instance.new("Frame")
		list.BackgroundTransparency = 1
		list.AnchorPoint = Vector2.new(0.5, 0)
		list.Position = UDim2.new(0.5, 0, 0, 64)
		list.Size = UDim2.new(0, 420, 0, 300)
		list.Parent = toastGui
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
	if icon or emoji then Ui.icon(t, icon or "", emoji or "⭐", UDim2.fromOffset(32, 32)) end
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
