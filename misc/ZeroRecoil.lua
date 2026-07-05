-- ZeroRecoil LocalScript (v3 — fixed shared table isolation)
-- Place in StarterPlayerScripts.
--
-- Problem: The executor's `shared` table is isolated from the game's
-- `shared` table, so shared.Framework and shared.CustomCamera are nil.
-- Fix: Use getrenv().shared to access the real game environment.

local PREFIX = "[ZeroRecoil]"

local function log(...)
	print(PREFIX, ...)
end

local function logwarn(...)
	warn(PREFIX, ...)
end

log("Script started.")

----------------------------------------------------------------------
-- Resolve the REAL shared table (game environment, not executor env)
----------------------------------------------------------------------
local gameShared = nil

-- Strategy 1: getrenv().shared (most executors)
pcall(function()
	if getrenv then
		local renv = getrenv()
		if renv and renv.shared then
			gameShared = renv.shared
			log("Found game shared via getrenv().shared")
		end
	end
end)

-- Strategy 2: Try the executor's own shared (maybe it's not isolated)
if not gameShared then
	if shared and shared.Framework then
		gameShared = shared
		log("Using executor shared (not isolated)")
	end
end

-- Strategy 3: getsenv on the ClientGunHandler script
if not gameShared then
	pcall(function()
		if getsenv then
			log("Trying getsenv to find ClientGunHandler...")
			for _, obj in ipairs(game:GetDescendants()) do
				if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
					local env = getsenv(obj)
					if env and env.shared then
						gameShared = env.shared
						log("Found game shared via getsenv on " .. obj:GetFullName())
						break
					end
				end
			end
		end
	end)
end

if not gameShared then
	logwarn("Could not find the game's shared table via any method.")
	logwarn("Available executor functions:")
	for _, name in ipairs({"getrenv", "getsenv", "getgenv", "getgc", "getfenv", "identifyexecutor", "getexecutorname"}) do
		local exists = false
		pcall(function() exists = getfenv()[name] ~= nil or _G[name] ~= nil end)
		log(string.format("  %s: %s", name, tostring(exists)))
	end
	-- Last resort: just wait on executor shared in case it syncs late
	log("Falling back to polling executor shared table...")
end

----------------------------------------------------------------------
-- Phase 1: Wait for Framework
----------------------------------------------------------------------
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

log("Waiting for Loaded attribute...")
local waitStart = tick()
while not LocalPlayer:GetAttribute("Loaded") do
	if tick() - waitStart > 60 then
		logwarn("Timed out waiting for Loaded attribute.")
		return
	end
	task.wait()
end
log("Loaded attribute is true.")

-- If we have gameShared, wait for Framework on it
-- If not, try to proceed without it
local resolvedShared = gameShared

if not resolvedShared then
	-- Poll both shared tables
	log("Polling for shared.Framework on any accessible shared table...")
	waitStart = tick()
	local lastReport = 0
	while true do
		local elapsed = tick() - waitStart

		-- Re-check getrenv each iteration in case executor loads late
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

		if resolvedShared then
			log("Found shared.Framework!")
			break
		end

		if elapsed - lastReport >= 5 then
			lastReport = elapsed
			log(string.format("Still searching for shared.Framework (%.0fs)...", elapsed))
		end

		if elapsed > 60 then
			logwarn("Timed out waiting for shared.Framework.")
			logwarn("Attempting to proceed without it (searching for Camera directly)...")
			break
		end

		task.wait()
	end
end

----------------------------------------------------------------------
-- Phase 2: Find the Camera table
----------------------------------------------------------------------
local Camera = nil

-- Method A: shared.CustomCamera
if resolvedShared then
	log("Waiting for CustomCamera on resolved shared table...")
	waitStart = tick()
	while true do
		if resolvedShared.CustomCamera then
			Camera = resolvedShared.CustomCamera
			log("Found Camera via shared.CustomCamera!")
			break
		end
		if tick() - waitStart > 30 then
			logwarn("Timed out waiting for shared.CustomCamera.")
			break
		end
		task.wait()
	end
end

-- Method B: getgc() scan for the Camera table
if not Camera then
	log("Trying getgc() to find Camera table...")
	pcall(function()
		if getgc then
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" then
					-- Camera table has these specific fields: Recoil, ResetRecoil, HStep, Mode, etc.
					if rawget(v, "Recoil") and rawget(v, "ResetRecoil") and rawget(v, "HStep") then
						Camera = v
						log("Found Camera table via getgc()!")
						break
					end
				end
			end
		else
			log("getgc not available.")
		end
	end)
end

