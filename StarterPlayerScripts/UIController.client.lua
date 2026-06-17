-- LocalScript: StarterPlayerScripts > UIController
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig    = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local RoundStateChanged = RemoteEvents:WaitForChild("RoundStateChanged")
local UpdateTimers  = RemoteEvents:WaitForChild("UpdateTimers")
local SwapPlayers   = RemoteEvents:WaitForChild("SwapPlayers")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BLOCK_TYPES = GameConfig.BLOCK_TYPES

-- ========== Build the HUD ==========

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- Full-screen swap flash overlay
local flashFrame = Instance.new("Frame")
flashFrame.Name            = "FlashOverlay"
flashFrame.Size            = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.ZIndex          = 10
flashFrame.Parent          = screenGui

-- Status label (shown during lobby / countdown / results)
local statusLabel = Instance.new("TextLabel")
statusLabel.Name            = "StatusLabel"
statusLabel.Size            = UDim2.new(0.6, 0, 0.1, 0)
statusLabel.Position        = UDim2.new(0.2, 0, 0.42, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3      = Color3.new(1, 1, 1)
statusLabel.TextScaled      = true
statusLabel.Font            = Enum.Font.GothamBold
statusLabel.Text            = "Waiting for players..."
statusLabel.Parent          = screenGui

-- Swap timer (top-center)
local swapLabel = Instance.new("TextLabel")
swapLabel.Name            = "SwapLabel"
swapLabel.Size            = UDim2.new(0.3, 0, 0.07, 0)
swapLabel.Position        = UDim2.new(0.35, 0, 0.02, 0)
swapLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
swapLabel.BackgroundTransparency = 0.4
swapLabel.TextColor3      = Color3.new(1, 1, 0)
swapLabel.TextScaled      = true
swapLabel.Font            = Enum.Font.GothamBold
swapLabel.Text            = "SWAP IN: --"
swapLabel.Visible         = false
swapLabel.Parent          = screenGui
Instance.new("UICorner", swapLabel).CornerRadius = UDim.new(0, 6)

-- Round timer (top-right)
local roundLabel = Instance.new("TextLabel")
roundLabel.Name            = "RoundLabel"
roundLabel.Size            = UDim2.new(0.2, 0, 0.05, 0)
roundLabel.Position        = UDim2.new(0.78, 0, 0.03, 0)
roundLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
roundLabel.BackgroundTransparency = 0.5
roundLabel.TextColor3      = Color3.new(1, 1, 1)
roundLabel.TextScaled      = true
roundLabel.Font            = Enum.Font.Gotham
roundLabel.Text            = ""
roundLabel.Visible         = false
roundLabel.Parent          = screenGui
Instance.new("UICorner", roundLabel).CornerRadius = UDim.new(0, 6)

-- Win screen (hidden until results)
local winScreen = Instance.new("Frame")
winScreen.Name                   = "WinScreen"
winScreen.Size                   = UDim2.new(0.5, 0, 0.3, 0)
winScreen.Position               = UDim2.new(0.25, 0, 0.35, 0)
winScreen.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
winScreen.BackgroundTransparency = 0.2
winScreen.Visible                = false
winScreen.Parent                 = screenGui
Instance.new("UICorner", winScreen).CornerRadius = UDim.new(0, 12)

local winLabel = Instance.new("TextLabel")
winLabel.Size            = UDim2.fromScale(1, 1)
winLabel.BackgroundTransparency = 1
winLabel.TextColor3      = Color3.new(1, 1, 0)
winLabel.TextScaled      = true
winLabel.Font            = Enum.Font.GothamBold
winLabel.Text            = ""
winLabel.Parent          = winScreen

-- Hotbar (bottom-center)
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name                   = "HotbarFrame"
hotbarFrame.Size                   = UDim2.new(0, #BLOCK_TYPES * 70, 0, 70)
hotbarFrame.Position               = UDim2.new(0.5, -#BLOCK_TYPES * 35, 1, -90)
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.Visible                = false
hotbarFrame.Parent                 = screenGui

local slotFrames = {}
local countLabels = {}

for i, blockDef in ipairs(BLOCK_TYPES) do
	local slot = Instance.new("Frame")
	slot.Size            = UDim2.new(0, 62, 0, 62)
	slot.Position        = UDim2.new(0, (i - 1) * 70, 0, 0)
	slot.BackgroundColor3 = blockDef.color
	slot.BorderSizePixel = 3
	slot.Parent          = hotbarFrame
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size            = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3      = Color3.new(1, 1, 1)
	nameLabel.TextScaled      = true
	nameLabel.Font            = Enum.Font.GothamBold
	nameLabel.Text            = blockDef.id
	nameLabel.Parent          = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Size            = UDim2.new(1, 0, 0.5, 0)
	countLabel.Position        = UDim2.new(0, 0, 0.5, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3      = Color3.new(1, 1, 1)
	countLabel.TextScaled      = true
	countLabel.Font            = Enum.Font.Gotham
	countLabel.Text            = "0"
	countLabel.Parent          = slot

	slotFrames[i]  = slot
	countLabels[i] = countLabel
end

local selectedSlot = 1
local function highlightSlot(index)
	for i, frame in ipairs(slotFrames) do
		frame.BorderColor3 = (i == index) and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80)
	end
end
highlightSlot(1)

-- ========== Remote listeners ==========

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

RoundStateChanged.OnClientEvent:Connect(function(state, data)
	local isPlaying  = (state == "PLAYING")
	local isResults  = (state == "RESULTS")
	local isLobby    = (state == "LOBBY" or state == "COUNTDOWN")

	swapLabel.Visible  = isPlaying
	roundLabel.Visible = isPlaying
	hotbarFrame.Visible = isPlaying
	winScreen.Visible  = isResults

	if isLobby then
		statusLabel.Visible = true
		statusLabel.Text    = (state == "COUNTDOWN") and "Game starting..." or "Waiting for players..."
	elseif isPlaying then
		statusLabel.Visible = false
	elseif isResults then
		statusLabel.Visible = false
		winLabel.Text = data and (data .. " wins!") or "Game Over"
	end
end)

UpdateTimers.OnClientEvent:Connect(function(timeToSwap, timeLeft)
	swapLabel.Text  = "SWAP IN: " .. math.max(0, math.floor(timeToSwap))
	roundLabel.Text = formatTime(math.max(0, math.floor(timeLeft)))

	-- Turn swap label red in the last 10 seconds before a swap
	if timeToSwap <= 10 then
		swapLabel.TextColor3 = Color3.new(1, 0.2, 0.2)
	else
		swapLabel.TextColor3 = Color3.new(1, 1, 0)
	end
end)

SwapPlayers.OnClientEvent:Connect(function()
	-- White flash effect on swap
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end)

-- ========== Hotbar updates from PlacementClient ==========

-- Wait for PlacementClient to create its BindableEvents
task.spawn(function()
	local invEvent  = player:WaitForChild("InventoryChanged", 10)
	local slotEvent = player:WaitForChild("SelectedSlotChanged", 10)

	if invEvent then
		invEvent.Event:Connect(function(inv)
			for i, blockDef in ipairs(BLOCK_TYPES) do
				countLabels[i].Text = tostring(inv[blockDef.id] or 0)
				-- Grey out slots with 0 blocks
				slotFrames[i].BackgroundTransparency = (inv[blockDef.id] or 0) == 0 and 0.6 or 0
			end
		end)
	end

	if slotEvent then
		slotEvent.Event:Connect(function(slot)
			selectedSlot = slot
			highlightSlot(slot)
		end)
	end
end)
