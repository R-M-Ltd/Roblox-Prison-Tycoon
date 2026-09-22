-- ModuleScript: ServerScriptService.EscapeAttempt
-- Rare night-time escape attempts toward EscapePoint if present.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local _defaultAssetsModule = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
local DefaultAssets = _defaultAssetsModule and require(_defaultAssetsModule) or nil
local FacilityClock = require(script.Parent:WaitForChild("FacilityClock", 30))
local SecurityWorld = require(script.Parent:WaitForChild("SecurityWorld", 30))

local EscapeAttempt = {}
local running = false

local function findEscapePoint(tycoon)
	-- Per-tycoon only: a shared Workspace.EscapePoint would send every pad's
	-- escapees to one spot and couple multi-pad economy/AI incorrectly.
	if DefaultAssets then
		DefaultAssets.ensurePadParts(tycoon)
	end
	local p = tycoon:FindFirstChild("EscapePoint", true)
	if p and p:IsA("BasePart") then
		return p
	end
	local folder = tycoon:FindFirstChild("EscapePoints")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				return child
			end
		end
	end
	return nil
end

local function getRoot(inmate)
	if inmate:IsA("Model") then
		return inmate.PrimaryPart or inmate:FindFirstChildWhichIsA("BasePart", true)
	elseif inmate:IsA("BasePart") then
		return inmate
	end
	return nil
end

local function tryEscape(tycoon)
	if SecurityWorld.isLockdown(tycoon) then
		return
	end
	if not FacilityClock.isNight() then
		return
	end

	local escapePoint = findEscapePoint(tycoon)
	if not escapePoint then
		return
	end

	local folder = tycoon:FindFirstChild("ActiveInmates")
	if not folder then
		return
	end
	local inmates = folder:GetChildren()
	if #inmates == 0 then
		return
	end

	local chance = WorldConfig.EscapeChancePerCheck or 0.03
	if math.random() > chance then
		return
	end

	local inmate = inmates[math.random(1, #inmates)]
	if inmate:GetAttribute("Escaping") == true then
		return
	end

	local root = getRoot(inmate)
	if not root or root.Anchored then
		return
	end

	inmate:SetAttribute("Escaping", true)
	inmate:SetAttribute("AIState", "Escape")
	local speed = WorldConfig.EscapeSpeed or 14
	local delta = escapePoint.Position - root.Position
	delta = Vector3.new(delta.X, 0, delta.Z)
	if delta.Magnitude > 0.1 then
		local dir = delta.Unit
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, 4, dir.Z * speed)
	end

	-- Despawn after flee window (escaped / removed from pad economy)
	local life = WorldConfig.EscapeDespawnSeconds or 20
	Debris:AddItem(inmate, life)

	local worldState = workspace:FindFirstChild(WorldConfig.WorldStateName)
	if worldState then
		local n = worldState:GetAttribute("EscapeAttempts") or 0
		worldState:SetAttribute("EscapeAttempts", n + 1)
	end
end

function EscapeAttempt.start()
	if running then
		return
	end
	running = true

	local interval = WorldConfig.EscapeCheckInterval or 25
	task.spawn(function()
		while running do
			task.wait(interval)
			if FacilityClock.isNight() then
				for _, tycoon in TycoonService.getTycoonsFolder():GetChildren() do
					local ownerId = tycoon:GetAttribute("OwnerUserId")
					if typeof(ownerId) == "number" and ownerId ~= 0 then
						tryEscape(tycoon)
					end
				end
			end
		end
	end)
end

function EscapeAttempt.stop()
	running = false
end

return EscapeAttempt
