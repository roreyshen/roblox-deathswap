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

-- ── Test Mode button (visible in lobby only) ──
local testButton = Instance.new("TextButton")
testButton.Name                   = "TestModeButton"
testButton.Size                   = UDim2.new(0, 200, 0, 50)
testButton.Position               = UDim2.new(0.5, -100, 0.56, 0)
testButton.BackgroundColor3       = Color3.fromRGB(50, 160, 50)
testButton.TextColor3             = Color3.new(1, 1, 1)
testButton.TextScaled             = true
testButton.Font                   = Enum.Font.GothamBold
testButton.Text                   = "TEST (Solo)"
testButton.ZIndex                 = 5
testButton.Parent                 = screenGui
Instance.new("UICorner", testButton).CornerRadius = UDim.new(0, 10)

testButton.MouseButton1Click:Connect(function()
	StartTestMode:FireServer()
	testButton.Text   = "Starting..."
	testButton.Active = false
end)

-- ── RPG Inventory Panel (I key / bag button) ──
local invPanelOpen = false

local invPanel = Instance.new("Frame")
invPanel.Name                   = "InventoryPanel"
invPanel.Size                   = UDim2.new(0, 390, 0, 460)
invPanel.Position               = UDim2.new(0.5, -195, 0.5, -230)
invPanel.BackgroundColor3       = Color3.fromRGB(18, 15, 11)
invPanel.BorderSizePixel        = 0
invPanel.Visible                = false
invPanel.ZIndex                 = 30
invPanel.Parent                 = screenGui
Instance.new("UICorner", invPanel).CornerRadius = UDim.new(0, 10)
local invPanelStroke = Instance.new("UIStroke", invPanel)
invPanelStroke.Color     = Color3.fromRGB(145, 115, 50)
invPanelStroke.Thickness = 3

-- Header
local invHeader = Instance.new("Frame", invPanel)
invHeader.Size             = UDim2.new(1, 0, 0, 36)
invHeader.BackgroundColor3 = Color3.fromRGB(38, 30, 18)
invHeader.BorderSizePixel  = 0
invHeader.ZIndex           = 31
Instance.new("UICorner", invHeader).CornerRadius = UDim.new(0, 10)
local invHeaderPatch = Instance.new("Frame", invHeader)
invHeaderPatch.Size             = UDim2.new(1, 0, 0.5, 0)
invHeaderPatch.Position         = UDim2.new(0, 0, 0.5, 0)
invHeaderPatch.BackgroundColor3 = Color3.fromRGB(38, 30, 18)
invHeaderPatch.BorderSizePixel  = 0
invHeaderPatch.ZIndex           = 31

local invTitle = Instance.new("TextLabel", invHeader)
invTitle.Size                   = UDim2.new(1, -44, 1, 0)
invTitle.Position               = UDim2.new(0, 12, 0, 0)
invTitle.BackgroundTransparency = 1
invTitle.TextColor3             = Color3.fromRGB(205, 170, 70)
invTitle.TextScaled             = true
invTitle.Font                   = Enum.Font.GothamBold
invTitle.Text                   = "INVENTORY  [I]"
invTitle.TextXAlignment         = Enum.TextXAlignment.Left
invTitle.ZIndex                 = 32

local invCloseBtn = Instance.new("TextButton", invHeader)
invCloseBtn.Size             = UDim2.new(0, 28, 0, 28)
invCloseBtn.Position         = UDim2.new(1, -32, 0.5, -14)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
invCloseBtn.TextColor3       = Color3.new(1, 1, 1)
invCloseBtn.TextScaled       = true
invCloseBtn.Font             = Enum.Font.GothamBold
invCloseBtn.Text             = "X"
invCloseBtn.ZIndex           = 32
Instance.new("UICorner", invCloseBtn).CornerRadius = UDim.new(0, 5)
invCloseBtn.MouseButton1Click:Connect(function()
	invPanelOpen = false
	invPanel.Visible = false
end)

-- Vertical divider
local invVDiv = Instance.new("Frame", invPanel)
invVDiv.Size             = UDim2.new(0, 1, 1, -42)
invVDiv.Position         = UDim2.new(0, 148, 0, 40)
invVDiv.BackgroundColor3 = Color3.fromRGB(100, 80, 35)
invVDiv.BorderSizePixel  = 0
invVDiv.ZIndex           = 31

