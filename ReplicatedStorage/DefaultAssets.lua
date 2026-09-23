-- ModuleScript: ReplicatedStorage.DefaultAssets
-- Idempotent Studio fallbacks so a bare place still boots the core loop.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local worldConfigModule = ReplicatedStorage:WaitForChild("WorldConfig", 10)
local WorldConfig = worldConfigModule and require(worldConfigModule) or {}

local DefaultAssets = {}

local MARKER = "_AutoDefault"

local function mark(inst)
	inst:SetAttribute(MARKER, true)
	return inst
end

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		mark(f)
	end
	return f
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.Anchored = if props.Anchored == nil then true else props.Anchored
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Transparency = props.Transparency or 0
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Color then
		p.Color = props.Color
	end
	if props.Parent then
		p.Parent = props.Parent
	end
	mark(p)
	return p
end

local function ensureNamedPart(parent, name, props)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local merged = table.clone(props or {})
	merged.Name = name
	merged.Parent = parent
	return makePart(merged)
end

local function ensureUnlockCell(unlocks, name, offset)
	local cell = unlocks:FindFirstChild(name)
	if not cell then
		cell = Instance.new("Model")
		cell.Name = name
		cell.Parent = unlocks
		mark(cell)
	end

	local floor = cell:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		if floor then
			floor:Destroy()
		end
		floor = makePart({
			Name = "Floor",
			Size = Vector3.new(8, 1, 8),
			CFrame = CFrame.new(offset),
			Color = Color3.fromRGB(90, 90, 110),
			Parent = cell,
		})
	end
	if cell:IsA("Model") then
		cell.PrimaryPart = floor
	end

	local deposit = cell:FindFirstChild("Deposit", true)
	if not deposit or not deposit:IsA("BasePart") then
		if deposit then
			deposit:Destroy()
		end
		deposit = makePart({
			Name = "Deposit",
			Size = Vector3.new(6, 2, 6),
			CFrame = CFrame.new(offset + Vector3.new(0, 1.5, 0)),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Color = Color3.fromRGB(0, 255, 100),
			Parent = cell,
		})
		deposit.CanTouch = true
	else
		deposit.CanCollide = false
		deposit.CanTouch = true
		if deposit.Transparency < 1 then
			deposit.Transparency = 1
		end
	end

	return cell
end

local function ensurePurchaseButton(buttons, name, purchaseId, offset, color)
	local btn = buttons:FindFirstChild(name)
	if not btn or not btn:IsA("BasePart") then
		if btn then
			btn:Destroy()
		end
		btn = makePart({
			Name = name,
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(offset),
			CanCollide = false,
			Color = color,
			Parent = buttons,
		})
	end
	if btn:GetAttribute("PurchaseId") == nil then
		btn:SetAttribute("PurchaseId", purchaseId)
	end
	return btn
end

local function ensureDropper(droppers, name, requiresUnlock, aimUnlock, offset)
	local dropper = droppers:FindFirstChild(name)
	if not dropper or not dropper:IsA("BasePart") then
		if dropper then
			dropper:Destroy()
		end
		dropper = makePart({
			Name = name,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(offset),
			CanCollide = false,
			Color = Color3.fromRGB(200, 120, 40),
			Parent = droppers,
		})
	end
	if dropper:GetAttribute("RequiresUnlock") == nil then
		dropper:SetAttribute("RequiresUnlock", requiresUnlock)
	end
	if aimUnlock and dropper:GetAttribute("AimUnlock") == nil then
		dropper:SetAttribute("AimUnlock", aimUnlock)
	end
	return dropper
end

