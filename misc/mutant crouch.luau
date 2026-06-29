local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local mutationAttributes = {
    "IsMutant",
    "HasReachedAdvancedMutation"
}

for index, attributeName in ipairs(mutationAttributes) do
    local currentValue = character:GetAttribute(attributeName)
    
    if currentValue ~= nil then
        character:SetAttribute(attributeName, false)
        print("Successfully hid mutant status for:", attributeName)
    end
end
