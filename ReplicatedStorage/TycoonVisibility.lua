-- ModuleScript: ReplicatedStorage.TycoonVisibility
-- Shared unlock/dropper visibility helpers (used by Assigner + PurchaseHandler).
local TycoonVisibility = {}

function TycoonVisibility.setUnlockVisible(unlockModel, visible)
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

function TycoonVisibility.setDropperActive(dropper, active)
	if not dropper:IsA("BasePart") then
		return
	end
	if dropper:GetAttribute("OriginalTransparency") == nil then
		dropper:SetAttribute("OriginalTransparency", dropper.Transparency)
		dropper:SetAttribute("OriginalCanCollide", dropper.CanCollide)
	end
	if active then
		dropper.Transparency = dropper:GetAttribute("OriginalTransparency") or 0
		local canCollide = dropper:GetAttribute("OriginalCanCollide")
		dropper.CanCollide = if canCollide == nil then false else canCollide
		dropper:SetAttribute("Active", true)
	else
		dropper.Transparency = 1
		dropper.CanCollide = false
		dropper:SetAttribute("Active", false)
	end
end

function TycoonVisibility.syncDroppers(tycoon)
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

		TycoonVisibility.setDropperActive(dropper, owned)
	end
end

function TycoonVisibility.applyFreshUnlockState(tycoon)
	local unlocks = tycoon:FindFirstChild("Unlocks")
	if not unlocks then
		warn("Tycoon missing Unlocks:", tycoon:GetFullName())
		return
	end

	for _, unlock in unlocks:GetChildren() do
		if unlock.Name == "Cell1" then
			TycoonVisibility.setUnlockVisible(unlock, true)
		else
			TycoonVisibility.setUnlockVisible(unlock, false)
		end
	end

	TycoonVisibility.syncDroppers(tycoon)
end

return TycoonVisibility
