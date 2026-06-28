local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AssetPath = "pillar.rbxm"
local ExplosionSoundId = "5564342147"

local Connections = {}
local WatchedSounds = setmetatable({}, { __mode = "k" })
local WasPlaying = setmetatable({}, { __mode = "k" })

local RandomGen = Random.new()
local PillarSpecTemplate = nil

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

local function TaskDebris(object, lifetime)
	Debris:AddItem(object, lifetime)
end

local function getSoundIdNumber(sound)
	return tostring(sound.SoundId):match("%d+")
end

local function setupPart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function findPillarSpec(objects)
	for _, object in ipairs(objects) do
		if object.Name == "pillarspecs" and object:IsA("BasePart") then
			return object
		end

		local found = object:FindFirstChild("pillarspecs", true)
		if found and found:IsA("BasePart") then
			return found
		end
	end

	for _, object in ipairs(objects) do
		if object:IsA("BasePart") then
			return object
		end

		local part = object:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part
		end
	end

	return nil
end

if typeof(isfile) == "function" and not isfile(AssetPath) then
	warn("Missing file:", AssetPath)
	return
end

local success, objects = pcall(function()
	return game:GetObjects(getcustomasset(AssetPath))
end)

if not success or not objects or #objects == 0 then
	warn("Failed to load:", AssetPath)
	return
end

PillarSpecTemplate = findPillarSpec(objects)

if not PillarSpecTemplate then
	warn("Could not find pillarspecs inside:", AssetPath)
	return
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

local function createExplosionCylinder(position, size, growAmount, lifetime)
	local explosion = Instance.new("Part")
	explosion.Shape = Enum.PartType.Cylinder
	explosion.Size = size
	explosion.Color = Color3.fromRGB(85, 85, 255)
	explosion.Material = Enum.Material.Neon
	explosion.Transparency = 0
	setupPart(explosion)

	explosion.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	explosion.Parent = Folder

	TweenService:Create(
		explosion,
		TweenInfo.new(lifetime),
		{
			Size = size + growAmount,
			Transparency = 1
		}
	):Play()

	TaskDebris(explosion, lifetime + 0.05)
end

local function createPillarSpec(position)
	local pillarSpecs = PillarSpecTemplate:Clone()
	setupPart(pillarSpecs)

	pillarSpecs.Transparency = 0
	pillarSpecs.CFrame =
		CFrame.new(position)
		* CFrame.Angles(0, math.rad(RandomGen:NextInteger(-360, 360)), 0)

	pillarSpecs.Parent = Folder

	TweenService:Create(
		pillarSpecs,
		TweenInfo.new(0.3),
		{
			Size = Vector3.new(1030, 185, 185),
			Transparency = 1
		}
	):Play()

	TaskDebris(pillarSpecs, 0.35)
end

local function playPillarVFX(position)
	local now = os.clock()

	if LastVFXPosition and (position - LastVFXPosition).Magnitude < 8 and now - LastVFXTime < 0.5 then
		return
	end

	LastVFXTime = now
	LastVFXPosition = position

	task.spawn(function()
		cameraShake(0.2, 0.25)

		for i = 1, 35 do
			createExplosionCylinder(
				position,
				Vector3.new(1000, 155, 155),
				Vector3.new(0, 33, 33),
				1
			)

			createPillarSpec(position)

			createExplosionCylinder(
				position,
				Vector3.new(5, 200, 200),
				Vector3.new(0, 85, 85),
				1
			)

			if i % 3 == 0 then
				cameraShake(0.08, 0.15)
			end

			task.wait(0.1)
		end
	end)

	warn("Played pillar VFX")
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
	playPillarVFX(getSoundPosition(sound))
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

				playPillarVFX(descendant.Position)
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
		warn("Pillar VFX script stopped.")
	end
end))

warn("Pillar VFX loaded from:", PillarSpecTemplate:GetFullName())
warn("Throw frag grenade to trigger. Press F10 to stop.")
