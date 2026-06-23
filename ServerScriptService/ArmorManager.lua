-- ModuleScript: ServerScriptService > ArmorManager
-- Tracks equipped armor and applies damage reduction via HealthChanged refund.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))

local ArmorManager = {}
local equipped   = {}    -- [Player] = armorId string or nil
local armorConns = {}    -- [Player] = HealthChanged connection

local function getArmorDef(armorId)
	for _, def in ipairs(GameConfig.ARMOR_TYPES) do
		if def.id == armorId then return def end
	end
	return nil
end

local function disconnectConn(player)
	if armorConns[player] then
		armorConns[player]:Disconnect()
		armorConns[player] = nil
	end
end

local function applyToCharacter(player, def)
	disconnectConn(player)

	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Visual tint
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.TorsoColor3    = def.color
		bc.LeftArmColor3  = def.color
		bc.RightArmColor3 = def.color
	end

	-- Damage reduction: when health drops, refund (reduction * damage)
	local prevHealth = hum.Health
	armorConns[player] = hum.HealthChanged:Connect(function(newHealth)
		if newHealth >= prevHealth then
			prevHealth = newHealth
			return
		end
		if newHealth <= 0 then
			prevHealth = 0
			return
		end
		local dmg    = prevHealth - newHealth
		local refund = dmg * def.reduction
		prevHealth   = newHealth + refund
		hum.Health   = prevHealth
	end)
end

local function removeFromCharacter(player)
	disconnectConn(player)
	local char = player.Character
	if not char then return end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		local defaultColor = Color3.fromRGB(163, 162, 165)
		bc.TorsoColor3    = defaultColor
		bc.LeftArmColor3  = defaultColor
		bc.RightArmColor3 = defaultColor
	end
end

function ArmorManager.equip(player, armorId)
	local def = getArmorDef(armorId)
	if not def then return false end
	if equipped[player] then ArmorManager.unequip(player) end
	equipped[player] = armorId
	applyToCharacter(player, def)
	return true
end

function ArmorManager.unequip(player)
	if not equipped[player] then return end
	equipped[player] = nil
	removeFromCharacter(player)
end

function ArmorManager.getEquipped(player)
	return equipped[player]
end

function ArmorManager.getReduction(player)
	local armorId = equipped[player]
	if not armorId then return 0 end
	local def = getArmorDef(armorId)
	return def and def.reduction or 0
end

function ArmorManager.reapply(player)
	local armorId = equipped[player]
	if not armorId then return end
	local def = getArmorDef(armorId)
	if def then applyToCharacter(player, def) end
end

function ArmorManager.clear(player)
	disconnectConn(player)
	equipped[player] = nil
end

function ArmorManager.clearAll()
	for player in pairs(armorConns) do
		disconnectConn(player)
	end
	equipped = {}
end

return ArmorManager
