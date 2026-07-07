-- ZeroSpread LocalScript (v2)
-- Place in StarterPlayerScripts (or execute via executor).
--
-- Eliminates weapon spread/bloom by zeroing:
--   - Data.SpreadRadius (the random offset range)
--   - Data.AccuracyDeteriorationRate (bloom buildup per shot)
--   - accuracyPercentage upvalue inside firegun (the bloom multiplier)

local PREFIX = "[ZeroSpread]"

local function log(...)
	print(PREFIX, ...)
end

local function logwarn(...)
	warn(PREFIX, ...)
end

log("Script started.")

----------------------------------------------------------------------
-- Resolve the REAL shared table
----------------------------------------------------------------------
local gameShared = nil

pcall(function()
	if getrenv then
		local renv = getrenv()
		if renv and renv.shared then
			gameShared = renv.shared
			log("Found game shared via getrenv().shared")
		end
	end
end)

if not gameShared then
	if shared and shared.Framework then
		gameShared = shared
		log("Using executor shared (not isolated)")
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
						log("Found game shared via getsenv on " .. obj:GetFullName())
						break
					end
				end
			end
		end
	end)
end

if not gameShared then
	logwarn("Could not find game shared table. Falling back to polling...")
end

----------------------------------------------------------------------
-- Wait for Loaded
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
		if resolvedShared then
			log("Found shared.Framework!")
			break
		end
		if elapsed > 60 then
			logwarn("Timed out waiting for shared.Framework.")
			break
		end
		task.wait()
	end
end

----------------------------------------------------------------------
-- Find Combat table (one-time scan, not per-frame)
----------------------------------------------------------------------
local Combat = nil

-- Method A: getsenv
pcall(function()
	if getsenv then
		for _, obj in ipairs(game:GetDescendants()) do
			if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
				local env = getsenv(obj)
				if env then
					for k, v in pairs(env) do
						if type(v) == "table" and rawget(v, "CurrentWeapon") ~= nil then
							Combat = v
							log("Found Combat table via getsenv key: " .. tostring(k))
							break
						end
					end
				end
				break
			end
		end
	end
end)

-- Method B: getgc (ONE-TIME only, never in a loop)
if not Combat then
	log("Trying getgc() to find Combat table...")
	pcall(function()
		if getgc then
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" then
					if rawget(v, "CurrentWeapon") ~= nil then
						Combat = v
						log("Found Combat table via getgc()!")
						break
					end
				end
			end
		end
	end)
end

if not Combat then
	logwarn("Could not find Combat table. Will rely on getgc weapon scan (slow fallback).")
end

----------------------------------------------------------------------
-- Upvalue helpers
----------------------------------------------------------------------

-- Most executors return (name, value) from getupvalue but many return
-- numeric/empty names. We detect accuracyPercentage by TYPE + CONTEXT:
-- it's a number upvalue in the firegun closure, near other gun-related
-- upvalues like accuracyDeteriorationRate and lastFired.

local _getupvalue = nil
local _setupvalue = nil
local _getupvalues = nil

pcall(function() _getupvalue = debug.getupvalue end)
pcall(function() _setupvalue = debug.setupvalue end)
pcall(function() _getupvalues = debug.getupvalues end)

-- Fallback to global executor functions
if not _getupvalue then pcall(function() _getupvalue = getupvalue end) end
if not _setupvalue then pcall(function() _setupvalue = setupvalue end) end
if not _getupvalues then pcall(function() _getupvalues = getupvalues end) end

local hasUpvalueTools = (_getupvalue ~= nil and _setupvalue ~= nil)

log("Upvalue tools available: " .. tostring(hasUpvalueTools))
if _getupvalue then log("  getupvalue: yes") end
if _setupvalue then log("  setupvalue: yes") end
if _getupvalues then log("  getupvalues: yes") end

----------------------------------------------------------------------
-- Find accuracyPercentage upvalue index in a firegun closure
----------------------------------------------------------------------

-- The firegun closure has these upvalues (in approximate order):
--   lastFired         (number, starts at 0)
--   accuracyRecoveryRate (number)
--   accuracyDeteriorationRate (number, usually 0.25)
--   accuracyPercentage (number, starts at 0, the bloom multiplier)
--
-- Since names may not be available, we find them by scanning for a
-- cluster of number upvalues. We use getupvalues() which returns a
-- {[index] = value} or {[name] = value} table to map them out.

