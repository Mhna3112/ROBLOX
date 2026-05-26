--[[
    Kick a Lucky Block - Autofarm & UI
    Developed by Gemini CLI
]]

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Packages.Network)

-- GUI creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AlimeFarm"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 220, 0, 280)
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Kick a Lucky Block"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 1, -45)
scroll.Position = UDim2.new(0, 5, 0, 40)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = scroll

local function createToggle(name, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -5, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    button.Text = name .. ": OFF"
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.AutoButtonColor = false
    button.Parent = scroll
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button

    local enabled = false
    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        button.Text = name .. ": " .. (enabled and "ON" or "OFF")
        button.TextColor3 = enabled and Color3.new(1, 1, 1) or Color3.new(0.8, 0.8, 0.8)
        button.BackgroundColor3 = enabled and Color3.fromRGB(0, 120, 215) or Color3.fromRGB(40, 40, 40)
        callback(enabled)
    end)
    return button
end

local flags = {
    AutoKick = false,
    AutoCollect = false,
    AutoSell = false,
    AutoUpgrade = false
}

createToggle("Auto Kick & Open", function(v) flags.AutoKick = v end)
createToggle("Auto Collect Drops", function(v) flags.AutoCollect = v end)
createToggle("Auto Sell All", function(v) flags.AutoSell = v end)
createToggle("Auto Buy Upgrades", function(v) flags.AutoUpgrade = v end)

-- Autofarm Loops

-- Kick & Open
task.spawn(function()
    while task.wait(0.2) do
        if flags.AutoKick then
            -- Multiple remotes to ensure it works
            Network.FireServer("KickEvent")
            Network.FireServer("lb_open")
            Network.FireServer("LB_OpenRequest")
            Network.FireServer("TaviMishkal") -- Training/Weight
        end
    end
end)

-- Collect
task.spawn(function()
    while task.wait(0.5) do
        if flags.AutoCollect then
            -- Based on logs, B_Collect takes an index. 
            -- We try a range that usually covers most drops.
            for i = 1, 30 do
                Network.FireServer("B_Collect", i)
            end
        end
    end
end)

-- Sell
task.spawn(function()
    while task.wait(10) do
        if flags.AutoSell then
            -- Selling brainrots
            Network.InvokeServer("B_SellAll")
        end
    end
end)

-- Upgrades
task.spawn(function()
    while task.wait(5) do
        if flags.AutoUpgrade then
            Network.FireServer("SPEED_UPGRADE")
            Network.FireServer("bs_upgrade") -- Slot upgrades
            Network.FireServer("Weight_Update")
        end
    end
end)

print("Alime Farm Loaded!")
