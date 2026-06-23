-- ModuleScript: ServerScriptService > LobbyMapGenerator
-- Builds the full lobby island at runtime: hub + 4 zones

local LobbyMapGenerator = {}

local FLOOR_Y = 0  -- Y of the island's top walking surface

local mapFolder

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function p(name, size, cf, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name           = name
	part.Anchored       = true
	part.CanCollide     = (canCollide ~= false)
	part.Size           = size
	part.CFrame         = cf
	part.Color          = color or Color3.fromRGB(140, 140, 140)
	part.Material       = material or Enum.Material.SmoothPlastic
	part.TopSurface     = Enum.SurfaceType.Smooth
	part.BottomSurface  = Enum.SurfaceType.Smooth
	part.Parent         = mapFolder
	return part
end

local function billboard(adornee, text, studsUp, w, h, textColor)
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, w or 220, 0, h or 60)
	bb.StudsOffset = Vector3.new(0, studsUp or 4, 0)
	bb.MaxDistance = 100
	bb.Parent      = adornee

	local bg = Instance.new("Frame", bb)
	bg.Size                   = UDim2.fromScale(1, 1)
	bg.BackgroundColor3       = Color3.fromRGB(10, 10, 22)
	bg.BackgroundTransparency = 0.15
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

	local lbl = Instance.new("TextLabel", bg)
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = textColor or Color3.new(1, 1, 1)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = text
	lbl.TextWrapped            = true
	return lbl
end

local function zoneTag(part, tag)
	local v = Instance.new("StringValue")
	v.Name   = "ZoneTag"
	v.Value  = tag
	v.Parent = part
end

-- ── Generate ──────────────────────────────────────────────────────────────────

