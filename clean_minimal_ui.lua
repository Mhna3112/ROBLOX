local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("CleanControlUI")
if existing then
    existing:Destroy()
end

local theme = {
    bg = Color3.fromRGB(14, 14, 16),
    panel = Color3.fromRGB(22, 22, 25),
    soft = Color3.fromRGB(32, 32, 36),
    line = Color3.fromRGB(52, 52, 58),
    text = Color3.fromRGB(235, 235, 240),
    muted = Color3.fromRGB(170, 170, 180),
    accent = Color3.fromRGB(120, 190, 255)
}

local transparency = {
    main = 0.28,
    panel = 0.35,
    soft = 0.42,
    accent = 0.12,
    icon = 0.30
}

local tags = {
    { name = "Farm", info = "Auto Farm, Harvest, Sell" },
    { name = "Shop", info = "Seed Roll, Buy, Upgrade" },
    { name = "Event", info = "QueenBee, Alien, Spin" },
    { name = "Player", info = "Movement, Utility, Misc" }
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CleanControlUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(560, 340)
main.Position = UDim2.new(0.5, -280, 0.5, -170)
main.BackgroundColor3 = theme.bg
main.BackgroundTransparency = transparency.main
main.BorderSizePixel = 0
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = theme.line
mainStroke.Thickness = 1
mainStroke.Transparency = 0.2
mainStroke.Parent = main

local top = Instance.new("Frame")
top.Name = "Top"
top.Size = UDim2.new(1, 0, 0, 44)
top.BackgroundColor3 = theme.panel
top.BackgroundTransparency = transparency.panel
top.BorderSizePixel = 0
top.Parent = main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = top

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 12)
topFix.Position = UDim2.fromOffset(0, 32)
topFix.BackgroundColor3 = theme.panel
topFix.BackgroundTransparency = transparency.panel
topFix.BorderSizePixel = 0
topFix.Parent = top

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 0)
title.Size = UDim2.new(1, -120, 1, 0)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = theme.text
title.Text = "Clean Hub"
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(90, 0)
subtitle.Size = UDim2.new(1, -180, 1, 0)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = theme.muted
subtitle.Text = "Ctrl: Toggle UI"
subtitle.Parent = top

local collapseBtn = Instance.new("TextButton")
collapseBtn.Name = "Collapse"
collapseBtn.Size = UDim2.fromOffset(28, 28)
collapseBtn.Position = UDim2.new(1, -36, 0, 8)
collapseBtn.BackgroundColor3 = theme.soft
collapseBtn.BackgroundTransparency = transparency.soft
collapseBtn.BorderSizePixel = 0
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 16
collapseBtn.TextColor3 = theme.text
collapseBtn.Text = "-"
collapseBtn.AutoButtonColor = true
collapseBtn.Parent = top

local collapseCorner = Instance.new("UICorner")
collapseCorner.CornerRadius = UDim.new(0, 8)
collapseCorner.Parent = collapseBtn

local nav = Instance.new("Frame")
nav.Name = "Tags"
nav.Position = UDim2.fromOffset(12, 56)
nav.Size = UDim2.fromOffset(160, 272)
nav.BackgroundColor3 = theme.panel
nav.BackgroundTransparency = transparency.panel
nav.BorderSizePixel = 0
nav.Parent = main

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 10)
navCorner.Parent = nav

local navPad = Instance.new("UIPadding")
navPad.PaddingTop = UDim.new(0, 10)
navPad.PaddingLeft = UDim.new(0, 10)
navPad.PaddingRight = UDim.new(0, 10)
navPad.PaddingBottom = UDim.new(0, 10)
navPad.Parent = nav

local navList = Instance.new("UIListLayout")
navList.Padding = UDim.new(0, 8)
navList.FillDirection = Enum.FillDirection.Vertical
navList.HorizontalAlignment = Enum.HorizontalAlignment.Center
navList.SortOrder = Enum.SortOrder.LayoutOrder
navList.Parent = nav

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(184, 56)
content.Size = UDim2.fromOffset(364, 272)
content.BackgroundColor3 = theme.panel
content.BackgroundTransparency = transparency.panel
content.BorderSizePixel = 0
content.Parent = main

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = content

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 16)
contentPad.PaddingLeft = UDim.new(0, 16)
contentPad.PaddingRight = UDim.new(0, 16)
contentPad.PaddingBottom = UDim.new(0, 16)
contentPad.Parent = content

