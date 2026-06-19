-- ModuleScript: ServerScriptService > InventoryManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local InventoryManager = {}
local inventories = {}  -- [Player] = { blockId = count, ... }

-- Called at round start and when a player joins mid-lobby
function InventoryManager.reset(player)
	inventories[player] = {}
	for id, count in pairs(GameConfig.STARTING_INVENTORY) do
		inventories[player][id] = count
	end
	-- Seed armor slots at 0
	for _, armorDef in ipairs(GameConfig.ARMOR_TYPES or {}) do
		inventories[player][armorDef.id] = inventories[player][armorDef.id] or 0
	end
end

function InventoryManager.get(player)
	return inventories[player] or {}
end

-- Returns true and decrements if the player has >= amount of blockId
function InventoryManager.deduct(player, blockId, amount)
	amount = amount or 1
	local inv = inventories[player]
	if not inv then return false end
	if (inv[blockId] or 0) < amount then return false end
	inv[blockId] -= amount
	return true
end

-- Refund blocks (on remove; gives back floor(amount * 0.5))
function InventoryManager.refund(player, blockId, amount)
	amount = amount or 1
	local inv = inventories[player]
	if not inv then return end
	inv[blockId] = (inv[blockId] or 0) + math.floor(amount * 0.5)
end

-- Drop approximately `rate` fraction of total items, chosen randomly across types
function InventoryManager.loseRandom(player, rate)
	local inv = inventories[player]
	if not inv then return end

	local totalItems = 0
	for _, count in pairs(inv) do totalItems += count end

	local toRemove = math.floor(totalItems * rate)
	for _ = 1, toRemove do
		local available = {}
		for id, count in pairs(inv) do
			if count > 0 then table.insert(available, id) end
		end
		if #available == 0 then break end
		local chosen = available[math.random(1, #available)]
		inv[chosen] -= 1
	end
end

function InventoryManager.clear(player)
	inventories[player] = nil
end

return InventoryManager
