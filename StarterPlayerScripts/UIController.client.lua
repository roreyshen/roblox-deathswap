-- LocalScript: StarterPlayerScripts > UIController
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
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
local StartTestMode      = RemoteEvents:WaitForChild("StartTestMode")
local DevCheat           = RemoteEvents:WaitForChild("DevCheat")
local UpdateGems         = RemoteEvents:WaitForChild("UpdateGems")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BLOCK_TYPES = GameConfig.BLOCK_TYPES

-- Disable default Roblox health bar
task.spawn(function()
	task.wait()
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end)

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

-- ── Gem display (below coin display) ──
local gemFrame = Instance.new("Frame")
gemFrame.Name                   = "GemFrame"
gemFrame.Size                   = UDim2.new(0.14, 0, 0.045, 0)
gemFrame.Position               = UDim2.new(0.84, 0, 0.08, 0)
gemFrame.BackgroundColor3       = Color3.fromRGB(160, 60, 220)
gemFrame.BackgroundTransparency = 0.3
gemFrame.Visible                = false
gemFrame.Parent                 = screenGui
Instance.new("UICorner", gemFrame).CornerRadius = UDim.new(0, 6)

local gemLabel = Instance.new("TextLabel", gemFrame)
gemLabel.Size                   = UDim2.fromScale(1, 1)
gemLabel.BackgroundTransparency = 1
gemLabel.TextColor3             = Color3.fromRGB(255, 220, 255)
gemLabel.TextScaled             = true
gemLabel.Font                   = Enum.Font.GothamBold
gemLabel.Text                   = "♦ 0"

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
	{ id = "Wood",     itemType = "block",   label = "Wood x10",              cost = 10  },
	{ id = "Stone",    itemType = "block",   label = "Stone x10",             cost = 15  },
	{ id = "Obsidian", itemType = "block",   label = "Obsidian x5",           cost = 10  },
	{ id = "Leather",  itemType = "armor",   label = "Leather Armor (20% DR)", cost = 50 },
	{ id = "Iron",     itemType = "armor",   label = "Iron Armor (40% DR)",    cost = 120 },
	{ id = "Stone",    itemType = "sword",   label = "Stone Sword (12 dmg)",   cost = 75  },
	{ id = "Stone",    itemType = "pickaxe", label = "Stone Pickaxe (2x)",     cost = 75  },
	{ id = "Iron",     itemType = "sword",   label = "Iron Sword (16 dmg)",    cost = 150 },
	{ id = "Iron",     itemType = "pickaxe", label = "Iron Pickaxe (3x)",      cost = 150 },
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
			PurchaseItem:FireServer(entry.id, entry.itemType)
		end)
	end
	itemList.CanvasSize = UDim2.new(0, 0, 0, #SHOP_CATALOG * 50)
	-- Expand panel to show more items
	shopPanel.Size = UDim2.new(0, 320, 0, math.min(500, 100 + #SHOP_CATALOG * 50))
end

buildShopRows()

shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)


-- TEST (Solo) button
local testButton = Instance.new("TextButton")
testButton.Name                   = "TestModeButton"
testButton.Size                   = UDim2.new(0, 160, 0, 40)
testButton.Position               = UDim2.new(0.5, -80, 0.64, 0)
testButton.BackgroundColor3       = Color3.fromRGB(50, 60, 130)
testButton.TextColor3             = Color3.new(1, 1, 1)
testButton.TextScaled             = true
testButton.Font                   = Enum.Font.GothamBold
testButton.Text                   = "SOLO TEST"
testButton.ZIndex                 = 5
testButton.Visible                = false
testButton.Parent                 = screenGui
Instance.new("UICorner", testButton).CornerRadius = UDim.new(0, 10)

testButton.MouseButton1Click:Connect(function()
	StartTestMode:FireServer()
	testButton.Text   = "Starting..."
	testButton.Active = false
end)

-- ── Inventory Panel (I key) ──
local invPanelOpen = false

local PANEL_W, PANEL_H = 580, 460
local invPanel = Instance.new("Frame")
invPanel.Name                   = "InventoryPanel"
invPanel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
invPanel.Position               = UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
invPanel.BackgroundColor3       = Color3.fromRGB(10, 12, 18)
invPanel.BorderSizePixel        = 0
invPanel.Visible                = false
invPanel.ZIndex                 = 30
invPanel.Parent                 = screenGui
Instance.new("UICorner", invPanel).CornerRadius = UDim.new(0, 10)
local invPanelStroke = Instance.new("UIStroke", invPanel)
invPanelStroke.Color     = Color3.fromRGB(55, 145, 210)
invPanelStroke.Thickness = 2

-- Header bar
local invHeaderBar = Instance.new("Frame", invPanel)
invHeaderBar.Size             = UDim2.new(1, 0, 0, 40)
invHeaderBar.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
invHeaderBar.BorderSizePixel  = 0
invHeaderBar.ZIndex           = 31
Instance.new("UICorner", invHeaderBar).CornerRadius = UDim.new(0, 10)
do  -- patch bottom corners flat
	local p = Instance.new("Frame", invHeaderBar)
	p.Size = UDim2.new(1,0,0.5,0); p.Position = UDim2.new(0,0,0.5,0)
	p.BackgroundColor3 = Color3.fromRGB(14,18,28); p.BorderSizePixel = 0; p.ZIndex = 31
end

local invTitle = Instance.new("TextLabel", invHeaderBar)
invTitle.Size = UDim2.new(1, -50, 1, 0)
invTitle.Position = UDim2.new(0, 14, 0, 0)
invTitle.BackgroundTransparency = 1
invTitle.TextColor3 = Color3.fromRGB(100, 190, 255)
invTitle.TextScaled = true; invTitle.Font = Enum.Font.GothamBold
invTitle.Text = "INVENTORY"; invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.ZIndex = 32

local invAccentLine = Instance.new("Frame", invPanel)
invAccentLine.Size = UDim2.new(1, -4, 0, 2)
invAccentLine.Position = UDim2.new(0, 2, 0, 40)
invAccentLine.BackgroundColor3 = Color3.fromRGB(55, 145, 210)
invAccentLine.BorderSizePixel = 0; invAccentLine.ZIndex = 32

local invCloseBtn = Instance.new("TextButton", invPanel)
invCloseBtn.Size             = UDim2.new(0, 28, 0, 28)
invCloseBtn.Position         = UDim2.new(1, -34, 0, 6)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
invCloseBtn.TextColor3       = Color3.new(1, 1, 1)
invCloseBtn.TextScaled       = true
invCloseBtn.Font             = Enum.Font.GothamBold
invCloseBtn.Text             = "X"
invCloseBtn.ZIndex           = 34
Instance.new("UICorner", invCloseBtn).CornerRadius = UDim.new(0, 5)
invCloseBtn.MouseButton1Click:Connect(function()
	invPanelOpen = false
	invPanel.Visible = false
end)

-- ── LEFT COLUMN: character viewport + armor + stats (width=158) ──
local LEFT_W = 158

-- Character viewport (ViewportFrame)
local vpFrame = Instance.new("ViewportFrame", invPanel)
vpFrame.Name             = "CharPreview"
vpFrame.Size             = UDim2.new(0, LEFT_W - 8, 0, 200)
vpFrame.Position         = UDim2.new(0, 4, 0, 46)
vpFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
vpFrame.BorderSizePixel  = 0
vpFrame.ZIndex           = 32
vpFrame.LightDirection   = Vector3.new(-1, -2, -1)
vpFrame.Ambient          = Color3.fromRGB(80, 80, 90)
Instance.new("UICorner", vpFrame).CornerRadius = UDim.new(0, 8)
local vpStroke = Instance.new("UIStroke", vpFrame)
vpStroke.Color = Color3.fromRGB(40, 65, 100); vpStroke.Thickness = 1
local vpCamera = Instance.new("Camera", vpFrame)
vpCamera.FieldOfView = 50
vpFrame.CurrentCamera = vpCamera

-- Armor section
local armorSectionLbl = Instance.new("TextLabel", invPanel)
armorSectionLbl.Size = UDim2.new(0, LEFT_W - 8, 0, 18)
armorSectionLbl.Position = UDim2.new(0, 4, 0, 252)
armorSectionLbl.BackgroundTransparency = 1
armorSectionLbl.TextColor3 = Color3.fromRGB(80, 150, 215)
armorSectionLbl.TextScaled = true; armorSectionLbl.Font = Enum.Font.GothamBold
armorSectionLbl.Text = "ARMOR"; armorSectionLbl.TextXAlignment = Enum.TextXAlignment.Left
armorSectionLbl.ZIndex = 32

local chestSlotFrame = Instance.new("Frame", invPanel)
chestSlotFrame.Name             = "ArmorSlot"
chestSlotFrame.Size             = UDim2.new(0, LEFT_W - 8, 0, 60)
chestSlotFrame.Position         = UDim2.new(0, 4, 0, 272)
chestSlotFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 38)
chestSlotFrame.BorderSizePixel  = 0
chestSlotFrame.ZIndex           = 32
Instance.new("UICorner", chestSlotFrame).CornerRadius = UDim.new(0, 8)
local csStroke = Instance.new("UIStroke", chestSlotFrame)
csStroke.Color = Color3.fromRGB(50, 75, 115); csStroke.Thickness = 1.5

local chestIcon = Instance.new("TextLabel", chestSlotFrame)
chestIcon.Size = UDim2.new(0, 32, 1, -6)
chestIcon.Position = UDim2.new(0, 6, 0, 3)
chestIcon.BackgroundTransparency = 1
chestIcon.TextColor3 = Color3.fromRGB(90, 110, 145)
chestIcon.TextScaled = true; chestIcon.Font = Enum.Font.GothamBold
chestIcon.Text = "▲"; chestIcon.ZIndex = 33

local invArmorSlotLbl = Instance.new("TextLabel", chestSlotFrame)
invArmorSlotLbl.Size = UDim2.new(1, -42, 1, -6)
invArmorSlotLbl.Position = UDim2.new(0, 42, 0, 3)
invArmorSlotLbl.BackgroundTransparency = 1
invArmorSlotLbl.TextColor3 = Color3.fromRGB(175, 185, 205)
invArmorSlotLbl.TextScaled = true; invArmorSlotLbl.Font = Enum.Font.GothamBold
invArmorSlotLbl.Text = "None"; invArmorSlotLbl.TextXAlignment = Enum.TextXAlignment.Left
invArmorSlotLbl.ZIndex = 33
local invArmorIcon = chestSlotFrame  -- compat: ArmorEquipped handler sets BackgroundColor3

-- Stats
local invHPLabel = Instance.new("TextLabel", invPanel)
invHPLabel.Size = UDim2.new(0, LEFT_W - 8, 0, 22)
invHPLabel.Position = UDim2.new(0, 4, 0, 342)
invHPLabel.BackgroundTransparency = 1
invHPLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
invHPLabel.TextScaled = true; invHPLabel.Font = Enum.Font.Gotham
invHPLabel.Text = "HP: ---"; invHPLabel.TextXAlignment = Enum.TextXAlignment.Left
invHPLabel.ZIndex = 32

local invCoinsLabel = Instance.new("TextLabel", invPanel)
invCoinsLabel.Size = UDim2.new(0, LEFT_W - 8, 0, 20)
invCoinsLabel.Position = UDim2.new(0, 4, 0, 366)
invCoinsLabel.BackgroundTransparency = 1
invCoinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
invCoinsLabel.TextScaled = true; invCoinsLabel.Font = Enum.Font.Gotham
invCoinsLabel.Text = "Coins: $0"; invCoinsLabel.TextXAlignment = Enum.TextXAlignment.Left
invCoinsLabel.ZIndex = 32

-- Vertical divider
local invVDiv = Instance.new("Frame", invPanel)
invVDiv.Size = UDim2.new(0, 1, 1, -44)
invVDiv.Position = UDim2.new(0, LEFT_W + 4, 0, 43)
invVDiv.BackgroundColor3 = Color3.fromRGB(32, 52, 78)
invVDiv.BorderSizePixel = 0; invVDiv.ZIndex = 31

-- ── RIGHT: block inventory grid ──
local vpX = LEFT_W + 10

local invItemsHeader = Instance.new("TextLabel", invPanel)
invItemsHeader.Size                   = UDim2.new(1, -(vpX + 8), 0, 24)
invItemsHeader.Position               = UDim2.new(0, vpX + 4, 0, 48)
invItemsHeader.BackgroundColor3       = Color3.fromRGB(18, 52, 86)
invItemsHeader.BackgroundTransparency = 0.35
invItemsHeader.TextColor3             = Color3.fromRGB(80, 175, 240)
invItemsHeader.TextScaled             = true
invItemsHeader.Font                   = Enum.Font.GothamBold
invItemsHeader.Text                   = "BLOCKS"
invItemsHeader.ZIndex                 = 32
Instance.new("UICorner", invItemsHeader).CornerRadius = UDim.new(0, 5)

local ICOLS     = 3
local ISLOT_GAP = 6
local invRightW = PANEL_W - vpX - 8
local ISLOT_W   = math.floor((invRightW - ISLOT_GAP * (ICOLS - 1)) / ICOLS)
local ISLOT_H   = 96

local invGridSlots  = {}
local invGridCounts = {}
local invGridFills  = {}

for i, blockDef in ipairs(BLOCK_TYPES) do
	local col = (i - 1) % ICOLS
	local row = math.floor((i - 1) / ICOLS)
	local sx  = vpX + 4 + col * (ISLOT_W + ISLOT_GAP)
	local sy  = 78 + row * (ISLOT_H + ISLOT_GAP)

	local cell = Instance.new("TextButton", invPanel)
	cell.Name             = "InvSlot" .. i
	cell.Size             = UDim2.new(0, ISLOT_W, 0, ISLOT_H)
	cell.Position         = UDim2.new(0, sx, 0, sy)
	cell.BackgroundColor3 = Color3.fromRGB(17, 21, 32)
	cell.BorderSizePixel  = 0
	cell.Text             = ""
	cell.AutoButtonColor  = false
	cell.LayoutOrder      = i
	cell.ZIndex           = 32
	Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)
	local cs = Instance.new("UIStroke", cell)
	cs.Color = Color3.fromRGB(42, 58, 88); cs.Thickness = 1.5

	-- Color swatch (fills most of the slot)
	local fill = Instance.new("Frame", cell)
	fill.Size             = UDim2.new(1, -10, 0, ISLOT_H - 38)
	fill.Position         = UDim2.new(0, 5, 0, 5)
	fill.BackgroundColor3 = blockDef.color
	fill.BorderSizePixel  = 0
	fill.ZIndex           = 33
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

	local nameL = Instance.new("TextLabel", cell)
	nameL.Size                   = UDim2.new(1, -8, 0, 16)
	nameL.Position               = UDim2.new(0, 4, 1, -32)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3             = Color3.fromRGB(170, 180, 200)
	nameL.TextScaled             = true
	nameL.Font                   = Enum.Font.Gotham
	nameL.Text                   = blockDef.id
	nameL.ZIndex                 = 33

	local countL = Instance.new("TextLabel", cell)
	countL.Size                   = UDim2.new(0, 46, 0, 20)
	countL.Position               = UDim2.new(1, -50, 1, -22)
	countL.BackgroundTransparency = 1
	countL.TextColor3             = Color3.new(1, 1, 1)
	countL.TextScaled             = true
	countL.Font                   = Enum.Font.GothamBold
	countL.Text                   = "0"
	countL.ZIndex                 = 34

	local keyL = Instance.new("TextLabel", cell)
	keyL.Size                   = UDim2.new(0, 16, 0, 16)
	keyL.Position               = UDim2.new(0, 4, 0, 4)
	keyL.BackgroundTransparency = 1
	keyL.TextColor3             = Color3.fromRGB(100, 120, 160)
	keyL.TextScaled             = true
	keyL.Font                   = Enum.Font.Gotham
	keyL.Text                   = tostring(i)
	keyL.ZIndex                 = 35

	invGridSlots[i]  = cell
	invGridCounts[i] = countL
	invGridFills[i]  = fill