-- ── LEFT: Equipment + Stats ──
local invLeft = Instance.new("Frame", invPanel)
invLeft.Size                   = UDim2.new(0, 148, 1, -42)
invLeft.Position               = UDim2.new(0, 0, 0, 40)
invLeft.BackgroundTransparency = 1
invLeft.ZIndex                 = 31

local function invSectionLbl(parent, text, yPos)
	local l = Instance.new("TextLabel", parent)
	l.Size = UDim2.new(1, -10, 0, 18)
	l.Position = UDim2.new(0, 6, 0, yPos)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(165, 132, 60)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.ZIndex = 32
	return l
end

invSectionLbl(invLeft, "EQUIPPED", 6)

local invArmorSlot = Instance.new("Frame", invLeft)
invArmorSlot.Size             = UDim2.new(0, 110, 0, 110)
invArmorSlot.Position         = UDim2.new(0.5, -55, 0, 28)
invArmorSlot.BackgroundColor3 = Color3.fromRGB(30, 25, 18)
invArmorSlot.BorderSizePixel  = 0
invArmorSlot.ZIndex           = 32
Instance.new("UICorner", invArmorSlot).CornerRadius = UDim.new(0, 8)
local invArmorSlotStroke = Instance.new("UIStroke", invArmorSlot)
invArmorSlotStroke.Color = Color3.fromRGB(100, 80, 38)
invArmorSlotStroke.Thickness = 2

local invArmorIcon = Instance.new("Frame", invArmorSlot)
invArmorIcon.Size             = UDim2.new(0.65, 0, 0.6, 0)
invArmorIcon.Position         = UDim2.new(0.175, 0, 0.08, 0)
invArmorIcon.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
invArmorIcon.BorderSizePixel  = 0
invArmorIcon.ZIndex           = 33
Instance.new("UICorner", invArmorIcon).CornerRadius = UDim.new(0, 5)

local invArmorSlotLbl = Instance.new("TextLabel", invArmorSlot)
invArmorSlotLbl.Size                   = UDim2.new(1, -4, 0, 22)
invArmorSlotLbl.Position               = UDim2.new(0, 2, 1, -24)
invArmorSlotLbl.BackgroundTransparency = 1
invArmorSlotLbl.TextColor3             = Color3.fromRGB(180, 180, 180)
invArmorSlotLbl.TextScaled             = true
invArmorSlotLbl.Font                   = Enum.Font.GothamBold
invArmorSlotLbl.Text                   = "None"
invArmorSlotLbl.ZIndex                 = 33

local invArmorTypeLbl = Instance.new("TextLabel", invLeft)
invArmorTypeLbl.Size                   = UDim2.new(1, -10, 0, 14)
invArmorTypeLbl.Position               = UDim2.new(0, 6, 0, 142)
invArmorTypeLbl.BackgroundTransparency = 1
invArmorTypeLbl.TextColor3             = Color3.fromRGB(120, 100, 55)
invArmorTypeLbl.TextScaled             = true
invArmorTypeLbl.Font                   = Enum.Font.Gotham
invArmorTypeLbl.Text                   = "CHEST ARMOR"
invArmorTypeLbl.ZIndex                 = 32

local invStatsDivider = Instance.new("Frame", invLeft)
invStatsDivider.Size             = UDim2.new(1, -14, 0, 1)
invStatsDivider.Position         = UDim2.new(0, 7, 0, 162)
invStatsDivider.BackgroundColor3 = Color3.fromRGB(100, 80, 35)
invStatsDivider.BorderSizePixel  = 0
invStatsDivider.ZIndex           = 32

invSectionLbl(invLeft, "STATS", 168)

local invHPLabel = Instance.new("TextLabel", invLeft)
invHPLabel.Size                   = UDim2.new(1, -10, 0, 18)
invHPLabel.Position               = UDim2.new(0, 6, 0, 190)
invHPLabel.BackgroundTransparency = 1
invHPLabel.TextColor3             = Color3.fromRGB(255, 80, 80)
invHPLabel.TextScaled             = true
invHPLabel.Font                   = Enum.Font.Gotham
invHPLabel.Text                   = "HP: --- / ---"
invHPLabel.TextXAlignment         = Enum.TextXAlignment.Left
invHPLabel.ZIndex                 = 32

