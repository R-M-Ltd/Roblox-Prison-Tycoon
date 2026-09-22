-- ModuleScript: ReplicatedStorage.WorldConfig
-- Tunables for the world / facility simulation layer (additive to tycoon loop).
local WorldConfig = {}

-- Full day-night cycle length in real seconds
WorldConfig.DayLengthSeconds = 180

-- When true (default), FacilityClock writes Lighting.ClockTime each tick.
-- Set false if another lighting / atmosphere script owns the sky clock.
WorldConfig.FacilityClockControlsLighting = true

-- Fraction of cycle that counts as night [0, 1). Night wraps across midnight.
-- Default: night from 0.75 (dusk) through 0.25 (dawn).
WorldConfig.NightStartFraction = 0.75
WorldConfig.NightEndFraction = 0.25

-- Clock attribute host (created under Workspace by WorldBootstrap if missing)
WorldConfig.WorldStateName = "WorldState"

-- Zone part / folder names expected under Workspace.WorldZones (or per-tycoon Zones)
WorldConfig.ZoneNames = {
	"Yard",
	"Cafeteria",
	"Infirmary",
	"Solitary",
	"Intake",
	"CellBlock",
}

-- Lockdown
WorldConfig.LockdownDefaultDuration = 45
WorldConfig.LockdownPausesDroppers = true
WorldConfig.LockdownCooldown = 15

-- Inmate lightweight AI
WorldConfig.InmateAIStepInterval = 1.5
WorldConfig.InmateWanderChance = 0.35
WorldConfig.InmateWanderSpeed = 8
WorldConfig.MaxInmatesProcessedPerStep = 8

-- Staff
WorldConfig.StaffPerTycoon = 2
WorldConfig.StaffWanderInterval = 6
WorldConfig.StaffWanderSpeed = 10

-- Escape attempts (rare, night only)
WorldConfig.EscapeCheckInterval = 25
WorldConfig.EscapeChancePerCheck = 0.03
WorldConfig.EscapeSpeed = 14
WorldConfig.EscapeDespawnSeconds = 20

-- Remotes folder name under ReplicatedStorage
WorldConfig.RemotesFolderName = "WorldRemotes"

return WorldConfig
