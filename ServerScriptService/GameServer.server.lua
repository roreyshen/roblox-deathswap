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
local ArmorManager      = require(ServerScriptService.ArmorManager)
local CurrencyManager   = require(ServerScriptService.CurrencyManager)

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

Players.CharacterAutoLoads = false

-- ========== Armor equip handler ==========

EquipArmor.OnServerEvent:Connect(function(player, armorId)
	local inv = InventoryManager.get(player)
	if not inv or (inv[armorId] or 0) < 1 then return end
	if ArmorManager.equip(player, armorId) then
		InventoryManager.deduct(player, armorId)
		UpdateInventory:FireClient(player, InventoryManager.get(player))
		ArmorEquipped:FireClient(player, armorId, ArmorManager.getBonusHP(player))
	end
end)

-- ========== State ==========

local aliveSet      = {}  -- [Player] = true while alive this round
local respawningSet = {}  -- [Player] = true while counting down to anchor respawn
local deathConns    = {}  -- [Player] = RBXScriptConnection

local function countAlive()
	local n = 0
	for _, v in pairs(aliveSet) do if v then n += 1 end end
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
		local cf = n > 0 and cframes[((i - 1) % n) + 1] or nil
		spawnPlayer(player, cf)
	end
end

-- ========== Death connection ==========

local connectDeath  -- forward-declared so the closure below can reference it

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
		-- ---- SETUP phase: free respawn at a spawn point ----
		if GameState.current == "SETUP" then
			task.delay(2, function()
				if aliveSet[player] == nil then return end
				local cfs = MapManager.getSpawnCFrames()
				local cf  = #cfs > 0 and cfs[math.random(1, #cfs)] or nil
				spawnPlayer(player, cf)
			end)
			return
		end

		if GameState.current ~= "PLAYING" then return end
		if not aliveSet[player] then return end  -- already eliminated

		if AnchorManager.hasAnchor(player) then
			-- Anchor respawn: delayed + lose 25 % of items
			respawningSet[player] = true
			InventoryManager.loseRandom(player, GameConfig.DEATH_LOSS_RATE)
			UpdateInventory:FireClient(player, InventoryManager.get(player))
			PlayerRespawning:FireClient(player, GameConfig.RESPAWN_DELAY)

			task.delay(GameConfig.RESPAWN_DELAY, function()
				respawningSet[player] = nil
				if not aliveSet[player] then return end
				local spawnCF = AnchorManager.getSpawnCF(player)
				spawnPlayer(player, spawnCF)
			end)
		else
			-- No anchor = permanent elimination
			aliveSet[player] = false
			DataManager.recordLoss(player)
			PlayerEliminated:FireAllClients(player.Name)
		end
	end)
end

-- Re-hook on every new character (handles both round-start and anchor respawns)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		connectDeath(player)
		-- Re-apply armor stats after respawn (new character resets Humanoid)
		task.wait(0.1)
		ArmorManager.reapply(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	aliveSet[player]      = nil
	respawningSet[player] = nil
	if deathConns[player] then
		deathConns[player]:Disconnect()
		deathConns[player] = nil
	end
	InventoryManager.clear(player)
	AnchorManager.clear(player)
	ArmorManager.clear(player)
	CurrencyManager.clear(player)
end)

-- ========== Swap logic ==========

local function doSwap()
	local alive = getAlivePlayers()
	if #alive < 2 then return end

	-- Capture positions RIGHT NOW (wherever each player is at this exact moment)
	local positions = {}
	for i, player in ipairs(alive) do
		local char = player.Character
		if char and char.Parent and not respawningSet[player] then
			positions[i] = char:GetPivot()
		else
			-- Respawning / no char: send them to their anchor or a safe fallback
			positions[i] = AnchorManager.getSpawnCF(player) or CFrame.new(0, 50, 0)
		end
	end

	-- Rotate: player[i] goes to position[i % n + 1]
	for i, player in ipairs(alive) do
		local char = player.Character
		local dest = positions[i % #alive + 1]
		if char and char.Parent and not respawningSet[player] then
			char:PivotTo(dest * CFrame.new(0, 3, 0))
		end
	end

	SwapPlayers:FireAllClients()
end

-- ========== State helpers ==========

local function setState(state, data)
	GameState.current = state
	RoundStateChanged:FireAllClients(state, data)
end

local function waitForMinPlayers()
	while #Players:GetPlayers() < GameConfig.MIN_PLAYERS do
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
	-- LOBBY
	setState("LOBBY")
	waitForMinPlayers()

	-- COUNTDOWN
	setState("COUNTDOWN")
	if not runLobbyCountdown() then continue end

	-- Reset world and generate a fresh random island
	MapManager.reset()
	MapManager.generate()
	AnchorManager.clearAll()
	aliveSet      = {}
	respawningSet = {}

	-- Spawn everyone then give them 60 s to build and place Soul Crystals
	spawnAllPlayers()
	runSetupPhase()

	-- PLAYING
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

		-- Passive currency income for alive players
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

	-- RESULTS
	local survivors  = getAlivePlayers()
	local winnerName = "No one"
	if #survivors == 1 then
		winnerName = survivors[1].Name
		DataManager.recordWin(survivors[1])
	elseif #survivors > 1 then
		winnerName = "Draw"
	end

	setState("RESULTS", winnerName)

	task.wait(GameConfig.RESULTS_DURATION)

	for _, player in ipairs(Players:GetPlayers()) do
		InventoryManager.clear(player)
		AnchorManager.clear(player)
		ArmorManager.clear(player)
		if player.Character then player.Character:Destroy() end
	end
end
