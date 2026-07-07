-- ZeroRecoilSpread LocalScript
-- Place in StarterPlayerScripts (or execute via executor).
--
-- Combines zero recoil + zero spread into a single script.
-- Eliminates:
--   Recoil: Camera:Recoil / Camera:ResetRecoil + recoilspring
--   Spread: Data.SpreadRadius, Data.AccuracyDeteriorationRate,
--           accuracyPercentage upvalue inside firegun

----------------------------------------------------------------------
-- Resolve the REAL shared table (game environment, not executor env)
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
-- Find Camera table (for recoil)
----------------------------------------------------------------------
local Camera = nil

if resolvedShared then
	waitStart = tick()
	while true do
		if resolvedShared.CustomCamera then
			Camera = resolvedShared.CustomCamera
			break
		end
		if tick() - waitStart > 30 then break end
		task.wait()
	end
end

if not Camera then
	pcall(function()
		if getgc then
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" then
					if rawget(v, "Recoil") and rawget(v, "ResetRecoil") and rawget(v, "HStep") then
						Camera = v
						break
					end
				end
			end
		end
	end)
end

if not Camera then
	pcall(function()
		if getsenv then
			for _, obj in ipairs(game:GetDescendants()) do
				if obj:IsA("LocalScript") and obj.Name:find("ClientGunHandler") then
					local env = getsenv(obj)
					if env then
						for k, v in pairs(env) do
							if type(v) == "table" and rawget(v, "Recoil") and rawget(v, "HStep") then
								Camera = v
								break
							end
						end
					end
					if Camera then break end
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Find Combat table (for spread)
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

----------------------------------------------------------------------
-- Recoil: Nuke Camera:Recoil + recoilspring
----------------------------------------------------------------------
local function noop() end
local origRecoil = nil
local recoilspring = nil

if Camera then
	waitStart = tick()
	while not Camera.Recoil do
		if tick() - waitStart > 30 then break end
		task.wait()
	end

	if Camera.Recoil then
		origRecoil = Camera.Recoil
		Camera.Recoil = noop
		Camera.ResetRecoil = noop
	end
end

-- Find recoilspring in upvalues
local function findSpringInUpvalues(func)
	if not func then return nil end

	local _getupvalues = nil
	pcall(function() _getupvalues = debug.getupvalues end)
	pcall(function() _getupvalues = _getupvalues or getfenv().getupvalues end)

	if _getupvalues then
		local ok, upvals = pcall(_getupvalues, func)
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
							return v
						end
					end
				end
			end
		end
	end

	local _getupvalue = nil
	pcall(function() _getupvalue = debug.getupvalue end)
	pcall(function() _getupvalue = _getupvalue or getfenv().getupvalue end)

	if _getupvalue then
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
						return val
					end
				end
			end
		end
	end

	return nil
end

if Camera then
	recoilspring = findSpringInUpvalues(Camera.HStep)
	if not recoilspring then
		recoilspring = findSpringInUpvalues(origRecoil)
	end
end

----------------------------------------------------------------------
-- Spread: Upvalue helpers
----------------------------------------------------------------------
local _getupvalue = nil
local _setupvalue = nil

pcall(function() _getupvalue = debug.getupvalue end)
pcall(function() _setupvalue = debug.setupvalue end)
if not _getupvalue then pcall(function() _getupvalue = getupvalue end) end
if not _setupvalue then pcall(function() _setupvalue = setupvalue end) end

local hasUpvalueTools = (_getupvalue ~= nil and _setupvalue ~= nil)

----------------------------------------------------------------------
-- Analyze firegun upvalues to find accuracyPercentage index
----------------------------------------------------------------------
local function analyzeFiregunUpvalues(func)
	if not hasUpvalueTools then return nil end

	local upvalueMap = {}

	for i = 1, 200 do
		local name, val
		local success = pcall(function()
			name, val = _getupvalue(func, i)
		end)
		if not success or name == nil then break end
		table.insert(upvalueMap, {index = i, name = tostring(name), value = val, vtype = type(val)})
	end

	local result = {
		accuracyPercentageIdx = nil,
		accuracyDeteriorationRateIdx = nil,
		lastFiredIdx = nil,
	}

	-- Strategy 1: Named upvalues
	for _, uv in ipairs(upvalueMap) do
		local n = uv.name:lower()
		if n == "accuracypercentage" then
			result.accuracyPercentageIdx = uv.index
		elseif n == "accuracydeteriorationrate" then
			result.accuracyDeteriorationRateIdx = uv.index
		elseif n == "lastfired" then
			result.lastFiredIdx = uv.index
		end
	end

	if result.accuracyPercentageIdx then
		return result
	end

	-- Strategy 2: Heuristic — find cluster of consecutive number upvalues
	-- Pattern: [lastFired/recoveryRate] [deteriorationRate ~0.05-2.0] [accuracyPercentage 0-3]
	for idx, uv in ipairs(upvalueMap) do
		if uv.vtype == "number" and uv.value >= 0.05 and uv.value <= 2.0 then
			local nextUv = upvalueMap[idx + 1]
			if nextUv and nextUv.vtype == "number" then
				local prevUv = upvalueMap[idx - 1]
				if prevUv and prevUv.vtype == "number" then
					if nextUv.value >= 0 and nextUv.value <= 3 then
						result.accuracyDeteriorationRateIdx = uv.index
						result.accuracyPercentageIdx = nextUv.index
						if idx >= 3 then
							local prevPrevUv = upvalueMap[idx - 2]
							if prevPrevUv and prevPrevUv.vtype == "number" then
								result.lastFiredIdx = prevPrevUv.index
							end
						end
						return result
					end
				end
			end
		end
	end

	-- Strategy 3: Brute force — collect all number upvalue indices
	local numberUpvalues = {}
	for _, uv in ipairs(upvalueMap) do
		if uv.vtype == "number" then
			table.insert(numberUpvalues, uv.index)
		end
	end
	result.allNumberIndices = numberUpvalues

	return result
end

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
-- Combined enforcement loop (recoil + spread, single thread)
----------------------------------------------------------------------
local cachedFiregun = nil
local cachedAnalysis = nil
local cachedDataTable = nil
local frameCount = 0
local gcScanInterval = 300
local gcBackupWeapon = nil

task.spawn(function()
	local zero = Vector3.zero or Vector3.new(0, 0, 0)

	while true do
		frameCount += 1

		-- === RECOIL: Zero recoilspring + re-hook Camera methods ===
		if Camera then
			Camera.Recoil = noop
			Camera.ResetRecoil = noop
		end

		if recoilspring then
			recoilspring.t = zero
			recoilspring.a = zero
			if recoilspring.p ~= zero then
				recoilspring.p = zero
			end
		end

		-- === SPREAD: Zero weapon data + firegun upvalues ===
		local currentWeapon = nil

		if Combat then
			pcall(function()
				currentWeapon = Combat.CurrentWeapon
			end)
		end

		if not currentWeapon and not Combat then
			if gcBackupWeapon then
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
			local data = rawget(currentWeapon, "Data") or rawget(currentWeapon, "data")
			if data and type(data) == "table" then
				if data ~= cachedDataTable then
					cachedDataTable = data
				end
				if rawget(data, "SpreadRadius") then
					rawset(data, "SpreadRadius", 0)
				end
				if rawget(data, "AccuracyDeteriorationRate") then
					rawset(data, "AccuracyDeteriorationRate", 0)
				end
			end

			local fg = rawget(currentWeapon, "firegun")
			if fg and type(fg) == "function" then
				if fg ~= cachedFiregun then
					cachedFiregun = fg
					cachedAnalysis = analyzeFiregunUpvalues(fg)
				end
				zeroFiregunUpvalues(fg, cachedAnalysis)
			end
		end

		task.wait()
	end
end)
