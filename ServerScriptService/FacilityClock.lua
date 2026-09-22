-- ModuleScript: ServerScriptService.FacilityClock
-- Drives day-night via Lighting and publishes clock attributes on WorldState.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local FacilityClock = {}

local worldState = nil
local running = false
local startedAt = 0

local function isNightFraction(fraction)
	local startF = WorldConfig.NightStartFraction
	local endF = WorldConfig.NightEndFraction
	if startF > endF then
		-- wraps midnight, e.g. 0.75 -> 1.0 and 0.0 -> 0.25
		return fraction >= startF or fraction < endF
	end
	return fraction >= startF and fraction < endF
end

local function publish(fraction, night)
	if not worldState then
		return
	end
	worldState:SetAttribute("TimeOfDayFraction", fraction)
	worldState:SetAttribute("IsNight", night)
	-- Roblox Lighting.ClockTime is 0–24 hours
	Lighting.ClockTime = fraction * 24
	worldState:SetAttribute("ClockTime", Lighting.ClockTime)
end

function FacilityClock.getWorldState()
	return worldState
end

function FacilityClock.isNight()
	if worldState then
		return worldState:GetAttribute("IsNight") == true
	end
	return false
end

function FacilityClock.getFraction()
	if worldState then
		local f = worldState:GetAttribute("TimeOfDayFraction")
		if typeof(f) == "number" then
			return f
		end
	end
	return 0
end

local function pickDaytimeStartFraction()
	local startF = WorldConfig.NightStartFraction
	local endF = WorldConfig.NightEndFraction
	if typeof(startF) ~= "number" then
		startF = 0.75
	end
	if typeof(endF) ~= "number" then
		endF = 0.25
	end
	if startF > endF then
		-- Night wraps midnight: day is [endF, startF) — start at midday
		return (endF + startF) / 2
	end
	-- Non-wrapping night: prefer fraction 0 if daytime, else just after night ends
	if not isNightFraction(0) then
		return 0
	end
	return endF
end

function FacilityClock.start(stateFolder)
	if running then
		return
	end
	worldState = stateFolder
	running = true

	local dayLen = WorldConfig.DayLengthSeconds
	if typeof(dayLen) ~= "number" or dayLen <= 0 then
		dayLen = 180
	end

	-- Offset so boot is daytime when night wraps across 0 (avoids night-at-boot)
	local startFraction = pickDaytimeStartFraction()
	startedAt = os.clock() - startFraction * dayLen
	publish(startFraction, isNightFraction(startFraction))

	task.spawn(function()
		while running and worldState and worldState.Parent do
			local elapsed = os.clock() - startedAt
			local fraction = (elapsed % dayLen) / dayLen
			local night = isNightFraction(fraction)
			publish(fraction, night)
			task.wait(0.5)
		end
	end)
end

function FacilityClock.stop()
	running = false
end

return FacilityClock
