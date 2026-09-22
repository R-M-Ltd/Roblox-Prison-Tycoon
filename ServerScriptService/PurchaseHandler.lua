-- Script: ServerScriptService.PurchaseHandler
-- Owner-only buys, per-pad unlock visibility, syncDroppers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig", 30))
local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService", 30))
local TycoonVisibility = require(ReplicatedStorage:WaitForChild("TycoonVisibility", 30))

local DEBOUNCE_TIME = 0.5
local debounce = {}
local hookedButtons = {}
local hookedTycoons = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
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
	TycoonVisibility.setUnlockVisible(unlock, true)
	TycoonVisibility.syncDroppers(tycoon)

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

	button.Destroying:Connect(function()
		hookedButtons[button] = nil
	end)
end

local function hookTycoon(tycoon)
	if hookedTycoons[tycoon] then
		return
	end
	hookedTycoons[tycoon] = true

	-- Fresh pads already prepared by Assigner; re-sync droppers to be safe
	TycoonVisibility.syncDroppers(tycoon)

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

	tycoon.Destroying:Connect(function()
		hookedTycoons[tycoon] = nil
	end)
end

local tycoonsFolder = TycoonService.getTycoonsFolder()
for _, tycoon in tycoonsFolder:GetChildren() do
	hookTycoon(tycoon)
end
tycoonsFolder.ChildAdded:Connect(hookTycoon)
