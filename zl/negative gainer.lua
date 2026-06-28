--Change to desired amount. Intelligence, strength, and agility can't go over 1 but can go into the negatives. Volume settings have no restrictions and can go to whatever you want. The attributes can't exceed 1 in total.
local Event = game:GetService("ReplicatedStorage").Remotes.Events.SpeakerSetting
Event:FireServer(
    {
        IntelligenceSetting = 0,
        StrengthSetting = 0,
        AgilitySetting = 1,
        VolumeSetting = 1.5
    }
)
