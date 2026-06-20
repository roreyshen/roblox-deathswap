-- ModuleScript: ServerScriptService > MapGenerator
-- Procedurally builds a randomized floating island each round.
local MapGenerator = {}

local ISLAND_Y = 100  -- height of island base above void

local function makePart(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name          = name
	p.Size          = size
	p.CFrame        = CFrame.new(position)
	p.Anchored      = true
	p.CanCollide    = true
	p.Color         = color
	p.Material      = material or Enum.Material.SmoothPlastic
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent        = parent
	return p
end

-- Merchant hat colors (one per shop location)
local HAT_COLORS = {
	Color3.fromRGB(80, 40, 10),   -- dark brown
	Color3.fromRGB(20, 55, 110),  -- dark blue
	Color3.fromRGB(100, 20, 20),  -- dark red
	Color3.fromRGB(25, 80, 30),   -- dark green
	Color3.fromRGB(80, 65, 10),   -- dark gold
}

-- Builds a simple merchant NPC model at the given base CFrame (facing direction baked in).
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

	-- Legs (dark blue pants)
	addPart("LeftLeg",  Vector3.new(0.9, 2.2, 0.9), Vector3.new(-0.5, 1.1, 0),  Color3.fromRGB(50, 55, 110))
	addPart("RightLeg", Vector3.new(0.9, 2.2, 0.9), Vector3.new(0.5,  1.1, 0),  Color3.fromRGB(50, 55, 110))

	-- Torso (brown tunic, collidable so ProximityPrompt is reachable)
	local torso = addPart("Torso", Vector3.new(2, 2.5, 1), Vector3.new(0, 3.35, 0), Color3.fromRGB(105, 65, 20), true)

	-- Arms (cream sleeves)
	addPart("LeftArm",  Vector3.new(0.8, 2.2, 0.8), Vector3.new(-1.4, 3.2, 0), Color3.fromRGB(200, 155, 80))
	addPart("RightArm", Vector3.new(0.8, 2.2, 0.8), Vector3.new(1.4,  3.2, 0), Color3.fromRGB(200, 155, 80))

	-- Head (skin)
	addPart("Head", Vector3.new(1.8, 1.8, 1.8), Vector3.new(0, 5.5, 0), Color3.fromRGB(255, 200, 140))

	-- Hat brim + top
	addPart("HatBrim", Vector3.new(2.8, 0.4, 2.8), Vector3.new(0, 6.55, 0), hatColor)
	addPart("HatTop",  Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 7.55, 0), hatColor)

	-- Eyes (small dark squares on front face, local -Z = forward)
	addPart("EyeL", Vector3.new(0.4, 0.4, 0.1), Vector3.new(-0.45, 5.6, -0.95), Color3.fromRGB(30, 20, 10))
	addPart("EyeR", Vector3.new(0.4, 0.4, 0.1), Vector3.new(0.45,  5.6, -0.95), Color3.fromRGB(30, 20, 10))

	-- Smile
	addPart("Smile", Vector3.new(0.8, 0.2, 0.1), Vector3.new(0, 5.15, -0.95), Color3.fromRGB(110, 40, 40))

	-- SHOP billboard above hat
	local gui = Instance.new("BillboardGui")
	gui.Size        = UDim2.new(0, 160, 0, 50)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = false
	gui.Parent      = torso

	local bg = Instance.new("Frame", gui)
	bg.Size                  = UDim2.fromScale(1, 1)
	bg.BackgroundColor3      = Color3.fromRGB(40, 20, 0)
	bg.BackgroundTransparency = 0.15
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel", bg)
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = Color3.fromRGB(255, 220, 60)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = "SHOP"

	-- ProximityPrompt on torso
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

