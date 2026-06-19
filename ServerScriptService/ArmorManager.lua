-- ModuleScript: ServerScriptService > ArmorManager
-- Tracks and applies equippable armor for each player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig        = require(ReplicatedStorage:WaitForChild("GameConfig"))

local ArmorManager = {}
local equipped = {}  -- [Player] = armorId string or nil

local BASE_HP = 100

-- Returns the armor definition table for the given id, or nil.
local function getArmorDef(armorId)
	for _, def in ipairs(GameConfig.ARMOR_TYPES) do
		if def.id == armorId then return def end
	end
	return nil
end

-- Applies armor visuals and MaxHealth to the player's current character.
local function applyToCharacter(player, def)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local newMax = BASE_HP + def.bonusHP
	hum.MaxHealth = newMax
	hum.Health    = math.min(hum.Health + def.bonusHP, newMax)

	-- Tint Shirt/Pants if they exist; otherwise tint BodyColors
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.TorsoColor3       = def.color
		bc.LeftArmColor3     = def.color
		bc.RightArmColor3    = def.color
	end
end

-- Removes armor visuals and restores base MaxHealth.
local function removeFromCharacter(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum.MaxHealth = BASE_HP
	hum.Health    = math.min(hum.Health, BASE_HP)

	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		-- Reset to Roblox default (light grey)
		local defaultColor = Color3.fromRGB(163, 162, 165)
		bc.TorsoColor3    = defaultColor
		bc.LeftArmColor3  = defaultColor
		bc.RightArmColor3 = defaultColor
	end
end

function ArmorManager.equip(player, armorId)
	local def = getArmorDef(armorId)
	if not def then return false end

	-- Unequip current armor first
	if equipped[player] then
		ArmorManager.unequip(player)
	end

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

function ArmorManager.getBonusHP(player)
	local armorId = equipped[player]
	if not armorId then return 0 end
	local def = getArmorDef(armorId)
	return def and def.bonusHP or 0
end

-- Re-apply armor after a character respawn
function ArmorManager.reapply(player)
	local armorId = equipped[player]
	if not armorId then return end
	local def = getArmorDef(armorId)
	if def then applyToCharacter(player, def) end
end

function ArmorManager.clear(player)
	equipped[player] = nil
end

function ArmorManager.clearAll()
	equipped = {}
end

return ArmorManager
