-- ModuleScript: ReplicatedStorage > Modules > MapManager
local MapManager = {}

local function getMapFolder()
	return workspace:FindFirstChild("Map")
end

-- Destroy all blocks placed during the round
function MapManager.reset()
	local map = getMapFolder()
	if not map then return end
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
