-- Script: ServerScriptService.WorldBootstrap
-- Start order for the world / facility layer. Creates runtime folders; inits safely.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig", 30))
local _defaultAssetsModule = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
local DefaultAssets = _defaultAssetsModule and require(_defaultAssetsModule) or nil

-- ModuleScripts live alongside this Script in ServerScriptService
local FacilityClock = require(script.Parent:WaitForChild("FacilityClock", 30))
local WorldZones = require(script.Parent:WaitForChild("WorldZones", 30))
local SecurityWorld = require(script.Parent:WaitForChild("SecurityWorld", 30))
local InmateWorldAI = require(script.Parent:WaitForChild("InmateWorldAI", 30))
local StaffSpawner = require(script.Parent:WaitForChild("StaffSpawner", 30))
local EscapeAttempt = require(script.Parent:WaitForChild("EscapeAttempt", 30))
local WorldRemotes = require(script.Parent:WaitForChild("WorldRemotes", 30))

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function ensureWorldState()
	local name = WorldConfig.WorldStateName or "WorldState"
	local state = workspace:FindFirstChild(name)
	if not state then
		state = Instance.new("Folder")
		state.Name = name
		state.Parent = workspace
	end
	-- Documented attributes (defaults)
	if state:GetAttribute("IsNight") == nil then
		state:SetAttribute("IsNight", false)
	end
	if state:GetAttribute("TimeOfDayFraction") == nil then
		state:SetAttribute("TimeOfDayFraction", 0)
	end
	if state:GetAttribute("ClockTime") == nil then
		state:SetAttribute("ClockTime", 0)
	end
	if state:GetAttribute("AnyLockdown") == nil then
		state:SetAttribute("AnyLockdown", false)
	end
	if state:GetAttribute("EscapeAttempts") == nil then
		state:SetAttribute("EscapeAttempts", 0)
	end
	if state:GetAttribute("WorldBootstrapped") == nil then
		state:SetAttribute("WorldBootstrapped", false)
	end
	return state
end

local function ensureRemotesFolder()
	local name = WorldConfig.RemotesFolderName or "WorldRemotes"
	return ensureFolder(ReplicatedStorage, name)
end

local function ensureOptionalWorkspaceHooks()
	-- Prefer DefaultAssets (creates zone Parts if empty); folder-only fallback otherwise
	if DefaultAssets then
		DefaultAssets.ensureWorld()
	else
		ensureFolder(workspace, "WorldZones")
	end
end

local worldState = ensureWorldState()
if worldState:GetAttribute("WorldBootstrapped") == true then
	-- Attribute may be persisted in a saved place file; module start()s are idempotent.
	warn("[WorldBootstrap] WorldBootstrapped already true — re-calling idempotent starts.")
end

print("[WorldBootstrap] Starting world layer…")

ensureRemotesFolder()
ensureOptionalWorkspaceHooks() -- includes DefaultAssets.ensureWorld() when available

-- Start order: clock → zones → security → remotes → AI → staff → escape
FacilityClock.start(worldState)
WorldZones.start()
SecurityWorld.start()
WorldRemotes.start()
InmateWorldAI.start()
StaffSpawner.start()
EscapeAttempt.start()

worldState:SetAttribute("WorldBootstrapped", true)
print("[WorldBootstrap] World layer ready.")