end

local function highlightInvSlot(index)
	for i, cell in ipairs(invGridSlots) do
		if cell then
			local stroke = cell:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color     = (i == index) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(42, 58, 88)
				stroke.Thickness = (i == index) and 2.5 or 1.5
			end
		end
	end
end
highlightInvSlot(1)

-- Render the local player's character inside the viewport frame
local function refreshCharPreview()
	for _, obj in ipairs(vpFrame:GetChildren()) do
		if obj:IsA("Model") then obj:Destroy() end
	end
	local char = player.Character
	if not char then return end
	local clone = char:Clone()
	for _, s in ipairs(clone:GetDescendants()) do
		if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
			s:Destroy()
		end
	end
	-- Hide tools so they don't clutter the preview
	for _, s in ipairs(clone:GetChildren()) do
		if s:IsA("Tool") then s:Destroy() end
	end
	clone.Parent = vpFrame
	local hrp = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso")
	if hrp then
		vpCamera.CFrame = hrp.CFrame * CFrame.new(0, 0.6, 5.5) * CFrame.Angles(0, math.pi, 0)
	end
end

-- Bag toggle button (bottom-left, above hotbar)
local invToggleBtn = Instance.new("TextButton")
invToggleBtn.Name             = "InvToggleBtn"
invToggleBtn.Size             = UDim2.new(0, 54, 0, 40)
invToggleBtn.Position         = UDim2.new(0, 10, 1, -104)
invToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
invToggleBtn.TextColor3       = Color3.fromRGB(100, 190, 255)
invToggleBtn.TextScaled       = true
invToggleBtn.Font             = Enum.Font.GothamBold
invToggleBtn.Text             = "[I]"
invToggleBtn.Visible          = false
invToggleBtn.ZIndex           = 6
invToggleBtn.Parent           = screenGui
Instance.new("UICorner", invToggleBtn).CornerRadius = UDim.new(0, 8)
local invBtnStroke = Instance.new("UIStroke", invToggleBtn)
invBtnStroke.Color     = Color3.fromRGB(60, 160, 220)
invBtnStroke.Thickness = 2

