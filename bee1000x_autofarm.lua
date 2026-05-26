-- =======================================================
--   BEE WORLD SIMULATOR - AUTO-FARM V7.3 (LUAU STANDARD)
--   Cơ chế: TOUCH FlowerParts để lấy pollen (không cần tool)
--   Di chuyển: Tween nhanh tới field → ĐI BỘ (Walk) trong field
--   Tính năng: Auto Claim Hive, MakeHoney (true/false), Auto Collect Tokens
--   Quy chuẩn: Tuân thủ 100% quy tắc viết code LuaU sạch & tối ưu hiệu suất
-- =======================================================

-- Dừng instance cũ để tránh trùng lặp loop
if getgenv().BeeWorldFarmInstance then
    getgenv().BeeWorldFarmInstance.running = false
    task.wait(0.3)
end

-- Mỗi lần load script sẽ tạo một instance id mới.
-- Tất cả loop cũ sẽ tự thoát nếu id không còn khớp.
getgenv().BeeWorldFarmInstanceId = (getgenv().BeeWorldFarmInstanceId or 0) + 1
local INSTANCE_ID = getgenv().BeeWorldFarmInstanceId

-- =======================================================
-- [[ ROBLOX SERVICES & CACHING ]]
-- =======================================================
local PLAYERS             = game:GetService("Players")
local TWEEN_SERVICE        = game:GetService("TweenService")
local REPLICATED_STORAGE   = game:GetService("ReplicatedStorage")
local REMOTES              = REPLICATED_STORAGE:WaitForChild("Remotes")

local player              = PLAYERS.LocalPlayer

-- =======================================================
-- [[ GLOBAL CONFIGURATION ]]
-- =======================================================
getgenv().BeeConfig = getgenv().BeeConfig or {
    AutoFarm          = true,
    AutoDig           = true,       -- tự động đào đất bằng click ảo
    AutoQuest         = true,       -- tự nhận/nhận thưởng quest
    AutoQuestFollow   = true,       -- tự đọc quest và đổi field theo nhiệm vụ
    SelectedField     = "Daisy Field",
    AutoHoney         = true,       -- tự đổ mật khi đầy pollen
    AutoClaimHive     = true,       -- tự động claim hive trống khi startup
    AutoCollectTokens = true,       -- tự động nhặt token rơi gần đó
    StopAtPercent     = 0.95,       -- về tổ khi pollen >= 95% sức chứa
    TravelSpeed       = 220,        -- studs/s khi di chuyển xa (tween nhanh)
    PatrolSpeed       = 24,         -- WalkSpeed thực tế của nhân vật khi farm (tự nhiên nhất là 20-30 studs/s)
    StopTime          = 0.1,        -- giây dừng tại mỗi waypoint
    NumWaypoints      = 16,         -- số điểm tuần tra trong lưới Zig-Zag 4x4
    PatrolRadius      = 0.85,       -- % kích thước field dùng làm bán kính quét
    QuestTick         = 0.8,        -- chu kỳ quét quest (giây)
}
local config = getgenv().BeeConfig

