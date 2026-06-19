-- ModuleScript: ServerScriptService > ShopManager
-- Handles shop purchases. Server-only.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))
local InventoryManager  = require(ServerScriptService.InventoryManager)
local CurrencyManager   = require(ServerScriptService.CurrencyManager)
local GameState         = require(ServerScriptService.GameState)
local ArmorManager      = require(ServerScriptService.ArmorManager)

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

-- Returns success (bool), message (string), equippedArmorId (string or nil)
function ShopManager.purchase(player, itemId)
	local entry = getCatalogEntry(itemId)
	if not entry then
		return false, "Unknown item.", nil
	end

	local balance = CurrencyManager.get(player)
	if balance < entry.cost then
		return false, string.format("Need %d coins (have %d).", entry.cost, balance), nil
	end

	-- Deduct currency
	CurrencyManager.deduct(player, entry.cost)

	if entry.itemType == "armor" then
		-- Auto-equip armor immediately (don't add to block inventory)
		ArmorManager.equip(player, entry.id)
		return true, string.format("Equipped %s! (+%d HP)", entry.id,
			ArmorManager.getBonusHP(player)), entry.id
	else
		-- Add blocks to inventory
		local inv = InventoryManager.get(player)
		if inv then
			inv[entry.id] = (inv[entry.id] or 0) + entry.amount
		end
		return true, string.format("Bought %dx %s!", entry.amount, entry.id), nil
	end
end

-- Wires up the PurchaseItem RemoteEvent (called once from GameServer)
function ShopManager.init(remoteEvents, updateInventory, updateCurrency)
	local PurchaseItem = remoteEvents:WaitForChild("PurchaseItem")
	local ShopResponse = remoteEvents:WaitForChild("ShopResponse")

	local ArmorEquipped = remoteEvents:WaitForChild("ArmorEquipped")

	PurchaseItem.OnServerEvent:Connect(function(player, itemId)
		if type(itemId) ~= "string" then return end
		local st = GameState.current
		if st ~= "SETUP" and st ~= "PLAYING" then return end
		local ok, msg, equippedArmorId = ShopManager.purchase(player, itemId)
		-- Sync inventory and currency to client
		updateInventory:FireClient(player, InventoryManager.get(player))
		updateCurrency:FireClient(player, CurrencyManager.get(player))
		ShopResponse:FireClient(player, ok, msg)
		-- Notify client of armor equip so HUD updates
		if ok and equippedArmorId then
			ArmorEquipped:FireClient(player, equippedArmorId, ArmorManager.getBonusHP(player))
		end
	end)
end

return ShopManager
