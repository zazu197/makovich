local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local AssetPaths = {
	"Fireball VFX.rbxm",
	"lightning projectile i think.rbxm"
}

local MaxDistance = 1500
local TracerSpeed = 950

local TracerList = {}
local Buttons = {}
local Connections = {}

local CurrentTracerIndex = 1
local ScriptAlive = true
local Firing = false
local StatusLabel = nil

local Folder = Workspace:FindFirstChild("CustomTracerFolder")
if not Folder then
	Folder = Instance.new("Folder")
	Folder.Name = "CustomTracerFolder"
	Folder.Parent = Workspace
end

local function addConnection(connection)
	table.insert(Connections, connection)
end

local function track(object, lifetime)
	Debris:AddItem(object, lifetime)
end

local function hasTracerObjects(root)
	local function isTracerComponent(instance)
		return instance:IsA("Beam") or instance:IsA("Trail") or instance:IsA("ParticleEmitter")
			or instance:IsA("BasePart") or instance:IsA("Attachment")
	end

	if isTracerComponent(root) then return true end
	for _, descendant in ipairs(root:GetDescendants()) do
		if isTracerComponent(descendant) then
			return true
		end
	end
	return false
end

local function addTracerTemplate(name, template)
	if not template or not hasTracerObjects(template) then return end
	for _, data in ipairs(TracerList) do
		if data.Template == template then return end
	end
	table.insert(TracerList, {
		Name = name or template.Name or ("Tracer " .. tostring(#TracerList + 1)),
		Template = template
	})
end

local function loadTracers()
	local totalLoaded = 0
	
	if typeof(getcustomasset) ~= "function" then
		warn("Exploit does not support getcustomasset.")
		return false
	end
	
	for _, path in ipairs(AssetPaths) do
		if typeof(isfile) == "function" and not isfile(path) then
			warn("Missing file: " .. tostring(path))
			continue
		end
		
		local success, objects = pcall(function()
			return game:GetObjects(getcustomasset(path))
		end)
		
		if success and objects and #objects > 0 then
			for _, root in ipairs(objects) do
				local toDelete = {}
				for _, descendant in ipairs(root:GetDescendants()) do
					local n = string.lower(descendant.Name)
					if n == "bottom" or n == "top" or n == "trails" or n == "trail" then
						table.insert(toDelete, descendant)
					end
				end
				for _, obj in ipairs(toDelete) do
					pcall(function() obj:Destroy() end)
				end

				if hasTracerObjects(root) then
					local modeName = root.Name
					local lowerPath = string.lower(path)
					
					if lowerPath:find("fireball") then
						modeName = "Fireball Tracer"
					elseif lowerPath:find("lightning") then
						modeName = "Lightning Tracer"
					end
					
					addTracerTemplate(modeName, root)
					totalLoaded = totalLoaded + 1
				end
			end
		end
	end
	
	if totalLoaded == 0 then
		warn("No custom tracer VFX loaded from the provided rbxm files.")
		return false
	end
	
	for index, data in ipairs(TracerList) do
		warn("Loaded tracer:", index, data.Name)
	end
	return true
end

local function getCharacter()
	return LocalPlayer.Character
end

local function getMuzzlePosition()
	local character = getCharacter()
	if not character then return Vector3.new(0, 0, 0) end

	local tool = nil
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			tool = child
			break
		end
	end

	if tool then
		local muzzle = tool:FindFirstChild("Muzzle", true)
		if muzzle then
			if muzzle:IsA("Attachment") then return muzzle.WorldPosition end
			if muzzle:IsA("BasePart") then return muzzle.Position end
		end

		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then return handle.Position end
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end

	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end

	return Vector3.new(0, 0, 0)
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

local function setupBasePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function hasClass(root, className)
	if root:IsA(className) then return true end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA(className) then return true end
	end
	return false
end

local function getEmitCount(emitter)
	local emitCount = emitter:GetAttribute("EmitCount")
	if typeof(emitCount) == "number" and emitCount > 0 then
		return math.clamp(math.floor(emitCount), 1, 1000)
	end
	local lifetime = 1
	local rate = 25
	pcall(function() lifetime = math.max(emitter.Lifetime.Max, 0.2) end)
	pcall(function() rate = math.max(emitter.Rate, 1) end)
	return math.clamp(math.floor(rate * lifetime), 5, 400)
end

local function getEmitDelay(emitter)
	local delayValue = emitter:GetAttribute("EmitDelay") or emitter:GetAttribute("Delay") or emitter:GetAttribute("EmitDelayTime") or 0
	if typeof(delayValue) ~= "number" then return 0 end
	return delayValue
end

local function isImpactObject(object)
	local current = object
	while current do
		local name = string.lower(current.Name)
		if name:find("impact") or name:find("hit") or name:find("ground") or name:find("end") or name:find("explode") then
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

local function emitImpactOnly(template, position)
	local _, attachment = makeAnchor(position)
	if template:IsA("ParticleEmitter") and isImpactObject(template) then
		cloneEmitterTo(template, attachment)
	end
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") and isImpactObject(descendant) then
			cloneEmitterTo(descendant, attachment)
		elseif descendant:IsA("PointLight") and isImpactObject(descendant) then
			local light = descendant:Clone()
			light.Parent = attachment
			track(light, 0.25)
		end
	end
end

local function emitTemplateParticles(template, startAttachment, endAttachment)
	if template:IsA("ParticleEmitter") then
		if isImpactObject(template) then
			cloneEmitterTo(template, endAttachment)
		else
			cloneEmitterTo(template, startAttachment)
		end
	end
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			if isImpactObject(descendant) then
				cloneEmitterTo(descendant, endAttachment)
			else
				cloneEmitterTo(descendant, startAttachment)
			end
		elseif descendant:IsA("PointLight") then
			local light = descendant:Clone()
			if isImpactObject(descendant) then
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
	if distance <= 0 then return end
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
	TweenService:Create(part, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	track(part, 0.18)
end

local function playBeamTracer(template, startPosition, endPosition)
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
			if beam and beam.Parent then beam.Enabled = false end
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
				if beam and beam.Parent then beam.Enabled = false end
			end)
			track(beam, 0.35)
		end
	end
	if not madeBeam then
		createFallbackTracer(startPosition, endPosition, Color3.fromRGB(85, 170, 255))
	end
	emitTemplateParticles(template, startAttachment, endAttachment)
	track(startPart, 3)
	track(endPart, 3)
end

local function prepClone(root)
	if root:IsA("BasePart") then setupBasePart(root) end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setupBasePart(descendant)
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = not isImpactObject(descendant)
		elseif descendant:IsA("Sound") then
			pcall(function() descendant:Stop() end)
		end
	end
end

local function setRootCFrame(root, cframe)
	if root:IsA("Model") then
		root:PivotTo(cframe)
	elseif root:IsA("BasePart") then
		root.CFrame = cframe
	else
		local part = root:FindFirstChildWhichIsA("BasePart", true)
		if part then part.CFrame = cframe end
	end
end

local function moveRootOverTime(root, startPosition, endPosition, travelTime)
	local direction = endPosition - startPosition
	if direction.Magnitude <= 0 then return end
	local startClock = os.clock()
	local startCFrame = CFrame.lookAt(startPosition, endPosition)
	local endCFrame = CFrame.lookAt(endPosition, endPosition + direction.Unit)
	setRootCFrame(root, startCFrame)
	
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not root or not root.Parent then
			if connection then connection:Disconnect() end
			return
		end
		local alpha = math.clamp((os.clock() - startClock) / travelTime, 0, 1)
		local cf = startCFrame:Lerp(endCFrame, alpha)
		setRootCFrame(root, cf)
		if alpha >= 1 then
			if connection then connection:Disconnect() end
		end
	end)
end

local function playProjectileTracer(template, startPosition, endPosition)
	local direction = endPosition - startPosition
	local distance = direction.Magnitude
	if distance <= 0 then return end
	local travelTime = math.clamp(distance / TracerSpeed, 0.035, 0.3)
	
	local clone = template:Clone()
	clone.Parent = Folder
	prepClone(clone)
	
	local hasVisualPart = clone:IsA("BasePart") or clone:IsA("Model") or clone:FindFirstChildWhichIsA("BasePart", true) ~= nil
	if hasVisualPart then
		moveRootOverTime(clone, startPosition, endPosition, travelTime)
	else
		local projectile = Instance.new("Part")
		projectile.Name = "TracerProjectile"
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Transparency = 1
		projectile.Size = Vector3.new(0.2, 0.2, 0.2)
		projectile.CFrame = CFrame.lookAt(startPosition, endPosition)
		projectile.Parent = Folder
		local attachment = Instance.new("Attachment")
		attachment.Parent = projectile
		clone.Parent = projectile
		moveRootOverTime(projectile, startPosition, endPosition, travelTime)
		track(projectile, 3)
	end
	
	task.delay(travelTime, function()
		if clone and clone.Parent then
			for _, descendant in ipairs(clone:GetDescendants()) do
				if descendant:IsA("Trail") then descendant.Enabled = false
				elseif descendant:IsA("Beam") then descendant.Enabled = false
				elseif descendant:IsA("ParticleEmitter") then descendant.Enabled = false
				elseif descendant:IsA("BasePart") then descendant.Transparency = 1 end
			end
			if clone:IsA("BasePart") then clone.Transparency = 1 end
		end
		emitImpactOnly(template, endPosition)
	end)
	track(clone, 3)
end

local function getCurrentTracer()
	local data = TracerList[CurrentTracerIndex]
	if not data then return nil end
	return data.Template
end

local function getCurrentTracerName()
	local data = TracerList[CurrentTracerIndex]
	if not data then return "None" end
	return data.Name
end

local function playTracer(startPosition, endPosition)
	if not ScriptAlive then return end
	if typeof(startPosition) ~= "Vector3" or typeof(endPosition) ~= "Vector3" then return end
	if (startPosition - endPosition).Magnitude < 1 then return end
	
	local template = getCurrentTracer()
	if not template then return end
	
	if hasClass(template, "Trail") or hasClass(template, "BasePart") or template:IsA("BasePart") or template:IsA("Model") then
		playProjectileTracer(template, startPosition, endPosition)
	else
		playBeamTracer(template, startPosition, endPosition)
	end
end

local function refreshButtons()
	for index, button in pairs(Buttons) do
		local data = TracerList[index]
		if data then
			if index == CurrentTracerIndex then
				button.BackgroundColor3 = Color3.fromRGB(75, 110, 180)
				button.Text = "✓ " .. data.Name
			else
				button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				button.Text = data.Name
			end
		end
	end
	if StatusLabel then
		StatusLabel.Text = "Selected: " .. getCurrentTracerName()
	end
end

local function createUI()
	local old = PlayerGui:FindFirstChild("CustomTracerModsUI")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CustomTracerModsUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui

	local height = 76 + (#TracerList * 34) + 24
	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.Size = UDim2.new(0, 260, 0, height)
	frame.Position = UDim2.new(0, 30, 0, 220)
	frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 260, 0, 30)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	title.BorderSizePixel = 0
	title.Text = "Custom VFX Tracers"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 2
	title.Parent = frame

	StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "Status"
	StatusLabel.Size = UDim2.new(0, 240, 0, 22)
	StatusLabel.Position = UDim2.new(0, 10, 0, 36)
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.Text = "Selected: " .. getCurrentTracerName()
	StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	StatusLabel.TextSize = 12
	StatusLabel.Font = Enum.Font.Gotham
	StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	StatusLabel.ZIndex = 2
	StatusLabel.Parent = frame

	for index, data in ipairs(TracerList) do
		local button = Instance.new("TextButton")
		button.Name = "TracerButton" .. tostring(index)
		button.Size = UDim2.new(0, 240, 0, 28)
		button.Position = UDim2.new(0, 10, 0, 64 + ((index - 1) * 34))
		button.BorderSizePixel = 0
		button.Text = data.Name
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 14
		button.Font = Enum.Font.Gotham
		button.AutoButtonColor = true
		button.Active = true
		button.Selectable = true
		button.ZIndex = 3
		button.Parent = frame
		Buttons[index] = button
		addConnection(button.Activated:Connect(function()
			CurrentTracerIndex = index
			refreshButtons()
			warn("Selected tracer:", getCurrentTracerName())
		end))
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.Size = UDim2.new(0, 260, 0, 20)
	footer.Position = UDim2.new(0, 0, 1, -22)
	footer.BackgroundTransparency = 1
	footer.Text = "F10 = uninject"
	footer.TextColor3 = Color3.fromRGB(170, 170, 170)
	footer.TextSize = 12
	footer.Font = Enum.Font.Gotham
	footer.ZIndex = 2
	footer.Parent = frame

	local dragging = false
	local dragStart = nil
	local startPos = nil

	addConnection(title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end))

	addConnection(title.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	addConnection(UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))

	refreshButtons()
end

local function cleanup()
	ScriptAlive = false
	Firing = false
	for _, connection in ipairs(Connections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(Connections)
	local gui = PlayerGui:FindFirstChild("CustomTracerModsUI")
	if gui then gui:Destroy() end
	if Folder and Folder.Parent then Folder:Destroy() end
	warn("Custom Tracer script uninjected.")
end

local loaded = loadTracers()
if not loaded then
	warn("Script stopped because no VFX loaded.")
	return
end

createUI()

addConnection(UIS.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F10 then
		cleanup()
		return
	end
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Firing = true
	end
end))

addConnection(UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Firing = false
	end
end))

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

warn("Custom VFX Tracer Loaded. Select VFX via UI and shoot.")
