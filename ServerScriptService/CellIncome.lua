-- Script: ServerScriptService.CellIncome
-- Passive cash per owned unlock, paid to each pad owner only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonService = require(ReplicatedStorage:WaitForChild("TycoonService"))
local Config = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local function ownedCount(tycoon)
	local unlocks = tycoon:FindFirstChild("Unlocks")
	if not unlocks then
		return 0
	end
	local n = 0
	for _, unlock in unlocks:GetChildren() do
		if unlock:GetAttribute("Owned") == true then
			n += 1
		end
	end
	return n
end

task.spawn(function()
	while true do
		task.wait(Config.IncomeInterval)
		for _, tycoon in TycoonService.getTycoonsFolder():GetChildren() do
			local ownerId = tycoon:GetAttribute("OwnerUserId")
			if ownerId and ownerId ~= 0 then
				local owner = Players:GetPlayerByUserId(ownerId)
				local cash = owner and owner:FindFirstChild("leaderstats") and owner.leaderstats:FindFirstChild("Cash")
				local n = ownedCount(tycoon)
				if cash and n > 0 then
					cash.Value += n * Config.IncomePerOwnedUnlock
				end
			end
		end
	end
end)
