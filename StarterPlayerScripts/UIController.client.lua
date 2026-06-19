-- LocalScript: StarterPlayerScripts > UIController
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local RoundStateChanged  = RemoteEvents:WaitForChild("RoundStateChanged")
local UpdateTimers       = RemoteEvents:WaitForChild("UpdateTimers")
local SwapPlayers        = RemoteEvents:WaitForChild("SwapPlayers")
local PlayerRespawning   = RemoteEvents:WaitForChild("PlayerRespawning")
local PlayerEliminated   = RemoteEvents:WaitForChild("PlayerEliminated")
local AnchorDestroyed    = RemoteEvents:WaitForChild("AnchorDestroyed")
local AnchorHealthUpdate = RemoteEvents:WaitForChild("AnchorHealthUpdate")
local ArmorEquipped      = RemoteEvents:WaitForChild("ArmorEquipped")
local UpdateCurrency     = RemoteEvents:WaitForChild("UpdateCurrency")
local OpenShop           = RemoteEvents:WaitForChild("OpenShop")
local PurchaseItem       = RemoteEvents:WaitForChild("PurchaseItem")
local ShopResponse       = RemoteEvents:WaitForChild("ShopResponse")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BLOCK_TYPES = GameConfig.BLOCK_TYPES

-- ========== Build the HUD ==========

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- Helpers
local function makeLabel(name, size, pos, textColor, bgColor, bgTrans, font, zIndex)
	local lbl = Instance.new("TextLabel")
	lbl.Name                   = name
	lbl.Size                   = size
	lbl.Position               = pos
	lbl.BackgroundColor3       = bgColor or Color3.new(0, 0, 0)
	lbl.BackgroundTransparency = bgTrans or 1
	lbl.TextColor3             = textColor or Color3.new(1, 1, 1)
	lbl.TextScaled             = true
	lbl.Font                   = font or Enum.Font.Gotham
	lbl.Text                   = ""
	lbl.ZIndex                 = zIndex or 1
	lbl.Visible                = false
	lbl.Parent                 = screenGui
	return lbl
end

-- Swap flash overlay
local flashFrame = Instance.new("Frame")
flashFrame.Size                    = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3        = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency  = 1
flashFrame.ZIndex                  = 20
flashFrame.Parent                  = screenGui

-- Status label (lobby / countdown / results)
local statusLabel = makeLabel("StatusLabel",
	UDim2.new(0.6, 0, 0.1, 0),
	UDim2.new(0.2, 0, 0.42, 0),
	Color3.new(1, 1, 1), nil, 1, Enum.Font.GothamBold)
statusLabel.Text    = "Waiting for players..."
statusLabel.Visible = true

-- ── SETUP PHASE banner ──
local setupBanner = makeLabel("SetupBanner",
	UDim2.new(0.7, 0, 0.09, 0),
	UDim2.new(0.15, 0, 0.02, 0),
	Color3.fromRGB(0, 220, 255),
	Color3.fromRGB(10, 10, 30), 0.35,
	Enum.Font.GothamBold, 5)
setupBanner.TextXAlignment = Enum.TextXAlignment.Center
Instance.new("UICorner", setupBanner).CornerRadius = UDim.new(0, 8)

-- ── Swap label (top-center) ──
local swapLabel = makeLabel("SwapLabel",
	UDim2.new(0.3, 0, 0.07, 0),
	UDim2.new(0.35, 0, 0.02, 0),
	Color3.new(1, 1, 0),
	Color3.fromRGB(20, 20, 20), 0.4,
	Enum.Font.GothamBold)
swapLabel.Text = "SWAP IN: --"
Instance.new("UICorner", swapLabel).CornerRadius = UDim.new(0, 6)

-- ── Big swap-countdown number (center of screen) ──
local bigCountdown = makeLabel("BigCountdown",
	UDim2.new(0.2, 0, 0.2, 0),
	UDim2.new(0.4, 0, 0.35, 0),
	Color3.new(1, 0.2, 0.2),
	nil, 1, Enum.Font.GothamBold, 8)
bigCountdown.TextXAlignment = Enum.TextXAlignment.Center

-- ── Round timer (top-right) ──
local roundLabel = makeLabel("RoundLabel",
	UDim2.new(0.2, 0, 0.05, 0),
	UDim2.new(0.78, 0, 0.03, 0),
	Color3.new(1, 1, 1),
	Color3.fromRGB(20, 20, 20), 0.5,
	Enum.Font.Gotham)
