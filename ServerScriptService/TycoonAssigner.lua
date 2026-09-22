-- Script: ServerScriptService.TycoonAssigner
-- Clones pads to spawns, handles claim, destroys + reclones on leave.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local TycoonVisibility = require(ReplicatedStorage:WaitForChild("TycoonVisibility", 30))
local _defaultAssetsModule = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
local DefaultAssets = _defaultAssetsModule and require(_defaultAssetsModule)
if not DefaultAssets then
	error("[TycoonAssigner] DefaultAssets module required")
end

DefaultAssets.ensureAll()

local template = ServerStorage:FindFirstChild("TycoonTemplate")
	or ServerStorage:WaitForChild("TycoonTemplate", 5)
if not template then
	DefaultAssets.ensureTycoonTemplate()
	template = ServerStorage:WaitForChild("TycoonTemplate", 5)
end
if not template then
	error("[TycoonAssigner] TycoonTemplate missing even after DefaultAssets")
end

local spawnsFolder = workspace:FindFirstChild("TycoonSpawns")
	or workspace:WaitForChild("TycoonSpawns", 5)
if not spawnsFolder then
	DefaultAssets.ensureTycoonSpawns()
	spawnsFolder = workspace:WaitForChild("TycoonSpawns", 5)
end
if not spawnsFolder then
	error("[TycoonAssigner] TycoonSpawns missing even after DefaultAssets")
end

local padBySpawn = {}
local spawnByUserId = {}

local function prepareFreshTycoon(tycoon)
	tycoon:SetAttribute("IsTycoon", true)
	tycoon:SetAttribute("OwnerUserId", 0)

	DefaultAssets.ensurePadParts(tycoon)
	TycoonVisibility.applyFreshUnlockState(tycoon)

	local claim = tycoon:FindFirstChild("ClaimPad", true)
	if claim and claim:IsA("BasePart") then
		claim.Transparency = 0
		claim.CanCollide = false
		claim:SetAttribute("Claimable", true)
	end

	local active = tycoon:FindFirstChild("ActiveInmates")
	if active then
		active:ClearAllChildren()
	else
		active = Instance.new("Folder")
		active.Name = "ActiveInmates"
		active.Parent = tycoon
	end
end

local function placeAtSpawn(spawnPart, index)
	local tycoon = template:Clone()
	tycoon.Name = "Tycoon_" .. tostring(index)
	tycoon:SetAttribute("SpawnName", spawnPart.Name)

	local pivotPart = tycoon.PrimaryPart or tycoon:FindFirstChildWhichIsA("BasePart", true)
	if not pivotPart then
		warn("TycoonTemplate needs at least one BasePart")
		tycoon:Destroy()
		return nil
	end
	tycoon.PrimaryPart = pivotPart
	tycoon:PivotTo(spawnPart.CFrame)

	prepareFreshTycoon(tycoon)
	tycoon.Parent = TycoonService.getTycoonsFolder()
	return tycoon
end

local function hookClaimPad(tycoon, spawnPart)
	local claim = tycoon:FindFirstChild("ClaimPad", true)
	if not claim or not claim:IsA("BasePart") then
		warn("Tycoon missing ClaimPad:", tycoon.Name)
		return
	end

	claim.Touched:Connect(function(hit)
		if claim:GetAttribute("Claimable") ~= true then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		if spawnByUserId[player.UserId] then
			return
		end
		if tycoon:GetAttribute("OwnerUserId") ~= 0 then
			return
		end

		tycoon:SetAttribute("OwnerUserId", player.UserId)
		spawnByUserId[player.UserId] = spawnPart
		claim.Transparency = 1
		claim:SetAttribute("Claimable", false)

		local playerSpawn = tycoon:FindFirstChild("PlayerSpawn", true)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if playerSpawn and playerSpawn:IsA("BasePart") and hrp then
			hrp.CFrame = playerSpawn.CFrame + Vector3.new(0, 3, 0)
		end
	end)
end

local function respawnPad(spawnPart, index)
	local old = padBySpawn[spawnPart]
	if old then
		old:Destroy()
		padBySpawn[spawnPart] = nil
	end

	local tycoon = placeAtSpawn(spawnPart, index)
	if not tycoon then
		return nil
	end

	padBySpawn[spawnPart] = tycoon
	hookClaimPad(tycoon, spawnPart)
	return tycoon
end

local spawnParts = spawnsFolder:GetChildren()
table.sort(spawnParts, function(a, b)
	return a.Name < b.Name
end)

for i, spawnPart in ipairs(spawnParts) do
	if spawnPart:IsA("BasePart") then
		respawnPad(spawnPart, i)
	end
end

local function spawnIndex(spawnPart)
	for i, part in ipairs(spawnParts) do
		if part == spawnPart then
			return i
		end
	end
	return 0
end

Players.PlayerRemoving:Connect(function(player)
	local spawnPart = spawnByUserId[player.UserId]
	spawnByUserId[player.UserId] = nil
	if not spawnPart then
		return
	end
	respawnPad(spawnPart, spawnIndex(spawnPart))
end)
