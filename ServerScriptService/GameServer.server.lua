-- Script: ServerScriptService > GameServer
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig       = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MapManager       = require(ReplicatedStorage:WaitForChild("MapManager"))
local InventoryManager = require(ServerScriptService.InventoryManager)
local DataManager      = require(ServerScriptService.DataManager)
local GameState        = require(ServerScriptService.GameState)
local AnchorManager    = require(ServerScriptService.AnchorManager)
local ArmorManager     = require(ServerScriptService.ArmorManager)
local CurrencyManager  = require(ServerScriptService.CurrencyManager)
local ShopManager      = require(ServerScriptService.ShopManager)
local ToolManager      = require(ServerScriptService.ToolManager)
local GemManager       = require(ServerScriptService.GemManager)
local KitManager       = require(ServerScriptService.KitManager)
local RoundStats       = require(ServerScriptService.RoundStats)

local RemoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local SwapPlayers        = RemoteEvents:WaitForChild("SwapPlayers")
local RoundStateChanged  = RemoteEvents:WaitForChild("RoundStateChanged")
local UpdateTimers       = RemoteEvents:WaitForChild("UpdateTimers")
local UpdateInventory    = RemoteEvents:WaitForChild("UpdateInventory")
local PlayerRespawning   = RemoteEvents:WaitForChild("PlayerRespawning")
local PlayerEliminated   = RemoteEvents:WaitForChild("PlayerEliminated")
local EquipArmor         = RemoteEvents:WaitForChild("EquipArmor")
local ArmorEquipped      = RemoteEvents:WaitForChild("ArmorEquipped")
local UpdateCurrency     = RemoteEvents:WaitForChild("UpdateCurrency")
local OpenShop           = RemoteEvents:WaitForChild("OpenShop")
local StartTestMode      = RemoteEvents:WaitForChild("StartTestMode")
local UpdateGems          = RemoteEvents:WaitForChild("UpdateGems")

ShopManager.init(RemoteEvents, UpdateInventory, UpdateCurrency)