Instance.new("UICorner", roundLabel).CornerRadius = UDim.new(0, 6)

-- ── Anchor status (left side, below center) ──
local anchorStatus = Instance.new("Frame")
anchorStatus.Name                   = "AnchorStatus"
anchorStatus.Size                   = UDim2.new(0.22, 0, 0.06, 0)
anchorStatus.Position               = UDim2.new(0.01, 0, 0.44, 0)
anchorStatus.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
anchorStatus.BackgroundTransparency = 0.4
anchorStatus.Visible                = false
anchorStatus.Parent                 = screenGui
Instance.new("UICorner", anchorStatus).CornerRadius = UDim.new(0, 8)

local anchorStatusLabel = Instance.new("TextLabel", anchorStatus)
anchorStatusLabel.Size                   = UDim2.fromScale(1, 1)
anchorStatusLabel.BackgroundTransparency = 1
anchorStatusLabel.TextColor3             = Color3.new(0.5, 1, 1)
anchorStatusLabel.TextScaled             = true
anchorStatusLabel.Font                   = Enum.Font.GothamBold
anchorStatusLabel.Text                   = "Soul Crystal: NOT PLACED"

-- ── Armor indicator (top-left) ──
local armorFrame = Instance.new("Frame")
armorFrame.Name                   = "ArmorFrame"
armorFrame.Size                   = UDim2.new(0.18, 0, 0.055, 0)
armorFrame.Position               = UDim2.new(0.01, 0, 0.52, 0)
armorFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
armorFrame.BackgroundTransparency = 0.4
armorFrame.Visible                = false
armorFrame.Parent                 = screenGui
Instance.new("UICorner", armorFrame).CornerRadius = UDim.new(0, 8)

local armorLabel = Instance.new("TextLabel", armorFrame)
armorLabel.Size                   = UDim2.fromScale(1, 1)
armorLabel.BackgroundTransparency = 1
armorLabel.TextColor3             = Color3.fromRGB(200, 200, 220)
armorLabel.TextScaled             = true
armorLabel.Font                   = Enum.Font.GothamBold
armorLabel.Text                   = "Armor: None"

-- ── Currency display (top-right, below round timer) ──
local currencyFrame = Instance.new("Frame")
currencyFrame.Name                   = "CurrencyFrame"
currencyFrame.Size                   = UDim2.new(0.14, 0, 0.045, 0)
currencyFrame.Position               = UDim2.new(0.84, 0, 0.03, 0)
currencyFrame.BackgroundColor3       = Color3.fromRGB(255, 200, 0)
currencyFrame.BackgroundTransparency = 0.3
currencyFrame.Visible                = false
currencyFrame.Parent                 = screenGui
Instance.new("UICorner", currencyFrame).CornerRadius = UDim.new(0, 6)

local currencyLabel = Instance.new("TextLabel", currencyFrame)
currencyLabel.Size                   = UDim2.fromScale(1, 1)
currencyLabel.BackgroundTransparency = 1
currencyLabel.TextColor3             = Color3.fromRGB(60, 40, 0)
currencyLabel.TextScaled             = true
currencyLabel.Font                   = Enum.Font.GothamBold
currencyLabel.Text                   = "$ 0"

-- ── Shop Panel (center screen, shown on ProximityPrompt trigger) ──
local shopPanel = Instance.new("Frame")
shopPanel.Name                   = "ShopPanel"
shopPanel.Size                   = UDim2.new(0, 320, 0, 400)
shopPanel.Position               = UDim2.new(0.5, -160, 0.5, -200)
shopPanel.BackgroundColor3       = Color3.fromRGB(25, 25, 35)
shopPanel.BackgroundTransparency = 0.05
shopPanel.Visible                = false
shopPanel.ZIndex                 = 25
shopPanel.Parent                 = screenGui
Instance.new("UICorner", shopPanel).CornerRadius = UDim.new(0, 12)

-- Shop header
local shopHeader = Instance.new("TextLabel", shopPanel)
shopHeader.Size                   = UDim2.new(1, -40, 0, 40)
shopHeader.Position               = UDim2.new(0, 10, 0, 8)
shopHeader.BackgroundTransparency = 1
shopHeader.TextColor3             = Color3.fromRGB(255, 200, 40)
shopHeader.TextScaled             = true
shopHeader.Font                   = Enum.Font.GothamBold
shopHeader.Text                   = "SHOP"
shopHeader.ZIndex                 = 26

