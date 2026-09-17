-- Script: ServerScriptService.InmateCollector
-- Inmate touches Deposit → CashPerInmate to pad owner; inmate despawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))

local DEBOUNCE = {}

local function getInmateModel(hit)
	local current = hit
	while current and current ~= workspace do
		if current.Name == "Inmate" then
			return current
		end
		if current.Parent and current.Parent.Name == "ActiveInmates" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function payOwner(tycoon, amount)
	local ownerId = tycoon and tycoon:GetAttribute("OwnerUserId")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	if not owner then
		return
	end
	local cash = owner:FindFirstChild("leaderstats") and owner.leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += amount
	end
end

local function onDepositTouched(deposit, hit)
	local inmate = getInmateModel(hit)
	if not inmate then
		return
	end
	if DEBOUNCE[inmate] then
		return
	end
	DEBOUNCE[inmate] = true

	local tycoon = TycoonService.getTycoonFromInstance(deposit)
	if not tycoon then
		DEBOUNCE[inmate] = nil
		return
	end

	local cell = deposit:FindFirstAncestorWhichIsA("Model") or deposit.Parent
	while cell and cell.Parent and cell.Parent.Name ~= "Unlocks" do
		cell = cell.Parent
	end
	if cell and cell:GetAttribute("Owned") == false then
		DEBOUNCE[inmate] = nil
		return
	end

	local amount = Config.CashPerInmate or 10
	payOwner(tycoon, amount)
	inmate:Destroy()
	DEBOUNCE[inmate] = nil
end

local function hookDeposit(deposit)
	if not deposit:IsA("BasePart") or deposit.Name ~= "Deposit" then
		return
	end
	deposit.Touched:Connect(function(hit)
		onDepositTouched(deposit, hit)
	end)
end

local function scanUnlocks(unlocks)
	for _, unlock in unlocks:GetChildren() do
		local deposit = unlock:FindFirstChild("Deposit", true)
		if deposit then
			hookDeposit(deposit)
		end
		unlock.DescendantAdded:Connect(function(desc)
			if desc.Name == "Deposit" and desc:IsA("BasePart") then
				hookDeposit(desc)
			end
		end)
	end
end

local function hookTycoon(tycoon)
	local unlocks = tycoon:WaitForChild("Unlocks", 10)
	if not unlocks then
		return
	end
	scanUnlocks(unlocks)
	unlocks.ChildAdded:Connect(function(unlock)
		task.wait()
		local deposit = unlock:FindFirstChild("Deposit", true)
		if deposit then
			hookDeposit(deposit)
		end
	end)
end

local tycoonsFolder = TycoonService.getTycoonsFolder()
for _, tycoon in tycoonsFolder:GetChildren() do
	hookTycoon(tycoon)
end
tycoonsFolder.ChildAdded:Connect(hookTycoon)
