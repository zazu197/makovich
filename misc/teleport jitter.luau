local Players = game:GetService("Players")
local player = Players.LocalPlayer

local job = {}
shared.TeleportJob = job

local lastCharacter
local origin

while shared.TeleportJob == job do
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root and humanoid and humanoid.Health > 0 then
		if character ~= lastCharacter then
			lastCharacter = character
			origin = root.Position
		end

		local offset = Vector3.new(
			math.random(-100, 100),
			0,
			math.random(-100, 100)
		)

		root.CFrame = CFrame.new(origin + offset) * root.CFrame.Rotation
	end

	task.wait(0.1)
end
