-- Arena (Zombie Survival) Auto-Shot / Kill Aura Script
-- Game: Arena by Nectarforge Studios
-- Features: Kill Aura, Auto Buy Weapon, Auto Equip, Anti-AFK, Auto Collect Shards, Fixed Spawn TP

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local SETTINGS_FILE = "ArenaAutoShotSettings.json"
local DEFAULT_SCRIPT_URL = "https://raw.githubusercontent.com/Mhna3112/dislayhoney/refs/heads/main/arena_autoshot.lua"
local LOBBY_PLACE_ID = 114204398207377

getgenv().ArenaAutoShotConfig = getgenv().ArenaAutoShotConfig or {
    Enabled = true,
    KillAllZombies = false,
    KillDistance = 500,
    AttackDelay = 0.1,
    HitsPerTarget = 3,
    MaxZombiesPerTick = 0,
    AutoBuyWeapon = true,
    MaxWeaponPurchases = 1,
    AutoEquip = true,
    AntiAFK = true,
    AutoCollect = true,
    AutoSkill = false,
    AutoSkillDelay = 1,
    AutoSkillKeys = {
        E = true,
        R = true,
        Q = true
    },
    Debug = false,
    ScriptUrl = DEFAULT_SCRIPT_URL,
    SettingsFile = SETTINGS_FILE,

    Lobby = {
        Enabled = true,
        ShipName = "Ship1",
        PartySize = 1,
        Difficulty = "Normal",
        Map = "Default",
        TweenSpeed = 45,
        RetryDelay = 3,
        MaxJoinAttempts = 12,
        TeleportWait = 8
    },

    FixedSpawn = {
        Enabled = true,
        Position = Vector3.new(-265.59295654297, 478.25930786133, -335.0315246582)
    }
}

local Config = getgenv().ArenaAutoShotConfig
getgenv().Config = Config
Config.SettingsFile = Config.SettingsFile or SETTINGS_FILE
Config.ScriptUrl = Config.ScriptUrl or DEFAULT_SCRIPT_URL
Config.Lobby = Config.Lobby or {
    Enabled = true,
    ShipName = "Ship1",
    PartySize = 1,
    Difficulty = "Normal",
    Map = "Default",
    TweenSpeed = 45,
    RetryDelay = 3,
    MaxJoinAttempts = 12,
    TeleportWait = 8
}
Config.FixedSpawn = Config.FixedSpawn or {
    Enabled = true,
    Position = Vector3.new(-265.59295654297, 478.25930786133, -335.0315246582)
}
Config.AutoSkillKeys = Config.AutoSkillKeys or {
    E = true,
    R = true,
    Q = true
}
getgenv().ArenaAutoShotState = getgenv().ArenaAutoShotState or {
    LobbyStarted = false,
    WeaponPurchases = 0,
    RunId = 0
}
local State = getgenv().ArenaAutoShotState
State.WeaponPurchases = State.WeaponPurchases or 0
State.RunId = State.RunId or 0

local function debug_log(...)
    if Config.Debug then
        print("[ArenaAutoShot]", ...)
    end
end

local function validate_config()
    Config.KillAllZombies = Config.KillAllZombies == true
    Config.KillDistance = math.max(1, tonumber(Config.KillDistance) or 500)
    Config.AttackDelay = math.max(0.1, tonumber(Config.AttackDelay) or 0.1)
    Config.HitsPerTarget = math.clamp(math.floor(tonumber(Config.HitsPerTarget) or 1), 1, 10)
    Config.MaxZombiesPerTick = math.max(0, math.floor(tonumber(Config.MaxZombiesPerTick) or 0))
    if Config.KillAllZombies then
        Config.KillDistance = math.max(Config.KillDistance, 100000)
        Config.MaxZombiesPerTick = 0
    end
    Config.MaxWeaponPurchases = math.max(0, math.floor(tonumber(Config.MaxWeaponPurchases) or 1))
    Config.AutoSkillDelay = math.max(0.25, tonumber(Config.AutoSkillDelay) or 1)
    Config.AutoSkillKeys = Config.AutoSkillKeys or {}
    Config.AutoSkillKeys.E = Config.AutoSkillKeys.E ~= false
    Config.AutoSkillKeys.R = Config.AutoSkillKeys.R ~= false
    Config.AutoSkillKeys.Q = Config.AutoSkillKeys.Q ~= false
    Config.Lobby.PartySize = math.max(1, math.floor(tonumber(Config.Lobby.PartySize) or 1))
    Config.Lobby.TweenSpeed = math.max(1, tonumber(Config.Lobby.TweenSpeed) or 45)
    Config.Lobby.RetryDelay = math.max(1, tonumber(Config.Lobby.RetryDelay) or 3)
    Config.Lobby.MaxJoinAttempts = math.max(1, math.floor(tonumber(Config.Lobby.MaxJoinAttempts) or 12))
    Config.Lobby.TeleportWait = math.max(1, tonumber(Config.Lobby.TeleportWait) or 8)
