local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
if not player then
    error("LocalPlayer is unavailable")
end

local sectors = Workspace
    :WaitForChild("Facility")
    :WaitForChild("Sectors")

local interactionRemotes = ReplicatedStorage
    :WaitForChild("DynamicRemotes")
    :WaitForChild("Interaction_Remotes")

local interactionFunction = interactionRemotes:WaitForChild("Interaction_RF")
local interactionEvent = interactionRemotes:WaitForChild("Interaction_RE")

if not interactionFunction:IsA("RemoteFunction") then
    error("Interaction_RF is not a RemoteFunction")
end

if not interactionEvent:IsA("RemoteEvent") then
    error("Interaction_RE is not a RemoteEvent")
end

local zca003Box = sectors
    :WaitForChild("Zeta Labs")
    :WaitForChild("Interactions")
    :WaitForChild("ZCAs")
    :WaitForChild("AudioParalyzer")
    :WaitForChild("ZCA003Box")

if not zca003Box:IsA("Model") then
    error("ZCA003Box is not a Model")
end

local TELEPORT_OFFSET = CFrame.new(0, 2.5, 2.5)
local TELEPORT_DELAY = 0.35
local INTERACTION_DELAY = 0.25
local ZCA003_LOAD_DELAY = 0.2
local INVENTORY_SYNC_TIMEOUT = 3
local CASSETTE_EQUIP_DELAY = 0.2
local CASSETTE_USE_CONFIRM_TIMEOUT = 2
local GLOBAL_TRAITOR_INITIAL_DELAY = 1.5
local GLOBAL_TRAITOR_POLL_TIMEOUT = 3
local MELEE_SCAN_TIMEOUT = 8
local MELEE_PICKUP_CONFIRM_TIMEOUT = 2
local MELEE_EQUIP_SYNC_DELAY = 0.5
local MELEE_EQUIP_DELAY = 0.35
local MELEE_EQUIP_RETRY_DELAY = 0.25
local MELEE_EQUIP_ATTEMPTS = 3
local PICKUP_CONFIRM_TIMEOUT = 2
local MAX_ATTEMPTS_PER_CASSETTE = 2
local MAX_ATTEMPTS_PER_MELEE = 2

local attempts = {}
local meleeAttempts = {}

local MELEE_NAMES = {
    Baton = true,
    Hammer = true,
    ["Metal Pipe"] = true,
    Screwdriver = true,
}

local function getRootPart()
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart")
end

local function isCassetteSpawn(instance)
    if not instance:IsA("Model") or instance.Name ~= "ItemSpawn" then
        return false
    end

    local itemName = instance:GetAttribute("Item")
    return typeof(itemName) == "string"
        and string.find(string.lower(itemName), "cassette", 1, true) ~= nil
end

local function getSpawnPart(spawn)
    return spawn.PrimaryPart or spawn:FindFirstChildWhichIsA("BasePart", true)
end

local function findCassettes(origin)
    local cassettes = {}

    for _, spawn in sectors:QueryDescendants("Model#ItemSpawn[$Item]") do
        if isCassetteSpawn(spawn)
            and (attempts[spawn] or 0) < MAX_ATTEMPTS_PER_CASSETTE
        then
            local spawnPart = getSpawnPart(spawn)
            if spawnPart then
                cassettes[#cassettes + 1] = {
                    Spawn = spawn,
                    Part = spawnPart,
                    Distance = (spawnPart.Position - origin).Magnitude,
                }
            end
        end
    end

    table.sort(cassettes, function(a, b)
        return a.Distance < b.Distance
    end)

    return cassettes
end

local ZCA003_PICKUP_CFRAME = CFrame.new(
    439.95379638672,
    -152.7919921875,
    -286.09323120117,
    0.99968105554581,
    -2.8002462570953e-09,
    -0.025253467261791,
    1.6747987441335e-09,
    1,
    -4.458720681555e-08,
    0.025253467261791,
    4.4530690246347e-08,
    0.99968105554581
)

local CASSETTE_ACTIVATION_CFRAME = CFrame.new(
    559.51416015625,
    -150.55520629883,
    -206.93057250977,
    -0.46495825052261,
    -5.4657672166059e-08,
    -0.8853325843811,
    -1.143074968013e-08,
    1,
    -5.5733689663384e-08,
    0.8853325843811,
    -1.579382313821e-08,
    -0.46495825052261
)

local GLOBAL_TRAITOR_CFRAME = CFrame.new(
    339.48007202148,
    166.73434448242,
    -57.893062591553,
    -0.39522862434387,
    1.5454221014011e-08,
    -0.91858279705048,
    3.4893861133867e-09,
    1,
    1.5322642710203e-08,
    0.91858279705048,
    2.8506568217068e-09,
    -0.39522862434387
)

print(("ZCA-003 pickup CFrame: %s"):format(tostring(ZCA003_PICKUP_CFRAME)))
print(("Cassette activation CFrame: %s"):format(tostring(CASSETTE_ACTIVATION_CFRAME)))
print(("Global Traitor destination CFrame: %s"):format(tostring(GLOBAL_TRAITOR_CFRAME)))

