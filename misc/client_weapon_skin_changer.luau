-- Client-only weapon skin changer LocalScript.
-- No server scripts, RemoteEvents, datastore, or server communication.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

local CONTROLLER_NAME = "CodexClientWeaponSkinChanger_Controller"
local GUI_NAME = "CodexClientWeaponSkinChanger"
local GLOBAL_KEY = "__CodexClientWeaponSkinChanger"
local HOLSTER_APPLY_DELAY = 0.35

local oldController = PLAYER_GUI:FindFirstChild(CONTROLLER_NAME)
if oldController then
	local uninject = oldController:FindFirstChild("Uninject")
	if uninject and uninject:IsA("BindableFunction") then
		pcall(function()
			uninject:Invoke()
		end)
	end
	oldController:Destroy()
end

local oldGlobal = rawget(_G, GLOBAL_KEY)
if type(oldGlobal) == "table" and type(oldGlobal.Uninject) == "function" then
	pcall(function()
		oldGlobal.Uninject()
	end)
	_G[GLOBAL_KEY] = nil
end

local oldGui = PLAYER_GUI:FindFirstChild(GUI_NAME)
if oldGui then
	oldGui:Destroy()
end

for _, child in ipairs(PLAYER_GUI:GetChildren()) do
	if (child:IsA("SurfaceGui") and child.Name:find("ClientSkin_CustomSurface")) or (child:IsA("BillboardGui") and child.Name == "ClientSkin_CustomBillboard") then
		child:Destroy()
	end
end

local controllerFolder = Instance.new("Folder")
controllerFolder.Name = CONTROLLER_NAME
controllerFolder.Parent = PLAYER_GUI

local SkinCatalog = {
	Universal = {
		{
			Id = "plain_white",
			Name = "Plain White",
			Preview = "",
			SwatchColor = Color3.fromRGB(245, 245, 245),
			Parts = {
				["*"] = {
					Color = Color3.fromRGB(245, 245, 245),
					Material = Enum.Material.SmoothPlastic,
				},
			},
		},
		{
			Id = "plain_black",
			Name = "Plain Black",
			Preview = "",
			SwatchColor = Color3.fromRGB(12, 12, 12),
			Parts = {
				["*"] = {
					Color = Color3.fromRGB(12, 12, 12),
					Material = Enum.Material.SmoothPlastic,
				},
			},
		},
		{
			Id = "muted_blue",
			Name = "Muted Blue",
			Preview = "",
			SwatchColor = Color3.fromRGB(74, 112, 154),
			Parts = {
				["*"] = {
					Color = Color3.fromRGB(74, 112, 154),
					Material = Enum.Material.Metal,
				},
			},
		},
		{
			Id = "arctic_asset",
			Name = "Arctic Asset",
			Preview = "rbxassetid://123456789",
			SwatchColor = Color3.fromRGB(220, 230, 235),
			Parts = {
				["*"] = {
					Color = Color3.fromRGB(220, 230, 235),
					Mesh = {
						TextureId = "rbxassetid://123456789",
					},
					Decals = {
						{ Name = "ClientSkin_Decal_Right", Face = Enum.NormalId.Right, Texture = "rbxassetid://123456789" },
					},
				},
			},
		},
	},

	MP5 = {
		{
			Id = "mp5_blueprint",
			Name = "MP5 Blueprint",
			Preview = "rbxassetid://123456789",
			SwatchColor = Color3.fromRGB(58, 88, 120),
			Parts = {
				Handle = {
					Color = Color3.fromRGB(58, 88, 120),
					Mesh = {
						MeshId = "rbxassetid://123456789",
						TextureId = "rbxassetid://123456789",
					},
				},
				["*"] = {
					Color = Color3.fromRGB(42, 48, 55),
					Textures = {
						{
							Name = "ClientSkin_Texture_Front",
							Face = Enum.NormalId.Front,
							Texture = "rbxassetid://123456789",
							StudsPerTileU = 1,
							StudsPerTileV = 1,
						},
					},
				},
			},
		},
	},

	["M9 Beretta"] = {
		{
			Id = "m9_whiteout",
			Name = "M9 Whiteout",
			Preview = "",
			SwatchColor = Color3.fromRGB(245, 245, 245),
			Parts = {
				["*"] = {
					Color = Color3.fromRGB(245, 245, 245),
					Material = Enum.Material.SmoothPlastic,
				},
			},
		},
	},
}

local state = {
	Connections = {},
	ActiveSkins = {},
	Originals = {},
	ManagedInstances = {},
	PendingTools = {},
	ApplyingTools = {},
	HookedContainers = {},
	WatchedCosmeticsRoots = {},
	CosmeticsReskinQueued = false,
	SelectedSkinId = nil,
	CurrentToolName = nil,
	CurrentTab = "Skins",
	CustomColor = Color3.fromRGB(255, 255, 255),
	CustomHue = 0,
	CustomSaturation = 0,
	CustomValue = 1,
	CustomDecalAsset = "",
	CustomDecalFace = "All",
	SelectedToolName = nil,
	Gui = nil,
	Panel = nil,
	Destroyed = false,
	Visible = false,
	MouseIconBeforeOpen = UserInputService.MouseIconEnabled,
	MouseBehaviorBeforeOpen = UserInputService.MouseBehavior,
}

local ui = {}
local rawActiveSkins = nil

local FACE_NAMES = { "All", "Front", "Back", "Left", "Right", "Top", "Bottom" }
local FACE_BY_NAME = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
}

local function safeCall(callback, ...)
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[CodexSkinChanger] " .. tostring(err))
	end
end

local function addConnection(connection)
	table.insert(state.Connections, connection)
	return connection
end

local function connect(signal, callback)
	return addConnection(signal:Connect(function(...)
		safeCall(callback, ...)
	end))
end

local function clearArray(array)
	for index = #array, 1, -1 do
		array[index] = nil
	end
end

local function clearMap(map)
	if not map then
		return
	end
	for key in pairs(map) do
		map[key] = nil
	end
end

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	return instance
end

local function rgbToHex(color)
	local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

local function parseHex(text)
	local value = tostring(text or ""):gsub("%s+", "")
	if value:sub(1, 1) == "#" then
		value = value:sub(2)
	end
	if value:sub(1, 2):lower() == "0x" then
		value = value:sub(3)
	end
	if #value == 3 then
		value = value:sub(1, 1) .. value:sub(1, 1) .. value:sub(2, 2) .. value:sub(2, 2) .. value:sub(3, 3) .. value:sub(3, 3)
	end
	if #value ~= 6 or value:find("[^%x]") then
		return nil
	end
	local r = tonumber(value:sub(1, 2), 16)
	local g = tonumber(value:sub(3, 4), 16)
	local b = tonumber(value:sub(5, 6), 16)
	return Color3.fromRGB(r, g, b)
end

local function parseByte(text)
	local number = tonumber(tostring(text or ""):match("%d+"))
	if not number then
		return nil
	end
	return math.clamp(math.floor(number + 0.5), 0, 255)
end

local function normalizeAssetId(text)
	local value = tostring(text or ""):gsub("%s+", "")
	if value == "" then
		return ""
	end
	local digits = value:match("(%d+)")
	if digits then
		return "rbxassetid://" .. digits
	end
	if value:sub(1, 13):lower() == "rbxassetid://" then
		return value
	end
	return value
end

local function getAssetDigits(text)
	return tostring(text or ""):match("(%d+)")
end

local function getImageContentForAsset(text)
	local digits = getAssetDigits(text)
	if digits then
		return "rbxthumb://type=Asset&id=" .. digits .. "&w=420&h=420"
	end
	return normalizeAssetId(text)
end

local function encodeCatalog(skinId)
	return "catalog:" .. tostring(skinId)
end

local function encodeColor(color)
	return "color:" .. rgbToHex(color)
end

local function encodeDecal(assetId, faceName)
	return "decal:" .. normalizeAssetId(assetId) .. ":" .. tostring(faceName or "All")
end

