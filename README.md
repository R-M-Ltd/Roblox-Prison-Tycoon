# Roblox Prison Tycoon (Warden Empire)

Luau scripts + Studio setup for a multi-pad owner-claim prison tycoon.

## Fantasy
You are the warden. Claim a pad, house inmates, unlock cells/facilities, earn cash.

## Studio hierarchy
```
ServerStorage
  TycoonTemplate
    ClaimPad
    PlayerSpawn (optional)
    Buttons/          # Parts with PurchaseId attribute
    Unlocks/          # Cell1 (free) + Cell2..Kitchen; each cell needs Deposit
    Droppers/         # Intake_CellN with RequiresUnlock / AimUnlock
  InmateTemplate      # Model with PrimaryPart

ReplicatedStorage
  TycoonConfig        # ModuleScript
  TycoonService       # ModuleScript
  TycoonVisibility    # ModuleScript (shared unlock/dropper helpers)
  WorldConfig         # ModuleScript (world tunables)

ServerScriptService
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
  TycoonSpawns/       # Spawn1, Spawn2, ...
  Tycoons/            # runtime clones
  WorldState/         # runtime clock + lockdown attrs (created by bootstrap)
  WorldZones/         # optional facility zone Parts
```

## Install
1. Create matching ModuleScripts/Scripts in Studio from the `.lua` files in this repo.
2. Build `TycoonTemplate` and `InmateTemplate` in ServerStorage.
3. Place `TycoonSpawns` parts spaced apart.
4. Play: claim a pad, buy Cell2 with $50, watch droppers + deposits pay the owner.

## Config
See `ReplicatedStorage/TycoonConfig.lua` for prices and income rates.

Primary cash is the Deposit collector. Passive income defaults to `0` to avoid double-pay.

## World layer
Additive facility simulation (day-night, zones, lockdown, inmate wander, staff, rare escapes).
See **[docs/WORLD_SCRIPTS.md](docs/WORLD_SCRIPTS.md)** for Studio checklist and attributes.
Does not replace the tycoon purchase / deposit loop — hooks via attributes only.

## GitHub
https://github.com/R-M-Ltd/Roblox-Prison-Tycoon
