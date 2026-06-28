local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local AssetPath = "tracers.rbxm"

local MaxDistance = 1500
local TracerSpeed = 950
local RequireEquippedTool = false

local FireGunTemplate = nil
local Connections = {}

local ScriptAlive = true
local Firing = false

local Folder = Workspace:FindFirstChild("TracerFolder")
if not Folder then
	Folder = Instance.new("Folder")
	Folder.Name = "TracerFolder"
	Folder.Parent = Workspace
end

local function addConnection(connection)
	table.insert(Connections, connection)
end

local function track(object, lifetime)
	Debris:AddItem(object, lifetime)
end

local function loadObjectsFromFile()
	if typeof(getcustomasset) == "function" then
		if typeof(isfile) == "function" and not isfile(AssetPath) then
			warn("Missing file: " .. tostring(AssetPath) .. ". Checking fallback.")
		else
			local success, objects = pcall(function()
				return game:GetObjects(getcustomasset(AssetPath))
			end)
	
			if success and objects and #objects > 0 then
				return objects
			end
		end
	end

	local fallback = ReplicatedStorage:FindFirstChild("tracers")
		or ReplicatedStorage:FindFirstChild("Tracers")
		or ReplicatedStorage:FindFirstChild("TracerVFX")

	if fallback then
		return { fallback }
	end

	return nil
end

local function loadTracers()
	local objects = loadObjectsFromFile()

	if not objects or #objects == 0 then
		warn("Could not load tracers.rbxm.")
		return false
	end

	for _, object in ipairs(objects) do
		if object.Name == "FireGun" then
			FireGunTemplate = object
			break
		end

		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant.Name == "FireGun" then
				FireGunTemplate = descendant
				break
			end
		end
		if FireGunTemplate then break end
	end

	if not FireGunTemplate then
		warn("Could not find FireGun in tracers.rbxm.")
		return false
	end

	warn("Loaded FireGun tracer successfully.")
	return true
end

local function getCharacter()
	return LocalPlayer.Character
end

local function getEquippedTool()
	local character = getCharacter()
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

local function getMuzzlePosition()
	local tool = getEquippedTool()

	if tool then
		local muzzle = tool:FindFirstChild("Muzzle", true)

		if muzzle then
			if muzzle:IsA("Attachment") then
				return muzzle.WorldPosition
			end

			if muzzle:IsA("BasePart") then
				return muzzle.Position
			end
		end

		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.Position
		end
	end

	local character = getCharacter()

	if character then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
	end

	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end

	return Vector3.new(0, 0, 0)
end

local function getAimPosition(startPosition)
	local camera = Workspace.CurrentCamera
	local targetPosition = nil

	if Mouse and Mouse.Hit then
		targetPosition = Mouse.Hit.Position
	elseif camera then
		targetPosition = camera.CFrame.Position + camera.CFrame.LookVector * MaxDistance
	end

	if not targetPosition then
		return startPosition + Vector3.new(0, 0, -MaxDistance)
	end

	local direction = targetPosition - startPosition

	if direction.Magnitude < 1 then
		if camera then
			direction = camera.CFrame.LookVector * MaxDistance
		else
			direction = Vector3.new(0, 0, -MaxDistance)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignore = { Folder }

	local character = getCharacter()
	if character then
		table.insert(ignore, character)
	end

	rayParams.FilterDescendantsInstances = ignore

	local ray = Workspace:Raycast(startPosition, direction.Unit * MaxDistance, rayParams)

	if ray then
		return ray.Position
	end

	return startPosition + direction.Unit * MaxDistance
end

local function makeAnchor(position)
	local part = Instance.new("Part")
	part.Name = "TracerAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = Folder

	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	track(part, 3)

	return part, attachment
end

local function getEmitCount(emitter)
	local emitCount = emitter:GetAttribute("EmitCount")

	if typeof(emitCount) == "number" and emitCount > 0 then
		return math.clamp(math.floor(emitCount), 1, 1000)
	end

	local lifetime = 1
	local rate = 25

	pcall(function()
		lifetime = math.max(emitter.Lifetime.Max, 0.2)
	end)

	pcall(function()
		rate = math.max(emitter.Rate, 1)
	end)

	return math.clamp(math.floor(rate * lifetime), 5, 400)
end

local function getEmitDelay(emitter)
	local delayValue =
		emitter:GetAttribute("EmitDelay")
		or emitter:GetAttribute("Delay")
		or emitter:GetAttribute("EmitDelayTime")
		or 0

	if typeof(delayValue) ~= "number" then
		return 0
	end

	return delayValue
end

local function isImpactObject(object)
	local current = object

	while current do
		local name = string.lower(current.Name)

		if name:find("impact")
			or name:find("hit")
			or name:find("ground")
			or name:find("end")
			or name:find("explode") then
			return true
		end

		current = current.Parent
	end

	return false
end

local function cloneEmitterTo(emitterTemplate, attachment)
	local emitter = emitterTemplate:Clone()
	emitter.Parent = attachment
	emitter.Enabled = false

	local emitDelay = getEmitDelay(emitter)
	local emitCount = getEmitCount(emitter)

	task.delay(emitDelay, function()
		if emitter and emitter.Parent then
			emitter:Emit(emitCount)
		end
	end)

	track(emitter, 3)
