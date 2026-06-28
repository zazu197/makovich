local target = "TargetName"
local localPlayerName = game:GetService("Players").LocalPlayer.Name

local Event = game:GetService("ReplicatedStorage").DataRemoteEvent
Event:FireServer(
    {
        {
            "\x03",
            "Players." .. localPlayerName .. ".PlayerScripts.ClientGunHandler:6574"
        },
        {
            workspace[target].Humanoid,
            "Melee2"
        },
        {
            "\x03",
            "Players." .. localPlayerName .. ".PlayerScripts.ClientGunHandler:6575"
        },
        {
            workspace[target].Humanoid,
            "Attack",
            [6] = Vector3.new(645.88989257812, -66.000923156738, -368.04232788086)
        }
    }
)
