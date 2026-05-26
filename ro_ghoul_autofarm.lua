-- Ro-Ghoul [ALPHA] Auto-Farm Script V4 (SAFE STEALTH)
-- Features: Safe Tweening, Auto Stats, Auto Codes, Anti-AFK, Staff Server Hop

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- CONFIGURATION
local Config = {
    AutoTeam = "Ghoul",
    Enabled = true,
    TweenSpeed = 45, -- Lower speed is SAFER
    Distance = 6,
    AutoStats = { Enabled = true, Stats = {"Physical", "Weapon", "Durability", "Speed"} },
    AutoCodes = true,
    -- STEALTH
    AntiAFK = true,
    NoClip = true,
    StaffCheck = true,
    ServerHopOnStaff = true,
    RandomizeDelay = true,
    SpoofStats = true
}

-- 1. Property Spoofing
if Config.SpoofStats then
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(t, k)
            if not checkcaller() and t:IsA("Humanoid") then
                if k == "WalkSpeed" then return 16 end
                if k == "JumpPower" then return 50 end
            end
            return oldIndex(t, k)
        end)
        setreadonly(mt, true)
    end)
end

-- 2. Anti-AFK
if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- 3. NoClip (Only for Character)
RunService.Stepped:Connect(function()
    if Config.Enabled and Config.NoClip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- 4. Server Hop
local function ServerHop()
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, s in pairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                return true
            end
        end
    end)
end

-- 5. Staff Detection
local function IsStaff(player)
    return player:GetRankInGroup(28603491) >= 200 
end
Players.PlayerAdded:Connect(function(player)
    if Config.StaffCheck and IsStaff(player) and Config.ServerHopOnStaff then ServerHop() end
end)

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RaceChose = Remotes:WaitForChild("Race"):WaitForChild("Chose")
local DissectRemote = Remotes:WaitForChild("GyaSac"):WaitForChild("Dissect")
local SettingsRemote = Remotes:WaitForChild("Settings"):WaitForChild("Settings")
local CodeRemote = Remotes:WaitForChild("Code")

-- 6. Auto Codes & Team
task.spawn(function()
    if not LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("MainGui") then
        RaceChose:InvokeServer(Config.AutoTeam)
    end
    if Config.AutoCodes then
        local codes = {"ANNIVERSARY-8", "MATCHMAKING!", "No-Ghoul", "03/04/26 upd", "ReReKura1", "Taki Face", "1BV", "2M FAVS", "ANNIVERSARY-7", "TY FOR PLAYING :)"}
        for _, c in pairs(codes) do 
            task.wait(math.random(10, 30)/10)
            pcall(function() CodeRemote:FireServer("!Code " .. c) end) 
        end
    end
end)

-- 7. Auto Stats
task.spawn(function()
    while task.wait(5) do
        if Config.AutoStats.Enabled then
            for _, s in pairs(Config.AutoStats.Stats) do 
                pcall(function() SettingsRemote:InvokeServer("Focus", s) end) 
                task.wait(math.random(5, 15)/10)
            end
        end
    end
end)

-- 8. Safe Movement & Farming
local function GetKeyEvent()
    local Char = LocalPlayer.Character
    return Char and Char:FindFirstChild("Remotes") and Char.Remotes:FindFirstChild("KeyEvent")
end

local function GetNearestNPC()
    local nearest, dist = nil, math.huge
    for _, v in pairs(game.Workspace.NPCSpawns:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local root = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Head")
            if root then
                local d = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude
                if d < dist then dist = d; nearest = v end
            end
        end
    end
    return nearest
end

local currentTween = nil
local function SafeTween(targetPos)
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if currentTween then currentTween:Cancel() end
    
    local distance = (hrp.Position - targetPos).Magnitude
    local duration = distance / Config.TweenSpeed
    
    currentTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    currentTween:Play()
    return currentTween
end

-- MAIN LOOP
task.spawn(function()
    while task.wait(0.1) do
        if not Config.Enabled then continue end
        local Char = LocalPlayer.Character
        if not Char or not Char:FindFirstChild("HumanoidRootPart") then continue end
        
        -- Equip
        local ke = GetKeyEvent()
        if ke then ke:FireServer("1") end
        
        local npc = GetNearestNPC()
        if npc then
            local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
            if npcRoot then
                -- Random offset for stealth
                local offset = Vector3.new(math.random(-2, 2), Config.Distance, math.random(-2, 2))
                local targetPos = npcRoot.Position + offset
                
                local tween = SafeTween(targetPos)
                
                -- Wait for movement or NPC death
                while npc and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 and Config.Enabled do
                    task.wait(0.3)
                    
                    -- Dynamic follow without direct CFrame setting
                    local newTarget = npcRoot.Position + offset
                    if (Char.HumanoidRootPart.Position - newTarget).Magnitude > 2 then
                        SafeTween(newTarget)
                    end
                    
                    -- Attack
                    local attackKey = GetKeyEvent()
                    if attackKey then
                        attackKey:FireServer("Click", {["Hit"] = npcRoot.CFrame, ["Target"] = npcRoot})
                    end
                end
                
                -- Small delay after kill
                task.wait(0.5)
                -- Auto Dissect
                for _, v in pairs(game.Workspace:GetChildren()) do
                    if v.Name:find("Corpse") and (Char.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude < 15 then
                        DissectRemote:InvokeServer(v)
                        task.wait(0.3)
                        break
                    end
                end
            end
        end
    end
end)

print("Ro-Ghoul SAFE STEALTH V4 Loaded!")
