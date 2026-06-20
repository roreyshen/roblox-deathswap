-- ModuleScript: ServerScriptService > MapGenerator
-- Procedurally builds a voxel-based floating island each round.
local MapGenerator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local GRID    = GameConfig.GRID_SIZE          -- 4 studs per voxel
local RADIUS  = GameConfig.ISLAND_RADIUS      -- 100 studs
local BASE_Y  = GameConfig.ISLAND_Y           -- 100 (bottom of bedrock)
local WALL_H  = GameConfig.TERRAIN_WALL_HEIGHT -- 12 studs

local RVOX       = math.floor(RADIUS / GRID)  -- 25 voxels radius
local SURFACE_Y  = BASE_Y + GRID * 4           -- 116: top of normal flat terrain

local LAYER_DEFS = {
	{ id = "Rock",  color = Color3.fromRGB(100, 100, 110), material = Enum.Material.SmoothPlastic },
	{ id = "Dirt",  color = Color3.fromRGB(120, 80,  40),  material = Enum.Material.SmoothPlastic },
	{ id = "Grass", color = Color3.fromRGB(90,  150, 60),  material = Enum.Material.Grass         },
}
local BEDROCK_COLOR = Color3.fromRGB(30, 30, 35)
local BARRIER_COLOR = Color3.fromRGB(80, 120, 220)

local HAT_COLORS = {
	Color3.fromRGB(80, 40, 10),
	Color3.fromRGB(20, 55, 110),
	Color3.fromRGB(100, 20, 20),
	Color3.fromRGB(25, 80, 30),
	Color3.fromRGB(80, 65, 10),
}

local function makePart(parent, name, size, pos, color, material, transparency, canCollide)
	local p = Instance.new("Part")
	p.Name          = name
	p.Size          = size
	p.CFrame        = CFrame.new(pos)
	p.Anchored      = true
	p.CanCollide    = canCollide ~= false
	p.Color         = color
	p.Material      = material or Enum.Material.SmoothPlastic
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency  = transparency or 0
	p.CastShadow    = canCollide ~= false
	p.Parent        = parent
	return p
end

-- Voxel terrain: builds Bedrock + 3 mineable layers + optional hill bumps.
-- Returns surfaceTop[gx][gz] = world Y of the top surface at that cell.
local function buildVoxelTerrain(folder)
	local BLOCK_HP = GameConfig.BLOCK_HP
	local seed     = math.random() * 200
	local n        = 0
	local surfaceTop = {}

	for gx = -RVOX, RVOX do
		surfaceTop[gx] = {}
		for gz = -RVOX, RVOX do
			if gx * gx + gz * gz <= RVOX * RVOX then
				local wx = gx * GRID
				local wz = gz * GRID

				-- Bedrock (indestructible bottom layer)
				local bpart = makePart(folder, "Bedrock",
					Vector3.new(GRID, GRID, GRID),
					Vector3.new(wx, BASE_Y + GRID / 2, wz),
					BEDROCK_COLOR, Enum.Material.SmoothPlastic)
				bpart:SetAttribute("IsBedrock",  true)
				bpart:SetAttribute("BlockType",   "Bedrock")
				n += 1

				-- Three mineable layers (Rock, Dirt, Grass)
				for li, layerDef in ipairs(LAYER_DEFS) do
					local cy  = BASE_Y + GRID * li + GRID / 2
					local hp  = BLOCK_HP[layerDef.id] or 1
					local tp  = makePart(folder, layerDef.id,
						Vector3.new(GRID, GRID, GRID),
						Vector3.new(wx, cy, wz),
						layerDef.color, layerDef.material)
					tp:SetAttribute("IsTerrain", true)
					tp:SetAttribute("BlockType",  layerDef.id)
					tp:SetAttribute("HP",         hp)
					tp:SetAttribute("MaxHP",      hp)
					n += 1
				end

				-- Hill bumps: sine noise, avoid perimeter ring
				local noise   = math.sin(gx * 0.35 + seed) * math.cos(gz * 0.35 + seed * 0.7)
				local distSq  = gx * gx + gz * gz
				local isHill  = noise > 0.60 and distSq < (RVOX - 4) * (RVOX - 4)
				local hillExt = isHill and math.random(1, 2) or 0

				local topAfterLayers = BASE_Y + GRID * 4  -- top of Grass = 116
				for hi = 1, hillExt do
					local hy = topAfterLayers + GRID * (hi - 1) + GRID / 2
					local hp = BLOCK_HP["Grass"] or 1
					local hp2 = makePart(folder, "GrassHill",
						Vector3.new(GRID, GRID, GRID),
						Vector3.new(wx, hy, wz),
						LAYER_DEFS[3].color, LAYER_DEFS[3].material)
					hp2:SetAttribute("IsTerrain", true)
					hp2:SetAttribute("BlockType",  "Grass")
					hp2:SetAttribute("HP",         hp)
					hp2:SetAttribute("MaxHP",      hp)
					n += 1
				end

				surfaceTop[gx][gz] = topAfterLayers + hillExt * GRID

				if n % 200 == 0 then task.wait() end
			end
		end
	end
	return surfaceTop
