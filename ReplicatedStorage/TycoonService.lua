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
		-- Prefer explicit tycoon marker
		if current:GetAttribute("IsTycoon") == true then
			return current
		end
		-- Fallback: only treat direct children of Workspace.Tycoons as pads
		-- (avoids false positives if a nested part accidentally has OwnerUserId)
		local parent = current.Parent
		if parent and parent.Name == "Tycoons" and parent.Parent == workspace then
			if current:GetAttribute("OwnerUserId") ~= nil then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

return TycoonService
