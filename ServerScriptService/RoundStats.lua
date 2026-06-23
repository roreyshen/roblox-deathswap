-- ModuleScript: ServerScriptService > RoundStats
-- Tracks per-player stats within a round for MVP awards.
local RoundStats = {}

local stats = {}  -- [Player] = { damage=0, blocks=0, gems=0 }

local function ensure(player)
	if not stats[player] then
		stats[player] = { damage = 0, blocks = 0, gems = 0 }
	end
end

function RoundStats.reset()
	stats = {}
end

function RoundStats.addDamage(player, amount)
	ensure(player)
	stats[player].damage += amount
end

function RoundStats.addBlock(player)
	ensure(player)
	stats[player].blocks += 1
end

function RoundStats.addGems(player, amount)
	ensure(player)
	stats[player].gems += amount
end

function RoundStats.getTotalGems(player)
	return stats[player] and stats[player].gems or 0
end

function RoundStats.getMVP_Damage()
	local best, bestVal = nil, 0
	for p, s in pairs(stats) do
		if s.damage > bestVal then best, bestVal = p, s.damage end
	end
	return best
end

function RoundStats.getMVP_Blocks()
	local best, bestVal = nil, 0
	for p, s in pairs(stats) do
		if s.blocks > bestVal then best, bestVal = p, s.blocks end
	end
	return best
end

return RoundStats