-- =======================================================
-- [[ FIELDS CONSTANTS – tọa độ thực từ game ]]
-- =======================================================
local FIELDS = {
    ["Apple Field"]        = { cx=-1966.88, cy=92.34,  cz=-343.29, sx=132.6, sz=123.2 },
    ["Bamboo Field"]       = { cx=-1635.08, cy=115.41, cz=-168.68, sx=113.8, sz=109.8 },
    ["Blueberry Field"]    = { cx=-2070.47, cy=71.42,  cz=-183.77, sx=132.1, sz=131.2 },
    ["Cactus Field"]       = { cx=-2396.16, cy=106.92, cz=45.93,   sx=134.3, sz=128.0 },
    ["Cave Field"]         = { cx=-2009.33, cy=189.24, cz=-592.81, sx=235.2, sz=267.6 },
    ["Clover Field"]       = { cx=-1642.57, cy=144.76, cz=-492.96, sx=126.5, sz=140.2 },
    ["Daisy Field"]        = { cx=-2163.94, cy=71.42,  cz=47.38,   sx=140.0, sz=130.8 },
    ["Dragon Fruit Field"] = { cx=-2202.19, cy=145.18, cz=264.21,  sx=140.2, sz=129.8 },
    ["Elemental Field"]    = { cx=-2573.89, cy=140.86, cz=-244.76, sx=107.9, sz=132.0 },
    ["Forest Field"]       = { cx=-2357.71, cy=93.07,  cz=-181.28, sx=124.3, sz=144.2 },
    ["Glitch Field"]       = { cx=-2566.59, cy=165.91, cz=-427.96, sx=76.0,  sz=104.0 },
    ["Grape Field"]        = { cx=-2113.69, cy=92.34,  cz=-348.72, sx=132.1, sz=118.0 },
    ["Lemon Field"]        = { cx=-1809.28, cy=92.34,  cz=-339.98, sx=130.1, sz=128.1 },
    ["Mango Field"]        = { cx=-1899.45, cy=71.42,  cz=-137.44, sx=112.8, sz=105.7 },
    ["Mountain Field"]     = { cx=-1994.45, cy=234.38, cz=-516.11, sx=156.2, sz=116.0 },
    ["Mushroom Field"]     = { cx=-1784.11, cy=144.76, cz=-654.47, sx=158.4, sz=99.2  },
    ["Pear Field"]         = { cx=-1806.91, cy=144.76, cz=-487.74, sx=103.2, sz=150.0 },
    ["Pineapple Field"]    = { cx=-2422.51, cy=195.65, cz=380.46,  sx=216.5, sz=139.0 },
    ["Strawberry Field"]   = { cx=-1766.54, cy=71.42,  cz=-71.29,  sx=125.1, sz=140.0 },
    ["Watermelon Field"]   = { cx=-2215.61, cy=144.76, cz=-523.95, sx=120.0, sz=113.5 },
}

-- =======================================================
-- [[ RUNTIME STATE ]]
-- =======================================================
local runtime_state = {
    id           = INSTANCE_ID,
    running      = true,
    lastField    = nil,
    atField      = false,
    waypoints    = {},
    wpIdx        = 1,
    goingHome    = false,
    activeQuestText = "",
    questTargetField = nil,
    last_npc_talk = {},
}
getgenv().BeeWorldFarmInstance = runtime_state

-- =======================================================
-- [[ HELPERS & MEMORY CACHING ]]
-- =======================================================
local function get_root()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function get_honey_spoon()
    local char = player.Character
    local bp = player:FindFirstChild("Backpack")

    local tool = char and char:FindFirstChild("Honey Spoon")
    if tool and tool:IsA("Tool") then
        return tool
    end

    tool = bp and bp:FindFirstChild("Honey Spoon")
    if tool and tool:IsA("Tool") then
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(tool)
            task.wait()
        end
        return char and char:FindFirstChild("Honey Spoon") or tool
    end

    tool = char and char:FindFirstChildWhichIsA("Tool")
    if tool then
        return tool
    end

    tool = bp and bp:FindFirstChildWhichIsA("Tool")
    if tool then
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(tool)
            task.wait()
        end
        return char and char:FindFirstChild(tool.Name) or tool
    end

    return nil
end

local function dig_with_tool()
    local tool = get_honey_spoon()
    if not tool then
        return 0.12
    end

    local click = tool:FindFirstChild("Click")
    if click and click:IsA("Sound") then
        click:Play()
    end

    local remote = tool:FindFirstChild("ToolRemote")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    else
        tool:Activate()
    end

    local speed = tool:FindFirstChild("Speed")
    if speed and speed:IsA("NumberValue") then
        return math.clamp(speed.Value, 0.05, 1)
    end

    return 0.1
end

