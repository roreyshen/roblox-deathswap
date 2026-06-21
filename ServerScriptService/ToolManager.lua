-- ModuleScript: ServerScriptService > ToolManager
-- Sword + Pickaxe tool creation, weapon gifting, mine-speed multipliers, loot drops.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local SwordSwing   = RemoteEvents:WaitForChild("SwordSwing")

local RoundStats   = require(ServerScriptService:WaitForChild("RoundStats"))

local TIERS = {
	Wood  = { swordDmg = 8,  mineMult = 1.5, color = Color3.fromRGB(160, 120, 60)  },
	Stone = { swordDmg = 12, mineMult = 2.0, color = Color3.fromRGB(130, 130, 130) },
	Iron  = { swordDmg = 16, mineMult = 3.0, color = Color3.fromRGB(180, 185, 190) },
}

local SWING_WINDOW = 0.5

local activeSwings = {}  -- [Player] = { tier, expireTime }

local ToolManager = {}

-- ─── Tool builders ───────────────────────────────────────────────────────────

local function makeHandle(parent, color, material)
	local h = Instance.new("Part")
	h.Name          = "Handle"
	h.Size          = Vector3.new(0.3, 2.5, 0.3)
	h.Color         = color
	h.Material      = material or Enum.Material.Wood
	h.TopSurface    = Enum.SurfaceType.Smooth
	h.BottomSurface = Enum.SurfaceType.Smooth
	h.Parent        = parent
	return h
end

local function weldTo(handle, part, offset)
	local w = Instance.new("Weld")
	w.Part0  = handle
	w.Part1  = part
	w.C0     = CFrame.new(offset)
	w.Parent = handle
	return w
end

local function buildSword(tierName)
	local tier = TIERS[tierName] or TIERS.Wood
	local tool = Instance.new("Tool")
	tool.Name           = tierName .. "Sword"
	tool.ToolTip        = tierName .. " Sword — " .. tier.swordDmg .. " dmg"
	tool.RequiresHandle = true
	tool.CanBeDropped   = true
	tool:SetAttribute("WeaponType", "Sword")
	tool:SetAttribute("Tier",       tierName)
	tool:SetAttribute("Damage",     tier.swordDmg)

	local handle = makeHandle(tool, Color3.fromRGB(110, 70, 30))

	local blade = Instance.new("Part")
	blade.Name          = "Blade"
	blade.Size          = Vector3.new(0.15, 1.8, 0.5)
	blade.Color         = tier.color
	blade.Material      = Enum.Material.Metal
	blade.CanCollide    = false
	blade.TopSurface    = Enum.SurfaceType.Smooth
	blade.BottomSurface = Enum.SurfaceType.Smooth
	blade.Parent        = tool
	weldTo(handle, blade, Vector3.new(0, 2.15, 0))

	handle.Touched:Connect(function(hit)
		local char  = hit.Parent
		local hum   = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		local owner = tool.Parent and Players:GetPlayerFromCharacter(tool.Parent)
		if not owner then return end
		if char == owner.Character then return end
		local swing = activeSwings[owner]
		if not swing or tick() > swing.expireTime then return end
		local dmg = TIERS[swing.tier] and TIERS[swing.tier].swordDmg or 8
		hum:TakeDamage(dmg)
		RoundStats.addDamage(owner, dmg)
	end)

	return tool
end

local function buildPickaxe(tierName)
	local tier = TIERS[tierName] or TIERS.Wood
	local tool = Instance.new("Tool")
	tool.Name           = tierName .. "Pickaxe"
	tool.ToolTip        = tierName .. " Pickaxe — " .. tier.mineMult .. "x mine speed"
	tool.RequiresHandle = true
	tool.CanBeDropped   = true
	tool:SetAttribute("WeaponType", "Pickaxe")
	tool:SetAttribute("Tier",       tierName)
	tool:SetAttribute("MineMult",   tier.mineMult)

	local handle = makeHandle(tool, Color3.fromRGB(110, 70, 30))

	local head = Instance.new("Part")
	head.Name          = "Head"
	head.Size          = Vector3.new(1.4, 0.3, 0.3)
	head.Color         = tier.color
	head.Material      = Enum.Material.Metal
	head.CanCollide    = false
	head.TopSurface    = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent        = tool
	weldTo(handle, head, Vector3.new(0, 1.4, 0))

	return tool
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- swordTier / pkTier: pass nil to leave existing weapon of that type unchanged
function ToolManager.giveWeapons(player, swordTier, pkTier)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	-- Remove existing weapons of the requested types
	local function clearType(wtype)
		for _, item in ipairs(backpack:GetChildren()) do
			if item:GetAttribute("WeaponType") == wtype then item:Destroy() end
		end
		local char = player.Character
		if char then
			for _, item in ipairs(char:GetChildren()) do
				if item:GetAttribute("WeaponType") == wtype then item:Destroy() end
			end
		end
	end

	if swordTier ~= nil then
		clearType("Sword")
		buildSword(swordTier or "Wood").Parent = backpack
	end
	if pkTier ~= nil then
		clearType("Pickaxe")
		buildPickaxe(pkTier or "Wood").Parent = backpack
	end
end

function ToolManager.getMineMultiplier(player)
	local char = player.Character
	if not char then return 1 end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:GetAttribute("WeaponType") == "Pickaxe" then
			local tier = tool:GetAttribute("Tier") or "Wood"
			return (TIERS[tier] and TIERS[tier].mineMult) or 1
		end
	end
	return 1
end

function ToolManager.dropWeaponsAt(player, position)
	local char = player.Character
	if not char then return end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local wt = tool:GetAttribute("WeaponType")
			if wt == "Sword" or wt == "Pickaxe" then
				local dropped = tool:Clone()
				dropped.Parent = workspace
				local handle = dropped:FindFirstChild("Handle")
				if handle then
					handle.Anchored = false
					handle.CFrame   = CFrame.new(
						position + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
					)
				end
				tool:Destroy()
			end
		end
	end
end

-- ─── Sword swing event ───────────────────────────────────────────────────────

SwordSwing.OnServerEvent:Connect(function(player, tier)
	tier = tostring(tier)
	if not TIERS[tier] then tier = "Wood" end
	activeSwings[player] = { tier = tier, expireTime = tick() + SWING_WINDOW }
end)

Players.PlayerRemoving:Connect(function(player)
	activeSwings[player] = nil
end)

return ToolManager
