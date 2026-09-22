-- ModuleScript: ServerScriptService.WorldZones
-- Attribute/tag driven facility zones. Graceful no-op if Studio assets missing.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local _defaultAssetsModule = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
local DefaultAssets = _defaultAssetsModule and require(_defaultAssetsModule) or nil

local ZONE_TAG = "WorldZone"

local WorldZones = {}
local zonesByName = {} -- [name] = { BasePart, ... }
local warnedMissing = false
local started = false

local function registerPart(part)
	if not part:IsA("BasePart") then
		return
	end
	local zoneName = part:GetAttribute("ZoneName") or part.Name
	if typeof(zoneName) ~= "string" or zoneName == "" then
		return
	end
	part:SetAttribute("ZoneName", zoneName)
	if not CollectionService:HasTag(part, ZONE_TAG) then
		CollectionService:AddTag(part, ZONE_TAG)
	end
	zonesByName[zoneName] = zonesByName[zoneName] or {}
	-- Dedupe: refresh() + tagged scan used to insert the same part twice
	for _, existing in ipairs(zonesByName[zoneName]) do
		if existing == part then
			return
		end
	end
	table.insert(zonesByName[zoneName], part)
end

local function scanFolder(folder)
	if not folder then
		return
	end
	for _, child in folder:GetDescendants() do
		if child:IsA("BasePart") then
			local name = child:GetAttribute("ZoneName") or child.Name
			local matched = false
			for _, expected in ipairs(WorldConfig.ZoneNames) do
				if name == expected or child.Name == expected then
					registerPart(child)
					matched = true
					break
				end
			end
			-- Also register any BasePart that already has ZoneName attribute
			if not matched and child:GetAttribute("ZoneName") then
				registerPart(child)
			end
		end
	end
end

local function scanTycoonZones()
	local tycoons = TycoonService.getTycoonsFolder()
	for _, tycoon in tycoons:GetChildren() do
		local zones = tycoon:FindFirstChild("Zones")
		if zones then
			scanFolder(zones)
		end
	end
end

function WorldZones.getZoneParts(zoneName)
	return zonesByName[zoneName] or {}
end

function WorldZones.getRandomZonePart(preferredNames)
	local names = preferredNames or WorldConfig.ZoneNames
	local candidates = {}
	for _, name in ipairs(names) do
		for _, part in ipairs(zonesByName[name] or {}) do
			if part.Parent then
				table.insert(candidates, part)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

function WorldZones.getAllZoneParts()
	local all = {}
	for _, list in pairs(zonesByName) do
		for _, part in ipairs(list) do
			if part.Parent then
				table.insert(all, part)
			end
		end
	end
	return all
end

function WorldZones.refresh()
	table.clear(zonesByName)
	if DefaultAssets then
		DefaultAssets.ensureWorldZones()
	end
	local root = workspace:FindFirstChild("WorldZones")
	if root then
		scanFolder(root)
	end
	scanTycoonZones()

	-- Tagged parts anywhere in workspace
	for _, part in CollectionService:GetTagged(ZONE_TAG) do
		if part:IsA("BasePart") then
			registerPart(part)
		end
	end

	local count = 0
	for _, list in pairs(zonesByName) do
		count += #list
	end
	if count == 0 and not warnedMissing then
		warnedMissing = true
		warn(
			"[WorldZones] No zone parts found after DefaultAssets.ensureWorldZones() — AI wander will no-op."
		)
	end
	return count
end

function WorldZones.start()
	if started then
		return
	end
	started = true
	WorldZones.refresh()

	local root = workspace:FindFirstChild("WorldZones")
	if root then
		root.DescendantAdded:Connect(function(inst)
			if inst:IsA("BasePart") then
				task.defer(WorldZones.refresh)
			end
		end)
	end

	-- Always ensure Tycoons exists so late pad clones still refresh zones
	local tycoons = TycoonService.getTycoonsFolder()
	tycoons.ChildAdded:Connect(function()
		task.defer(WorldZones.refresh)
	end)
end

return WorldZones
