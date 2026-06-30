local Event = game:GetService("ReplicatedStorage").Remotes.Events.SpeakerSetting
Event:FireServer(
    {
        IntelligenceSetting = -10,
        StrengthSetting = 0,
        AgilitySetting = 10,
        VolumeSetting = 1
    }
)

--The bug works because the server only checks whether StrengthSetting + IntelligenceSetting + AgilitySetting <= 1, 
--so a player can send a high positive stat like StrengthSetting = 8.67 and hide it with a negative stat like IntelligenceSetting = -7.67, making the total still pass.
