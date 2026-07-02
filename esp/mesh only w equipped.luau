--// Pure Roblox LocalScript
--// Applies x-ray / wireframe effect to the Tool you are currently holding.
--// Standard Roblox APIs only. No executor-specific APIs. No remotes. No hooks.
--// F10 fully restores and shuts down the effect.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	-- "Green" = closer to your second image.
	-- "Cyan" = closer to your first image.
	ColorMode = "Green",

	Green = Color3.fromRGB(0, 255, 45),
	Cyan = Color3.fromRGB(0, 255, 230),

	BodyTransparency = 0.55,
	WireTransparency = 0.02,
	WireThickness = 1,

	HighlightFillTransparency = 0.72,
	HighlightOutlineTransparency = 0.04,

	AlwaysOnTop = true,

	UseTrueMeshWireframe = true,

	-- Set this to false if it starts affecting arms/viewmodel models under CurrentCamera.
	IncludeCameraViewmodels = true,

	-- Scans for newly created weapon parts/viewmodels.
	ScanInterval = 0.35,

	-- math.huge = true 1:1 where possible.
	-- Lower this if FPS dies, because Roblox will not mourn your GPU.
	MaxEdgesPerPart = math.huge,

	UseBloom = true,
	BloomIntensity = 1.4,
	BloomSize = 24,
	BloomThreshold = 0.8,
}

local State = {
	enabled = true,

	currentTool = nil,
	generation = 0,

	folder = nil,
	bloom = nil,

	adornments = {},
	highlights = {},
	changed = {},

	processedParts = {},
	processedContainers = {},

	connections = {},

	lastScan = 0,
}

local function effectColor()
	if CONFIG.ColorMode == "Cyan" then
		return CONFIG.Cyan
	end

	return CONFIG.Green
end

local function addConnection(conn)
	table.insert(State.connections, conn)
	return conn
end

local function safeDestroy(obj)
	if obj then
		pcall(function()
			obj:Destroy()
		end)
	end
end

local function getAdornmentFolder()
	if State.folder and State.folder.Parent then
		return State.folder
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")

	local folder = Instance.new("Folder")
	folder.Name = "Local_XRay_Wireframe_Effect"
	folder.Parent = playerGui

	State.folder = folder
	return folder
end

local function rememberProperty(obj, prop)
	if not obj then
		return
	end

	State.changed[obj] = State.changed[obj] or {}

	if State.changed[obj][prop] ~= nil then
		return
	end

	local ok, value = pcall(function()
		return obj[prop]
	end)

	if ok then
		State.changed[obj][prop] = value
	end
end

local function setProperty(obj, prop, value)
	if not obj then
		return
	end

	rememberProperty(obj, prop)

	pcall(function()
		obj[prop] = value
	end)
end

local function restoreProperties()
	for obj, props in pairs(State.changed) do
		if obj and obj.Parent then
			for prop, value in pairs(props) do
				pcall(function()
					obj[prop] = value
				end)
			end
		end
	end

	table.clear(State.changed)
end

local function ensureBloom()
	if not CONFIG.UseBloom then
		return
	end

	if State.bloom and State.bloom.Parent then
		return
	end

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Local_XRay_Bloom"
	bloom.Intensity = CONFIG.BloomIntensity
	bloom.Size = CONFIG.BloomSize
	bloom.Threshold = CONFIG.BloomThreshold
	bloom.Parent = Lighting

	State.bloom = bloom
end

local function getEquippedTool()
	local character = player.Character

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

local function hasBasePart(container)
	return container and container:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function isLikelyCameraViewmodel(obj, tool)
	if not CONFIG.IncludeCameraViewmodels then
		return false
	end

	if not obj:IsA("Model") and not obj:IsA("Folder") then
		return false
	end

	if not hasBasePart(obj) then
		return false
	end

	local name = string.lower(obj.Name)
	local toolName = tool and string.lower(tool.Name) or ""

	if toolName ~= "" and string.find(name, toolName, 1, true) then
		return true
	end

	if string.find(name, "viewmodel", 1, true) then
		return true
	end

	if string.find(name, "view", 1, true) then
		return true
	end

	if string.find(name, "weapon", 1, true) then
		return true
	end

	if string.find(name, "gun", 1, true) then
		return true
	end

	return false
end

local function getVisualTargets(tool)
	local targets = {}

	if tool and hasBasePart(tool) then
		table.insert(targets, tool)
	end

	camera = workspace.CurrentCamera or camera

	if CONFIG.IncludeCameraViewmodels and camera then
		for _, child in ipairs(camera:GetChildren()) do
			if isLikelyCameraViewmodel(child, tool) then
				table.insert(targets, child)
			end
		end
	end

	return targets
end