-- Close button
local shopClose = Instance.new("TextButton", shopPanel)
shopClose.Size                   = UDim2.new(0, 30, 0, 30)
shopClose.Position               = UDim2.new(1, -35, 0, 8)
shopClose.BackgroundColor3       = Color3.fromRGB(180, 40, 40)
shopClose.TextColor3             = Color3.new(1, 1, 1)
shopClose.TextScaled             = true
shopClose.Font                   = Enum.Font.GothamBold
shopClose.Text                   = "X"
shopClose.ZIndex                 = 26
Instance.new("UICorner", shopClose).CornerRadius = UDim.new(0, 6)

-- Balance display inside shop
local shopBalanceLabel = Instance.new("TextLabel", shopPanel)
shopBalanceLabel.Size                   = UDim2.new(1, -20, 0, 28)
shopBalanceLabel.Position               = UDim2.new(0, 10, 0, 52)
shopBalanceLabel.BackgroundTransparency = 1
shopBalanceLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
shopBalanceLabel.TextScaled             = true
shopBalanceLabel.Font                   = Enum.Font.Gotham
shopBalanceLabel.Text                   = "Balance: $0"
shopBalanceLabel.ZIndex                 = 26

-- Feedback label (success/fail messages)
local shopFeedback = Instance.new("TextLabel", shopPanel)
shopFeedback.Size                   = UDim2.new(1, -20, 0, 24)
shopFeedback.Position               = UDim2.new(0, 10, 1, -30)
shopFeedback.BackgroundTransparency = 1
shopFeedback.TextColor3             = Color3.fromRGB(100, 255, 100)
shopFeedback.TextScaled             = true
shopFeedback.Font                   = Enum.Font.Gotham
shopFeedback.Text                   = ""
shopFeedback.ZIndex                 = 26

-- Scrolling item list
local itemList = Instance.new("ScrollingFrame", shopPanel)
itemList.Size                  = UDim2.new(1, -20, 0, 270)
itemList.Position              = UDim2.new(0, 10, 0, 86)
itemList.BackgroundTransparency= 1
itemList.ScrollBarThickness    = 6
itemList.CanvasSize            = UDim2.new(0, 0, 0, 0)
itemList.ZIndex                = 26

local listLayout = Instance.new("UIListLayout", itemList)
listLayout.SortOrder    = Enum.SortOrder.LayoutOrder
listLayout.Padding      = UDim.new(0, 6)

-- Shop catalog (mirrors ShopManager.CATALOG)
local SHOP_CATALOG = {
	{ id = "Wood",     label = "Wood x10",    cost = 10  },
	{ id = "Stone",    label = "Stone x10",   cost = 15  },
	{ id = "Obsidian", label = "Obsidian x5", cost = 10  },
	{ id = "Leather",  label = "Leather Armor (+20 HP)", cost = 50  },
	{ id = "Iron",     label = "Iron Armor (+50 HP)",    cost = 120 },
}

local shopCurrentBalance = 0