-- Builds island terrain parts into the Generated folder.
-- Returns the top surface Y of the island and the center position.
local function buildIsland(generated, cx, cz, radius, stoneH, dirtH, grassH)
	local totalH  = stoneH + dirtH + grassH
	local stoneY  = ISLAND_Y + stoneH / 2
	local dirtY   = ISLAND_Y + stoneH + dirtH / 2
	local grassY  = ISLAND_Y + stoneH + dirtH + grassH / 2
	local topY    = ISLAND_Y + totalH

	-- Stone core (slightly wider for overhanging feel)
	makePart(generated, "Stone",
		Vector3.new(radius * 2, stoneH, radius * 2),
		Vector3.new(cx, stoneY, cz),
		Color3.fromRGB(105, 105, 105), Enum.Material.SmoothPlastic)

	-- Dirt band
	makePart(generated, "Dirt",
		Vector3.new(radius * 2, dirtH, radius * 2),
		Vector3.new(cx, dirtY, cz),
		Color3.fromRGB(140, 100, 60), Enum.Material.SmoothPlastic)

	-- Grass cap
	makePart(generated, "Grass",
		Vector3.new(radius * 2, grassH, radius * 2),
		Vector3.new(cx, grassY, cz),
		Color3.fromRGB(106, 127, 63), Enum.Material.Grass)

	-- Tapered bottom (visual: makes it look like a floating island)
	local taperH = math.floor(stoneH * 0.6)
	makePart(generated, "StoneBase",
		Vector3.new(radius * 1.2, taperH, radius * 1.2),
		Vector3.new(cx, ISLAND_Y - taperH / 2, cz),
		Color3.fromRGB(85, 85, 85), Enum.Material.SmoothPlastic)

	return topY
end

function MapGenerator.generate(mapFolder)
	-- Clear old generated parts
	local existing = mapFolder:FindFirstChild("Generated")
	if existing then existing:Destroy() end

	-- Clear old center platform
	local oldCenter = mapFolder:FindFirstChild("CenterPlatform")
	if oldCenter then oldCenter:Destroy() end

	-- Clear old spawn points
	local spawnFolder = mapFolder:FindFirstChild("SpawnPoints")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name   = "SpawnPoints"
		spawnFolder.Parent = mapFolder
	else
		for _, child in ipairs(spawnFolder:GetChildren()) do
			child:Destroy()
		end
	end

	-- Ensure PlayerBuilds folder
	if not mapFolder:FindFirstChild("PlayerBuilds") then
		local pb = Instance.new("Folder")
		pb.Name   = "PlayerBuilds"
		pb.Parent = mapFolder
	end

	local generated = Instance.new("Folder")
	generated.Name   = "Generated"
	generated.Parent = mapFolder

	-- Random island parameters (large scale)
	local radius  = math.random(350, 550)
	local stoneH  = math.random(15, 25)
	local dirtH   = math.random(4, 8)
	local grassH  = 5
	local cx, cz  = 0, 0  -- island centered at origin horizontally

	local topY = buildIsland(generated, cx, cz, radius, stoneH, dirtH, grassH)
	local platformY = topY + 1  -- spawn platforms sit on top surface

	-- 4 spawn platforms at cardinal directions (inset from island edge)
	local spawnOffset = radius - 20
	local spawnDirs = {
		{name="Spawn1", dx=0,           dz=-spawnOffset},
		{name="Spawn2", dx=spawnOffset, dz=0           },
		{name="Spawn3", dx=0,           dz=spawnOffset },
		{name="Spawn4", dx=-spawnOffset,dz=0           },
	}

	for _, sp in ipairs(spawnDirs) do
		local part = makePart(spawnFolder, sp.name,
			Vector3.new(40, 1, 40),
			Vector3.new(cx + sp.dx, platformY, cz + sp.dz),
			Color3.fromRGB(106, 155, 50), Enum.Material.Grass)
		part.CanCollide = true
	end

	-- Center platform (for the shop)
	local centerPlatform = makePart(mapFolder, "CenterPlatform",
		Vector3.new(80, 1, 80),
		Vector3.new(cx, platformY, cz),
		Color3.fromRGB(162, 162, 162), Enum.Material.SmoothPlastic)
	centerPlatform.CanCollide = true

	-- Merchant NPCs: one at each spawn platform (facing island center) + one at center
	local shopFolder = mapFolder:FindFirstChild("Shops")
	if shopFolder then shopFolder:Destroy() end
	shopFolder = Instance.new("Folder")
	shopFolder.Name   = "Shops"
	shopFolder.Parent = mapFolder

	local islandCenter = Vector3.new(cx, platformY + 0.5, cz)

	for i, sp in ipairs(spawnDirs) do
		local pos   = Vector3.new(cx + sp.dx, platformY + 0.5, cz + sp.dz)
		local faceCF = CFrame.new(pos, islandCenter)  -- face toward island center
		buildMerchant(shopFolder, faceCF, HAT_COLORS[i] or HAT_COLORS[1])
	end

	-- Center merchant faces default -Z direction
	buildMerchant(shopFolder, CFrame.new(islandCenter), HAT_COLORS[5])

	return {
		islandCenter = Vector3.new(cx, platformY, cz),
		topY         = topY,
		radius       = radius,
	}
