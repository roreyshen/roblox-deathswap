-- Script: ServerScriptService > PlacementHandler
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig       = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MapManager       = require(ReplicatedStorage:WaitForChild("MapManager"))
local InventoryManager = require(ServerScriptService.InventoryManager)
local GameState        = require(ServerScriptService.GameState)
local AnchorManager    = require(ServerScriptService.AnchorManager)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceBlock       = RemoteEvents:WaitForChild("PlaceBlock")
local RemoveBlock      = RemoteEvents:WaitForChild("RemoveBlock")
local UpdateInventory  = RemoteEvents:WaitForChild("UpdateInventory")
local PlaceAnchor      = RemoteEvents:WaitForChild("PlaceAnchor")
local MineAnchor       = RemoteEvents:WaitForChild("MineAnchor")
local AnchorDestroyed  = RemoteEvents:WaitForChild("AnchorDestroyed")
local AnchorHealthUpdate = RemoteEvents:WaitForChild("AnchorHealthUpdate")

local GRID = GameConfig.GRID_SIZE

-- ========== Helpers ==========

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

	if blockDef.damagePer  then attachLavaDamage(part, blockDef.damagePer)      end
	if blockDef.damageOnce then attachSpikeDamage(part, blockDef.damageOnce)    end
	if blockDef.explode    then attachTNT(part)                                  end

	UpdateInventory:FireClient(player, InventoryManager.get(player))
end)

-- ========== Block removal (SETUP + PLAYING) ==========

RemoveBlock.OnServerEvent:Connect(function(player, targetPart)
	local state = GameState.current
	if state ~= "PLAYING" and state ~= "SETUP" then return end
	if not targetPart or not targetPart:IsA("BasePart") then return end
	if targetPart:GetAttribute("IsAnchor") then return end  -- use MineAnchor for crystals

	local buildsFolder = MapManager.getBuildsFolder()
	if not buildsFolder then return end
	if not targetPart:IsDescendantOf(buildsFolder) then return end

	local root = getRoot(player)
	if not root then return end
	if (targetPart.Position - root.Position).Magnitude > GameConfig.PLACE_RANGE + 2 then return end

	InventoryManager.refund(player, targetPart.Name, 1)
	targetPart:Destroy()

	UpdateInventory:FireClient(player, InventoryManager.get(player))
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
		-- Find the owner's display name
		local ownerName = "Unknown"
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == ownerUserId then ownerName = p.Name; break end
		end
		AnchorDestroyed:FireAllClients(ownerUserId, ownerName)
	end
end)
