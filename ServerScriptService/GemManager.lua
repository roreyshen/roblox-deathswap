-- ModuleScript: ServerScriptService > GemManager
-- Tracks gem balances per player. Gems are the premium currency used to unlock kits.
local GemManager = {}

local DataStoreService = game:GetService("DataStoreService")
local gemStore = DataStoreService:GetDataStore("DeathswapGems_v1")

local balances = {}  -- [Player] = number

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

game:GetService("Players").PlayerAdded:Connect(load)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	save(player)
	balances[player] = nil
end)
game:BindToClose(function()
	for player, _ in pairs(balances) do
		save(player)
	end
end)

function GemManager.get(player)
	return balances[player] or 0
end

function GemManager.add(player, amount)
	balances[player] = (balances[player] or 0) + math.max(0, amount)
	return balances[player]
end

function GemManager.set(player, amount)
	balances[player] = math.max(0, amount)
	return balances[player]
end

function GemManager.deduct(player, amount)
	local bal = balances[player] or 0
	if bal < amount then return false end
	balances[player] = bal - amount
	return true
end

function GemManager.clear(player)
	balances[player] = nil
end

return GemManager
