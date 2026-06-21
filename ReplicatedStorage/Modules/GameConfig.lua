-- ModuleScript: ReplicatedStorage > Modules > GameConfig
return {
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 4,

	-- Setup phase (before PLAYING begins)
	SETUP_DURATION = 60,          -- seconds to place Soul Crystal and build base

	-- Soul Crystal (anchor) settings
	ANCHOR_MAX_HP        = 5,     -- hits to destroy
	ANCHOR_MINE_COOLDOWN = 1,     -- seconds between hits by the same miner

	-- Death-with-anchor penalty
	RESPAWN_DELAY    = 4,         -- seconds before respawn at anchor
	DEATH_LOSS_RATE  = 0.25,      -- fraction of total inventory randomly dropped

	SWAP_INTERVAL    = 90,
	MIN_SWAP_INTERVAL = 25,
	SWAP_REDUCTION   = 10,
	SWAP_COUNTDOWN   = 10,        -- seconds of dramatic countdown before each swap

	ROUND_DURATION    = 600,
	LOBBY_COUNTDOWN   = 15,
	RESULTS_DURATION  = 10,

	GRID_SIZE   = 4,
	PLACE_RANGE = 25,

	-- Voxel terrain settings
	ISLAND_RADIUS        = 100,   -- studs from center to edge
	ISLAND_Y             = 100,   -- base Y of terrain bottom (bedrock)
	TERRAIN_WALL_HEIGHT  = 800,   -- perimeter barrier height in studs (very tall — impossible to escape)
	PLACE_HEIGHT_LIMIT   = 40,    -- max studs above island surface players can build

	-- Order matters: index 1-9 maps to hotbar slots (1-6 combat, 7-9 terrain)
	BLOCK_TYPES = {
		{ id = "Stone",    material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(130, 130, 130) },
		{ id = "Wood",     material = Enum.Material.Wood,          color = Color3.fromRGB(160, 120, 60)  },
		{ id = "Obsidian", material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(30,  20,  50)  },
		{ id = "Lava",     material = Enum.Material.Neon,          color = Color3.fromRGB(255, 60,  0),  damagePer  = 20  },
		{ id = "Spike",    material = Enum.Material.Metal,         color = Color3.fromRGB(180, 180, 200), damageOnce = 50  },
		{ id = "TNT",      material = Enum.Material.Neon,          color = Color3.fromRGB(220, 30,  30),  explode    = true },
		{ id = "Grass",    material = Enum.Material.Grass,         color = Color3.fromRGB(90,  150, 60)  },
		{ id = "Dirt",     material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(120, 80,  40)  },
		{ id = "Rock",     material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(100, 100, 110) },
	},

	-- Hits required to break each block type with right-click/E-key
	BLOCK_HP = {
		Stone    = 75,   -- building block (5× longer decay)
		Wood     = 25,   -- building block (5× longer decay)
		Obsidian = 200,  -- building block (5× longer decay)
		Lava     = 1,    -- trap: unchanged
		Spike    = 2,    -- trap: unchanged
		TNT      = 1,    -- trap: unchanged
		Grass    = 25,   -- building block (5× longer decay)
		Dirt     = 50,   -- building block (5× longer decay)
		Rock     = 75,   -- building block (5× longer decay)
	},

	STARTING_INVENTORY = {
		Stone    = 20,
		Wood     = 15,
		Obsidian = 3,
		Lava     = 3,
		Spike    = 5,
		TNT      = 2,
		Grass    = 0,
		Dirt     = 0,
		Rock     = 0,
	},

	-- Terrain layer definitions (bottom to top, each 4 studs tall)
	-- BEDROCK is layer 0 (indestructible), not in BLOCK_TYPES
	TERRAIN_LAYERS = {
		{ id = "Rock",  yIndex = 1 },  -- layer 1 above bedrock
		{ id = "Dirt",  yIndex = 2 },
		{ id = "Grass", yIndex = 3 },  -- top layer
	},

	-- Armor tiers: equip one at a time, reduces incoming damage by reduction (0–1)
	ARMOR_TYPES = {
		{ id = "Leather", reduction = 0.20, color = Color3.fromRGB(150, 100, 60),  cost = 50  },
		{ id = "Iron",    reduction = 0.40, color = Color3.fromRGB(180, 185, 190), cost = 120 },
	},
}