local function decodeSelection(selection)
	if type(selection) ~= "string" then
		return nil, nil, nil
	end
	local kind, rest = selection:match("^([^:]+):(.+)$")
	if kind == "catalog" then
		return "catalog", rest, nil
	elseif kind == "color" then
		return "color", parseHex(rest), nil
	elseif kind == "decal" then
		local asset, face = rest:match("^(.-):([^:]+)$")
		return "decal", asset or rest, face or "All"
	end
	return "catalog", selection, nil
end

local function isWeaponTool(instance)
	return instance and instance:IsA("Tool")
end

local function getBackpack()
	return LOCAL_PLAYER:FindFirstChildOfClass("Backpack")
end

local function getToolContainers()
	return getBackpack(), LOCAL_PLAYER.Character
end

local function normalizedName(value)
	return string.lower(tostring(value or "")):gsub("[%s_%-]+", "")
end

local function visualNameMatchesToolName(instanceName, toolName, allowLooseMatch)
	local instanceKey = normalizedName(instanceName)
	local toolKey = normalizedName(toolName)
	if instanceKey == "" or toolKey == "" then
		return false
	end
	if instanceKey == toolKey then
		return true
	end
	return allowLooseMatch == true and string.find(instanceKey, toolKey, 1, true) ~= nil
end

local function getOwnedCosmeticsFolder()
	local cosmeticsRoot = workspace:FindFirstChild("CharacterCosmetics")
	if not cosmeticsRoot then
		return nil
	end
	return cosmeticsRoot:FindFirstChild(tostring(LOCAL_PLAYER.UserId) .. "_Cosmetics")
end

local function getClientHolstersFolder()
	local cosmeticsFolder = getOwnedCosmeticsFolder()
	if not cosmeticsFolder then
		return nil
	end
	return cosmeticsFolder:FindFirstChild("ClientHolstersFolder")
end

local function isClientHolstersFolder(instance)
	return instance ~= nil and instance == getClientHolstersFolder()
end

local function isHolsterVisualContainer(instance)
	local holstersFolder = getClientHolstersFolder()
	return instance ~= nil and holstersFolder ~= nil and instance ~= holstersFolder and instance:IsDescendantOf(holstersFolder)
end

local function directChildUnder(root, descendant)
	if not root or not descendant then
		return nil
	end

	local cursor = descendant
	while cursor and cursor.Parent ~= root do
		cursor = cursor.Parent
	end
	return cursor
end

local function collectVisualSearchRoots()
	local roots = {}
	local function add(root, loose, directChildrenOnly)
		if root then
			table.insert(roots, {
				Root = root,
				LooseMatch = loose == true,
				DirectChildrenOnly = directChildrenOnly == true,
			})
		end
	end

	add(LOCAL_PLAYER.Character, false)
	add(workspace.CurrentCamera, false)
	add(getClientHolstersFolder(), true, true)
	return roots
end

local function getCurrentTool()
	local character = LOCAL_PLAYER.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				return child
			end
		end
	end

	local backpack = getBackpack()
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				return child
			end
		end
	end

	return nil
end

local function getToolByName(toolName)
	local backpack, character = getToolContainers()
	local containers = { character, backpack }
	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == toolName then
					return child
				end
			end
		end
	end
	return nil
end

local function forEachTool(callback)
	local backpack, character = getToolContainers()
	local containers = { character, backpack }
	local seen = {}
	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and not seen[child] then
					seen[child] = true
					callback(child)
				end
			end
		end
	end
end

local function anyTool()
	local found = nil
	forEachTool(function(tool)
		if not found then
			found = tool
		end
	end)
	return found
end

local function getAvailableToolNames()
	local names = {}
	local seen = {}
	forEachTool(function(tool)
		if not seen[tool.Name] then
			seen[tool.Name] = true
			table.insert(names, tool.Name)
		end
	end)
	table.sort(names)
	return names
end

local function toolNameExists(toolName)
	if not toolName then
		return false
	end
	local exists = false
	forEachTool(function(tool)
		if tool.Name == toolName then
			exists = true
		end
	end)
	return exists
end

local function forEachToolNamed(toolName, callback)
	if not toolName then
		return
	end
	forEachTool(function(tool)
		if tool.Name == toolName then
			callback(tool)
		end
	end)
end

local function hasVisualParts(instance)
	if not instance then
		return false
	end
	if instance:IsA("BasePart") then
		return true
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return true
		end
	end
	return false
end

local function forEachVisualContainerNamed(toolName, callback)
	if not toolName then
		return
	end

	local seen = {}
	forEachToolNamed(toolName, function(tool)
		seen[tool] = true
		callback(tool)
	end)

	for _, entry in ipairs(collectVisualSearchRoots()) do
		local root = entry.Root
		if root then
			local candidates = entry.DirectChildrenOnly and root:GetChildren() or root:GetDescendants()
			for _, candidate in ipairs(candidates) do
				if not seen[candidate] and visualNameMatchesToolName(candidate.Name, toolName, entry.LooseMatch) and hasVisualParts(candidate) then
					seen[candidate] = true
					callback(candidate, toolName)
				end
			end
		end
	end
end

local function getSkinsForTool(toolName)
	local skins = {}
	if toolName and SkinCatalog[toolName] then
		for _, skin in ipairs(SkinCatalog[toolName]) do
			table.insert(skins, skin)
		end
	end
	for _, skin in ipairs(SkinCatalog.Universal or {}) do
		table.insert(skins, skin)
	end
	return skins
end

local function findSkin(toolName, skinId)
	for _, skin in ipairs(getSkinsForTool(toolName)) do
		if skin.Id == skinId then
			return skin
		end
	end
	return nil
end

local function countSkins(toolName)
	local count = 0
	for _ in ipairs(getSkinsForTool(toolName)) do
		count = count + 1
	end
	return count
end

local function trackOriginal(instance)
	if not instance or state.Originals[instance] then
		return state.Originals[instance]
	end

	local data = {
		ClassName = instance.ClassName,
		Parent = instance.Parent,
		CreatedBySkinChanger = state.ManagedInstances[instance] == true,
	}

	if instance:IsA("BasePart") then
		data.Color = instance.Color
		data.Material = instance.Material
		data.Transparency = instance.Transparency
		data.LocalTransparencyModifier = instance.LocalTransparencyModifier
		data.Reflectance = instance.Reflectance
		if instance:IsA("MeshPart") then
			data.TextureID = instance.TextureID
		end
	elseif instance:IsA("SpecialMesh") then
		data.MeshId = instance.MeshId
		data.TextureId = instance.TextureId
		data.Scale = instance.Scale
		data.Offset = instance.Offset
		data.VertexColor = instance.VertexColor
		data.MeshType = instance.MeshType
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		data.Texture = instance.Texture
		data.Transparency = instance.Transparency
		data.Color3 = instance.Color3
		data.Face = instance.Face
		if instance:IsA("Texture") then
			data.StudsPerTileU = instance.StudsPerTileU
			data.StudsPerTileV = instance.StudsPerTileV
			data.OffsetStudsU = instance.OffsetStudsU
			data.OffsetStudsV = instance.OffsetStudsV
		end
	elseif instance:IsA("SurfaceAppearance") then
		data.ColorMap = instance.ColorMap
		data.MetalnessMap = instance.MetalnessMap
		data.NormalMap = instance.NormalMap
		data.RoughnessMap = instance.RoughnessMap
		data.AlphaMode = instance.AlphaMode
	end

	state.Originals[instance] = data
	return data
end

