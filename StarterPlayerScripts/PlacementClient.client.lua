-- LocalScript: StarterPlayerScripts > PlacementClient
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceBlock        = RemoteEvents:WaitForChild("PlaceBlock")
local RemoveBlock       = RemoteEvents:WaitForChild("RemoveBlock")
local PlaceAnchor       = RemoteEvents:WaitForChild("PlaceAnchor")
local MineAnchor        = RemoteEvents:WaitForChild("MineAnchor")
local UpdateInventory   = RemoteEvents:WaitForChild("UpdateInventory")
local RoundStateChanged = RemoteEvents:WaitForChild("RoundStateChanged")

local player   = Players.LocalPlayer
local camera   = workspace.CurrentCamera
local mouse    = player:GetMouse()

-- ========== State ==========

local currentState   = "LOBBY"
local canPlace       = false   -- true during SETUP and PLAYING
local canPlaceAnchor = false   -- true during SETUP only (and only until placed)
local anchorPlaced   = false   -- once placed, F key is locked
local inventory      = {}
local selectedSlot   = 1
local GRID           = GameConfig.GRID_SIZE
local BLOCK_TYPES    = GameConfig.BLOCK_TYPES

-- ========== Grid snap ==========

local function snapToGrid(pos)
	return Vector3.new(
		math.round(pos.X / GRID) * GRID,
		math.round(pos.Y / GRID) * GRID,
		math.round(pos.Z / GRID) * GRID
	)
end

-- ========== Preview block ==========

local previewBlock = Instance.new("Part")
previewBlock.Name         = "PlacementPreview"
previewBlock.Size         = Vector3.new(GRID, GRID, GRID)
previewBlock.Anchored     = true
previewBlock.CanCollide   = false
previewBlock.CastShadow   = false
previewBlock.Transparency = 1
previewBlock.Material     = Enum.Material.SmoothPlastic
previewBlock.Color        = Color3.fromRGB(130, 130, 130)
previewBlock.Parent       = workspace

-- Crystal preview shown when aiming to place anchor
local crystalPreview = Instance.new("Part")
crystalPreview.Name         = "CrystalPreview"
crystalPreview.Size         = Vector3.new(4, 5, 4)
crystalPreview.Anchored     = true
crystalPreview.CanCollide   = false
crystalPreview.CastShadow   = false
crystalPreview.Transparency = 0.7
crystalPreview.Material     = Enum.Material.Neon
crystalPreview.Color        = Color3.fromRGB(0, 210, 255)
crystalPreview.Parent       = workspace

local function hidePreview()
	previewBlock.Transparency  = 1
	crystalPreview.Transparency = 1
end

local function updatePreviewBlock()
	local blockDef = BLOCK_TYPES[selectedSlot]
	if blockDef then
		previewBlock.Color    = blockDef.color
		previewBlock.Material = blockDef.material
	end
end

-- ========== Raycast helpers ==========

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getTarget(extraExclude)
	local char = player.Character
	if not char then return nil end
	local excludeList = { previewBlock, crystalPreview, char }
	-- Exclude merchant NPCs and test bots so they don't intercept block placement
	local map = workspace:FindFirstChild("Map")
	if map then
		local shops = map:FindFirstChild("Shops")
		if shops then table.insert(excludeList, shops) end
	end
	for _, v in ipairs(workspace:GetChildren()) do
		if v.Name == "TestBot" then table.insert(excludeList, v) end
	end
	if extraExclude then table.insert(excludeList, extraExclude) end
	rayParams.FilterDescendantsInstances = excludeList

	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	return workspace:Raycast(unitRay.Origin, unitRay.Direction * GameConfig.PLACE_RANGE, rayParams)
end

-- ========== Render loop ==========

RunService.RenderStepped:Connect(function()
	if not canPlace then
		hidePreview()
		return
	end

	-- Crystal preview when F is held-to-place or SETUP with no anchor yet
	if canPlaceAnchor and not anchorPlaced then
		local result = getTarget()
		if result then
			local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
			crystalPreview.CFrame       = CFrame.new(snapped)
			crystalPreview.Transparency = 0.65
		else
			crystalPreview.Transparency = 1
		end
		previewBlock.Transparency = 1
	else
		-- Normal block preview
		crystalPreview.Transparency = 1
		local result = getTarget()
		if result then
			local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
			previewBlock.CFrame       = CFrame.new(snapped)
			previewBlock.Transparency = 0.5
		else
			previewBlock.Transparency = 1
		end
	end
end)