-- Tween di chuyển xa (Chỉ dùng khi bay về tổ hoặc bay tới cánh đồng)
local _current_tween = nil
local function tween_to(pos, speed, style, dir)
    local root = get_root()
    if not root then return end
    if _current_tween then _current_tween:Cancel(); _current_tween = nil end

    local dist = (root.Position - pos).Magnitude
    if dist < 1.5 then return end

    local secs = math.clamp(dist / speed, 0.05, 8)
    local ti   = TweenInfo.new(secs, style or Enum.EasingStyle.Sine,
                                     dir  or Enum.EasingDirection.InOut)
    
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true -- tắt trạng thái vật lý để tween mượt khi bay xa
    end

    local tw   = TWEEN_SERVICE:Create(root, ti, { CFrame = CFrame.new(pos) })
    _current_tween = tw
    tw:Play()
    tw.Completed:Wait()
    
    if hum then
        hum.PlatformStand = false
        root.Velocity = Vector3.zero
    end
    
    if _current_tween == tw then _current_tween = nil end
end

-- ĐI BỘ THỰC TẾ (Sử dụng Humanoid:MoveTo trong cánh đồng)
local function walk_to(pos)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = get_root()
    if not hum or not root then return end

    -- Đồng bộ WalkSpeed và đảm bảo trạng thái bình thường
    hum.WalkSpeed = config.PatrolSpeed
    hum.PlatformStand = false

    -- Gọi lệnh đi bộ
    hum:MoveTo(pos)

    local start = os.clock()
    local reached = false
    local connection
    
    connection = hum.MoveToFinished:Connect(function()
        reached = true
    end)

    -- Đợi đến khi tới nơi hoặc bị kẹt quá 4 giây (Unstuck Timeout)
    repeat
        task.wait(0.05)
        local dist = (root.Position - pos).Magnitude
        if dist < 2.5 then
            reached = true
        end
    until reached or (os.clock() - start) > 4 or not runtime_state.running

    if connection then connection:Disconnect() end
end

-- Tạo lưới di chuyển Zig-Zag bao phủ 100% diện tích cánh đồng
local function make_waypoints(name)
    local d = FIELDS[name]
    if not d then return {} end

    local rx = (d.sx / 2) * config.PatrolRadius
    local rz = (d.sz / 2) * config.PatrolRadius
    
    local rows = 4
    local cols = 4
    local pts = {}

    for r = 0, rows - 1 do
        local x_ratio = r / (rows - 1)
        local x = d.cx - rx + (2 * rx * x_ratio)
        
        -- Đi Zig-Zag: dòng chẵn đi xuôi, dòng lẻ đi ngược
        if r % 2 == 0 then
            for c = 0, cols - 1 do
                local z_ratio = c / (cols - 1)
                local z = d.cz - rz + (2 * rz * z_ratio)
                table.insert(pts, Vector3.new(x, d.cy, z))
            end
        else
            for c = cols - 1, 0, -1 do
                local z_ratio = c / (cols - 1)
                local z = d.cz - rz + (2 * rz * z_ratio)
                table.insert(pts, Vector3.new(x, d.cy, z))
            end
        end
    end
    
    return pts
end

-- Tìm và Claim Hive trống
local function claim_hive()
    local hive_obj = player:FindFirstChild("Hive")
    if hive_obj and hive_obj.Value then
        return hive_obj.Value
    end
    
    local Hives = workspace:FindFirstChild("Hives")
    if Hives then
        for _, hive in ipairs(Hives:GetChildren()) do
            local claimed = hive:FindFirstChild("Claimed")
            if claimed and claimed.Value == false then
                print("[BeeWorld] 🍯 Phát hiện Hive trống! Đang claim:", hive.Name)
                REPLICATED_STORAGE.Remotes.ClaimHive:FireServer(hive)
                task.wait(1)
                hive_obj = player:FindFirstChild("Hive")
                if hive_obj and hive_obj.Value == hive then
                    print("[BeeWorld] ✅ Đã claim thành công Hive:", hive.Name)
                    return hive
                end
            end
        end
    end
    return nil
