-- LocalScript: StarterPlayerScripts > WeaponClient
-- Fires SwordSwing to server when a Sword tool is activated.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local SwordSwing   = RemoteEvents:WaitForChild("SwordSwing")

local player = Players.LocalPlayer

local function hookTool(tool)
	if tool:GetAttribute("WeaponType") ~= "Sword" then return end
	tool.Activated:Connect(function()
		local tier = tool:GetAttribute("Tier") or "Wood"
		SwordSwing:FireServer(tier)
	end)
end

-- Hook tools already in backpack
local backpack = player:WaitForChild("Backpack")
for _, tool in ipairs(backpack:GetChildren()) do hookTool(tool) end
backpack.ChildAdded:Connect(hookTool)

-- Hook tools equipped to character
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then hookTool(child) end
	end)
end)
