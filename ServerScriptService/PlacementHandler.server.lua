-- Script: ServerScriptService > PlacementHandler
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig       = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MapManager       = require(ReplicatedStorage:WaitForChild("MapManager"))
local InventoryManager = require(ServerScriptService.InventoryManager)
local GameState        = require(ServerScriptService.GameState)
local AnchorManager    = require(ServerScriptService.AnchorManager)
local ToolManager      = require(ServerScriptService.ToolManager)
local GemManager       = require(ServerScriptService.GemManager)
local RoundStats       = require(ServerScriptService.RoundStats)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceBlock       = RemoteEvents:WaitForChild("PlaceBlock")
local RemoveBlock      = RemoteEvents:WaitForChild("RemoveBlock")
local UpdateInventory  = RemoteEvents:WaitForChild("UpdateInventory")
local PlaceAnchor      = RemoteEvents:WaitForChild("PlaceAnchor")
local MineAnchor       = RemoteEvents:WaitForChild("MineAnchor")
local AnchorDestroyed  = RemoteEvents:WaitForChild("AnchorDestroyed")
local AnchorHealthUpdate = RemoteEvents:WaitForChild("AnchorHealthUpdate")
local UpdateGems       = RemoteEvents:WaitForChild("UpdateGems")

local GRID       = GameConfig.GRID_SIZE
local RADIUS     = GameConfig.ISLAND_RADIUS or 100
-- Max Y players can place blocks (surface Y + height limit)
local MAX_PLACE_Y = GameConfig.ISLAND_Y + GameConfig.GRID_SIZE * 4 + (GameConfig.PLACE_HEIGHT_LIMIT or 40)

-- ========== Helpers ==========

local function snapToGrid(pos)
	local HALF = GRID / 2
	return Vector3.new(
		math.round(pos.X / GRID) * GRID,
		math.round((pos.Y - HALF) / GRID) * GRID + HALF,
		math.round(pos.Z / GRID) * GRID
	)
end

local function getBlockDef(blockId)
	for _, def in ipairs(GameConfig.BLOCK_TYPES) do
		if def.id == blockId then return def end
	end
	return nil
end

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

local function getRoot(player)
	local char = player.Character
	if not char or not char.Parent then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

-- ========== Damage behaviours ==========

local function attachLavaDamage(part, dps)
	local touching = {}
	part.Touched:Connect(function(hit)
		local char = hit.Parent
		if char and char:FindFirstChildOfClass("Humanoid") then touching[char] = true end
	end)
	part.TouchEnded:Connect(function(hit) touching[hit.Parent] = nil end)

	task.spawn(function()
		while part and part.Parent do
			for char in pairs(touching) do
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then hum:TakeDamage(dps / 10) end
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
		if hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") then
			triggered = true
			local explosion          = Instance.new("Explosion")
			explosion.Position       = part.Position
			explosion.BlastRadius    = 10
			explosion.BlastPressure  = 500000
			explosion.Parent         = workspace
			part:Destroy()
		end
	end)
end

-- ========== Block placement (SETUP + PLAYING) ==========