function LobbyMapGenerator.generate()
	mapFolder = workspace:WaitForChild("LobbyMap")
	mapFolder:ClearAllChildren()

	local F = FLOOR_Y

	-- ════════════════════════════════════════════════════════════════
	-- MAIN ISLAND  (420×420, top surface at Y=0)
	-- ════════════════════════════════════════════════════════════════
	p("IslandGrass", Vector3.new(420, 8, 420), CFrame.new(0, F-4, 0),
		Color3.fromRGB(88, 148, 55), Enum.Material.Grass)
	p("IslandDirt", Vector3.new(410, 16, 410), CFrame.new(0, F-16, 0),
		Color3.fromRGB(112, 76, 40))
	p("IslandRock", Vector3.new(395, 12, 395), CFrame.new(0, F-30, 0),
		Color3.fromRGB(88, 86, 88))

	-- SpawnLocation (hub center, players load here)
	local sl = Instance.new("SpawnLocation")
	sl.Name      = "HubSpawn"
	sl.Size      = Vector3.new(8, 1, 8)
	sl.CFrame    = CFrame.new(0, F + 0.5, 0)
	sl.Anchored  = true
	sl.Neutral   = true
	sl.Duration  = 0
	sl.BrickColor = BrickColor.new("Medium stone grey")
	sl.Material  = Enum.Material.SmoothPlastic
	sl.TopSurface = Enum.SurfaceType.Smooth
	sl.Parent    = mapFolder

	-- ════════════════════════════════════════════════════════════════
	-- HUB  (center raised stone circle)
	-- ════════════════════════════════════════════════════════════════
	p("HubPlatform", Vector3.new(55, 1, 55), CFrame.new(0, F+0.5, 0),
		Color3.fromRGB(148, 148, 158))

	-- DEATHSWAP title sign on a pillar
	p("TitlePillar", Vector3.new(3, 26, 3), CFrame.new(0, F+14, 0),
		Color3.fromRGB(55, 55, 65), Enum.Material.SmoothPlastic, false)
	local titleSign = p("TitleSign", Vector3.new(65, 13, 2),
		CFrame.new(0, F+28, 0),
		Color3.fromRGB(12, 8, 28), Enum.Material.SmoothPlastic, false)
	billboard(titleSign, "DEATHSWAP LOBBY", 0, 560, 90, Color3.fromRGB(255, 80, 80))

	-- 4 teleport pads + paths
	local padDefs = {
		{ name="PlayPad",     x=0,    z=-72,  color=Color3.fromRGB(30, 210, 80),   label="▶  PLAY",     zone="play"     },
		{ name="KitPad",      x=72,   z=0,    color=Color3.fromRGB(160, 60, 225),  label="⚙  KITS",     zone="kits"     },
		{ name="PracticePad", x=0,    z=72,   color=Color3.fromRGB(220, 100, 30),  label="⚔  PRACTICE", zone="practice" },
		{ name="ObbyPad",     x=-72,  z=0,    color=Color3.fromRGB(55, 140, 220),  label="🏃 OBBY",     zone="obby"     },
	}
	local pathDefs = {
		{ size=Vector3.new(10,1,88),  cf=CFrame.new(0,   F+0.5, -100) },
		{ size=Vector3.new(88,1,10),  cf=CFrame.new(100, F+0.5, 0)    },
		{ size=Vector3.new(10,1,88),  cf=CFrame.new(0,   F+0.5, 100)  },
		{ size=Vector3.new(70,1,10),  cf=CFrame.new(-85, F+0.5, 0)    },
	}
	for _, pd in ipairs(pathDefs) do
		p("Path", pd.size, pd.cf, Color3.fromRGB(128, 128, 138))
	end
	for _, pd in ipairs(padDefs) do
		local pad = p(pd.name, Vector3.new(20, 2, 20),
			CFrame.new(pd.x, F+2, pd.z),
			pd.color, Enum.Material.Neon)
		zoneTag(pad, pd.zone)
		billboard(pad, pd.label, 6, 230, 58, pd.color)
	end

	-- ════════════════════════════════════════════════════════════════
	-- PLAY ZONE  (north, Z ≈ -165)
	-- ════════════════════════════════════════════════════════════════
	local PX, PZ = 0, -165
	p("PlayFloor", Vector3.new(95, 2, 95), CFrame.new(PX, F+1, PZ),
		Color3.fromRGB(20, 62, 32))

	-- glowing portal ring
	local portalR = 18
	for i = 1, 16 do
		local a = (i/16) * math.pi * 2
		p("PortalRing"..i, Vector3.new(4,4,4),
			CFrame.new(PX + math.cos(a)*portalR, F+22 + math.sin(a)*portalR, PZ),
			Color3.fromRGB(30, 210, 80), Enum.Material.Neon, false)
	end

	-- queue scoreboard billboard
	local qBoard = p("QueueBoard", Vector3.new(75, 28, 2),
		CFrame.new(PX, F+17, PZ-44),
		Color3.fromRGB(10, 10, 22), Enum.Material.SmoothPlastic, false)
	local qLbl = billboard(qBoard, "Waiting for players...", 0, 650, 240,
		Color3.fromRGB(100, 255, 140))
	qLbl.Name = "QueueText"   -- server writes to this

	-- ════════════════════════════════════════════════════════════════
	-- KIT ZONE  (east, X ≈ 165)
	-- ════════════════════════════════════════════════════════════════
	local KX, KZ = 165, 0
	p("KitFloor", Vector3.new(140, 2, 95), CFrame.new(KX, F+1, KZ),
		Color3.fromRGB(33, 20, 52))

	local kitZoneSign = p("KitZoneSign", Vector3.new(90, 12, 2),
		CFrame.new(KX, F+18, KZ-44),
		Color3.fromRGB(12, 8, 26), Enum.Material.SmoothPlastic, false)
	billboard(kitZoneSign, "KIT SHOP  ·  100 gems each", 0, 700, 100,
		Color3.fromRGB(190, 110, 255))

	local KIT_DEFS = {
		{ id="Speed",   color=Color3.fromRGB(80,  180, 255), desc="+15% Move Speed"  },
		{ id="Jump",    color=Color3.fromRGB(120, 255, 120), desc="+20% Jump Power"  },
		{ id="Miner",   color=Color3.fromRGB(255, 180, 60),  desc="+50% Mine Speed"  },
		{ id="Healer",  color=Color3.fromRGB(255, 100, 180), desc="2 HP/s Regen"     },
		{ id="Trapper", color=Color3.fromRGB(200, 80,  255), desc="+25% Trap Dmg"    },
	}
	for i, kit in ipairs(KIT_DEFS) do
		local kx = 108 + (i-1) * 28
		local ped = p("KitPedestal_"..kit.id, Vector3.new(20, 6, 20),
			CFrame.new(kx, F+4, KZ),
			Color3.fromRGB(38, 28, 58))
		p("KitGem_"..kit.id, Vector3.new(8, 8, 8),
			CFrame.new(kx, F+11, KZ),
			kit.color, Enum.Material.Neon, false)
		billboard(ped, kit.id.."\n"..kit.desc.."\n♦ 100", 9, 210, 90, kit.color)

		local kv = Instance.new("StringValue")
		kv.Name = "KitId"; kv.Value = kit.id; kv.Parent = ped

		local pp = Instance.new("ProximityPrompt")
		pp.ActionText  = "Equip Kit"
		pp.ObjectText  = kit.id.." Kit"
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.MaxActivationDistance = 10
		pp.Parent = ped
	end

	-- ════════════════════════════════════════════════════════════════
	-- PRACTICE ZONE  (south, Z ≈ 165)
	-- ════════════════════════════════════════════════════════════════
	local AX, AZ = 0, 165
	local AW, AD = 120, 120
	p("PracticeFloor", Vector3.new(AW, 2, AD), CFrame.new(AX, F+1, AZ),
		Color3.fromRGB(52, 33, 33))
	local wH = 24
	for i, wd in ipairs({
		{ Vector3.new(AW+8, wH, 4), CFrame.new(AX,       F+wH/2+2, AZ+AD/2)  },
		{ Vector3.new(AW+8, wH, 4), CFrame.new(AX,       F+wH/2+2, AZ-AD/2)  },
		{ Vector3.new(4, wH, AD),   CFrame.new(AX+AW/2,  F+wH/2+2, AZ)       },
		{ Vector3.new(4, wH, AD),   CFrame.new(AX-AW/2,  F+wH/2+2, AZ)       },
	}) do
		p("ArenaWall"..i, wd[1], wd[2], Color3.fromRGB(68, 42, 42))
	end
	local pracSign = p("PracticeSign", Vector3.new(80, 14, 2),
		CFrame.new(AX, F+19, AZ-AD/2-2),
		Color3.fromRGB(14, 9, 9), Enum.Material.SmoothPlastic, false)
	billboard(pracSign, "PRACTICE ARENA\nFight bots — warm up before the match", 0, 680, 130,
		Color3.fromRGB(255, 130, 60))

	-- ════════════════════════════════════════════════════════════════
	-- OBBY ZONE  (west, platforms extending from X=-145)
	-- ════════════════════════════════════════════════════════════════
	local obbySign = p("ObbySign", Vector3.new(55, 12, 2),
		CFrame.new(-152, F+12, 0),
		Color3.fromRGB(10, 28, 58), Enum.Material.SmoothPlastic, false)
	billboard(obbySign, "OBSTACLE COURSE\nFinish for +5 gems!", 0, 500, 110,
		Color3.fromRGB(80, 180, 255))

	local platforms = {
		--  x       y         z    w   d
		{ -162,  F,      0,   22, 22 },   -- launch pad (on island)
		{ -198,  F+6,    18,  14, 14 },
		{ -230,  F+12,  -16,  12, 12 },
		{ -262,  F+18,   12,  11, 11 },
		{ -294,  F+14,  -18,  10, 10 },
		{ -326,  F+20,   10,   9,  9 },
		{ -358,  F+26,   -8,   9,  9 },
		{ -390,  F+22,   20,   9,  9 },
		{ -422,  F+28,   -5,   9,  9 },
		{ -454,  F+24,   12,   9,  9 },
		{ -486,  F+30,  -14,   9,  9 },
		{ -515,  F+18,    0,  24, 24 },   -- finish
	}
	local obbyColors = {
		Color3.fromRGB(50, 105, 195),
		Color3.fromRGB(68, 148, 228),
		Color3.fromRGB(88, 178, 255),
	}
	for i, ob in ipairs(platforms) do
		local isFinish = (i == #platforms)
		local col = isFinish and Color3.fromRGB(255, 200, 30)
		            or obbyColors[((i-1) % #obbyColors) + 1]
		local plat = p(isFinish and "ObbyFinish" or ("ObbyPlat"..i),
			Vector3.new(ob[4], 2, ob[5]),
			CFrame.new(ob[1], ob[2], ob[3]),
			col)
		if isFinish then
			zoneTag(plat, "obbyfinish")
			local fs = p("FinishSign", Vector3.new(32, 12, 2),
				CFrame.new(ob[1], ob[2]+9, ob[3]-14),
				Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic, false)
			billboard(fs, "FINISH!\n+5 Gems", 0, 300, 110, Color3.fromRGB(255, 215, 0))
		end
	end

	return mapFolder
end

-- ── Accessors (used by LobbyServer) ──────────────────────────────────────────

function LobbyMapGenerator.getZoneCFrames()
	local F = FLOOR_Y
	return {
		hub      = CFrame.new(  0, F+4,    0),
		play     = CFrame.new(  0, F+4, -155),
		kits     = CFrame.new(142, F+4,    0),
		practice = CFrame.new(  0, F+4,  152),
		obby     = CFrame.new(-152, F+4,   0),
	}
end

function LobbyMapGenerator.getPracticeSpawns()
	local F = FLOOR_Y
	return {
		CFrame.new( 28, F+3, 152),
		CFrame.new(-28, F+3, 152),
		CFrame.new( 28, F+3, 178),
		CFrame.new(-28, F+3, 178),
		CFrame.new(  0, F+3, 195),
		CFrame.new( 44, F+3, 165),
		CFrame.new(-44, F+3, 165),
		CFrame.new(  0, F+3, 138),
	}
end

return LobbyMapGenerator
