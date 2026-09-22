-- Script: ServerScriptService.00_DefaultAssetsBootstrap
-- Runs first (name sorts early). Creates missing Studio templates/spawns/zones.
-- Must run before TycoonAssigner / InmateDropper / WorldBootstrap rely on assets.
-- Idempotent: safe if another script also calls DefaultAssets.ensureAll().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = ReplicatedStorage:WaitForChild("DefaultAssets", 30)
if not module then
	warn("[00_DefaultAssetsBootstrap] DefaultAssets module missing — bare place may hang on WaitForChild.")
	return
end

local DefaultAssets = require(module)
print("[00_DefaultAssetsBootstrap] Ensuring default Studio assets…")
DefaultAssets.ensureAll()
print("[00_DefaultAssetsBootstrap] Defaults ready.")