local function makeHighlight(container)
	if State.processedContainers[container] then
		return
	end

	State.processedContainers[container] = true

	local highlight = Instance.new("Highlight")
	highlight.Name = "Local_XRay_Highlight"
	highlight.Adornee = container
	highlight.FillColor = effectColor()
	highlight.OutlineColor = Color3.fromRGB(220, 255, 235)
	highlight.FillTransparency = CONFIG.HighlightFillTransparency
	highlight.OutlineTransparency = CONFIG.HighlightOutlineTransparency
	highlight.DepthMode = CONFIG.AlwaysOnTop
		and Enum.HighlightDepthMode.AlwaysOnTop
		or Enum.HighlightDepthMode.Occluded

	highlight.Parent = container

	table.insert(State.highlights, highlight)
end

local function stylePart(part)
	setProperty(part, "Color", effectColor())
	setProperty(part, "Transparency", CONFIG.BodyTransparency)
	setProperty(part, "Material", Enum.Material.ForceField)
	setProperty(part, "CastShadow", false)

	pcall(function()
		setProperty(part, "Reflectance", 0)
	end)

	if part:IsA("MeshPart") then
		pcall(function()
			setProperty(part, "DoubleSided", true)
		end)

		pcall(function()
			setProperty(part, "TextureID", "")
		end)

		pcall(function()
			if Content and Content.none then
				setProperty(part, "TextureContent", Content.none)
			end
		end)
	end
end

local function styleExtraVisual(obj)
	if obj:IsA("Decal") or obj:IsA("Texture") then
		setProperty(obj, "Transparency", 1)
	elseif obj:IsA("SurfaceAppearance") then
		setProperty(obj, "Enabled", false)
	end
end

local function makeWire(part)
	local wire = Instance.new("WireframeHandleAdornment")
	wire.Name = "Local_XRay_Wire_" .. part.Name
	wire.Adornee = part
	wire.Color3 = effectColor()
	wire.Transparency = CONFIG.WireTransparency
	wire.AlwaysOnTop = CONFIG.AlwaysOnTop
	wire.ZIndex = 10

	pcall(function()
		wire.Thickness = CONFIG.WireThickness
	end)

	wire.Parent = getAdornmentFolder()

	table.insert(State.adornments, wire)

	return wire
end

local function addBoxWireframe(part)
	if not State.enabled or not part or not part.Parent then
		return
	end

	local wire = makeWire(part)

	local sx = part.Size.X / 2
	local sy = part.Size.Y / 2
	local sz = part.Size.Z / 2

	local c = {
		Vector3.new(-sx, -sy, -sz),
		Vector3.new( sx, -sy, -sz),
		Vector3.new( sx,  sy, -sz),
		Vector3.new(-sx,  sy, -sz),

		Vector3.new(-sx, -sy,  sz),
		Vector3.new( sx, -sy,  sz),
		Vector3.new( sx,  sy,  sz),
		Vector3.new(-sx,  sy,  sz),
	}

	local edges = {
		{1, 2}, {2, 3}, {3, 4}, {4, 1},
		{5, 6}, {6, 7}, {7, 8}, {8, 5},
		{1, 5}, {2, 6}, {3, 7}, {4, 8},
	}

	for _, edge in ipairs(edges) do
		wire:AddLine(c[edge[1]], c[edge[2]])
	end

	-- Extra internal diagonal lines to mimic x-ray geometry.
	local slices = 6

	for i = 1, slices do
		local t = i / (slices + 1)
		local z = -sz + ((sz * 2) * t)

		wire:AddLine(Vector3.new(-sx, -sy, z), Vector3.new( sx,  sy, z))
		wire:AddLine(Vector3.new(-sx,  sy, z), Vector3.new( sx, -sy, z))
	end
end

local function getMeshContent(meshPart)
	local okContent, meshContent = pcall(function()
		return meshPart.MeshContent
	end)

	if okContent and meshContent and tostring(meshContent) ~= "" then
		return meshContent
	end

	local okMeshId, meshId = pcall(function()
		return meshPart.MeshId
	end)

	if okMeshId and meshId and meshId ~= "" then
		local okUri, content = pcall(function()
			return Content.fromUri(meshId)
		end)

		if okUri and content then
			return content
		end
	end

	return nil
end

local function convertVertexToPartSpace(vertex, center, meshSize, partSize)
	local xScale = meshSize.X ~= 0 and partSize.X / meshSize.X or 1
	local yScale = meshSize.Y ~= 0 and partSize.Y / meshSize.Y or 1
	local zScale = meshSize.Z ~= 0 and partSize.Z / meshSize.Z or 1

	local p = vertex - center

	return Vector3.new(
		p.X * xScale,
		p.Y * yScale,
		p.Z * zScale
	)
end

