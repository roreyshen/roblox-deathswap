-- Script: ServerScriptService > CheatHandler
-- Dev-only cheat panel handler. Applies coin/gem/HP/kit overrides for testing.
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurrencyManager = require(ServerScriptService:WaitForChild("CurrencyManager"))
local GemManager      = require(ServerScriptService:WaitForChild("GemManager"))
local ArmorManager    = require(ServerScriptService:WaitForChild("ArmorManager"))

local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local DevCheat      = RemoteEvents:WaitForChild("DevCheat")
local UpdateCurrency = RemoteEvents:WaitForChild("UpdateCurrency")
local UpdateGems    = RemoteEvents:WaitForChild("UpdateGems")
local ArmorEquipped  = RemoteEvents:WaitForChild("ArmorEquipped")
local GameConfig     = require(ReplicatedStorage:WaitForChild("GameConfig"))

local KIT_STATS = {
	speed   = { walkSpeed = 20 },   -- default 16
	jump    = { jumpPower = 62 },    -- default 50
	miner   = { mineSpeed = 2.0 },   -- multiplier
	healer  = { regenRate = 2 },     -- HP/sec
	trapper = { trapDmgMult = 1.25 },
	none    = {},
}

-- Per-player kit state (server-authoritative)
local playerKits = {}  -- [Player] = "speed"|"jump"|"miner"|"healer"|"trapper"|"none"

local function applyKit(player, kitId)
	playerKits[player] = kitId
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Reset to defaults first
	hum.WalkSpeed = 16
	hum.JumpPower = 50

	local stats = KIT_STATS[kitId] or {}
	if stats.walkSpeed then hum.WalkSpeed = stats.walkSpeed end
	if stats.jumpPower then hum.JumpPower = stats.jumpPower end
end

-- Re-apply kit when character respawns
Players.PlayerAdded:Connect(function(player)
	playerKits[player] = "none"
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		applyKit(player, playerKits[player] or "none")
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerKits[player] = nil
end)

-- Expose kit state for other modules
local CheatHandler = {}
function CheatHandler.getKit(player) return playerKits[player] or "none" end
function CheatHandler.getKitStats(kitId) return KIT_STATS[kitId] or {} end

DevCheat.OnServerEvent:Connect(function(player, action, value)
	if action == "setCoins" then
		local amount = math.clamp(tonumber(value) or 0, 0, 99999)
		local diff = amount - CurrencyManager.get(player)
		if diff > 0 then
			CurrencyManager.add(player, diff)
		else
			CurrencyManager.reset(player)
			if amount > 0 then CurrencyManager.add(player, amount) end
		end
		UpdateCurrency:FireClient(player, CurrencyManager.get(player))

	elseif action == "setGems" then
		local amount = math.clamp(tonumber(value) or 0, 0, 99999)
		GemManager.set(player, amount)
		UpdateGems:FireClient(player, GemManager.get(player))

	elseif action == "setHP" then
		local amount = math.clamp(tonumber(value) or 0, 1, 500)
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = amount
				hum.Health = amount
			end
		end

	elseif action == "setKit" then
		local kitId = tostring(value):lower()
		if KIT_STATS[kitId] then
			applyKit(player, kitId)
		end

	elseif action == "setArmor" then
		local armorId = tostring(value)
		-- ARMOR_TYPES is an array; find matching id case-insensitively
		local def = nil
		for _, entry in ipairs(GameConfig.ARMOR_TYPES) do
			if entry.id:lower() == armorId:lower() then def = entry; break end
		end
		if def then
			ArmorManager.equip(player, def.id)
			ArmorEquipped:FireClient(player, def.id, def.bonusHP or 0)
		end
	end
end)

return CheatHandler
