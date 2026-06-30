local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Settings = {
	Enabled = true,
	Color = Color3.fromRGB(255, 0, 0),
	Thickness = 0.12,
	Transparency = 0,
	FadeTime = 0.35,
	Material = Enum.Material.Neon,
	MaxDistance = 1000,
}

local TracerFolder = Workspace:FindFirstChild("TracerFolder")
if not TracerFolder then
	TracerFolder = Instance.new("Folder")
	TracerFolder.Name = "TracerFolder"
	TracerFolder.Parent = Workspace
end

local characterConnections = {}
local weaponData = {}

local function hasWeaponType(instance: Instance): boolean
	if instance:GetAttribute("WeaponType") ~= nil then
		return true
	end

	if instance:FindFirstChild("WeaponType") then
		return true
	end

	return false
end

local function hasEnabledProperty(instance: Instance): boolean
	local success, value = pcall(function()
		return instance.Enabled
	end)

	return success and typeof(value) == "boolean"
end

local function isMuzzleTrigger(instance: Instance): boolean
	if not hasEnabledProperty(instance) then
		return false
	end

	if instance.Name == "MuzzleLight" then
		return true
	end

	if instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		local parent = instance.Parent
		if parent and parent.Name == "Muzzle" then
			return true
		end
	end

	return false
end

local function getCharacter(): Model?
	return LocalPlayer.Character
end

local function getInstancePosition(instance: Instance?): Vector3?
	if not instance then
		return nil
	end

	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	local parent = instance.Parent

	if parent then
		if parent:IsA("Attachment") then
			return parent.WorldPosition
		end

		if parent:IsA("BasePart") then
			return parent.Position
		end
	end

	return nil
end

local function getMuzzlePosition(weaponRoot: Instance, sourceObject: Instance?): Vector3
	local sourcePosition = getInstancePosition(sourceObject)
	if sourcePosition then
		return sourcePosition
	end

	local muzzle = weaponRoot:FindFirstChild("Muzzle", true)
	local muzzlePosition = getInstancePosition(muzzle)

	if muzzlePosition then
		return muzzlePosition
	end

	local possibleNames = {
		"FirePoint",
		"Barrel",
		"Tip",
		"Suppressor",
		"Silencer",
		"Handle",
	}

	for _, name in ipairs(possibleNames) do
		local object = weaponRoot:FindFirstChild(name, true)
		local position = getInstancePosition(object)

		if position then
			return position
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

	return Vector3.zero
end

local function getTargetPosition(startPosition: Vector3): Vector3
	local mousePosition = Mouse.Hit.Position
	local direction = mousePosition - startPosition

	if direction.Magnitude <= 0.05 then
		return startPosition
	end

	if direction.Magnitude > Settings.MaxDistance then
		return startPosition + direction.Unit * Settings.MaxDistance
	end

	return mousePosition
end

local function playTracer(startPosition: Vector3, endPosition: Vector3)
	local direction = endPosition - startPosition
	local distance = direction.Magnitude

	if distance <= 0.05 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "TracerLine"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Settings.Material
	tracer.Color = Settings.Color
	tracer.Transparency = Settings.Transparency
	tracer.Size = Vector3.new(Settings.Thickness, Settings.Thickness, distance)
	tracer.CFrame = CFrame.lookAt(startPosition, endPosition) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = TracerFolder

	local tween = TweenService:Create(
		tracer,
		TweenInfo.new(Settings.FadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(0.01, 0.01, distance),
		}
	)

	tween:Play()
	Debris:AddItem(tracer, Settings.FadeTime + 0.1)
end

local function createTracerFromWeapon(weaponRoot: Instance, sourceObject: Instance?)
	if not Settings.Enabled then
		return
	end

	if not hasWeaponType(weaponRoot) then
		return
	end

	local character = getCharacter()
	if not character or not weaponRoot:IsDescendantOf(character) then
		return
	end

	local startPosition = getMuzzlePosition(weaponRoot, sourceObject)
	local endPosition = getTargetPosition(startPosition)

	playTracer(startPosition, endPosition)
end

local function disconnectWeapon(weaponRoot: Instance)
	local data = weaponData[weaponRoot]
	if not data then
		return
	end

	for _, connection in pairs(data.Connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	for _, connection in pairs(data.MuzzleConnections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end

	weaponData[weaponRoot] = nil
end

local function connectMuzzleTrigger(weaponRoot: Instance, muzzleObject: Instance)
	local data = weaponData[weaponRoot]
	if not data then
		return
	end

	if data.MuzzleConnections[muzzleObject] then
		return
	end

	if not isMuzzleTrigger(muzzleObject) then
		return
	end

	data.MuzzleConnections[muzzleObject] = muzzleObject:GetPropertyChangedSignal("Enabled"):Connect(function()
		if muzzleObject.Enabled then
			createTracerFromWeapon(weaponRoot, muzzleObject)
		end
	end)
end

local function scanMuzzlesForWeapon(weaponRoot: Instance)
	local data = weaponData[weaponRoot]
	if not data then
		return
	end

	for _, descendant in ipairs(weaponRoot:GetDescendants()) do
		if isMuzzleTrigger(descendant) then
			connectMuzzleTrigger(weaponRoot, descendant)
		end
	end
end

local function connectWeapon(weaponRoot: Instance)
	if weaponData[weaponRoot] then
		scanMuzzlesForWeapon(weaponRoot)
		return
	end

	if not hasWeaponType(weaponRoot) then
		return
	end

	local character = getCharacter()
	if not character or not weaponRoot:IsDescendantOf(character) then
		return
	end

	weaponData[weaponRoot] = {
		Connections = {},
		MuzzleConnections = {},
	}

	local data = weaponData[weaponRoot]

	table.insert(data.Connections, weaponRoot.DescendantAdded:Connect(function(descendant)
		if isMuzzleTrigger(descendant) then
			connectMuzzleTrigger(weaponRoot, descendant)
		end
	end))

	table.insert(data.Connections, weaponRoot.AncestryChanged:Connect(function()
		local currentCharacter = getCharacter()

		if not currentCharacter or not weaponRoot:IsDescendantOf(currentCharacter) then
			disconnectWeapon(weaponRoot)
		end
	end))

	table.insert(data.Connections, weaponRoot:GetAttributeChangedSignal("WeaponType"):Connect(function()
		if hasWeaponType(weaponRoot) then
			scanMuzzlesForWeapon(weaponRoot)
		else
			disconnectWeapon(weaponRoot)
		end
	end))

	scanMuzzlesForWeapon(weaponRoot)
end

local function scanCharacterForWeapons(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if hasWeaponType(descendant) then
			connectWeapon(descendant)
		end
	end
end

local scanQueued = false

local function queueCharacterScan(character: Model)
	if scanQueued then
		return
	end

	scanQueued = true

	task.defer(function()
		scanQueued = false

		if character.Parent then
			scanCharacterForWeapons(character)
		end
	end)
end

local function disconnectCharacter()
	for _, connection in ipairs(characterConnections) do
		connection:Disconnect()
	end

	table.clear(characterConnections)

	for weaponRoot in pairs(weaponData) do
		disconnectWeapon(weaponRoot)
	end
end

local function watchCharacter(character: Model)
	disconnectCharacter()

	scanCharacterForWeapons(character)

	table.insert(characterConnections, character.DescendantAdded:Connect(function()
		queueCharacterScan(character)
	end))
end

if LocalPlayer.Character then
	watchCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(watchCharacter)
