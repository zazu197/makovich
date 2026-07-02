local Localplayer = game.Players.LocalPlayer
local Character = Localplayer.Character or Localplayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Seat = workspace.Facility.Sectors["Zeta Labs"].Interactions.ZCAs.SubliminalManipulator.Control.ControlPanel.Chair.Seat

Seat:Sit(Humanoid)
