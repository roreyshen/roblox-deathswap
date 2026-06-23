-- Script: ServerScriptService > LobbyServer
local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GAME_PLACE_ID = 118403186714318
local MIN_PLAYERS   = 2

Players.CharacterAutoLoads = false

local GemManager        = require(ServerScriptService.GemManager)
local KitManager        = require(ServerScriptService.KitManager)
local LobbyMapGenerator = require(ServerScriptService.LobbyMapGenerator)

local RemoteEvents        = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateGems          = RemoteEvents:WaitForChild("UpdateGems")
local UpdateKit           = RemoteEvents:WaitForChild("UpdateKit")
local PurchaseKit         = RemoteEvents:WaitForChild("PurchaseKit")
local KitPurchaseResponse = RemoteEvents:WaitForChild("KitPurchaseResponse")
local JoinQueue           = RemoteEvents:WaitForChild("JoinQueue")
local LeaveQueue          = RemoteEvents:WaitForChild("LeaveQueue")
local QueueUpdate         = RemoteEvents:WaitForChild("QueueUpdate")
local OpenKitShop         = RemoteEvents:WaitForChild("OpenKitShop")

-- ── Clear any leftover content from previous place ────────────────────────────

workspace.Terrain:Clear()
for _, obj in ipairs(workspace:GetChildren()) do
	if not obj:IsA("Camera") and obj.Name ~= "LobbyMap" then
		pcall(function() obj:Destroy() end)
	end
end

-- ── Generate map ──────────────────────────────────────────────────────────────

LobbyMapGenerator.generate()
local zoneCFs       = LobbyMapGenerator.getZoneCFrames()
local practiceCFs   = LobbyMapGenerator.getPracticeSpawns()

-- ── Queue state ───────────────────────────────────────────────────────────────

local lobbyQueue      = {}   -- [Player] = true
local countdownActive = false

local function countQueue()
	local n = 0
	for _ in pairs(lobbyQueue) do n += 1 end
	return n
end

-- Update the 3D world billboard on the QueueBoard part
local function updateWorldBoard(text)
	local map   = workspace:FindFirstChild("LobbyMap")
	if not map then return end
	local board = map:FindFirstChild("QueueBoard")
	if not board then return end
	local bb    = board:FindFirstChildOfClass("BillboardGui")
	if not bb   then return end
	local bg    = bb:FindFirstChildOfClass("Frame")
	if not bg   then return end
	local lbl   = bg:FindFirstChild("QueueText")
	if lbl      then lbl.Text = text end
end

local function broadcastQueue(countdown)
	local n = countQueue()
	QueueUpdate:FireAllClients(n, MIN_PLAYERS, countdown or 0)
	if countdown and countdown > 0 then
		updateWorldBoard(string.format("Players ready: %d/%d\nStarting in %ds...", n, MIN_PLAYERS, countdown))
	else
		updateWorldBoard(string.format("Players in queue: %d / %d\nStep on PLAY to join!", n, MIN_PLAYERS))
	end
end

local function startCountdown()
	if countdownActive then return end
	countdownActive = true
	task.spawn(function()
		for i = 10, 1, -1 do
			broadcastQueue(i)
			task.wait(1)
			if countQueue() < MIN_PLAYERS then
				countdownActive = false
				broadcastQueue()
				return
			end
		end
		-- Gather queued players and teleport
		local toTeleport = {}
		for player in pairs(lobbyQueue) do
			table.insert(toTeleport, player)
		end
		lobbyQueue        = {}
		countdownActive   = false
		broadcastQueue()

		if #toTeleport > 0 then
			local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, GAME_PLACE_ID, toTeleport)
			if not ok then warn("[Lobby] Teleport failed:", err) end
		end
	end)
end

JoinQueue.OnServerEvent:Connect(function(player)
	lobbyQueue[player] = true
	broadcastQueue()
	if countQueue() >= MIN_PLAYERS then
		startCountdown()
	end
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	lobbyQueue[player] = nil
	broadcastQueue()
end)

-- ── Practice bots ─────────────────────────────────────────────────────────────

local BOT_COLORS = {
	Color3.fromRGB(180, 50,  50),
	Color3.fromRGB(50,  80,  180),
	Color3.fromRGB(180, 130, 50),
	Color3.fromRGB(60,  160, 80),
}

local spawnBotRec  -- forward declare for recursion

