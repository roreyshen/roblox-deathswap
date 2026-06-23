-- Shared DataStore "DeathswapKit_v1" so kit choice persists into the game place
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local KitManager = {}
local kitStore   = DataStoreService:GetDataStore("DeathswapKit_v1")

local KIT_DEFS = {
	Speed   = { id = "Speed",   cost = 100, desc = "+15% Move Speed"  },
	Jump    = { id = "Jump",    cost = 100, desc = "+20% Jump Power"  },
	Miner   = { id = "Miner",   cost = 100, desc = "+50% Mine Speed"  },
	Healer  = { id = "Healer",  cost = 100, desc = "2 HP/sec Regen"   },
	Trapper = { id = "Trapper", cost = 100, desc = "+25% Trap Damage" },
}

local playerKits = {}  -- [Player] = kitId | nil

local function save(player)
	pcall(function()
		kitStore:SetAsync("kit_" .. player.UserId, playerKits[player] or "none")
	end)
end

Players.PlayerAdded:Connect(function(player)
	local ok, val = pcall(function()
		return kitStore:GetAsync("kit_" .. player.UserId)
	end)
	playerKits[player] = (ok and KIT_DEFS[val]) and val or nil
end)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	playerKits[player] = nil
end)
game:BindToClose(function()
	for player in pairs(playerKits) do save(player) end
end)

function KitManager.getDef(kitId)  return KIT_DEFS[kitId] end
function KitManager.getAll()       return KIT_DEFS end
function KitManager.getKit(player) return playerKits[player] or "none" end
function KitManager.setKit(player, kitId)
	playerKits[player] = KIT_DEFS[kitId] and kitId or nil
	save(player)
end

return KitManager