local function teleportTo(targetCFrame)
    local rootPart = getRootPart()
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.CFrame = targetCFrame
    task.wait(ZCA003_LOAD_DELAY)
end

local function findOwnedTool(predicate)
    local character = player.Character
    if character then
        for _, child in character:GetChildren() do
            if child:IsA("Tool") and predicate(child) then
                return child
            end
        end
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in backpack:GetChildren() do
            if child:IsA("Tool") and predicate(child) then
                return child
            end
        end
    end

    return nil
end

local function waitForOwnedTool(predicate, timeout)
    local deadline = os.clock() + (timeout or INVENTORY_SYNC_TIMEOUT)

    repeat
        local tool = findOwnedTool(predicate)
        if tool then
            return tool
        end
        task.wait(0.1)
    until os.clock() >= deadline

    return nil
end

local function isCassetteTool(tool)
    return tool:GetAttribute("SpawnTag") == "ZCACassetteTape"
        or string.match(tool.Name, "^Cassette #%d+$") ~= nil
end

local function isInInventory(tool)
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    return tool.Parent == character or tool.Parent == backpack
end

local function isMeleeTool(tool)
    return MELEE_NAMES[tool.Name] == true
end

local function isMeleeSpawn(instance)
    return instance:IsA("Model")
        and instance.Name == "ItemSpawn"
        and MELEE_NAMES[instance:GetAttribute("Item")] == true
end

local function findMeleeSpawns(origin)
    local meleeSpawns = {}

    for _, spawn in sectors:QueryDescendants("Model#ItemSpawn[$Item]") do
        if isMeleeSpawn(spawn)
            and (meleeAttempts[spawn] or 0) < MAX_ATTEMPTS_PER_MELEE
        then
            local spawnPart = getSpawnPart(spawn)
            if spawnPart then
                meleeSpawns[#meleeSpawns + 1] = {
                    Spawn = spawn,
                    Part = spawnPart,
                    Distance = (spawnPart.Position - origin).Magnitude,
                }
            end
        end
    end

    table.sort(meleeSpawns, function(a, b)
        return a.Distance < b.Distance
    end)

    return meleeSpawns
end

local function grabMelee()
    local ownedMelee = findOwnedTool(isMeleeTool)
    if ownedMelee then
        print(("Melee already owned: %s"):format(ownedMelee.Name))
        return ownedMelee
    end

    local scanDeadline = os.clock() + MELEE_SCAN_TIMEOUT

    repeat
        local rootPart = getRootPart()
        local meleeSpawns = findMeleeSpawns(rootPart.Position)

        for _, candidate in meleeSpawns do
            if os.clock() >= scanDeadline then
                break
            end

            local spawn = candidate.Spawn
            if spawn.Parent and isMeleeSpawn(spawn) then
                local spawnPart = getSpawnPart(spawn)
                if spawnPart then
                    local itemName = tostring(spawn:GetAttribute("Item"))
                    meleeAttempts[spawn] = (meleeAttempts[spawn] or 0) + 1
                    rootPart = getRootPart()
                    rootPart.AssemblyLinearVelocity = Vector3.zero
                    rootPart.AssemblyAngularVelocity = Vector3.zero
                    rootPart.CFrame = spawnPart.CFrame * TELEPORT_OFFSET
                    task.wait(TELEPORT_DELAY)

                    local ok, result = pcall(function()
                        return interactionFunction:InvokeServer(
                            "ServerInteraction",
                            spawn,
                            Enum.NormalId.Back,
                            nil,
                            nil
                        )
                    end)

                    if ok then
                        local meleeTool = waitForOwnedTool(
                            isMeleeTool,
                            MELEE_PICKUP_CONFIRM_TIMEOUT
                        )

                        if meleeTool then
                            print(("Melee picked up: %s"):format(meleeTool.Name))
                            return meleeTool
                        end

                        warn(("Melee pickup was not confirmed: %s"):format(itemName))
                    else
                        warn(("Melee pickup failed for %s: %s"):format(
                            itemName,
                            tostring(result)
                        ))
                    end

                    task.wait(INTERACTION_DELAY)
                end
            end
        end

        task.wait(0.2)
    until os.clock() >= scanDeadline

    return nil
end

local function equipMelee(meleeTool)
    task.wait(MELEE_EQUIP_SYNC_DELAY)

    for _ = 1, MELEE_EQUIP_ATTEMPTS do
        if not meleeTool.Parent then
            return false
        end

        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        local backpack = player:WaitForChild("Backpack")

        if meleeTool.Parent == character then
            return true
        end

        humanoid:UnequipTools()
        task.wait(0.1)

        if meleeTool.Parent ~= backpack then
            meleeTool.Parent = backpack
            task.wait(0.1)
        end

        humanoid:EquipTool(meleeTool)
        task.wait(MELEE_EQUIP_DELAY)

        if meleeTool.Parent == character then
            return true
        end

        meleeTool.Parent = character
        task.wait(MELEE_EQUIP_RETRY_DELAY)

        if meleeTool.Parent == character then
            return true
        end
    end

    return false