local contentTag = Instance.new("TextLabel")
contentTag.BackgroundTransparency = 1
contentTag.Size = UDim2.new(1, 0, 0, 26)
contentTag.Font = Enum.Font.GothamSemibold
contentTag.TextSize = 20
contentTag.TextXAlignment = Enum.TextXAlignment.Left
contentTag.TextColor3 = theme.text
contentTag.Text = "Farm"
contentTag.Parent = content

local contentInfo = Instance.new("TextLabel")
contentInfo.BackgroundTransparency = 1
contentInfo.Position = UDim2.fromOffset(0, 34)
contentInfo.Size = UDim2.new(1, 0, 0, 20)
contentInfo.Font = Enum.Font.Gotham
contentInfo.TextSize = 13
contentInfo.TextXAlignment = Enum.TextXAlignment.Left
contentInfo.TextColor3 = theme.muted
contentInfo.Text = "Auto Farm, Harvest, Sell"
contentInfo.Parent = content

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(0, 66)
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = theme.line
divider.BackgroundTransparency = 0.55
divider.BorderSizePixel = 0
divider.Parent = content

local placeholder = Instance.new("TextLabel")
placeholder.BackgroundTransparency = 1
placeholder.Position = UDim2.fromOffset(0, 84)
placeholder.Size = UDim2.new(1, 0, 0, 46)
placeholder.Font = Enum.Font.Gotham
placeholder.TextWrapped = true
placeholder.TextYAlignment = Enum.TextYAlignment.Top
placeholder.TextXAlignment = Enum.TextXAlignment.Left
placeholder.TextSize = 13
placeholder.TextColor3 = theme.muted
placeholder.Text = "Auto Roll: set target rate then start."
placeholder.Parent = content

local autoWrap = Instance.new("Frame")
autoWrap.Name = "AutoRoll"
autoWrap.BackgroundColor3 = theme.soft
autoWrap.BackgroundTransparency = transparency.soft
autoWrap.BorderSizePixel = 0
autoWrap.Position = UDim2.fromOffset(0, 138)
autoWrap.Size = UDim2.new(1, 0, 0, 126)
autoWrap.Parent = content

local autoWrapCorner = Instance.new("UICorner")
autoWrapCorner.CornerRadius = UDim.new(0, 8)
autoWrapCorner.Parent = autoWrap

local autoTitle = Instance.new("TextLabel")
autoTitle.BackgroundTransparency = 1
autoTitle.Position = UDim2.fromOffset(10, 8)
autoTitle.Size = UDim2.new(1, -20, 0, 16)
autoTitle.Font = Enum.Font.GothamSemibold
autoTitle.TextSize = 12
autoTitle.TextXAlignment = Enum.TextXAlignment.Left
autoTitle.TextColor3 = theme.text
autoTitle.Text = "AUTO ROLL"
autoTitle.Parent = autoWrap

local rateBox = Instance.new("TextBox")
rateBox.Name = "RateBox"
rateBox.BackgroundColor3 = theme.panel
rateBox.BackgroundTransparency = transparency.panel
rateBox.BorderSizePixel = 0
rateBox.Position = UDim2.fromOffset(10, 30)
rateBox.Size = UDim2.new(1, -110, 0, 32)
rateBox.Font = Enum.Font.Gotham
rateBox.TextSize = 13
rateBox.TextColor3 = theme.text
rateBox.PlaceholderText = "Click rarity buttons below"
rateBox.PlaceholderColor3 = theme.muted
rateBox.Text = ""
rateBox.ClearTextOnFocus = false
rateBox.TextEditable = false
rateBox.Parent = autoWrap

local rateBoxCorner = Instance.new("UICorner")
rateBoxCorner.CornerRadius = UDim.new(0, 8)
rateBoxCorner.Parent = rateBox

local autoToggle = Instance.new("TextButton")
autoToggle.Name = "AutoToggle"
autoToggle.BackgroundColor3 = theme.accent
autoToggle.BackgroundTransparency = transparency.accent
autoToggle.BorderSizePixel = 0
autoToggle.Position = UDim2.new(1, -98, 0, 30)
autoToggle.Size = UDim2.fromOffset(88, 32)
autoToggle.Font = Enum.Font.GothamSemibold
autoToggle.TextSize = 13
autoToggle.TextColor3 = Color3.fromRGB(15, 20, 26)
autoToggle.Text = "Start"
autoToggle.Parent = autoWrap

local autoToggleCorner = Instance.new("UICorner")
autoToggleCorner.CornerRadius = UDim.new(0, 8)
autoToggleCorner.Parent = autoToggle