end

-- Lấy Hive Pad đã claim để về đổ mật
local function get_hive_pad()
    local hive_obj = player:FindFirstChild("Hive")
    local my_hive  = hive_obj and hive_obj.Value
    if not my_hive then return nil end
    local plat = my_hive:FindFirstChild("Platform")
    if not plat then return nil end
    return plat:FindFirstChild("Top")
        or plat:FindFirstChild("Buttom")
        or plat:FindFirstChildWhichIsA("BasePart", true)
end

-- Lấy số lượng phấn hoa (Pollen) và sức chứa (Cap)
local function get_pollen()
    local p = player:FindFirstChild("Pollen")
    local c = player:FindFirstChild("Cap")
    return p and p.Value or 0, c and c.Value or 1000
end

-- [Tối ưu bộ nhớ]: Khai báo mảng tĩnh ngoài vòng lặp nhặt token để tránh cấp phát liên tục
local temp_tokens = {}

-- Tự động đi bộ (Walk) nhặt các token phần thưởng (Collectible) ở cự ly gần
local function collect_nearest_tokens()
    if not config.AutoCollectTokens then return end
    local root = get_root()
    if not root then return end

    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return end

    -- Reset mảng tĩnh để tái sử dụng
    table.clear(temp_tokens)

    -- Lọc token gần trong bán kính 45 studs
    for _, token in ipairs(collectibles:GetChildren()) do
        local part = token:IsA("BasePart") and token or token:FindFirstChildWhichIsA("BasePart")
        if part then
            local dist = (root.Position - part.Position).Magnitude
            if dist < 45 then
                table.insert(temp_tokens, { part = part, dist = dist })
            end
        end
    end

    -- Sắp xếp để nhặt các token gần nhất trước
    table.sort(temp_tokens, function(a, b) return a.dist < b.dist end)

    for i = 1, #temp_tokens do
        local t = temp_tokens[i]
        if t.part and t.part.Parent and runtime_state.running then
            -- Đi bộ tới token để nhặt tự nhiên
            walk_to(t.part.Position)
            task.wait(0.05)
        end
    end
end

local function normalize_text(s)
    s = string.lower(tostring(s or ""))
    s = s:gsub("[%c\r\n\t]", " ")
    s = s:gsub("%s+", " ")
    return s
end

local function detect_field_from_quest_text(quest_text)
    local q = normalize_text(quest_text)
    if q == "" then return nil end

    for field_name in pairs(FIELDS) do
        local full = normalize_text(field_name)
        local short = full:gsub("%s+field$", "")
        if q:find(full, 1, true) or q:find(short, 1, true) then
            return field_name
        end
    end

    return nil
end