local function restoreTrackedInstance(instance, data)
	if not instance or not instance.Parent then
		state.Originals[instance] = nil
		state.ManagedInstances[instance] = nil
		return
	end

	if data.CreatedBySkinChanger then
		state.Originals[instance] = nil
		state.ManagedInstances[instance] = nil
		instance:Destroy()
		return
	end

	if instance:IsA("BasePart") then
		instance.Color = data.Color or instance.Color
		instance.Material = data.Material or instance.Material
		instance.Transparency = data.Transparency or 0
		instance.LocalTransparencyModifier = data.LocalTransparencyModifier or 0
		instance.Reflectance = data.Reflectance or 0
		if instance:IsA("MeshPart") then
			instance.TextureID = data.TextureID or ""
		end
	elseif instance:IsA("SpecialMesh") then
		instance.MeshId = data.MeshId or ""
		instance.TextureId = data.TextureId or ""
		instance.Scale = data.Scale or Vector3.new(1, 1, 1)
		instance.Offset = data.Offset or Vector3.new(0, 0, 0)
		instance.VertexColor = data.VertexColor or Vector3.new(1, 1, 1)
		instance.MeshType = data.MeshType or instance.MeshType
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Texture = data.Texture or ""
		instance.Transparency = data.Transparency or 0
		instance.Color3 = data.Color3 or Color3.new(1, 1, 1)
		instance.Face = data.Face or Enum.NormalId.Front
		if instance:IsA("Texture") then
			instance.StudsPerTileU = data.StudsPerTileU or 1
			instance.StudsPerTileV = data.StudsPerTileV or 1
			instance.OffsetStudsU = data.OffsetStudsU or 0
			instance.OffsetStudsV = data.OffsetStudsV or 0
		end
	elseif instance:IsA("SurfaceAppearance") then
		instance.ColorMap = data.ColorMap or ""
		instance.MetalnessMap = data.MetalnessMap or ""
		instance.NormalMap = data.NormalMap or ""
		instance.RoughnessMap = data.RoughnessMap or ""
		instance.AlphaMode = data.AlphaMode or Enum.AlphaMode.Overlay
	end
end

local function isSkinChangerManagedInstance(instance)
	if typeof(instance) ~= "Instance" or string.sub(instance.Name, 1, 11) ~= "ClientSkin_" then
		return false
	end
	return instance:IsA("SpecialMesh") or instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("SurfaceGui") or instance:IsA("BillboardGui")
end

