-- FireRateChanger LocalScript
-- Place in StarterPlayerScripts (or execute via executor).
--
-- Modifies weapon fire rate by scaling FireDelaySeconds and burst
-- delays on Combat.CurrentWeapon. Also bypasses post-shot reload
-- lockout (shotreloading) for pump/bolt-action weapons.

----------------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------------
-- Fire rate multiplier: higher = faster fire rate.
--   2   = 2x faster (double RPM)
--   3   = 3x faster (triple RPM)
--   5   = 5x faster
--   10  = 10x faster
--   0.5 = half speed (slower)
local FIRE_RATE_MULTIPLIER = 3

-- Skip post-shot reload delay (pump-action, bolt-action cycling).
-- Set to true to remove the delay between shots on these weapons.
local SKIP_SHOT_RELOAD = true

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
-- Track original fire delay values per weapon Tool instance
----------------------------------------------------------------------
-- We store originals keyed by the Tool instance so we can correctly
-- recompute the target delay when FIRE_RATE_MULTIPLIER changes or
-- when the same weapon is re-equipped.
local originals = {} -- [Tool] = { FireDelay, BurstCooldown, BurstDelay }

local function getOriginals(weapon)
	local tool = rawget(weapon, "Tool")
	if not tool then return nil end

	if not originals[tool] then
		originals[tool] = {
			FireDelay = rawget(weapon, "FireDelaySeconds"),
			BurstCooldown = rawget(weapon, "FireBurstCooldownDelaySeconds"),
			BurstDelay = rawget(weapon, "FireBurstDelaySeconds"),
		}
	end

	return originals[tool]
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
			local orig = getOriginals(weapon)

			if orig then
				-- Scale fire delays by the multiplier
				-- FireDelaySeconds controls semi-auto, auto, and post-burst wait
				if orig.FireDelay then
					local target = orig.FireDelay / FIRE_RATE_MULTIPLIER
					local current = rawget(weapon, "FireDelaySeconds")
					if current ~= target then
						rawset(weapon, "FireDelaySeconds", target)
					end
				end

				-- FireBurstCooldownDelaySeconds controls time before next burst
				if orig.BurstCooldown then
					local target = orig.BurstCooldown / FIRE_RATE_MULTIPLIER
					local current = rawget(weapon, "FireBurstCooldownDelaySeconds")
					if current ~= target then
						rawset(weapon, "FireBurstCooldownDelaySeconds", target)
					end
				end

				-- FireBurstDelaySeconds controls delay between shots inside a burst
				if orig.BurstDelay then
					local target = orig.BurstDelay / FIRE_RATE_MULTIPLIER
					local current = rawget(weapon, "FireBurstDelaySeconds")
					if current ~= target then
						rawset(weapon, "FireBurstDelaySeconds", target)
					end
				end
			end

			-- Skip post-shot reload lockout (pump/bolt-action cycling)
			if SKIP_SHOT_RELOAD then
				if rawget(weapon, "shotreloading") == true then
					rawset(weapon, "shotreloading", false)

					-- Stop the ShotReload animation instantly
					pcall(function()
						local anims = rawget(weapon, "Animations")
						if anims then
							local track = anims["ShotReload"]
							if track and track.IsPlaying then
								track:Stop(0)
							end
						end
					end)
				end
			end
		end

		task.wait()
	end
end)