spawnBotRec = function(index, spawnCF)
	local color = BOT_COLORS[((index-1) % #BOT_COLORS) + 1]

	local model = Instance.new("Model")
	model.Name  = "PracticeBot"

	local hrp = Instance.new("Part")
	hrp.Name         = "HumanoidRootPart"
	hrp.Size         = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame       = spawnCF * CFrame.new(0, 3, 0)
	hrp.Parent       = model
	model.PrimaryPart = hrp

	local torso = Instance.new("Part")
	torso.Name   = "Torso"
	torso.Size   = Vector3.new(2, 2, 1)
	torso.Color  = color
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
	gui.Size        = UDim2.new(0, 170, 0, 48)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.Parent      = hrp
	local bg = Instance.new("Frame", gui)
	bg.Size = UDim2.fromScale(1,1)
	bg.BackgroundColor3 = Color3.fromRGB(10,10,22)
	bg.BackgroundTransparency = 0.2
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
	local lbl = Instance.new("TextLabel", bg)
	lbl.Size = UDim2.fromScale(1,1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(120, 200, 255)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = "PRACTICE BOT"

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	hum.Health    = 100
	hum.Parent    = model

	model.Parent = workspace

	hum.Died:Connect(function()
		task.delay(5, function()
			pcall(function() model:Destroy() end)
			spawnBotRec(index, spawnCF)
		end)
	end)
end

-- ── Player lifecycle (set up BEFORE any yields) ──────────────────────────────

local function sendInitialData(player)
	task.wait(2)
	if not player.Parent then return end
	UpdateGems:FireClient(player, GemManager.get(player))
	UpdateKit:FireClient(player,  KitManager.getKit(player))
end

local function spawnAtHub(player)
	task.wait(0.4)
	local char = player.Character
	if not char then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		char:PivotTo(zoneCFs.hub * CFrame.new(math.random(-12,12), 3, math.random(-12,12)))
	end
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function()
		spawnAtHub(player)
	end)
	player.CharacterRemoving:Connect(function()
		task.delay(3, function()
			if player.Parent then player:LoadCharacter() end
		end)
	end)
	player:LoadCharacter()
	task.spawn(sendInitialData, player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	lobbyQueue[player] = nil
	broadcastQueue()
end)

-- Handle players who joined before this handler was connected
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

-- ── Practice bots (background task so they don't block PlayerAdded setup) ────

task.spawn(function()
	for i, cf in ipairs(practiceCFs) do
		task.wait(0.08)
		spawnBotRec(i, cf)
	end
end)

-- ── Zone teleport pads (touch to teleport within lobby) ───────────────────────

local function wireTouchPads()
	local map = workspace:WaitForChild("LobbyMap")
	local cooldowns = {}  -- [Player] = lastTick

	local function tryTeleport(zoneName, otherPart)
		local char   = otherPart.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end
		local now = tick()
		if cooldowns[player] and now - cooldowns[player] < 2 then return end
		cooldowns[player] = now
		local cf = zoneCFs[zoneName]
		if cf and char.PrimaryPart then
			char:PivotTo(cf * CFrame.new(math.random(-8,8), 3, math.random(-8,8)))
		end
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("StringValue") and obj.Name == "ZoneTag" then
			local pad  = obj.Parent
			local zone = obj.Value
			if pad:IsA("BasePart") then
				if zone == "obbyfinish" then
					-- Reward gems on finish (once per respawn)
					local rewarded = {}
					pad.Touched:Connect(function(hit)
						local char   = hit.Parent
						local player = Players:GetPlayerFromCharacter(char)
						if not player or rewarded[player] then return end
						rewarded[player] = true
						local g = GemManager.add(player, 5)
						UpdateGems:FireClient(player, g)
					end)
					-- Clear on character respawn
					Players.PlayerAdded:Connect(function(pl)
						pl.CharacterAdded:Connect(function() rewarded[pl] = nil end)
					end)
				else
					pad.Touched:Connect(function(hit) tryTeleport(zone, hit) end)
				end
			end
		end
	end

	-- Kit pedestals: ProximityPrompt opens the kit shop on the client
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Parent:FindFirstChild("KitId") then
			obj.Triggered:Connect(function(player)
				OpenKitShop:FireClient(player)
			end)
		end
	end
end

task.delay(0.5, wireTouchPads)

-- ── Kit purchase ──────────────────────────────────────────────────────────────

PurchaseKit.OnServerEvent:Connect(function(player, kitId)
	if type(kitId) ~= "string" then return end
	local def = KitManager.getDef(kitId)
	if not def then
		KitPurchaseResponse:FireClient(player, false, "Unknown kit.")
		return
	end
	if KitManager.getKit(player) == kitId then
		KitPurchaseResponse:FireClient(player, false, "Already equipped.")
		return
	end
	if not GemManager.deduct(player, def.cost) then
		KitPurchaseResponse:FireClient(player, false, string.format("Need %d gems.", def.cost))
		return
	end
	KitManager.setKit(player, kitId)
	local newGems = GemManager.get(player)
	UpdateGems:FireClient(player, newGems)
	UpdateKit:FireClient(player, kitId)
	KitPurchaseResponse:FireClient(player, true, kitId, newGems)
end)

-- Fire initial queue state to any late-joining client
broadcastQueue()