local function cleanupStaleSkinInstances(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if isSkinChangerManagedInstance(descendant) then
			state.Originals[descendant] = nil
			state.ManagedInstances[descendant] = nil
			descendant:Destroy()
		end
	end
end

local function resetTool(tool)
	if not tool then
		return
	end

	state.ApplyingTools[tool] = true
	for instance, data in pairs(state.Originals) do
		local belongsToTool = false
		if typeof(instance) == "Instance" then
			belongsToTool = instance:IsDescendantOf(tool)
			if not belongsToTool and instance:IsA("SurfaceGui") and instance.Adornee then
				belongsToTool = instance.Adornee:IsDescendantOf(tool)
			end
			if not belongsToTool and instance:IsA("BillboardGui") and instance.Adornee then
				belongsToTool = instance.Adornee:IsDescendantOf(tool)
			end
		end
		if belongsToTool then
			restoreTrackedInstance(instance, data)
		end
	end
	cleanupStaleSkinInstances(tool)
	state.ApplyingTools[tool] = nil
end

local function resetToolName(toolName)
	forEachVisualContainerNamed(toolName, function(container)
		resetTool(container)
	end)
	state.ActiveSkins[toolName] = nil
end

local function getOrCreateSpecialMesh(part, shouldCreate)
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		trackOriginal(mesh)
		return mesh
	end
	if not shouldCreate then
		return nil
	end

	mesh = Instance.new("SpecialMesh")
	mesh.Name = "ClientSkin_SpecialMesh"
	state.ManagedInstances[mesh] = true
	mesh.Parent = part
	trackOriginal(mesh)
	return mesh
end

local function stripPartVisualsForPlainColor(part)
	if part:IsA("MeshPart") then
		trackOriginal(part)
		part.TextureID = ""
	end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SpecialMesh") then
			trackOriginal(child)
			child.TextureId = ""
		elseif child:IsA("Decal") or child:IsA("Texture") then
			trackOriginal(child)
			child.Transparency = 1
		elseif child:IsA("SurfaceAppearance") then
			trackOriginal(child)
			child.ColorMap = ""
			child.MetalnessMap = ""
			child.NormalMap = ""
			child.RoughnessMap = ""
		end
	end
end

local function applyPartOverride(part, override)
	trackOriginal(part)

	if override.Color then
		part.Color = override.Color
	end
	if override.Material then
		part.Material = override.Material
	end
	if override.Transparency ~= nil then
		part.Transparency = override.Transparency
	end
	if override.Reflectance ~= nil then
		part.Reflectance = override.Reflectance
	end
	if override.PlainColor == true then
		stripPartVisualsForPlainColor(part)
	end

	local meshData = override.Mesh
	if meshData then
		local mesh = getOrCreateSpecialMesh(part, meshData.MeshId ~= nil)
		if mesh then
			if meshData.MeshId ~= nil then
				mesh.MeshId = meshData.MeshId
			end
			if meshData.TextureId ~= nil then
				mesh.TextureId = meshData.TextureId
			end
			if meshData.Scale ~= nil then
				mesh.Scale = meshData.Scale
			end
			if meshData.Offset ~= nil then
				mesh.Offset = meshData.Offset
			end
			if meshData.VertexColor ~= nil then
				mesh.VertexColor = meshData.VertexColor
			end
			if meshData.MeshType ~= nil then
				mesh.MeshType = meshData.MeshType
			end
		end
	end

	for _, decalData in ipairs(override.Decals or {}) do
		local object = nil
		local face = decalData.Face or Enum.NormalId.Front
		local name = decalData.Name or "ClientSkin_Decal"
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("Decal") and child.Name == name and child.Face == face then
				object = child
				break
			end
		end
		if not object then
			object = Instance.new("Decal")
			object.Name = name
			state.ManagedInstances[object] = true
			object.Parent = part
		end
		trackOriginal(object)
		object.Face = face
		object.Texture = decalData.Texture or ""
		object.Transparency = decalData.Transparency or 0
		object.Color3 = decalData.Color3 or Color3.new(1, 1, 1)
	end

	for _, textureData in ipairs(override.Textures or {}) do
		local object = nil
		local face = textureData.Face or Enum.NormalId.Front
		local name = textureData.Name or "ClientSkin_Texture"
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("Texture") and child.Name == name and child.Face == face then
				object = child
				break
			end
		end
		if not object then
			object = Instance.new("Texture")
			object.Name = name
			state.ManagedInstances[object] = true
			object.Parent = part
		end
		trackOriginal(object)
		object.Face = face
		object.Texture = textureData.Texture or ""
		object.Transparency = textureData.Transparency or 0
		object.Color3 = textureData.Color3 or Color3.new(1, 1, 1)
		object.StudsPerTileU = textureData.StudsPerTileU or 1
		object.StudsPerTileV = textureData.StudsPerTileV or 1
		object.OffsetStudsU = textureData.OffsetStudsU or 0
		object.OffsetStudsV = textureData.OffsetStudsV or 0
	end

	if override.MeshPartTexture and part:IsA("MeshPart") then
		trackOriginal(part)
		part.TextureID = override.MeshPartTexture
	end
end

local function partMatches(part, partName)
	return partName == "*" or part.Name == partName
end

local function isSmallSkinDetailPart(part, totalPartCount)
	if totalPartCount <= 1 then
		return false
	end

	local size = part.Size
	local volume = size.X * size.Y * size.Z
	local maxAxis = math.max(size.X, size.Y, size.Z)
	local minAxis = math.min(size.X, size.Y, size.Z)

	if volume <= 0.012 then
		return true
	end
	if maxAxis <= 0.25 then
		return true
	end
	if minAxis <= 0.07 and maxAxis <= 0.55 then
		return true
	end

	return false
end

local function isSkinHelperPart(part)
	local name = part.Name
	return name == "HOLSTER_PRIMARY_PART" or name == "BoundingBox"
end

local function hideSmallSkinDetailPart(part)
	trackOriginal(part)
	part.LocalTransparencyModifier = 1
end

local function applySkinToTool(tool, skin)
	if not tool or not tool.Parent or not skin or state.Destroyed then
		return
	end

	state.ApplyingTools[tool] = true
	resetTool(tool)

	local totalPartCount = 0
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			totalPartCount = totalPartCount + 1
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for partName, override in pairs(skin.Parts or {}) do
				if partMatches(descendant, partName) then
					local shouldIgnorePart = isSkinHelperPart(descendant) or (override.IgnoreSmallParts == true and isSmallSkinDetailPart(descendant, totalPartCount))
					if shouldIgnorePart then
						if override.HideSmallParts == true then
							hideSmallSkinDetailPart(descendant)
						end
					else
						applyPartOverride(descendant, override)
					end
				end
			end
		end
	end

	state.ApplyingTools[tool] = nil
end

local function makeColorSkin(color)
	return {
		Id = "custom_color",
		Name = "Custom Color",
		SwatchColor = color,
		Parts = {
			["*"] = {
				Color = color,
				Material = Enum.Material.SmoothPlastic,
				PlainColor = true,
			},
		},
	}
end

local function makeDecalSkin(assetId, faceName)
	local normalized = normalizeAssetId(assetId)
	local imageContent = getImageContentForAsset(normalized)
	local textures = {}
	if faceName == "All" then
		for _, item in ipairs(FACE_NAMES) do
			if item ~= "All" then
				table.insert(textures, {
					Name = "ClientSkin_CustomTexture_" .. item,
					Face = FACE_BY_NAME[item],
					Texture = imageContent,
					StudsPerTileU = 2,
					StudsPerTileV = 2,
				})
			end
		end
	else
		table.insert(textures, {
			Name = "ClientSkin_CustomTexture_" .. faceName,
			Face = FACE_BY_NAME[faceName] or Enum.NormalId.Front,
			Texture = imageContent,
			StudsPerTileU = 2,
			StudsPerTileV = 2,
		})
	end

	return {
		Id = "custom_decal",
		Name = "Custom Decal",
		Preview = imageContent,
		Parts = {
			["*"] = {
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
				Mesh = {
					TextureId = imageContent,
				},
				MeshPartTexture = imageContent,
				Textures = textures,
				IgnoreSmallParts = true,
				HideSmallParts = true,
			},
		},
	}
end

local function applySelectionToTool(tool, selection)
	if not tool or not selection then
		return
	end
	local kind, value, extra = decodeSelection(selection)
	if kind == "catalog" then
		local skin = findSkin(tool.Name, value)
		if skin then
			applySkinToTool(tool, skin)
		end
	elseif kind == "color" and value then
		applySkinToTool(tool, makeColorSkin(value))
	elseif kind == "decal" and value and value ~= "" then
		applySkinToTool(tool, makeDecalSkin(value, extra or "All"))
	end
end

local function activeSelectionForVisualContainer(container)
	if not container then
		return nil, nil
	end

	local exactSelection = state.ActiveSkins[container.Name]
	if exactSelection then
		return container.Name, exactSelection
	end

	for toolName, selection in pairs(state.ActiveSkins) do
		if visualNameMatchesToolName(container.Name, toolName, true) then
			return toolName, selection
		end
	end

	return nil, nil
end

local function applyActiveSkin(tool, selection)
	if not tool or state.Destroyed then
		return
	end

	if not selection then
		local _, activeSelection = activeSelectionForVisualContainer(tool)
		selection = activeSelection
	end

	applySelectionToTool(tool, selection)
end

local function scheduleApply(tool, selection, delaySeconds)
	if not tool or state.Destroyed or state.ApplyingTools[tool] then
		return
	end
	if state.PendingTools[tool] then
		if selection then
			state.PendingTools[tool] = selection
		end
		return
	end

	state.PendingTools[tool] = selection or true
	local function runPendingApply()
		local pendingSelection = state.PendingTools[tool]
		state.PendingTools[tool] = nil
		if tool and tool.Parent and not state.ApplyingTools[tool] then
			if pendingSelection == true then
				pendingSelection = nil
			end
			applyActiveSkin(tool, pendingSelection)
		end
	end

	if delaySeconds and delaySeconds > 0 then
		task.delay(delaySeconds, runPendingApply)
	else
		task.defer(runPendingApply)
	end
end

local function reskinAllKnownTools()
	local backpack, character = getToolContainers()
	local containers = { backpack, character }
	for _, container in ipairs(containers) do
		if container then
			for _, descendant in ipairs(container:GetDescendants()) do
				if descendant:IsA("Tool") then
					scheduleApply(descendant)
				end
			end
		end
	end
	for toolName in pairs(state.ActiveSkins) do
		forEachVisualContainerNamed(toolName, function(container)
			scheduleApply(container, state.ActiveSkins[toolName], isHolsterVisualContainer(container) and HOLSTER_APPLY_DELAY or nil)
		end)
	end
end

local function updateMirror(toolName)
	local activeSkinsFolder = controllerFolder:FindFirstChild("ActiveSkins")
	if not activeSkinsFolder then
		return
	end
	local selection = state.ActiveSkins[toolName]
	if selection == nil then
		local old = activeSkinsFolder:FindFirstChild(toolName)
		if old then
			old:Destroy()
		end
		return
	end
	local value = activeSkinsFolder:FindFirstChild(toolName)
	if not value then
		value = Instance.new("StringValue")
		value.Name = toolName
		value.Parent = activeSkinsFolder
	end
	value.Value = selection
end

local function setActiveSelection(toolName, selection)
	state.ActiveSkins[toolName] = selection
	updateMirror(toolName)
end

local function applySelectionToToolName(toolName, selection)
	if not toolName or not selection then
		return false
	end
	local applied = false
	forEachVisualContainerNamed(toolName, function(container)
		applySelectionToTool(container, selection)
		applied = true
	end)
	if applied then
		setActiveSelection(toolName, selection)
	end
	return applied
end

local function setCardSelected(card, selected)
	card.BackgroundColor3 = selected and Color3.fromRGB(42, 61, 82) or Color3.fromRGB(31, 31, 31)
	card.BorderColor3 = selected and Color3.fromRGB(145, 170, 198) or Color3.fromRGB(54, 54, 54)
end

local function updateButtonState(button, enabled)
	if not button then
		return
	end
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.TextTransparency = enabled and 0 or 0.45
end

local function updateCustomCursorPosition()
	if not ui.CustomCursor then
		return
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	ui.CustomCursor.Position = UDim2.fromOffset(mouseLocation.X - inset.X, mouseLocation.Y - inset.Y)
end

local function clearContent()
	if not ui.Content then
		return
	end
	for _, child in ipairs(ui.Content:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local refreshUi

local function refreshToolButtons()
	if not ui.ToolRow then
		return
	end
	for _, child in ipairs(ui.ToolRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local names = getAvailableToolNames()
	if #names == 0 then
		state.SelectedToolName = nil
		return
	end
	if not state.SelectedToolName or not toolNameExists(state.SelectedToolName) then
		local equipped = getCurrentTool()
		state.SelectedToolName = equipped and equipped.Name or names[1]
	end

	for _, toolName in ipairs(names) do
		local selected = toolName == state.SelectedToolName
		local button = make("TextButton", {
			Name = "Tool_" .. toolName,
			Text = toolName,
			TextColor3 = selected and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(205, 205, 205),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = true,
			BackgroundColor3 = selected and Color3.fromRGB(48, 73, 102) or Color3.fromRGB(34, 34, 34),
			BorderSizePixel = 0,
			Size = UDim2.new(0, math.clamp(#toolName * 8 + 24, 72, 132), 1, 0),
			ZIndex = 5,
			Parent = ui.ToolRow,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		connect(button.MouseButton1Click, function()
			state.SelectedToolName = toolName
			refreshUi()
		end)
	end
end

local function setVisible(visible)
	local wasVisible = state.Visible
	if visible and not wasVisible then
		state.MouseIconBeforeOpen = UserInputService.MouseIconEnabled
		state.MouseBehaviorBeforeOpen = UserInputService.MouseBehavior
	end

	state.Visible = visible
	if state.Gui then
		state.Gui.Enabled = visible
	end
	if ui.ModalCapture then
		ui.ModalCapture.Modal = visible
		ui.ModalCapture.Active = visible
		ui.ModalCapture.Visible = visible
	end
	if ui.CustomCursor then
		ui.CustomCursor.Visible = visible
		if visible then
			updateCustomCursorPosition()
		end
	end
	if visible then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif state.MouseIconBeforeOpen ~= nil then
		UserInputService.MouseIconEnabled = state.MouseIconBeforeOpen
		if state.MouseBehaviorBeforeOpen ~= nil then
			UserInputService.MouseBehavior = state.MouseBehaviorBeforeOpen
		end
	end
	controllerFolder:SetAttribute("Visible", visible)
end

local function cycleTab(nextTab)
	state.CurrentTab = nextTab
	for _, button in pairs(ui.TabButtons or {}) do
		button.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
		button.TextColor3 = Color3.fromRGB(210, 210, 210)
	end
	if ui.TabButtons and ui.TabButtons[nextTab] then
		ui.TabButtons[nextTab].BackgroundColor3 = Color3.fromRGB(48, 73, 102)
		ui.TabButtons[nextTab].TextColor3 = Color3.fromRGB(245, 245, 245)
	end
end

local function currentToolName()
	if state.SelectedToolName and toolNameExists(state.SelectedToolName) then
		return state.SelectedToolName, getToolByName(state.SelectedToolName)
	end

	local tool = getCurrentTool()
	if not tool then
		tool = anyTool()
	end
	if tool then
		state.SelectedToolName = tool.Name
		return tool.Name, tool
	end
	state.SelectedToolName = nil
	return nil, nil
end

local function applyCurrentCatalog()
	local toolName, tool = currentToolName()
	if not tool or not state.SelectedSkinId then
		return false
	end
	local skin = findSkin(toolName, state.SelectedSkinId)
	if not skin then
		return false
	end
	local selection = encodeCatalog(skin.Id)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	return true
end

local function applyCurrentColor()
	local toolName = currentToolName()
	if not toolName then
		return false
	end
	local selection = encodeColor(state.CustomColor)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	return true
end

local function applyCurrentDecal()
	local toolName = currentToolName()
	if not toolName then
		return false
	end
	local assetId = normalizeAssetId(ui.DecalBox and ui.DecalBox.Text or state.CustomDecalAsset)
	if assetId == "" then
		return false
	end
	state.CustomDecalAsset = assetId
	local selection = encodeDecal(assetId, state.CustomDecalFace)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	return true
end

function refreshUi()
	if state.Destroyed or not ui.Content then
		return
	end

	refreshToolButtons()
	local toolName = currentToolName()
	state.CurrentToolName = toolName
	if ui.Title then
		ui.Title.Text = toolName and ("Weapon Skins - " .. toolName) or "Weapon Skins - No weapon found"
	end
	updateButtonState(ui.ApplyButton, toolName ~= nil)
	updateButtonState(ui.ResetButton, toolName ~= nil)

	clearContent()

	if state.CurrentTab == "Skins" then
		local grid = make("ScrollingFrame", {
			Name = "SkinGrid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120),
			Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Parent = ui.Content,
		})
		local layout = make("UIGridLayout", {
			CellSize = UDim2.new(0, 126, 0, 150),
			CellPadding = UDim2.new(0, 10, 0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		ui.Grid = grid
		ui.Layout = layout

		if toolName then
			local skins = getSkinsForTool(toolName)
			local activeKind, activeValue = decodeSelection(state.ActiveSkins[toolName])
			if activeKind == "catalog" and activeValue and findSkin(toolName, activeValue) then
				state.SelectedSkinId = activeValue
			elseif not state.SelectedSkinId or not findSkin(toolName, state.SelectedSkinId) then
				state.SelectedSkinId = skins[1] and skins[1].Id or nil
			end

			for _, skin in ipairs(skins) do
				local card = make("TextButton", {
					Name = skin.Id,
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.new(0, 126, 0, 150),
					BackgroundColor3 = Color3.fromRGB(31, 31, 31),
					BorderColor3 = Color3.fromRGB(54, 54, 54),
					BorderSizePixel = 1,
					ZIndex = 5,
					Parent = grid,
				})
				make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = card })

				local previewFrame = make("Frame", {
					Name = "Preview",
					BackgroundColor3 = skin.SwatchColor or Color3.fromRGB(24, 24, 24),
					BorderSizePixel = 0,
					Size = UDim2.new(1, -16, 0, 86),
					Position = UDim2.new(0, 8, 0, 8),
					ZIndex = 6,
					Parent = card,
				})
				make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = previewFrame })
				if skin.Preview and skin.Preview ~= "" then
					make("ImageLabel", {
						Name = "Thumbnail",
						BackgroundTransparency = 1,
						Image = skin.Preview,
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.new(1, 0, 1, 0),
						ZIndex = 7,
						Parent = previewFrame,
					})
				else
					make("TextLabel", {
						Name = "ColorLabel",
						BackgroundTransparency = 1,
						Text = "COLOR",
						TextColor3 = Color3.fromRGB(225, 225, 225),
						TextSize = 12,
						Font = Enum.Font.GothamBold,
						Size = UDim2.new(1, 0, 1, 0),
						ZIndex = 7,
						Parent = previewFrame,
					})
				end
				make("TextLabel", {
					Name = "Name",
					BackgroundTransparency = 1,
					Text = skin.Name,
					TextColor3 = Color3.fromRGB(225, 225, 225),
					TextSize = 13,
					Font = Enum.Font.GothamMedium,
					TextWrapped = true,
					Size = UDim2.new(1, -14, 0, 38),
					Position = UDim2.new(0, 7, 0, 102),
					ZIndex = 7,
					Parent = card,
				})
				setCardSelected(card, skin.Id == state.SelectedSkinId)
				connect(card.MouseButton1Click, function()
					state.SelectedSkinId = skin.Id
					for _, other in ipairs(grid:GetChildren()) do
						if other:IsA("TextButton") then
							setCardSelected(other, other.Name == skin.Id)
						end
					end
				end)
			end
		end

		task.defer(function()
			if grid and layout then
				grid.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
			end
		end)
	elseif state.CurrentTab == "Color" then
		local color = state.CustomColor
		local h, s, v = color:ToHSV()
		state.CustomHue = h
		state.CustomSaturation = s
		state.CustomValue = v

		local square = make("TextButton", {
			Name = "ColorSquare",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromHSV(state.CustomHue, 1, 1),
			BorderColor3 = Color3.fromRGB(70, 70, 70),
			Size = UDim2.new(0, 220, 0, 180),
			Position = UDim2.new(0, 0, 0, 0),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = square })
		local whiteOverlay = make("Frame", {
			Name = "WhiteOverlay",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 6,
			Parent = square,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 0,
			Parent = whiteOverlay,
		})
		local blackOverlay = make("Frame", {
			Name = "BlackOverlay",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 7,
			Parent = square,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Rotation = 90,
			Parent = blackOverlay,
		})
		local picker = make("Frame", {
			Name = "Picker",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.new(0, 10, 0, 10),
			Position = UDim2.new(state.CustomSaturation, -5, 1 - state.CustomValue, -5),
			ZIndex = 9,
			Parent = square,
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = picker })

		local hueBar = make("TextButton", {
			Name = "HueBar",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderColor3 = Color3.fromRGB(70, 70, 70),
			Size = UDim2.new(0, 24, 0, 180),
			Position = UDim2.new(0, 234, 0, 0),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = hueBar })
		make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			}),
			Rotation = 90,
			Parent = hueBar,
		})
		local huePicker = make("Frame", {
			Name = "HuePicker",
			BackgroundColor3 = Color3.fromRGB(245, 245, 245),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.new(1, 4, 0, 4),
			Position = UDim2.new(0, -2, state.CustomHue, -2),
			ZIndex = 9,
			Parent = hueBar,
		})

		local preview = make("Frame", {
			Name = "Preview",
			BackgroundColor3 = color,
			BorderColor3 = Color3.fromRGB(70, 70, 70),
			Size = UDim2.new(0, 132, 0, 72),
			Position = UDim2.new(0, 278, 0, 0),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = preview })

		local function box(name, placeholder, x, y, w)
			local label = make("TextLabel", {
				Name = name .. "Label",
				BackgroundTransparency = 1,
				Text = placeholder,
				TextColor3 = Color3.fromRGB(190, 190, 190),
				TextSize = 11,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0, w, 0, 14),
				Position = UDim2.new(0, x, 0, y),
				ZIndex = 5,
				Parent = ui.Content,
			})
			local input = make("TextBox", {
				Name = name,
				BackgroundColor3 = Color3.fromRGB(34, 34, 34),
				BorderColor3 = Color3.fromRGB(62, 62, 62),
				TextColor3 = Color3.fromRGB(235, 235, 235),
				PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
				TextSize = 13,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = false,
				Text = "",
				PlaceholderText = placeholder,
				Size = UDim2.new(0, w, 0, 30),
				Position = UDim2.new(0, x, 0, y + 16),
				ZIndex = 5,
				Parent = ui.Content,
			})
			make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = input })
			return input, label
		end

		local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
		local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
		local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
		ui.HexBox = box("HexBox", "HEX", 278, 86, 132)
		ui.RBox = box("RBox", "R", 278, 140, 38)
		ui.GBox = box("GBox", "G", 325, 140, 38)
		ui.BBox = box("BBox", "B", 372, 140, 38)
		ui.HexBox.Text = rgbToHex(color)
		ui.RBox.Text = tostring(r)
		ui.GBox.Text = tostring(g)
		ui.BBox.Text = tostring(b)

		local function setColor(colorValue, skipText)
			state.CustomColor = colorValue
			local nh, ns, nv = colorValue:ToHSV()
			state.CustomHue = nh
			state.CustomSaturation = ns
			state.CustomValue = nv
			square.BackgroundColor3 = Color3.fromHSV(nh, 1, 1)
			picker.Position = UDim2.new(ns, -5, 1 - nv, -5)
			huePicker.Position = UDim2.new(0, -2, nh, -2)
			preview.BackgroundColor3 = colorValue
			if not skipText then
				ui.HexBox.Text = rgbToHex(colorValue)
				ui.RBox.Text = tostring(math.clamp(math.floor(colorValue.R * 255 + 0.5), 0, 255))
				ui.GBox.Text = tostring(math.clamp(math.floor(colorValue.G * 255 + 0.5), 0, 255))
				ui.BBox.Text = tostring(math.clamp(math.floor(colorValue.B * 255 + 0.5), 0, 255))
			end
		end

		local draggingSquare = false
		local draggingHue = false
		local function updateSquare(input)
			local pos = square.AbsolutePosition
			local size = square.AbsoluteSize
			local x = math.clamp((input.Position.X - pos.X) / math.max(size.X, 1), 0, 1)
			local y = math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 1)
			state.CustomSaturation = x
			state.CustomValue = 1 - y
			setColor(Color3.fromHSV(state.CustomHue, state.CustomSaturation, state.CustomValue))
		end
		local function updateHue(input)
			local pos = hueBar.AbsolutePosition
			local size = hueBar.AbsoluteSize
			local y = math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 1)
			state.CustomHue = y
			setColor(Color3.fromHSV(state.CustomHue, state.CustomSaturation, state.CustomValue))
		end
		connect(square.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingSquare = true
				updateSquare(input)
			end
		end)
		connect(hueBar.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingHue = true
				updateHue(input)
			end
		end)
		connect(UserInputService.InputChanged, function(input)
			if draggingSquare and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				updateSquare(input)
			elseif draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				updateHue(input)
			end
		end)
		connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingSquare = false
				draggingHue = false
			end
		end)
		connect(ui.HexBox.FocusLost, function()
			local parsed = parseHex(ui.HexBox.Text)
			if parsed then
				setColor(parsed)
			else
				ui.HexBox.Text = rgbToHex(state.CustomColor)
			end
		end)
		local function rgbFocusLost()
			local nr = parseByte(ui.RBox.Text)
			local ng = parseByte(ui.GBox.Text)
			local nb = parseByte(ui.BBox.Text)
			if nr and ng and nb then
				setColor(Color3.fromRGB(nr, ng, nb))
			else
				setColor(state.CustomColor)
			end
		end
		connect(ui.RBox.FocusLost, rgbFocusLost)
		connect(ui.GBox.FocusLost, rgbFocusLost)
		connect(ui.BBox.FocusLost, rgbFocusLost)
	elseif state.CurrentTab == "Decal" then
		make("TextLabel", {
			Name = "DecalLabel",
			BackgroundTransparency = 1,
			Text = "Custom decal asset",
			TextColor3 = Color3.fromRGB(225, 225, 225),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 5,
			Parent = ui.Content,
		})
		ui.DecalBox = make("TextBox", {
			Name = "DecalBox",
			BackgroundColor3 = Color3.fromRGB(34, 34, 34),
			BorderColor3 = Color3.fromRGB(62, 62, 62),
			TextColor3 = Color3.fromRGB(235, 235, 235),
			PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
			TextSize = 13,
			Font = Enum.Font.Gotham,
			ClearTextOnFocus = false,
			Text = state.CustomDecalAsset,
			PlaceholderText = "rbxassetid://123456789 or 123456789",
			Size = UDim2.new(1, -150, 0, 34),
			Position = UDim2.new(0, 0, 0, 28),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = ui.DecalBox })
		connect(ui.DecalBox.FocusLost, function()
			state.CustomDecalAsset = normalizeAssetId(ui.DecalBox.Text)
			ui.DecalBox.Text = state.CustomDecalAsset
		end)

		ui.FaceButton = make("TextButton", {
			Name = "FaceButton",
			Text = "Face: " .. state.CustomDecalFace,
			TextColor3 = Color3.fromRGB(235, 235, 235),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			BackgroundColor3 = Color3.fromRGB(48, 73, 102),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 136, 0, 34),
			Position = UDim2.new(1, -136, 0, 28),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 5), Parent = ui.FaceButton })
		connect(ui.FaceButton.MouseButton1Click, function()
			local index = 1
			for i, name in ipairs(FACE_NAMES) do
				if name == state.CustomDecalFace then
					index = i
					break
				end
			end
			index = index + 1
			if index > #FACE_NAMES then
				index = 1
			end
			state.CustomDecalFace = FACE_NAMES[index]
			ui.FaceButton.Text = "Face: " .. state.CustomDecalFace
		end)

		local preview = make("ImageLabel", {
			Name = "DecalPreview",
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderColor3 = Color3.fromRGB(70, 70, 70),
			Image = getImageContentForAsset(state.CustomDecalAsset),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.new(0, 180, 0, 130),
			Position = UDim2.new(0, 0, 0, 82),
			ZIndex = 5,
			Parent = ui.Content,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = preview })
		make("TextLabel", {
			Name = "DecalHint",
			BackgroundTransparency = 1,
			Text = "Applies the decal locally to the selected face on every weapon part. Use Reset or Uninject to restore originals.",
			TextColor3 = Color3.fromRGB(180, 180, 180),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -200, 0, 90),
			Position = UDim2.new(0, 200, 0, 86),
			ZIndex = 5,
			Parent = ui.Content,
		})
	end
