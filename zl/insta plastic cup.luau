local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local event = ReplicatedStorage.Remotes.PlasticCupDispenser
local targetPosition = Vector3.new(698.81, -150.11, -94.68)
local activationDistance = 5
local cooldown = 5
local lastFired = 0

RunService.Heartbeat:Connect(function()
    local character = localPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        local distance = (hrp.Position - targetPosition).Magnitude
        if distance <= activationDistance then
            local currentTime = tick()
            if currentTime - lastFired >= cooldown then
                lastFired = currentTime
                event:FireServer(workspace.Facility.Sectors["Zeta Labs"].Props.PlasticCupDispenser)
            end
        end
    end
end)