invToggleBtn.MouseButton1Click:Connect(function()
	invPanelOpen = not invPanelOpen
	invPanel.Visible = invPanelOpen
	if invPanelOpen then refreshCharPreview() end
end)

-- I key toggles the panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.I then return end
	if currentState ~= "SETUP" and currentState ~= "PLAYING" then return end
	invPanelOpen = not invPanelOpen
	invPanel.Visible = invPanelOpen
	if invPanelOpen then refreshCharPreview() end
end)

-- Live HP update: hearts bar always, inventory panel when open
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if heartsFrame and heartsFrame.Visible then
			updateHearts(hum.Health, hum.MaxHealth)
		end
		if invPanel.Visible then
			invHPLabel.Text = string.format("HP: %d / %d", math.ceil(hum.Health), hum.MaxHealth)
		end
	end
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

-- ── Hearts health bar (above hotbar) — actual heart shapes with half-heart clipping ──
local HEART_SIZE = 46   -- larger for clearer heart rendering
local HEART_GAP  = 5
local NUM_HEARTS = 10

local heartsFrame = Instance.new("Frame")
heartsFrame.Name                   = "HeartsFrame"
heartsFrame.Size                   = UDim2.new(0, NUM_HEARTS * (HEART_SIZE + HEART_GAP) - HEART_GAP, 0, HEART_SIZE + 4)
heartsFrame.BackgroundTransparency = 1
heartsFrame.Visible                = false
heartsFrame.Parent                 = screenGui