local autoRollAfterBuyBtn = Instance.new("TextButton")
autoRollAfterBuyBtn.Name = "AutoRollAfterBuy"
autoRollAfterBuyBtn.BackgroundColor3 = theme.soft
autoRollAfterBuyBtn.BackgroundTransparency = transparency.soft
autoRollAfterBuyBtn.BorderSizePixel = 0
autoRollAfterBuyBtn.Position = UDim2.new(1, -98, 0, 52)
autoRollAfterBuyBtn.Size = UDim2.fromOffset(88, 20)
autoRollAfterBuyBtn.Font = Enum.Font.Gotham
autoRollAfterBuyBtn.TextSize = 10
autoRollAfterBuyBtn.TextColor3 = theme.text
autoRollAfterBuyBtn.Text = "Buy->Roll: ON"
autoRollAfterBuyBtn.Parent = autoWrap

local autoRollAfterBuyCorner = Instance.new("UICorner")
autoRollAfterBuyCorner.CornerRadius = UDim.new(0, 6)
autoRollAfterBuyCorner.Parent = autoRollAfterBuyBtn

local autoBuySelectedBtn = Instance.new("TextButton")
autoBuySelectedBtn.Name = "AutoBuySelected"
autoBuySelectedBtn.BackgroundColor3 = theme.soft
autoBuySelectedBtn.BackgroundTransparency = transparency.soft
autoBuySelectedBtn.BorderSizePixel = 0
autoBuySelectedBtn.Position = UDim2.new(1, -98, 0, 74)
autoBuySelectedBtn.Size = UDim2.fromOffset(88, 20)
autoBuySelectedBtn.Font = Enum.Font.Gotham
autoBuySelectedBtn.TextSize = 10
autoBuySelectedBtn.TextColor3 = theme.text
autoBuySelectedBtn.Text = "AutoBuy: OFF"
autoBuySelectedBtn.Parent = autoWrap

local autoBuySelectedCorner = Instance.new("UICorner")
autoBuySelectedCorner.CornerRadius = UDim.new(0, 6)
autoBuySelectedCorner.Parent = autoBuySelectedBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(10, 54)
statusLabel.Size = UDim2.new(1, -110, 0, 40)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextColor3 = theme.muted
statusLabel.Text = "Status: Idle"
statusLabel.Parent = autoWrap

local rarityButtonsFrame = Instance.new("Frame")
rarityButtonsFrame.Name = "RarityButtons"
rarityButtonsFrame.BackgroundColor3 = theme.panel
rarityButtonsFrame.BackgroundTransparency = transparency.panel
rarityButtonsFrame.BorderSizePixel = 0
rarityButtonsFrame.Position = UDim2.fromOffset(10, 98)
rarityButtonsFrame.Size = UDim2.new(1, -20, 0, 24)
rarityButtonsFrame.Parent = autoWrap

local rarityButtonsCorner = Instance.new("UICorner")
rarityButtonsCorner.CornerRadius = UDim.new(0, 6)
rarityButtonsCorner.Parent = rarityButtonsFrame

local rarityScroll = Instance.new("ScrollingFrame")
rarityScroll.Name = "RarityScroll"
rarityScroll.BackgroundTransparency = 1
rarityScroll.BorderSizePixel = 0
rarityScroll.Size = UDim2.new(1, -8, 1, -4)
rarityScroll.Position = UDim2.fromOffset(4, 2)
rarityScroll.ScrollBarThickness = 2
rarityScroll.ScrollingDirection = Enum.ScrollingDirection.X
rarityScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
rarityScroll.CanvasSize = UDim2.fromOffset(0, 0)
rarityScroll.Parent = rarityButtonsFrame

local rarityList = Instance.new("UIListLayout")
rarityList.FillDirection = Enum.FillDirection.Horizontal
rarityList.Padding = UDim.new(0, 6)
rarityList.SortOrder = Enum.SortOrder.LayoutOrder
rarityList.VerticalAlignment = Enum.VerticalAlignment.Center
rarityList.Parent = rarityScroll

local function setActiveButton(button, active)
    if active then
        button.BackgroundColor3 = theme.accent
        button.BackgroundTransparency = transparency.accent
        button.TextColor3 = Color3.fromRGB(15, 20, 26)
    else
        button.BackgroundColor3 = theme.soft
        button.BackgroundTransparency = transparency.soft
        button.TextColor3 = theme.text
    end
end

local selectedIndex = 1
local buttons = {}