local invCoinsLabel = Instance.new("TextLabel", invLeft)
invCoinsLabel.Size                   = UDim2.new(1, -10, 0, 18)
invCoinsLabel.Position               = UDim2.new(0, 6, 0, 212)
invCoinsLabel.BackgroundTransparency = 1
invCoinsLabel.TextColor3             = Color3.fromRGB(255, 215, 0)
invCoinsLabel.TextScaled             = true
invCoinsLabel.Font                   = Enum.Font.Gotham
invCoinsLabel.Text                   = "Coins: $0"
invCoinsLabel.TextXAlignment         = Enum.TextXAlignment.Left
invCoinsLabel.ZIndex                 = 32

-- ── RIGHT: Block grid ──
local invRight = Instance.new("Frame", invPanel)
invRight.Size                   = UDim2.new(1, -156, 1, -42)
invRight.Position               = UDim2.new(0, 153, 0, 40)
invRight.BackgroundTransparency = 1
invRight.ZIndex                 = 31

invSectionLbl(invRight, "BLOCKS  (click to select)", 6)

local IGRID  = 68
local IGAP   = 5
local ICOLS  = 3
local invGridSlots  = {}
local invGridCounts = {}
local invGridFills  = {}

for i, blockDef in ipairs(BLOCK_TYPES) do
	local col = (i - 1) % ICOLS
	local row = math.floor((i - 1) / ICOLS)
	local gx  = col * (IGRID + IGAP) + 4
	local gy  = row * (IGRID + IGAP) + 28

	local cell = Instance.new("TextButton", invRight)
	cell.Size             = UDim2.new(0, IGRID, 0, IGRID)
	cell.Position         = UDim2.new(0, gx, 0, gy)
	cell.BackgroundColor3 = Color3.fromRGB(28, 24, 18)
	cell.BorderSizePixel  = 0
	cell.Text             = ""
	cell.AutoButtonColor  = false
	cell.ZIndex           = 32
	Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)
	local cs = Instance.new("UIStroke", cell)
	cs.Color     = Color3.fromRGB(90, 72, 38)
	cs.Thickness = 2

	local fill = Instance.new("Frame", cell)
	fill.Size             = UDim2.new(1, -8, 0, IGRID - 24)
	fill.Position         = UDim2.new(0, 4, 0, 3)
	fill.BackgroundColor3 = blockDef.color
	fill.BorderSizePixel  = 0
	fill.ZIndex           = 33
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local nameL = Instance.new("TextLabel", cell)
	nameL.Size = UDim2.new(1, -4, 0, 17)
	nameL.Position = UDim2.new(0, 2, 1, -19)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3 = Color3.fromRGB(210, 210, 210)
	nameL.TextScaled = true
	nameL.Font = Enum.Font.GothamBold
	nameL.Text = blockDef.id
	nameL.ZIndex = 33

	local cntL = Instance.new("TextLabel", cell)
	cntL.Size = UDim2.new(0, 28, 0, 18)
	cntL.Position = UDim2.new(1, -30, 0, 2)
	cntL.BackgroundTransparency = 1
	cntL.TextColor3 = Color3.new(1, 1, 1)
	cntL.TextScaled = true
	cntL.Font = Enum.Font.GothamBold
	cntL.Text = "0"
	cntL.ZIndex = 34

	invGridSlots[i]  = cell
	invGridCounts[i] = cntL
	invGridFills[i]  = fill
end

local function highlightInvSlot(index)
	for i, cell in ipairs(invGridSlots) do
		local s = cell:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color     = (i == index) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(90, 72, 38)
			s.Thickness = (i == index) and 3 or 2
		end
	end
end
highlightInvSlot(1)

-- Bag toggle button (bottom-left, above hotbar)
local invToggleBtn = Instance.new("TextButton")
invToggleBtn.Name             = "InvToggleBtn"
invToggleBtn.Size             = UDim2.new(0, 54, 0, 40)
invToggleBtn.Position         = UDim2.new(0, 10, 1, -104)
invToggleBtn.BackgroundColor3 = Color3.fromRGB(38, 30, 18)
invToggleBtn.TextColor3       = Color3.fromRGB(200, 165, 70)
invToggleBtn.TextScaled       = true
invToggleBtn.Font             = Enum.Font.GothamBold
invToggleBtn.Text             = "[I]"
invToggleBtn.Visible          = false
invToggleBtn.ZIndex           = 6
invToggleBtn.Parent           = screenGui
Instance.new("UICorner", invToggleBtn).CornerRadius = UDim.new(0, 8)
local invBtnStroke = Instance.new("UIStroke", invToggleBtn)
invBtnStroke.Color     = Color3.fromRGB(145, 115, 50)
invBtnStroke.Thickness = 2

