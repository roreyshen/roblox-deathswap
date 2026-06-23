-- LocalScript: StarterPlayerScripts > LobbyClient
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RemoteEvents        = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateGems          = RemoteEvents:WaitForChild("UpdateGems")
local UpdateKit           = RemoteEvents:WaitForChild("UpdateKit")
local PurchaseKit         = RemoteEvents:WaitForChild("PurchaseKit")
local KitPurchaseResponse = RemoteEvents:WaitForChild("KitPurchaseResponse")
local JoinQueue           = RemoteEvents:WaitForChild("JoinQueue")
local LeaveQueue          = RemoteEvents:WaitForChild("LeaveQueue")
local QueueUpdate         = RemoteEvents:WaitForChild("QueueUpdate")
local OpenKitShop         = RemoteEvents:WaitForChild("OpenKitShop")

local gems        = 0
local equippedKit = "none"
local inQueue     = false

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local sg = Instance.new("ScreenGui")
sg.Name           = "LobbyGui"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = playerGui

local function corner(parent, r)
	Instance.new("UICorner", parent).CornerRadius = UDim.new(0, r or 10)
end

-- ── TOP BAR ───────────────────────────────────────────────────────────────────

local topBar = Instance.new("Frame", sg)
topBar.Name                   = "TopBar"
topBar.Size                   = UDim2.new(1, 0, 0, 52)
topBar.Position               = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3       = Color3.fromRGB(8, 6, 18)
topBar.BackgroundTransparency = 0.2
topBar.ZIndex                 = 2

