-- ModuleScript: ReplicatedStorage > Modules > MapManager
local MapManager = {}

-- MapGenerator is a server-only module; require lazily so this module
-- can still be required on the client without erroring.
local MapGenerator = nil
local function getGenerator()
	if MapGenerator then return MapGenerator end
	local ok, mod = pcall(function()
		return require(game:GetService("ServerScriptService").MapGenerator)
	end)
	if ok then MapGenerator = mod end
	return MapGenerator
end

local BORDER_SIZE = 150  -- studs from center to kill-wall

local function getMapFolder()
	local map = workspace:FindFirstChild("Map")
	if not map then
		map = Instance.new("Folder")
		map.Name   = "Map"
		map.Parent = workspace
	end
	return map
end

-- Generate a fresh random island for the round (server only)
function MapManager.generate()
	local map = getMapFolder()
	local gen = getGenerator()
	if gen then
		local info = gen.generate(map)
		gen.buildKillBorder(map, BORDER_SIZE)
		return info
	end
end

-- Destroy all blocks placed during the round AND the generated island
function MapManager.reset()
	local map = getMapFolder()
	if not map then return end

	local gen = getGenerator()
	if gen then gen.clear(map) end

	local builds = map:FindFirstChild("PlayerBuilds")
	if builds then
		for _, child in ipairs(builds:GetChildren()) do
			child:Destroy()
		end
	end
end

-- Returns a table of CFrame values for each spawn point Part
function MapManager.getSpawnCFrames()
	local map = getMapFolder()
	local cframes = {}
	if not map then return cframes end
	local spawnFolder = map:FindFirstChild("SpawnPoints")
	if not spawnFolder then return cframes end
	for _, part in ipairs(spawnFolder:GetChildren()) do
		if part:IsA("BasePart") then
			-- Offset upward so the character spawns above the part surface
			table.insert(cframes, part.CFrame + Vector3.new(0, 5, 0))
		end
	end
	return cframes
end

-- Returns the PlayerBuilds folder (creates it if missing)
function MapManager.getBuildsFolder()
	local map = getMapFolder()
	if not map then return nil end
	local builds = map:FindFirstChild("PlayerBuilds")
	if not builds then
		builds = Instance.new("Folder")
		builds.Name = "PlayerBuilds"
		builds.Parent = map
	end
	return builds
end

return MapManager
