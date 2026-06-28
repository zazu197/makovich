local Players = game:GetService("Players")

local TARGET_ANIM_ID = "129575827606461"
local playerConnections = {}
local inCooldown = {}

-- STREAMING_CHUNK:Handling player points and animation cooldown
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

-- STREAMING_CHUNK:Setting up character events and checking animations
local function setupCharacter(player, character)
task.spawn(function()
local humanoid = character:WaitForChild("Humanoid", 10)
if not humanoid then return end

	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator then return end
	
	if playerConnections[player] then
		playerConnections[player]:Disconnect()
	end
	
	playerConnections[player] = animator.AnimationPlayed:Connect(function(animationTrack)
		local animation = animationTrack.Animation
		if animation then
			local id = string.match(animation.AnimationId, "%d+")
			
			if id == TARGET_ANIM_ID then
				awardPlayer(player, animationTrack)
			end
		end
	end)
	
	humanoid.Died:Connect(function()
		player:SetAttribute("HeartAttackScore", 0)
		inCooldown[player] = nil
	end)
end)


end

-- STREAMING_CHUNK:Managing player joining and leaving
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
inCooldown[player] = nil
end)
