-- ModuleScript: ServerScriptService > AnchorManager
-- Manages Soul Crystal anchors: placement, HP tracking, and destruction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MapManager = require(ReplicatedStorage:WaitForChild("MapManager"))

local AnchorManager = {}

local anchors      = {}  -- [userId] = { part = Part, hp = int }
local mineCooldown = {}  -- [minerUserId .. "|" .. ownerUserId] = lastHitTick

local ANCHOR_COLOR = Color3.fromRGB(0, 210, 255)
local ANCHOR_SIZE  = Vector3.new(4, 5, 4)
local GRID         = GameConfig.GRID_SIZE

local function snap(v)
	return Vector3.new(
		math.round(v.X / GRID) * GRID,
		math.round(v.Y / GRID) * GRID,
		math.round(v.Z / GRID) * GRID
	)
end

-- Place an anchor for `player` at `position`. Returns true on success.
function AnchorManager.place(player, position)
	if anchors[player.UserId] then return false end

	local builds = MapManager.getBuildsFolder()
	if not builds then return false end

	local snapped = snap(position)

	local part = Instance.new("Part")
	part.Name       = "SoulCrystal"
	part.Size       = ANCHOR_SIZE
	part.CFrame     = CFrame.new(snapped)
	part.Anchored   = true
	part.Material   = Enum.Material.Neon
	part.Color      = ANCHOR_COLOR
	part.CastShadow = false
	part:SetAttribute("IsAnchor", true)
	part:SetAttribute("AnchorOwner", player.UserId)

	-- Name label above the crystal
	local bill = Instance.new("BillboardGui")
	bill.Size         = UDim2.new(0, 140, 0, 36)
	bill.StudsOffset  = Vector3.new(0, 4, 0)
	bill.AlwaysOnTop  = false
	bill.Parent       = part

	local lbl = Instance.new("TextLabel", bill)
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = player.Name .. "'s Crystal"

	part.Parent = builds

	anchors[player.UserId] = { part = part, hp = GameConfig.ANCHOR_MAX_HP }
	return true
end

-- Strike an anchor owned by `ownerUserId`. Returns remaining HP (0 = destroyed),
-- or nil if on cooldown / target not found / miner owns it.
function AnchorManager.hit(miner, ownerUserId)
	if miner.UserId == ownerUserId then return nil end

	local data = anchors[ownerUserId]
	if not data or not data.part or not data.part.Parent then return nil end

	local key = miner.UserId .. "|" .. ownerUserId
	local now = tick()
	if mineCooldown[key] and (now - mineCooldown[key]) < GameConfig.ANCHOR_MINE_COOLDOWN then
		return nil
	end
	mineCooldown[key] = now

	data.hp -= 1

	-- Visual: fade as HP drops
	data.part.Transparency = (GameConfig.ANCHOR_MAX_HP - data.hp) / GameConfig.ANCHOR_MAX_HP * 0.75

	if data.hp <= 0 then
		pcall(function() data.part:Destroy() end)
		anchors[ownerUserId] = nil
		return 0
	end
	return data.hp
end

function AnchorManager.hasAnchor(player)
	return anchors[player.UserId] ~= nil
end

-- CFrame to respawn the player at (above their crystal)
function AnchorManager.getSpawnCF(player)
	local data = anchors[player.UserId]
	if data and data.part and data.part.Parent then
		return data.part.CFrame + Vector3.new(0, 6, 0)
	end
	return nil
end

function AnchorManager.clear(player)
	local data = anchors[player.UserId]
	if data then
		pcall(function() if data.part then data.part:Destroy() end end)
		anchors[player.UserId] = nil
	end
	local uid = tostring(player.UserId)
	for key in pairs(mineCooldown) do
		if key:find(uid, 1, true) then
			mineCooldown[key] = nil
		end
	end
end

function AnchorManager.clearAll()
	for _, data in pairs(anchors) do
		pcall(function() if data.part then data.part:Destroy() end end)
	end
	anchors      = {}
	mineCooldown = {}
end

return AnchorManager
