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

	-- Order matters: index 1-5 maps to hotbar slots 1-5
	BLOCK_TYPES = {
		{ id = "Stone", material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(130, 130, 130) },
		{ id = "Wood",  material = Enum.Material.Wood,          color = Color3.fromRGB(160, 120, 60)  },
		{ id = "Lava",  material = Enum.Material.Neon,          color = Color3.fromRGB(255, 60,  0),  damagePer  = 20  },
		{ id = "Spike", material = Enum.Material.Metal,         color = Color3.fromRGB(180, 180, 200), damageOnce = 50  },
		{ id = "TNT",   material = Enum.Material.Neon,          color = Color3.fromRGB(220, 30,  30),  explode    = true },
	},

	STARTING_INVENTORY = {
		Stone = 20,
		Wood  = 15,
		Lava  = 3,
		Spike = 5,
		TNT   = 2,
	},
}