end

local function can_use_files()
    return type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function apply_saved_settings(settings)
    if type(settings) ~= "table" then
        return
    end

    local scalar_keys = {
        "Enabled",
        "KillAllZombies",
        "KillDistance",
        "AttackDelay",
        "HitsPerTarget",
        "MaxZombiesPerTick",
        "AutoBuyWeapon",
        "MaxWeaponPurchases",
        "AutoEquip",
        "AntiAFK",
        "AutoCollect",
        "AutoSkill",
        "AutoSkillDelay",
        "ScriptUrl",
        "Debug"
    }

    for i = 1, #scalar_keys do
        local key = scalar_keys[i]
        if settings[key] ~= nil then
            Config[key] = settings[key]
        end
    end

    if type(settings.Lobby) == "table" then
        Config.Lobby = Config.Lobby or {}
        for key, value in pairs(settings.Lobby) do
            Config.Lobby[key] = value
        end
    end

    if type(settings.AutoSkillKeys) == "table" then
        Config.AutoSkillKeys = Config.AutoSkillKeys or {}
        for key, value in pairs(settings.AutoSkillKeys) do
            Config.AutoSkillKeys[key] = value
        end
    end
end

local function load_settings()
    if not can_use_files() or not isfile(Config.SettingsFile) then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(Config.SettingsFile))
    end)

    if ok then
        apply_saved_settings(decoded)
        validate_config()
    else
        warn("Arena Settings: failed to load settings file")
    end
end

local function save_settings()
if not can_use_files() then
        return false
    end

    local settings = {
        Enabled = Config.Enabled,
        KillAllZombies = Config.KillAllZombies,
        KillDistance = Config.KillDistance,
        AttackDelay = Config.AttackDelay,
        HitsPerTarget = Config.HitsPerTarget,
        MaxZombiesPerTick = Config.MaxZombiesPerTick,
        AutoBuyWeapon = Config.AutoBuyWeapon,
        MaxWeaponPurchases = Config.MaxWeaponPurchases,
        AutoEquip = Config.AutoEquip,
        AntiAFK = Config.AntiAFK,
        AutoCollect = Config.AutoCollect,
        AutoSkill = Config.AutoSkill,
        AutoSkillDelay = Config.AutoSkillDelay,
        AutoSkillKeys = {
            E = Config.AutoSkillKeys.E,
            R = Config.AutoSkillKeys.R,
            Q = Config.AutoSkillKeys.Q
        },
        ScriptUrl = Config.ScriptUrl,
        Debug = Config.Debug,
        Lobby = {
            Enabled = Config.Lobby.Enabled,
            ShipName = Config.Lobby.ShipName,
            PartySize = Config.Lobby.PartySize,
            Difficulty = Config.Lobby.Difficulty,
            Map = Config.Lobby.Map,
            TweenSpeed = Config.Lobby.TweenSpeed,
            RetryDelay = Config.Lobby.RetryDelay,
            MaxJoinAttempts = Config.Lobby.MaxJoinAttempts,
            TeleportWait = Config.Lobby.TeleportWait
        }
    }

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(settings)
    end)

    if ok then
        local write_ok = pcall(function()
            writefile(Config.SettingsFile, encoded)
        end)
        return write_ok
    end

    return false
