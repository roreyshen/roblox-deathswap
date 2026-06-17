-- Script: ServerScriptService > GameServer
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig      = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MapManager      = require(ReplicatedStorage:WaitForChild("MapManager"))
local InventoryManager = require(ServerScriptService.InventoryManager)
local DataManager     = require(ServerScriptService.DataManager)
local GameState       = require(ServerScriptService.GameState)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local SwapPlayers      = RemoteEvents:WaitForChild("SwapPlayers")
local RoundStateChanged = RemoteEvents:WaitForChild("RoundStateChanged")
local UpdateTimers     = RemoteEvents:WaitForChild("UpdateTimers")
local UpdateInventory  = RemoteEvents:WaitForChild("UpdateInventory")

-- Prevent automatic respawning; GameServer controls when characters spawn
Players.CharacterAutoLoads = false

-- ========== State ==========

local aliveSet = {}  -- [Player] = true while alive this round

local function countAlive()
	local n = 0
	for _, v in pairs(aliveSet) do
		if v then n += 1 end
	end
	return n
end

local function getAlivePlayers()
	local list = {}
	for player, alive in pairs(aliveSet) do
		if alive then table.insert(list, player) end
	end
	return list
end

-- ========== Character tracking ==========

local function onCharacterAdded(player, char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		if GameState.current == "PLAYING" then
			aliveSet[player] = false
			DataManager.recordLoss(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	aliveSet[player] = nil
	InventoryManager.clear(player)
end)

-- ========== Swap logic ==========

local function doSwap()
	local alive = getAlivePlayers()
	if #alive < 2 then return end

	-- Capture ALL positions before moving anyone (critical order)
	local positions = {}
	for i, player in ipairs(alive) do
		local char = player.Character
		positions[i] = (char and char.Parent) and char:GetPivot() or nil
	end

	-- Rotate destinations: player[i] goes to position[i+1] (wraps)
	for i, player in ipairs(alive) do
		local char = player.Character
		local dest = positions[i % #alive + 1]
		if char and char.Parent and dest then
			char:PivotTo(dest * CFrame.new(0, 3, 0))
		end
	end

	SwapPlayers:FireAllClients()
end

-- ========== Spawn helpers ==========

local function spawnPlayer(player, spawnCF)
	player:LoadCharacter()
	task.wait(0.2) -- brief wait so character tree is ready before PivotTo
	local char = player.Character
	if char and char.Parent and spawnCF then
		char:PivotTo(spawnCF)
	end
end

local function spawnAllPlayers()
	local spawnCFrames = MapManager.getSpawnCFrames()

	-- Shuffle spawn points so players get a different spot each round
	for i = #spawnCFrames, 2, -1 do
		local j = math.random(1, i)
		spawnCFrames[i], spawnCFrames[j] = spawnCFrames[j], spawnCFrames[i]
	end

	local playerList = Players:GetPlayers()

	-- Assign spawn points; cycle if more players than points
	local numSpawns = #spawnCFrames
	for i, player in ipairs(playerList) do
		aliveSet[player] = true
		InventoryManager.reset(player)
		UpdateInventory:FireClient(player, InventoryManager.get(player))
		local cf = numSpawns > 0 and spawnCFrames[((i - 1) % numSpawns) + 1] or nil
		spawnPlayer(player, cf)
	end
end

-- ========== State machine helpers ==========

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
		UpdateTimers:FireAllClients(i, 0)
		task.wait(1)
		if #Players:GetPlayers() < GameConfig.MIN_PLAYERS then
			return false
		end
	end
	return true
end

-- ========== Main game loop ==========

while true do
	-- LOBBY: wait until enough players join
	setState("LOBBY")
	waitForMinPlayers()

	-- COUNTDOWN: give players a moment to ready up
	setState("COUNTDOWN")
	local ready = runLobbyCountdown()
	if not ready then continue end

	-- Reset world and respawn everyone
	MapManager.reset()
	aliveSet = {}
	setState("PLAYING")
	spawnAllPlayers()

	local swapTimer       = 0
	local roundTimer      = 0
	local currentInterval = GameConfig.SWAP_INTERVAL

	while roundTimer < GameConfig.ROUND_DURATION and countAlive() >= 2 do
		task.wait(1)
		roundTimer += 1
		swapTimer  += 1

		local timeToSwap = currentInterval - swapTimer
		local timeLeft   = GameConfig.ROUND_DURATION - roundTimer
		UpdateTimers:FireAllClients(timeToSwap, timeLeft)

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
	local survivors = getAlivePlayers()
	local winnerName = "No one"
	if #survivors == 1 then
		winnerName = survivors[1].Name
		DataManager.recordWin(survivors[1])
	elseif #survivors > 1 then
		-- Time ran out with multiple survivors — declare a draw
		winnerName = "Draw"
	end

	setState("RESULTS", winnerName)

	-- Clean up inventory after short wait so players can read results
	task.wait(GameConfig.RESULTS_DURATION)

	for _, player in ipairs(Players:GetPlayers()) do
		InventoryManager.clear(player)
		-- Remove the character so players don't wander during lobby
		if player.Character then
			player.Character:Destroy()
		end
	end
end