local heartClippers = {}  -- [i] = clipper Frame whose width drives full/half/empty

for hi = 1, NUM_HEARTS do
	local slot = Instance.new("Frame")
	slot.Name             = "Heart" .. hi
	slot.Size             = UDim2.new(0, HEART_SIZE, 0, HEART_SIZE)
	slot.Position         = UDim2.new(0, (hi - 1) * (HEART_SIZE + HEART_GAP), 0, 2)
	slot.BackgroundTransparency = 1
	slot.Parent           = heartsFrame

	-- Dark empty heart (shows heart shape when unfilled)
	local bgH = Instance.new("TextLabel", slot)
	bgH.Size                   = UDim2.new(0, HEART_SIZE, 0, HEART_SIZE)
	bgH.BackgroundTransparency = 1
	bgH.TextColor3             = Color3.fromRGB(55, 18, 18)
	bgH.TextScaled             = false
	bgH.TextSize               = HEART_SIZE - 2
	bgH.Font                   = Enum.Font.GothamBlack
	bgH.Text                   = "♥"
	bgH.TextXAlignment         = Enum.TextXAlignment.Center
	bgH.TextYAlignment         = Enum.TextYAlignment.Center
	bgH.TextStrokeColor3       = Color3.new(0, 0, 0)
	bgH.TextStrokeTransparency = 0.4
	bgH.ZIndex                 = 5

	-- Clipper: 100% = full heart, 50% = half heart, 0% = empty
	local clipper = Instance.new("Frame", slot)
	clipper.ClipsDescendants     = true
	clipper.BackgroundTransparency = 1
	clipper.Size                 = UDim2.new(1, 0, 1, 0)
	clipper.ZIndex               = 6

	-- Bright red heart (fills to show health — clipped)
	local redH = Instance.new("TextLabel", clipper)
	redH.Size                   = UDim2.new(0, HEART_SIZE, 0, HEART_SIZE)
	redH.BackgroundTransparency = 1
	redH.TextColor3             = Color3.fromRGB(240, 30, 30)
	redH.TextScaled             = false
	redH.TextSize               = HEART_SIZE - 2
	redH.Font                   = Enum.Font.GothamBlack
	redH.Text                   = "♥"
	redH.TextXAlignment         = Enum.TextXAlignment.Center
	redH.TextYAlignment         = Enum.TextYAlignment.Center
	redH.TextStrokeColor3       = Color3.fromRGB(90, 0, 0)
	redH.TextStrokeTransparency = 0.25
	redH.ZIndex                 = 7

	heartClippers[hi] = clipper
