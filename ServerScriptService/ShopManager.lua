-- ModuleScript: ServerScriptService > ShopManager
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))
local InventoryManager  = require(ServerScriptService.InventoryManager)
local CurrencyManager   = require(ServerScriptService.CurrencyManager)
local GameState         = require(ServerScriptService.GameState)
local ArmorManager      = require(ServerScriptService.ArmorManager)
local ToolManager       = require(ServerScriptService.ToolManager)

local ShopManager = {}

-- itemType: "block" | "armor" | "sword" | "pickaxe"
ShopManager.CATALOG = {
	{ id = "Wood",     itemType = "block",   cost = 10,  amount = 10 },
	{ id = "Stone",    itemType = "block",   cost = 15,  amount = 10 },
	{ id = "Obsidian", itemType = "block",   cost = 10,  amount = 5  },
	{ id = "Leather",  itemType = "armor",   cost = 50,  amount = 1  },
	{ id = "Iron",     itemType = "armor",   cost = 120, amount = 1  },
	{ id = "Stone",    itemType = "sword",   cost = 75,  amount = 1  },
	{ id = "Stone",    itemType = "pickaxe", cost = 75,  amount = 1  },
	{ id = "Iron",     itemType = "sword",   cost = 150, amount = 1  },
	{ id = "Iron",     itemType = "pickaxe", cost = 150, amount = 1  },
}

local function getCatalogEntry(itemId, itemType)
	for _, entry in ipairs(ShopManager.CATALOG) do
		local typeMatch = (itemType == nil) or (entry.itemType == itemType)
		if entry.id == itemId and typeMatch then return entry end
	end
	return nil
end

function ShopManager.purchase(player, itemId, itemType)
	-- itemType is optional for backwards-compat; blocks are found by id alone
	local entry = getCatalogEntry(itemId, itemType)
	if not entry then return false, "Unknown item.", nil end

	local balance = CurrencyManager.get(player)
	if balance < entry.cost then
		return false, string.format("Need %d coins (have %d).", entry.cost, balance), nil
	end

	CurrencyManager.deduct(player, entry.cost)

	if entry.itemType == "armor" then
		ArmorManager.equip(player, entry.id)
		local pct = math.floor(ArmorManager.getReduction(player) * 100)
		return true, string.format("Equipped %s! (%d%% DR)", entry.id, pct), entry.id

	elseif entry.itemType == "sword" then
		ToolManager.giveWeapons(player, entry.id, nil)
		return true, string.format("Equipped %s Sword!", entry.id), nil

	elseif entry.itemType == "pickaxe" then
		ToolManager.giveWeapons(player, nil, entry.id)
		return true, string.format("Equipped %s Pickaxe!", entry.id), nil

	else
		local inv = InventoryManager.get(player)
		if inv then
			inv[entry.id] = (inv[entry.id] or 0) + entry.amount
		end
		return true, string.format("Bought %dx %s!", entry.amount, entry.id), nil
	end
end

function ShopManager.init(remoteEvents, updateInventory, updateCurrency)
	local PurchaseItem  = remoteEvents:WaitForChild("PurchaseItem")
	local ShopResponse  = remoteEvents:WaitForChild("ShopResponse")
	local ArmorEquipped = remoteEvents:WaitForChild("ArmorEquipped")

	PurchaseItem.OnServerEvent:Connect(function(player, itemId, itemType)
		if type(itemId) ~= "string" then return end
		local st = GameState.current
		if st ~= "SETUP" and st ~= "PLAYING" then return end
		local ok, msg, equippedArmorId = ShopManager.purchase(player, itemId, itemType)
		updateInventory:FireClient(player, InventoryManager.get(player))
		updateCurrency:FireClient(player, CurrencyManager.get(player))
		ShopResponse:FireClient(player, ok, msg)
		if ok and equippedArmorId then
			ArmorEquipped:FireClient(player, equippedArmorId, ArmorManager.getReduction(player))
		end
	end)
end

return ShopManager