local function read_active_quest_text()
    local player_gui = player:FindFirstChildOfClass("PlayerGui")
    if not player_gui then return "" end

    local main = player_gui:FindFirstChild("Main")
    local quest_frame = main and main:FindFirstChild("QuestFrame")
    local quests = quest_frame and quest_frame:FindFirstChild("Quests")
    if not quests then return "" end

    local chunks = {}
    for _, obj in ipairs(quests:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local t = normalize_text(obj.Text)
            if t ~= "" and #t >= 3 then
                table.insert(chunks, t)
            end
        end
    end

    return table.concat(chunks, " | ")
end

local function apply_quest_target_field(field_name)
    if not field_name or not FIELDS[field_name] then return end
    if config.SelectedField == field_name then return end

    config.SelectedField = field_name
    runtime_state.lastField = nil
    runtime_state.atField = false
    runtime_state.waypoints = {}
    runtime_state.wpIdx = 1
    runtime_state.questTargetField = field_name
    print("[BeeWorld] Auto Quest Follow ->", field_name)
end

local function try_click_gui_button(button)
    if not button or not button:IsA("GuiButton") then return false end
    local ok = false

    pcall(function()
        if firesignal then
            if button.Activated then firesignal(button.Activated) end
            if button.MouseButton1Click then firesignal(button.MouseButton1Click) end
            ok = true
        end
    end)

    if not ok then
        pcall(function()
            button:Activate()
            ok = true
        end)
    end

    return ok
end

local function auto_quest_tick()
    if not config.AutoQuest then return end

    local char = player.Character
    local root = get_root()
    if not char or not root then return end

    -- 1) Chỉ bấm nút quest trong khung QuestFrame (tránh dính shop UI)
    local player_gui = player:FindFirstChildOfClass("PlayerGui")
    if player_gui then
        local main = player_gui:FindFirstChild("Main")
        local quest_frame = main and main:FindFirstChild("QuestFrame")
        local quest_root = quest_frame and (quest_frame:FindFirstChild("Quests") or quest_frame)
        if quest_root then
            for _, obj in ipairs(quest_root:GetDescendants()) do
                if obj:IsA("GuiButton") and obj.Visible then
                    local n = string.lower(obj.Name or "")
                    local text = ""
                    if obj:IsA("TextButton") then
                        text = string.lower(obj.Text or "")
                    end
                    if n:find("claim") or n:find("accept") or n:find("complete")
                        or text:find("claim") or text:find("accept") or text:find("complete") then
                        try_click_gui_button(obj)
                    end
                end
            end
        end
    end

    -- 1.5) Chặn trigger từ nút shop hay pack có thể bị dính khi UI overlap
    local function is_shop_open()
        local player_gui2 = player:FindFirstChildOfClass("PlayerGui")
        if not player_gui2 then return false end
        local main2 = player_gui2:FindFirstChild("Main")
        if not main2 then return false end
        local shop = main2:FindFirstChild("Shop")
        local catalog = main2:FindFirstChild("Catalog1")
        return (shop and shop.Visible) or (catalog and catalog.Visible)
    end
    if is_shop_open() then
        return
    end

    -- 2) Theo source PlayerNpc: TalkToNPC:FireServer(prompt.ActionText)
    local quest_npcs = workspace:FindFirstChild("QuestNPCS")
    local talk_remote = REMOTES:FindFirstChild("TalkToNPC")
    if quest_npcs and talk_remote and talk_remote:IsA("RemoteEvent") then
        local now = os.clock()
        for _, obj in ipairs(quest_npcs:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Name == "Proxy" and obj.Enabled then
                local holder = obj.Parent
                local part = holder and (holder:IsA("BasePart") and holder or holder:FindFirstChildWhichIsA("BasePart", true))
                if part and (part.Position - root.Position).Magnitude <= 14 then
                    local npc_name = tostring(obj.ActionText or "")
                    if npc_name ~= "" then
                        local last_talk = runtime_state.last_npc_talk[npc_name] or 0
                        if now - last_talk >= 1.5 then
                            pcall(function()
                                talk_remote:FireServer(npc_name)
                            end)
                            runtime_state.last_npc_talk[npc_name] = now
                        end
                    end
                end
            end
        end
    end

    -- 3) Đọc quest hiện tại và bám theo nhiệm vụ (ưu tiên nhiệm vụ theo field)
    if config.AutoQuestFollow then
        local quest_text = read_active_quest_text()
        if quest_text ~= "" then
            runtime_state.activeQuestText = quest_text
            local field_target = detect_field_from_quest_text(quest_text)
            apply_quest_target_field(field_target)
        end
    end
end

-- =======================================================
-- [[ AUTO DIG PROCESS (Luồng Đào Đất Bằng ToolRemote) ]]
-- =======================================================
task.spawn(function()
    while runtime_state.running and getgenv().BeeWorldFarmInstanceId == INSTANCE_ID do
        local dig_delay = 0.12
        if runtime_state.running and config.AutoFarm and config.AutoDig and not runtime_state.goingHome and runtime_state.atField then
            pcall(function()
                dig_delay = dig_with_tool()
            end)
        end
        task.wait(dig_delay)
    end
end)