local function setTag(index)
    selectedIndex = index
    for i, btn in ipairs(buttons) do
        setActiveButton(btn, i == selectedIndex)
    end
    contentTag.Text = tags[index].name
    contentInfo.Text = tags[index].info
end

for i, tag in ipairs(tags) do
    local btn = Instance.new("TextButton")
    btn.Name = tag.name .. "Tag"
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = theme.soft
    btn.BackgroundTransparency = transparency.soft
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Text = tag.name
    btn.TextColor3 = theme.text
    btn.AutoButtonColor = true
    btn.LayoutOrder = i
    btn.Parent = nav

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        setTag(i)
    end)

    table.insert(buttons, btn)
end

setTag(1)

local icon = Instance.new("ImageButton")
icon.Name = "MiniIcon"
icon.Size = UDim2.fromOffset(44, 44)
icon.Position = UDim2.new(0.5, -22, 0.5, -22)
icon.BackgroundColor3 = theme.panel
icon.BackgroundTransparency = transparency.icon
icon.BorderSizePixel = 0
icon.Image = "rbxassetid://6031094678"
icon.ImageColor3 = theme.text
icon.Visible = false
icon.Parent = screenGui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = icon

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = theme.line
iconStroke.Thickness = 1
iconStroke.Transparency = 0.2
iconStroke.Parent = icon

local minimized = false
local hiddenByCtrl = false

local function applyVisibility()
    if hiddenByCtrl then
        main.Visible = false
        icon.Visible = false
    else
        main.Visible = not minimized
        icon.Visible = minimized
    end
end

collapseBtn.MouseButton1Click:Connect(function()
    minimized = true
    icon.Position = main.Position
    applyVisibility()
end)

icon.MouseButton1Click:Connect(function()
    minimized = false
    applyVisibility()
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        hiddenByCtrl = not hiddenByCtrl
        applyVisibility()
    end
end)

applyVisibility()

local function makeDraggable(dragHandle, moveTarget)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        moveTarget.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = moveTarget.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

makeDraggable(top, main)
makeDraggable(icon, icon)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rollRemote = remotes:WaitForChild("RollSeeds")
local buyRemote = remotes:WaitForChild("BuySeed")
local registry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Registry"))

local autoRollEnabled = false
local rollInFlight = false
local lastHit = nil
local autoRollAfterBuyEnabled = true
local currentRolledSeeds = {}
local autoBuySelectedEnabled = false
local lastRollRequestAt = 0

local function getOneInForPlant(plantName)
    local plant = registry.Plants[plantName]
    if not plant or not plant.RollChance or plant.RollChance <= 0 then
        return nil
    end

    local totalChance = 0
    for _, info in pairs(registry.Plants) do
        if type(info) == "table" and info.RollChance and info.RollChance > 0 then
            totalChance += info.RollChance
        end
    end

    if totalChance <= 0 then
        return nil
    end

    return math.max(1, math.floor((totalChance / plant.RollChance) + 0.5))
end

local rarityOrder = {
    "Common",
    "Uncommon",
    "Rare",
    "Legendary",
    "Secret",
    "Divine",
    "Exotic",
    "Prismatic",
    "Transcended"
}

local rarityRank = {}
for i, name in ipairs(rarityOrder) do
    rarityRank[string.lower(name)] = i
end

local selectedRarities = {
    Rare = true,
    Legendary = true,
    Secret = true
}

local function getSelectedRaritySetAndText()
    local selectedSet = {}
    local selectedList = {}
    for _, rarityName in ipairs(rarityOrder) do
        if selectedRarities[rarityName] then
            selectedSet[rarityName] = true
            table.insert(selectedList, rarityName)
        end
    end
    if #selectedList == 0 then
        return nil, nil
    end
    rateBox.Text = table.concat(selectedList, ", ")
    return selectedSet, table.concat(selectedList, ", ")
end

local rarityButtonRefs = {}
local function refreshRarityButtons()
    for rarityName, btn in pairs(rarityButtonRefs) do
        local enabled = selectedRarities[rarityName] == true
        if enabled then
            btn.BackgroundColor3 = theme.accent
            btn.BackgroundTransparency = 0.2
            btn.TextColor3 = Color3.fromRGB(15, 20, 26)
        else
            btn.BackgroundColor3 = theme.soft
            btn.BackgroundTransparency = transparency.soft
            btn.TextColor3 = theme.text
        end
    end
    getSelectedRaritySetAndText()
end