end

local function buildGui()
	local gui = make("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 100000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PLAYER_GUI,
	})
	state.Gui = gui

	ui.ModalCapture = make("TextButton", {
		Name = "ModalCapture",
		Text = "",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Modal = true,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
		Parent = gui,
	})

	ui.CustomCursor = make("Frame", {
		Name = "CustomPlusCursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 18, 0, 18),
		Visible = false,
		ZIndex = 1000000,
		Parent = gui,
	})
	make("Frame", {
		Name = "HorizontalShadow",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 14, 0, 4),
		Position = UDim2.new(0.5, -7, 0.5, -2),
		ZIndex = 1000000,
		Parent = ui.CustomCursor,
	})
	make("Frame", {
		Name = "VerticalShadow",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 0, 14),
		Position = UDim2.new(0.5, -2, 0.5, -7),
		ZIndex = 1000000,
		Parent = ui.CustomCursor,
	})
	make("Frame", {
		Name = "Horizontal",
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 12, 0, 2),
		Position = UDim2.new(0.5, -6, 0.5, -1),
		ZIndex = 1000001,
		Parent = ui.CustomCursor,
	})
	make("Frame", {
		Name = "Vertical",
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 0, 12),
		Position = UDim2.new(0.5, -1, 0.5, -6),
		ZIndex = 1000001,
		Parent = ui.CustomCursor,
	})

	local panel = make("Frame", {
		Name = "Panel",
		BackgroundColor3 = Color3.fromRGB(26, 26, 26),
		BorderColor3 = Color3.fromRGB(48, 48, 48),
		Size = UDim2.new(0, 560, 0, 420),
		Position = UDim2.new(0, 24, 0.5, -210),
		ZIndex = 3,
		Parent = gui,
	})
	state.Panel = panel
	make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = panel })

	ui.Title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = "Weapon Skins",
		TextColor3 = Color3.fromRGB(235, 235, 235),
		TextSize = 16,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -170, 0, 32),
		Position = UDim2.new(0, 14, 0, 10),
		ZIndex = 4,
		Parent = panel,
	})

	make("TextLabel", {
		Name = "ToggleHint",
		BackgroundTransparency = 1,
		Text = "RightShift",
		TextColor3 = Color3.fromRGB(165, 165, 165),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 130, 0, 28),
		Position = UDim2.new(1, -144, 0, 12),
		ZIndex = 4,
		Parent = panel,
	})

	ui.ToolRow = make("ScrollingFrame", {
		Name = "ToolSelector",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -28, 0, 28),
		Position = UDim2.new(0, 14, 0, 48),
		ZIndex = 4,
		Parent = panel,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.ToolRow,
	})
	connect(ui.ToolRow:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"), function()
		local layout = ui.ToolRow and ui.ToolRow:FindFirstChildOfClass("UIListLayout")
		if layout then
			ui.ToolRow.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 8, 0, 0)
		end
	end)

	local tabBar = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 34),
		Position = UDim2.new(0, 14, 0, 84),
		ZIndex = 4,
		Parent = panel,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabBar,
	})

	ui.TabButtons = {}
	local function tab(name)
		local button = make("TextButton", {
			Name = name .. "Tab",
			Text = name,
			TextColor3 = Color3.fromRGB(210, 210, 210),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			BackgroundColor3 = Color3.fromRGB(36, 36, 36),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 106, 1, 0),
			ZIndex = 5,
			Parent = tabBar,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		ui.TabButtons[name] = button
		connect(button.MouseButton1Click, function()
			cycleTab(name)
			refreshUi()
		end)
	end
	tab("Skins")
	tab("Color")
	tab("Decal")

	ui.Content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -176),
		Position = UDim2.new(0, 14, 0, 130),
		ZIndex = 4,
		Parent = panel,
	})

	local buttons = make("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 36),
		Position = UDim2.new(0, 14, 1, -50),
		ZIndex = 4,
		Parent = panel,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons,
	})

	local function button(name, text, color)
		local item = make("TextButton", {
			Name = name,
			Text = text,
			TextColor3 = Color3.fromRGB(238, 238, 238),
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = true,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 170, 1, 0),
			ZIndex = 5,
			Parent = buttons,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = item })
		return item
	end

	ui.ApplyButton = button("Apply", "Apply", Color3.fromRGB(48, 73, 102))
	ui.ResetButton = button("Reset", "Reset", Color3.fromRGB(45, 45, 45))
	ui.UninjectButton = button("Uninject", "Uninject", Color3.fromRGB(82, 46, 46))

	connect(ui.ApplyButton.MouseButton1Click, function()
		local ok = false
		if state.CurrentTab == "Skins" then
			ok = applyCurrentCatalog()
		elseif state.CurrentTab == "Color" then
			ok = applyCurrentColor()
		elseif state.CurrentTab == "Decal" then
			ok = applyCurrentDecal()
		end
		if ok then
			refreshUi()
		end
	end)

	connect(ui.ResetButton.MouseButton1Click, function()
		local toolName = currentToolName()
		if toolName then
			resetToolName(toolName)
			refreshUi()
		end
	end)

	connect(ui.UninjectButton.MouseButton1Click, function()
		if state.Uninject then
			state.Uninject()
		end
	end)

	cycleTab("Skins")
	refreshUi()