local function buildShopRows()
	for _, entry in ipairs(SHOP_CATALOG) do
		local row = Instance.new("Frame", itemList)
		row.Size              = UDim2.new(1, -8, 0, 44)
		row.BackgroundColor3  = Color3.fromRGB(40, 40, 55)
		row.LayoutOrder       = 1
		row.ZIndex            = 27
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local nameLabel = Instance.new("TextLabel", row)
		nameLabel.Size                   = UDim2.new(0.65, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3             = Color3.new(1, 1, 1)
		nameLabel.TextScaled             = true
		nameLabel.Font                   = Enum.Font.Gotham
		nameLabel.Text                   = entry.label
		nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
		nameLabel.Position               = UDim2.new(0, 8, 0, 0)
		nameLabel.ZIndex                 = 28

		local buyBtn = Instance.new("TextButton", row)
		buyBtn.Size             = UDim2.new(0, 90, 0, 30)
		buyBtn.Position         = UDim2.new(1, -98, 0.5, -15)
		buyBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 60)
		buyBtn.TextColor3       = Color3.new(1, 1, 1)
		buyBtn.TextScaled       = true
		buyBtn.Font             = Enum.Font.GothamBold
		buyBtn.Text             = "$" .. entry.cost
		buyBtn.ZIndex           = 28
		Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

		buyBtn.MouseButton1Click:Connect(function()
			PurchaseItem:FireServer(entry.id)
		end)
	end
	-- Update canvas size
	itemList.CanvasSize = UDim2.new(0, 0, 0, #SHOP_CATALOG * 50)
end

buildShopRows()

shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

-- ── Respawn overlay ──
local respawnFrame = Instance.new("Frame")
respawnFrame.Size                    = UDim2.fromScale(1, 1)
respawnFrame.BackgroundColor3        = Color3.new(0, 0, 0)
respawnFrame.BackgroundTransparency  = 0.5
respawnFrame.ZIndex                  = 15
respawnFrame.Visible                 = false
respawnFrame.Parent                  = screenGui

local respawnLabel = Instance.new("TextLabel", respawnFrame)
respawnLabel.Size                   = UDim2.new(0.6, 0, 0.2, 0)
respawnLabel.Position               = UDim2.new(0.2, 0, 0.4, 0)
respawnLabel.BackgroundTransparency = 1
respawnLabel.TextColor3             = Color3.fromRGB(255, 80, 80)
respawnLabel.TextScaled             = true
respawnLabel.Font                   = Enum.Font.GothamBold
respawnLabel.Text                   = "RESPAWNING..."
respawnLabel.ZIndex                 = 16

local respawnSubLabel = Instance.new("TextLabel", respawnFrame)
respawnSubLabel.Size                   = UDim2.new(0.5, 0, 0.1, 0)
respawnSubLabel.Position               = UDim2.new(0.25, 0, 0.62, 0)
respawnSubLabel.BackgroundTransparency = 1
respawnSubLabel.TextColor3             = Color3.new(1, 1, 1)
respawnSubLabel.TextScaled             = true
respawnSubLabel.Font                   = Enum.Font.Gotham
respawnSubLabel.Text                   = "(25% of items lost)"
respawnSubLabel.ZIndex                 = 16

-- ── Announcement banner (center, temporary) ──
local announceBanner = makeLabel("AnnounceBanner",
	UDim2.new(0.6, 0, 0.08, 0),
	UDim2.new(0.2, 0, 0.2, 0),
	Color3.new(1, 1, 1),
	Color3.fromRGB(10, 10, 10), 0.3,
	Enum.Font.GothamBold, 10)
Instance.new("UICorner", announceBanner).CornerRadius = UDim.new(0, 8)

-- ── Results screen ──
local winScreen = Instance.new("Frame")
winScreen.Name                   = "WinScreen"
winScreen.Size                   = UDim2.new(0.5, 0, 0.3, 0)
winScreen.Position               = UDim2.new(0.25, 0, 0.35, 0)
winScreen.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
winScreen.BackgroundTransparency = 0.2
winScreen.Visible                = false
winScreen.Parent                 = screenGui
Instance.new("UICorner", winScreen).CornerRadius = UDim.new(0, 12)

local winLabel = Instance.new("TextLabel", winScreen)
winLabel.Size                   = UDim2.fromScale(1, 1)
winLabel.BackgroundTransparency = 1
winLabel.TextColor3             = Color3.new(1, 1, 0)
winLabel.TextScaled             = true
winLabel.Font                   = Enum.Font.GothamBold

-- ── Hotbar (bottom-center) ──
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name                   = "HotbarFrame"
hotbarFrame.Size                   = UDim2.new(0, #BLOCK_TYPES * 70, 0, 70)
hotbarFrame.Position               = UDim2.new(0.5, -#BLOCK_TYPES * 35, 1, -90)
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.Visible                = false
hotbarFrame.Parent                 = screenGui

local slotFrames  = {}
local countLabels = {}

for i, blockDef in ipairs(BLOCK_TYPES) do
	local slot = Instance.new("Frame")
	slot.Size            = UDim2.new(0, 62, 0, 62)
	slot.Position        = UDim2.new(0, (i - 1) * 70, 0, 0)
	slot.BackgroundColor3 = blockDef.color
	slot.BorderSizePixel = 3
	slot.Parent          = hotbarFrame
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

	local nameLabel = Instance.new("TextLabel", slot)
	nameLabel.Size                   = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3             = Color3.new(1, 1, 1)
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.Text                   = blockDef.id

	local countLabel = Instance.new("TextLabel", slot)
	countLabel.Size                   = UDim2.new(1, 0, 0.5, 0)
	countLabel.Position               = UDim2.new(0, 0, 0.5, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3             = Color3.new(1, 1, 1)
	countLabel.TextScaled             = true
	countLabel.Font                   = Enum.Font.Gotham
	countLabel.Text                   = "0"

	slotFrames[i]  = slot
	countLabels[i] = countLabel
end

local function highlightSlot(index)
	for i, frame in ipairs(slotFrames) do
		frame.BorderColor3 = (i == index) and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80)
	end
end
highlightSlot(1)

-- ========== Helpers ==========

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local announceCo  -- coroutine handle for announcement
local function showAnnouncement(text, color, duration)
	if announceCo and coroutine.status(announceCo) ~= "dead" then
		-- Just update immediately if already showing
	end
	announceBanner.Text    = text
	announceBanner.TextColor3 = color or Color3.new(1, 1, 1)
	announceBanner.Visible = true
	announceCo = task.delay(duration or 3, function()
		announceBanner.Visible = false
	end)
end

-- ========== State tracking ──
local currentState   = "LOBBY"
local myAnchorAlive  = false  -- set true when placed, false when destroyed

-- ========== Remote listeners ==========

RoundStateChanged.OnClientEvent:Connect(function(state, data)
	currentState = state

	local isSetup   = (state == "SETUP")
	local isPlaying = (state == "PLAYING")
	local isResults = (state == "RESULTS")
	local isLobby   = (state == "LOBBY" or state == "COUNTDOWN")

	-- Visibility toggles
	statusLabel.Visible  = isLobby
	setupBanner.Visible  = isSetup
	swapLabel.Visible    = isPlaying
	roundLabel.Visible   = isPlaying
	bigCountdown.Visible = false
	hotbarFrame.Visible    = (isSetup or isPlaying)
	winScreen.Visible      = isResults
	anchorStatus.Visible   = (isSetup or isPlaying)
	armorFrame.Visible     = (isSetup or isPlaying)
	currencyFrame.Visible  = (isSetup or isPlaying)

	-- Close shop if transitioning away from active play
	if isLobby or isResults then
		shopPanel.Visible = false
	end

	if isLobby then
		statusLabel.Text = (state == "COUNTDOWN") and "Game starting..." or "Waiting for players..."
	elseif isSetup then
		myAnchorAlive = false
		anchorStatusLabel.Text       = "Soul Crystal: NOT PLACED"
		anchorStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 0)
	elseif isResults then
		winLabel.Text = data and (data .. " wins!") or "Game Over"
		respawnFrame.Visible = false
	end
end)

UpdateTimers.OnClientEvent:Connect(function(timeToSwap, timeLeft, setupTimeLeft)
	if currentState == "SETUP" then
		local t = math.max(0, math.floor(setupTimeLeft or 0))
		setupBanner.Text = string.format(
			"SETUP PHASE  %ds  |  Left-click to place Soul Crystal  |  1-5 to build", t)

	elseif currentState == "PLAYING" then
		local ts = math.max(0, math.floor(timeToSwap))
		local tl = math.max(0, math.floor(timeLeft))
		swapLabel.Text  = "SWAP IN: " .. ts
		roundLabel.Text = formatTime(tl)

		if ts <= GameConfig.SWAP_COUNTDOWN and ts > 0 then
			swapLabel.TextColor3   = Color3.new(1, 0.15, 0.15)
			bigCountdown.Text      = tostring(ts)
			bigCountdown.Visible   = true
		elseif ts == 0 then
			bigCountdown.Visible   = false
			swapLabel.TextColor3   = Color3.new(1, 1, 0)
		else
			bigCountdown.Visible   = false
			swapLabel.TextColor3   = Color3.new(1, 1, 0)
		end

	elseif currentState == "LOBBY" or currentState == "COUNTDOWN" then
		local t = math.max(0, math.floor(timeToSwap))
		statusLabel.Text = t > 0 and ("Starting in " .. t .. "s") or statusLabel.Text
	end
end)

SwapPlayers.OnClientEvent:Connect(function()
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	bigCountdown.Visible = false
end)

-- Anchor placed (local client confirms via BindableEvent from PlacementClient)
task.spawn(function()
	local ae = player:WaitForChild("AnchorStatusChanged", 10)
	if ae then
		ae.Event:Connect(function(status)
			if status == "placed" then
				myAnchorAlive                = true
				anchorStatusLabel.Text       = "Soul Crystal: ACTIVE"
				anchorStatusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
			end
		end)
	end
end)

-- Anchor health update (show crack progress)
AnchorHealthUpdate.OnClientEvent:Connect(function(ownerUserId, hp, maxHp)
	if ownerUserId == player.UserId then
		local pct = hp / (maxHp or GameConfig.ANCHOR_MAX_HP)
		local barStr = string.rep("|", math.ceil(pct * 10)) .. string.rep(" ", 10 - math.ceil(pct * 10))
		anchorStatusLabel.Text       = string.format("Soul Crystal: [%s] %d/%d", barStr, hp, maxHp or 5)
		anchorStatusLabel.TextColor3 = Color3.fromRGB(255, math.floor(pct * 200), 0)
	end
end)

-- Anchor destroyed
AnchorDestroyed.OnClientEvent:Connect(function(ownerUserId, ownerName)
	if ownerUserId == player.UserId then
		myAnchorAlive                = false
		anchorStatusLabel.Text       = "Soul Crystal: DESTROYED!"
		anchorStatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		-- Big warning flash
		showAnnouncement("YOUR CRYSTAL WAS DESTROYED!\nNEXT DEATH = ELIMINATED", Color3.fromRGB(255, 50, 50), 5)
	else
		showAnnouncement(ownerName .. "'s Crystal was destroyed!", Color3.fromRGB(255, 180, 0), 3)
	end
end)

-- Player respawning countdown
PlayerRespawning.OnClientEvent:Connect(function(delay)
	respawnFrame.Visible = true
	task.spawn(function()
		for i = delay, 1, -1 do
			respawnLabel.Text = "RESPAWNING IN " .. i .. "..."
			task.wait(1)
		end
		respawnFrame.Visible = false
		respawnLabel.Text    = "RESPAWNING..."
	end)
end)

-- Player eliminated
PlayerEliminated.OnClientEvent:Connect(function(playerName)
	if playerName == player.Name then
		showAnnouncement("YOU HAVE BEEN ELIMINATED!", Color3.fromRGB(255, 50, 50), 5)
	else
		showAnnouncement(playerName .. " has been ELIMINATED!", Color3.fromRGB(255, 120, 0), 3)
	end
end)

-- Shop open trigger
OpenShop.OnClientEvent:Connect(function(currentBalance)
	shopCurrentBalance      = currentBalance or 0
	shopBalanceLabel.Text   = "Balance: $" .. shopCurrentBalance
	shopFeedback.Text       = ""
	shopPanel.Visible       = true
end)

-- Shop purchase response
ShopResponse.OnClientEvent:Connect(function(success, message)
	shopFeedback.Text      = message or ""
	shopFeedback.TextColor3 = success
		and Color3.fromRGB(80, 255, 80)
		or  Color3.fromRGB(255, 80, 80)
end)

-- Armor equipped notification
ArmorEquipped.OnClientEvent:Connect(function(armorId, bonusHP)
	armorLabel.Text      = string.format("Armor: %s (+%d HP)", armorId, bonusHP)
	armorLabel.TextColor3 = armorId == "Iron"
		and Color3.fromRGB(180, 185, 190)
		or  Color3.fromRGB(150, 100, 60)
end)

-- Currency update
UpdateCurrency.OnClientEvent:Connect(function(amount)
	currencyLabel.Text    = "$ " .. tostring(amount)
	shopCurrentBalance    = amount
	if shopPanel.Visible then
		shopBalanceLabel.Text = "Balance: $" .. tostring(amount)
	end
end)

-- ========== Hotbar updates from PlacementClient ==========

task.spawn(function()
	local invEvent  = player:WaitForChild("InventoryChanged",    10)
	local slotEvent = player:WaitForChild("SelectedSlotChanged", 10)

	if invEvent then
		invEvent.Event:Connect(function(inv)
			for i, blockDef in ipairs(BLOCK_TYPES) do
				local count = inv[blockDef.id] or 0
				countLabels[i].Text                     = tostring(count)
				slotFrames[i].BackgroundTransparency    = count == 0 and 0.6 or 0
			end
		end)
	end

	if slotEvent then
		slotEvent.Event:Connect(function(slot)
			highlightSlot(slot)
		end)
	end
end)
