-- Script: ServerScriptService > PlacementHandler
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")

local GameConfig       = require(ReplicatedStorage.Modules.GameConfig)
local MapManager       = require(ReplicatedStorage.Modules.MapManager)
local InventoryManager = require(ServerScriptService.InventoryManager)
local GameState        = require(ServerScriptService.GameState)

local RemoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceBlock      = RemoteEvents:WaitForChild("PlaceBlock")
local RemoveBlock     = RemoteEvents:WaitForChild("RemoveBlock")
local UpdateInventory = RemoteEvents:WaitForChild("UpdateInventory")

-- ========== Helpers ==========

local GRID = GameConfig.GRID_SIZE

local function snapToGrid(pos)
	return Vector3.new(
		math.round(pos.X / GRID) * GRID,
		math.round(pos.Y / GRID) * GRID,
		math.round(pos.Z / GRID) * GRID
	)
end

local function getBlockDef(blockId)
	for _, def in ipairs(GameConfig.BLOCK_TYPES) do
		if def.id == blockId then return def end
	end
	return nil
end

-- Check no existing part overlaps a given position (returns true if clear)
local function isClear(position)
	local halfSize = Vector3.new(GRID, GRID, GRID) * 0.49
	local parts = workspace:GetPartBoundsInBox(CFrame.new(position), halfSize * 2)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide then
			return false
		end
	end
	return true
end

-- ========== Damage behaviours ==========

local function attachLavaDamage(part, dps)
	local touching = {}

	part.Touched:Connect(function(hit)
		local char = hit.Parent
		if char and char:FindFirstChildOfClass("Humanoid") then
			touching[char] = true
		end
	end)
	part.TouchEnded:Connect(function(hit)
		touching[hit.Parent] = nil
	end)

	task.spawn(function()
		while part and part.Parent do
			for char in pairs(touching) do
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum:TakeDamage(dps / 10)  -- called every 0.1s → dps per second
				end
			end
			task.wait(0.1)
		end
	end)
end

local function attachSpikeDamage(part, damage)
	local debounce = {}

	part.Touched:Connect(function(hit)
		local char = hit.Parent
		if debounce[char] then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			debounce[char] = true
			hum:TakeDamage(damage)
			task.delay(1, function() debounce[char] = nil end)
		end
	end)
end

local function attachTNT(part)
	local triggered = false

	part.Touched:Connect(function(hit)
		if triggered then return end
		local char = hit.Parent
		if char and char:FindFirstChildOfClass("Humanoid") then
			triggered = true
			local explosion = Instance.new("Explosion")
			explosion.Position    = part.Position
			explosion.BlastRadius = 10
			explosion.BlastPressure = 500000
			explosion.Parent = workspace
			part:Destroy()
		end
	end)
end

-- ========== Block placement ==========

PlaceBlock.OnServerEvent:Connect(function(player, clientPos, blockId)
	-- Only allow during an active round
	if GameState.current ~= "PLAYING" then return end

	local blockDef = getBlockDef(blockId)
	if not blockDef then return end

	-- Validate player character exists
	local char = player.Character
	if not char or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Server-side snap (never trust the client's exact value)
	if typeof(clientPos) ~= "Vector3" then return end
	local snapped = snapToGrid(clientPos)

	-- Distance check
	if (snapped - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	-- Overlap check
	if not isClear(snapped) then return end

	-- Inventory check + deduct
	if not InventoryManager.deduct(player, blockId) then return end

	-- Create the block
	local part = Instance.new("Part")
	part.Name      = blockId
	part.Size      = Vector3.new(GRID, GRID, GRID)
	part.CFrame    = CFrame.new(snapped)
	part.Anchored  = true
	part.Material  = blockDef.material
	part.Color     = blockDef.color
	part.CastShadow = true
	part.Parent    = MapManager.getBuildsFolder()

	-- Attach behaviour for trap blocks
	if blockDef.damagePer then
		attachLavaDamage(part, blockDef.damagePer)
	elseif blockDef.damageOnce then
		attachSpikeDamage(part, blockDef.damageOnce)
	elseif blockDef.explode then
		attachTNT(part)
	end

	-- Notify client of updated inventory
	UpdateInventory:FireClient(player, InventoryManager.get(player))
end)

-- ========== Block removal ==========

RemoveBlock.OnServerEvent:Connect(function(player, targetPart)
	if GameState.current ~= "PLAYING" then return end
	if not targetPart or not targetPart:IsA("BasePart") then return end

	-- Only allow removing blocks in PlayerBuilds
	local buildsFolder = MapManager.getBuildsFolder()
	if not buildsFolder then return end
	if not targetPart:IsDescendantOf(buildsFolder) then return end

	-- Distance check
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (targetPart.Position - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	-- Refund 50% and destroy
	InventoryManager.refund(player, targetPart.Name, 1)
	targetPart:Destroy()

	UpdateInventory:FireClient(player, InventoryManager.get(player))
end)
