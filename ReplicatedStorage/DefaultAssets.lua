-- ModuleScript: ReplicatedStorage.DefaultAssets
-- Idempotent Studio fallbacks so a bare place still boots the core loop.
-- Templates marked DefaultAssetsBuilt=true may have visuals refreshed;
-- user-authored templates without that attr only get missing structure filled.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local worldConfigModule = ReplicatedStorage:WaitForChild("WorldConfig", 10)
local WorldConfig = worldConfigModule and require(worldConfigModule) or {}

local tycoonConfigModule = ReplicatedStorage:FindFirstChild("TycoonConfig")
local TycoonConfig = tycoonConfigModule and require(tycoonConfigModule) or nil

local DefaultAssets = {}

local MARKER = "_AutoDefault"
local BUILT_ATTR = "DefaultAssetsBuilt"

-- Fallback purchase prices if TycoonConfig is unavailable (match TycoonConfig.Purchases)
local FALLBACK_COSTS = {
	Cell2 = 50,
	Cell3 = 150,
	Cell4 = 400,
	Kitchen = 1000,
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

local function markBuilt(inst)
	inst:SetAttribute(BUILT_ATTR, true)
	mark(inst)
	return inst
end

local function isDefaultBuilt(inst)
	return inst ~= nil and inst:GetAttribute(BUILT_ATTR) == true
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
	-- Also a Billboard for readability from the side
	ensureBillboardLabel(btn, "CostBillboard", text, Vector3.new(0, 2, 0), 16)
end

local function ensureWeld(part0, part1, name)
	local existing = part0:FindFirstChild(name or "Weld")
	if existing and existing:IsA("WeldConstraint") then
		existing.Part0 = part0
		existing.Part1 = part1
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local w = Instance.new("WeldConstraint")
	w.Name = name or "Weld"
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
	mark(w)
	return w
end

local function ensureCellBars(cell, floor, refreshVisuals)
	local bars = cell:FindFirstChild("Bars")
	if not bars then
		bars = Instance.new("Model")
		bars.Name = "Bars"
		bars.Parent = cell
		mark(bars)
	end
	local baseCf = floor.CFrame
	-- Aesthetic only (CanCollide false): solid bars blocked Intake→Deposit
	-- for Cell1, which is the StartingCash=0 bootstrap income path.
	for i = 1, 5 do
		local x = -3 + (i - 1) * 1.5
		local barName = "Bar" .. tostring(i)
		ensureNamedPart(bars, barName, {
			Size = Vector3.new(0.3, 6, 0.3),
			CFrame = baseCf * CFrame.new(x, 3.5, 4),
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Anchored = true,
		}, refreshVisuals)
	end
	-- Top crossbar
	ensureNamedPart(bars, "Crossbar", {
		Size = Vector3.new(8, 0.3, 0.3),
		CFrame = baseCf * CFrame.new(0, 6.5, 4),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	-- Side walls of cell
	ensureNamedPart(bars, "WallL", {
		Size = Vector3.new(0.5, 6, 8),
		CFrame = baseCf * CFrame.new(-4, 3.5, 0),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Concrete,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	ensureNamedPart(bars, "WallR", {
		Size = Vector3.new(0.5, 6, 8),
		CFrame = baseCf * CFrame.new(4, 3.5, 0),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Concrete,
		CanCollide = false,
		Anchored = true,
	}, refreshVisuals)
	ensureNamedPart(bars, "WallBack", {
		Size = Vector3.new(8, 6, 0.5),
		CFrame = baseCf * CFrame.new(0, 3.5, -4),
		Color = Color3.fromRGB(70, 70, 80),
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
		Color = Color3.fromRGB(100, 100, 105),
		Material = Enum.Material.Concrete,
		Parent = cell,
	}, refreshVisuals)
	if cell:IsA("Model") then
		cell.PrimaryPart = floor
	end

	-- Deposit: invisible sensor filling the cell floor
	local deposit = ensureNamedPart(cell, "Deposit", {
		Size = Vector3.new(7.5, 2, 7.5),
		CFrame = CFrame.new(offset + Vector3.new(0, 1.5, 0)),
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		Anchored = true,
		Color = Color3.fromRGB(0, 255, 100),
		Parent = cell,
	}, refreshVisuals)
	deposit.CanCollide = false
	deposit.CanTouch = true
	if deposit.Transparency < 1 then
		deposit.Transparency = 1
	end

	-- Bars aesthetic only when refreshing DefaultAssets-built templates
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
		Color = Color3.fromRGB(255, 140, 40),
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

-- Claim pad + optional ClaimedBy billboard (Assigner updates ownership text).
function DefaultAssets.ensureClaimBillboard(tycoon)
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

function DefaultAssets.setClaimedByDisplay(tycoon, displayName)
	local claim = DefaultAssets.ensureClaimBillboard(tycoon)
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

function DefaultAssets.ensurePadParts(tycoon, refreshVisuals)
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
			Transparency = 0.5,
			Color = Color3.fromRGB(40, 80, 200),
			Material = Enum.Material.Neon,
		}, refreshVisuals)
		local gs = tycoon:FindFirstChild("GuardSpawn")
		if gs and gs:IsA("BasePart") then
			ensureBillboardLabel(gs, "HelperLabel", "GuardSpawn", Vector3.new(0, 2, 0), 12)
		end
	elseif refreshVisuals and guard and guard:IsA("BasePart") then
		guard.Transparency = 0.5
	end

	local escape = tycoon:FindFirstChild("EscapePoint", true)
	if not (escape and escape:IsA("BasePart")) then
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
				Transparency = 0.5,
				Color = Color3.fromRGB(200, 40, 40),
				Material = Enum.Material.Neon,
			}, refreshVisuals)
			local ep = tycoon:FindFirstChild("EscapePoint")
			if ep and ep:IsA("BasePart") then
				ensureBillboardLabel(ep, "HelperLabel", "EscapePoint", Vector3.new(0, 2, 0), 12)
			end
		end
	elseif refreshVisuals and escape and escape:IsA("BasePart") then
		escape.Transparency = 0.5
	end
end

local function ensurePrisonSilhouette(model, refreshVisuals)
	local structure = model:FindFirstChild("Structure")
	if not structure then
		structure = Instance.new("Folder")
		structure.Name = "Structure"
		structure.Parent = model
		mark(structure)
	end

	-- Outer outline walls (office → hallway → cell silhouette)
	local walls = {
		{ Name = "OuterN", Size = Vector3.new(42, 8, 1), CFrame = CFrame.new(0, 4, -21), Color = Color3.fromRGB(55, 55, 60) },
		{ Name = "OuterS", Size = Vector3.new(42, 8, 1), CFrame = CFrame.new(0, 4, 21), Color = Color3.fromRGB(55, 55, 60) },
		{ Name = "OuterE", Size = Vector3.new(1, 8, 42), CFrame = CFrame.new(21, 4, 0), Color = Color3.fromRGB(55, 55, 60) },
		{ Name = "OuterW", Size = Vector3.new(1, 8, 42), CFrame = CFrame.new(-21, 4, 0), Color = Color3.fromRGB(55, 55, 60) },
		-- Office partition (claim end / south)
		{ Name = "OfficeWallL", Size = Vector3.new(1, 6, 10), CFrame = CFrame.new(-6, 3, 14), Color = Color3.fromRGB(65, 65, 72) },
		{ Name = "OfficeWallR", Size = Vector3.new(1, 6, 10), CFrame = CFrame.new(6, 3, 14), Color = Color3.fromRGB(65, 65, 72) },
		-- Hallway sides
		{ Name = "HallWallL", Size = Vector3.new(1, 6, 12), CFrame = CFrame.new(-5, 3, 4), Color = Color3.fromRGB(60, 60, 68) },
		{ Name = "HallWallR", Size = Vector3.new(1, 6, 12), CFrame = CFrame.new(5, 3, 4), Color = Color3.fromRGB(60, 60, 68) },
		-- Cell-block divider
		{ Name = "CellDivider", Size = Vector3.new(20, 6, 1), CFrame = CFrame.new(0, 3, -2), Color = Color3.fromRGB(50, 50, 58) },
	}
	for _, w in ipairs(walls) do
		-- Visual silhouette only — CellDivider sat on Intake_Cell1→Deposit path
		ensureNamedPart(structure, w.Name, {
			Size = w.Size,
			CFrame = w.CFrame,
			Color = w.Color,
			Material = Enum.Material.Concrete,
			CanCollide = false,
			Anchored = true,
		}, refreshVisuals)
	end
end

function DefaultAssets.ensureInmateTemplate()
	local existing = ServerStorage:FindFirstChild("InmateTemplate")
	local refresh = existing ~= nil and isDefaultBuilt(existing)

	if existing and not refresh then
		-- User-authored: only ensure PrimaryPart, never restyle
		if existing:IsA("Model") and not existing.PrimaryPart then
			local part = existing:FindFirstChildWhichIsA("BasePart", true)
			if part then
				existing.PrimaryPart = part
			end
		end
		return existing
	end

	local model = existing
	if not model then
		model = Instance.new("Model")
		model.Name = "InmateTemplate"
		markBuilt(model)
	end

	-- Orange jumpsuit body + darker head; unanchored for physics
	local body = ensureNamedPart(model, "Body", {
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(0, 1, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(255, 140, 0),
		Material = Enum.Material.SmoothPlastic,
	}, true)
	local head = ensureNamedPart(model, "Head", {
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(0, 2.6, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(90, 55, 35),
		Material = Enum.Material.SmoothPlastic,
	}, true)
	ensureWeld(body, head, "HeadWeld")
	model.PrimaryPart = body
	if not model.Parent then
		model.Parent = ServerStorage
		print("[DefaultAssets] Created ServerStorage.InmateTemplate")
	end
	return model
end

function DefaultAssets.ensureGuardTemplate()
	local existing = ServerStorage:FindFirstChild("GuardTemplate")
	local refresh = existing ~= nil and isDefaultBuilt(existing)

	if existing and not refresh then
		if existing:IsA("Model") and not existing.PrimaryPart then
			local part = existing:FindFirstChildWhichIsA("BasePart", true)
			if part then
				existing.PrimaryPart = part
			end
		end
		return existing
	end

	local model = existing
	if not model then
		model = Instance.new("Model")
		model.Name = "GuardTemplate"
		markBuilt(model)
	end

	-- Blue body + black belts/vest accents; distinct from inmates
	local body = ensureNamedPart(model, "Body", {
		Size = Vector3.new(2, 2.5, 1),
		CFrame = CFrame.new(0, 1.25, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(30, 60, 140),
		Material = Enum.Material.SmoothPlastic,
	}, true)
	local vest = ensureNamedPart(model, "Vest", {
		Size = Vector3.new(2.2, 1.2, 1.2),
		CFrame = CFrame.new(0, 1.5, 0),
		Anchored = false,
		CanCollide = false,
		Color = Color3.fromRGB(20, 20, 25),
		Material = Enum.Material.SmoothPlastic,
	}, true)
	local head = ensureNamedPart(model, "Head", {
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(0, 2.9, 0),
		Anchored = false,
		CanCollide = true,
		Color = Color3.fromRGB(90, 55, 35),
		Material = Enum.Material.SmoothPlastic,
	}, true)
	ensureWeld(body, vest, "VestWeld")
	ensureWeld(body, head, "HeadWeld")
	model.PrimaryPart = body
	if not model.Parent then
		model.Parent = ServerStorage
		print("[DefaultAssets] Created ServerStorage.GuardTemplate")
	end
	return model
end

-- Fill missing claim / buttons / unlocks / droppers so live scripts can run.
-- Idempotent: never replaces Studio-authored children that already exist.
-- refreshVisuals=true only when DefaultAssetsBuilt (our template); otherwise structure-only.
local function ensureTycoonPlayableStructure(model, refreshVisuals)
	refreshVisuals = refreshVisuals == true

	local floor = model:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		floor = ensureNamedPart(model, "Floor", {
			Size = Vector3.new(40, 1, 40),
			CFrame = CFrame.new(0, 0, 0),
			Color = Color3.fromRGB(145, 145, 135),
			Material = Enum.Material.Concrete,
		}, refreshVisuals)
	elseif refreshVisuals then
		floor.Color = Color3.fromRGB(145, 145, 135)
		floor.Material = Enum.Material.Concrete
		floor.Size = Vector3.new(40, 1, 40)
	end
	if not model.PrimaryPart then
		model.PrimaryPart = floor
	end

	-- Silhouette walls only on DefaultAssets-built templates (never restyle user art)
	if refreshVisuals then
		ensurePrisonSilhouette(model, true)
	end

	local claim = model:FindFirstChild("ClaimPad", true)
	if not (claim and claim:IsA("BasePart")) then
		claim = ensureNamedPart(model, "ClaimPad", {
			Size = Vector3.new(8, 1, 8),
			CFrame = CFrame.new(0, 1, 16),
			CanCollide = false,
			Color = Color3.fromRGB(40, 255, 80),
			Material = Enum.Material.Neon,
		}, refreshVisuals)
	elseif refreshVisuals then
		claim.Color = Color3.fromRGB(40, 255, 80)
		claim.Material = Enum.Material.Neon
		claim.Size = Vector3.new(8, 1, 8)
		claim.CanCollide = false
	end
	if claim:GetAttribute("Claimable") == nil then
		claim:SetAttribute("Claimable", true)
	end
	DefaultAssets.ensureClaimBillboard(model)

	if not model:FindFirstChild("PlayerSpawn", true) then
		ensureNamedPart(model, "PlayerSpawn", {
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(0, 1, 10),
			CanCollide = false,
			Transparency = 0.5,
			Color = Color3.fromRGB(180, 180, 255),
		}, refreshVisuals)
	end

	local buttons = ensureFolder(model, "Buttons")
	ensurePurchaseButton(buttons, "Cell2", "Cell2", Vector3.new(-8, 1, 8), Color3.fromRGB(255, 220, 60), refreshVisuals)
	ensurePurchaseButton(buttons, "Cell3", "Cell3", Vector3.new(-12, 1, 8), Color3.fromRGB(255, 180, 60), refreshVisuals)
	ensurePurchaseButton(buttons, "Cell4", "Cell4", Vector3.new(-16, 1, 8), Color3.fromRGB(255, 140, 60), refreshVisuals)
	ensurePurchaseButton(buttons, "Kitchen", "Kitchen", Vector3.new(8, 1, 8), Color3.fromRGB(255, 100, 160), refreshVisuals)

	local unlocks = ensureFolder(model, "Unlocks")
	-- Cell1 visible with bars; Cell2+ exist for Assigner to hide
	ensureUnlockCell(unlocks, "Cell1", Vector3.new(-10, 1, -6), refreshVisuals, true)
	ensureUnlockCell(unlocks, "Cell2", Vector3.new(10, 1, -6), refreshVisuals, false)
	ensureUnlockCell(unlocks, "Cell3", Vector3.new(-10, 1, -16), refreshVisuals, false)
	ensureUnlockCell(unlocks, "Cell4", Vector3.new(10, 1, -16), refreshVisuals, false)
	ensureUnlockCell(unlocks, "Kitchen", Vector3.new(0, 1, -22), refreshVisuals, false)

	local droppers = ensureFolder(model, "Droppers")
	ensureDropper(droppers, "Intake_Cell1", "Cell1", "Cell1", Vector3.new(-10, 5, 4), refreshVisuals)
	ensureDropper(droppers, "Intake_Cell2", "Cell2", "Cell2", Vector3.new(10, 5, 4), refreshVisuals)

	ensureFolder(model, "ActiveInmates")
	DefaultAssets.ensurePadParts(model, refreshVisuals)
	return model
end

function DefaultAssets.ensureTycoonTemplate()
	local existing = ServerStorage:FindFirstChild("TycoonTemplate")
	if existing then
		local refresh = isDefaultBuilt(existing)
		ensureTycoonPlayableStructure(existing, refresh)
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "TycoonTemplate"
	markBuilt(model)
	ensureTycoonPlayableStructure(model, true)
	model.Parent = ServerStorage
	print("[DefaultAssets] Created ServerStorage.TycoonTemplate (minimal prison pad)")
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
