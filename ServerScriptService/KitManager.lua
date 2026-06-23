-- ModuleScript: ServerScriptService > KitManager
-- Manages player kits (passive ability loadouts). Kits cost 100 gems each.
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local kitStore = DataStoreService:GetDataStore("DeathswapKit_v1")

local KitManager = {}

local KIT_DEFS = {
	Speed   = { id = "Speed",   cost = 100, walkSpeed = 18.4 },  -- +15% (16 * 1.15)
	Jump    = { id = "Jump",    cost = 100, jumpPower = 60   },  -- +20% (50 * 1.20)
	Miner   = { id = "Miner",   cost = 100, mineBoost = 1.5  },  -- +50% mine speed
	Healer  = { id = "Healer",  cost = 100, regenRate = 2    },  -- 2 HP/sec
	Trapper = { id = "Trapper", cost = 100, trapMult  = 1.25 },  -- +25% trap damage
}

local playerKits = {}  -- [Player] = kitId or nil
local regenConns = {}  -- [Player] = Heartbeat connection for Healer

function KitManager.getDef(kitId)
	return KIT_DEFS[kitId]
end

function KitManager.getKit(player)
	return playerKits[player] or "none"
end

function KitManager.getMineBoost(player)
	local def = KIT_DEFS[playerKits[player] or ""]
	return (def and def.mineBoost) or 1
end

function KitManager.getTrapMult(player)
	local def = KIT_DEFS[playerKits[player] or ""]
	return (def and def.trapMult) or 1
end

local function stopRegen(player)
	if regenConns[player] then
		regenConns[player]:Disconnect()
		regenConns[player] = nil
	end
end

local function startRegen(player, rate)
	stopRegen(player)
	regenConns[player] = RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
			hum.Health = math.min(hum.Health + rate * dt, hum.MaxHealth)
		end
	end)
end

local function applyToChar(player)
	local kitId = playerKits[player] or "none"
	local char  = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum.WalkSpeed = 16
	hum.JumpPower = 50
	stopRegen(player)

	local def = KIT_DEFS[kitId]
	if not def then return end

	if def.walkSpeed then hum.WalkSpeed = def.walkSpeed end
	if def.jumpPower then hum.JumpPower = def.jumpPower end
	if def.regenRate then startRegen(player, def.regenRate) end
end

function KitManager.setKit(player, kitId)
	playerKits[player] = (KIT_DEFS[kitId] and kitId) or nil
	applyToChar(player)
end

function KitManager.reapply(player)
	applyToChar(player)
end

function KitManager.clearPlayer(player)
	stopRegen(player)
	playerKits[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	-- Load kit chosen in the lobby
	local ok, val = pcall(function()
		return kitStore:GetAsync("kit_" .. player.UserId)
	end)
	if ok and type(val) == "string" and KIT_DEFS[val] then
		playerKits[player] = val
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		applyToChar(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	stopRegen(player)
	playerKits[player] = nil
end)

return KitManager