for i, rarityName in ipairs(rarityOrder) do
    local rarityBtn = Instance.new("TextButton")
    rarityBtn.Name = rarityName .. "Btn"
    rarityBtn.LayoutOrder = i
    rarityBtn.BackgroundColor3 = theme.soft
    rarityBtn.BackgroundTransparency = transparency.soft
    rarityBtn.BorderSizePixel = 0
    rarityBtn.Font = Enum.Font.Gotham
    rarityBtn.TextSize = 11
    rarityBtn.Text = rarityName
    rarityBtn.TextColor3 = theme.text
    rarityBtn.AutomaticSize = Enum.AutomaticSize.X
    rarityBtn.Size = UDim2.fromOffset(0, 20)
    rarityBtn.Parent = rarityScroll

    local rarityBtnCorner = Instance.new("UICorner")
    rarityBtnCorner.CornerRadius = UDim.new(0, 6)
    rarityBtnCorner.Parent = rarityBtn

    rarityBtn.MouseButton1Click:Connect(function()
        selectedRarities[rarityName] = not selectedRarities[rarityName]
        refreshRarityButtons()
    end)

    rarityButtonRefs[rarityName] = rarityBtn
end

local function updateRarityCanvas()
    local width = rarityList.AbsoluteContentSize.X + 8
    rarityScroll.CanvasSize = UDim2.fromOffset(width, 0)
end

rarityList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateRarityCanvas)
updateRarityCanvas()

refreshRarityButtons()

local function refreshAutoBuyRollButton()
    if autoRollAfterBuyEnabled then
        autoRollAfterBuyBtn.Text = "Buy->Roll: ON"
        autoRollAfterBuyBtn.BackgroundColor3 = theme.accent
        autoRollAfterBuyBtn.BackgroundTransparency = 0.2
        autoRollAfterBuyBtn.TextColor3 = Color3.fromRGB(15, 20, 26)
    else
        autoRollAfterBuyBtn.Text = "Buy->Roll: OFF"
        autoRollAfterBuyBtn.BackgroundColor3 = theme.soft
        autoRollAfterBuyBtn.BackgroundTransparency = transparency.soft
        autoRollAfterBuyBtn.TextColor3 = theme.text
    end
end

refreshAutoBuyRollButton()
autoRollAfterBuyBtn.MouseButton1Click:Connect(function()
    autoRollAfterBuyEnabled = not autoRollAfterBuyEnabled
    refreshAutoBuyRollButton()
end)

local function refreshAutoBuySelectedButton()
    if autoBuySelectedEnabled then
        autoBuySelectedBtn.Text = "AutoBuy: ON"
        autoBuySelectedBtn.BackgroundColor3 = theme.accent
        autoBuySelectedBtn.BackgroundTransparency = 0.2
        autoBuySelectedBtn.TextColor3 = Color3.fromRGB(15, 20, 26)
    else
        autoBuySelectedBtn.Text = "AutoBuy: OFF"
        autoBuySelectedBtn.BackgroundColor3 = theme.soft
        autoBuySelectedBtn.BackgroundTransparency = transparency.soft
        autoBuySelectedBtn.TextColor3 = theme.text
    end
end

refreshAutoBuySelectedButton()
autoBuySelectedBtn.MouseButton1Click:Connect(function()
    autoBuySelectedEnabled = not autoBuySelectedEnabled
    refreshAutoBuySelectedButton()
end)

local function setAutoState(enabled)
    autoRollEnabled = enabled
    if enabled then
        autoToggle.Text = "AutoRoll: ON"
        autoToggle.BackgroundColor3 = Color3.fromRGB(255, 145, 145)
        autoToggle.TextColor3 = Color3.fromRGB(45, 18, 18)
    else
        autoToggle.Text = "AutoRoll: OFF"
        autoToggle.BackgroundColor3 = theme.accent
        autoToggle.TextColor3 = Color3.fromRGB(15, 20, 26)
        rollInFlight = false
    end
end

