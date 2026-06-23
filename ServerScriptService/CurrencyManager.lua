-- ModuleScript: ServerScriptService > CurrencyManager
-- Tracks coin balances for each player. Server-only.
local CurrencyManager = {}

local balances = {}  -- [Player] = number

local COINS_PER_SECOND   = 5   -- passive income while alive in PLAYING phase
local COINS_ON_SWAP_KILL = 25  -- bonus when an opponent dies at your location during swap

function CurrencyManager.get(player)
	return balances[player] or 0
end

function CurrencyManager.add(player, amount)
	balances[player] = (balances[player] or 0) + math.max(0, amount)
	return balances[player]
end

function CurrencyManager.deduct(player, amount)
	local balance = balances[player] or 0
	if balance < amount then return false end
	balances[player] = balance - amount
	return true
end

function CurrencyManager.reset(player)
	balances[player] = 0
end

function CurrencyManager.clear(player)
	balances[player] = nil
end

function CurrencyManager.clearAll()
	balances = {}
end

CurrencyManager.COINS_PER_SECOND   = COINS_PER_SECOND
CurrencyManager.COINS_ON_SWAP_KILL = COINS_ON_SWAP_KILL

return CurrencyManager