end

-- hp/maxHp → hearts in 0.5 increments. 51 HP = 5 full, 55 HP = 5.5, 100 HP = 10 full.
local function updateHearts(hp, maxHp)
	local halfPerHeart = (maxHp or 100) / NUM_HEARTS / 2  -- 5 HP per half-heart
	local totalHalves  = math.floor(hp / halfPerHeart)
	for hi = 1, NUM_HEARTS do
		local halves = totalHalves - (hi - 1) * 2
		if halves >= 2 then
			heartClippers[hi].Size = UDim2.new(1, 0, 1, 0)
		elseif halves == 1 then
			heartClippers[hi].Size = UDim2.new(0.5, 0, 1, 0)
		else
			heartClippers[hi].Size = UDim2.new(0, 0, 1, 0)
		end
	end
end

-- ── Hotbar (bottom-center, clickable slots) ──
local SLOT_SIZE = 74
local SLOT_GAP  = 5
local numSlots  = #BLOCK_TYPES

local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name                   = "HotbarFrame"
hotbarFrame.Size                   = UDim2.new(0, numSlots * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP, 0, SLOT_SIZE)
hotbarFrame.Position               = UDim2.new(0.5, -math.floor(numSlots * (SLOT_SIZE + SLOT_GAP) / 2), 1, -(SLOT_SIZE + 14))
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.Visible                = false
hotbarFrame.Parent                 = screenGui

local slotFrames   = {}
local slotSwatches = {}
local countLabels  = {}

