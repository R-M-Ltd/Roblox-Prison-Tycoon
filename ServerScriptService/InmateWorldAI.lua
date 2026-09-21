-- ModuleScript: ServerScriptService.InmateWorldAI
-- Lightweight wander AI for ActiveInmates. Cheap stepped loop; no pathfinding.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))
local WorldZones = require(script.Parent:WaitForChild("WorldZones"))
local SecurityWorld = require(script.Parent:WaitForChild("SecurityWorld"))

local InmateWorldAI = {}
local running = false

local WANDER_ZONES = { "Yard", "Cafeteria", "Infirmary", "Intake", "CellBlock" }

local function getRoot(inmate)
	if inmate:IsA("Model") then
		return inmate.PrimaryPart or inmate:FindFirstChildWhichIsA("BasePart", true)
	elseif inmate:IsA("BasePart") then
		return inmate
	end
	return nil
end

local function pushToward(root, targetPos, speed)
	if not root or root.Anchored then
		return
	end
	local delta = targetPos - root.Position
	delta = Vector3.new(delta.X, 0, delta.Z)
	if delta.Magnitude < 1 then
		return
	end
	local dir = delta.Unit
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
end

local function pickTarget(inmate, tycoon)
	-- Prefer zones under this tycoon, else global WorldZones
	local zonesFolder = tycoon:FindFirstChild("Zones")
	if zonesFolder then
		local parts = {}
		for _, name in ipairs(WANDER_ZONES) do
			local z = zonesFolder:FindFirstChild(name)
			if z and z:IsA("BasePart") then
				table.insert(parts, z)
			elseif z then
				local p = z:IsA("Model") and (z.PrimaryPart or z:FindFirstChildWhichIsA("BasePart", true))
				if p then
					table.insert(parts, p)
				end
			end
		end
		if #parts > 0 then
			return parts[math.random(1, #parts)]
		end
	end
	return WorldZones.getRandomZonePart(WANDER_ZONES)
end

local function stepTycoon(tycoon)
	if SecurityWorld.isLockdown(tycoon) then
		return
	end
	local folder = tycoon:FindFirstChild("ActiveInmates")
	if not folder then
		return
	end

	local inmates = folder:GetChildren()
	local maxN = WorldConfig.MaxInmatesProcessedPerStep or 8
	local processed = 0
	local chance = WorldConfig.InmateWanderChance or 0.35
	local speed = WorldConfig.InmateWanderSpeed or 8

	-- Shuffle-ish: start at random offset
	local start = (#inmates > 0) and math.random(1, #inmates) or 1
	for i = 1, #inmates do
		if processed >= maxN then
			break
		end
		local idx = ((start + i - 2) % #inmates) + 1
		local inmate = inmates[idx]
		if inmate:GetAttribute("Escaping") == true then
			continue
		end
		if math.random() > chance then
			continue
		end
		local root = getRoot(inmate)
		if not root then
			continue
		end
		local target = pickTarget(inmate, tycoon)
		if target then
			inmate:SetAttribute("AIState", "Wander")
			inmate:SetAttribute("AIZone", target:GetAttribute("ZoneName") or target.Name)
			pushToward(root, target.Position, speed)
			processed += 1
		end
	end
end

function InmateWorldAI.start()
	if running then
		return
	end
	running = true

	local interval = WorldConfig.InmateAIStepInterval or 1.5
	task.spawn(function()
		while running do
			task.wait(interval)
			for _, tycoon in TycoonService.getTycoonsFolder():GetChildren() do
				local ownerId = tycoon:GetAttribute("OwnerUserId")
				if typeof(ownerId) == "number" and ownerId ~= 0 then
					stepTycoon(tycoon)
				end
			end
		end
	end)
end

function InmateWorldAI.stop()
	running = false
end

return InmateWorldAI