end

load_settings()
validate_config()

local function queue_self_after_teleport()
    if type(Config.ScriptUrl) ~= "string" or Config.ScriptUrl == "" then
        warn("Arena Lobby: ScriptUrl is empty, cannot queue script after teleport")
        return
    end

    local source = string.format([[
        task.wait(3)
        pcall(function()
            loadstring(game:HttpGet(%q))()
        end)
    ]], Config.ScriptUrl)

    if syn and syn.queue_on_teleport then
        syn.queue_on_teleport(source)
    elseif queue_on_teleport then
        queue_on_teleport(source)
    end
end

local function get_root_part()
    local player = LocalPlayer or Players.LocalPlayer
    while not player do
        task.wait(0.1)
        player = Players.LocalPlayer
    end

    LocalPlayer = player

    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 10)
end

local function is_lobby()
    if game.PlaceId == LOBBY_PLACE_ID then
        return true
    end

    return Config.Lobby.Enabled
        and ReplicatedStorage:FindFirstChild("QueueRemotes") ~= nil
        and workspace:FindFirstChild("Queues") ~= nil
end

local function read_queue_number(instance, names)
    for _, name in ipairs(names) do
        local value = instance:GetAttribute(name)
        if tonumber(value) then
            return tonumber(value)
        end
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
            local lower_name = descendant.Name:lower()
            for _, name in ipairs(names) do
                if lower_name:find(name:lower(), 1, true) then
                    return tonumber(descendant.Value)
                end
            end
        end
    end

    return nil
end

local function read_queue_capacity_from_text(ship)
    for _, descendant in ipairs(ship:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local current, max = tostring(descendant.Text):match("(%d+)%s*/%s*(%d+)")
            if current and max then
                return tonumber(current), tonumber(max)
            end
        end
    end

    return nil, nil
end

local function get_queue_room_count(ship)
    local current = read_queue_number(ship, {"CurrentPlayers", "PlayerCount", "Players", "Count", "Amount"})
    local max = read_queue_number(ship, {"MaxPlayers", "MaxPlayer", "Capacity", "MaxSize", "Size"})

    if not current or not max then
        local text_current, text_max = read_queue_capacity_from_text(ship)
        current = current or text_current
        max = max or text_max
    end

    local players_folder = ship:FindFirstChild("Players") or ship:FindFirstChild("Members")
    if not current and players_folder then
        current = #players_folder:GetChildren()
    end

    return current, max
end

local function is_queue_room_full(ship)
    local current, max = get_queue_room_count(ship)
    return current ~= nil and max ~= nil and max > 0 and current >= max
end

local function get_queue_touch_part(ship)
    return ship and (ship:FindFirstChild("TouchPart") or ship:FindFirstChildWhichIsA("BasePart", true))
end

local function get_queue_order(queues)
    local ships = {}
    local preferred = queues:FindFirstChild(Config.Lobby.ShipName)

    if preferred then
        table.insert(ships, preferred)
    end

    local others = queues:GetChildren()
    table.sort(others, function(a, b)
        return a.Name < b.Name
    end)

    for _, ship in ipairs(others) do
        if ship ~= preferred and get_queue_touch_part(ship) then
            table.insert(ships, ship)
        end
    end

    return ships
end

local function find_available_queue_ship(queues, skipped_ships)
    local first_valid
    for _, ship in ipairs(get_queue_order(queues)) do
        if get_queue_touch_part(ship) and not skipped_ships[ship] then
            first_valid = first_valid or ship
            if not is_queue_room_full(ship) then
                return ship, false
            end
        end
    end

    return first_valid, first_valid ~= nil
end

local function still_in_lobby()
    return ReplicatedStorage:FindFirstChild("QueueRemotes") ~= nil and workspace:FindFirstChild("Queues") ~= nil
end

local function run_lobby()
    if State.LobbyStarted then
        print("Arena Lobby: already started, waiting for teleport")
        return
    end

    local queue_remotes = ReplicatedStorage:WaitForChild("QueueRemotes", 10)
    local queues = workspace:WaitForChild("Queues", 10)
    if not queue_remotes or not queues then
        warn("Arena Lobby: QueueRemotes or Queues not found")
        return
    end

    local create_party = queue_remotes:WaitForChild("CreateParty", 10)
    if not create_party then
        warn("Arena Lobby: CreateParty not found")
        return
    end

    queue_self_after_teleport()
    State.LobbyStarted = true

    local attempts = 0
    local skipped_ships = {}
    while attempts < Config.Lobby.MaxJoinAttempts and still_in_lobby() do
        attempts += 1

        local ship, all_full = find_available_queue_ship(queues, skipped_ships)
        if not ship then
            warn("Arena Lobby: no open queue ships found, waiting")
            skipped_ships = {}
            task.wait(Config.Lobby.RetryDelay)
            continue
        end

        if all_full then
            warn("Arena Lobby: all queue rooms look full, waiting")
            task.wait(Config.Lobby.RetryDelay)
            continue
        end

        local hrp = get_root_part()
        local touch_part = get_queue_touch_part(ship)
        if not hrp or not touch_part then
            warn("Arena Lobby: failed to find touch part for " .. tostring(ship.Name))
            task.wait(Config.Lobby.RetryDelay)
            continue
        end

        local distance = (hrp.Position - touch_part.Position).Magnitude
        local duration = distance / Config.Lobby.TweenSpeed
        local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = touch_part.CFrame
        })

        print("Arena Lobby: moving to " .. ship.Name)
        tween:Play()
        tween.Completed:Wait()
        tween:Destroy()

        if firetouchinterest then
            firetouchinterest(hrp, touch_part, 0)
            task.wait(0.1)
            firetouchinterest(hrp, touch_part, 1)
        end

        task.wait(1.5)
        print("Arena Lobby: creating party in " .. ship.Name)
        create_party:FireServer(Config.Lobby.PartySize, Config.Lobby.Difficulty, Config.Lobby.Map)
        task.wait(Config.Lobby.TeleportWait)
        if still_in_lobby() then
            skipped_ships[ship] = true
            warn("Arena Lobby: still in lobby after trying " .. ship.Name .. ", switching room")
        end
    end

    if still_in_lobby() then
        warn("Arena Lobby: join stopped after max attempts")
    end