end

local function hookContainer(container)
	if not container or state.Destroyed then
		return
	end
	if state.HookedContainers[container] then
		return
	end
	state.HookedContainers[container] = true
	local isHolstersFolder = isClientHolstersFolder(container)

	connect(container.DescendantAdded, function(descendant)
		if state.Destroyed then
			return
		end
		if state.ManagedInstances[descendant] or isSkinChangerManagedInstance(descendant) then
			return
		end

		if isHolstersFolder then
			local visualContainer = directChildUnder(container, descendant)
			if visualContainer then
				local _, activeSelection = activeSelectionForVisualContainer(visualContainer)
				if activeSelection then
					scheduleApply(visualContainer, activeSelection, HOLSTER_APPLY_DELAY)
				end
			end
			return
		end

		local tool = nil
		local selection = nil
		if descendant:IsA("Tool") then
			tool = descendant
		elseif descendant:IsA("BasePart") or descendant:IsA("SpecialMesh") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			tool = descendant:FindFirstAncestorOfClass("Tool")
			if not tool then
				local cursor = descendant.Parent
				while cursor and cursor ~= container do
					local _, activeSelection = activeSelectionForVisualContainer(cursor)
					if activeSelection and hasVisualParts(cursor) then
						tool = cursor
						selection = activeSelection
						break
					end
					cursor = cursor.Parent
				end
			end
		end

		if tool and not state.ApplyingTools[tool] and not state.ManagedInstances[descendant] then
			scheduleApply(tool, selection)
			task.defer(refreshUi)
		end
	end)

	connect(container.ChildAdded, function(child)
		if isHolstersFolder then
			local _, activeSelection = activeSelectionForVisualContainer(child)
			if activeSelection then
				scheduleApply(child, activeSelection, HOLSTER_APPLY_DELAY)
			end
			return
		end

		if child:IsA("Tool") then
			scheduleApply(child)
			task.defer(refreshUi)
		elseif hasVisualParts(child) then
			local _, activeSelection = activeSelectionForVisualContainer(child)
			if activeSelection then
				scheduleApply(child, activeSelection)
				task.defer(refreshUi)
			end
		end
	end)

	connect(container.ChildRemoved, function()
		task.defer(refreshUi)
	end)