PlaceBlock.OnServerEvent:Connect(function(player, clientPos, blockId)
	local state = GameState.current
	if state ~= "PLAYING" and state ~= "SETUP" then return end

	local blockDef = getBlockDef(blockId)
	if not blockDef then return end

	local root = getRoot(player)
	if not root then return end

	if typeof(clientPos) ~= "Vector3" then return end
	local snapped = snapToGrid(clientPos)

	if (snapped - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	-- Height and radius limits
	if snapped.Y > MAX_PLACE_Y then return end
	if snapped.X * snapped.X + snapped.Z * snapped.Z > RADIUS * RADIUS then return end

	if not isClear(snapped) then return end
	if not InventoryManager.deduct(player, blockId) then return end

	local part = Instance.new("Part")
	part.Name       = blockId
	part.Size       = Vector3.new(GRID, GRID, GRID)
	part.CFrame     = CFrame.new(snapped)
	part.Anchored   = true
	part.Material   = blockDef.material
	part.Color      = blockDef.color
	part.CastShadow = true
	part.Parent     = MapManager.getBuildsFolder()

	-- Track who placed this block and its max HP
	local maxHp = (GameConfig.BLOCK_HP and GameConfig.BLOCK_HP[blockId]) or 1
	part:SetAttribute("PlacedBy", player.UserId)
	part:SetAttribute("HP",       maxHp)
	part:SetAttribute("MaxHP",    maxHp)

	if blockDef.damagePer  then attachLavaDamage(part, blockDef.damagePer)      end
	if blockDef.damageOnce then attachSpikeDamage(part, blockDef.damageOnce)    end
	if blockDef.explode    then attachTNT(part)                                  end

	RoundStats.addBlock(player)
	UpdateInventory:FireClient(player, InventoryManager.get(player))
end)

-- ========== Block removal (SETUP + PLAYING) ==========

RemoveBlock.OnServerEvent:Connect(function(player, targetPart)
	local state = GameState.current
	if state ~= "PLAYING" and state ~= "SETUP" then return end
	if not targetPart or not targetPart:IsA("BasePart") then return end
	if targetPart:GetAttribute("IsAnchor") then return end  -- use MineAnchor for crystals
	if targetPart:GetAttribute("IsBarrier") then return end  -- perimeter barrier is indestructible
	if targetPart:GetAttribute("IsBedrock") then return end  -- bedrock is indestructible

	local root = getRoot(player)
	if not root then return end
	if (targetPart.Position - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	-- Terrain blocks (voxel island / trees) — HP-based, drop into inventory on destroy
	if targetPart:GetAttribute("IsTerrain") then
		local mineMult = ToolManager.getMineMultiplier(player)
		local dmg = math.max(1, math.floor(mineMult))
		local hp  = (targetPart:GetAttribute("HP") or 1) - dmg
		if hp <= 0 then
			local blockId = targetPart:GetAttribute("BlockType")
			if blockId and getBlockDef(blockId) then
				InventoryManager.add(player, blockId, 1)
				UpdateInventory:FireClient(player, InventoryManager.get(player))
			end
			targetPart:Destroy()
		else
			targetPart:SetAttribute("HP", hp)
			local maxHp = targetPart:GetAttribute("MaxHP") or 1
			targetPart.Color = targetPart.Color:Lerp(Color3.fromRGB(20, 20, 20), ((maxHp - hp) / maxHp) * 0.5)
		end
		return
	end

	-- Player-placed blocks
	local buildsFolder = MapManager.getBuildsFolder()
	if not buildsFolder then return end
	if not targetPart:IsDescendantOf(buildsFolder) then return end

	local placedBy = targetPart:GetAttribute("PlacedBy")

	if placedBy == player.UserId then
		-- Own block: instant remove with 50% refund
		InventoryManager.refund(player, targetPart.Name, 1)
		targetPart:Destroy()
		UpdateInventory:FireClient(player, InventoryManager.get(player))
	else
		-- Enemy block: HP-based destruction
		local hp = (targetPart:GetAttribute("HP") or 1) - 1
		if hp <= 0 then
			targetPart:Destroy()
		else
			targetPart:SetAttribute("HP", hp)
			local maxHp = targetPart:GetAttribute("MaxHP") or 1
			local pct   = hp / maxHp
			targetPart.Color = targetPart.Color:Lerp(Color3.fromRGB(20, 20, 20), (1 - pct) * 0.4)
		end
	end
end)

-- ========== Soul Crystal placement (SETUP only) ==========

PlaceAnchor.OnServerEvent:Connect(function(player, clientPos)
	if GameState.current ~= "SETUP" then return end

	local root = getRoot(player)
	if not root then return end

	if typeof(clientPos) ~= "Vector3" then return end
	if (clientPos - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	AnchorManager.place(player, clientPos)
	-- The Part replicates automatically; no extra event needed
end)

-- ========== Soul Crystal mining (PLAYING only) ==========

MineAnchor.OnServerEvent:Connect(function(player, anchorPart)
	if GameState.current ~= "PLAYING" then return end
	if not anchorPart or not anchorPart:IsA("BasePart") then return end
	if not anchorPart:GetAttribute("IsAnchor") then return end

	local root = getRoot(player)
	if not root then return end
	if (anchorPart.Position - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	local ownerUserId = anchorPart:GetAttribute("AnchorOwner")
	if not ownerUserId then return end
	if ownerUserId == player.UserId then return end  -- can't mine own crystal

	local hp = AnchorManager.hit(player, ownerUserId)
	if hp == nil then return end  -- on cooldown or invalid

	AnchorHealthUpdate:FireAllClients(ownerUserId, hp, GameConfig.ANCHOR_MAX_HP)

	if hp == 0 then
		local ownerName = "Unknown"
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == ownerUserId then ownerName = p.Name; break end
		end
		AnchorDestroyed:FireAllClients(ownerUserId, ownerName)
		-- Award 5 gems to the player who destroyed the crystal
		local newGems = GemManager.add(player, 5)
		RoundStats.addGems(player, 5)
		UpdateGems:FireClient(player, newGems)
	end
end)
