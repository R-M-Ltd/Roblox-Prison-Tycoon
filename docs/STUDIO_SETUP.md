# Studio setup checklist

1. Copy each `.lua` into the matching Roblox instance type (ModuleScript vs Script).
2. On `TycoonTemplate`, set a PrimaryPart.
3. Button attributes: `PurchaseId` = `Cell2` / `Cell3` / `Cell4` / `Kitchen`.
4. Dropper attributes: `RequiresUnlock`, optional `AimUnlock`, optional `DropInterval`.
5. Each unlock cell needs a Part named `Deposit` (CanCollide false for testing ok).
6. Cell1 starts owned/visible; no purchase button for Cell1.
7. Never edit live `Workspace.Tycoons` clones as source of truth — edit the template.
