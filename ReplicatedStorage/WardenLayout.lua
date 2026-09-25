-- ModuleScript: ReplicatedStorage.WardenLayout
-- Builds the playable pad silhouette end-to-end:
--   office → intake → corridor → cell block + perimeter walls
-- Wired to TycoonTemplate / WorldZones / TycoonSpawns contracts so
-- claim → buy → deposit still works. Parts only (no MeshIds).
--
-- Idempotent. Templates with DefaultAssetsBuilt=true may refresh visuals;
-- user-authored templates without that attr only get missing structure filled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tycoonConfigModule = ReplicatedStorage:FindFirstChild("TycoonConfig")
local TycoonConfig = tycoonConfigModule and require(tycoonConfigModule) or nil

local WardenLayout = {}

local MARKER = "_AutoDefault"
local BUILT_ATTR = "DefaultAssetsBuilt"

-- Fallback purchase prices if TycoonConfig is unavailable
local FALLBACK_COSTS = {
	Cell2 = 50,
	Cell3 = 150,
	Cell4 = 400,
	Kitchen = 1000,
}

-- Warden-empire palette: concrete + orange neon claim + prison steel
local COLORS = {
	Floor = Color3.fromRGB(145, 145, 135),
	OfficeFloor = Color3.fromRGB(120, 110, 95),
	Corridor = Color3.fromRGB(130, 130, 125),
	CellFloor = Color3.fromRGB(100, 100, 105),
	OuterWall = Color3.fromRGB(45, 45, 50),
	InnerWall = Color3.fromRGB(65, 65, 72),
	HallWall = Color3.fromRGB(60, 60, 68),
	Bars = Color3.fromRGB(40, 40, 50),
	Claim = Color3.fromRGB(255, 140, 40), -- orange neon
	PlayerSpawn = Color3.fromRGB(180, 180, 255),
	Guard = Color3.fromRGB(40, 80, 200),
	Escape = Color3.fromRGB(200, 40, 40),
	Dropper = Color3.fromRGB(255, 140, 40),
	Desk = Color3.fromRGB(90, 70, 50),
	ButtonCell2 = Color3.fromRGB(255, 220, 60),
	ButtonCell3 = Color3.fromRGB(255, 180, 60),
	ButtonCell4 = Color3.fromRGB(255, 140, 60),
	ButtonKitchen = Color3.fromRGB(255, 100, 160),
	DepositHint = Color3.fromRGB(0, 255, 100),
}

local function purchaseCost(purchaseId)
	if TycoonConfig and TycoonConfig.Purchases and TycoonConfig.Purchases[purchaseId] then
		return TycoonConfig.Purchases[purchaseId].Cost
	end
	return FALLBACK_COSTS[purchaseId] or 0
end

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
	if props.CanTouch ~= nil then
		p.CanTouch = props.CanTouch
	end
	if props.Parent then
		p.Parent = props.Parent
	end
	mark(p)
	return p
end

local function ensureNamedPart(parent, name, props, refreshVisuals)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		if refreshVisuals then
			if props.Size then
				existing.Size = props.Size
			end
			if props.Color then
				existing.Color = props.Color
			end
			if props.Material then
				existing.Material = props.Material
			end
			if props.Transparency ~= nil then
				existing.Transparency = props.Transparency
			end
			if props.CanCollide ~= nil then
				existing.CanCollide = props.CanCollide
			end
			if props.CanTouch ~= nil then
				existing.CanTouch = props.CanTouch
			end
			if props.Anchored ~= nil then
				existing.Anchored = props.Anchored
			end
			if props.CFrame then
				existing.CFrame = props.CFrame
			end
		end
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

local function ensureBillboardLabel(adornee, guiName, text, studsOffset, textSize)
	local gui = adornee:FindFirstChild(guiName)
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = guiName
		gui.AlwaysOnTop = true
		gui.Size = UDim2.new(0, 160, 0, 40)
		gui.StudsOffset = studsOffset or Vector3.new(0, 2.5, 0)
		gui.MaxDistance = 80
		gui.Parent = adornee
		mark(gui)
	end
	local label = gui:FindFirstChild("Label")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		label.Font = Enum.Font.GothamBold
		label.TextScaled = false
		label.TextSize = textSize or 18
		label.Parent = gui
		mark(label)
	end
	label.Text = text
	return gui, label