end

local function waitForGlobalTraitorAndTeleport()
    task.wait(GLOBAL_TRAITOR_INITIAL_DELAY)
    local deadline = os.clock() + GLOBAL_TRAITOR_POLL_TIMEOUT

    repeat
        local character = player.Character
        if character and CollectionService:HasTag(character, "GlobalTraitor") then
            local meleeTool = grabMelee()
            if not meleeTool then
                error("No listed melee could be acquired; final teleport canceled")
            end

            teleportTo(GLOBAL_TRAITOR_CFRAME)

            if not equipMelee(meleeTool) then
                error(("Failed to equip %s after the final teleport"):format(
                    meleeTool.Name
                ))
            end

            print(("Global Traitor detected; grabbed, teleported, and equipped %s."):format(
                meleeTool.Name
            ))
            return
        end
        task.wait(0.1)
    until os.clock() >= deadline

    warn("Global Traitor was not detected before the timeout")
end

local function equipAndUseCassette()
    local zca003Tool = waitForOwnedTool(function(tool)
        return tool.Name == "ZCA-003"
    end)

    if not zca003Tool then
        error("ZCA-003 did not appear in the inventory")
    end

    local cassetteTool = waitForOwnedTool(isCassetteTool)
    if not cassetteTool then
        error("The collected Cassette did not appear in the inventory")
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    teleportTo(CASSETTE_ACTIVATION_CFRAME)
    humanoid:EquipTool(cassetteTool)
    task.wait(CASSETTE_EQUIP_DELAY)

    if cassetteTool.Parent ~= character then
        error(("Failed to equip %s"):format(cassetteTool.Name))
    end

    local cassetteName = cassetteTool.Name
    cassetteTool:Activate()

    local deadline = os.clock() + CASSETTE_USE_CONFIRM_TIMEOUT
    repeat
        task.wait(0.1)
    until not isInInventory(cassetteTool) or os.clock() >= deadline

    if isInInventory(cassetteTool) then
        warn(("%s was activated but is still in the inventory"):format(cassetteName))
    else
        print(("%s equipped and activated; it left the inventory."):format(cassetteName))
    end

    waitForGlobalTraitorAndTeleport()
end

local function returnAndRequestZCA003()
    local rootPart = getRootPart()
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.CFrame = ZCA003_PICKUP_CFRAME
    task.wait(ZCA003_LOAD_DELAY)

    rootPart = getRootPart()
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.CFrame = ZCA003_PICKUP_CFRAME

    local ok, errorMessage = pcall(function()
        interactionEvent:FireServer(
            "ServerInteraction",
            zca003Box,
            Enum.NormalId.Left,
            nil,
            nil
        )
    end)

    if not ok then
        error(("ZCA-003 pickup request failed: %s"):format(tostring(errorMessage)))
    end

    print("Returned to the starting location and requested ZCA-003 pickup.")
    equipAndUseCassette()
end

while true do
    local rootPart = getRootPart()
    local cassettes = findCassettes(rootPart.Position)

    if #cassettes == 0 then
        break
    end

    for _, cassette in cassettes do
        local spawn = cassette.Spawn

        if spawn.Parent and isCassetteSpawn(spawn) then
            local spawnPart = getSpawnPart(spawn)

            if spawnPart then
                attempts[spawn] = (attempts[spawn] or 0) + 1
                local itemName = tostring(spawn:GetAttribute("Item"))
                rootPart = getRootPart()
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
                rootPart.CFrame = spawnPart.CFrame * TELEPORT_OFFSET
                task.wait(TELEPORT_DELAY)

                local ok, result = pcall(function()
                    return interactionFunction:InvokeServer(
                        "ServerInteraction",
                        spawn,
                        Enum.NormalId.Back,
                        nil,
                        nil
                    )
                end)

                if ok then
                    local deadline = os.clock() + PICKUP_CONFIRM_TIMEOUT
                    local cassetteInInventory = findOwnedTool(isCassetteTool) ~= nil

                    repeat
                        task.wait(0.1)
                        cassetteInInventory = findOwnedTool(isCassetteTool) ~= nil
                    until cassetteInInventory
                        or not spawn.Parent
                        or not isCassetteSpawn(spawn)
                        or os.clock() >= deadline

                    if cassetteInInventory
                        or not spawn.Parent
                        or not isCassetteSpawn(spawn)
                    then
                        print(("Cassette picked up: %s"):format(itemName))
                        returnAndRequestZCA003()
                        return
                    end

                    warn(("Cassette pickup was not confirmed: %s"):format(itemName))
                else
                    warn(("Cassette pickup failed: %s"):format(tostring(result)))
                end

                task.wait(INTERACTION_DELAY)
            end
        end
    end
end

print("Cassette scan complete; no pickup was confirmed.")
