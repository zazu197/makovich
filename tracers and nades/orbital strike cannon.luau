local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local ExplosionSoundId = "5564342147"

local Connections = {}
local WatchedSounds = setmetatable({}, { __mode = "k" })
local WasPlaying = setmetatable({}, { __mode = "k" })

local RandomGen = Random.new()

local LastVFXTime = 0
local LastVFXPosition = nil

local Folder = Workspace:FindFirstChild("Folder")
if not Folder then
	Folder = Instance.new("Folder")
	Folder.Name = "Folder"
	Folder.Parent = Workspace
end

local function addConnection(connection)
	table.insert(Connections, connection)
end

local function getSoundIdNumber(sound)
	return tostring(sound.SoundId):match("%d+")
end

local function taskDebris(object, lifetime)
	Debris:AddItem(object, lifetime)
end

local function getGroundPosition(position)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignore = { Folder }

	if LocalPlayer and LocalPlayer.Character then
		table.insert(ignore, LocalPlayer.Character)
	end

	rayParams.FilterDescendantsInstances = ignore

	local origin = position + Vector3.new(0, 25, 0)
	local direction = Vector3.new(0, -250, 0)

	local ray = Workspace:Raycast(origin, direction, rayParams)

	if ray then
		return ray.Position
	end

	return position
end

local function getXAndZPositions(angle, radius)
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	return x, z
end

local function createCircle(centerPart, amount, radius)
	local parts = {}
	local fullCircle = 2 * math.pi

	for i = 1, amount do
		local part = Instance.new("Part")
		part.Name = "CircleExplosionPiece"
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Size = Vector3.new(1, 1, 1)
		part.Parent = Folder

		local angle = i * (fullCircle / amount)
		local x, z = getXAndZPositions(angle, radius)

		local position = (centerPart.CFrame * CFrame.new(x, 0, z)).Position
		local lookAt = centerPart.Position

		part.CFrame =
			CFrame.lookAt(position, lookAt)
			* CFrame.fromEulerAnglesXYZ(0, -math.pi / RandomGen:NextNumber(1.85, 2), 0)

		table.insert(parts, part)
	end

	return parts
end

local function cameraShake(duration, strength)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	task.spawn(function()
		local start = os.clock()

		while os.clock() - start < duration do
			local x = RandomGen:NextNumber(-strength, strength)
			local y = RandomGen:NextNumber(-strength, strength)

			camera.CFrame = camera.CFrame * CFrame.new(x, y, 0)

			RunService.RenderStepped:Wait()
		end
	end)
end

local function createImpactFlash()
	local lighting = game:GetService("Lighting")

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CircleExplosionImpact"
	cc.Brightness = -0.6
	cc.Contrast = 6
	cc.Saturation = -0.5
	cc.TintColor = Color3.fromRGB(200, 220, 255)
	cc.Parent = lighting

	task.delay(0.04, function()
		if cc then
			cc.Brightness = 0
			cc.Contrast = 0
			cc.Saturation = 0
		end
	end)

	taskDebris(cc, 0.12)
end

