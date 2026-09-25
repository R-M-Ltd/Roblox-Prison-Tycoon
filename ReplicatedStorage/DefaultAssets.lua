-- ModuleScript: ReplicatedStorage.DefaultAssets
-- Idempotent Studio fallbacks so a bare place still boots the core loop.
-- Pad silhouette (office → intake → corridor → cell block) is built by
-- ReplicatedStorage.WardenLayout; this module owns templates / spawns / zones
-- and the single ensureAll() boot path.
-- Templates marked DefaultAssetsBuilt=true may have visuals refreshed;
-- user-authored templates without that attr only get missing structure filled.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local worldConfigModule = ReplicatedStorage:WaitForChild("WorldConfig", 10)
local WorldConfig = worldConfigModule and require(worldConfigModule) or {}

local wardenLayoutModule = ReplicatedStorage:FindFirstChild("WardenLayout")
	or ReplicatedStorage:WaitForChild("WardenLayout", 5)
local WardenLayout = wardenLayoutModule and require(wardenLayoutModule) or nil
if not WardenLayout then
	warn("[DefaultAssets] WardenLayout missing — pad silhouette will be minimal stubs only")
end

local DefaultAssets = {}

local MARKER = "_AutoDefault"
local BUILT_ATTR = "DefaultAssetsBuilt"

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

-- Claim pad + optional ClaimedBy billboard (Assigner updates ownership text).
function DefaultAssets.ensureClaimBillboard(tycoon)
	if WardenLayout and WardenLayout.ensureClaimBillboard then
		return WardenLayout.ensureClaimBillboard(tycoon)
	end
	return nil
end

function DefaultAssets.setClaimedByDisplay(tycoon, displayName)
	if WardenLayout and WardenLayout.setClaimedByDisplay then
		WardenLayout.setClaimedByDisplay(tycoon, displayName)
	end
end

-- GuardSpawn / EscapePoint / missing-structure fill for pads that already exist
-- (Assigner prepareFresh). Never refresh visuals on live pivoted pads — after
-- PivotTo, BasePart CFrames are world-space; rewriting local offsets would snap
-- geometry back to the origin. Full visual refresh belongs to ensureTycoonTemplate.
function DefaultAssets.ensurePadParts(tycoon, refreshVisuals)
	if not tycoon then
		return
	end
	if WardenLayout and WardenLayout.buildPad then
		-- Only pass refreshVisuals=true when caller explicitly requests it on a
		-- pre-pivot template (ServerStorage). Assigner calls with nil → fill only.
		WardenLayout.buildPad(tycoon, refreshVisuals == true)
		return
	end

	-- Fallback stubs if WardenLayout absent
	local guard = tycoon:FindFirstChild("GuardSpawn", true)
	if not (guard and guard:IsA("BasePart")) then
		ensureNamedPart(tycoon, "GuardSpawn", {
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(14, 1, 0),
			CanCollide = false,
			Transparency = 0.5,
			Color = Color3.fromRGB(40, 80, 200),
			Material = Enum.Material.Neon,
		}, refreshVisuals)
	end
	local escape = tycoon:FindFirstChild("EscapePoint", true)
	if not (escape and escape:IsA("BasePart")) then
		ensureNamedPart(tycoon, "EscapePoint", {
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(0, 1, -18),
			CanCollide = false,
			Transparency = 0.5,
			Color = Color3.fromRGB(200, 40, 40),
			Material = Enum.Material.Neon,
		}, refreshVisuals)
	end
	ensureFolder(tycoon, "ActiveInmates")
end

function DefaultAssets.ensureInmateTemplate()
	local existing = ServerStorage:FindFirstChild("InmateTemplate")
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
		model.Name = "InmateTemplate"
		markBuilt(model)
	end

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
-- Idempotent. refreshVisuals=true only when DefaultAssetsBuilt; otherwise structure-only.
local function ensureTycoonPlayableStructure(model, refreshVisuals)
	refreshVisuals = refreshVisuals == true

	if WardenLayout and WardenLayout.buildPad then
		WardenLayout.buildPad(model, refreshVisuals)
		return model
	end

	-- Minimal fallback without WardenLayout (should not happen in shipped place)
	local floor = model:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		floor = ensureNamedPart(model, "Floor", {
			Size = Vector3.new(40, 1, 40),
			CFrame = CFrame.new(0, 0, 0),
			Color = Color3.fromRGB(145, 145, 135),
			Material = Enum.Material.Concrete,
		}, refreshVisuals)
	end
	if model:IsA("Model") and not model.PrimaryPart then
		model.PrimaryPart = floor
	end
	ensureFolder(model, "Buttons")
	ensureFolder(model, "Unlocks")
	ensureFolder(model, "Droppers")
	ensureFolder(model, "ActiveInmates")
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
	print("[DefaultAssets] Created ServerStorage.TycoonTemplate (WardenLayout pad)")
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
		Vector3.new(100, 1, 0), -- wider gap for 48x56 pads
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
		Yard = Vector3.new(0, 1, 50),
		Cafeteria = Vector3.new(40, 1, 50),
		Infirmary = Vector3.new(-40, 1, 50),
		Solitary = Vector3.new(0, 1, 70),
		Intake = Vector3.new(40, 1, 20),
		CellBlock = Vector3.new(-40, 1, 20),
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
