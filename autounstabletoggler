local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage.Remotes.Events.Speakers

local pcScreen = workspace:WaitForChild("Facility").Sectors["Zeta Labs"].Props.PCSetupZCA001.PCScreen
local warningScreen = pcScreen:GetChildren()[3]:WaitForChild("ZCA001WarningScreen")

local function onStateChanged()
    if warningScreen.Enabled then
        Event:FireServer("ToggleSpeaker")
    end
end

onStateChanged()

warningScreen:GetPropertyChangedSignal("Enabled"):Connect(onStateChanged)
