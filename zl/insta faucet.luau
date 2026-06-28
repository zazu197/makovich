local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local event = ReplicatedStorage.Remotes.FaucetEvent
local targetPosition = Vector3.new(764.309, -152.832, -155.554)
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
                event:FireServer()
            end
        end
    end
end)
