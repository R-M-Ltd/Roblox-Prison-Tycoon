-- Script: ServerScriptService.InmateCollector
-- Inmate touches matching Deposit → CashPerInmate to pad owner; inmate despawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))

local DEBOUNCE = {} -- [inmate] = true
local debounceHooked = {} -- [inmate] = true (Destroying connected once)
local hookedDeposits = {} -- [deposit] = true

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

local function findUnlockModel(deposit)
	local cell = deposit:FindFirstAncestorWhichIsA("Model") or deposit.Parent
	while cell and cell.Parent and cell.Parent.Name ~= "Unlocks" do
		cell = cell.Parent
	end
	if cell and cell.Parent and cell.Parent.Name == "Unlocks" then
		return cell
	end
	return nil
end

local function payOwner(tycoon, amount)
	local ownerId = tycoon and tycoon:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" or ownerId == 0 then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
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
	-- Connect Destroying once so Debris/lifetime despawns cannot leak table keys
	if not debounceHooked[inmate] then
		debounceHooked[inmate] = true
		inmate.Destroying:Connect(function()
			DEBOUNCE[inmate] = nil
			debounceHooked[inmate] = nil
		end)
	end

	local tycoon = TycoonService.getTycoonFromInstance(deposit)
	if not tycoon then
		DEBOUNCE[inmate] = nil
		return
	end

	local unlock = findUnlockModel(deposit)
	-- Strict: only collect into owned unlocks
	if not unlock or unlock:GetAttribute("Owned") ~= true then
		DEBOUNCE[inmate] = nil
		return
	end

	-- Same pad only: reject inmates from another tycoon's ActiveInmates
	local inmateTycoon = TycoonService.getTycoonFromInstance(inmate)
	if inmateTycoon ~= tycoon then
		DEBOUNCE[inmate] = nil
		return
	end

	-- Honor dropper aim: inmate must target this unlock (or have no target set)
	local target = inmate:GetAttribute("TargetUnlock")
	if typeof(target) == "string" and target ~= "" and target ~= unlock.Name then
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
	if hookedDeposits[deposit] then
		return
	end
	hookedDeposits[deposit] = true

	deposit.Touched:Connect(function(hit)
		onDepositTouched(deposit, hit)
	end)

	deposit.Destroying:Connect(function()
		hookedDeposits[deposit] = nil
	end)
end

local function watchUnlock(unlock)
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

local function hookTycoon(tycoon)
	local unlocks = tycoon:WaitForChild("Unlocks", 10)
	if not unlocks then
		return
	end

	for _, unlock in unlocks:GetChildren() do
		watchUnlock(unlock)
	end
	unlocks.ChildAdded:Connect(watchUnlock)
end

local tycoonsFolder = TycoonService.getTycoonsFolder()
for _, tycoon in tycoonsFolder:GetChildren() do
	hookTycoon(tycoon)
end
tycoonsFolder.ChildAdded:Connect(hookTycoon)