local function buildTrueMeshWireframe(meshPart, generation)
	if not State.enabled then
		return
	end

	if generation ~= State.generation then
		return
	end

	if not meshPart or not meshPart.Parent then
		return
	end

	local content = getMeshContent(meshPart)

	if not content then
		addBoxWireframe(meshPart)
		return
	end

	local editableMesh

	local ok, err = pcall(function()
		editableMesh = AssetService:CreateEditableMeshAsync(content, {
			FixedSize = true,
		})
	end)

	if not ok or not editableMesh then
		warn("[XRay] Could not read mesh triangles for:", meshPart:GetFullName(), err)
		addBoxWireframe(meshPart)
		return
	end

	if not State.enabled or generation ~= State.generation then
		pcall(function()
			editableMesh:Destroy()
		end)
		return
	end

	local wire = makeWire(meshPart)

	local okBuild, buildErr = pcall(function()
		local faces = editableMesh:GetFaces()
		local center = editableMesh:GetCenter()
		local meshSize = editableMesh:GetSize()

		local seenEdges = {}
		local edgeCount = 0
		local yieldCounter = 0

		for _, faceId in ipairs(faces) do
			if not State.enabled or generation ~= State.generation then
				break
			end

			local vertexIds = editableMesh:GetFaceVertices(faceId)
			local count = #vertexIds

			if count >= 2 then
				for i = 1, count do
					local a = vertexIds[i]
					local b = vertexIds[(i % count) + 1]

					local lo = math.min(a, b)
					local hi = math.max(a, b)
					local key = tostring(lo) .. ":" .. tostring(hi)

					if not seenEdges[key] then
						seenEdges[key] = true

						local pa = editableMesh:GetPosition(a)
						local pb = editableMesh:GetPosition(b)

						pa = convertVertexToPartSpace(pa, center, meshSize, meshPart.Size)
						pb = convertVertexToPartSpace(pb, center, meshSize, meshPart.Size)

						wire:AddLine(pa, pb)

						edgeCount += 1
						yieldCounter += 1

						if yieldCounter >= 500 then
							yieldCounter = 0
							task.wait()
						end

						if edgeCount >= CONFIG.MaxEdgesPerPart then
							break
						end
					end
				end
			end

			if edgeCount >= CONFIG.MaxEdgesPerPart then
				break
			end
		end

		if edgeCount == 0 then
			safeDestroy(wire)
			addBoxWireframe(meshPart)
		end
	end)

	if not okBuild then
		warn("[XRay] Mesh wire build failed:", buildErr)
		safeDestroy(wire)
		addBoxWireframe(meshPart)
	end

	pcall(function()
		editableMesh:Destroy()
	end)
end

local function applyToContainer(container)
	if not State.enabled or not container or not container.Parent then
		return
	end

	makeHighlight(container)

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			if not State.processedParts[obj] then
				State.processedParts[obj] = true

				stylePart(obj)

				if CONFIG.UseTrueMeshWireframe and obj:IsA("MeshPart") then
					local generation = State.generation

					task.spawn(function()
						buildTrueMeshWireframe(obj, generation)
					end)
				else
					addBoxWireframe(obj)
				end
			end
		else
			styleExtraVisual(obj)
		end
	end
end

local function clearEffect()
	State.generation += 1

	for _, obj in ipairs(State.adornments) do
		safeDestroy(obj)
	end

	for _, obj in ipairs(State.highlights) do
		safeDestroy(obj)
	end

	table.clear(State.adornments)
	table.clear(State.highlights)
	table.clear(State.processedParts)
	table.clear(State.processedContainers)

	if State.folder then
		pcall(function()
			State.folder:ClearAllChildren()
		end)
	end

	restoreProperties()

	State.currentTool = nil
end

local function refresh()
	if not State.enabled then
		return
	end

	local equippedTool = getEquippedTool()

	if equippedTool ~= State.currentTool then
		clearEffect()
		State.currentTool = equippedTool
	end

	if not equippedTool then
		return
	end

	ensureBloom()

	local targets = getVisualTargets(equippedTool)

	for _, container in ipairs(targets) do
		applyToContainer(container)
	end
end

local function shutdown()
	if not State.enabled then
		return
	end

	State.enabled = false

	for _, conn in ipairs(State.connections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end

	table.clear(State.connections)

	clearEffect()

	safeDestroy(State.folder)
	State.folder = nil

	safeDestroy(State.bloom)
	State.bloom = nil

	print("[XRay] Fully cleaned up with F10.")

	pcall(function()
		script.Disabled = true
	end)

	task.defer(function()
		pcall(function()
			script:Destroy()
		end)
	end)
end

addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F10 then
		shutdown()
	end
end))

addConnection(RunService.Heartbeat:Connect(function()
	if not State.enabled then
		return
	end

	local now = os.clock()

	if now - State.lastScan >= CONFIG.ScanInterval then
		State.lastScan = now
		refresh()
	end
end))

addConnection(player.CharacterAdded:Connect(function()
	task.wait(0.25)

	if State.enabled then
		clearEffect()
		refresh()
	end
end))

refresh()
