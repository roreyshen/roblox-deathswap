-- ModuleScript: ServerScriptService > ShopManager
-- Handles shop purchases. Server-only.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))
local InventoryManager  = require(ServerScriptService.InventoryManager)
local CurrencyManager   = require(ServerScriptService.CurrencyManager)
local GameState         = require(ServerScriptService.GameState)

local ShopManager = {}

-- Catalog: each entry is {id, itemType ("block"|"armor"), cost, amount}
ShopManager.CATALOG = {
	{ id = "Wood",     itemType = "block", cost = 10,  amount = 10 },
	{ id = "Stone",    itemType = "block", cost = 15,  amount = 10 },
	{ id = "Obsidian", itemType = "block", cost = 10,  amount = 5  },
	{ id = "Leather",  itemType = "armor", cost = 50,  amount = 1  },
	{ id = "Iron",     itemType = "armor", cost = 120, amount = 1  },
}

local function getCatalogEntry(itemId)
	for _, entry in ipairs(ShopManager.CATALOG) do
		if entry.id == itemId then return entry end
	end
	return nil
end

-- Returns success (bool), message (string)
function ShopManager.purchase(player, itemId)
	local entry = getCatalogEntry(itemId)
	if not entry then
		return false, "Unknown item."
	end

	local balance = CurrencyManager.get(player)
	if balance < entry.cost then
		return false, string.format("Need %d coins (have %d).", entry.cost, balance)
	end

	-- Deduct currency
	CurrencyManager.deduct(player, entry.cost)

	-- Add to inventory
	local inv = InventoryManager.get(player)
	if inv then
		inv[entry.id] = (inv[entry.id] or 0) + entry.amount
	end

	return true, string.format("Bought %dx %s!", entry.amount, entry.id)
end

-- Wires up the PurchaseItem RemoteEvent (called once from GameServer)
function ShopManager.init(remoteEvents, updateInventory, updateCurrency)
	local PurchaseItem = remoteEvents:WaitForChild("PurchaseItem")
	local ShopResponse = remoteEvents:WaitForChild("ShopResponse")

	PurchaseItem.OnServerEvent:Connect(function(player, itemId)
		if type(itemId) ~= "string" then return end
		local st = GameState.current
		if st ~= "SETUP" and st ~= "PLAYING" then return end
		local ok, msg = ShopManager.purchase(player, itemId)
		-- Sync inventory and currency to client
		updateInventory:FireClient(player, InventoryManager.get(player))
		updateCurrency:FireClient(player, CurrencyManager.get(player))
		ShopResponse:FireClient(player, ok, msg)
	end)
end

return ShopManager