function DefaultAssets.ensurePadParts(tycoon)
	if not tycoon then
		return
	end
	local guard = tycoon:FindFirstChild("GuardSpawn", true)
	local hasGuard = guard and guard:IsA("BasePart")
	if not hasGuard then
		for _, folderName in ipairs({ "GuardSpawns", "StaffSpawns" }) do
			local folder = tycoon:FindFirstChild(folderName)
			if folder then
				for _, child in folder:GetChildren() do
					if child:IsA("BasePart") then
						hasGuard = true
						break
					end
				end
			end
			if hasGuard then
				break
			end
		end
	end
	if not hasGuard then
		ensureNamedPart(tycoon, "GuardSpawn", {
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(14, 1, 0),
			CanCollide = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(40, 80, 200),
		})
	end
	local escape = tycoon:FindFirstChild("EscapePoint", true)
	if not (escape and escape:IsA("BasePart")) then
		-- Also accept EscapePoints folder with at least one BasePart
		local folder = tycoon:FindFirstChild("EscapePoints")
		local hasFolderPoint = false
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					hasFolderPoint = true
					break
				end
			end
		end
		if not hasFolderPoint then
			ensureNamedPart(tycoon, "EscapePoint", {
				Size = Vector3.new(3, 1, 3),
				CFrame = CFrame.new(0, 1, -18),
				CanCollide = false,
				Transparency = 0.4,
				Color = Color3.fromRGB(200, 40, 40),
			})
		end
	end
end

