# Warden layout world builder

Server-side ModuleScript that builds the playable pad silhouette end-to-end:

**office → intake → corridor → cell block + perimeter walls**

Wired to existing `TycoonTemplate` / `WorldZones` / `TycoonSpawns` contracts so
**claim → buy → deposit** still works. Parts only — no MeshIds required.

## Studio paste types

| File | Studio type | Parent |
|------|-------------|--------|
| `ReplicatedStorage/WardenLayout.lua` | **ModuleScript** named `WardenLayout` | ReplicatedStorage |
| `ReplicatedStorage/DefaultAssets.lua` | **ModuleScript** named `DefaultAssets` | ReplicatedStorage |
| `ServerScriptService/00_DefaultAssetsBootstrap.lua` | **Script** named `00_DefaultAssetsBootstrap` | ServerScriptService |

Boot path (unchanged): `00_DefaultAssetsBootstrap` → `DefaultAssets.ensureAll()` →
`ensureTycoonTemplate()` → `WardenLayout.buildPad(...)`.

Assigner / Dropper also call `DefaultAssets` defensively; safe if bootstrap already ran.

## What the builder creates

Per pad (local coords around `Floor` origin; **+Z = office / claim**, **−Z = cells**):

### 1. Office
- `ClaimPad` — orange neon, `Claimable=true`, Claim / ClaimedBy billboards
- `PlayerSpawn` — nearby teleport target after claim
- Optional desk + office partition walls under `Structure/` (aesthetic)

### 2. Intake
- `Droppers/Intake_Cell1` — `RequiresUnlock=Cell1`, `AimUnlock=Cell1` (Active via Visibility)
- `Droppers/Intake_Cell2..4` + `Intake_Kitchen` — same attrs for each unlock; inactive until Owned
- Neon orange parts + Intake billboards

### 3. Corridor
- `Structure/HallWallL|R`, `CorridorStrip` — walkway connecting office → cells
- **CanCollide = false** (must not block Inmate → Deposit)

### 4. Cell block (`Unlocks/`)
| Unlock | Start state | Notes |
|--------|-------------|-------|
| `Cell1` | Owned + visible + bars | Free bootstrap income path |
| `Cell2`–`Cell4`, `Kitchen` | Hidden (`Owned=false`) | Revealed by PurchaseHandler |
| Each cell | `Floor` + `Deposit` | Deposit: Transparency 1, **CanCollide false**, **CanTouch true** |
| Bars | Aesthetic only | **CanCollide false** — solids block Intake→Deposit |

### 5. Walls (`Structure/`)
- **OuterN/S/E/W** — perimeter fence, **CanCollide = true** (containment)
- Interior partitions / CellDivider / desk — **CanCollide = false**

### 6. Buttons (`Buttons/`)
| Name | PurchaseId | Cost (TycoonConfig) |
|------|------------|---------------------|
| Cell2 | Cell2 | $50 |
| Cell3 | Cell3 | $150 |
| Cell4 | Cell4 | $400 |
| Kitchen | Kitchen | $1000 |

SurfaceGui `CostGui` + Billboard `CostBillboard` on each button.

### 7. Helpers
- `GuardSpawn` — semi-visible blue neon + label (StaffSpawner)
- `EscapePoint` — semi-visible red neon + label (EscapeAttempt)
- `ActiveInmates/` folder (InmateDropper / Collector)

### 8. Marker
- Sets `DefaultAssetsBuilt=true` on newly created templates
- User art **without** that attribute: structure-only fill (no restyle)

## Workspace still ensured

| Instance | Role |
|----------|------|
| `Workspace.TycoonSpawns` | ≥2 spawn Parts (pads PivotTo these) |
| `Workspace.WorldZones` | Yard, Cafeteria, Infirmary, Solitary, Intake, CellBlock per WorldConfig |

## Collider rules (do not break)

1. Aesthetic parts on the **Intake → Deposit** path: **CanCollide = false**
2. Deposits: invisible, **CanCollide = false**, **CanTouch = true**
3. Outer fence: **CanCollide = true** OK
4. Never rename attributes: `PurchaseId`, `RequiresUnlock`, `AimUnlock`, `Claimable`, `Owned`, `Active`, `OwnerUserId`, `IsTycoon`, `DefaultAssetsBuilt`

## Claim → buy → deposit (still OK)

1. **Claim** — touch `ClaimPad` → Assigner sets `OwnerUserId`, hides claim, teleports to `PlayerSpawn`
2. **Drop** — `Intake_Cell1` Active → inmates toward Cell1 Deposit
3. **Collect** — InmateCollector pays `CashPerInmate` on owned Deposit touch
4. **Buy** — touch Button with `PurchaseId` → PurchaseHandler spends cash, sets unlock Owned, `syncDroppers`
5. New intake droppers activate for purchased cells

## Colors (warden-empire)

Concrete floors / walls, orange neon claim + droppers, yellow→pink neon buy buttons,
blue GuardSpawn, red EscapePoint, metal bars.
