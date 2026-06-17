-- ModuleScript: ReplicatedStorage > Modules > GameConfig
return {
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 4,

	SWAP_INTERVAL    = 90,   -- seconds between swaps at round start
	MIN_SWAP_INTERVAL = 20,  -- floor: never faster than this
	SWAP_REDUCTION   = 10,   -- subtract this each time a swap fires

	ROUND_DURATION    = 600, -- max round length in seconds (10 min)
	LOBBY_COUNTDOWN   = 15,
	RESULTS_DURATION  = 10,

	GRID_SIZE   = 4,  -- block size in studs (also grid snap unit)
	PLACE_RANGE = 25, -- max studs from player to place/remove

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