end

if is_lobby() then
    run_lobby()
    return
end

State.RunId += 1
local run_id = State.RunId
local BUTTON_SIGNALS = {"Activated", "MouseButton1Click"}

-- REMOTES
local GunRemotes = ReplicatedStorage:WaitForChild("GunRemotes")
local GunFire = GunRemotes:WaitForChild("GunFire")
local GunHit = GunRemotes:WaitForChild("GunHit")

local UpgradeRemotes = ReplicatedStorage:WaitForChild("UpgradeRemotes")
local PurchaseWeaponUpgrade = UpgradeRemotes:WaitForChild("PurchaseWeaponUpgrade")
local GetUpgrades = UpgradeRemotes:WaitForChild("GetUpgrades")

local DataRemotes = ReplicatedStorage:WaitForChild("DataRemotes")
local GetMinerals = DataRemotes:WaitForChild("GetMinerals")

local EventRemotes = ReplicatedStorage:WaitForChild("EventRemotes")
local GalacticShardCollect = EventRemotes:WaitForChild("GalacticShardCollect")
local GalacticShardDrop = EventRemotes:WaitForChild("GalacticShardDrop")

local function create_weapon_purchase_ui()
    local player_gui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if not player_gui then
        return
    end

    local old_gui = player_gui:FindFirstChild("ArenaAutoShotUI")
    if old_gui then
        old_gui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ArenaAutoShotUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    end
    gui.Parent = player_gui

    local frame = Instance.new("Frame")
    frame.Name = "WeaponPurchasePanel"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -16, 0, 96)
    frame.Size = UDim2.new(0, 230, 0, 190)
    frame.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 8)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.Font = Enum.Font.GothamBold
    title.Text = "Auto Buy Gun"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local function make_button(name, text, x)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = UDim2.new(0, x, 0, 42)
        button.Size = UDim2.new(0, 34, 0, 30)
        button.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 18
        button.Parent = frame

        local button_corner = Instance.new("UICorner")
        button_corner.CornerRadius = UDim.new(0, 6)
        button_corner.Parent = button

        return button
    end

    local minus = make_button("Minus", "-", 12)
    local plus = make_button("Plus", "+", 184)

    local input = Instance.new("TextBox")
    input.Name = "MaxPurchases"
    input.Position = UDim2.new(0, 54, 0, 42)
    input.Size = UDim2.new(0, 122, 0, 30)
    input.BackgroundColor3 = Color3.fromRGB(34, 36, 42)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.GothamBold
    input.PlaceholderText = "0 = unlimited"
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.TextSize = 14
    input.Text = tostring(Config.MaxWeaponPurchases)
    input.Parent = frame

    local input_corner = Instance.new("UICorner")
    input_corner.CornerRadius = UDim.new(0, 6)
    input_corner.Parent = input

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 12, 0, 82)
    status.Size = UDim2.new(1, -86, 0, 22)
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(210, 214, 222)
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local reset = Instance.new("TextButton")
    reset.Name = "Reset"
    reset.Position = UDim2.new(1, -70, 0, 80)
    reset.Size = UDim2.new(0, 58, 0, 26)
    reset.BackgroundColor3 = Color3.fromRGB(65, 45, 45)
    reset.BorderSizePixel = 0
    reset.Font = Enum.Font.GothamBold
    reset.Text = "Reset"
    reset.TextColor3 = Color3.fromRGB(255, 235, 235)
    reset.TextSize = 12
    reset.Parent = frame

    local reset_corner = Instance.new("UICorner")
    reset_corner.CornerRadius = UDim.new(0, 6)
    reset_corner.Parent = reset

    local skill_toggle = Instance.new("TextButton")
    skill_toggle.Name = "AutoSkillToggle"
    skill_toggle.Position = UDim2.new(0, 12, 0, 116)
    skill_toggle.Size = UDim2.new(1, -24, 0, 26)
    skill_toggle.BorderSizePixel = 0
    skill_toggle.Font = Enum.Font.GothamBold
    skill_toggle.TextSize = 12
    skill_toggle.Parent = frame

    local skill_corner = Instance.new("UICorner")
    skill_corner.CornerRadius = UDim.new(0, 6)
    skill_corner.Parent = skill_toggle

    local skill_buttons = {}
    local function make_skill_key_button(key_name, x)
        local button = Instance.new("TextButton")
        button.Name = "AutoSkill" .. key_name
        button.Position = UDim2.new(0, x, 0, 150)
        button.Size = UDim2.new(0, 62, 0, 26)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 12
        button.Parent = frame

        local button_corner = Instance.new("UICorner")
        button_corner.CornerRadius = UDim.new(0, 6)
        button_corner.Parent = button

        skill_buttons[key_name] = button
        return button
    end

    make_skill_key_button("E", 12)
    make_skill_key_button("R", 84)
    make_skill_key_button("Q", 156)

    local function set_limit(value, should_save)
        value = math.max(0, math.floor(tonumber(value) or Config.MaxWeaponPurchases or 1))
        Config.MaxWeaponPurchases = value
        input.Text = tostring(value)
        status.Text = string.format("Bought: %d / %s", State.WeaponPurchases, value == 0 and "inf" or tostring(value))
        if should_save then
            save_settings()
        end
    end

    local function set_auto_skill(enabled, should_save)
        Config.AutoSkill = enabled == true
        skill_toggle.Text = Config.AutoSkill and "Auto Skill: ON" or "Auto Skill: OFF"
        skill_toggle.BackgroundColor3 = Config.AutoSkill and Color3.fromRGB(42, 92, 62) or Color3.fromRGB(56, 50, 48)
        skill_toggle.TextColor3 = Config.AutoSkill and Color3.fromRGB(220, 255, 230) or Color3.fromRGB(235, 225, 220)
        if should_save then
            save_settings()
        end
    end

    local function set_skill_key(key_name, enabled, should_save)
        Config.AutoSkillKeys[key_name] = enabled == true
        local button = skill_buttons[key_name]
        if button then
            button.Text = key_name .. ": " .. (Config.AutoSkillKeys[key_name] and "ON" or "OFF")
            button.BackgroundColor3 = Config.AutoSkillKeys[key_name] and Color3.fromRGB(42, 70, 92) or Color3.fromRGB(58, 42, 42)
            button.TextColor3 = Config.AutoSkillKeys[key_name] and Color3.fromRGB(220, 238, 255) or Color3.fromRGB(255, 225, 225)
        end
        if should_save then
            save_settings()
        end
    end

    minus.MouseButton1Click:Connect(function()
        set_limit((tonumber(input.Text) or Config.MaxWeaponPurchases or 1) - 1, true)
    end)

    plus.MouseButton1Click:Connect(function()
        set_limit((tonumber(input.Text) or Config.MaxWeaponPurchases or 1) + 1, true)
    end)

    input.FocusLost:Connect(function()
        validate_config()
        set_limit(input.Text, true)
    end)

    reset.MouseButton1Click:Connect(function()
        State.WeaponPurchases = 0
        set_limit(Config.MaxWeaponPurchases, true)
    end)

    skill_toggle.MouseButton1Click:Connect(function()
        set_auto_skill(not Config.AutoSkill, true)
    end)

    for _, key_name in ipairs({"E", "R", "Q"}) do
        skill_buttons[key_name].MouseButton1Click:Connect(function()
            set_skill_key(key_name, not Config.AutoSkillKeys[key_name], true)
        end)
    end

    task.spawn(function()
        while gui.Parent do
            status.Text = string.format(
                "Bought: %d / %s",
                State.WeaponPurchases,
                Config.MaxWeaponPurchases == 0 and "inf" or tostring(Config.MaxWeaponPurchases)
            )
            task.wait(0.5)
        end
    end)

    set_limit(Config.MaxWeaponPurchases, false)
    set_auto_skill(Config.AutoSkill, false)
    set_skill_key("E", Config.AutoSkillKeys.E, false)
    set_skill_key("R", Config.AutoSkillKeys.R, false)
    set_skill_key("Q", Config.AutoSkillKeys.Q, false)
