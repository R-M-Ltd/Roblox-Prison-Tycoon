# World scripts layer (Warden Empire)

Additive facility simulation on top of the existing tycoon purchase / deposit / income loop.
**Does not replace** TycoonAssigner, PurchaseHandler, InmateDropper, InmateCollector, or CellIncome.

## Scripts & modules

| Instance | Type | Location | Role |
|----------|------|----------|------|
| `WorldConfig` | ModuleScript | ReplicatedStorage | Tunables (day length, zones, lockdown, escape, staff, AI) |
| `WardenLayout` | ModuleScript | ReplicatedStorage | Pad silhouette builder (office→intake→corridor→cells+walls) |
| `DefaultAssets` | ModuleScript | ReplicatedStorage | Idempotent auto-create; calls WardenLayout for TycoonTemplate |
| `00_DefaultAssetsBootstrap` | Script | ServerScriptService | Calls `DefaultAssets.ensureAll()` first (name sorts early) |
| `WorldBootstrap` | Script | ServerScriptService | Start order; creates `Workspace.WorldState` + remotes folder; calls `ensureWorld()` |
| `FacilityClock` | ModuleScript | ServerScriptService | Day-night attributes on `WorldState`; optional `Lighting` writes |
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
1. Add `WorldConfig` + `WardenLayout` + `DefaultAssets` ModuleScripts under ReplicatedStorage.
2. Add Script `00_DefaultAssetsBootstrap` under ServerScriptService (ensure defaults before Assigner).
3. Add these ModuleScripts under ServerScriptService: `FacilityClock`, `WorldZones`, `SecurityWorld`, `InmateWorldAI`, `StaffSpawner`, `EscapeAttempt`, `WorldRemotes`.
4. Add Script `WorldBootstrap` under ServerScriptService (runs the start order; calls `DefaultAssets.ensureWorld()`).
5. Re-sync the lockdown guard in `InmateDropper` (or paste the updated file).

### Zones (inmate wander) — auto-created if empty
6. `DefaultAssets.ensureWorldZones()` creates `Workspace.WorldZones` Parts named:
   - `Yard`, `Cafeteria`, `Infirmary`, `Solitary`, `Intake`, `CellBlock`
7. Replace with polished Studio Parts anytime; FindFirstChild skips re-create.
8. Optional: CollectionService tag `WorldZone` on any BasePart.
9. Optional per-pad: `TycoonTemplate/Zones/` with the same part names (AI prefers pad-local zones).

### Staff — auto-created if missing
10. `ServerStorage.GuardTemplate` auto-created (simple Model + PrimaryPart) if missing.
11. Per-pad `GuardSpawn` auto-added on template/pads via `ensurePadParts` if missing.
12. Optional: folder `GuardWaypoints` (pad or Workspace) for wander targets.

### Escape — auto-created if missing
13. Per-pad `EscapePoint` auto-added via `ensurePadParts` if missing (per-tycoon only; no shared world EscapePoint).

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
- `FacilityClockControlsLighting` (default `true`) — set `false` so FacilityClock only publishes `WorldState` attrs and does **not** write `Lighting.ClockTime`
- `LockdownDefaultDuration`, `LockdownCooldown`, `LockdownPausesDroppers`
- `InmateAIStepInterval`, `InmateWanderChance`, `InmateWanderSpeed`
- `StaffPerTycoon`, `StaffWanderInterval`
- `EscapeCheckInterval`, `EscapeChancePerCheck`

## Default assets (bare place)

`DefaultAssets.ensureAll()` (idempotent) creates when missing:
- `ServerStorage.InmateTemplate`, `GuardTemplate`, `TycoonTemplate` (full WardenLayout pad)
- `Workspace.TycoonSpawns` (≥2 spawn Parts)
- `Workspace.WorldZones` Parts for each `WorldConfig.ZoneNames` entry
- Per-pad `GuardSpawn` + `EscapePoint` via `WardenLayout` / `ensurePadParts`

See **WARDEN_LAYOUT.md** for the office→intake→corridor→cell silhouette and collider rules.

Studio-authored assets are still recommended for polish; existing named instances are never duplicated.

## Graceful degradation

- Missing Studio assets are **auto-created** by DefaultAssets (no infinite WaitForChild).
- Tycoon loop (claim, buy, drop, deposit, income) works on a bare place after pasting scripts.
- Set `FacilityClockControlsLighting = false` if another Lighting system owns the sky.

## Start order

`00_DefaultAssetsBootstrap` → (tycoon Scripts) → `WorldBootstrap` → FacilityClock → WorldZones → SecurityWorld → WorldRemotes → InmateWorldAI → StaffSpawner → EscapeAttempt
