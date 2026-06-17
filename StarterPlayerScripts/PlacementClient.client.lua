-- LocalScript: StarterPlayerScripts > PlacementClient
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceBlock    = RemoteEvents:WaitForChild("PlaceBlock")
local RemoveBlock   = RemoteEvents:WaitForChild("RemoveBlock")
local UpdateInventory = RemoteEvents:WaitForChild("UpdateInventory")
local RoundStateChanged = RemoteEvents:WaitForChild("RoundStateChanged")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local mouse     = player:GetMouse()

-- ========== State ==========

local canPlace     = false  -- only true during PLAYING
local inventory    = {}     -- mirrors server inventory
local selectedSlot = 1      -- 1-5 maps to BLOCK_TYPES index
local GRID         = GameConfig.GRID_SIZE
local BLOCK_TYPES  = GameConfig.BLOCK_TYPES

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
previewBlock.Name        = "PlacementPreview"
previewBlock.Size        = Vector3.new(GRID, GRID, GRID)
previewBlock.Anchored    = true
previewBlock.CanCollide  = false
previewBlock.CastShadow  = false
previewBlock.Transparency = 0.6
previewBlock.Material    = Enum.Material.SmoothPlastic
previewBlock.Color       = Color3.fromRGB(130, 130, 130)
previewBlock.Parent      = workspace

local function hidePreview()
	previewBlock.Transparency = 1
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

local function getPlacementTarget()
	local char = player.Character
	if not char then return nil end
	rayParams.FilterDescendantsInstances = { previewBlock, char }

	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * GameConfig.PLACE_RANGE, rayParams)
	return result
end

-- ========== Render loop ==========

RunService.RenderStepped:Connect(function()
	if not canPlace then
		hidePreview()
		return
	end

	local result = getPlacementTarget()
	if not result then
		hidePreview()
		return
	end

	local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
	previewBlock.CFrame = CFrame.new(snapped)
	previewBlock.Transparency = 0.5
end)

-- ========== Input ==========

-- Hotbar: number keys 1-5
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local numMap = {
		[Enum.KeyCode.One]   = 1,
		[Enum.KeyCode.Two]   = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four]  = 4,
		[Enum.KeyCode.Five]  = 5,
	}
	local slot = numMap[input.KeyCode]
	if slot then
		selectedSlot = slot
		updatePreviewBlock()
		-- Fire a BindableEvent or update the UI module directly
		-- UIController listens to UpdateInventory which carries full inventory, so
		-- we broadcast the selection change via a BindableEvent stored in LocalPlayer
		local selChanged = player:FindFirstChild("SelectedSlotChanged")
		if selChanged then selChanged:Fire(selectedSlot) end
		return
	end
end)

-- Left-click: place block
mouse.Button1Down:Connect(function()
	if not canPlace then return end

	local blockDef = BLOCK_TYPES[selectedSlot]
	if not blockDef then return end
	if (inventory[blockDef.id] or 0) <= 0 then return end

	local result = getPlacementTarget()
	if not result then return end

	local snapped = snapToGrid(result.Position + result.Normal * (GRID / 2))
	PlaceBlock:FireServer(snapped, blockDef.id)
end)

-- Right-click or E: remove block
local function tryRemove()
	if not canPlace then return end
	local result = getPlacementTarget()
	if not result then return end
	local target = result.Instance
	if target and target:IsA("BasePart") then
		RemoveBlock:FireServer(target)
	end
end

mouse.Button2Down:Connect(tryRemove)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryRemove()
	end
end)

-- ========== Remote listeners ==========

RoundStateChanged.OnClientEvent:Connect(function(state)
	canPlace = (state == "PLAYING")
	if not canPlace then
		hidePreview()
	end
end)

UpdateInventory.OnClientEvent:Connect(function(inv)
	inventory = inv
	-- Fire a BindableEvent so UIController can update the hotbar without coupling
	local invChanged = player:FindFirstChild("InventoryChanged")
	if invChanged then invChanged:Fire(inv) end
end)

-- ========== Slot-changed BindableEvent (created here so UIController can connect) ==========

local slotEvent = Instance.new("BindableEvent")
slotEvent.Name   = "SelectedSlotChanged"
slotEvent.Parent = player

local invEvent = Instance.new("BindableEvent")
invEvent.Name   = "InventoryChanged"
invEvent.Parent = player