function DefaultAssets.ensureInmateTemplate()
	local existing = ServerStorage:FindFirstChild("InmateTemplate")
	if existing then
		if existing:IsA("Model") and not existing.PrimaryPart then
			local part = existing:FindFirstChildWhichIsA("BasePart", true)
			if part then
				existing.PrimaryPart = part
			end
		end
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "InmateTemplate"
	mark(model)

	local body = makePart({
		Name = "Body",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(0, 1, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(255, 170, 0),
		Parent = model,
	})
	model.PrimaryPart = body
	model.Parent = ServerStorage
	print("[DefaultAssets] Created ServerStorage.InmateTemplate")
	return model
end

function DefaultAssets.ensureGuardTemplate()
	local existing = ServerStorage:FindFirstChild("GuardTemplate")
	if existing then
		if existing:IsA("Model") and not existing.PrimaryPart then
			local part = existing:FindFirstChildWhichIsA("BasePart", true)
			if part then
				existing.PrimaryPart = part
			end
		end
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "GuardTemplate"
	mark(model)

	local body = makePart({
		Name = "Body",
		Size = Vector3.new(2, 2.5, 1),
		CFrame = CFrame.new(0, 1.25, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(50, 90, 200),
		Parent = model,
	})
	model.PrimaryPart = body
	model.Parent = ServerStorage
	print("[DefaultAssets] Created ServerStorage.GuardTemplate")
	return model
end

-- Fill missing claim / buttons / unlocks / droppers so live scripts can run.
-- Idempotent: never replaces Studio-authored children that already exist.
local function ensureTycoonPlayableStructure(model)
	if not model.PrimaryPart then
		local floor = model:FindFirstChild("Floor")
		if not (floor and floor:IsA("BasePart")) then
			floor = ensureNamedPart(model, "Floor", {
				Size = Vector3.new(40, 1, 40),
				CFrame = CFrame.new(0, 0, 0),
				Color = Color3.fromRGB(70, 70, 75),
			})
		end
		model.PrimaryPart = floor
	end

	local claim = model:FindFirstChild("ClaimPad", true)
	if not (claim and claim:IsA("BasePart")) then
		claim = ensureNamedPart(model, "ClaimPad", {
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(0, 1, 16),
			CanCollide = false,
			Color = Color3.fromRGB(80, 220, 100),
		})
	end
	if claim:GetAttribute("Claimable") == nil then
		claim:SetAttribute("Claimable", true)
	end

	if not model:FindFirstChild("PlayerSpawn", true) then
		ensureNamedPart(model, "PlayerSpawn", {
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(0, 1, 10),
			CanCollide = false,
			Transparency = 0.5,
			Color = Color3.fromRGB(180, 180, 255),
		})
	end

	local buttons = ensureFolder(model, "Buttons")
	ensurePurchaseButton(buttons, "Cell2", "Cell2", Vector3.new(-8, 1, 8), Color3.fromRGB(255, 220, 60))
	ensurePurchaseButton(buttons, "Cell3", "Cell3", Vector3.new(-12, 1, 8), Color3.fromRGB(255, 180, 60))
	ensurePurchaseButton(buttons, "Cell4", "Cell4", Vector3.new(-16, 1, 8), Color3.fromRGB(255, 140, 60))
	ensurePurchaseButton(buttons, "Kitchen", "Kitchen", Vector3.new(8, 1, 8), Color3.fromRGB(255, 100, 160))

	local unlocks = ensureFolder(model, "Unlocks")
	ensureUnlockCell(unlocks, "Cell1", Vector3.new(-10, 1, -6))
	ensureUnlockCell(unlocks, "Cell2", Vector3.new(10, 1, -6))
	-- Stub unlock models for later purchases (Deposit included so collector can hook)
	ensureUnlockCell(unlocks, "Cell3", Vector3.new(-10, 1, -16))
	ensureUnlockCell(unlocks, "Cell4", Vector3.new(10, 1, -16))
	ensureUnlockCell(unlocks, "Kitchen", Vector3.new(0, 1, -22))

	local droppers = ensureFolder(model, "Droppers")
	ensureDropper(droppers, "Intake_Cell1", "Cell1", "Cell1", Vector3.new(-10, 5, 4))
	ensureDropper(droppers, "Intake_Cell2", "Cell2", "Cell2", Vector3.new(10, 5, 4))

	ensureFolder(model, "ActiveInmates")
	DefaultAssets.ensurePadParts(model)
	return model
end

function DefaultAssets.ensureTycoonTemplate()
	local existing = ServerStorage:FindFirstChild("TycoonTemplate")
	if existing then
		-- Enrich partial Studio templates (missing attrs/folders/pads) in place
		ensureTycoonPlayableStructure(existing)
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "TycoonTemplate"
	mark(model)
	ensureTycoonPlayableStructure(model)
	model.Parent = ServerStorage
	print("[DefaultAssets] Created ServerStorage.TycoonTemplate (minimal playable pad)")
	return model
end

function DefaultAssets.ensureTycoonSpawns()
	local folder = workspace:FindFirstChild("TycoonSpawns")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TycoonSpawns"
		folder.Parent = workspace
		mark(folder)
	end

	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	if #parts >= 2 then
		return folder
	end

	local offsets = {
		Vector3.new(0, 1, 0),
		Vector3.new(80, 1, 0),
	}
	for i = #parts + 1, 2 do
		local name = "Spawn" .. tostring(i)
		if not folder:FindFirstChild(name) then
			makePart({
				Name = name,
				Size = Vector3.new(6, 1, 6),
				CFrame = CFrame.new(offsets[i]),
				CanCollide = false,
				Transparency = 0.6,
				Color = Color3.fromRGB(120, 200, 255),
				Parent = folder,
			})
			print("[DefaultAssets] Created Workspace.TycoonSpawns." .. name)
		end
	end
	return folder
end

function DefaultAssets.ensureWorldZones()
	local folder = workspace:FindFirstChild("WorldZones")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WorldZones"
		folder.Parent = workspace
		mark(folder)
	end

	local names = WorldConfig.ZoneNames
		or { "Yard", "Cafeteria", "Infirmary", "Solitary", "Intake", "CellBlock" }

	local layout = {
		Yard = Vector3.new(0, 1, 40),
		Cafeteria = Vector3.new(30, 1, 40),
		Infirmary = Vector3.new(-30, 1, 40),
		Solitary = Vector3.new(0, 1, 60),
		Intake = Vector3.new(30, 1, 20),
		CellBlock = Vector3.new(-30, 1, 20),
	}

	for _, name in ipairs(names) do
		local part = folder:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			if part then
				part:Destroy()
			end
			part = makePart({
				Name = name,
				Size = Vector3.new(20, 1, 20),
				CFrame = CFrame.new(layout[name] or Vector3.new(0, 1, 40)),
				CanCollide = false,
				Transparency = 0.85,
				Color = Color3.fromRGB(150, 150, 180),
				Parent = folder,
			})
			print("[DefaultAssets] Created Workspace.WorldZones." .. name)
		end
		if part:GetAttribute("ZoneName") == nil then
			part:SetAttribute("ZoneName", name)
		end
	end
	return folder
end

function DefaultAssets.ensureWorld()
	DefaultAssets.ensureWorldZones()
	DefaultAssets.ensureGuardTemplate()
end

function DefaultAssets.ensureAll()
	DefaultAssets.ensureInmateTemplate()
	DefaultAssets.ensureGuardTemplate()
	DefaultAssets.ensureTycoonTemplate()
	DefaultAssets.ensureTycoonSpawns()
	DefaultAssets.ensureWorldZones()
	return true
end

return DefaultAssets
