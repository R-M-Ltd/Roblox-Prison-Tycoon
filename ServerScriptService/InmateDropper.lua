-- Script: ServerScriptService.InmateDropper
-- Per-pad dropper loops; spawn only when claimed; ActiveInmates per pad.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))

local DEFAULT_INTERVAL = 3
local MAX_INMATES_PER_TYCOON = 25
local INMATE_LIFETIME = 60

local template = ServerStorage:WaitForChild("InmateTemplate")
local hooked = {}

local function getOrCreateActiveFolder(tycoon)
	local folder = tycoon:FindFirstChild("ActiveInmates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActiveInmates"
		folder.Parent = tycoon
	end
	return folder
end

local function countInmates(tycoon)
	local folder = tycoon:FindFirstChild("ActiveInmates")
	return folder and #folder:GetChildren() or 0
end

local function isClaimed(tycoon)
	local ownerId = tycoon:GetAttribute("OwnerUserId")
	return typeof(ownerId) == "number" and ownerId ~= 0
end

local function getAimPosition(tycoon, dropper)
	local unlocks = tycoon:FindFirstChild("Unlocks")
	local aimName = dropper:GetAttribute("AimUnlock") or dropper:GetAttribute("RequiresUnlock")
	local cell = unlocks and aimName and unlocks:FindFirstChild(aimName)

	if cell then
		local deposit = cell:FindFirstChild("Deposit", true)
		if deposit and deposit:IsA("BasePart") then
			return deposit.Position
		end
		local part = cell.PrimaryPart or cell:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end

	return dropper.Position + Vector3.new(0, 0, -10)
end

local function spawnFrom(tycoon, dropper)
	if not dropper.Parent or not tycoon.Parent then
		return
	end
	if not isClaimed(tycoon) then
		return
	end
	if dropper:GetAttribute("Active") ~= true then
		return
	end
	if countInmates(tycoon) >= MAX_INMATES_PER_TYCOON then
		return
	end

	local inmate = template:Clone()
	inmate.Name = "Inmate"
	inmate.Parent = getOrCreateActiveFolder(tycoon)

	local root = inmate.PrimaryPart or inmate:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		inmate:Destroy()
		warn("InmateTemplate needs a BasePart / PrimaryPart")
		return
	end
	inmate.PrimaryPart = root

	root.CFrame = CFrame.new(dropper.Position + Vector3.new(0, dropper.Size.Y / 2 + 2, 0))
	root.Anchored = false

	local target = getAimPosition(tycoon, dropper)
	local direction = target - root.Position
	if direction.Magnitude > 0.1 then
		root.AssemblyLinearVelocity = direction.Unit * 12 + Vector3.new(0, 2, 0)
	end

	inmate:SetAttribute(
		"TargetUnlock",
		dropper:GetAttribute("AimUnlock") or dropper:GetAttribute("RequiresUnlock")
	)

	Debris:AddItem(inmate, INMATE_LIFETIME)
end

local function runDropperLoop(tycoon, dropper)
	task.spawn(function()
		while dropper.Parent and tycoon.Parent do
			local interval = dropper:GetAttribute("DropInterval")
			if typeof(interval) ~= "number" or interval <= 0 then
				interval = DEFAULT_INTERVAL
			end
			task.wait(interval)
			spawnFrom(tycoon, dropper)
		end
	end)
end

local function hookDropper(tycoon, dropper)
	if not dropper:IsA("BasePart") then
		return
	end
	if dropper:GetAttribute("Active") == nil then
		local required = dropper:GetAttribute("RequiresUnlock")
		local starter = required == nil or required == "Cell1"
		dropper:SetAttribute("Active", starter)
	end
	runDropperLoop(tycoon, dropper)
end

local function hookTycoon(tycoon)
	if hooked[tycoon] then
		return
	end
	hooked[tycoon] = true

	local droppersFolder = tycoon:WaitForChild("Droppers", 10)
	if not droppersFolder then
		warn("Tycoon missing Droppers:", tycoon:GetFullName())
		return
	end

	getOrCreateActiveFolder(tycoon)

	for _, dropper in droppersFolder:GetChildren() do
		hookDropper(tycoon, dropper)
	end

	droppersFolder.ChildAdded:Connect(function(dropper)
		hookDropper(tycoon, dropper)
	end)

	tycoon:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		if not isClaimed(tycoon) then
			local folder = tycoon:FindFirstChild("ActiveInmates")
			if folder then
				folder:ClearAllChildren()
			end
		end
	end)

	tycoon.Destroying:Connect(function()
		hooked[tycoon] = nil
	end)
end

local tycoonsFolder = TycoonService.getTycoonsFolder()
for _, tycoon in tycoonsFolder:GetChildren() do
	hookTycoon(tycoon)
end
tycoonsFolder.ChildAdded:Connect(hookTycoon)
