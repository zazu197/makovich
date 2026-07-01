local GatesFolder = workspace.Facility.Sectors["Zeta Labs"].Interactions.Doors.LockdownGates
local Descendants = GatesFolder:GetDescendants()

for _, item in Descendants do
    if item:IsA("Model") and item.Name == "LockdownGate" then
        if item:GetAttribute("Active") == true then
            local gatehighlight = Instance.new("Highlight")
            gatehighlight.Adornee = item
            gatehighlight.Parent = item
        else
            local oldHighlight = item:FindFirstChildWhichIsA("Highlight")
            if oldHighlight then
                oldHighlight:Destroy()
            end
        end
        item:GetAttributeChangedSignal("Active"):Connect(function()
        if item:GetAttribute("Active") == true then
            local gatehighlight = Instance.new("Highlight")
            gatehighlight.Adornee = item
            gatehighlight.Parent = item
        else
            local oldHighlight = item:FindFirstChildWhichIsA("Highlight")
            if oldHighlight then
                oldHighlight:Destroy()
            end
        end
        end)
        
    end
end