end

create_weapon_purchase_ui()

-- 0. ANTI-AFK
if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- 0.1 AUTO COLLECT (Listener)
if Config.AutoCollect then
    GalacticShardDrop.OnClientEvent:Connect(function(zId, amount, pos)
        task.wait(0.5)
        for i = 1, amount do
            GalacticShardCollect:FireServer(zId)
        end
    end)
end

-- 0.2 FIXED SPAWN TP
task.spawn(function()
    while run_id == State.RunId do
        task.wait(1)
        if Config.FixedSpawn.Enabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                if (hrp.Position - Config.FixedSpawn.Position).Magnitude > 5 then
                    hrp.CFrame = CFrame.new(Config.FixedSpawn.Position)
                end
            end
        end
    end
end)

-- Helper: Get equipped gun name
local function get_equipped_gun_name()
    local char = LocalPlayer.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            return tool.Name
        end
    end
    return nil
end

-- Helper: Extract id from "Zombie_ID"
local function get_zombie_id(name)
    local id = name:match("Zombie_(%d+)")
    return id and tonumber(id) or nil
end

local function get_zombie_hit_part(zombie)
    if zombie.PrimaryPart then
        return zombie.PrimaryPart
    end

    return zombie:FindFirstChild("HumanoidRootPart")
        or zombie:FindFirstChild("Head")
        or zombie:FindFirstChildWhichIsA("BasePart")