end

local hookHolsterContainers
local hookCosmeticsWatcher

local function hookCharacter(character)
	hookContainer(character)
	task.defer(function()
		hookCosmeticsWatcher()
		hookHolsterContainers()
		reskinAllKnownTools()
		refreshUi()
	end)
end

hookHolsterContainers = function()
	local holstersFolder = getClientHolstersFolder()
	if holstersFolder then
		hookContainer(holstersFolder)
	end
end

local function queueHolsterReskin()
	if state.CosmeticsReskinQueued then
		return
	end
	state.CosmeticsReskinQueued = true
	task.delay(HOLSTER_APPLY_DELAY, function()
		state.CosmeticsReskinQueued = false
		if state.Destroyed then
			return
		end
		hookHolsterContainers()
		reskinAllKnownTools()
	end)
end

hookCosmeticsWatcher = function()
	local cosmeticsRoot = workspace:FindFirstChild("CharacterCosmetics")
	if not cosmeticsRoot or state.WatchedCosmeticsRoots[cosmeticsRoot] then
		return
	end
	state.WatchedCosmeticsRoots[cosmeticsRoot] = true

	connect(cosmeticsRoot.DescendantAdded, function(descendant)
		if state.Destroyed then
			return
		end
		if state.ManagedInstances[descendant] or isSkinChangerManagedInstance(descendant) then
			return
		end

		local ownedFolder = getOwnedCosmeticsFolder()
		if descendant.Name == tostring(LOCAL_PLAYER.UserId) .. "_Cosmetics" or (descendant.Name == "ClientHolstersFolder" and ownedFolder and descendant:IsDescendantOf(ownedFolder)) then
			queueHolsterReskin()
		end
	end)
