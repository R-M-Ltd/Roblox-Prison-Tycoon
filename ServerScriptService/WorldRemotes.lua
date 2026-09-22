-- ModuleScript: ServerScriptService.WorldRemotes
-- Owner-only world remotes (lockdown). Validates ownership like PurchaseHandler.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local SecurityWorld = require(script.Parent:WaitForChild("SecurityWorld", 30))

local WorldRemotes = {}

local DEBOUNCE = {} -- [userId] = true
local DEBOUNCE_TIME = 1
local started = false
local hookedLockdownButtons = {} -- [part] = true

local function getRemotesFolder()
	local name = WorldConfig.RemotesFolderName or "WorldRemotes"
	local folder = ReplicatedStorage:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function ensureRemote(folder, name)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local function ownerTycoon(player)
	return TycoonService.getPlayerTycoon(player)
end

function WorldRemotes.start()
	if started then
		return
	end
	started = true

	local folder = getRemotesFolder()
	local requestLockdown = ensureRemote(folder, "RequestLockdown")
	local requestEndLockdown = ensureRemote(folder, "RequestEndLockdown")
	local lockdownState = ensureRemote(folder, "LockdownState") -- server → client notify

	requestLockdown.OnServerEvent:Connect(function(player, duration)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		local userId = player.UserId
		if DEBOUNCE[userId] then
			return
		end
		DEBOUNCE[userId] = true
		task.delay(DEBOUNCE_TIME, function()
			DEBOUNCE[userId] = nil
		end)

		local tycoon = ownerTycoon(player)
		if not tycoon then
			return
		end
		if tycoon:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end

		local dur = duration
		if typeof(dur) ~= "number" then
			dur = WorldConfig.LockdownDefaultDuration
		end
		-- Clamp abuse
		dur = math.clamp(dur, 5, 120)

		local ok, reason = SecurityWorld.startLockdown(tycoon, dur)
		lockdownState:FireClient(player, {
			Active = ok == true,
			Reason = reason,
			Duration = dur,
			TycoonName = tycoon.Name,
		})
	end)

	requestEndLockdown.OnServerEvent:Connect(function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		local tycoon = ownerTycoon(player)
		if not tycoon then
			return
		end
		if tycoon:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		SecurityWorld.endLockdown(tycoon)
		lockdownState:FireClient(player, {
			Active = false,
			Reason = "ended",
			TycoonName = tycoon.Name,
		})
	end)

	-- Optional: touch-pad lockdown button (attribute LockdownButton=true on a Part)
	local function hookLockdownButton(part)
		if not part:IsA("BasePart") then
			return
		end
		if part:GetAttribute("LockdownButton") ~= true then
			return
		end
		if hookedLockdownButtons[part] then
			return
		end
		hookedLockdownButtons[part] = true
		part.Destroying:Connect(function()
			hookedLockdownButtons[part] = nil
		end)
		part.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			local tycoon = TycoonService.getTycoonFromInstance(part) or ownerTycoon(player)
			if not tycoon or tycoon:GetAttribute("OwnerUserId") ~= player.UserId then
				return
			end
			if DEBOUNCE[player.UserId] then
				return
			end
			DEBOUNCE[player.UserId] = true
			task.delay(DEBOUNCE_TIME, function()
				DEBOUNCE[player.UserId] = nil
			end)
			SecurityWorld.startLockdown(tycoon, WorldConfig.LockdownDefaultDuration)
		end)
	end

	for _, tycoon in TycoonService.getTycoonsFolder():GetChildren() do
		for _, desc in tycoon:GetDescendants() do
			if desc:GetAttribute("LockdownButton") == true then
				hookLockdownButton(desc)
			end
		end
		tycoon.DescendantAdded:Connect(function(desc)
			if desc:GetAttribute("LockdownButton") == true then
				hookLockdownButton(desc)
			end
		end)
	end
	TycoonService.getTycoonsFolder().ChildAdded:Connect(function(tycoon)
		task.defer(function()
			for _, desc in tycoon:GetDescendants() do
				if desc:GetAttribute("LockdownButton") == true then
					hookLockdownButton(desc)
				end
			end
			tycoon.DescendantAdded:Connect(function(desc)
				if desc:GetAttribute("LockdownButton") == true then
					hookLockdownButton(desc)
				end
			end)
		end)
	end)
end

return WorldRemotes