for i, blockDef in ipairs(BLOCK_TYPES) do
	local slot = Instance.new("TextButton")
	slot.Name             = "Slot" .. i
	slot.Size             = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.Position         = UDim2.new(0, (i - 1) * (SLOT_SIZE + SLOT_GAP), 0, 0)
	slot.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	slot.BorderSizePixel  = 0
	slot.Text             = ""
	slot.AutoButtonColor  = false
	slot.Parent           = hotbarFrame
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", slot)
	stroke.Color     = Color3.fromRGB(65, 65, 65)
	stroke.Thickness = 2

	-- Block color swatch
	local swatch = Instance.new("Frame", slot)
	swatch.Size             = UDim2.new(1, -10, 0, SLOT_SIZE - 28)
	swatch.Position         = UDim2.new(0, 5, 0, 5)
	swatch.BackgroundColor3 = blockDef.color
	swatch.BorderSizePixel  = 0
	Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 4)

	-- Count (top-right corner)
	local countLabel = Instance.new("TextLabel", slot)
	countLabel.Size                   = UDim2.new(0, 28, 0, 18)
	countLabel.Position               = UDim2.new(1, -30, 0, 4)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3             = Color3.new(1, 1, 1)
	countLabel.TextScaled             = true
	countLabel.Font                   = Enum.Font.GothamBold
	countLabel.Text                   = "0"

	-- Key number (top-left corner)
	local keyLabel = Instance.new("TextLabel", slot)
	keyLabel.Size                   = UDim2.new(0, 14, 0, 14)
	keyLabel.Position               = UDim2.new(0, 4, 0, 4)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3             = Color3.fromRGB(170, 170, 170)
	keyLabel.TextScaled             = true
	keyLabel.Font                   = Enum.Font.Gotham
	keyLabel.Text                   = tostring(i)

	-- Block name (bottom strip)
	local nameLabel = Instance.new("TextLabel", slot)
	nameLabel.Size                   = UDim2.new(1, -4, 0, 18)
	nameLabel.Position               = UDim2.new(0, 2, 1, -20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3             = Color3.fromRGB(210, 210, 210)
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.Text                   = blockDef.id

	slotFrames[i]   = slot
	slotSwatches[i] = swatch
	countLabels[i]  = countLabel
end

local function highlightSlot(index)
	for i, slot in ipairs(slotFrames) do
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color     = (i == index) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(65, 65, 65)
			stroke.Thickness = (i == index) and 3 or 2
		end
	end
end
highlightSlot(1)

-- Position hearts above hotbar (HEART_SIZE+4 = actual frame height)
local hotbarHeartOffset = -(SLOT_SIZE + 14 + (HEART_SIZE + 4) + 6)
heartsFrame.Position = UDim2.new(
	0.5, -math.floor((NUM_HEARTS * (HEART_SIZE + HEART_GAP) - HEART_GAP) / 2),
	1, hotbarHeartOffset
)


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
	heartsFrame.Visible    = (isSetup or isPlaying)
	winScreen.Visible      = isResults
	anchorStatus.Visible   = (isSetup or isPlaying)
	armorFrame.Visible     = (isSetup or isPlaying)
	currencyFrame.Visible  = (isSetup or isPlaying)
	gemFrame.Visible       = (isSetup or isPlaying)
	testButton.Visible      = (state == "LOBBY")
	invToggleBtn.Visible   = (isSetup or isPlaying)

	-- Close shop/inventory panel when transitioning away from active play
	if isLobby or isResults then
		shopPanel.Visible = false
		invPanel.Visible  = false
		invPanelOpen      = false
	end

	if isLobby then
		statusLabel.Text  = (state == "COUNTDOWN") and "Game starting..." or "Waiting for players..."
		testButton.Text   = "TEST (Solo)"
		testButton.Active = true
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
			"SETUP PHASE  %ds  |  Left-click to place Soul Crystal  |  1-9 to build", t)

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
ArmorEquipped.OnClientEvent:Connect(function(armorId, reduction)
	if not armorId then
		armorLabel.Text = "Armor: None"
		invArmorSlotLbl.Text = "None"
		return
	end
	local color = armorId == "Iron"
		and Color3.fromRGB(180, 185, 190)
		or  Color3.fromRGB(150, 100, 60)
	local pct = math.round((reduction or 0) * 100)
	armorLabel.Text       = string.format("Armor: %s (%d%% DR)", armorId, pct)
	armorLabel.TextColor3 = color
	invArmorIcon.BackgroundColor3 = color
	invArmorSlotLbl.Text          = string.format("%s (%d%% DR)", armorId, pct)
	invArmorSlotLbl.TextColor3    = color
end)

-- Currency update
UpdateCurrency.OnClientEvent:Connect(function(amount)
	currencyLabel.Text    = "$ " .. tostring(amount)
	invCoinsLabel.Text    = "Coins: $" .. tostring(amount)
	shopCurrentBalance    = amount
	if shopPanel.Visible then
		shopBalanceLabel.Text = "Balance: $" .. tostring(amount)
	end
end)