-- ========== Input ==========

-- Number keys: switch hotbar slot
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	local numMap = {
		[Enum.KeyCode.One]   = 1,
		[Enum.KeyCode.Two]   = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four]  = 4,
		[Enum.KeyCode.Five]  = 5,
		[Enum.KeyCode.Six]   = 6,
	}
	local slot = numMap[input.KeyCode]
	if slot then
		selectedSlot = slot
		updatePreviewBlock()
		local selChanged = player:FindFirstChild("SelectedSlotChanged")
		if selChanged then selChanged:Fire(selectedSlot) end
	end
end)

-- Left-click: place block OR place anchor (SETUP)
-- Using InputBegan so clicks on GUI elements (inventory slots) are ignored
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end  -- skip if clicking a GUI element
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not canPlace then return end

	if canPlaceAnchor and not anchorPlaced then
		-- Place Soul Crystal at aim position
		local result = getTarget()
		if not result then return end
		local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
		PlaceAnchor:FireServer(snapped)
		anchorPlaced   = true
		canPlaceAnchor = false

		-- Tell UIController anchor is placed
		local anchorEvent = player:FindFirstChild("AnchorStatusChanged")
		if anchorEvent then anchorEvent:Fire("placed") end
		return
	end

	-- Normal block placement
	local blockDef = BLOCK_TYPES[selectedSlot]
	if not blockDef then return end
	if (inventory[blockDef.id] or 0) <= 0 then return end

	local result = getTarget()
	if not result then return end
	local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
	PlaceBlock:FireServer(snapped, blockDef.id)
end)

-- Right-click / E: remove block or mine anchor
local function tryInteract()
	if not canPlace then return end

	local result = getTarget()
	if not result then return end
	local target = result.Instance
	if not target or not target:IsA("BasePart") then return end

	if target:GetAttribute("IsAnchor") then
		-- Mine the crystal (only during PLAYING)
		if currentState == "PLAYING" then
			MineAnchor:FireServer(target)
		end
	else
		-- Remove block (refund 50%)
		RemoveBlock:FireServer(target)
	end
end

mouse.Button2Down:Connect(tryInteract)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryInteract()
	end
end)

-- ========== Remote listeners ==========

RoundStateChanged.OnClientEvent:Connect(function(state)
	currentState   = state
	canPlace       = (state == "PLAYING" or state == "SETUP")
	canPlaceAnchor = (state == "SETUP") and not anchorPlaced

	if state == "SETUP" then
		anchorPlaced = false  -- reset for new round
		canPlaceAnchor = true
	end

	if not canPlace then hidePreview() end
end)

UpdateInventory.OnClientEvent:Connect(function(inv)
	inventory = inv
	local invChanged = player:FindFirstChild("InventoryChanged")
	if invChanged then invChanged:Fire(inv) end
end)

-- ========== BindableEvents for UIController ==========

local slotEvent = Instance.new("BindableEvent")
slotEvent.Name   = "SelectedSlotChanged"
slotEvent.Parent = player

local invEvent = Instance.new("BindableEvent")
invEvent.Name   = "InventoryChanged"
invEvent.Parent = player

local anchorStatusEvent = Instance.new("BindableEvent")
anchorStatusEvent.Name   = "AnchorStatusChanged"
anchorStatusEvent.Parent = player

-- UIController fires this when player clicks an inventory slot
local selectSlotEvent = Instance.new("BindableEvent")
selectSlotEvent.Name   = "SelectSlot"
selectSlotEvent.Parent = player

selectSlotEvent.Event:Connect(function(slot)
	selectedSlot = slot
	updatePreviewBlock()
	local selChanged = player:FindFirstChild("SelectedSlotChanged")
	if selChanged then selChanged:Fire(selectedSlot) end
end)