-- Title
local titleLbl = Instance.new("TextLabel", topBar)
titleLbl.Size                   = UDim2.new(0.4, 0, 1, 0)
titleLbl.Position               = UDim2.new(0.3, 0, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3             = Color3.fromRGB(255, 80, 80)
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextScaled             = true
titleLbl.Text                   = "DEATHSWAP"
titleLbl.ZIndex                 = 3

-- Gem counter (top right)
local gemFrame = Instance.new("Frame", topBar)
gemFrame.Name            = "GemFrame"
gemFrame.Size            = UDim2.new(0, 155, 0, 36)
gemFrame.Position        = UDim2.new(1, -168, 0.5, -18)
gemFrame.BackgroundColor3 = Color3.fromRGB(20, 14, 36)
gemFrame.BackgroundTransparency = 0.15
gemFrame.ZIndex          = 3
corner(gemFrame, 8)

local gemLabel = Instance.new("TextLabel", gemFrame)
gemLabel.Name                   = "GemLabel"
gemLabel.Size                   = UDim2.fromScale(1, 1)
gemLabel.BackgroundTransparency = 1
gemLabel.TextColor3             = Color3.fromRGB(190, 130, 255)
gemLabel.Font                   = Enum.Font.GothamBold
gemLabel.TextScaled             = true
gemLabel.Text                   = "♦ 0"
gemLabel.ZIndex                 = 4

-- Kit indicator (top left)
local kitFrame = Instance.new("Frame", topBar)
kitFrame.Name            = "KitFrame"
kitFrame.Size            = UDim2.new(0, 155, 0, 36)
kitFrame.Position        = UDim2.new(0, 12, 0.5, -18)
kitFrame.BackgroundColor3 = Color3.fromRGB(20, 14, 36)
kitFrame.BackgroundTransparency = 0.15
kitFrame.ZIndex          = 3
corner(kitFrame, 8)

local kitLabel = Instance.new("TextLabel", kitFrame)
kitLabel.Name                   = "KitLabel"
kitLabel.Size                   = UDim2.fromScale(1, 1)
kitLabel.BackgroundTransparency = 1
kitLabel.TextColor3             = Color3.fromRGB(160, 160, 180)
kitLabel.Font                   = Enum.Font.GothamBold
kitLabel.TextScaled             = true
kitLabel.Text                   = "Kit: None"
kitLabel.ZIndex                 = 4

-- ── QUEUE STATUS BAR (bottom center, shown when in queue) ─────────────────────

local queueBar = Instance.new("Frame", sg)
queueBar.Name                   = "QueueBar"
queueBar.Size                   = UDim2.new(0, 380, 0, 56)
queueBar.Position               = UDim2.new(0.5, -190, 1, -80)
queueBar.BackgroundColor3       = Color3.fromRGB(10, 10, 22)
queueBar.BackgroundTransparency = 0.1
queueBar.Visible                = false
queueBar.ZIndex                 = 10
corner(queueBar, 12)

local queueLabel = Instance.new("TextLabel", queueBar)
queueLabel.Size                   = UDim2.new(0.7, 0, 1, 0)
queueLabel.Position               = UDim2.new(0, 12, 0, 0)
queueLabel.BackgroundTransparency = 1
queueLabel.TextColor3             = Color3.fromRGB(100, 255, 140)
queueLabel.Font                   = Enum.Font.GothamBold
queueLabel.TextScaled             = true
queueLabel.TextXAlignment         = Enum.TextXAlignment.Left
queueLabel.Text                   = "In queue: 1/2"
queueLabel.ZIndex                 = 11

local leaveBtn = Instance.new("TextButton", queueBar)
leaveBtn.Name            = "LeaveBtn"
leaveBtn.Size            = UDim2.new(0, 100, 0, 36)
leaveBtn.Position        = UDim2.new(1, -112, 0.5, -18)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
leaveBtn.TextColor3      = Color3.new(1,1,1)
leaveBtn.Font            = Enum.Font.GothamBold
leaveBtn.TextScaled      = true
leaveBtn.Text            = "LEAVE"
leaveBtn.ZIndex          = 12
corner(leaveBtn, 8)

-- ── PLAY BUTTON (bottom center, shown when NOT in queue) ──────────────────────

local playBtn = Instance.new("TextButton", sg)
playBtn.Name             = "PlayBtn"
playBtn.Size             = UDim2.new(0, 240, 0, 64)
playBtn.Position         = UDim2.new(0.5, -120, 1, -90)
playBtn.BackgroundColor3 = Color3.fromRGB(28, 185, 78)
playBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
playBtn.Font             = Enum.Font.GothamBold
playBtn.TextScaled       = true
playBtn.Text             = "JOIN QUEUE"
playBtn.ZIndex           = 10
corner(playBtn, 14)
local playStroke = Instance.new("UIStroke", playBtn)
playStroke.Color     = Color3.fromRGB(18, 130, 52)
playStroke.Thickness = 2

-- ── KIT SHOP PANEL (hidden by default, toggle with button or pedestal prompt) ─

local kitPanel = Instance.new("Frame", sg)
kitPanel.Name                   = "KitPanel"
kitPanel.Size                   = UDim2.new(0, 620, 0, 320)
kitPanel.Position               = UDim2.new(0.5, -310, 0.5, -160)
kitPanel.BackgroundColor3       = Color3.fromRGB(12, 9, 24)
kitPanel.BackgroundTransparency = 0.08
kitPanel.Visible                = false
kitPanel.ZIndex                 = 20
corner(kitPanel, 16)

local panelTitle = Instance.new("TextLabel", kitPanel)
panelTitle.Size                   = UDim2.new(1, -50, 0, 46)
panelTitle.Position               = UDim2.new(0, 0, 0, 0)
panelTitle.BackgroundTransparency = 1
panelTitle.TextColor3             = Color3.fromRGB(220, 220, 255)
panelTitle.Font                   = Enum.Font.GothamBold
panelTitle.TextScaled             = true
panelTitle.Text                   = "CHOOSE YOUR KIT"
panelTitle.ZIndex                 = 21

local closeBtn = Instance.new("TextButton", kitPanel)
closeBtn.Size            = UDim2.new(0, 36, 0, 36)
closeBtn.Position        = UDim2.new(1, -44, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.TextColor3      = Color3.new(1,1,1)
closeBtn.Font            = Enum.Font.GothamBold
closeBtn.TextScaled      = true
closeBtn.Text            = "✕"
closeBtn.ZIndex          = 22
corner(closeBtn, 8)

local statusLbl = Instance.new("TextLabel", kitPanel)
statusLbl.Size                   = UDim2.new(1, -20, 0, 28)
statusLbl.Position               = UDim2.new(0, 10, 1, -34)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3             = Color3.fromRGB(180, 180, 200)
statusLbl.Font                   = Enum.Font.Gotham
statusLbl.TextScaled             = true
statusLbl.Text                   = ""
statusLbl.ZIndex                 = 21

-- Kit cards row
local cardRow = Instance.new("Frame", kitPanel)
cardRow.Size                   = UDim2.new(1, -24, 0, 240)
cardRow.Position               = UDim2.new(0, 12, 0, 50)
cardRow.BackgroundTransparency = 1
cardRow.ZIndex                 = 21
local rowLayout = Instance.new("UIListLayout", cardRow)
rowLayout.FillDirection        = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
rowLayout.Padding              = UDim.new(0, 10)

local KIT_DEFS = {
	{ id="Speed",   cost=100, desc="+15%\nMove Speed",  color=Color3.fromRGB(80,  180, 255) },
	{ id="Jump",    cost=100, desc="+20%\nJump Power",  color=Color3.fromRGB(120, 255, 120) },
	{ id="Miner",   cost=100, desc="+50%\nMine Speed",  color=Color3.fromRGB(255, 180, 60)  },
	{ id="Healer",  cost=100, desc="2 HP/s\nRegen",     color=Color3.fromRGB(255, 100, 180) },
	{ id="Trapper", cost=100, desc="+25%\nTrap Dmg",    color=Color3.fromRGB(200, 80,  255) },
}

local kitButtonMap = {}  -- [kitId] = {btn=, card=, baseColor=}

for _, def in ipairs(KIT_DEFS) do
	local card = Instance.new("Frame", cardRow)
	card.Size             = UDim2.new(0, 102, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(20, 15, 36)
	card.ZIndex           = 22
	corner(card, 10)

	local nameL = Instance.new("TextLabel", card)
	nameL.Size                   = UDim2.new(1, -6, 0, 36)
	nameL.Position               = UDim2.new(0, 3, 0, 8)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3             = def.color
	nameL.Font                   = Enum.Font.GothamBold
	nameL.TextScaled             = true
	nameL.Text                   = def.id
	nameL.ZIndex                 = 23

	local descL = Instance.new("TextLabel", card)
	descL.Size                   = UDim2.new(1, -8, 0, 80)
	descL.Position               = UDim2.new(0, 4, 0, 46)
	descL.BackgroundTransparency = 1
	descL.TextColor3             = Color3.fromRGB(185, 185, 205)
	descL.Font                   = Enum.Font.Gotham
	descL.TextWrapped            = true
	descL.TextScaled             = true
	descL.Text                   = def.desc
	descL.ZIndex                 = 23

	local btn = Instance.new("TextButton", card)
	btn.Size             = UDim2.new(1, -12, 0, 38)
	btn.Position         = UDim2.new(0, 6, 1, -46)
	btn.BackgroundColor3 = def.color
	btn.TextColor3       = Color3.new(1, 1, 1)
	btn.Font             = Enum.Font.GothamBold
	btn.TextScaled       = true
	btn.Text             = "♦ 100"
	btn.ZIndex           = 24
	corner(btn, 8)

	kitButtonMap[def.id] = { btn=btn, card=card, baseColor=def.color }

	local capturedId = def.id
	btn.MouseButton1Click:Connect(function()
		if equippedKit == capturedId then return end
		PurchaseKit:FireServer(capturedId)
	end)
end

-- Open kits button (always visible, top-right of panel trigger)
local kitsOpenBtn = Instance.new("TextButton", sg)
kitsOpenBtn.Size             = UDim2.new(0, 110, 0, 38)
kitsOpenBtn.Position         = UDim2.new(0.5, -55, 0, 60)
kitsOpenBtn.BackgroundColor3 = Color3.fromRGB(100, 40, 160)
kitsOpenBtn.TextColor3       = Color3.new(1, 1, 1)
kitsOpenBtn.Font             = Enum.Font.GothamBold
kitsOpenBtn.TextScaled       = true
kitsOpenBtn.Text             = "⚙ KITS"
kitsOpenBtn.ZIndex           = 5
corner(kitsOpenBtn, 8)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function showStatus(msg, success)
	statusLbl.Text       = msg
	statusLbl.TextColor3 = success
		and Color3.fromRGB(80, 255, 120)
		or  Color3.fromRGB(255, 80, 80)
	task.delay(3, function()
		if statusLbl.Text == msg then statusLbl.Text = "" end
	end)
end

local function refreshKitButtons()
	for id, entry in pairs(kitButtonMap) do
		if id == equippedKit then
			entry.btn.BackgroundColor3 = Color3.fromRGB(28, 185, 78)
			entry.btn.Text             = "EQUIPPED"
			entry.card.BackgroundColor3 = Color3.fromRGB(14, 30, 18)
		else
			entry.btn.BackgroundColor3 = entry.baseColor
			entry.btn.Text             = "♦ 100"
			entry.card.BackgroundColor3 = Color3.fromRGB(20, 15, 36)
		end
	end
	if equippedKit ~= "none" then
		kitLabel.Text       = "Kit: " .. equippedKit
		kitLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	else
		kitLabel.Text       = "Kit: None"
		kitLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	end
end

local function setInQueue(queued)
	inQueue       = queued
	playBtn.Visible   = not queued
	queueBar.Visible  = queued
end

-- ── Button connections ────────────────────────────────────────────────────────

playBtn.MouseButton1Click:Connect(function()
	if inQueue then return end
	setInQueue(true)
	JoinQueue:FireServer()
end)

leaveBtn.MouseButton1Click:Connect(function()
	if not inQueue then return end
	setInQueue(false)
	LeaveQueue:FireServer()
end)

kitsOpenBtn.MouseButton1Click:Connect(function()
	kitPanel.Visible = not kitPanel.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
	kitPanel.Visible = false
end)

-- Teleport pad: "PLAY" zone pad also joins queue
local function onCharacterAdded(char)
	-- If player walks onto the PLAY pad, auto-join queue (handled server-side via touch)
	-- Visual highlight on pad is handled by zone tags; client just listens to remotes
	setInQueue(false)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ── Remote handlers ───────────────────────────────────────────────────────────

UpdateGems.OnClientEvent:Connect(function(amount)
	gems          = amount
	gemLabel.Text = string.format("♦ %d", gems)
end)

UpdateKit.OnClientEvent:Connect(function(kitId)
	equippedKit = kitId or "none"
	refreshKitButtons()
end)

KitPurchaseResponse.OnClientEvent:Connect(function(success, kitIdOrMsg, newGems)
	if success then
		equippedKit = kitIdOrMsg
		if newGems then
			gems          = newGems
			gemLabel.Text = string.format("♦ %d", gems)
		end
		showStatus(kitIdOrMsg .. " Kit equipped!", true)
	else
		showStatus(kitIdOrMsg, false)
	end
	refreshKitButtons()
end)

QueueUpdate.OnClientEvent:Connect(function(count, minPlayers, countdown)
	if count == 0 then
		-- No one in queue — leave our queue state too if kicked
		if inQueue then
			setInQueue(false)
		end
		return
	end

	local msg
	if countdown and countdown > 0 then
		msg = string.format("Queue: %d/%d  •  Starting in %ds", count, minPlayers, countdown)
	else
		msg = string.format("In queue: %d/%d players", count, minPlayers)
	end
	queueLabel.Text = msg
end)

OpenKitShop.OnClientEvent:Connect(function()
	kitPanel.Visible = true
end)