end

-- Visible perimeter barrier (12 studs tall, semi-transparent blue)
local function buildBarrier(folder)
	local n = 0
	local barrierY = SURFACE_Y + WALL_H / 2
	for gx = -RVOX, RVOX do
		for gz = -RVOX, RVOX do
			local d2 = gx * gx + gz * gz
			local onEdge = d2 <= RVOX * RVOX and (
				(gx+1)*(gx+1)+gz*gz   > RVOX*RVOX or
				(gx-1)*(gx-1)+gz*gz   > RVOX*RVOX or
				gx*gx+(gz+1)*(gz+1)   > RVOX*RVOX or
				gx*gx+(gz-1)*(gz-1)   > RVOX*RVOX
			)
			if onEdge then
				local bp = makePart(folder, "Barrier",
					Vector3.new(GRID, WALL_H, GRID),
					Vector3.new(gx * GRID, barrierY, gz * GRID),
					BARRIER_COLOR, Enum.Material.Neon, 0.35)
				bp:SetAttribute("IsBarrier", true)
				n += 1
				if n % 50 == 0 then task.wait() end
			end
		end
	end
end

-- Tree at world position (wx, topY, wz) — topY is the surface's top Y
local function buildTree(folder, wx, topY, wz)
	local BLOCK_HP = GameConfig.BLOCK_HP
	local trunkH   = math.random(2, 3)

	for i = 1, trunkH do
		local tp = makePart(folder, "TreeTrunk",
			Vector3.new(GRID, GRID, GRID),
			Vector3.new(wx, topY + GRID * (i - 1) + GRID / 2, wz),
			Color3.fromRGB(110, 70, 30), Enum.Material.Wood)
		tp:SetAttribute("IsTerrain", true)
		tp:SetAttribute("BlockType",  "Wood")
		local hp = BLOCK_HP["Wood"] or 1
		tp:SetAttribute("HP",         hp)
		tp:SetAttribute("MaxHP",      hp)
	end

	local leafY  = topY + GRID * trunkH + GRID / 2
	local leafHP = BLOCK_HP["Grass"] or 1
	for dx = -1, 1 do
		for dz = -1, 1 do
			local lp = makePart(folder, "Leaf",
				Vector3.new(GRID, GRID, GRID),
				Vector3.new(wx + dx * GRID, leafY, wz + dz * GRID),
				Color3.fromRGB(55, 110, 35), Enum.Material.Grass)
			lp:SetAttribute("IsTerrain", true)
			lp:SetAttribute("BlockType",  "Grass")
			lp:SetAttribute("HP",         leafHP)
			lp:SetAttribute("MaxHP",      leafHP)
		end
	end
end

