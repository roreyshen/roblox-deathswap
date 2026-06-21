-- Script: ServerScriptService > CheatHandler
-- Dev-only cheat panel handler. Applies coin/gem/HP/kit/armor overrides for testing.
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CurrencyManager = require(ServerScriptService:WaitForChild("CurrencyManager"))
local GemManager      = require(ServerScriptService:WaitForChild("GemManager"))
local ArmorManager    = require(ServerScriptService:WaitForChild("ArmorManager"))
local KitManager      = require(ServerScriptService:WaitForChild("KitManager"))
local GameConfig      = require(ReplicatedStorage:WaitForChild("GameConfig"))

local RemoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local DevCheat       = RemoteEvents:WaitForChild("DevCheat")
local UpdateCurrency = RemoteEvents:WaitForChild("UpdateCurrency")
local UpdateGems     = RemoteEvents:WaitForChild("UpdateGems")
local ArmorEquipped  = RemoteEvents:WaitForChild("ArmorEquipped")

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
				hum.Health    = amount
			end
		end

	elseif action == "setKit" then
		local kitId = value and (value:sub(1,1):upper() .. value:sub(2):lower()) or "none"
		KitManager.setKit(player, kitId == "None" and nil or kitId)

	elseif action == "setArmor" then
		local armorId = tostring(value)
		if armorId:lower() == "none" then
			ArmorManager.unequip(player)
			ArmorEquipped:FireClient(player, nil, 0)
			return
		end
		local def = nil
		for _, entry in ipairs(GameConfig.ARMOR_TYPES) do
			if entry.id:lower() == armorId:lower() then def = entry; break end
		end
		if def then
			ArmorManager.equip(player, def.id)
			ArmorEquipped:FireClient(player, def.id, def.reduction)
		end
	end
end)
