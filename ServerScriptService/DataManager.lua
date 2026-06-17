-- ModuleScript: ServerScriptService > DataManager
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}
local store = DataStoreService:GetDataStore("DeathswapStats_v1")
local cache = {}  -- [Player] = { wins=0, losses=0 }

local function loadData(player)
	local key = "player_" .. player.UserId
	local success, data = pcall(function()
		return store:GetAsync(key)
	end)
	cache[player] = (success and data) or { wins = 0, losses = 0 }
end

local function saveData(player)
	local key = "player_" .. player.UserId
	local data = cache[player]
	if not data then return end
	pcall(function()
		store:UpdateAsync(key, function(old)
			old = old or { wins = 0, losses = 0 }
			old.wins   = data.wins
			old.losses = data.losses
			return old
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	loadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	cache[player] = nil
end)

game:BindToClose(function()
	for player in pairs(cache) do
		saveData(player)
	end
end)

function DataManager.recordWin(player)
	if cache[player] then
		cache[player].wins += 1
	end
end

function DataManager.recordLoss(player)
	if cache[player] then
		cache[player].losses += 1
	end
end

function DataManager.getStats(player)
	return cache[player] or { wins = 0, losses = 0 }
end

return DataManager