-- Gems update
UpdateGems.OnClientEvent:Connect(function(gems)
	gemLabel.Text = "♦ " .. tostring(gems)
end)

-- ========== Hotbar updates from PlacementClient ==========

task.spawn(function()
	local invEvent      = player:WaitForChild("InventoryChanged",    10)
	local slotEvent     = player:WaitForChild("SelectedSlotChanged", 10)
	local selectSlotEvt = player:WaitForChild("SelectSlot",          10)

	-- Wire hotbar clicks → SelectSlot
	if selectSlotEvt then
		for i, slot in ipairs(slotFrames) do
			local capturedI = i
			slot.MouseButton1Click:Connect(function()
				selectSlotEvt:Fire(capturedI)
			end)
		end
		-- Wire inventory panel grid clicks → SelectSlot
		for i, cell in ipairs(invGridSlots) do
			local capturedI = i
			cell.MouseButton1Click:Connect(function()
				selectSlotEvt:Fire(capturedI)
			end)
		end
	end

	if invEvent then
		invEvent.Event:Connect(function(inv)
			for i, blockDef in ipairs(BLOCK_TYPES) do
				local count = inv[blockDef.id] or 0
				local dimColor = Color3.fromRGB(110, 110, 110)
				-- Hotbar
				countLabels[i].Text       = tostring(count)
				countLabels[i].TextColor3 = count == 0 and dimColor or Color3.new(1, 1, 1)
				if slotSwatches[i] then
					slotSwatches[i].BackgroundTransparency = count == 0 and 0.55 or 0
				end
				-- Inventory panel grid
				if invGridCounts[i] then
					invGridCounts[i].Text       = tostring(count)
					invGridCounts[i].TextColor3 = count == 0 and dimColor or Color3.new(1, 1, 1)
				end
				if invGridFills[i] then
					invGridFills[i].BackgroundTransparency = count == 0 and 0.55 or 0
				end
			end
		end)
	end

	if slotEvent then
		slotEvent.Event:Connect(function(slot)
			highlightSlot(slot)
			highlightInvSlot(slot)
		end)
	end
end)

