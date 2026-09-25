# Roblox Prison Tycoon (Warden Empire)

Luau scripts + Studio setup for a multi-pad owner-claim prison tycoon.

## Fantasy
You are the warden. Claim a pad, house inmates, unlock cells/facilities, earn cash.

## Studio hierarchy
```
ServerStorage
  TycoonTemplate      # optional — auto-created by WardenLayout if missing
    Floor / Structure/  # office → corridor → cell silhouette + outer fence
    ClaimPad / PlayerSpawn
    GuardSpawn / EscapePoint
    Buttons/          # Parts with PurchaseId attribute + cost billboards
    Unlocks/          # Cell1 (free) + Cell2..Kitchen; each cell needs Deposit
    Droppers/         # Intake_Cell1..4 + Intake_Kitchen (RequiresUnlock / AimUnlock)
    ActiveInmates/
  InmateTemplate      # optional — auto-created if missing
  GuardTemplate       # optional — auto-created if missing

ReplicatedStorage
  TycoonConfig        # ModuleScript
  TycoonService       # ModuleScript
  TycoonVisibility    # ModuleScript (shared unlock/dropper helpers)
  WorldConfig         # ModuleScript (world tunables)
  WardenLayout        # ModuleScript — pad silhouette builder (office→cells)
  DefaultAssets       # ModuleScript — ensureAll boot; calls WardenLayout

ServerScriptService
  00_DefaultAssetsBootstrap  # Script — ensure templates/spawns/zones first
  PlayerSetup
  TycoonAssigner
  PurchaseHandler
  InmateDropper
  InmateCollector
  CellIncome
  WorldBootstrap      # Script — world layer entry
  FacilityClock       # ModuleScript
  WorldZones          # ModuleScript
  SecurityWorld       # ModuleScript
  InmateWorldAI       # ModuleScript
  StaffSpawner        # ModuleScript
  EscapeAttempt       # ModuleScript
  WorldRemotes        # ModuleScript

Workspace
  TycoonSpawns/       # optional — auto-created (2 pads) if empty
  Tycoons/            # runtime clones
  WorldState/         # runtime clock + lockdown attrs (created by bootstrap)
  WorldZones/         # optional — auto-created zone Parts if empty
```

## Install
1. Create matching ModuleScripts/Scripts in Studio from the `.lua` files in this repo
   (include `WardenLayout`, `DefaultAssets`, and `00_DefaultAssetsBootstrap`).
2. **Recommended:** build polished `TycoonTemplate` / `InmateTemplate` and place `TycoonSpawns`.
   A **bare place** still boots: `WardenLayout` builds the full pad silhouette;
   defaults also create 2 spawn pads, world zones, and guard/inmate models.
3. Play: claim a pad, buy Cell2 with $50, watch droppers + deposits pay the owner.

## Config
See `ReplicatedStorage/TycoonConfig.lua` for prices and income rates.

Primary cash is the Deposit collector. Passive income defaults to `0` to avoid double-pay.

`WorldConfig.FacilityClockControlsLighting` (default `true`) — set `false` if another Lighting / atmosphere script should own `Lighting.ClockTime`.

## Warden layout
Full pad builder (office → intake → corridor → cell block + perimeter).
See **[docs/WARDEN_LAYOUT.md](docs/WARDEN_LAYOUT.md)** for Studio paste types, collider rules, and claim→buy→deposit checklist.

## World layer
Additive facility simulation (day-night, zones, lockdown, inmate wander, staff, rare escapes).
See **[docs/WORLD_SCRIPTS.md](docs/WORLD_SCRIPTS.md)** for Studio checklist and attributes.
Does not replace the tycoon purchase / deposit loop — hooks via attributes only.

## GitHub
https://github.com/R-M-Ltd/Roblox-Prison-Tycoon
