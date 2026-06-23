-- Same DataStore as the game ("DeathswapGems_v1") so gems are shared across both places
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local GemManager = {}
local gemStore   = DataStoreService:GetDataStore("DeathswapGems_v1")
local balances   = {}  -- [Player] = number

local function load(player)
	local ok, val = pcall(function()
		return gemStore:GetAsync("gem_" .. player.UserId)
	end)
	balances[player] = (ok and type(val) == "number" and val) or 0
end

local function save(player)
	pcall(function()
		gemStore:SetAsync("gem_" .. player.UserId, balances[player] or 0)
	end)
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	balances[player] = nil
end)
game:BindToClose(function()
	for player in pairs(balances) do save(player) end
end)

function GemManager.get(player)    return balances[player] or 0 end
function GemManager.deduct(player, amount)
	local bal = balances[player] or 0
	if bal < amount then return false end
	balances[player] = bal - amount
	return true
end

return GemManager