invToggleBtn.MouseButton1Click:Connect(function()
	invPanelOpen = not invPanelOpen
	invPanel.Visible = invPanelOpen
end)

-- I key toggles the panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.I then return end
	if currentState ~= "SETUP" and currentState ~= "PLAYING" then return end
	invPanelOpen = not invPanelOpen
	invPanel.Visible = invPanelOpen
end)

-- Live HP update: hearts bar always, inventory panel when open
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if heartsFrame.Visible then
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

-- ── Hearts health bar (above hotbar) ──
local HEART_SIZE = 26
local HEART_GAP  = 3
local NUM_HEARTS = 10

local heartsFrame = Instance.new("Frame")
heartsFrame.Name                   = "HeartsFrame"
heartsFrame.Size                   = UDim2.new(0, NUM_HEARTS * (HEART_SIZE + HEART_GAP) - HEART_GAP, 0, HEART_SIZE)
heartsFrame.BackgroundTransparency = 1
heartsFrame.Visible                = false
heartsFrame.Parent                 = screenGui

local heartFrames = {}
for hi = 1, NUM_HEARTS do
	local h = Instance.new("Frame")
	h.Size             = UDim2.new(0, HEART_SIZE, 0, HEART_SIZE)
	h.Position         = UDim2.new(0, (hi - 1) * (HEART_SIZE + HEART_GAP), 0, 0)
	h.BackgroundColor3 = Color3.fromRGB(200, 35, 35)
	h.BorderSizePixel  = 0
	h.Parent           = heartsFrame
	Instance.new("UICorner", h).CornerRadius = UDim.new(0, 5)
	-- Inner pixel shadow for blocky look
	local inner = Instance.new("Frame", h)
	inner.Size             = UDim2.new(1, -4, 1, -4)
	inner.Position         = UDim2.new(0, 2, 0, 2)
	inner.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	inner.BorderSizePixel  = 0
	Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 3)
	heartFrames[hi] = h
end

local function updateHearts(hp, maxHp)
	local hpPerHeart = (maxHp or 100) / NUM_HEARTS
	for hi = 1, NUM_HEARTS do
		local threshold = hi * hpPerHeart
		if hp >= threshold then
			-- Full heart
			heartFrames[hi].BackgroundColor3 = Color3.fromRGB(190, 30, 30)
			heartFrames[hi].BackgroundTransparency = 0
			local inner = heartFrames[hi]:FindFirstChildOfClass("Frame")
			if inner then inner.BackgroundColor3 = Color3.fromRGB(255, 60, 60); inner.BackgroundTransparency = 0 end
		elseif hp > (hi - 1) * hpPerHeart then
			-- Half / partial heart
			heartFrames[hi].BackgroundColor3 = Color3.fromRGB(130, 25, 25)
			heartFrames[hi].BackgroundTransparency = 0
			local inner = heartFrames[hi]:FindFirstChildOfClass("Frame")
			if inner then inner.BackgroundColor3 = Color3.fromRGB(180, 45, 45); inner.BackgroundTransparency = 0 end
		else
			-- Empty heart
			heartFrames[hi].BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			heartFrames[hi].BackgroundTransparency = 0.3
			local inner = heartFrames[hi]:FindFirstChildOfClass("Frame")
			if inner then inner.BackgroundColor3 = Color3.fromRGB(70, 70, 70); inner.BackgroundTransparency = 0.3 end
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

-- Position hearts above hotbar (hotbar is at Y offset -(SLOT_SIZE+14))
local hotbarHeartOffset = -(SLOT_SIZE + 14 + HEART_SIZE + 6)
heartsFrame.Position = UDim2.new(
	0.5, -math.floor((NUM_HEARTS * (HEART_SIZE + HEART_GAP) - HEART_GAP) / 2),
	1, hotbarHeartOffset
)

