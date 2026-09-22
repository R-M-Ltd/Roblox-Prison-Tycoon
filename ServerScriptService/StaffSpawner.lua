-- ModuleScript: ServerScriptService.StaffSpawner
-- Spawns guards at GuardSpawn / waypoints when Studio assets exist.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local _defaultAssetsModule = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
local DefaultAssets = _defaultAssetsModule and require(_defaultAssetsModule) or nil

local StaffSpawner = {}
local hooked = {}
local started = false

local function getGuardTemplate()
	local t = ServerStorage:FindFirstChild("GuardTemplate")
	if t then
		return t
	end
	if DefaultAssets then
		DefaultAssets.ensureGuardTemplate()
		t = ServerStorage:FindFirstChild("GuardTemplate")
	end
	if not t then
		warn("[StaffSpawner] ServerStorage.GuardTemplate missing after DefaultAssets.")
	end
	return t
end

local function findSpawns(tycoon)
	if DefaultAssets then
		DefaultAssets.ensurePadParts(tycoon)
	end
	local spawns = {}
	local named = tycoon:FindFirstChild("GuardSpawn", true)
	if named and named:IsA("BasePart") then
		table.insert(spawns, named)
	end
	local folder = tycoon:FindFirstChild("GuardSpawns") or tycoon:FindFirstChild("StaffSpawns")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end
	-- Intentionally NOT using Workspace.GuardSpawns here: shared world spawns
	-- would be claimed by every pad and stack duplicate guards at one spot.
	return spawns
end

local function findWaypoints(tycoon)
	local points = {}
	local folder = tycoon:FindFirstChild("GuardWaypoints") or workspace:FindFirstChild("GuardWaypoints")
	if not folder then
		return points
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	return points
end

local function getOrCreateStaffFolder(tycoon)
	local folder = tycoon:FindFirstChild("ActiveStaff")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActiveStaff"
		folder.Parent = tycoon
	end
	return folder
end

local function spawnGuard(tycoon, spawnPart, index)
	local template = getGuardTemplate()
	if not template then
		return nil
	end
	local guard = template:Clone()
	guard.Name = "Guard_" .. tostring(index)
	guard:SetAttribute("IsStaff", true)
	guard:SetAttribute("StaffRole", "Guard")

	local root = guard:IsA("Model")
			and (guard.PrimaryPart or guard:FindFirstChildWhichIsA("BasePart", true))
		or (guard:IsA("BasePart") and guard)
	if not root then
		guard:Destroy()
		warn("[StaffSpawner] GuardTemplate needs a BasePart / PrimaryPart")
		return nil
	end
	if guard:IsA("Model") then
		guard.PrimaryPart = root
		guard:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	else
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	if root:IsA("BasePart") then
		root.Anchored = false
	end

	guard.Parent = getOrCreateStaffFolder(tycoon)
	return guard, root
end

local function runWander(tycoon, guard, root)
	local waypoints = findWaypoints(tycoon)
	local interval = WorldConfig.StaffWanderInterval or 6
	local speed = WorldConfig.StaffWanderSpeed or 10

	task.spawn(function()
		while guard.Parent and tycoon.Parent do
			task.wait(interval)
			if not root or not root.Parent then
				break
			end
			if tycoon:GetAttribute("LockdownActive") == true then
				-- Hold position during lockdown
				continue
			end
			local target
			if #waypoints > 0 then
				target = waypoints[math.random(1, #waypoints)]
			else
				local spawns = findSpawns(tycoon)
				if #spawns > 0 then
					target = spawns[math.random(1, #spawns)]
				end
			end
			if target and not root.Anchored then
				local delta = target.Position - root.Position
				delta = Vector3.new(delta.X, 0, delta.Z)
				if delta.Magnitude > 1 then
					local dir = delta.Unit
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
				end
			end
		end
	end)
end

local function clearStaff(tycoon)
	local folder = tycoon:FindFirstChild("ActiveStaff")
	if folder then
		folder:ClearAllChildren()
	end
end

local function populate(tycoon)
	clearStaff(tycoon)
	local ownerId = tycoon:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" or ownerId == 0 then
		return
	end

	local spawns = findSpawns(tycoon)
	if #spawns == 0 then
		if tycoon:GetAttribute("_StaffSpawnWarned") ~= true then
			tycoon:SetAttribute("_StaffSpawnWarned", true)
			warn("[StaffSpawner] No GuardSpawn on", tycoon.Name, "— skipping.")
		end
		return
	end

	local count = math.min(WorldConfig.StaffPerTycoon or 2, #spawns)
	for i = 1, count do
		local spawnPart = spawns[((i - 1) % #spawns) + 1]
		local guard, root = spawnGuard(tycoon, spawnPart, i)
		if guard and root then
			runWander(tycoon, guard, root)
		end
	end
end

local function hookTycoon(tycoon)
	if hooked[tycoon] then
		return
	end
	hooked[tycoon] = true

	tycoon:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		populate(tycoon)
	end)
	tycoon.Destroying:Connect(function()
		hooked[tycoon] = nil
	end)

	if typeof(tycoon:GetAttribute("OwnerUserId")) == "number" and tycoon:GetAttribute("OwnerUserId") ~= 0 then
		populate(tycoon)
	end
end

function StaffSpawner.start()
	if started then
		return
	end
	started = true
	local folder = TycoonService.getTycoonsFolder()
	for _, tycoon in folder:GetChildren() do
		hookTycoon(tycoon)
	end
	folder.ChildAdded:Connect(hookTycoon)
end

return StaffSpawner