local function wireShopPrompts()
	local map   = workspace:FindFirstChild("Map")
	if not map then return end
	local shops = map:FindFirstChild("Shops")
	if not shops then return end
	for _, desc in ipairs(shops:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc.Triggered:Connect(function(player)
				OpenShop:FireClient(player, CurrencyManager.get(player))
			end)
		end
	end
end

Players.CharacterAutoLoads = false

-- ========== Armor equip handler ==========

EquipArmor.OnServerEvent:Connect(function(player, armorId)
	local inv = InventoryManager.get(player)
	if not inv or (inv[armorId] or 0) < 1 then return end
	if ArmorManager.equip(player, armorId) then
		InventoryManager.deduct(player, armorId)
		UpdateInventory:FireClient(player, InventoryManager.get(player))
		ArmorEquipped:FireClient(player, armorId, ArmorManager.getReduction(player))
	end
end)

-- ========== Bot factory (test mode only) ==========

local testModeActive = false
local botSet         = {}    -- game bots (test mode)

local function makeBotModel(name, spawnCF, labelText, labelColor)
	local model = Instance.new("Model")
	model.Name  = name

	local hrp = Instance.new("Part")
	hrp.Name         = "HumanoidRootPart"
	hrp.Size         = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame       = spawnCF * CFrame.new(0, 5, 0)
	hrp.Parent       = model
	model.PrimaryPart = hrp

	local torso = Instance.new("Part")
	torso.Name   = "Torso"
	torso.Size   = Vector3.new(2, 2, 1)
	torso.Color  = Color3.fromRGB(180, 50, 50)
	torso.CFrame = hrp.CFrame
	torso.Parent = model
	local wt = Instance.new("WeldConstraint")
	wt.Part0 = hrp; wt.Part1 = torso; wt.Parent = hrp

	local head = Instance.new("Part")
	head.Name   = "Head"
	head.Size   = Vector3.new(2, 1, 1)
	head.Color  = Color3.fromRGB(255, 200, 150)
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
	head.Parent = model
	local wh = Instance.new("WeldConstraint")
	wh.Part0 = torso; wh.Part1 = head; wh.Parent = torso

	local gui = Instance.new("BillboardGui")
	gui.Size        = UDim2.new(0, 120, 0, 40)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.Parent      = hrp
	local lbl = Instance.new("TextLabel", gui)
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = labelColor or Color3.fromRGB(255, 80, 80)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = labelText or "BOT"

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health    = 100
	hum.Parent    = model

	model.Parent = workspace
	return model, hum
end

local function spawnTestBot(spawnCF)
	local model, hum = makeBotModel("TestBot", spawnCF, "TEST BOT", Color3.fromRGB(255, 80, 80))
	hum.Died:Connect(function() botSet[model] = nil end)
	return model
end

local function clearBots()
	for model in pairs(botSet) do
		pcall(function() model:Destroy() end)
	end
	botSet = {}
end

StartTestMode.OnServerEvent:Connect(function()
	if GameState.current ~= "LOBBY" then return end
	if #Players:GetPlayers() < 1 then return end
	testModeActive = true
end)

-- ========== State ==========

local aliveSet       = {}
local respawningSet  = {}
local deathConns     = {}
local playerSpawnCFs = {}
local lastSwapTime   = 0  -- tick() of most recent swap, for swap-kill bonus

local function countAlive()
	local n = 0
	for _, v in pairs(aliveSet) do if v then n += 1 end end
	for _, v in pairs(botSet)   do if v then n += 1 end end
	return n
end

local function getAlivePlayers()
	local list = {}
	for p, alive in pairs(aliveSet) do
		if alive then table.insert(list, p) end
	end
	return list
end

-- ========== Spawn helpers ==========

local function spawnPlayer(player, spawnCF)
	player:LoadCharacter()
	task.wait(0.2)
	local char = player.Character
	if char and char.Parent and spawnCF then
		char:PivotTo(spawnCF)
	end
end

-- Spawn a single player into the lobby with starting items
local function spawnPlayerInLobby(player)
	InventoryManager.reset(player)
	CurrencyManager.reset(player)
	UpdateInventory:FireClient(player, InventoryManager.get(player))
	UpdateCurrency:FireClient(player, CurrencyManager.get(player))
	UpdateGems:FireClient(player, GemManager.get(player))
	ToolManager.giveWeapons(player, "Wood", "Wood")
	KitManager.reapply(player)
	local cframes = MapManager.getSpawnCFrames()
	local cf = #cframes > 0 and cframes[math.random(1, #cframes)] or CFrame.new(0, 130, 0)
	spawnPlayer(player, cf)
end

local function spawnAllPlayersInLobby()
	for _, player in ipairs(Players:GetPlayers()) do
		spawnPlayerInLobby(player)
	end
end

local function spawnAllPlayers()
	local cframes = MapManager.getSpawnCFrames()
	for i = #cframes, 2, -1 do
		local j = math.random(1, i)
		cframes[i], cframes[j] = cframes[j], cframes[i]
	end

	local list = Players:GetPlayers()
	local n    = #cframes

	for i, player in ipairs(list) do
		aliveSet[player] = true
		InventoryManager.reset(player)
		CurrencyManager.reset(player)
		UpdateInventory:FireClient(player, InventoryManager.get(player))
		UpdateCurrency:FireClient(player, CurrencyManager.get(player))
		UpdateGems:FireClient(player, GemManager.get(player))
		ToolManager.giveWeapons(player, "Wood", "Wood")
		KitManager.reapply(player)
		local cf = n > 0 and cframes[((i - 1) % n) + 1] or nil
		playerSpawnCFs[player] = cf
		spawnPlayer(player, cf)
	end
end

-- ========== Death connection ==========

local connectDeath

connectDeath = function(player)
	if deathConns[player] then
		deathConns[player]:Disconnect()
		deathConns[player] = nil
	end

	local char = player.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end

	deathConns[player] = hum.Died:Connect(function()
		if GameState.current == "SETUP" then
			task.delay(2, function()
				if aliveSet[player] == nil then return end
				local cf
				if AnchorManager.hasAnchor(player) then
					cf = AnchorManager.getSpawnCF(player)
				else
					cf = playerSpawnCFs[player]
				end
				spawnPlayer(player, cf)
			end)
			return
		end

		if GameState.current ~= "PLAYING" then return end
		if not aliveSet[player] then return end

		local deathPos = Vector3.new(0, 120, 0)
		local deathChar = player.Character
		if deathChar and deathChar:FindFirstChild("HumanoidRootPart") then
			deathPos = deathChar.HumanoidRootPart.Position
		end
		ToolManager.dropWeaponsAt(player, deathPos)

		if AnchorManager.hasAnchor(player) then
			respawningSet[player] = true
			InventoryManager.loseRandom(player, GameConfig.DEATH_LOSS_RATE)
			UpdateInventory:FireClient(player, InventoryManager.get(player))
			PlayerRespawning:FireClient(player, GameConfig.RESPAWN_DELAY)

			task.delay(GameConfig.RESPAWN_DELAY, function()
				respawningSet[player] = nil
				if not aliveSet[player] then return end
				local spawnCF = AnchorManager.getSpawnCF(player)
				spawnPlayer(player, spawnCF)
				ToolManager.giveWeapons(player, "Wood", "Wood")
			end)
		else
			-- Permanent elimination
			aliveSet[player] = false
			DataManager.recordLoss(player)
			PlayerEliminated:FireAllClients(player.Name)

			-- Award 3 gems to all surviving players
			for _, survivor in ipairs(getAlivePlayers()) do
				local newGems = GemManager.add(survivor, 3)
				RoundStats.addGems(survivor, 3)
				UpdateGems:FireClient(survivor, newGems)
			end

			-- Swap-kill bonus: 25 coins if death happened within 5s of last swap
			if tick() - lastSwapTime <= 5 then
				for _, survivor in ipairs(getAlivePlayers()) do
					local newBal = CurrencyManager.add(survivor, CurrencyManager.COINS_ON_SWAP_KILL)
					UpdateCurrency:FireClient(survivor, newBal)
				end
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		connectDeath(player)
		task.wait(0.1)
		ArmorManager.reapply(player)
		KitManager.reapply(player)
	end)
	-- Spawn immediately in lobby so new arrivals can join and play
	if GameState.current == "LOBBY" then
		task.wait(1)  -- short wait for character system to init
		spawnPlayerInLobby(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	aliveSet[player]       = nil
	respawningSet[player]  = nil
	playerSpawnCFs[player] = nil
	if deathConns[player] then
		deathConns[player]:Disconnect()
		deathConns[player] = nil
	end
	InventoryManager.clear(player)
	AnchorManager.clear(player)
	ArmorManager.clear(player)
	CurrencyManager.clear(player)
	KitManager.clearPlayer(player)
end)

-- ========== Swap logic ==========

local function doSwap()
	local entities  = {}
	local positions = {}

	for _, p in ipairs(getAlivePlayers()) do
		local char = p.Character
		if char and char.Parent and not respawningSet[p] then
			local capturedChar = char
			table.insert(entities,  { move = function(cf) capturedChar:PivotTo(cf * CFrame.new(0, 3, 0)) end })
			table.insert(positions, char:GetPivot())
		else
			local fallback = AnchorManager.getSpawnCF(p) or CFrame.new(0, 50, 0)
			table.insert(entities,  { move = function() end })
			table.insert(positions, fallback)
		end
	end

	for model, isAlive in pairs(botSet) do
		if isAlive then
			local capturedModel = model
			table.insert(entities,  { move = function(cf) capturedModel:PivotTo(cf * CFrame.new(0, 3, 0)) end })
			table.insert(positions, model:GetPivot())
		end
	end

	local n = #entities
	if n < 2 then return end

	for i, ent in ipairs(entities) do
		ent.move(positions[i % n + 1])
	end

	lastSwapTime = tick()
	SwapPlayers:FireAllClients()
end

-- ========== State helpers ==========

local function setState(state, data)
	GameState.current = state
	RoundStateChanged:FireAllClients(state, data)
end

-- ========== Helpers ==========

local function waitForMinPlayers()
	while #Players:GetPlayers() < GameConfig.MIN_PLAYERS and not testModeActive do
		task.wait(1)
	end
end

local function runLobbyCountdown()
	for i = GameConfig.LOBBY_COUNTDOWN, 1, -1 do
		UpdateTimers:FireAllClients(i, 0, 0)
		task.wait(1)
		if #Players:GetPlayers() < GameConfig.MIN_PLAYERS then
			return false
		end
	end
	return true
end

local function runSetupPhase()
	setState("SETUP")
	for i = GameConfig.SETUP_DURATION, 1, -1 do
		UpdateTimers:FireAllClients(0, GameConfig.ROUND_DURATION, i)
		task.wait(1)
	end
end

-- ========== Main game loop ==========

while true do
	-- ── LOBBY PHASE ──────────────────────────────────────────────────────────
	setState("LOBBY")
	testModeActive = false
	clearBots()

	MapManager.reset()
	MapManager.generate()
	wireShopPrompts()
	AnchorManager.clearAll()

	spawnAllPlayersInLobby()

	-- Wait for enough players (teleported in from the lobby experience)
	waitForMinPlayers()

	-- ── TRANSITION TO GAME ────────────────────────────────────────────────────
	setState("COUNTDOWN")

	MapManager.reset()
	clearBots()
	MapManager.generate()
	wireShopPrompts()
	AnchorManager.clearAll()
	RoundStats.reset()
	aliveSet       = {}
	respawningSet  = {}
	playerSpawnCFs = {}

	spawnAllPlayers()

	if testModeActive then
		local cframes = MapManager.getSpawnCFrames()
		if #cframes > 0 then
			local botModel = spawnTestBot(cframes[#cframes])
			botSet[botModel] = true
		end
	end

	runSetupPhase()

	setState("PLAYING")

	local swapTimer       = 0
	local roundTimer      = 0
	local currentInterval = GameConfig.SWAP_INTERVAL

	while roundTimer < GameConfig.ROUND_DURATION and countAlive() >= 2 do
		task.wait(1)
		roundTimer += 1
		swapTimer  += 1

		local timeToSwap = currentInterval - swapTimer
		local timeLeft   = GameConfig.ROUND_DURATION - roundTimer
		UpdateTimers:FireAllClients(timeToSwap, timeLeft, 0)

		for _, p in ipairs(getAlivePlayers()) do
			local newBal = CurrencyManager.add(p, CurrencyManager.COINS_PER_SECOND)
			UpdateCurrency:FireClient(p, newBal)
		end

		if swapTimer >= currentInterval then
			swapTimer = 0
			doSwap()
			currentInterval = math.max(
				currentInterval - GameConfig.SWAP_REDUCTION,
				GameConfig.MIN_SWAP_INTERVAL
			)
		end
	end

	-- RESULTS: award MVP gems and winner bonus
	local survivors  = getAlivePlayers()
	local winnerName = "No one"
	local winner     = nil

	if #survivors == 1 then
		winner     = survivors[1]
		winnerName = winner.Name
		DataManager.recordWin(winner)
	elseif #survivors > 1 then
		winnerName = "Draw"
	elseif next(botSet) ~= nil then
		winnerName = "No one (bot survived)"
	end

	-- MVP: most damage dealt
	local mvpDmg = RoundStats.getMVP_Damage()
	if mvpDmg then
		local g = GemManager.add(mvpDmg, 2)
		UpdateGems:FireClient(mvpDmg, g)
	end

	-- MVP: most blocks placed
	local mvpBlocks = RoundStats.getMVP_Blocks()
	if mvpBlocks and mvpBlocks ~= mvpDmg then
		local g = GemManager.add(mvpBlocks, 2)
		UpdateGems:FireClient(mvpBlocks, g)
	end

	-- Winner bonus: 5 gems flat + 25% of gems earned this round
	if winner then
		local roundGems = RoundStats.getTotalGems(winner)
		local bonus     = 5 + math.floor(roundGems * 0.25)
		local g = GemManager.add(winner, bonus)
		UpdateGems:FireClient(winner, g)
	end

	setState("RESULTS", winnerName)

	task.wait(GameConfig.RESULTS_DURATION)

	for _, player in ipairs(Players:GetPlayers()) do
		InventoryManager.clear(player)
		AnchorManager.clear(player)
		ArmorManager.clear(player)
		if player.Character then player.Character:Destroy() end
	end
	clearBots()
end