-- ── Kit Shop button (next to inventory toggle) ──
local kitShopBtn = Instance.new("TextButton")
kitShopBtn.Name             = "KitShopBtn"
kitShopBtn.Size             = UDim2.new(0, 54, 0, 40)
kitShopBtn.Position         = UDim2.new(0, 68, 1, -104)
kitShopBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 160)
kitShopBtn.TextColor3       = Color3.fromRGB(220, 180, 255)
kitShopBtn.TextScaled       = true
kitShopBtn.Font             = Enum.Font.GothamBold
kitShopBtn.Text             = "[K]"
kitShopBtn.Visible          = false
kitShopBtn.ZIndex           = 6
kitShopBtn.Parent           = screenGui
Instance.new("UICorner", kitShopBtn).CornerRadius = UDim.new(0, 8)
local kitBtnStroke = Instance.new("UIStroke", kitShopBtn)
kitBtnStroke.Color     = Color3.fromRGB(180, 100, 255)
kitBtnStroke.Thickness = 2

-- ── Kit Shop Panel ──
local kitPanelOpen = false

local KIT_DEFS_CLIENT = {
	{ id = "Speed",   desc = "+15% WalkSpeed" },
	{ id = "Jump",    desc = "+20% JumpPower"  },
	{ id = "Miner",   desc = "+50% mine speed" },
	{ id = "Healer",  desc = "2 HP/sec regen"  },
	{ id = "Trapper", desc = "+25% trap dmg"   },
}
local KIT_COST = 100

local kitPanel = Instance.new("Frame")
kitPanel.Name                   = "KitPanel"
kitPanel.Size                   = UDim2.new(0, 300, 0, 380)
kitPanel.Position               = UDim2.new(0.5, -150, 0.5, -190)
kitPanel.BackgroundColor3       = Color3.fromRGB(20, 10, 35)
kitPanel.BackgroundTransparency = 0.05
kitPanel.Visible                = false
kitPanel.ZIndex                 = 25
kitPanel.Parent                 = screenGui
Instance.new("UICorner", kitPanel).CornerRadius = UDim.new(0, 12)
local kitPanelStroke = Instance.new("UIStroke", kitPanel)
kitPanelStroke.Color     = Color3.fromRGB(140, 70, 220)
kitPanelStroke.Thickness = 2

local kitHeader = Instance.new("TextLabel", kitPanel)
kitHeader.Size                   = UDim2.new(1, -40, 0, 40)
kitHeader.Position               = UDim2.new(0, 10, 0, 8)
kitHeader.BackgroundTransparency = 1
kitHeader.TextColor3             = Color3.fromRGB(200, 140, 255)
kitHeader.TextScaled             = true
kitHeader.Font                   = Enum.Font.GothamBold
kitHeader.Text                   = "KIT SHOP"
kitHeader.ZIndex                 = 26

local kitClose = Instance.new("TextButton", kitPanel)
kitClose.Size             = UDim2.new(0, 30, 0, 30)
kitClose.Position         = UDim2.new(1, -35, 0, 8)
kitClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
kitClose.TextColor3       = Color3.new(1, 1, 1)
kitClose.TextScaled       = true
kitClose.Font             = Enum.Font.GothamBold
kitClose.Text             = "X"
kitClose.ZIndex           = 26
Instance.new("UICorner", kitClose).CornerRadius = UDim.new(0, 6)

kitClose.MouseButton1Click:Connect(function()
	kitPanelOpen   = false
	kitPanel.Visible = false
end)

local kitGemLabel = Instance.new("TextLabel", kitPanel)
kitGemLabel.Size                   = UDim2.new(1, -20, 0, 26)
kitGemLabel.Position               = UDim2.new(0, 10, 0, 50)
kitGemLabel.BackgroundTransparency = 1
kitGemLabel.TextColor3             = Color3.fromRGB(200, 150, 255)
kitGemLabel.TextScaled             = true
kitGemLabel.Font                   = Enum.Font.Gotham
kitGemLabel.Text                   = "Gems: 0"
kitGemLabel.ZIndex                 = 26

