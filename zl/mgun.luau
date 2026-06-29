local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

LocalPlayer:SetAttribute("BackpackDisabled", false)

LocalPlayer:GetAttributeChangedSignal("BackpackDisabled"):Connect(function()
	if LocalPlayer:GetAttribute("BackpackDisabled") == true then
		LocalPlayer:SetAttribute("BackpackDisabled", false)
	end
end)

return function(...)
	LocalPlayer:SetAttribute("BackpackDisabled", false)

	return function()
		LocalPlayer:SetAttribute("BackpackDisabled", false)
	end
end
