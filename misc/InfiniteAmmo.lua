-- InfiniteAmmo LocalScript
-- Place in StarterPlayerScripts (or execute via executor).
--
-- Keeps self.ammo pinned to self.clipsize every frame so the
-- magazine never empties and you never need to reload.

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
-- Main loop: keep ammo full every frame
----------------------------------------------------------------------
task.spawn(function()
	while true do
		local weapon = nil

		pcall(function()
			weapon = Combat.CurrentWeapon
		end)

		if weapon then
			local clipsize = rawget(weapon, "clipsize")
			local ammo = rawget(weapon, "ammo")

			if clipsize and ammo and ammo < clipsize then
				rawset(weapon, "ammo", clipsize)
			end
		end

		task.wait()
	end
end)