-- Merchant NPC model
local function buildMerchant(parent, baseCF, hatColor)
	local model = Instance.new("Model")
	model.Name  = "Merchant"

	local function addPart(name, size, localOffset, color, canCollide)
		local p = Instance.new("Part")
		p.Name          = name
		p.Size          = size
		p.CFrame        = baseCF * CFrame.new(localOffset)
		p.Anchored      = true
		p.CanCollide    = canCollide or false
		p.Color         = color
		p.Material      = Enum.Material.SmoothPlastic
		p.TopSurface    = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow    = false
		p.Parent        = model
		return p
	end

	addPart("LeftLeg",  Vector3.new(0.9, 2.2, 0.9), Vector3.new(-0.5, 1.1, 0),  Color3.fromRGB(50, 55, 110))
	addPart("RightLeg", Vector3.new(0.9, 2.2, 0.9), Vector3.new(0.5,  1.1, 0),  Color3.fromRGB(50, 55, 110))
	local torso = addPart("Torso", Vector3.new(2, 2.5, 1), Vector3.new(0, 3.35, 0), Color3.fromRGB(105, 65, 20))
	addPart("LeftArm",  Vector3.new(0.8, 2.2, 0.8), Vector3.new(-1.4, 3.2, 0), Color3.fromRGB(200, 155, 80))
	addPart("RightArm", Vector3.new(0.8, 2.2, 0.8), Vector3.new(1.4,  3.2, 0), Color3.fromRGB(200, 155, 80))
	addPart("Head",     Vector3.new(1.8, 1.8, 1.8), Vector3.new(0,    5.5, 0),  Color3.fromRGB(255, 200, 140))
	addPart("HatBrim",  Vector3.new(2.8, 0.4, 2.8), Vector3.new(0,   6.55, 0), hatColor)
	addPart("HatTop",   Vector3.new(1.6, 1.6, 1.6), Vector3.new(0,   7.55, 0), hatColor)
	addPart("EyeL",     Vector3.new(0.4, 0.4, 0.1), Vector3.new(-0.45, 5.6, -0.95), Color3.fromRGB(30, 20, 10))
	addPart("EyeR",     Vector3.new(0.4, 0.4, 0.1), Vector3.new(0.45,  5.6, -0.95), Color3.fromRGB(30, 20, 10))
	addPart("Smile",    Vector3.new(0.8, 0.2, 0.1), Vector3.new(0,   5.15, -0.95), Color3.fromRGB(110, 40, 40))

	local gui = Instance.new("BillboardGui")
	gui.Size        = UDim2.new(0, 160, 0, 50)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = false
	gui.Parent      = torso

	local bg = Instance.new("Frame", gui)
	bg.Size                   = UDim2.fromScale(1, 1)
	bg.BackgroundColor3       = Color3.fromRGB(40, 20, 0)
	bg.BackgroundTransparency = 0.15
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel", bg)
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = Color3.fromRGB(255, 220, 60)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = "SHOP"

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Open Shop"
	prompt.ObjectText            = "Merchant"
	prompt.MaxActivationDistance = 15
	prompt.HoldDuration          = 0
	prompt.Parent                = torso

	model.PrimaryPart = torso
	model.Parent      = parent
	return model
end