task.spawn(function()
    while runtime_state.running and getgenv().BeeWorldFarmInstanceId == INSTANCE_ID do
        pcall(auto_quest_tick)
        task.wait(config.QuestTick or 0.8)
    end
end)

-- =======================================================
-- [[ MAIN AUTO FARM LOOP ]]
-- =======================================================
task.spawn(function()
    -- Đồng bộ dữ liệu ban đầu
    print("[BeeWorld] 🔄 Đang tải dữ liệu nhân vật...")
    pcall(function()
        REPLICATED_STORAGE.Remotes.GetData:InvokeServer()
    end)
    task.wait(0.5)

    while runtime_state.running and getgenv().BeeWorldFarmInstanceId == INSTANCE_ID do
        if not config.AutoFarm then task.wait(0.3); continue end

        local root = get_root()
        if not root then task.wait(0.5); continue end

        -- ── 0. Tự động Claim Hive nếu chưa có ──
        if config.AutoClaimHive then
            local my_hive = claim_hive()
            if not my_hive then
                warn("[BeeWorld] ⚠️ Không có Hive nào khả dụng để claim! Đang thử lại...")
                task.wait(1.5)
                continue
            end
        end

        -- ── 1. Đổ mật khi phấn hoa đầy (Backpack Full) ──
        local pollen, cap = get_pollen()
        if config.AutoHoney and pollen >= cap * config.StopAtPercent and cap > 0 then
            runtime_state.goingHome = true
            runtime_state.atField   = false  -- Reset trạng thái để di chuyển lại tới field sau khi xong
            local pad = get_hive_pad()
            if pad then
                print("[BeeWorld] 🎒 Phấn hoa đầy (" .. tostring(pollen) .. "/" .. tostring(cap) .. ")! Bay về tổ...")
                
                -- Tween nhanh về Hive Pad
                tween_to(pad.Position + Vector3.new(0, 3, 0), config.TravelSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                task.wait(0.1)

                -- Kích hoạt MakeHoney (true)
                print("[BeeWorld] 🍯 Đang bắt đầu làm mật...")
                pcall(function()
                    REPLICATED_STORAGE.Remotes.MakeHoney:FireServer(true)
                end)

                -- Chờ cho đến khi chuyển đổi hết phấn hoa
                local tries = 0
                repeat
                    task.wait(0.2)
                    pollen, cap = get_pollen()
                    tries = tries + 1
                until pollen <= 0 or tries > 100 or not runtime_state.running

                -- Dừng MakeHoney (false)
                pcall(function()
                    REPLICATED_STORAGE.Remotes.MakeHoney:FireServer(false)
                end)
                print("[BeeWorld] ✅ Làm mật hoàn tất!")
            else
                warn("[BeeWorld] ❌ Không tìm thấy Hive pad để làm mật!")
                task.wait(1.5)
            end
            runtime_state.goingHome  = false
            runtime_state.waypoints  = {}
            runtime_state.wpIdx      = 1
            task.wait(0.2)
            continue
        end

        -- ── 2. Di chuyển tuần tra và farm trong cánh đồng ──
        local field_name = config.SelectedField
        local field_data = FIELDS[field_name]

        -- Nếu đổi field -> reset waypoint tuần tra
        if field_name ~= runtime_state.lastField then
            runtime_state.lastField = field_name
            runtime_state.atField   = false
            runtime_state.waypoints = {}
            runtime_state.wpIdx     = 1
        end

        -- PHA 1: Tween NHANH tới tâm field (Di chuyển xa)
        if not runtime_state.atField and field_data then
            local center = Vector3.new(field_data.cx, field_data.cy, field_data.cz)
            local dist   = (root.Position - center).Magnitude
            if dist > 15 then
                print("[BeeWorld] 🚀 Bay tới cánh đồng:", field_name, string.format("(%.0f studs)", dist))
                tween_to(center, config.TravelSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                task.wait(0.1)
            end
            runtime_state.waypoints = make_waypoints(field_name)
            runtime_state.wpIdx     = 1
            runtime_state.atField   = true
            print("[BeeWorld] ✅ Đã đến cánh đồng. Bắt đầu đi bộ tuần tra quét sạch hoa!")
        end

        -- PHA 2: ĐI BỘ (Walk) tuần tra Zig-Zag & gom Tokens rơi gần
        if runtime_state.atField and #runtime_state.waypoints > 0 then
            -- Tự động đi bộ nhặt tokens xung quanh
            collect_nearest_tokens()

            local target = runtime_state.waypoints[runtime_state.wpIdx]
            if target and runtime_state.running then
                -- Đi bộ thực tế bằng Humanoid:MoveTo
                walk_to(target)
                task.wait(config.StopTime)
            end

            -- Đi tới waypoint tiếp theo
            runtime_state.wpIdx = runtime_state.wpIdx + 1
            if runtime_state.wpIdx > #runtime_state.waypoints then
                runtime_state.wpIdx     = 1
                runtime_state.waypoints = make_waypoints(field_name)
                print("[BeeWorld] 🔄 Đã quét hết vòng field. Bắt đầu vòng đi bộ mới!")
            end
        end

        task.wait(0.05)
    end
    if getgenv().BeeWorldFarmInstanceId == INSTANCE_ID then
        print("[BeeWorld] ⛔ Vòng lặp Auto-Farm đã dừng hẳn.")
    end
end)

-- =======================================================
-- =======================================================
-- [[ NATIVE UI ]]
-- =======================================================
pcall(function()
    local player_gui = player:WaitForChild("PlayerGui")
    local old = player_gui:FindFirstChild("BeeWorldNativeUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BeeWorldNativeUI"
    gui.ResetOnSpawn = false
    gui.Parent = player_gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(360, 430)
    frame.Position = UDim2.fromOffset(20, 120)
    frame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 30)
    title.Position = UDim2.fromOffset(5, 5)
    title.BackgroundTransparency = 1
    title.Text = "Bee World Auto Farm (Native UI)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local y = 42
    local function make_toggle(label, key)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 30)
        b.Position = UDim2.fromOffset(5, y)
        b.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 14
        b.Font = Enum.Font.Gotham
        local function refresh()
            b.Text = string.format("%s: %s", label, config[key] and "ON" or "OFF")
        end
        refresh()
        b.MouseButton1Click:Connect(function()
            config[key] = not config[key]
            if key == "AutoFarm" and config[key] then
                runtime_state.atField = false
            end
            refresh()
        end)
        b.Parent = frame
        y = y + 34
    end

    make_toggle("Auto Farm", "AutoFarm")
    make_toggle("Auto Dig", "AutoDig")
    make_toggle("Auto Quest", "AutoQuest")
    make_toggle("Auto Quest Follow", "AutoQuestFollow")
    make_toggle("Auto Honey", "AutoHoney")
    make_toggle("Auto Claim Hive", "AutoClaimHive")
    make_toggle("Auto Collect Tokens", "AutoCollectTokens")

    local field_list = {}
    for name in pairs(FIELDS) do
        table.insert(field_list, name)
    end
    table.sort(field_list)

    local field_idx = 1
    for i, name in ipairs(field_list) do
        if name == config.SelectedField then
            field_idx = i
            break
        end
    end

    local picker = Instance.new("Frame")
    picker.Size = UDim2.new(1, -10, 0, 30)
    picker.Position = UDim2.fromOffset(5, y)
    picker.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
    picker.BorderSizePixel = 0
    picker.Parent = frame

    local prev_btn = Instance.new("TextButton")
    prev_btn.Size = UDim2.fromOffset(30, 30)
    prev_btn.Position = UDim2.fromOffset(0, 0)
    prev_btn.BackgroundColor3 = Color3.fromRGB(64, 70, 90)
    prev_btn.BorderSizePixel = 0
    prev_btn.Text = "<"
    prev_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    prev_btn.TextSize = 16
    prev_btn.Font = Enum.Font.GothamBold
    prev_btn.Parent = picker

    local next_btn = Instance.new("TextButton")
    next_btn.Size = UDim2.fromOffset(30, 30)
    next_btn.Position = UDim2.new(1, -30, 0, 0)
    next_btn.BackgroundColor3 = Color3.fromRGB(64, 70, 90)
    next_btn.BorderSizePixel = 0
    next_btn.Text = ">"
    next_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    next_btn.TextSize = 16
    next_btn.Font = Enum.Font.GothamBold
    next_btn.Parent = picker

    local field_label = Instance.new("TextLabel")
    field_label.Size = UDim2.new(1, -60, 1, 0)
    field_label.Position = UDim2.fromOffset(30, 0)
    field_label.BackgroundTransparency = 1
    field_label.TextColor3 = Color3.fromRGB(255, 255, 255)
    field_label.TextSize = 14
    field_label.Font = Enum.Font.Gotham
    field_label.TextXAlignment = Enum.TextXAlignment.Center
    field_label.Parent = picker

    local function refresh_field_label()
        field_label.Text = field_list[field_idx] or "Unknown Field"
    end
    refresh_field_label()

    prev_btn.MouseButton1Click:Connect(function()
        field_idx = field_idx - 1
        if field_idx < 1 then
            field_idx = #field_list
        end
        refresh_field_label()
    end)

    next_btn.MouseButton1Click:Connect(function()
        field_idx = field_idx + 1
        if field_idx > #field_list then
            field_idx = 1
        end
        refresh_field_label()
    end)
    y = y + 34

    local apply_field = Instance.new("TextButton")
    apply_field.Size = UDim2.new(1, -10, 0, 30)
    apply_field.Position = UDim2.fromOffset(5, y)
    apply_field.BackgroundColor3 = Color3.fromRGB(58, 88, 150)
    apply_field.BorderSizePixel = 0
    apply_field.TextColor3 = Color3.fromRGB(255, 255, 255)
    apply_field.TextSize = 14
    apply_field.Font = Enum.Font.GothamBold
    apply_field.Text = "Apply Field"
    apply_field.MouseButton1Click:Connect(function()
        local v = field_list[field_idx]
        if v and FIELDS[v] then
            config.SelectedField = v
            runtime_state.atField = false
            runtime_state.waypoints = {}
            runtime_state.wpIdx = 1
        end
    end)
    apply_field.Parent = frame
    y = y + 34

    local reset_btn = Instance.new("TextButton")
    reset_btn.Size = UDim2.new(1, -10, 0, 30)
    reset_btn.Position = UDim2.fromOffset(5, y)
    reset_btn.BackgroundColor3 = Color3.fromRGB(56, 68, 84)
    reset_btn.BorderSizePixel = 0
    reset_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    reset_btn.TextSize = 14
    reset_btn.Font = Enum.Font.Gotham
    reset_btn.Text = "Reset Waypoints"
    reset_btn.MouseButton1Click:Connect(function()
        runtime_state.atField = false
        runtime_state.waypoints = {}
        runtime_state.wpIdx = 1
    end)
    reset_btn.Parent = frame
    y = y + 34

    local stop_btn = Instance.new("TextButton")
    stop_btn.Size = UDim2.new(1, -10, 0, 30)
    stop_btn.Position = UDim2.fromOffset(5, y)
    stop_btn.BackgroundColor3 = Color3.fromRGB(150, 64, 64)
    stop_btn.BorderSizePixel = 0
    stop_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stop_btn.TextSize = 14
    stop_btn.Font = Enum.Font.GothamBold
    stop_btn.Text = "Stop Script"
    stop_btn.MouseButton1Click:Connect(function()
        runtime_state.running = false
        if _current_tween then _current_tween:Cancel() end
        gui:Destroy()
    end)
    stop_btn.Parent = frame
end)
print("[BeeWorld] ✅ Auto-Farm V7.3 (LuaU Standard Edition) Loaded Thành Công!")
