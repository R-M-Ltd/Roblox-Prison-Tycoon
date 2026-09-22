-- ModuleScript: ServerScriptService.SecurityWorld
-- Lockdown server API. Sets attributes InmateDropper (and AI) can respect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))

local SecurityWorld = {}

local lockdownUntil = {} -- [tycoon] = os.clock deadline
local cooldownUntil = {} -- [tycoon] = os.clock
local bindable = nil
local started = false

local function ensureBindable()
	if bindable and bindable.Parent then
		return bindable
	end
	local folder = ReplicatedStorage:FindFirstChild(WorldConfig.RemotesFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WorldConfig.RemotesFolderName
		folder.Parent = ReplicatedStorage
	end
	bindable = folder:FindFirstChild("LockdownChanged")
	if not bindable then
		bindable = Instance.new("BindableEvent")
		bindable.Name = "LockdownChanged"
		bindable.Parent = folder
	end
	return bindable
end

local function setLockdownAttributes(tycoon, active, remaining)
	tycoon:SetAttribute("LockdownActive", active == true)
	tycoon:SetAttribute("LockdownRemaining", remaining or 0)
	-- Global mirror for systems that only check WorldState
	local worldState = workspace:FindFirstChild(WorldConfig.WorldStateName)
	if worldState then
		-- Any-tycoon lockdown flag (true if at least one pad locked down)
		local any = false
		for _, t in TycoonService.getTycoonsFolder():GetChildren() do
			if t:GetAttribute("LockdownActive") == true then
				any = true
				break
			end
		end
		worldState:SetAttribute("AnyLockdown", any)
	end
end

function SecurityWorld.isLockdown(tycoon)
	if not tycoon then
		return false
	end
	return tycoon:GetAttribute("LockdownActive") == true
end

function SecurityWorld.endLockdown(tycoon)
	if not tycoon or not tycoon.Parent then
		return
	end
	local wasActive = lockdownUntil[tycoon] ~= nil or tycoon:GetAttribute("LockdownActive") == true
	lockdownUntil[tycoon] = nil
	setLockdownAttributes(tycoon, false, 0)
	-- Always start cooldown when leaving an active lockdown (tick, delay, or remote end)
	if wasActive then
		cooldownUntil[tycoon] = os.clock() + (WorldConfig.LockdownCooldown or 15)
	end
	local ev = ensureBindable()
	ev:Fire(tycoon, false)
end

function SecurityWorld.startLockdown(tycoon, duration)
	if not tycoon or not tycoon.Parent then
		return false, "missing_tycoon"
	end
	local now = os.clock()
	if SecurityWorld.isLockdown(tycoon) then
		return false, "already_active"
	end
	local cd = cooldownUntil[tycoon]
	if cd and now < cd then
		return false, "cooldown"
	end

	local dur = duration
	if typeof(dur) ~= "number" or dur <= 0 then
		dur = WorldConfig.LockdownDefaultDuration
	end

	lockdownUntil[tycoon] = now + dur
	setLockdownAttributes(tycoon, true, dur)
	local ev = ensureBindable()
	ev:Fire(tycoon, true)

	task.delay(dur, function()
		if lockdownUntil[tycoon] and os.clock() >= lockdownUntil[tycoon] - 0.05 then
			SecurityWorld.endLockdown(tycoon)
		end
	end)

	return true
end

function SecurityWorld.start()
	if started then
		return
	end
	started = true
	ensureBindable()

	-- Tick remaining attribute for UI / debugging
	task.spawn(function()
		while started do
			task.wait(1)
			local now = os.clock()
			for tycoon, deadline in pairs(lockdownUntil) do
				if not tycoon.Parent then
					lockdownUntil[tycoon] = nil
				elseif now >= deadline then
					SecurityWorld.endLockdown(tycoon)
				else
					setLockdownAttributes(tycoon, true, math.max(0, deadline - now))
				end
			end
		end
	end)

	-- Clean up on pad destroy / reclaim
	local folder = TycoonService.getTycoonsFolder()
	folder.ChildRemoved:Connect(function(tycoon)
		lockdownUntil[tycoon] = nil
		cooldownUntil[tycoon] = nil
	end)
end

return SecurityWorld
