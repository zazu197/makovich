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

local currentMuzzleConnection: RBXScriptConnection? = nil
local currentChildConnection: RBXScriptConnection? = nil

local function getCharacter(): Model?
	return LocalPlayer.Character
end

local function getMP5(character: Model): Instance?
	return character:FindFirstChild("MP5")
end

local function getMuzzleLight(character: Model): Instance?
	local mp5 = getMP5(character)
	if not mp5 then
		return nil
	end

	local muzzle = mp5:FindFirstChild("Muzzle")
	if not muzzle then
		return nil
	end

	local muzzleLight = muzzle:FindFirstChild("MuzzleLight")
	if not muzzleLight then
		return nil
	end

	return muzzleLight
end

local function getMuzzlePosition(): Vector3
	local character = getCharacter()

	if character then
		local mp5 = character:FindFirstChild("MP5")

		if mp5 then
			local muzzle = mp5:FindFirstChild("Muzzle")

			if muzzle then
				if muzzle:IsA("Attachment") then
					return muzzle.WorldPosition
				end

				if muzzle:IsA("BasePart") then
					return muzzle.Position
				end
			end

			local handle = mp5:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				return handle.Position
			end
		end

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

local function createTracerFromMuzzle()
	if not Settings.Enabled then
		return
	end

	local startPosition = getMuzzlePosition()
	local endPosition = getTargetPosition(startPosition)

	playTracer(startPosition, endPosition)
end

local function connectMuzzleLight(character: Model)
	if currentMuzzleConnection then
		currentMuzzleConnection:Disconnect()
		currentMuzzleConnection = nil
	end

	local muzzleLight = getMuzzleLight(character)
	if not muzzleLight then
		return
	end

	if not muzzleLight:IsA("Light") then
		return
	end

	currentMuzzleConnection = muzzleLight:GetPropertyChangedSignal("Enabled"):Connect(function()
		if muzzleLight.Enabled then
			createTracerFromMuzzle()
		end
	end)
end

local function watchCharacter(character: Model)
	if currentMuzzleConnection then
		currentMuzzleConnection:Disconnect()
		currentMuzzleConnection = nil
	end

	if currentChildConnection then
		currentChildConnection:Disconnect()
		currentChildConnection = nil
	end

	task.defer(function()
		connectMuzzleLight(character)
	end)

	currentChildConnection = character.ChildAdded:Connect(function(child)
		if child.Name == "MP5" then
			task.wait()
			connectMuzzleLight(character)
		end
	end)
end

if LocalPlayer.Character then
	watchCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(watchCharacter)
