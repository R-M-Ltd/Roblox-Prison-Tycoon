# World scripts layer (Warden Empire)

Additive facility simulation on top of the existing tycoon purchase / deposit / income loop.
**Does not replace** TycoonAssigner, PurchaseHandler, InmateDropper, InmateCollector, or CellIncome.

## Scripts & modules

| Instance | Type | Location | Role |
|----------|------|----------|------|
| `WorldConfig` | ModuleScript | ReplicatedStorage | Tunables (day length, zones, lockdown, escape, staff, AI) |
| `WorldBootstrap` | Script | ServerScriptService | Start order; creates `Workspace.WorldState` + remotes folder |
| `FacilityClock` | ModuleScript | ServerScriptService | Day-night via `Lighting`; attributes on `WorldState` |
| `WorldZones` | ModuleScript | ServerScriptService | Yard / Cafeteria / … discovery (attribute + tag) |
| `SecurityWorld` | ModuleScript | ServerScriptService | Lockdown API; `LockdownActive` on each tycoon |
| `InmateWorldAI` | ModuleScript | ServerScriptService | Cheap wander for `ActiveInmates` |
| `StaffSpawner` | ModuleScript | ServerScriptService | Guards at `GuardSpawn` / waypoints |
| `EscapeAttempt` | ModuleScript | ServerScriptService | Rare night escapes toward `EscapePoint` |
| `WorldRemotes` | ModuleScript | ServerScriptService | Owner-only `RequestLockdown` remotes |

`InmateDropper` has a **one-line additive guard**: if `tycoon:GetAttribute("LockdownActive") == true`, it skips spawning. Existing dropper / collector / income behavior is otherwise unchanged.

## Runtime instances (created if missing)

### `Workspace.WorldState` (Folder)

| Attribute | Type | Meaning |
|-----------|------|---------|
| `IsNight` | boolean | Night window per `WorldConfig` |
| `TimeOfDayFraction` | number | `0–1` through the day cycle |
| `ClockTime` | number | Mirrored `Lighting.ClockTime` (0–24) |
| `AnyLockdown` | boolean | True if any claimed pad is locked down |
| `EscapeAttempts` | number | Counter of escape attempts this session |
| `WorldBootstrapped` | boolean | Set true when bootstrap finished |

### `ReplicatedStorage.WorldRemotes` (Folder)

| Name | Type | Direction | Notes |
|------|------|-----------|-------|
| `RequestLockdown` | RemoteEvent | Client → Server | Owner only; optional `duration` number (clamped 5–120) |
| `RequestEndLockdown` | RemoteEvent | Client → Server | Owner only |
| `LockdownState` | RemoteEvent | Server → Client | Notify result table |
| `LockdownChanged` | BindableEvent | Server only | `(tycoon, active)` for other scripts |

### Per-tycoon attributes (SecurityWorld)

| Attribute | Type | Meaning |
|-----------|------|---------|
| `LockdownActive` | boolean | Droppers pause; AI holds; escape skipped |
| `LockdownRemaining` | number | Seconds left (approx) |

## Studio setup checklist (world layer)

Copy each `.lua` into the matching Studio instance type (ModuleScript vs Script). Keep existing tycoon scripts.

### Required for basic clock / remotes
1. Add `WorldConfig` ModuleScript under ReplicatedStorage (from `ReplicatedStorage/WorldConfig.lua`).
2. Add these ModuleScripts under ServerScriptService: `FacilityClock`, `WorldZones`, `SecurityWorld`, `InmateWorldAI`, `StaffSpawner`, `EscapeAttempt`, `WorldRemotes`.
3. Add Script `WorldBootstrap` under ServerScriptService (runs the start order).
4. Re-sync the lockdown guard in `InmateDropper` (or paste the updated file).

### Optional — zones (inmate wander)
5. Create `Workspace.WorldZones` (Folder). Bootstrap creates an empty one if missing.
6. Add Parts named (or with `ZoneName` attribute):
   - `Yard`, `Cafeteria`, `Infirmary`, `Solitary`, `Intake`, `CellBlock`
7. Optional: CollectionService tag `WorldZone` on any BasePart.
8. Optional per-pad: `TycoonTemplate/Zones/` with the same part names (AI prefers pad-local zones).

### Optional — staff
9. `ServerStorage.GuardTemplate` — Model with PrimaryPart (same idea as InmateTemplate).
10. On template or pad: Part `GuardSpawn`, or folder `GuardSpawns` with Parts.
11. Optional: folder `GuardWaypoints` (pad or Workspace) for wander targets.
12. Without template/spawns, StaffSpawner warns once and no-ops.

### Optional — escape
13. Part `EscapePoint` on the tycoon (or `Workspace.EscapePoint` / `Workspace.EscapePoints/*`).
14. Without it, EscapeAttempt silently skips.

### Optional — lockdown button
15. Any BasePart with attribute `LockdownButton = true` (owner touch) triggers lockdown.

## Client usage (lockdown)

```lua
local Remotes = ReplicatedStorage:WaitForChild("WorldRemotes")
Remotes.RequestLockdown:FireServer(45) -- seconds
Remotes.LockdownState.OnClientEvent:Connect(print)
```

Ownership is validated server-side via `TycoonService.getPlayerTycoon` + `OwnerUserId`.

## Config knobs

Edit `ReplicatedStorage.WorldConfig`:
- `DayLengthSeconds`, `NightStartFraction`, `NightEndFraction`
- `LockdownDefaultDuration`, `LockdownCooldown`, `LockdownPausesDroppers`
- `InmateAIStepInterval`, `InmateWanderChance`, `InmateWanderSpeed`
- `StaffPerTycoon`, `StaffWanderInterval`
- `EscapeCheckInterval`, `EscapeChancePerCheck`

## Graceful degradation

Missing Studio assets produce **warn + no-op**, not errors:
- No zones → AI does not wander
- No GuardTemplate / GuardSpawn → no staff
- No EscapePoint → no escapes
- Tycoon loop (claim, buy, drop, deposit, income) keeps working either way

## Start order

`WorldBootstrap` → FacilityClock → WorldZones → SecurityWorld → WorldRemotes → InmateWorldAI → StaffSpawner → EscapeAttempt