end

local function emitTemplateParticles(template, startAttachment, endAttachment, forceEnd)
	if template:IsA("ParticleEmitter") then
		if forceEnd or isImpactObject(template) then
			cloneEmitterTo(template, endAttachment)
		else
			cloneEmitterTo(template, startAttachment)
		end
	end

	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			if forceEnd or isImpactObject(descendant) then
				cloneEmitterTo(descendant, endAttachment)
			else
				cloneEmitterTo(descendant, startAttachment)
			end
		elseif descendant:IsA("PointLight") then
			local light = descendant:Clone()

			if forceEnd or isImpactObject(descendant) then
				light.Parent = endAttachment
			else
				light.Parent = startAttachment
			end

			track(light, 0.25)
		end
	end
end

local function createFallbackTracer(startPosition, endPosition, color)
	local distance = (endPosition - startPosition).Magnitude

	if distance <= 0 then
		return
	end

	local part = Instance.new("Part")
	part.Name = "FallbackTracer"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(85, 170, 255)
	part.Transparency = 0
	part.Size = Vector3.new(0.08, 0.08, distance)
	part.CFrame = CFrame.lookAt(startPosition, endPosition) * CFrame.new(0, 0, -distance / 2)
	part.Parent = Folder

	TweenService:Create(
		part,
		TweenInfo.new(0.12),
		{
			Transparency = 1
		}
	):Play()

	track(part, 0.18)
end

local function playBeamTracer(template, startPosition, endPosition, forceEnd)
	local startPart, startAttachment = makeAnchor(startPosition)
	local endPart, endAttachment = makeAnchor(endPosition)

	local madeBeam = false

	if template:IsA("Beam") then
		local beam = template:Clone()
		beam.Attachment0 = startAttachment
		beam.Attachment1 = endAttachment
		beam.Enabled = true
		beam.Parent = startAttachment
		madeBeam = true

		task.delay(0.08, function()
			if beam and beam.Parent then
				beam.Enabled = false
			end
		end)

		track(beam, 0.35)
	end

	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("Beam") then
			local beam = descendant:Clone()
			beam.Attachment0 = startAttachment
			beam.Attachment1 = endAttachment
			beam.Enabled = true
			beam.Parent = startAttachment
			madeBeam = true

			task.delay(0.08, function()
				if beam and beam.Parent then
					beam.Enabled = false
				end
			end)

			track(beam, 0.35)
		end
	end

	if not madeBeam then
		createFallbackTracer(startPosition, endPosition, Color3.fromRGB(85, 170, 255))
	end

	emitTemplateParticles(template, startAttachment, endAttachment, forceEnd)

	track(startPart, 3)
	track(endPart, 3)
end

local function playTracer(startPosition, endPosition)
	if not ScriptAlive then
		return
	end

	if typeof(startPosition) ~= "Vector3" or typeof(endPosition) ~= "Vector3" then
		return
	end

	if (startPosition - endPosition).Magnitude < 1 then
		return
	end

	if not FireGunTemplate then
		return
	end

	-- FireGun uses beam tracer with forceEnd=true
	playBeamTracer(FireGunTemplate, startPosition, endPosition, true)
end

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = {...}

	if not checkcaller() and ScriptAlive and Firing and (method == "FireServer" or method == "InvokeServer") then
		if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
			
			local function isPos(val)
				if typeof(val) == "Vector3" then return val end
				if typeof(val) == "CFrame" then return val.Position end
				if typeof(val) == "Ray" then return val.Origin + val.Direction end
				return nil
			end

			local function searchTable(t)
				for _, v in pairs(t) do
					local p = isPos(v)
					if p then return p end
					if typeof(v) == "table" then
						p = searchTable(v)
						if p then return p end
					end
				end
				return nil
			end

			task.spawn(function()
				local startPos = getMuzzlePosition()
				local targetPos = nil

				for _, arg in ipairs(args) do
					local p = isPos(arg)
					if not p and typeof(arg) == "table" then
						p = searchTable(arg)
					end
					
					if p and (p - startPos).Magnitude > 2 then
						targetPos = p
						break
					end
				end

				if targetPos then
					playTracer(startPos, targetPos)
				end
			end)
		end
	end

	return OldNamecall(self, ...)
end)

local function cleanup()
	ScriptAlive = false
	Firing = false

	for _, connection in ipairs(Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(Connections)

	if Folder and Folder.Parent then
		Folder:Destroy()
	end

	warn("Tracer script uninjected.")
end

local loaded = loadTracers()

if not loaded then
	warn("Tracer script stopped because FireGun VFX loaded failed.")
	return
end

addConnection(UIS.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F10 then
		cleanup()
		return
	end

	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Firing = true
	end
end))

addConnection(UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Firing = false
	end
end))

warn("FireGun Tracer LocalScript loaded.")
warn("Hold left click to show tracers. F10 = uninject.")
