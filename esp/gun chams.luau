local function createEsp(target)
    if target:FindFirstChild("EspHighlight") then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "EspHighlight"
    highlight.FillColor = Color3.fromRGB(0, 255, 128)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = target
    highlight.Parent = target

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EspLabel"
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = target

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.SourceSansBold

    local displayName = "Item"
    local attributes = target:GetAttributes()
    for key, value in pairs(attributes) do
        displayName = tostring(value)
        break
    end
    
    textLabel.Text = displayName
    textLabel.Parent = billboard
    billboard.Parent = target
end

local function initializeEsp()
    local descendants = workspace:GetDescendants()
    for _, folder in pairs(descendants) do
        if folder:IsA("Folder") and folder.Name == "ItemSpawns" then
            local categories = folder:GetChildren()
            for _, category in pairs(categories) do
                local spawnsFolder = category:FindFirstChild("Spawns")
                if spawnsFolder then
                    local spawns = spawnsFolder:GetChildren()
                    for _, spawnPoint in pairs(spawns) do
                        if spawnPoint.Name == "ItemSpawn" then
                            createEsp(spawnPoint)
                        end
                    end
                end
            end
        end
    end
end

initializeEsp()