end

function state.Uninject()
	if state.Destroyed then
		return
	end
	state.Destroyed = true

	local backpack, character = getToolContainers()
	local containers = { backpack, character }
	for _, container in ipairs(containers) do
		if container then
			for _, descendant in ipairs(container:GetDescendants()) do
				if descendant:IsA("Tool") then
					resetTool(descendant)
				end
			end
		end
	end
	for instance, data in pairs(state.Originals) do
		if typeof(instance) == "Instance" then
			restoreTrackedInstance(instance, data)
		end
	end

	for _, connection in ipairs(state.Connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	clearArray(state.Connections)
	clearMap(state.ActiveSkins)
	clearMap(rawActiveSkins)
	clearMap(state.PendingTools)
	clearMap(state.ApplyingTools)
	clearMap(state.HookedContainers)
	clearMap(state.WatchedCosmeticsRoots)
	state.CosmeticsReskinQueued = false

	if state.MouseIconBeforeOpen ~= nil then
		UserInputService.MouseIconEnabled = state.MouseIconBeforeOpen
	end
	if state.MouseBehaviorBeforeOpen ~= nil then
		UserInputService.MouseBehavior = state.MouseBehaviorBeforeOpen
	end

	if state.Gui then
		state.Gui:Destroy()
		state.Gui = nil
	end
	if controllerFolder then
		controllerFolder:Destroy()
	end
	_G[GLOBAL_KEY] = nil
end

local activeSkinsFolder = Instance.new("Folder")
activeSkinsFolder.Name = "ActiveSkins"
activeSkinsFolder.Parent = controllerFolder

rawActiveSkins = state.ActiveSkins
state.ActiveSkins = setmetatable({}, {
	__index = rawActiveSkins,
	__newindex = function(_, key, value)
		rawActiveSkins[key] = value
		updateMirror(key)
	end,
})

local uninjectFunction = Instance.new("BindableFunction")
uninjectFunction.Name = "Uninject"
uninjectFunction.OnInvoke = function()
	state.Uninject()
	return true
end
uninjectFunction.Parent = controllerFolder

local applySkinFunction = Instance.new("BindableFunction")
applySkinFunction.Name = "ApplySkin"
applySkinFunction.OnInvoke = function(toolName, skinId)
	local tool = getToolByName(toolName)
	local skin = findSkin(toolName, skinId)
	if not tool or not skin then
		return false
	end
	local selection = encodeCatalog(skinId)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	refreshUi()
	return true
end
applySkinFunction.Parent = controllerFolder

local applyColorFunction = Instance.new("BindableFunction")
applyColorFunction.Name = "ApplyColor"
applyColorFunction.OnInvoke = function(toolName, colorText)
	if not toolName or toolName == "" then
		toolName = currentToolName()
	end
	local color = parseHex(colorText)
	if not color and type(colorText) == "table" then
		color = Color3.fromRGB(colorText.R or colorText[1] or 255, colorText.G or colorText[2] or 255, colorText.B or colorText[3] or 255)
	end
	if not toolName or not color then
		return false
	end
	state.CustomColor = color
	local selection = encodeColor(color)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	refreshUi()
	return true
end
applyColorFunction.Parent = controllerFolder

local applyDecalFunction = Instance.new("BindableFunction")
applyDecalFunction.Name = "ApplyDecal"
applyDecalFunction.OnInvoke = function(toolName, assetId, faceName)
	if not toolName or toolName == "" then
		toolName = currentToolName()
	end
	local normalized = normalizeAssetId(assetId)
	if not toolName or normalized == "" then
		return false
	end
	state.CustomDecalAsset = normalized
	state.CustomDecalFace = faceName or "All"
	local selection = encodeDecal(normalized, state.CustomDecalFace)
	applySelectionToToolName(toolName, selection)
	reskinAllKnownTools()
	refreshUi()
	return true
end
applyDecalFunction.Parent = controllerFolder

local resetSkinFunction = Instance.new("BindableFunction")
resetSkinFunction.Name = "ResetSkin"
resetSkinFunction.OnInvoke = function(toolName)
	if not toolName or toolName == "" then
		toolName = currentToolName()
	end
	if not toolName then
		return false
	end
	resetToolName(toolName)
	refreshUi()
	return true
end
resetSkinFunction.Parent = controllerFolder

local toggleFunction = Instance.new("BindableFunction")
toggleFunction.Name = "ToggleUi"
toggleFunction.OnInvoke = function(visible)
	if visible == nil then
		setVisible(not state.Visible)
	else
		setVisible(visible == true)
	end
	return state.Visible
end
toggleFunction.Parent = controllerFolder

local getStatusFunction = Instance.new("BindableFunction")
getStatusFunction.Name = "GetStatus"
getStatusFunction.OnInvoke = function()
	local tool = getCurrentTool()
	return {
		Ready = controllerFolder:GetAttribute("Ready") == true,
		CurrentToolName = tool and tool.Name or "",
		ConnectionCount = #state.Connections,
		SkinCount = tool and countSkins(tool.Name) or 0,
		Destroyed = state.Destroyed,
		Visible = state.Visible,
		CurrentTab = state.CurrentTab,
	}
end
getStatusFunction.Parent = controllerFolder

controllerFolder:SetAttribute("Ready", false)
controllerFolder:SetAttribute("CurrentToolName", "")
controllerFolder:SetAttribute("ConnectionCount", 0)
controllerFolder:SetAttribute("Visible", false)
controllerFolder:SetAttribute("SkinCount", 0)

buildGui()
setVisible(true)
hookContainer(LOCAL_PLAYER:WaitForChild("Backpack"))
hookCosmeticsWatcher()
hookHolsterContainers()
if LOCAL_PLAYER.Character then
	hookCharacter(LOCAL_PLAYER.Character)
end
connect(LOCAL_PLAYER.CharacterAdded, hookCharacter)
connect(LOCAL_PLAYER:GetPropertyChangedSignal("Character"), function()
	task.defer(hookHolsterContainers)
	task.defer(refreshUi)
end)
connect(workspace.ChildAdded, function(child)
	if child.Name == "CharacterCosmetics" then
		task.defer(function()
			hookCosmeticsWatcher()
			hookHolsterContainers()
			reskinAllKnownTools()
		end)
	end
end)
connect(UserInputService.InputBegan, function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.RightShift then
		setVisible(not state.Visible)
	end
end)
connect(RunService.RenderStepped, function()
	if state.Visible and ui.CustomCursor then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		updateCustomCursorPosition()
	end
end)

task.defer(function()
	reskinAllKnownTools()
	refreshUi()
	controllerFolder:SetAttribute("Ready", true)
	controllerFolder:SetAttribute("ConnectionCount", #state.Connections)
end)

task.spawn(function()
	while not state.Destroyed do
		local toolName = state.CurrentToolName or ""
		if controllerFolder.Parent then
			controllerFolder:SetAttribute("CurrentToolName", toolName)
			controllerFolder:SetAttribute("ConnectionCount", #state.Connections)
			controllerFolder:SetAttribute("SkinCount", countSkins(toolName))
			controllerFolder:SetAttribute("Visible", state.Visible)
		end
		task.wait(0.5)
	end
end)

_G[GLOBAL_KEY] = state

print("[CodexSkinChanger] Client weapon skin changer injected. Press RightShift to toggle.")
