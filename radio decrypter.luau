
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function setup()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

 
    character:SetAttribute("decrypted_channels", "facility,security,special_ops,management")

 
    local decrypted = character:GetAttribute("decrypted_channels")
    print("Decrypted channels set: " .. decrypted)
    for _, channel in ipairs(decrypted:split(",")) do
        print("  - " .. channel)
    end


    character:GetAttributeChangedSignal("decrypted_channels"):Connect(function()
        local updated = character:GetAttribute("decrypted_channels")
        print("Decrypted channels updated: " .. (updated or "nil"))
    end)
end

LocalPlayer.CharacterAdded:Connect(setup)
if LocalPlayer.Character then
    setup()
end