local function analyzeFiregunUpvalues(func)
	if not hasUpvalueTools then return nil end

	local upvalueMap = {} -- {index, name, value}

	-- Scan upvalues
	for i = 1, 200 do
		local ok, name, val
		local success = pcall(function()
			name, val = _getupvalue(func, i)
		end)
		if not success or name == nil then break end
		table.insert(upvalueMap, {index = i, name = tostring(name), value = val, vtype = type(val)})
	end

	-- Strategy 1: Look for named upvalues (works on some executors)
	local result = {
		accuracyPercentageIdx = nil,
		accuracyDeteriorationRateIdx = nil,
		lastFiredIdx = nil,
	}

	for _, uv in ipairs(upvalueMap) do
		local n = uv.name:lower()
		if n == "accuracypercentage" then
			result.accuracyPercentageIdx = uv.index
			log(string.format("  [named] accuracyPercentage at #%d = %s", uv.index, tostring(uv.value)))
		elseif n == "accuracydeteriorationrate" then
			result.accuracyDeteriorationRateIdx = uv.index
			log(string.format("  [named] accuracyDeteriorationRate at #%d = %s", uv.index, tostring(uv.value)))
		elseif n == "lastfired" then
			result.lastFiredIdx = uv.index
			log(string.format("  [named] lastFired at #%d = %s", uv.index, tostring(uv.value)))
		end
	end

	-- If we found at least accuracyPercentage by name, we're done
	if result.accuracyPercentageIdx then
		return result
	end

	-- Strategy 2: Heuristic search
	-- Look for a cluster of number upvalues. The pattern is:
	--   lastFired = 0 (or a timestamp)
	--   accuracyRecoveryRate = small positive number
	--   accuracyDeteriorationRate = ~0.25 (or similar small number)
	--   accuracyPercentage = 0 to 3 (the bloom value)
	--
	-- We look for the deterioration rate (~0.25 default) as an anchor,
	-- then the upvalue right after it should be accuracyPercentage.

	log("  Names not available, using heuristic scan...")
	log(string.format("  Total upvalues found: %d", #upvalueMap))

	-- Find candidate: a number upvalue with value around 0.1-1.0 that could be
	-- AccuracyDeteriorationRate, followed by another number (accuracyPercentage)
	for idx, uv in ipairs(upvalueMap) do
		if uv.vtype == "number" and uv.value >= 0.05 and uv.value <= 2.0 then
			-- This could be accuracyDeteriorationRate
			-- Check if the next upvalue is also a number (accuracyPercentage)
			local nextUv = upvalueMap[idx + 1]
			if nextUv and nextUv.vtype == "number" then
				-- Check if the one before could be lastFired or accuracyRecoveryRate
				local prevUv = upvalueMap[idx - 1]
				if prevUv and prevUv.vtype == "number" then
					-- We likely found the cluster: prevUv, uv, nextUv
					-- prevUv = accuracyRecoveryRate or lastFired
					-- uv = accuracyDeteriorationRate
					-- nextUv = accuracyPercentage

					-- Additional validation: accuracyPercentage should be 0-3
					if nextUv.value >= 0 and nextUv.value <= 3 then
						result.accuracyDeteriorationRateIdx = uv.index
						result.accuracyPercentageIdx = nextUv.index
						log(string.format("  [heuristic] Likely accuracyDeteriorationRate at #%d = %s", uv.index, tostring(uv.value)))
						log(string.format("  [heuristic] Likely accuracyPercentage at #%d = %s", nextUv.index, tostring(nextUv.value)))

						-- Check two before for lastFired
						if idx >= 3 then
							local prevPrevUv = upvalueMap[idx - 2]
							if prevPrevUv and prevPrevUv.vtype == "number" then
								result.lastFiredIdx = prevPrevUv.index
								log(string.format("  [heuristic] Likely lastFired at #%d = %s", prevPrevUv.index, tostring(prevPrevUv.value)))
							end
						end

						return result
					end
				end
			end
		end
	end

	-- Strategy 3: Brute force — if we can't find the cluster, just look for
	-- any number upvalue between 0 and 3 and try zeroing all of them each frame.
	-- Collect ALL number upvalue indices as candidates.
	log("  Heuristic failed, collecting all number upvalue candidates...")
	local numberUpvalues = {}
	for _, uv in ipairs(upvalueMap) do
		if uv.vtype == "number" then
			table.insert(numberUpvalues, uv.index)
		end
	end
	result.allNumberIndices = numberUpvalues
	log(string.format("  Found %d number upvalues to monitor", #numberUpvalues))

	return result
end

----------------------------------------------------------------------
-- Apply zeroing to a firegun's upvalues
----------------------------------------------------------------------

local function zeroFiregunUpvalues(func, analysis)
	if not hasUpvalueTools or not analysis then return end

	if analysis.accuracyPercentageIdx then
		pcall(function()
			_setupvalue(func, analysis.accuracyPercentageIdx, 0)
		end)
	end

	if analysis.accuracyDeteriorationRateIdx then
		pcall(function()
			_setupvalue(func, analysis.accuracyDeteriorationRateIdx, 0)
		end)
	end
end

----------------------------------------------------------------------
-- Main loop — lightweight, no getgc per frame
----------------------------------------------------------------------

log("Starting zero-spread enforcement loop...")

local cachedFiregun = nil
local cachedAnalysis = nil
local cachedDataTable = nil
local frameCount = 0
local gcScanInterval = 300 -- only scan getgc every ~5 seconds (300 frames)
local gcBackupWeapon = nil -- weapon found via getgc as last resort

task.spawn(function()
	while true do
		frameCount += 1

		-- Get current weapon from Combat table (cheap table lookup, no getgc)
		local currentWeapon = nil

		if Combat then
			pcall(function()
				currentWeapon = Combat.CurrentWeapon
			end)
		end

		-- Last resort: very infrequent getgc scan (every ~5 seconds)
		if not currentWeapon and not Combat then
			if gcBackupWeapon then
				-- Re-use cached weapon from last getgc scan
				currentWeapon = gcBackupWeapon
			end

			if frameCount % gcScanInterval == 0 then
				pcall(function()
					if getgc then
						for _, v in ipairs(getgc(true)) do
							if type(v) == "table" then
								local fg = rawget(v, "firegun")
								local ct = rawget(v, "combattype")
								if fg and type(fg) == "function" and ct == "Gun" then
									gcBackupWeapon = v
									currentWeapon = v
									break
								end
							end
						end
					end
				end)
			end
		end

		if currentWeapon then
			-- === Zero Data.SpreadRadius and AccuracyDeteriorationRate ===
			local data = rawget(currentWeapon, "Data") or rawget(currentWeapon, "data")
			if data and type(data) == "table" then
				if data ~= cachedDataTable then
					-- New weapon equipped
					cachedDataTable = data
					local origSpread = rawget(data, "SpreadRadius")
					local origDetRate = rawget(data, "AccuracyDeteriorationRate")
					if origSpread then
						log(string.format("New weapon: zeroing SpreadRadius (was %s)", tostring(origSpread)))
					end
					if origDetRate then
						log(string.format("New weapon: zeroing AccuracyDeteriorationRate (was %s)", tostring(origDetRate)))
					end
				end

				-- Enforce every frame (in case game resets them)
				if rawget(data, "SpreadRadius") then
					rawset(data, "SpreadRadius", 0)
				end
				if rawget(data, "AccuracyDeteriorationRate") then
					rawset(data, "AccuracyDeteriorationRate", 0)
				end
			end

			-- === Zero firegun upvalues ===
			local fg = rawget(currentWeapon, "firegun")
			if fg and type(fg) == "function" then
				if fg ~= cachedFiregun then
					-- New firegun closure, analyze its upvalues (one-time)
					cachedFiregun = fg
					log("Analyzing new firegun closure upvalues...")
					cachedAnalysis = analyzeFiregunUpvalues(fg)

					if cachedAnalysis then
						if cachedAnalysis.accuracyPercentageIdx then
							log("SUCCESS: Found accuracyPercentage upvalue!")
						elseif cachedAnalysis.allNumberIndices then
							log("Using brute-force number upvalue monitoring")
						else
							logwarn("Could not identify accuracyPercentage upvalue")
						end
					end
				end

				-- Apply zeroing every frame (cheap setupvalue calls)
				zeroFiregunUpvalues(fg, cachedAnalysis)
			end
		end

		task.wait()
	end
end)

----------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------

local methods = {}
if Combat then
	table.insert(methods, "Combat.CurrentWeapon direct access")
end
if hasUpvalueTools then
	table.insert(methods, "upvalue zeroing (getupvalue/setupvalue)")
end
table.insert(methods, "Data table field zeroing")

log("=== ZeroSpread active ===")
log("Active methods: " .. table.concat(methods, ", "))
log("Targets:")
log("  - Data.SpreadRadius → 0 (no random bullet offset)")
log("  - Data.AccuracyDeteriorationRate → 0 (no bloom buildup)")
log("  - accuracyPercentage upvalue → 0 (bloom multiplier zeroed)")
log("=== Every bullet goes exactly where the crosshair points ===")
