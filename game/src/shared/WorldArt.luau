--!strict
-- WorldArt (AAA Phase 4, D-069): whole images for Beams, Textures, Decals and particles
-- (bunting_strip, crowd_strip, confetti_square, flag_pennant; tools/ui/make_ui_svgs.py). Each is
-- uploaded as a Decal (UiImages), and AssetService publishes its image id as ReplicatedStorage
-- attribute UiSheet_<name> once loaded. Until then (or if a load fails) `image` returns nil and
-- callers keep their plain-coloured fallback. Works on the server and the client.

local WorldArt = {}

WorldArt.NAMES = { "bunting_strip", "crowd_strip", "confetti_square", "flag_pennant" }

-- "rbxassetid://<image id>" for a world image, or nil while it isn't loaded.
function WorldArt.image(name: string): string?
	local id = game:GetService("ReplicatedStorage"):GetAttribute("UiSheet_" .. name)
	if typeof(id) == "number" and id > 0 then return "rbxassetid://" .. tostring(id) end
	return nil
end

-- Calls fn(image) now if the image is loaded, otherwise once when it arrives.
function WorldArt.whenReady(name: string, fn: (string) -> ())
	local now = WorldArt.image(name)
	if now then
		fn(now)
		return
	end
	local rs = game:GetService("ReplicatedStorage")
	local conn: RBXScriptConnection? = nil
	conn = rs:GetAttributeChangedSignal("UiSheet_" .. name):Connect(function()
		local image = WorldArt.image(name)
		if image and conn then
			conn:Disconnect()
			conn = nil
			fn(image)
		end
	end)
end

return WorldArt
