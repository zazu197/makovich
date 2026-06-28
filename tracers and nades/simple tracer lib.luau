local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer

local TracerLibrary = {
	Enabled = true,
	Color = Color3.fromRGB(255, 0, 0),
	Thickness = 0.1,
	Transparency = 0,
	FadeTime = 0.5,
	Material = Enum.Material.Neon,
	
	_hook = nil
}

local Folder = Workspace:FindFirstChild("TracerFolder")
if not Folder then
	Folder = Instance.new("Folder")
	Folder.Name = "TracerFolder"
	Folder.Parent = Workspace
end

local function track(object, lifetime)
	Debris:AddItem(object, lifetime)
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

local function playTracer(startPosition, endPosition)
	local distance = (endPosition - startPosition).Magnitude

	if distance <= 0 then return end

	local part = Instance.new("Part")
	part.Name = "TracerLine"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = TracerLibrary.Material
	part.Color = TracerLibrary.Color
	part.Transparency = TracerLibrary.Transparency
	part.Size = Vector3.new(TracerLibrary.Thickness, TracerLibrary.Thickness, distance)
	part.CFrame = CFrame.lookAt(startPosition, endPosition) * CFrame.new(0, 0, -distance / 2)
	part.Parent = Folder

	TweenService:Create(
		part,
		TweenInfo.new(TracerLibrary.FadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			Transparency = 1,
			Size = Vector3.new(0, 0, distance)
		}
	):Play()

	track(part, TracerLibrary.FadeTime + 0.1)
end

function TracerLibrary:Start()
	if self._hook then 
		self.Enabled = true
		return 
	end
	
	local OldNamecall
	OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		local args = {...}

		if not checkcaller() and TracerLibrary.Enabled and (method == "FireServer" or method == "InvokeServer") then
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
	
	self._hook = OldNamecall
	warn("Bullet Tracer Library Started.")
end

function TracerLibrary:Stop()
	self.Enabled = false
	warn("Bullet Tracer Library Stopped. (Note: hook remains but is bypassed)")
end

return TracerLibrary
