local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AssetPath = "I_hate_you_all.rbxm"
local ExplosionSoundId = "5564342147"

local Connections = {}
local WatchedSounds = setmetatable({}, { __mode = "k" })
local WasPlaying = setmetatable({}, { __mode = "k" })

local VFXSource = nil
local LastVFXTime = 0
local LastVFXPosition = nil

local function addConnection(connection)
	table.insert(Connections, connection)
end

local function hasParticles(object)
	if object:IsA("ParticleEmitter") then
		return true
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			return true
		end
	end

	return false
end

local function findBestVFX(objects)
	for _, object in ipairs(objects) do
		if object.Name == "hitbox" and hasParticles(object) then
			return object
		end

		local hitbox = object:FindFirstChild("hitbox", true)
		if hitbox and hasParticles(hitbox) then
			return hitbox
		end
	end

	for _, object in ipairs(objects) do
		if object.Name == "explosion" and hasParticles(object) then
			return object
		end

		local explosion = object:FindFirstChild("explosion", true)
		if explosion and hasParticles(explosion) then
			return explosion
		end
	end

	local bestObject = nil
	local bestCount = 0

	for _, object in ipairs(objects) do
		local count = 0

		if object:IsA("ParticleEmitter") then
			count += 1
		end

		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				count += 1
			end
		end

		if count > bestCount then
			bestCount = count
			bestObject = object
		end
	end

	return bestObject
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

VFXSource = findBestVFX(objects)

if not VFXSource then
	warn("No usable VFX found in:", AssetPath)
	return
end

local function getSoundIdNumber(sound)
	return tostring(sound.SoundId):match("%d+")
end

local function getPositionFromSound(sound)
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

local function prepClone(root)
	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = false
		root.Transparency = 1
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = 1
		elseif descendant:IsA("Sound") then
			pcall(function()
				descendant:Stop()
			end)
		end
	end
end

local function getEmitCount(emitter)
	local emitCount = emitter:GetAttribute("EmitCount")

	if typeof(emitCount) == "number" and emitCount > 0 then
		return math.clamp(math.floor(emitCount), 1, 1000)
	end

	local lifetime = 1
	local rate = 30

	pcall(function()
		lifetime = math.max(emitter.Lifetime.Max, 0.25)
	end)

	pcall(function()
		rate = math.max(emitter.Rate, 1)
	end)

	return math.clamp(math.floor(rate * lifetime), 10, 600)
end

local function emitParticles(root)
	local cleanupTime = 4

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitter = descendant
			local lifetime = 2

			pcall(function()
				lifetime = emitter.Lifetime.Max
			end)

			cleanupTime = math.max(cleanupTime, lifetime + 3)

			local emitCount = getEmitCount(emitter)

			local emitDelay =
				emitter:GetAttribute("EmitDelay")
				or emitter:GetAttribute("Delay")
				or emitter:GetAttribute("EmitDelayTime")
				or 0

			if typeof(emitDelay) ~= "number" then
				emitDelay = 0
			end

			emitter.Enabled = false

			task.delay(emitDelay, function()
				if emitter and emitter.Parent then
					emitter:Emit(emitCount)
				end
			end)
		end
	end

	return cleanupTime
end

local function playVFX(position)
	local now = os.clock()

	if LastVFXPosition and (position - LastVFXPosition).Magnitude < 8 and now - LastVFXTime < 0.5 then
		return
	end

	LastVFXTime = now
	LastVFXPosition = position

	local anchor = Instance.new("Part")
	anchor.Name = "IHateYouAllAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = Workspace

	local clone = VFXSource:Clone()
	prepClone(clone)

	if clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(position)
		clone.Parent = Workspace
	else
		clone.Parent = anchor
	end

	local cleanupTime = emitParticles(clone)

	Debris:AddItem(anchor, cleanupTime)
	Debris:AddItem(clone, cleanupTime)

	warn("Played I_hate_you_all VFX")
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
	playVFX(getPositionFromSound(sound))
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

				playVFX(descendant.Position)
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
		warn("I_hate_you_all VFX script stopped.")
	end
end))

warn("I_hate_you_all VFX loaded from:", VFXSource:GetFullName())
