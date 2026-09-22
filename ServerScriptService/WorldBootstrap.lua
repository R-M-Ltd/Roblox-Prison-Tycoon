-- Script: ServerScriptService.WorldBootstrap
-- Start order for the world / facility layer. Creates runtime folders; inits safely.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

-- ModuleScripts live alongside this Script in ServerScriptService
local FacilityClock = require(script.Parent:WaitForChild("FacilityClock"))
local WorldZones = require(script.Parent:WaitForChild("WorldZones"))
local SecurityWorld = require(script.Parent:WaitForChild("SecurityWorld"))
local InmateWorldAI = require(script.Parent:WaitForChild("InmateWorldAI"))
local StaffSpawner = require(script.Parent:WaitForChild("StaffSpawner"))
local EscapeAttempt = require(script.Parent:WaitForChild("EscapeAttempt"))
local WorldRemotes = require(script.Parent:WaitForChild("WorldRemotes"))

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

-- Optional empty Studio hooks so the place has discoverable names
local function ensureOptionalWorkspaceHooks()
	ensureFolder(workspace, "WorldZones")
	-- Do not create GuardSpawns / EscapePoints automatically — docs describe them.
end

local worldState = ensureWorldState()
if worldState:GetAttribute("WorldBootstrapped") == true then
	-- Attribute may be persisted in a saved place file; module start()s are idempotent.
	warn("[WorldBootstrap] WorldBootstrapped already true — re-calling idempotent starts.")
end

print("[WorldBootstrap] Starting world layer…")

ensureRemotesFolder()
ensureOptionalWorkspaceHooks()

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