end

-- Builds invisible kill-border walls + void kill floor around the island.
-- borderSize: half-extent of the square border (studs from center)
function MapGenerator.buildKillBorder(mapFolder, borderSize)
	local border = mapFolder:FindFirstChild("KillBorder")
	if border then border:Destroy() end
	border = Instance.new("Folder")
	border.Name   = "KillBorder"
	border.Parent = mapFolder

	local wallH  = 150  -- tall enough players can't jump over
	local wallT  = 10   -- thickness
	local wallY  = ISLAND_Y + wallH / 2

	-- Helper: create a kill wall that fires damage on touch
	local function makeWall(name, size, position)
		local wall = Instance.new("Part")
		wall.Name          = name
		wall.Size          = size
		wall.CFrame        = CFrame.new(position)
		wall.Anchored      = true
		wall.CanCollide    = true
		wall.Transparency  = 1
		wall.CastShadow    = false
		wall.Parent        = border

		wall.Touched:Connect(function(hit)
			local char = hit.Parent
			local hum  = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum:TakeDamage(9999) end
		end)
	end

	local B = borderSize
	makeWall("WallN", Vector3.new(B*2+wallT*2, wallH, wallT), Vector3.new(0, wallY, -B))
	makeWall("WallS", Vector3.new(B*2+wallT*2, wallH, wallT), Vector3.new(0, wallY,  B))
	makeWall("WallE", Vector3.new(wallT, wallH, B*2),         Vector3.new( B, wallY, 0))
	makeWall("WallW", Vector3.new(wallT, wallH, B*2),         Vector3.new(-B, wallY, 0))

	-- Void kill floor far below island
	local floor = Instance.new("Part")
	floor.Name         = "VoidFloor"
	floor.Size         = Vector3.new(B*2+100, 4, B*2+100)
	floor.CFrame       = CFrame.new(0, ISLAND_Y - 80, 0)
	floor.Anchored     = true
	floor.CanCollide   = true
	floor.Transparency = 0.8
	floor.Color        = Color3.fromRGB(15, 15, 15)
	floor.CastShadow   = false
	floor.Parent       = border

	floor.Touched:Connect(function(hit)
		local char = hit.Parent
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(9999) end
	end)
end

-- Destroys all generated island parts (called on round reset)
function MapGenerator.clear(mapFolder)
	local generated = mapFolder:FindFirstChild("Generated")
	if generated then generated:Destroy() end

	local oldCenter = mapFolder:FindFirstChild("CenterPlatform")
	if oldCenter then oldCenter:Destroy() end

	-- Clear spawn points (regenerated each round)
	local spawnFolder = mapFolder:FindFirstChild("SpawnPoints")
	if spawnFolder then
		for _, child in ipairs(spawnFolder:GetChildren()) do
			child:Destroy()
		end
	end

	-- Clear kill border
	local border = mapFolder:FindFirstChild("KillBorder")
	if border then border:Destroy() end

	-- Clear shops
	local shops = mapFolder:FindFirstChild("Shops")
	if shops then shops:Destroy() end
end

return MapGenerator