end

local function hit_zombie(gun_name, zombie, z_id, my_pos)
    local hit_part = get_zombie_hit_part(zombie)
    if not hit_part then
        return
    end

    local target_pos = hit_part.Position
    local direction = (target_pos - my_pos).Unit

    for _ = 1, Config.HitsPerTarget do
        local ok, err = pcall(function()
            -- Fire gun toward zombie (simulate real shooting)
            GunFire:FireServer(gun_name, my_pos, direction)
            -- Register hit on zombie
            GunHit:FireServer(gun_name, z_id, target_pos)
        end)
        if not ok then
            debug_log("gun hit failed:", err)
            return
        end
    end
end

-- 1. KILL AURA LOOP
task.spawn(function()
    while run_id == State.RunId do
        task.wait(Config.AttackDelay)
        validate_config()
        if not Config.Enabled then continue end
        
        local gunName = get_equipped_gun_name()
        if not gunName then continue end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
        local myPos = char.HumanoidRootPart.Position
        
        local zombiesLocal = workspace:FindFirstChild("Zombies_Local")
        if not zombiesLocal then continue end

        local zombies = zombiesLocal:GetChildren()
        for i = 1, #zombies do
            local zombie = zombies[i]
            if zombie:IsA("Model") then
                local hit_part = get_zombie_hit_part(zombie)
                if not hit_part then
                    continue
                end

                local dist = (myPos - hit_part.Position).Magnitude
                if dist <= Config.KillDistance then
                    local zId = get_zombie_id(zombie.Name)
                    if zId then
                        hit_zombie(gunName, zombie, zId, myPos)
                        
                        if Config.AutoCollect then
                            task.spawn(function()
                                task.wait(1)
                                GalacticShardCollect:FireServer(zId)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- 2. AUTO BUY WEAPON LOOP
task.spawn(function()
    while run_id == State.RunId do
        task.wait(5)
        validate_config()
        if not Config.AutoBuyWeapon then continue end
        if Config.MaxWeaponPurchases > 0 and State.WeaponPurchases >= Config.MaxWeaponPurchases then continue end
        
        local ok, err = pcall(function()
            local upgrades = GetUpgrades:InvokeServer()
            local minerals = GetMinerals:InvokeServer()
            
            if upgrades and upgrades.NextWeapon and not upgrades.IsMaxWeapon and minerals >= upgrades.NextWeapon.Price then
                PurchaseWeaponUpgrade:FireServer()
                State.WeaponPurchases += 1
            end
        end)
        if not ok then
            debug_log("auto buy failed:", err)
        end
    end
end)

-- 3. AUTO EQUIP LOOP
task.spawn(function()
    while run_id == State.RunId do
        task.wait(1)
        if not Config.AutoEquip then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        
        if not char:FindFirstChildWhichIsA("Tool") then
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                local tool = backpack:FindFirstChildWhichIsA("Tool")
                if tool then
                    tool.Parent = char
                end
            end
        end
    end
end)

local function fire_gui_button(button)
    if not button or not button.Visible or not button.Active then
        return false
    end

    if type(firesignal) == "function" then
        for i = 1, #BUTTON_SIGNALS do
            local event = button[BUTTON_SIGNALS[i]]
            if event then
                pcall(firesignal, event)
            end
        end
        return true
    end

    if type(getconnections) == "function" then
        for i = 1, #BUTTON_SIGNALS do
            local event = button[BUTTON_SIGNALS[i]]
            if event then
                local ok, connections = pcall(getconnections, event)
                if ok then
                    for index = 1, #connections do
                        pcall(function()
                            connections[index]:Fire()
                        end)
                    end
                end
            end
        end
        return true
    end

    return false
end

local function can_use_gear_button(button)
    local cooldown = button and button:FindFirstChild("CooldownOverlay", true)
    return button ~= nil and button.Visible and button.Active and not (cooldown and cooldown.Visible)
end

-- 4. AUTO SKILL LOOP
task.spawn(function()
    while run_id == State.RunId do
        task.wait(Config.AutoSkillDelay)
        validate_config()
        if not Config.AutoSkill then continue end

        local player_gui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local main_gui = player_gui and player_gui:FindFirstChild("MainGui")
        if not main_gui then continue end

        local gear_slots = {
            {Name = "Gear1", Key = "E"},
            {Name = "Gear2", Key = "R"},
            {Name = "Gear3", Key = "Q"}
        }

        for _, gear in ipairs(gear_slots) do
            local button = main_gui:FindFirstChild(gear.Name, true)
            if Config.AutoSkillKeys[gear.Key] and can_use_gear_button(button) then
                fire_gui_button(button)
                task.wait(0.15)
            end
        end
    end
end)

print("Arena Script: Full Farm + Auto Skill Loaded!")
