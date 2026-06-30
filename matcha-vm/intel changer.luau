local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local function updateIntelligence()
    local character = LocalPlayer.Character
    if character then
        character:SetAttribute("IntelligenceAttribute", 99)
    end
end

RunService.Heartbeat:Connect(updateIntelligence)