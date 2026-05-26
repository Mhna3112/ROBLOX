-- Ro-Ghoul [ALPHA] Auto-Shot (Kill Aura) Script
-- Features: Auto-Aim, Rapid Attack, Skill Spam, Stealth Bypass

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- CONFIGURATION
local Config = {
    Enabled = true,
    TargetNPCs = true,
    TargetPlayers = false,
    AttackDistance = 50,
    ClickSpeed = 0.15, -- Tốc độ click (giây)
    UseSkills = true,   -- Tự động dùng E, R, F
    SkillDelay = 2      -- Khoảng cách dùng skill
}

-- Lấy Remote tấn công
local function GetKeyEvent()
    local Char = LocalPlayer.Character
    return Char and Char:FindFirstChild("Remotes") and Char.Remotes:FindFirstChild("KeyEvent")
end

-- Tìm mục tiêu gần nhất
local function GetTarget()
    local nearest, dist = nil, Config.AttackDistance
    
    -- Tìm NPC
    if Config.TargetNPCs then
        for _, v in pairs(game.Workspace.NPCSpawns:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                local root = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Head")
                if root then
                    local d = (LocalPlayer.Character.HumanoidRootPart.Position - root.Position).Magnitude
                    if d < dist then dist = d; nearest = v end
                end
            end
        end
    end
    
    -- Tìm Người chơi (nếu bật)
    if Config.TargetPlayers then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local d = (LocalPlayer.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
                if d < dist then dist = d; nearest = p.Character end
            end
        end
    end
    
    return nearest
end

-- Vòng lặp Tấn công (Auto Shot)
task.spawn(function()
    while task.wait(Config.ClickSpeed) do
        if not Config.Enabled then continue end
        local Char = LocalPlayer.Character
        if not Char then continue end
        
        local target = GetTarget()
        if target then
            local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head")
            local ke = GetKeyEvent()
            
            if targetRoot and ke then
                -- 1. Auto Click (Shot)
                ke:FireServer("Click", {
                    ["Hit"] = targetRoot.CFrame,
                    ["Target"] = targetRoot
                })
                
                -- 2. Auto Aim (Chỉnh Camera/MouseHit nếu cần)
                -- (Trong Ro-Ghoul, gửi Hit CFrame trong remote là đủ để trúng)
            end
        end
    end
end)

-- Vòng lặp Skill (E, R, F)
task.spawn(function()
    while task.wait(Config.SkillDelay) do
        if Config.Enabled and Config.UseSkills then
            local target = GetTarget()
            local ke = GetKeyEvent()
            if target and ke then
                local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head")
                local skills = {"E", "R", "F"}
                local randomSkill = skills[math.random(1, #skills)]
                
                ke:FireServer(randomSkill, {
                    ["Hit"] = targetRoot.CFrame,
                    ["Target"] = targetRoot
                })
            end
        end
    end
end)

print("Ro-Ghoul Auto-Shot (Kill Aura) Kích hoạt!")
