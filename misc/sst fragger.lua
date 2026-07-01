local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

LocalPlayer:SetAttribute("InProtectedArea", false)
LocalPlayer:GetAttributeChangedSignal("InProtectedArea"):Connect(function()
    if LocalPlayer:GetAttribute("InProtectedArea") == true then
        LocalPlayer:SetAttribute("InProtectedArea", false)
    end
end)

return function(...)
    LocalPlayer:SetAttribute("InProtectedArea", false)

    return function()
        LocalPlayer:SetAttribute("InprotectedArea", false)
    end
end