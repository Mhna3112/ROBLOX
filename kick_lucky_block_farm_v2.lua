--[[
    Kick a Lucky Block - Enhanced Autofarm V2 (Refactored & Fixed)
    Workflow: 
    1. TP to Custom Farm Position (User defined)
    2. Auto Kick until transformed into Brainrot
    3. Walk back to Safe Zone (Lobby) using MoveTo
    4. TP to Plot and Place
    5. Repeat
]]

-- Services
local players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local workspace_service = game:GetService("Workspace")
local run_service = game:GetService("RunService")

-- Dependencies
local network = require(replicated_storage.Shared.Packages.Network)
local plot_service = require(replicated_storage.Modules.ServicesLoader.ClientPlotService)

-- Local Cache
local player = players.LocalPlayer
local debris_service = workspace_service:WaitForChild("Debris")

-- Configuration
getgenv().Config = getgenv().Config or {
    auto_farm = false,
    auto_upgrade = false
}

local config = getgenv().Config

-- Clean up old GUIs
local player_gui = player:WaitForChild("PlayerGui")
for _, v in ipairs(player_gui:GetChildren()) do
    if v:IsA("ScreenGui") and (v.Name == "AlimeFarm" or v.Name == "AlimeFarmV2") then
        v:Destroy()
    end
end

-- GUI creation
local screen_gui = Instance.new("ScreenGui")
screen_gui.Name = "AlimeFarmV2"
screen_gui.ResetOnSpawn = false

if syn and syn.protect_gui then
    syn.protect_gui(screen_gui)
end
screen_gui.Parent = player_gui

local main_frame = Instance.new("Frame")
main_frame.Name = "Main"
main_frame.Size = UDim2.new(0, 250, 0, 320)
main_frame.Position = UDim2.new(0.5, 0, 0.5, -160)
main_frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main_frame.Active = true
main_frame.Draggable = true
main_frame.Parent = screen_gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main_frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Lucky Block Farm V2"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = main_frame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 1, -50)
scroll.Position = UDim2.new(0, 5, 0, 45)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main_frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = scroll

local status_label = Instance.new("TextLabel")
status_label.Size = UDim2.new(1, -5, 0, 25)
status_label.BackgroundTransparency = 1
status_label.TextColor3 = Color3.new(0.7, 0.7, 1)
status_label.Text = "Status: Idle"
status_label.Font = Enum.Font.Gotham
status_label.TextSize = 12
status_label.Parent = scroll

local function create_toggle(name, flag)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 30)
    button.BackgroundColor3 = config[flag] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    button.Text = name .. ": " .. (config[flag] and "ON" or "OFF")
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.Parent = scroll

    local ui_corner = Instance.new("UICorner")
    ui_corner.CornerRadius = UDim.new(0, 6)
    ui_corner.Parent = button

    button.MouseButton1Click:Connect(function()
        config[flag] = not config[flag]
        button.Text = name .. ": " .. (config[flag] and "ON" or "OFF")
        button.BackgroundColor3 = config[flag] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    end)
end

create_toggle("Auto Farm", "auto_farm")
create_toggle("Auto Upgrade", "auto_upgrade")

-- Constants & Helper Functions
local SAFE_ZONE_POS = Vector3.new(699.76, -0.5, 231.2)
local FARM_POS = Vector3.new(698.19, 3.22, 231.16)
local is_at_farm_pos = false

local function tp(pos)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(pos)
    end
end

local function walk_to(pos)
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:MoveTo(pos)
        local arrived = false
        local connection
        connection = humanoid.MoveToFinished:Connect(function()
            arrived = true
            connection:Disconnect()
        end)
        
        -- Timeout for safety (15s)
        local start_time = tick()
        while not arrived and tick() - start_time < 15 do
            task.wait(0.1)
        end
        if connection and connection.Connected then connection:Disconnect() end
    end
end

local function is_transformed()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local weld = root:FindFirstChild("Weld")
    if weld and weld.Part1 and weld.Part1.Parent and weld.Part1.Parent.Parent == debris_service then
        return true
    end
    return false
end

local function get_empty_slot()
    local my_plot = plot_service.Model
    if not my_plot then return nil end
    local slots = my_plot:FindFirstChild("Slots")
    if not slots then return nil end

    for i = 1, 20 do
        local slot = slots:FindFirstChild("Slot" .. i)
        if slot and not slot:FindFirstChild("PlacedPart") then
            return i
        end
    end
    return nil
end

local function handle_transformed_cycle()
    status_label.Text = "Status: Brainrot -> Walking to Safe Zone..."
    walk_to(SAFE_ZONE_POS)
    task.wait(0.5)

    local my_plot = plot_service.Model
    if not my_plot then
        status_label.Text = "Status: Plot not found, waiting..."
        task.wait(1)
        return false
    end

    local spawn_part = my_plot:FindFirstChild("SpawnPart")
    if not spawn_part then
        status_label.Text = "Status: SpawnPart missing, waiting..."
        task.wait(1)
        return false
    end

    status_label.Text = "Status: Brainrot -> TP Plot"
    tp(spawn_part.Position + Vector3.new(0, 3, 0))
    task.wait(0.5)

    local slot_index = get_empty_slot()
    if slot_index then
        status_label.Text = "Status: Brainrot -> Placing item..."
        network.FireServer("S_Interact", slot_index)
        task.wait(1.5)
        return true
    end

    status_label.Text = "Status: Brainrot -> Plot FULL, selling..."
    network.InvokeServer("B_SellAll")
    task.wait(1.5)
    return true
end

-- Logic Loop
task.spawn(function()
    while true do
        task.wait(0.1)
        if config.auto_farm then
            local success, err = pcall(function()
                if is_transformed() then
                    -- Priority phase when transformed:
                    -- Walk Safe Zone -> TP Plot -> Place (or Sell if full).
                    -- Only after this phase is completed, the loop can continue.
                    handle_transformed_cycle()
                    is_at_farm_pos = false
                else
                    -- Phase: Normal -> Stay at farm and kick (no continuous re-TP).
                    if not is_at_farm_pos then
                        status_label.Text = "Status: Moving to Farm Pos"
                        tp(FARM_POS)
                        task.wait(0.2)
                        is_at_farm_pos = true
                    end

                    status_label.Text = "Status: Kicking..."
                    network.FireServer("KickEvent")
                    network.FireServer("lb_open")
                    network.FireServer("LB_OpenRequest")
                    network.FireServer("TaviMishkal")
                end
            end)
            if not success then
                status_label.Text = "Status: Error in loop!"
                warn(err)
                task.wait(1)
            end
        end
    end
end)

-- Upgrade Loop
task.spawn(function()
    while true do
        task.wait(5)
        if config.auto_upgrade then
            pcall(function()
                network.FireServer("SPEED_UPGRADE")
                network.FireServer("bs_upgrade")
                network.FireServer("Weight_Update")
            end)
        end
    end
end)

print("Alime Farm V2 Fixed Logic Sequence!")