-- ========== DEV CHEAT PANEL (backtick ` to toggle) ==========
do
	local cheatGui = Instance.new("ScreenGui")
	cheatGui.Name           = "CheatPanel"
	cheatGui.ResetOnSpawn   = false
	cheatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	cheatGui.Parent         = playerGui

	local panel = Instance.new("Frame")
	panel.Name                  = "Panel"
	panel.Size                  = UDim2.new(0, 280, 0, 310)
	panel.Position              = UDim2.new(0, 10, 0.5, -155)
	panel.BackgroundColor3      = Color3.fromRGB(20, 20, 30)
	panel.BorderSizePixel       = 0
	panel.Visible               = false
	panel.Parent                = cheatGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

	-- Title bar (drag handle)
	local titleBar = Instance.new("TextLabel")
	titleBar.Name              = "TitleBar"
	titleBar.Size              = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3  = Color3.fromRGB(80, 0, 140)
	titleBar.BorderSizePixel   = 0
	titleBar.Text              = "DEV PANEL  [ ` ]"
	titleBar.TextColor3        = Color3.new(1, 1, 1)
	titleBar.TextSize          = 14
	titleBar.Font              = Enum.Font.GothamBold
	titleBar.Parent            = panel
	Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

	-- Dragging logic
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = input.Position
			startPos  = panel.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			panel.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- Row builder helper
	local rowY = 40
	local function addRow(labelText, action, placeholder)
		local lbl = Instance.new("TextLabel")
		lbl.Size              = UDim2.new(0, 80, 0, 24)
		lbl.Position          = UDim2.new(0, 8, 0, rowY)
		lbl.BackgroundTransparency = 1
		lbl.Text              = labelText
		lbl.TextColor3        = Color3.fromRGB(200, 200, 200)
		lbl.TextSize          = 13
		lbl.Font              = Enum.Font.Gotham
		lbl.TextXAlignment    = Enum.TextXAlignment.Left
		lbl.Parent            = panel

		local box = Instance.new("TextBox")
		box.Size              = UDim2.new(0, 110, 0, 24)
		box.Position          = UDim2.new(0, 92, 0, rowY)
		box.BackgroundColor3  = Color3.fromRGB(40, 40, 55)
		box.BorderSizePixel   = 0
		box.Text              = ""
		box.PlaceholderText   = placeholder or "value"
		box.TextColor3        = Color3.new(1, 1, 1)
		box.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
		box.TextSize          = 13
		box.Font              = Enum.Font.Gotham
		box.ClearTextOnFocus  = false
		box.Parent            = panel
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(0, 56, 0, 24)
		btn.Position         = UDim2.new(0, 210, 0, rowY)
		btn.BackgroundColor3 = Color3.fromRGB(80, 0, 140)
		btn.BorderSizePixel  = 0
		btn.Text             = "Set"
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.TextSize         = 13
		btn.Font             = Enum.Font.GothamBold
		btn.Parent           = panel
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		btn.MouseButton1Click:Connect(function()
			DevCheat:FireServer(action, box.Text)
		end)

		rowY = rowY + 32
		return box
	end

	addRow("Coins",  "setCoins", "0–99999")
	addRow("Gems",   "setGems",  "0–99999")
	addRow("HP",     "setHP",    "1–500")

	-- Kit dropdown (cycling button)
	local KITS = {"none","speed","jump","miner","healer","trapper"}
	local kitIdx = 1
	local kitLabel = Instance.new("TextLabel")
	kitLabel.Size           = UDim2.new(0, 80, 0, 24)
	kitLabel.Position       = UDim2.new(0, 8, 0, rowY)
	kitLabel.BackgroundTransparency = 1
	kitLabel.Text           = "Kit"
	kitLabel.TextColor3     = Color3.fromRGB(200, 200, 200)
	kitLabel.TextSize       = 13
	kitLabel.Font           = Enum.Font.Gotham
	kitLabel.TextXAlignment = Enum.TextXAlignment.Left
	kitLabel.Parent         = panel

	local kitBtn = Instance.new("TextButton")
	kitBtn.Size            = UDim2.new(0, 166, 0, 24)
	kitBtn.Position        = UDim2.new(0, 92, 0, rowY)
	kitBtn.BackgroundColor3= Color3.fromRGB(40, 40, 55)
	kitBtn.BorderSizePixel = 0
	kitBtn.Text            = "none"
	kitBtn.TextColor3      = Color3.new(1, 1, 1)
	kitBtn.TextSize        = 13
	kitBtn.Font            = Enum.Font.Gotham
	kitBtn.Parent          = panel
	Instance.new("UICorner", kitBtn).CornerRadius = UDim.new(0, 4)
	kitBtn.MouseButton1Click:Connect(function()
		kitIdx = (kitIdx % #KITS) + 1
		kitBtn.Text = KITS[kitIdx]
		DevCheat:FireServer("setKit", KITS[kitIdx])
	end)
	rowY = rowY + 32

	-- Armor dropdown
	local ARMORS = {"none","leather","iron"}
	local armorIdx = 1
	local armorLabel = Instance.new("TextLabel")
	armorLabel.Size           = UDim2.new(0, 80, 0, 24)
	armorLabel.Position       = UDim2.new(0, 8, 0, rowY)
	armorLabel.BackgroundTransparency = 1
	armorLabel.Text           = "Armor"
	armorLabel.TextColor3     = Color3.fromRGB(200, 200, 200)
	armorLabel.TextSize       = 13
	armorLabel.Font           = Enum.Font.Gotham
	armorLabel.TextXAlignment = Enum.TextXAlignment.Left
	armorLabel.Parent         = panel

	local armorBtn = Instance.new("TextButton")
	armorBtn.Size            = UDim2.new(0, 166, 0, 24)
	armorBtn.Position        = UDim2.new(0, 92, 0, rowY)
	armorBtn.BackgroundColor3= Color3.fromRGB(40, 40, 55)
	armorBtn.BorderSizePixel = 0
	armorBtn.Text            = "none"
	armorBtn.TextColor3      = Color3.new(1, 1, 1)
	armorBtn.TextSize        = 13
	armorBtn.Font            = Enum.Font.Gotham
	armorBtn.Parent          = panel
	Instance.new("UICorner", armorBtn).CornerRadius = UDim.new(0, 4)
	armorBtn.MouseButton1Click:Connect(function()
		armorIdx = (armorIdx % #ARMORS) + 1
		armorBtn.Text = ARMORS[armorIdx]
		DevCheat:FireServer("setArmor", ARMORS[armorIdx])
	end)
	rowY = rowY + 32

	-- Status label
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size           = UDim2.new(1, -16, 0, 20)
	statusLbl.Position       = UDim2.new(0, 8, 0, rowY)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text           = "Gems: 0"
	statusLbl.TextColor3     = Color3.fromRGB(180, 130, 255)
	statusLbl.TextSize       = 12
	statusLbl.Font           = Enum.Font.Gotham
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent         = panel

	panel.Size = UDim2.new(0, 280, 0, rowY + 28)

	-- Mirror gem count in the dev panel status label
	UpdateGems.OnClientEvent:Connect(function(gems)
		statusLbl.Text = "Gems: " .. gems
	end)

	-- Toggle with backtick
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Backquote then
			panel.Visible = not panel.Visible
		end
	end)
end