rollRemote.OnClientEvent:Connect(function(resultSeeds)
    rollInFlight = false
    if typeof(resultSeeds) == "table" then
        currentRolledSeeds = resultSeeds
    else
        currentRolledSeeds = {}
    end

    if not autoRollEnabled then
        if autoBuySelectedEnabled and typeof(resultSeeds) == "table" then
            local selectedSet = getSelectedRaritySetAndText()
            if selectedSet then
                for slot, seedName in ipairs(resultSeeds) do
                    local plant = registry.Plants[seedName]
                    local rarity = plant and plant.Rarity or "Common"
                    if selectedSet[rarity] then
                        pcall(function()
                            buyRemote:FireServer(slot)
                        end)
                        statusLabel.Text = ("Status: Auto bought %s (%s)"):format(seedName, rarity)
                        break
                    end
                end
            end
        end
        return
    end

    local selectedSet, selectedText = getSelectedRaritySetAndText()
    if not selectedSet then
        statusLabel.Text = "Status: Invalid rarities. Example: Rare,Legendary"
        setAutoState(false)
        return
    end

    local bestRate = 0
    local bestSeed = nil
    local bestRarity = nil
    local hitSeed = nil
    local hitRarity = nil
    local hitRate = nil
    if typeof(resultSeeds) == "table" then
        for _, seedName in ipairs(resultSeeds) do
            local oneIn = getOneInForPlant(seedName)
            local plant = registry.Plants[seedName]
            local rarity = plant and plant.Rarity or "Common"
            if oneIn and oneIn > bestRate then
                bestRate = oneIn
                bestSeed = seedName
                bestRarity = rarity
            end
            if selectedSet[rarity] and not hitSeed then
                hitSeed = seedName
                hitRarity = rarity
                hitRate = oneIn or 1
            end
        end
    end

    if hitSeed then
        if autoBuySelectedEnabled and typeof(resultSeeds) == "table" then
            for slot, seedName in ipairs(resultSeeds) do
                local plant = registry.Plants[seedName]
                local rarity = plant and plant.Rarity or "Common"
                if selectedSet[rarity] then
                    pcall(function()
                        buyRemote:FireServer(slot)
                    end)
                    break
                end
            end
        end
        lastHit = ("HIT: %s | %s (1 in %d)"):format(hitSeed, hitRarity or "Common", hitRate or 1)
        statusLabel.Text = "Status: " .. lastHit .. " | Auto stopped"
        setAutoState(false)
    else
        statusLabel.Text = ("Status: Rolling... Best %s (1 in %d) | Targets %s"):format(bestRarity or "Common", bestRate, selectedText)
    end
end)

buyRemote.OnClientEvent:Connect(function(slotIndex, success)
    if not autoRollAfterBuyEnabled then
        return
    end
    if success ~= true then
        return
    end
    if typeof(slotIndex) ~= "number" then
        return
    end

    local boughtSeed = currentRolledSeeds[slotIndex]
    if not boughtSeed then
        return
    end
    local plant = registry.Plants[boughtSeed]
    local boughtRarity = plant and plant.Rarity or "Common"
    local selectedSet = getSelectedRaritySetAndText()
    if not selectedSet or not selectedSet[boughtRarity] then
        return
    end

    if rollInFlight and (os.clock() - lastRollRequestAt) > 4 then
        rollInFlight = false
    end

    if not rollInFlight then
        rollInFlight = true
        lastRollRequestAt = os.clock()
        statusLabel.Text = ("Status: Bought %s (%s) -> Auto rolling..."):format(boughtSeed, boughtRarity)
        task.delay(0.2, function()
            pcall(function()
                rollRemote:FireServer()
            end)
        end)
    end
end)

task.spawn(function()
    while screenGui.Parent do
        if rollInFlight and (os.clock() - lastRollRequestAt) > 4 then
            rollInFlight = false
            if not autoRollEnabled then
                statusLabel.Text = "Status: Buy->Roll retry ready"
            end
        end
        if autoRollEnabled and not rollInFlight then
            local _, selectedText = getSelectedRaritySetAndText()
            if not selectedText then
                statusLabel.Text = "Status: Invalid rarities. Example: Rare,Legendary"
                setAutoState(false)
            else
                rollInFlight = true
                lastRollRequestAt = os.clock()
                statusLabel.Text = ("Status: Rolling... Targets %s"):format(selectedText)
                pcall(function()
                    rollRemote:FireServer()
                end)
            end
        end
        if autoRollEnabled and rollInFlight and (os.clock() - lastRollRequestAt) > 4 then
            rollInFlight = false
            statusLabel.Text = "Status: Retry rolling..."
        end
        task.wait(1.8)
    end
end)

autoToggle.MouseButton1Click:Connect(function()
    if autoRollEnabled then
        setAutoState(false)
        statusLabel.Text = "Status: AutoRoll OFF"
        return
    end

    local _, selectedText = getSelectedRaritySetAndText()
    if not selectedText then
        statusLabel.Text = "Status: Invalid rarities. Example: Rare,Legendary"
        return
    end

    setAutoState(true)
    statusLabel.Text = ("Status: AutoRoll ON | Targets %s"):format(selectedText)
end)
