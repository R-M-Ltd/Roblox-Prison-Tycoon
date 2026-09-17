-- ModuleScript: ReplicatedStorage.TycoonService
local TycoonService = {}

function TycoonService.getTycoonsFolder()
	local folder = workspace:FindFirstChild("Tycoons")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Tycoons"
		folder.Parent = workspace
	end
	return folder
end

function TycoonService.getPlayerTycoon(player)
	for _, tycoon in TycoonService.getTycoonsFolder():GetChildren() do
		if tycoon:GetAttribute("OwnerUserId") == player.UserId then
			return tycoon
		end
	end
	return nil
end

function TycoonService.getTycoonFromInstance(inst)
	local current = inst
	while current and current ~= workspace do
		if current:GetAttribute("OwnerUserId") ~= nil or current:GetAttribute("IsTycoon") then
			return current
		end
		current = current.Parent
	end
	return nil
end

return TycoonService