local kitFeedback = Instance.new("TextLabel", kitPanel)
kitFeedback.Size                   = UDim2.new(1, -20, 0, 22)
kitFeedback.Position               = UDim2.new(0, 10, 1, -28)
kitFeedback.BackgroundTransparency = 1
kitFeedback.TextColor3             = Color3.fromRGB(100, 255, 100)
kitFeedback.TextScaled             = true
kitFeedback.Font                   = Enum.Font.Gotham
kitFeedback.Text                   = ""
kitFeedback.ZIndex                 = 26

local PurchaseKit = RemoteEvents:WaitForChild("PurchaseKit")
local KitPurchaseResponse = RemoteEvents:WaitForChild("KitPurchaseResponse")

local kitRowY = 84
for _, kdef in ipairs(KIT_DEFS_CLIENT) do
	local row = Instance.new("Frame", kitPanel)
	row.Size              = UDim2.new(1, -20, 0, 48)
	row.Position          = UDim2.new(0, 10, 0, kitRowY)
	row.BackgroundColor3  = Color3.fromRGB(40, 20, 60)
	row.BorderSizePixel   = 0
	row.ZIndex            = 27
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local nameL = Instance.new("TextLabel", row)
	nameL.Size                   = UDim2.new(0.55, 0, 0.5, 0)
	nameL.Position               = UDim2.new(0, 8, 0, 2)
	nameL.BackgroundTransparency = 1
	nameL.TextColor3             = Color3.fromRGB(230, 200, 255)
	nameL.TextScaled             = true
	nameL.Font                   = Enum.Font.GothamBold
	nameL.Text                   = kdef.id
	nameL.TextXAlignment         = Enum.TextXAlignment.Left
	nameL.ZIndex                 = 28

	local descL = Instance.new("TextLabel", row)
	descL.Size                   = UDim2.new(0.55, 0, 0.45, 0)
	descL.Position               = UDim2.new(0, 8, 0.5, 0)
	descL.BackgroundTransparency = 1
	descL.TextColor3             = Color3.fromRGB(170, 140, 200)
	descL.TextScaled             = true
	descL.Font                   = Enum.Font.Gotham
	descL.Text                   = kdef.desc
	descL.TextXAlignment         = Enum.TextXAlignment.Left
	descL.ZIndex                 = 28

	local buyK = Instance.new("TextButton", row)
	buyK.Size             = UDim2.new(0, 90, 0, 32)
	buyK.Position         = UDim2.new(1, -98, 0.5, -16)
	buyK.BackgroundColor3 = Color3.fromRGB(100, 40, 160)
	buyK.TextColor3       = Color3.new(1, 1, 1)
	buyK.TextScaled       = true
	buyK.Font             = Enum.Font.GothamBold
	buyK.Text             = "♦ " .. KIT_COST
	buyK.ZIndex           = 28
	Instance.new("UICorner", buyK).CornerRadius = UDim.new(0, 6)

	local capturedKit = kdef.id
	buyK.MouseButton1Click:Connect(function()
		PurchaseKit:FireServer(capturedKit)
	end)

	kitRowY = kitRowY + 54
end

kitShopBtn.MouseButton1Click:Connect(function()
	kitPanelOpen   = not kitPanelOpen
	kitPanel.Visible = kitPanelOpen
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.K then
		if currentState ~= "SETUP" and currentState ~= "PLAYING" then return end
		kitPanelOpen   = not kitPanelOpen
		kitPanel.Visible = kitPanelOpen
	end
end)

KitPurchaseResponse.OnClientEvent:Connect(function(success, message, kitId)
	kitFeedback.Text       = message or ""
	kitFeedback.TextColor3 = success
		and Color3.fromRGB(80, 255, 80)
		or  Color3.fromRGB(255, 80, 80)
end)

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
	testButton.Visible     = (state == "LOBBY")
	invToggleBtn.Visible   = (isSetup or isPlaying)
	kitShopBtn.Visible     = (isSetup or isPlaying)

	-- Close shop/inventory/kit panel when transitioning away from active play
	if isLobby or isResults then
		shopPanel.Visible = false
		invPanel.Visible  = false
		kitPanel.Visible  = false
		invPanelOpen      = false
		kitPanelOpen      = false
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
	gemLabel.Text      = "♦ " .. tostring(gems)
	kitGemLabel.Text   = "Gems: " .. tostring(gems)
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
		if input.KeyCode == Enum.KeyCode.BackQuote then
			panel.Visible = not panel.Visible
		end
	end)
end