-- Method C: Search script environments
if not Camera then
	log("Trying getsenv() to find Camera in script environments...")
	pcall(function()
		if getsenv then
			for _, obj in ipairs(game:GetDescendants()) do
				if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
					local env = getsenv(obj)
					if env then
						-- Check for Camera or CustomCamera in the environment
						for k, v in pairs(env) do
							if type(v) == "table" and rawget(v, "Recoil") and rawget(v, "HStep") then
								Camera = v
								log("Found Camera via getsenv(" .. obj.Name .. ") key: " .. tostring(k))
								break
							end
						end
					end
					if Camera then break end
				end
			end
		else
			log("getsenv not available.")
		end
	end)
end

if not Camera then
	logwarn("FAILED: Could not find the Camera table through any method.")
	logwarn("Zero recoil cannot be applied.")
	return
end

----------------------------------------------------------------------
-- Phase 3: Wait for Camera.Recoil
----------------------------------------------------------------------
log("Camera table found. Waiting for Camera.Recoil...")
waitStart = tick()
while not Camera.Recoil do
	if tick() - waitStart > 30 then
		logwarn("Timed out waiting for Camera.Recoil.")
		break
	end
	task.wait()
end

if not Camera.Recoil then
	logwarn("Camera.Recoil never appeared. Dumping Camera keys:")
	for k, v in pairs(Camera) do
		log(string.format("  [%s] = %s (%s)", tostring(k), tostring(v), type(v)))
	end
	return
end

log("Camera.Recoil found: " .. type(Camera.Recoil))

----------------------------------------------------------------------
-- Step A: Nuke recoil methods
----------------------------------------------------------------------
local function noop() end
local origRecoil = Camera.Recoil
local origResetRecoil = Camera.ResetRecoil

Camera.Recoil = noop
Camera.ResetRecoil = noop
log("Replaced Camera:Recoil and Camera:ResetRecoil with noop.")

----------------------------------------------------------------------
-- Step B: Try to find and zero the recoilspring
----------------------------------------------------------------------
local recoilspring = nil

local function findSpringInUpvalues(func, label)
	if not func then return nil end

	local getupvalues = nil
	pcall(function() getupvalues = debug.getupvalues or getupvalues end)
	pcall(function() getupvalues = getupvalues or getfenv().getupvalues end)

	if getupvalues then
		local ok, upvals = pcall(getupvalues, func)
		if ok and upvals then
			for k, v in pairs(upvals) do
				if type(v) == "table" or type(v) == "userdata" then
					local isSpring = pcall(function()
						return v.p and v.t and v.a and v.s and v.d
					end)
					if isSpring then
						local sVal = nil
						pcall(function() sVal = v.s end)
						if sVal and math.abs(sVal - 17.5) < 2 then
							log(string.format("  Found recoilspring in %s upvalue [%s], s=%.1f", label, tostring(k), sVal))
							return v
						end
					end
				end
			end
		end
	end

	local getupvalue = nil
	pcall(function() getupvalue = debug.getupvalue or getupvalue end)
	pcall(function() getupvalue = getupvalue or getfenv().getupvalue end)

	if getupvalue then
		for i = 1, 200 do
			local ok, result = pcall(function()
				return {debug.getupvalue(func, i)}
			end)
			if not ok then break end
			local name, val = result[1], result[2]
			if name == nil then break end
			if val and (type(val) == "table" or type(val) == "userdata") then
				local isSpring = pcall(function()
					return val.p and val.t and val.a and val.s and val.d
				end)
				if isSpring then
					local sVal = nil
					pcall(function() sVal = val.s end)
					if sVal and math.abs(sVal - 17.5) < 2 then
						log(string.format("  Found recoilspring in %s upvalue #%d (%s), s=%.1f", label, i, tostring(name), sVal))
						return val
					end
				end
			end
		end
	end

	return nil
end

-- Search in HStep and origRecoil
recoilspring = findSpringInUpvalues(Camera.HStep, "Camera.HStep")
if not recoilspring then
	recoilspring = findSpringInUpvalues(origRecoil, "origRecoil")
end

----------------------------------------------------------------------
-- Step C: Apply the fix
----------------------------------------------------------------------
if recoilspring then
	log("SUCCESS: recoilspring found! Full zero-recoil active.")
	task.spawn(function()
		local zero = Vector3.zero or Vector3.new(0, 0, 0)
		while true do
			recoilspring.t = zero
			recoilspring.a = zero
			if recoilspring.p ~= zero then
				recoilspring.p = zero
			end
			Camera.Recoil = noop
			Camera.ResetRecoil = noop
			task.wait()
		end
	end)
else
	logwarn("Could not access recoilspring. Using method-hook fallback.")
	task.spawn(function()
		while true do
			Camera.Recoil = noop
			Camera.ResetRecoil = noop
			task.wait()
		end
	end)
end

log("=== ZeroRecoil active ===")
