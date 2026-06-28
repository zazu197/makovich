local Players = game:GetService("Players")

local TARGET_ANIM_ID = "129575827606461"

local playerConnections = {}
local playerDiedConnections = {}
local inCooldown = {}

local function awardPlayer(player, animationTrack)
	if inCooldown[player] then return end
	inCooldown[player] = true

	local currentCount = (player:GetAttribute("HeartAttackScore") or 0) + 1
	player:SetAttribute("HeartAttackScore", currentCount)
	print(player.Name .. " - " .. tostring(currentCount) .. " HA")

	animationTrack.Stopped:Once(function()
		inCooldown[player] = nil
	end)
end

local function setupCharacter(player, character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end
		local animator = humanoid:WaitForChild("Animator", 10)
		if not animator then return end

		-- Disconnect previous HealthChanged connection
		if playerConnections[player] then
			playerConnections[player]:Disconnect()
		end

		-- Disconnect previous Died connection
		if playerDiedConnections[player] then
			playerDiedConnections[player]:Disconnect()
		end

		local previousHealth = humanoid.Health

		playerConnections[player] = humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < previousHealth then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.Animation then
						local id = string.match(track.Animation.AnimationId, "%d+")
						if id == TARGET_ANIM_ID then
							awardPlayer(player, track)
							break
						end
					end
				end
			end
			previousHealth = newHealth
		end)

		playerDiedConnections[player] = humanoid.Died:Connect(function()
			player:SetAttribute("HeartAttackScore", 0)
			inCooldown[player] = nil
		end)
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	if playerConnections[player] then
		playerConnections[player]:Disconnect()
		playerConnections[player] = nil
	end
	if playerDiedConnections[player] then
		playerDiedConnections[player]:Disconnect()
		playerDiedConnections[player] = nil
	end
	inCooldown[player] = nil
end)
