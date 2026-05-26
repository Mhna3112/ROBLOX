-- Arena Lobby Automation V3
-- Game: Survive Zombie Arena (Lobby)
-- Features: Safe Tween TP, Auto Party Creation, Full Room Retry

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

local QueueRemotes = ReplicatedStorage:WaitForChild("QueueRemotes")
local CreateParty = QueueRemotes:WaitForChild("CreateParty")

-- CONFIGURATION
local Config = {
    ShipName = "Ship1",
    PartySize = 1,
    Difficulty = "Normal",
    Map = "Default",
    TweenSpeed = 45, -- Safe speed
    RetryDelay = 3,
    MaxJoinAttempts = 12,
    TeleportWait = 8
}

local function GetRootPart()
    local player = LocalPlayer or Players.LocalPlayer
    while not player do
        task.wait(0.1)
        player = Players.LocalPlayer
    end

    LocalPlayer = player
    Character = player.Character or player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart")
    return HRP
end

local function ReadNumber(instance, names)
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

local function ReadCapacityFromText(ship)
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

local function GetRoomCount(ship)
    local current = ReadNumber(ship, {"CurrentPlayers", "PlayerCount", "Players", "Count", "Amount"})
    local max = ReadNumber(ship, {"MaxPlayers", "MaxPlayer", "Capacity", "MaxSize", "Size"})

    if not current or not max then
        local text_current, text_max = ReadCapacityFromText(ship)
        current = current or text_current
        max = max or text_max
    end

    local players_folder = ship:FindFirstChild("Players") or ship:FindFirstChild("Members")
    if not current and players_folder then
        current = #players_folder:GetChildren()
    end

    return current, max
end

local function IsRoomFull(ship)
    local current, max = GetRoomCount(ship)
    return current ~= nil and max ~= nil and max > 0 and current >= max
end

local function GetTouchPart(ship)
    return ship and (ship:FindFirstChild("TouchPart") or ship:FindFirstChildWhichIsA("BasePart", true))
end

local function GetQueueOrder(queues)
    local ships = {}
    local preferred = queues:FindFirstChild(Config.ShipName)

    if preferred then
        table.insert(ships, preferred)
    end

    local others = queues:GetChildren()
    table.sort(others, function(a, b)
        return a.Name < b.Name
    end)

    for _, ship in ipairs(others) do
        if ship ~= preferred and GetTouchPart(ship) then
            table.insert(ships, ship)
        end
    end

    return ships
end

local function FindAvailableShip(queues, skipped_ships)
    local first_valid
    for _, ship in ipairs(GetQueueOrder(queues)) do
        if GetTouchPart(ship) and not skipped_ships[ship] then
            first_valid = first_valid or ship
            if not IsRoomFull(ship) then
                return ship, false
            end
        end
    end

    return first_valid, first_valid ~= nil
end

-- 1. Safe Tween to Ship
local function SafeTeleportToShip(ship)
    local target = GetTouchPart(ship)
    if not target then
        return false
    end

    local root = GetRootPart()
    print("Moving to " .. ship.Name .. " (Safe Tween)...")

    local distance = (root.Position - target.Position).Magnitude
    local duration = distance / Config.TweenSpeed

    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = target.CFrame})
    tween:Play()
    tween.Completed:Wait()
    tween:Destroy()

    -- Fire touch interest to trigger Lobby UI
    if firetouchinterest then
        firetouchinterest(root, target, 0)
        task.wait(0.1)
        firetouchinterest(root, target, 1)
    end

    return true
end

local function StillInLobby()
    return ReplicatedStorage:FindFirstChild("QueueRemotes") ~= nil and workspace:FindFirstChild("Queues") ~= nil
end

-- 2. Start Game Sequence
local function StartGame()
    task.wait(1.5) -- Wait for server to register character at ship
    print("Creating Party (Size: " .. Config.PartySize .. ")...")
    CreateParty:FireServer(Config.PartySize, Config.Difficulty, Config.Map)
end

-- Main Lobby Sequence
task.spawn(function()
    local queues = workspace:WaitForChild("Queues")
    local attempts = 0
    local skipped_ships = {}

    while attempts < Config.MaxJoinAttempts and StillInLobby() do
        attempts += 1

        local ship, all_full = FindAvailableShip(queues, skipped_ships)
        if not ship then
            warn("No open queue ships found, waiting before retry...")
            skipped_ships = {}
            task.wait(Config.RetryDelay)
            continue
        end

        if all_full then
            warn("All queue rooms look full, waiting before retry...")
            task.wait(Config.RetryDelay)
            continue
        end

        if SafeTeleportToShip(ship) then
            StartGame()
            task.wait(Config.TeleportWait)
            if StillInLobby() then
                skipped_ships[ship] = true
                warn("Still in lobby after trying " .. ship.Name .. ", switching room")
            end
        else
            warn("Failed to enter ship: " .. tostring(ship.Name))
            skipped_ships[ship] = true
            task.wait(Config.RetryDelay)
        end
    end

    if StillInLobby() then
        warn("Lobby join stopped after max attempts")
    end
end)

print("Arena Lobby Script V3 Loaded!")