local function playCircleExplosion(position)
	local now = os.clock()

	if LastVFXPosition and (position - LastVFXPosition).Magnitude < 8 and now - LastVFXTime < 0.5 then
		return
	end

	LastVFXTime = now
	LastVFXPosition = position

	local groundPosition = getGroundPosition(position)

	local middle = Instance.new("Part")
	middle.Name = "CircleExplosionMiddle"
	middle.Size = Vector3.new(1, 1, 1)
	middle.Transparency = 1
	middle.Anchored = true
	middle.CanCollide = false
	middle.CanTouch = false
	middle.CanQuery = false
	middle.Position = groundPosition
	middle.Parent = Folder

	local circle = createCircle(middle, 75, 15)

	createImpactFlash()
	cameraShake(0.18, 0.25)

	task.spawn(function()
		for _, part in ipairs(circle) do
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(85, 85, 255)
			part.Shape = Enum.PartType.Cylinder
			part.Transparency = 0
			part.Size = Vector3.zero

			part.CFrame =
				CFrame.lookAt(part.Position, middle.Position)
				* CFrame.Angles(0, 0, math.rad(90))

			TweenService:Create(
				part,
				TweenInfo.new(1, Enum.EasingStyle.Back),
				{
					Size = Vector3.new(1, 5, 5)
				}
			):Play()

			task.wait(0.01)
		end

		task.wait(0.05)

		for _, part in ipairs(circle) do
			TweenService:Create(
				part,
				TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = Vector3.new(500, 5, 5),
					Transparency = 1
				}
			):Play()

			taskDebris(part, 2.15)
		end

		taskDebris(middle, 2.2)
	end)

	warn("Played circle explosion VFX")
end

local function getSoundPosition(sound)
	local part = sound:FindFirstAncestorWhichIsA("BasePart")

	if part then
		return part.Position
	end

	if Workspace.CurrentCamera then
		return Workspace.CurrentCamera.CFrame.Position
	end

	return Vector3.new(0, 0, 0)
end

local function hideDefaultFragVFX(sound)
	local handle = sound:FindFirstAncestorWhichIsA("BasePart")
	if not handle then
		return
	end

	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("ParticleEmitter") and (child.Name == "ExplosionVFX" or child.Name == "DustVFX") then
			pcall(function()
				child.Enabled = false
				child.Rate = 0
				child.Transparency = NumberSequence.new(1)
				child:Clear()
			end)
		end
	end
end

local function isSoundPlaying(sound)
	local playing = false

	pcall(function()
		if sound.IsPlaying then
			playing = true
		end
	end)

	pcall(function()
		if sound.Playing then
			playing = true
		end
	end)

	return playing
end

local function triggerFromSound(sound)
	if getSoundIdNumber(sound) ~= ExplosionSoundId then
		return
	end

	if WasPlaying[sound] then
		return
	end

	WasPlaying[sound] = true

	hideDefaultFragVFX(sound)
	playCircleExplosion(getSoundPosition(sound))
end

local function watchSound(sound)
	if WatchedSounds[sound] then
		return
	end

	if not sound:IsA("Sound") then
		return
	end

	if getSoundIdNumber(sound) ~= ExplosionSoundId then
		return
	end

	WatchedSounds[sound] = true
	warn("Watching explosion sound:", sound:GetFullName())

	pcall(function()
		addConnection(sound.Played:Connect(function()
			triggerFromSound(sound)
		end))
	end)

	pcall(function()
		addConnection(sound:GetPropertyChangedSignal("Playing"):Connect(function()
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
			else
				WasPlaying[sound] = false
			end
		end))
	end)

	pcall(function()
		addConnection(sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
			else
				WasPlaying[sound] = false
			end
		end))
	end)
end

for _, descendant in ipairs(game:GetDescendants()) do
	if descendant:IsA("Sound") then
		watchSound(descendant)
	end
end

addConnection(game.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Sound") then
		task.defer(function()
			if descendant and descendant.Parent then
				watchSound(descendant)
			end
		end)
	elseif descendant:IsA("Explosion") then
		task.defer(function()
			if descendant and descendant.Parent then
				pcall(function()
					descendant.Visible = false
				end)

				playCircleExplosion(descendant.Position)
			end
		end)
	end
end))

addConnection(RunService.Heartbeat:Connect(function()
	for sound in pairs(WatchedSounds) do
		if sound and sound.Parent then
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
			else
				WasPlaying[sound] = false
			end
		end
	end
end))

addConnection(UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F10 then
		for _, connection in ipairs(Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(Connections)
		warn("Circle explosion VFX script stopped.")
	end
end))

warn("Circle explosion VFX loaded.")
warn("Throw frag grenade to trigger. Press F10 to stop.")
