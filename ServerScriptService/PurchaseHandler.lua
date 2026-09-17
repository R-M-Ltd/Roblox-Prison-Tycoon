-- Script: ServerScriptService.PurchaseHandler
-- Owner-only buys, per-pad unlock visibility, syncDroppers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))

local DEBOUNCE_TIME = 0.5
local debounce = {}
local hookedButtons = {}
local hookedTycoons = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function setUnlockVisible(unlockModel, visible)
	for _, inst in unlockModel:GetDescendants() do
		if inst:IsA("BasePart") then
			if visible then
				inst.Transparency = inst:GetAttribute("OriginalTransparency") or 0
				local canCollide = inst:GetAttribute("OriginalCanCollide")
				inst.CanCollide = if canCollide == nil then true else canCollide
			else
				if inst:GetAttribute("OriginalTransparency") == nil then
					inst:SetAttribute("OriginalTransparency", inst.Transparency)
					inst:SetAttribute("OriginalCanCollide", inst.CanCollide)
				end
				inst.Transparency = 1
				inst.CanCollide = false
			end
		end
	end
	unlockModel:SetAttribute("Owned", visible == true)
end

local function setDropperActive(dropper, active)
	if not dropper:IsA("BasePart") then
		return
	end
	if dropper:GetAttribute("OriginalTransparency") == nil then
		dropper:SetAttribute("OriginalTransparency", dropper.Transparency)
		dropper:SetAttribute("OriginalCanCollide", dropper.CanCollide)
	end
	if active then
		dropper.Transparency = dropper:GetAttribute("OriginalTransparency") or 0
		dropper.CanCollide = dropper:GetAttribute("OriginalCanCollide") == true
		dropper:SetAttribute("Active", true)
	else
		dropper.Transparency = 1
		dropper.CanCollide = false
		dropper:SetAttribute("Active", false)
	end
end

local function syncDroppers(tycoon)
	local droppers = tycoon:FindFirstChild("Droppers")
	local unlocks = tycoon:FindFirstChild("Unlocks")
	if not droppers then
		return
	end

	for _, dropper in droppers:GetChildren() do
		local required = dropper:GetAttribute("RequiresUnlock")
		local owned = false

		if required == nil or required == "Cell1" then
			owned = true
			if unlocks then
				local cell1 = unlocks:FindFirstChild("Cell1")
				if cell1 then
					cell1:SetAttribute("Owned", true)
				end
			end
		elseif unlocks then
			local unlock = unlocks:FindFirstChild(required)
			owned = unlock ~= nil and unlock:GetAttribute("Owned") == true
		end

		setDropperActive(dropper, owned)
	end
end

local function hideLockedUnlocks(tycoon)
	local unlocks = tycoon:FindFirstChild("Unlocks")
	if not unlocks then
		warn("Tycoon missing Unlocks:", tycoon:GetFullName())
		return
	end

	for _, unlock in unlocks:GetChildren() do
		if unlock.Name == "Cell1" then
			setUnlockVisible(unlock, true)
		else
			if unlock:GetAttribute("Owned") == true then
				setUnlockVisible(unlock, true)
			else
				setUnlockVisible(unlock, false)
			end
		end
	end

	syncDroppers(tycoon)
end

local function tryPurchase(player, button)
	local userId = player.UserId
	if debounce[userId] then
		return
	end
	debounce[userId] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[userId] = nil
	end)

	local tycoon = TycoonService.getTycoonFromInstance(button)
	if not tycoon then
		return
	end

	local ownerId = tycoon:GetAttribute("OwnerUserId")
	if ownerId ~= player.UserId then
		return
	end

	local purchaseId = button:GetAttribute("PurchaseId")
	local info = purchaseId and Config.Purchases[purchaseId]
	if not info then
		warn("Unknown or missing PurchaseId on", button:GetFullName())
		return
	end

	local cash = getCash(player)
	if not cash or cash.Value < info.Cost then
		return
	end

	local unlocks = tycoon:FindFirstChild("Unlocks")
	local unlock = unlocks and unlocks:FindFirstChild(info.Unlock)
	if not unlock then
		warn("Missing unlock model:", info.Unlock, "on", tycoon.Name)
		return
	end
	if unlock:GetAttribute("Owned") == true then
		return
	end

	cash.Value -= info.Cost
	setUnlockVisible(unlock, true)
	syncDroppers(tycoon)

	hookedButtons[button] = nil
	button:Destroy()
end

local function hookButton(button)
	if hookedButtons[button] then
		return
	end
	if not button:IsA("BasePart") then
		return
	end
	local inButtonsFolder = button.Parent and button.Parent.Name == "Buttons"
	local tagged = CollectionService:HasTag(button, "PurchaseButton")
	if not inButtonsFolder and not tagged then
		return
	end

	hookedButtons[button] = true
	button.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			tryPurchase(player, button)
		end
	end)
end

local function hookTycoon(tycoon)
	if hookedTycoons[tycoon] then
		return
	end
	hookedTycoons[tycoon] = true

	hideLockedUnlocks(tycoon)

	local buttonsFolder = tycoon:FindFirstChild("Buttons")
	if buttonsFolder then
		for _, button in buttonsFolder:GetChildren() do
			hookButton(button)
		end
		buttonsFolder.ChildAdded:Connect(hookButton)
	else
		warn("Tycoon missing Buttons folder:", tycoon:GetFullName())
	end

	for _, inst in tycoon:GetDescendants() do
		if CollectionService:HasTag(inst, "PurchaseButton") then
			hookButton(inst)
		end
	end
	tycoon.DescendantAdded:Connect(function(inst)
		if CollectionService:HasTag(inst, "PurchaseButton") then
			hookButton(inst)
		end
	end)

	tycoon:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		local ownerId = tycoon:GetAttribute("OwnerUserId")
		if ownerId == nil or ownerId == 0 then
			local unlocks = tycoon:FindFirstChild("Unlocks")
			if unlocks then
				for _, unlock in unlocks:GetChildren() do
					if unlock.Name == "Cell1" then
						setUnlockVisible(unlock, true)
					else
						setUnlockVisible(unlock, false)
					end
				end
			end
			syncDroppers(tycoon)
		end
	end)
end

local tycoonsFolder = TycoonService.getTycoonsFolder()
for _, tycoon in tycoonsFolder:GetChildren() do
	hookTycoon(tycoon)
end
tycoonsFolder.ChildAdded:Connect(hookTycoon)
