--!nonstrict
-- UiArt: puts playtest UI art (D-023) on ImageLabels from the atlas sheets. A sheet's
-- image id arrives as ReplicatedStorage attribute UiSheet_<sheet> once AssetService has
-- resolved it (after Roblox moderation). Until then the label stays hidden and the
-- caller's placeholder shapes show; when it arrives, onReady runs so the caller can hide
-- the placeholder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAtlas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiAtlas"))

local UiArt = {}

local function sheetId(name: string): (number?, any)
	local rect = UiAtlas[name]
	if not rect then return nil, nil end
	return ReplicatedStorage:GetAttribute("UiSheet_" .. rect.sheet), rect
end

function UiArt.ready(name: string): boolean
	return (sheetId(name)) ~= nil
end

-- Set `label` to atlas image `name` now if possible; returns true if it was set.
function UiArt.set(label: ImageLabel, name: string): boolean
	local id, rect = sheetId(name)
	if not id then
		label.Visible = false
		return false
	end
	label.Image = "rbxassetid://" .. id
	label.ImageRectOffset = Vector2.new(rect.x, rect.y)
	label.ImageRectSize = Vector2.new(rect.w, rect.h)
	label.Visible = true
	return true
end

-- An ImageLabel filling `parent`, showing `name` as soon as its sheet is ready.
function UiArt.attach(parent: GuiObject, name: string, zIndex: number?, onReady: (() -> ())?): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Art"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.ScaleType = Enum.ScaleType.Fit
	label.ZIndex = zIndex or (parent.ZIndex + 1)
	label.Visible = false
	label.Parent = parent
	local function try()
		if UiArt.set(label, name) and onReady then onReady() end
	end
	try()
	local rect = UiAtlas[name]
	if rect and not label.Visible then
		local conn
		conn = ReplicatedStorage:GetAttributeChangedSignal("UiSheet_" .. rect.sheet):Connect(function()
			try()
			if label.Visible then conn:Disconnect() end
		end)
	end
	return label
end

return UiArt