function MapGenerator.generate(mapFolder)
	-- Clear previous round
	for _, name in ipairs({"Generated", "CenterPlatform", "KillBorder", "Shops"}) do
		local old = mapFolder:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local spawnFolder = mapFolder:FindFirstChild("SpawnPoints")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name   = "SpawnPoints"
		spawnFolder.Parent = mapFolder
	else
		for _, c in ipairs(spawnFolder:GetChildren()) do c:Destroy() end
	end
	if not mapFolder:FindFirstChild("PlayerBuilds") then
		local pb = Instance.new("Folder")
		pb.Name   = "PlayerBuilds"
		pb.Parent = mapFolder
	end

	local generated = Instance.new("Folder")
	generated.Name   = "Generated"
	generated.Parent = mapFolder

	-- Build voxel terrain
	local surfaceTop = buildVoxelTerrain(generated)

	-- Build perimeter barrier
	buildBarrier(generated)

	-- Scatter 12 trees (avoid center 20 studs and perimeter edge 3 voxels)
	local treeCount   = 0
	local treeAttempts = 0
	while treeCount < 12 and treeAttempts < 200 do
		treeAttempts += 1
		local gx = math.random(-RVOX + 4, RVOX - 4)
		local gz = math.random(-RVOX + 4, RVOX - 4)
		local d2 = gx * gx + gz * gz
		-- Within radius, not in center 5-voxel area, not on a hill (keep flat areas for trees)
		if d2 <= (RVOX - 3) * (RVOX - 3) and d2 > 5 * 5 and surfaceTop[gx] and surfaceTop[gx][gz] then
			local topY = surfaceTop[gx][gz]
			buildTree(generated, gx * GRID, topY, gz * GRID)
			-- Mark neighbors to avoid overlap
			surfaceTop[gx][gz] = nil
			treeCount += 1
			task.wait()
		end
	end

	-- Spawn platforms (invisible anchors at cardinal positions on terrain surface)
	local spawnR   = RVOX - 6  -- inset 6 voxels from edge
	local spawnDirs = {
		{ name = "Spawn1", gx =  0,      gz = -spawnR },
		{ name = "Spawn2", gx =  spawnR, gz =  0      },
		{ name = "Spawn3", gx =  0,      gz =  spawnR },
		{ name = "Spawn4", gx = -spawnR, gz =  0      },
	}

	local centerY = SURFACE_Y  -- flat center is always at surface level

	for _, sp in ipairs(spawnDirs) do
		local wx = sp.gx * GRID
		local wz = sp.gz * GRID
		local topY = (surfaceTop[sp.gx] and surfaceTop[sp.gx][sp.gz]) or SURFACE_Y
		-- Visible spawn marker (small flat green disc)
		local marker = makePart(spawnFolder, sp.name,
			Vector3.new(20, 1, 20),
			Vector3.new(wx, topY + 0.5, wz),
			Color3.fromRGB(60, 200, 80), Enum.Material.Neon, 0.6)
		marker.CanCollide = false
	end

	-- Kill border (insta-kill walls outside island)
	MapGenerator.buildKillBorder(mapFolder, RADIUS + 20)

	-- Merchant NPCs (one per spawn + one at center)
	local shopFolder = Instance.new("Folder")
	shopFolder.Name   = "Shops"
	shopFolder.Parent = mapFolder

	local islandCenter = Vector3.new(0, centerY + 0.5, 0)
	for i, sp in ipairs(spawnDirs) do
		local pos    = Vector3.new(sp.gx * GRID, SURFACE_Y + 0.5, sp.gz * GRID)
		local faceCF = CFrame.new(pos, islandCenter)
		buildMerchant(shopFolder, faceCF, HAT_COLORS[i] or HAT_COLORS[1])
	end
	buildMerchant(shopFolder, CFrame.new(islandCenter), HAT_COLORS[5])

	return {
		islandCenter = Vector3.new(0, SURFACE_Y, 0),
		topY         = SURFACE_Y,
		radius       = RADIUS,
	}
end

function MapGenerator.buildKillBorder(mapFolder, borderSize)
	local border = mapFolder:FindFirstChild("KillBorder")
	if border then border:Destroy() end
	border = Instance.new("Folder")
	border.Name   = "KillBorder"
	border.Parent = mapFolder

	local wallH = 150
	local wallT = 10
	local wallY = BASE_Y + wallH / 2

	local function makeWall(name, size, pos)
		local wall = Instance.new("Part")
		wall.Name         = name
		wall.Size         = size
		wall.CFrame       = CFrame.new(pos)
		wall.Anchored     = true
		wall.CanCollide   = true
		wall.Transparency = 1
		wall.CastShadow   = false
		wall.Parent       = border
		wall.Touched:Connect(function(hit)
			local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if hum then hum:TakeDamage(9999) end
		end)
	end

	local B = borderSize
	makeWall("WallN", Vector3.new(B*2+wallT*2, wallH, wallT), Vector3.new(0,  wallY, -B))
	makeWall("WallS", Vector3.new(B*2+wallT*2, wallH, wallT), Vector3.new(0,  wallY,  B))
	makeWall("WallE", Vector3.new(wallT, wallH, B*2),         Vector3.new( B, wallY,  0))
	makeWall("WallW", Vector3.new(wallT, wallH, B*2),         Vector3.new(-B, wallY,  0))

	local floor = Instance.new("Part")
	floor.Name         = "VoidFloor"
	floor.Size         = Vector3.new(B*2+100, 4, B*2+100)
	floor.CFrame       = CFrame.new(0, BASE_Y - 80, 0)
	floor.Anchored     = true
	floor.CanCollide   = true
	floor.Transparency = 0.8
	floor.Color        = Color3.fromRGB(15, 15, 15)
	floor.CastShadow   = false
	floor.Parent       = border
	floor.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(9999) end
	end)
end

function MapGenerator.clear(mapFolder)
	for _, name in ipairs({"Generated", "CenterPlatform", "KillBorder", "Shops"}) do
		local obj = mapFolder:FindFirstChild(name)
		if obj then obj:Destroy() end
	end
	local spawnFolder = mapFolder:FindFirstChild("SpawnPoints")
	if spawnFolder then
		for _, c in ipairs(spawnFolder:GetChildren()) do c:Destroy() end
	end
end

return MapGenerator
