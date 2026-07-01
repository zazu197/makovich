local Workspace = game:GetService("Workspace")
local Children = Workspace:GetChildren()

local Minecolor = Color3.fromRGB(195, 0, 255) -- Set the desired color for the mines


for _, item in Children do
    if item.Name == "C_Mine" and item:IsA("MeshPart") then
        local minehighlight = Instance.new("Highlight")
        minehighlight.Adornee = item
        minehighlight.Parent = item
        minehighlight.FillColor = Minecolor
        minehighlight.OutlineColor = Minecolor
        item.Transparency = 0
    end
end

Workspace.ChildAdded:Connect(function(item)
    if item.Name == "C_Mine" and item:IsA("MeshPart") then
        task.wait(10)
        local minehighlight = Instance.new("Highlight")
        minehighlight.Adornee = item
        minehighlight.Parent = item
        item.Transparency = 0
        minehighlight.FillColor = Minecolor
        minehighlight.OutlineColor = Minecolor
    end
end)