end

local function ensureButtonCostGui(btn, purchaseId)
	local cost = purchaseCost(purchaseId)
	local text = "$" .. tostring(cost) .. " - " .. purchaseId
	local gui = btn:FindFirstChild("CostGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "CostGui"
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = btn
		mark(gui)
	end
	local label = gui:FindFirstChild("Label")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(0, 0, 0)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = gui
		mark(label)
	end
	label.Text = text
	ensureBillboardLabel(btn, "CostBillboard", text, Vector3.new(0, 2, 0), 16)
end

---------------------------------------------------------------------------
-- Layout constants (local coords around pad Floor origin)
-- +Z = office / claim   −Z = cell block
---------------------------------------------------------------------------
local PAD = {
	FloorSize = Vector3.new(48, 1, 56),
	-- Office (south / +Z)
	Claim = Vector3.new(0, 1, 22),
	PlayerSpawn = Vector3.new(0, 1, 16),
	Desk = Vector3.new(0, 1.75, 19),
	-- Corridor walkway center
	CorridorY = 0.55,
	-- Intake dropper bay (elevated, aims toward cells)
	IntakeZ = 6,
	IntakeY = 5,
	-- Cell block floors (Unlocks)
	Cell1 = Vector3.new(-12, 1, -8),
	Cell2 = Vector3.new(12, 1, -8),
	Cell3 = Vector3.new(-12, 1, -18),
	Cell4 = Vector3.new(12, 1, -18),
	Kitchen = Vector3.new(0, 1, -26),
	-- Purchase buttons (corridor / office side)
	BtnCell2 = Vector3.new(-8, 1, 10),
	BtnCell3 = Vector3.new(-12, 1, 10),
	BtnCell4 = Vector3.new(-16, 1, 10),
	BtnKitchen = Vector3.new(8, 1, 10),
	-- Helpers
	GuardSpawn = Vector3.new(20, 1, 2),
	EscapePoint = Vector3.new(0, 1, -30),
}

local function ensureCellBars(cell, floor, refreshVisuals)
	local bars = cell:FindFirstChild("Bars")
	if not bars then
		bars = Instance.new("Model")
		bars.Name = "Bars"
		bars.Parent = cell
		mark(bars)
	end
	local baseCf = floor.CFrame
	-- Aesthetic only (CanCollide false): solid bars must not block Intake→Deposit
	for i = 1, 5 do
		local x = -3 + (i - 1) * 1.5
		ensureNamedPart(bars, "Bar" .. tostring(i), {
			Size = Vector3.new(0.3, 6, 0.3),
			CFrame = baseCf * CFrame.new(x, 3.5, 4),
			Color = COLORS.Bars,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Anchored = true,
		}, refreshVisuals)
	end
	ensureNamedPart(bars, "Crossbar", {
		Size = Vector3.new(8, 0.3, 0.3),
		CFrame = baseCf * CFrame.new(0, 6.5, 4),
		Color = COLORS.Bars,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	ensureNamedPart(bars, "WallL", {
		Size = Vector3.new(0.5, 6, 8),
		CFrame = baseCf * CFrame.new(-4, 3.5, 0),
		Color = COLORS.InnerWall,
		Material = Enum.Material.Concrete,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	ensureNamedPart(bars, "WallR", {
		Size = Vector3.new(0.5, 6, 8),
		CFrame = baseCf * CFrame.new(4, 3.5, 0),
		Color = COLORS.InnerWall,
		Material = Enum.Material.Concrete,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	ensureNamedPart(bars, "WallBack", {
		Size = Vector3.new(8, 6, 0.5),
		CFrame = baseCf * CFrame.new(0, 3.5, -4),
		Color = COLORS.InnerWall,
		Material = Enum.Material.Concrete,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
end

local function ensureUnlockCell(unlocks, name, offset, refreshVisuals, withBars)
	local cell = unlocks:FindFirstChild(name)
	if not cell then
		cell = Instance.new("Model")
		cell.Name = name
		cell.Parent = unlocks
		mark(cell)
	end

	local floor = ensureNamedPart(cell, "Floor", {
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(offset),
		Color = COLORS.CellFloor,
		Material = Enum.Material.Concrete,
		Parent = cell,
	}, refreshVisuals)
	if cell:IsA("Model") then
		cell.PrimaryPart = floor
	end

	-- Deposit: invisible sensor; CanCollide false so inmates can enter; CanTouch true
	local deposit = ensureNamedPart(cell, "Deposit", {
		Size = Vector3.new(7.5, 2, 7.5),
		CFrame = CFrame.new(offset + Vector3.new(0, 1.5, 0)),
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		Anchored = true,
		Color = COLORS.DepositHint,
		Parent = cell,
	}, refreshVisuals)
	deposit.CanCollide = false
	deposit.CanTouch = true
	if deposit.Transparency < 1 then
		deposit.Transparency = 1
	end

	if withBars and refreshVisuals then
		ensureCellBars(cell, floor, true)
	end

	return cell
end

local function ensurePurchaseButton(buttons, name, purchaseId, offset, color, refreshVisuals)
	local btn = ensureNamedPart(buttons, name, {
		Size = Vector3.new(4, 1, 4),
		CFrame = CFrame.new(offset),
		CanCollide = false,
		Color = color,
		Material = Enum.Material.Neon,
		Parent = buttons,
	}, refreshVisuals)
	if btn:GetAttribute("PurchaseId") == nil then
		btn:SetAttribute("PurchaseId", purchaseId)
	end
	if refreshVisuals or not btn:FindFirstChild("CostGui") then
		ensureButtonCostGui(btn, purchaseId)
	end
	return btn
end

local function ensureDropper(droppers, name, requiresUnlock, aimUnlock, offset, refreshVisuals)
	local dropper = ensureNamedPart(droppers, name, {
		Size = Vector3.new(3, 1.5, 3),
		CFrame = CFrame.new(offset),
		CanCollide = false,
		Color = COLORS.Dropper,
		Material = Enum.Material.Neon,
		Parent = droppers,
	}, refreshVisuals)
	if dropper:GetAttribute("RequiresUnlock") == nil then
		dropper:SetAttribute("RequiresUnlock", requiresUnlock)
	end
	if aimUnlock and dropper:GetAttribute("AimUnlock") == nil then
		dropper:SetAttribute("AimUnlock", aimUnlock)
	end
	if refreshVisuals or not dropper:FindFirstChild("IntakeLabel") then
		ensureBillboardLabel(dropper, "IntakeLabel", "Intake: " .. requiresUnlock, Vector3.new(0, 2, 0), 14)
	end
	return dropper
end

-- Perimeter + interior silhouette. Outer fence CanCollide true (containment);
-- interior aesthetics CanCollide false so Intake→Deposit path stays clear.
local function ensureStructure(model, refreshVisuals)
	local structure = ensureFolder(model, "Structure")

	-- Outer fence (containment) — CanCollide true
	local outer = {
		{ Name = "OuterN", Size = Vector3.new(50, 10, 1.5), CFrame = CFrame.new(0, 5, -28.5), CanCollide = true },
		{ Name = "OuterS", Size = Vector3.new(50, 10, 1.5), CFrame = CFrame.new(0, 5, 28.5), CanCollide = true },
		{ Name = "OuterE", Size = Vector3.new(1.5, 10, 58), CFrame = CFrame.new(24.5, 5, 0), CanCollide = true },
		{ Name = "OuterW", Size = Vector3.new(1.5, 10, 58), CFrame = CFrame.new(-24.5, 5, 0), CanCollide = true },
	}
	for _, w in ipairs(outer) do
		ensureNamedPart(structure, w.Name, {
			Size = w.Size,
			CFrame = w.CFrame,
			Color = COLORS.OuterWall,
			Material = Enum.Material.Concrete,
			CanCollide = w.CanCollide,
			Anchored = true,
		}, refreshVisuals)
	end

	-- Interior aesthetics — CanCollide false (never block Inmate→Deposit)
	local interior = {
		-- Office partitions (claim end / +Z)
		{ Name = "OfficeWallL", Size = Vector3.new(1, 6, 12), CFrame = CFrame.new(-7, 3, 20) },
		{ Name = "OfficeWallR", Size = Vector3.new(1, 6, 12), CFrame = CFrame.new(7, 3, 20) },
		{ Name = "OfficeBack", Size = Vector3.new(14, 6, 0.5), CFrame = CFrame.new(0, 3, 26) },
		-- Corridor / hall sides
		{ Name = "HallWallL", Size = Vector3.new(1, 6, 14), CFrame = CFrame.new(-6, 3, 6) },
		{ Name = "HallWallR", Size = Vector3.new(1, 6, 14), CFrame = CFrame.new(6, 3, 6) },
		-- Cell-block divider (visual only — sits near Intake→Deposit; Must not collide)
		{ Name = "CellDivider", Size = Vector3.new(24, 6, 0.5), CFrame = CFrame.new(0, 3, -2) },
		-- Corridor floor strip (raised visual)
		{ Name = "CorridorStrip", Size = Vector3.new(10, 0.2, 16), CFrame = CFrame.new(0, 0.6, 8) },
		-- Office floor accent
		{ Name = "OfficeAccent", Size = Vector3.new(16, 0.2, 12), CFrame = CFrame.new(0, 0.6, 20) },
	}
	for _, w in ipairs(interior) do
		local color = COLORS.InnerWall
		local mat = Enum.Material.Concrete
		if w.Name == "CorridorStrip" then
			color = COLORS.Corridor
		elseif w.Name == "OfficeAccent" then
			color = COLORS.OfficeFloor
		elseif w.Name:find("Hall") then
			color = COLORS.HallWall
		end
		ensureNamedPart(structure, w.Name, {
			Size = w.Size,
			CFrame = w.CFrame,
			Color = color,
			Material = mat,
			CanCollide = false,
			Anchored = true,
		}, refreshVisuals)
	end

	-- Optional desk in office (aesthetic)
	ensureNamedPart(structure, "WardenDesk", {
		Size = Vector3.new(6, 1.5, 3),
		CFrame = CFrame.new(PAD.Desk),
		Color = COLORS.Desk,
		Material = Enum.Material.Wood,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
end

local function ensureOffice(model, refreshVisuals)
	local claim = model:FindFirstChild("ClaimPad", true)
	if not (claim and claim:IsA("BasePart")) then
		claim = ensureNamedPart(model, "ClaimPad", {
			Size = Vector3.new(8, 1, 8),
			CFrame = CFrame.new(PAD.Claim),
			CanCollide = false,
			Color = COLORS.Claim,
			Material = Enum.Material.Neon,
		}, refreshVisuals)
	elseif refreshVisuals then
		claim.Color = COLORS.Claim
		claim.Material = Enum.Material.Neon
		claim.Size = Vector3.new(8, 1, 8)
		claim.CanCollide = false
		claim.CFrame = CFrame.new(PAD.Claim)
	end
	if claim:GetAttribute("Claimable") == nil then
		claim:SetAttribute("Claimable", true)
	end

	-- Claim billboards (Assigner updates ClaimedBy text)
	ensureBillboardLabel(claim, "ClaimBillboard", "Claim Prison", Vector3.new(0, 3, 0), 20)
	local _, claimedLabel = ensureBillboardLabel(claim, "ClaimedByBillboard", "", Vector3.new(0, 4.5, 0), 16)
	claimedLabel.TextColor3 = Color3.fromRGB(200, 255, 200)

	if not model:FindFirstChild("PlayerSpawn", true) then
		ensureNamedPart(model, "PlayerSpawn", {
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(PAD.PlayerSpawn),
			CanCollide = false,
			Transparency = 0.5,
			Color = COLORS.PlayerSpawn,
		}, refreshVisuals)
	elseif refreshVisuals then
		local ps = model:FindFirstChild("PlayerSpawn", true)
		if ps and ps:IsA("BasePart") then
			ps.CFrame = CFrame.new(PAD.PlayerSpawn)
			ps.Transparency = 0.5
			ps.CanCollide = false
		end
	end
end

local function ensureButtons(model, refreshVisuals)
	local buttons = ensureFolder(model, "Buttons")
	ensurePurchaseButton(buttons, "Cell2", "Cell2", PAD.BtnCell2, COLORS.ButtonCell2, refreshVisuals)
	ensurePurchaseButton(buttons, "Cell3", "Cell3", PAD.BtnCell3, COLORS.ButtonCell3, refreshVisuals)
	ensurePurchaseButton(buttons, "Cell4", "Cell4", PAD.BtnCell4, COLORS.ButtonCell4, refreshVisuals)
	ensurePurchaseButton(buttons, "Kitchen", "Kitchen", PAD.BtnKitchen, COLORS.ButtonKitchen, refreshVisuals)
end

local function ensureUnlocks(model, refreshVisuals)
	local unlocks = ensureFolder(model, "Unlocks")
	-- Cell1 free / Owned+visible with bars; Cell2–4 + Kitchen for Assigner to hide
	ensureUnlockCell(unlocks, "Cell1", PAD.Cell1, refreshVisuals, true)
	ensureUnlockCell(unlocks, "Cell2", PAD.Cell2, refreshVisuals, false)
	ensureUnlockCell(unlocks, "Cell3", PAD.Cell3, refreshVisuals, false)
	ensureUnlockCell(unlocks, "Cell4", PAD.Cell4, refreshVisuals, false)
	ensureUnlockCell(unlocks, "Kitchen", PAD.Kitchen, refreshVisuals, false)
end

local function ensureIntake(model, refreshVisuals)
	local droppers = ensureFolder(model, "Droppers")
	local y = PAD.IntakeY
	local z = PAD.IntakeZ
	-- Intake_Cell1 Active (RequiresUnlock=Cell1); others inactive until unlock Owned
	ensureDropper(droppers, "Intake_Cell1", "Cell1", "Cell1", Vector3.new(-12, y, z), refreshVisuals)
	ensureDropper(droppers, "Intake_Cell2", "Cell2", "Cell2", Vector3.new(-4, y, z), refreshVisuals)
	ensureDropper(droppers, "Intake_Cell3", "Cell3", "Cell3", Vector3.new(4, y, z), refreshVisuals)
	ensureDropper(droppers, "Intake_Cell4", "Cell4", "Cell4", Vector3.new(12, y, z), refreshVisuals)
	ensureDropper(droppers, "Intake_Kitchen", "Kitchen", "Kitchen", Vector3.new(0, y, z + 2), refreshVisuals)
end

local function ensureHelpers(model, refreshVisuals)
	local guard = model:FindFirstChild("GuardSpawn", true)
	local hasGuard = guard and guard:IsA("BasePart")
	if not hasGuard then
		for _, folderName in ipairs({ "GuardSpawns", "StaffSpawns" }) do
			local folder = model:FindFirstChild(folderName)
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
		ensureNamedPart(model, "GuardSpawn", {
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(PAD.GuardSpawn),
			CanCollide = false,
			Transparency = 0.5,
			Color = COLORS.Guard,
			Material = Enum.Material.Neon,
		}, refreshVisuals)
		local gs = model:FindFirstChild("GuardSpawn")
		if gs and gs:IsA("BasePart") then
			ensureBillboardLabel(gs, "HelperLabel", "GuardSpawn", Vector3.new(0, 2, 0), 12)
		end
	elseif refreshVisuals and guard and guard:IsA("BasePart") then
		guard.Transparency = 0.5
		guard.CFrame = CFrame.new(PAD.GuardSpawn)
	end

	local escape = model:FindFirstChild("EscapePoint", true)
	if not (escape and escape:IsA("BasePart")) then
		local folder = model:FindFirstChild("EscapePoints")
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
			ensureNamedPart(model, "EscapePoint", {
				Size = Vector3.new(3, 1, 3),
				CFrame = CFrame.new(PAD.EscapePoint),
				CanCollide = false,
				Transparency = 0.5,
				Color = COLORS.Escape,
				Material = Enum.Material.Neon,
			}, refreshVisuals)
			local ep = model:FindFirstChild("EscapePoint")
			if ep and ep:IsA("BasePart") then
				ensureBillboardLabel(ep, "HelperLabel", "EscapePoint", Vector3.new(0, 2, 0), 12)
			end
		end
	elseif refreshVisuals and escape and escape:IsA("BasePart") then
		escape.Transparency = 0.5
		escape.CFrame = CFrame.new(PAD.EscapePoint)
	end
end

--- Build / fill the full warden pad on a TycoonTemplate (or clone).
-- @param model Model — tycoon pad root
-- @param refreshVisuals boolean — true only when DefaultAssetsBuilt (our template)
-- @return model
function WardenLayout.buildPad(model, refreshVisuals)
	if not model then
		return nil
	end
	refreshVisuals = refreshVisuals == true

	local floor = model:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		floor = ensureNamedPart(model, "Floor", {
			Size = PAD.FloorSize,
			CFrame = CFrame.new(0, 0, 0),
			Color = COLORS.Floor,
			Material = Enum.Material.Concrete,
		}, refreshVisuals)
	elseif refreshVisuals then
		floor.Color = COLORS.Floor
		floor.Material = Enum.Material.Concrete
		floor.Size = PAD.FloorSize
		floor.CFrame = CFrame.new(0, 0, 0)
	end
	if model:IsA("Model") and not model.PrimaryPart then
		model.PrimaryPart = floor
	end

	-- Silhouette walls only on DefaultAssets-built templates (never restyle user art)
	if refreshVisuals then
		ensureStructure(model, true)
	end

	ensureOffice(model, refreshVisuals)
	ensureButtons(model, refreshVisuals)
	ensureUnlocks(model, refreshVisuals)
	ensureIntake(model, refreshVisuals)
	ensureFolder(model, "ActiveInmates")
	ensureHelpers(model, refreshVisuals)

	if model:GetAttribute(BUILT_ATTR) ~= true and refreshVisuals then
		model:SetAttribute(BUILT_ATTR, true)
	end

	return model
end

--- Claim / ClaimedBy billboard helpers (used by Assigner via DefaultAssets).
function WardenLayout.ensureClaimBillboard(tycoon)
	if not tycoon then
		return nil
	end
	local claim = tycoon:FindFirstChild("ClaimPad", true)
	if not (claim and claim:IsA("BasePart")) then
		return nil
	end
	ensureBillboardLabel(claim, "ClaimBillboard", "Claim Prison", Vector3.new(0, 3, 0), 20)
	local _, claimedLabel = ensureBillboardLabel(claim, "ClaimedByBillboard", "", Vector3.new(0, 4.5, 0), 16)
	claimedLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
	return claim
end

function WardenLayout.setClaimedByDisplay(tycoon, displayName)
	local claim = WardenLayout.ensureClaimBillboard(tycoon)
	if not claim then
		return
	end
	local gui = claim:FindFirstChild("ClaimedByBillboard")
	local label = gui and gui:FindFirstChild("Label")
	if label then
		if displayName and displayName ~= "" then
			label.Text = "Claimed by " .. tostring(displayName)
		else
			label.Text = ""
		end
	end
	local claimGui = claim:FindFirstChild("ClaimBillboard")
	local claimLabel = claimGui and claimGui:FindFirstChild("Label")
	if claimLabel then
		if displayName and displayName ~= "" then
			claimLabel.Text = ""
		else
			claimLabel.Text = "Claim Prison"
		end
	end
end

WardenLayout.COLORS = COLORS
WardenLayout.PAD = PAD

return WardenLayout
