local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage:FindFirstChild("DataRemoteEvent")

if not Event then
    return
end

local localPlayer = Players.LocalPlayer
if not localPlayer then
    return
end

local function processTarget(targetName)
    local targetPlayer = Players:FindFirstChild(targetName)
    if not targetPlayer then
        return
    end

    local character = targetPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    -- Health check before firing (optional, but ensures we only act on alive targets)
    if humanoid.Health <= 0 then
        return
    end

    local payload = {
        {
            "\x03",
            "Players." .. localPlayer.Name .. ".PlayerScripts.ClientGunHandler:6574"
        },
        {
            humanoid,
            "Melee2"
        },
        {
            "\x03",
            "Players." .. localPlayer.Name .. ".PlayerScripts.ClientGunHandler:6575"
        },
        {
            humanoid,
            "Attack",
            [6] = Vector3.new(645.88989257812, -66.000923156738, -368.04232788086)
        }
    }

    Event:FireServer(payload)

    -- Wait briefly for the remote to process, then check health again
    task.wait(0.1) -- small buffer for server response
    if humanoid.Health <= 0 then
        return true -- target eliminated
    end
    return false -- still alive (optional, for loop logic)
end

-- Main execution
local function killAll()
    local players = Players:GetPlayers()
    for _, player in ipairs(players) do
        if player ~= localPlayer then
            local success = processTarget(player.Name)
            -- Wait 1 second before next target regardless of outcome
            task.wait(1)
        end
    end
end

-- Run it
killAll()
