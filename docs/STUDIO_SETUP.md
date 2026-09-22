# Studio setup checklist

1. Copy each `.lua` into the matching Roblox instance type (ModuleScript vs Script).
   - Include `ReplicatedStorage/DefaultAssets` (ModuleScript) and `ServerScriptService/00_DefaultAssetsBootstrap` (Script).
   - Name the bootstrap Script so it sorts early (`00_DefaultAssetsBootstrap`); it must run before Assigner if possible. Assigner/Dropper also call `DefaultAssets` defensively.
2. **Optional but recommended:** build polished `TycoonTemplate` / `InmateTemplate` in ServerStorage and place `TycoonSpawns`. If missing, `DefaultAssets` auto-creates playable Part-based defaults at runtime.
3. On a custom `TycoonTemplate`, set a PrimaryPart.
4. Button attributes: `PurchaseId` = `Cell2` / `Cell3` / `Cell4` / `Kitchen`.
5. Dropper attributes: `RequiresUnlock`, optional `AimUnlock`, optional `DropInterval`.
6. Each unlock cell needs a Part named `Deposit` (CanCollide false for testing ok).
7. Cell1 starts owned/visible; no purchase button for Cell1.
8. Never edit live `Workspace.Tycoons` clones as source of truth — edit the template.

9. World layer (day-night, zones, lockdown, staff, escapes): see **WORLD_SCRIPTS.md**.
   - `WorldConfig.FacilityClockControlsLighting` (default `true`) — set `false` if another Lighting script owns the sky.
