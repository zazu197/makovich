local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AssetPath = "Astral Redesign.rbxm"
local ExplosionSoundId = "5564342147"

local EmittersToApply = {}
local Connections = {}
local WatchedSounds = setmetatable({}, { __mode = "k" })
local TriggeredSounds = setmetatable({}, { __mode = "k" })

local LastVFXTime = 0
local LastVFXPosition = nil

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

for _, object in ipairs(objects) do
	if object:IsA("ParticleEmitter") then
		table.insert(EmittersToApply, object)
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			table.insert(EmittersToApply, descendant)
		end
	end
end

if #EmittersToApply == 0 then
	warn("No ParticleEmitters found in:", AssetPath)
	return
end

local function addConnection(connection)
	table.insert(Connections, connection)
end

local function getSoundIdNumber(sound)
	return tostring(sound.SoundId):match("%d+")
end

local function getVFXPosition(sound)
	local part = sound:FindFirstAncestorWhichIsA("BasePart")

	if part then
		return part.Position
	end

	if Workspace.CurrentCamera then
		return Workspace.CurrentCamera.CFrame.Position
	end

	return Vector3.new(0, 0, 0)
end

local function hideFragDefaultVFX(sound)
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

local function playAstralVFX(position)
	local now = os.clock()

	if LastVFXPosition and (position - LastVFXPosition).Magnitude < 8 and now - LastVFXTime < 0.5 then
		return
	end

	LastVFXTime = now
	LastVFXPosition = position

	local anchor = Instance.new("Part")
	anchor.Name = "AstralFragExplosionVFX"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local cleanupTime = 2

	for _, effect in ipairs(EmittersToApply) do
		local cloned = effect:Clone()
		cloned.Parent = attachment
		cloned.Enabled = false

		local lifetime = cloned.Lifetime.Max
		cleanupTime = math.max(cleanupTime, lifetime)

		local emitCount = cloned:GetAttribute("EmitCount")

		if typeof(emitCount) ~= "number" then
			emitCount = math.clamp(
				math.floor(math.max(cloned.Rate, 1) * math.max(lifetime, 0.25)),
				1,
				250
			)
		end

		task.defer(function()
			if cloned and cloned.Parent then
				cloned:Emit(emitCount)
			end
		end)
	end

	Debris:AddItem(anchor, cleanupTime + 1)
end

local function triggerFromSound(sound)
	if TriggeredSounds[sound] then
		return
	end

	if getSoundIdNumber(sound) ~= ExplosionSoundId then
		return
	end

	TriggeredSounds[sound] = true

	local position = getVFXPosition(sound)

	hideFragDefaultVFX(sound)
	playAstralVFX(position)

	warn("Astral VFX played from explosion sound:", sound:GetFullName())
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

	pcall(function()
		if sound.TimePosition > 0 then
			playing = true
		end
	end)

	return playing
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
			end
		end))
	end)

	pcall(function()
		addConnection(sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
			end
		end))
	end)

	pcall(function()
		addConnection(sound:GetPropertyChangedSignal("TimePosition"):Connect(function()
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
			end
		end))
	end)

	task.defer(function()
		if sound and sound.Parent and isSoundPlaying(sound) then
			triggerFromSound(sound)
		end
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
	end
end))

addConnection(RunService.Heartbeat:Connect(function()
	for sound in pairs(WatchedSounds) do
		if sound and sound.Parent and not TriggeredSounds[sound] then
			if isSoundPlaying(sound) then
				triggerFromSound(sound)
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
		warn("Astral frag VFX stopped.")
	end
end))

warn("Astral frag VFX ready. Watching SoundId:", ExplosionSoundId, "Emitters:", #EmittersToApply)
