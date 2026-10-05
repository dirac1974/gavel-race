--!nonstrict
-- Guide (D-035, D-043): glowing hoofprints on the ground from you to a place, for every GO
-- button. Uses PathfindingService so the trail goes round fences and buildings, redraws as
-- you move, and clears itself when you arrive. Hoofprints are local parts only you can see.
--   Guide.to(x, z, label?)   Guide.clear()

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Guide = {}

local player = Players.LocalPlayer
local SPACING = 5
local ARRIVE = 12
local GOLD = Color3.fromHex("FFD23F")

local folder: Folder? = nil
local target: Vector3? = nil
local prints: { BasePart } = {}
local lastPathAt = 0
local lastFrom: Vector3? = nil
local conn: RBXScriptConnection? = nil
local path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 7, AgentCanJump = false, WaypointSpacing = SPACING })

local function rootPos(): Vector3?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function clearPrints()
	for _, p in prints do p:Destroy() end
	table.clear(prints)
end

local function stamp(pos: Vector3, dir: Vector3, k: number)
	local p = Instance.new("Part")
	p.Name = "Hoofprint"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.12, 1.5, 1.2)
	local side = if k % 2 == 0 then 0.7 else -0.7
	local right = dir:Cross(Vector3.yAxis)
	local at = pos + right * side
	p.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(0, 0, math.pi / 2)
	p:SetAttribute("K", k)
	p.Parent = folder
	table.insert(prints, p)
end

local function draw(points: { Vector3 })
	clearPrints()
	local k = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = b - a
		local len = Vector3.new(seg.X, 0, seg.Z).Magnitude
		if len > 0.1 then
			local dir = Vector3.new(seg.X, 0, seg.Z).Unit
			local n = math.max(1, math.floor(len / SPACING))
			for j = 0, n - 1 do
				local p = a + seg * (j / n)
				stamp(Vector3.new(p.X, p.Y - 2.6 + 0.1, p.Z), dir, k)
				k += 1
				if k > 160 then return end
			end
		end
	end
end

local function recompute()
	local from = rootPos()
	if not from or not target then return end
	lastPathAt, lastFrom = os.clock(), from
	local ok = pcall(function() path:ComputeAsync(from, target) end)
	local points = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in path:GetWaypoints() do table.insert(points, w.Position + Vector3.new(0, 2.6, 0)) end
	else
		points = { from, Vector3.new(target.X, from.Y, target.Z) } -- straight line if no path
	end
	draw(points)
end

function Guide.clear()
	target = nil
	clearPrints()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

function Guide.to(x: number, z: number)
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "GuidePrints"
		folder.Parent = workspace
	end
	target = Vector3.new(x, 0, z)
	recompute()
	if conn then conn:Disconnect() end
	conn = RunService.Heartbeat:Connect(function()
		local pos = rootPos()
		if not pos or not target then return end
		if Vector3.new(pos.X - target.X, 0, pos.Z - target.Z).Magnitude < ARRIVE then
			Guide.clear()
			return
		end
		-- Redraw every couple of seconds or after moving away from the trail start.
		if os.clock() - lastPathAt > 2.5 or (lastFrom and (pos - lastFrom).Magnitude > 25) then
			task.spawn(recompute)
			lastPathAt = os.clock()
		end
		-- A wave of light running along the prints toward the goal.
		local t = os.clock() * 8
		for _, p in prints do
			local k = p:GetAttribute("K") or 0
			p.Transparency = 0.15 + 0.55 * (0.5 + 0.5 * math.sin((k - t) * 0.5))
		end
	end)
end

return Guide
