-- InstaReload LocalScript
-- Place in StarterPlayerScripts (or execute via executor).
--
-- Instantly completes reloads by detecting when self.reloading becomes
-- true, then immediately setting ammo to clipsize and clearing the
-- reload state. Also skips post-shot reload delays (shotreloading).

----------------------------------------------------------------------
-- Resolve the REAL shared table
----------------------------------------------------------------------
local gameShared = nil

pcall(function()
	if getrenv then
		local renv = getrenv()
		if renv and renv.shared then
			gameShared = renv.shared
		end
	end
end)

if not gameShared then
	if shared and shared.Framework then
		gameShared = shared
	end
end

if not gameShared then
	pcall(function()
		if getsenv then
			for _, obj in ipairs(game:GetDescendants()) do
				if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
					local env = getsenv(obj)
					if env and env.shared then
						gameShared = env.shared
						break
					end
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Wait for Loaded + Framework
----------------------------------------------------------------------
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local waitStart = tick()
while not LocalPlayer:GetAttribute("Loaded") do
	if tick() - waitStart > 60 then return end
	task.wait()
end

local resolvedShared = gameShared

if not resolvedShared then
	waitStart = tick()
	while true do
		local elapsed = tick() - waitStart
		pcall(function()
			if getrenv then
				local renv = getrenv()
				if renv and renv.shared and renv.shared.Framework then
					resolvedShared = renv.shared
				end
			end
		end)
		if shared and shared.Framework then
			resolvedShared = shared
		end
		if resolvedShared then break end
		if elapsed > 60 then break end
		task.wait()
	end
end

----------------------------------------------------------------------
-- Find Combat table
----------------------------------------------------------------------
local Combat = nil

pcall(function()
	if getsenv then
		for _, obj in ipairs(game:GetDescendants()) do
			if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
				local env = getsenv(obj)
				if env then
					for k, v in pairs(env) do
						if type(v) == "table" and rawget(v, "CurrentWeapon") ~= nil then
							Combat = v
							break
						end
					end
				end
				break
			end
		end
	end
end)

if not Combat then
	pcall(function()
		if getgc then
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" then
					if rawget(v, "CurrentWeapon") ~= nil then
						Combat = v
						break
					end
				end
			end
		end
	end)
end

if not Combat then return end

----------------------------------------------------------------------
-- Stop reload animations directly on AnimationTrack objects
----------------------------------------------------------------------
local function stopReloadAnimations(weapon)
	local anims = rawget(weapon, "Animations")
	if not anims or type(anims) ~= "table" then return end

	-- Stop all reload-related animation tracks
	local reloadAnimNames = {"Reload", "TacticalReload", "ShellIn", "ShellInEnd"}
	for _, name in ipairs(reloadAnimNames) do
		pcall(function()
			local track = anims[name]
			if track and track.IsPlaying then
				track:Stop(0) -- 0 fade time = instant stop
			end
		end)
	end

	-- Disconnect any active shell reload connections to prevent
	-- the shell-by-shell chain from continuing
	pcall(function()
		local conn = rawget(weapon, "_reload_activeShellInStoppedConnection")
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end)
	pcall(function()
		local conn = rawget(weapon, "_reload_activeShellInEndStoppedConnection")
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end)
end

local function stopShotReloadAnimation(weapon)
	local anims = rawget(weapon, "Animations")
	if not anims or type(anims) ~= "table" then return end

	pcall(function()
		local track = anims["ShotReload"]
		if track and track.IsPlaying then
			track:Stop(0)
		end
	end)
end

----------------------------------------------------------------------
-- Main enforcement loop
----------------------------------------------------------------------
task.spawn(function()
	while true do
		local weapon = nil

		pcall(function()
			weapon = Combat.CurrentWeapon
		end)

		if weapon then
			local reloading = rawget(weapon, "reloading")
			local shotreloading = rawget(weapon, "shotreloading")
			local clipsize = rawget(weapon, "clipsize")

			-- Insta-reload: if the weapon is currently reloading,
			-- immediately refill ammo and clear the reload state.
			-- Order matters: set ammo first, then reloading = false,
			-- then stop animations. The Stopped handler checks
			-- self.reloading before setting ammo, so setting it false
			-- first prevents double-refill.
			if reloading == true and clipsize then
				rawset(weapon, "ammo", clipsize)
				rawset(weapon, "reloading", false)
				stopReloadAnimations(weapon)
			end

			-- Skip post-shot reload delay (pump-action, bolt-action).
			-- These weapons set shotreloading = true after each shot
			-- and block firing until the ShotReload animation finishes.
			if shotreloading == true then
				rawset(weapon, "shotreloading", false)
				stopShotReloadAnimation(weapon)
			end
		end

		task.wait()
	end
end)
