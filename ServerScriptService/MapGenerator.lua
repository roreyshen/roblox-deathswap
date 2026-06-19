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

	-- Random island parameters
	local radius  = math.random(35, 55)
	local stoneH  = math.random(8, 14)
	local dirtH   = math.random(2, 4)
	local grassH  = 2
	local cx, cz  = 0, 0  -- island centered at origin horizontally

	local topY = buildIsland(generated, cx, cz, radius, stoneH, dirtH, grassH)
	local platformY = topY + 1  -- spawn platforms sit on top surface

	-- 4 spawn platforms at cardinal directions (at island edge)
	local spawnOffset = radius - 4
	local spawnDirs = {
		{name="Spawn1", dx=0,           dz=-spawnOffset},
		{name="Spawn2", dx=spawnOffset, dz=0           },
		{name="Spawn3", dx=0,           dz=spawnOffset },
		{name="Spawn4", dx=-spawnOffset,dz=0           },
	}

	for _, sp in ipairs(spawnDirs) do
		local part = makePart(spawnFolder, sp.name,
			Vector3.new(10, 1, 10),
			Vector3.new(cx + sp.dx, platformY, cz + sp.dz),
			Color3.fromRGB(106, 155, 50), Enum.Material.Grass)
		part.CanCollide = true
	end

	-- Center platform (for the shop)
	local centerPlatform = makePart(mapFolder, "CenterPlatform",
		Vector3.new(14, 1, 14),
		Vector3.new(cx, platformY, cz),
		Color3.fromRGB(162, 162, 162), Enum.Material.SmoothPlastic)
	centerPlatform.CanCollide = true

	return {
		islandCenter = Vector3.new(cx, platformY, cz),
		topY         = topY,
		radius       = radius,
	}
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

	-- Clear kill border (tagged as part of Generated or separate)
	local border = mapFolder:FindFirstChild("KillBorder")
	if border then border:Destroy() end
end

return MapGenerator
