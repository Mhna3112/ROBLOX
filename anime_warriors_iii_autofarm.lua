local players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")
local core_gui = game:GetService("CoreGui")
local user_input_service = game:GetService("UserInputService")
local tween_service = game:GetService("TweenService")
local lighting = game:GetService("Lighting")

local local_player = players.LocalPlayer

local constants = require(replicated_storage.src.common.constants.core)
local datastore = require(replicated_storage.src.common.store.players.datastore)

local remote_container = replicated_storage
    :WaitForChild("rbxts_include")
    :WaitForChild("node_modules")
    :WaitForChild("@rbxts")
    :WaitForChild("remo")
    :WaitForChild("src")
    :WaitForChild("container")

local function get_remote(remote_name)
    return remote_container:FindFirstChild(remote_name)
end

local enemies_switch_enemy = get_remote("enemies.switchEnemy")
local enemies_send_and_retreat = get_remote("enemies.sendAndRetreat")
local warriors_equip = get_remote("warriors.equip")
local warriors_unequip_all = get_remote("warriors.unequipAll")
local weapons_equip = get_remote("weapons.equip")
local world_teleport_to_waystone = get_remote("world.teleportToWaystone")

getgenv().anime_warriors_config = getgenv().anime_warriors_config or {
    auto_farm = false,
    auto_cycle_islands = false,
    auto_equip_selected = true,
    auto_equip_weapon = true,
    anti_afk = true,
    no_render = false,
    farm_delay = 0.2,
    teleport_delay = 12,
    tween_speed = 280,
    tween_height = 6,
    selected_warriors = {},
    selected_islands = {},
    target_enemy_id = "",
    target_enemy_name = "",
    target_enemy_anchor = nil,
    -- New Egg Features
    auto_open_egg = false,
    selected_egg = "Nemak",
    open_amount = 1,
    webhook_url = "https://discord.com/api/webhooks/1407599678119481395/ZLo1lkVMIZxFRk6KJSPni6MBc9_Td_WHzvwErhYhVBdTYs719xsqwgv9sC63EDt3RzJW",
    webhook_enabled = true,
    webhook_rarity = "mythical"
}

local config = getgenv().anime_warriors_config

config.auto_farm = config.auto_farm == true
config.auto_cycle_islands = config.auto_cycle_islands == true
config.auto_equip_selected = config.auto_equip_selected ~= false
config.auto_equip_weapon = config.auto_equip_weapon ~= false
config.anti_afk = config.anti_afk ~= false
config.no_render = config.no_render == true
config.farm_delay = tonumber(config.farm_delay) or 0.2
config.teleport_delay = tonumber(config.teleport_delay) or 12
config.tween_speed = tonumber(config.tween_speed) or 280
config.tween_height = tonumber(config.tween_height) or 6
config.selected_warriors = typeof(config.selected_warriors) == "table" and config.selected_warriors or {}
config.selected_islands = typeof(config.selected_islands) == "table" and config.selected_islands or {}
config.target_enemy_id = type(config.target_enemy_id) == "string" and config.target_enemy_id or ""
config.target_enemy_name = type(config.target_enemy_name) == "string" and config.target_enemy_name or ""
config.target_enemy_anchor = typeof(config.target_enemy_anchor) == "table" and config.target_enemy_anchor or nil

-- New Egg Config Init
config.auto_open_egg = config.auto_open_egg == true
config.selected_egg = type(config.selected_egg) == "string" and config.selected_egg or "Nemak"
config.open_amount = tonumber(config.open_amount) or 1
config.webhook_url = type(config.webhook_url) == "string" and config.webhook_url or ""
config.webhook_enabled = config.webhook_enabled == true
config.webhook_rarity = type(config.webhook_rarity) == "string" and config.webhook_rarity or "mythical"

local previous_instance = getgenv().anime_warriors_runtime_instance
if type(previous_instance) == "table" then
    if previous_instance.runtime then
        previous_instance.runtime.running = false
    end

    local previous_ui_refs = previous_instance.ui_refs
    if type(previous_ui_refs) == "table" and previous_ui_refs.window then
        pcall(function()
            previous_ui_refs.window:Unload()
        end)
    end
end

local runtime = {
    running = true,
    island_index = 1,
    last_teleport = 0,
    status = "idle",
    connections = {},
    character = nil,
    root_part = nil,
    humanoid = nil,
    active_tween = nil,
    manual_target_selected = false,
    last_target_enemy_id = "",
    last_target_move_at = 0,
    last_egg_open = 0
}

local ui_refs = {}
getgenv().anime_warriors_runtime_instance = {
    runtime = runtime,
    ui_refs = ui_refs
}

local rarity_order = {
    ["common"] = 1,
    ["rare"] = 2,
    ["epic"] = 3,
    ["legendary"] = 4,
    ["mythical"] = 5,
    ["exclusive"] = 6,
    ["???"] = 7
}

local warrior_rarity_cache = {}
local function build_warrior_rarity_cache()
    local ok, content = pcall(function()
        return require(replicated_storage.src.common.content.humans.warriors).warriorsContent
    end)
    if ok and content then
        for name, data in pairs(content) do
            warrior_rarity_cache[name] = data.rarity or "common"
        end
    end
end

build_warrior_rarity_cache()

local http_request = request or http_request or (http and http.request) or (syn and syn.request)

local function send_webhook(title, description, color)
    if not config.webhook_enabled or config.webhook_url == "" or not http_request then
        return
    end

    local data = {
        ["content"] = nil,
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 16777215,
            ["footer"] = {
                ["text"] = "Anime Warriors III Autofarm"
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        http_request({
            Url = config.webhook_url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(data)
        })
    end)
end

local eggs_open = get_remote("eggs.open")
local enemy_name_cache = {}
local enemy_bounds_name_cache = {
    ["5.00|6.25|1.25"] = "Sand Elder",
    ["6.00|7.50|1.50"] = "Puppeteer",
    ["4.00|5.00|1.00"] = "Sand Ninja",
    ["14.00|17.50|3.50"] = "Gurra",
    ["7.00|8.75|1.75"] = "Temmuri"
}

local function get_enemy_signature(model)
    local part_names = {}

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
            table.insert(part_names, descendant.Name)
        end
    end

    table.sort(part_names)

    local slice_end = math.min(#part_names, 12)
    return table.concat(part_names, "|", 1, slice_end)
end

local function build_enemy_name_cache()
    table.clear(enemy_name_cache)

    local assets = replicated_storage:FindFirstChild("Assets")
    local enemies_folder = assets and assets:FindFirstChild("Enemies")
    if not enemies_folder then
        return
    end

    for _, enemy_model in ipairs(enemies_folder:GetChildren()) do
        if enemy_model:IsA("Model") then
            enemy_name_cache[get_enemy_signature(enemy_model)] = enemy_model.Name
        end
    end
end

build_enemy_name_cache()

local function ensure_blur()
    local blur = lighting:FindFirstChild("anime_warriors_blur")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "anime_warriors_blur"
        blur.Size = 24
        blur.Parent = lighting
    end

    return blur
end

local function safe_disconnect(connection)
    if connection then
        connection:Disconnect()
    end
end

local function get_enemy_from_instance(instance)
    local enemies_folder = workspace:FindFirstChild("World")
    enemies_folder = enemies_folder and enemies_folder:FindFirstChild("Enemies")
    if not enemies_folder or not instance then
        return nil
    end

    local current = instance
    while current and current ~= workspace do
        if current.Parent == enemies_folder and current:IsA("Model") then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function safe_fire(remote, ...)
    if remote and remote:IsA("RemoteEvent") then
        local ok, err = pcall(function(...)
            remote:FireServer(...)
        end, ...)
        return ok, err
    end

    return false, "missing_remote"
end

local function safe_invoke(remote, ...)
    if remote and remote:IsA("RemoteFunction") then
        local ok, result = pcall(function(...)
            return remote:InvokeServer(...)
        end, ...)
        return ok, result
    end

    return false, "missing_remote"
end

local function setup_optimizations()
    -- Anti AFK
    local virtual_user = game:GetService("VirtualUser")
    local_player.Idled:Connect(function()
        if config.anti_afk then
            virtual_user:CaptureController()
            virtual_user:ClickButton2(Vector2.new())
        end
    end)

    -- No Render (CPU Saver)
    run_service:Set3dRenderingEnabled(not config.no_render)
    
    -- Sync no_render state if changed externally or initially
    task.spawn(function()
        while runtime.running do
            local should_be_enabled = not config.no_render
            if run_service:Get3dRenderingEnabled() ~= should_be_enabled then
                run_service:Set3dRenderingEnabled(should_be_enabled)
            end
            task.wait(1)
        end
        run_service:Set3dRenderingEnabled(true) -- Restore on stop
    end)
end

setup_optimizations()

local function update_character_references(character)
    runtime.character = character
    runtime.root_part = character and character:FindFirstChild("HumanoidRootPart") or nil
    runtime.humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
end

update_character_references(local_player.Character or local_player.CharacterAdded:Wait())

table.insert(runtime.connections, local_player.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    update_character_references(character)
end))

local player_data_cache = {
    data = nil,
    last_update = 0
}

local function get_player_data()
    local now = os.clock()
    if player_data_cache.data and now - player_data_cache.last_update < 1 then
        return player_data_cache.data
    end

    local data = datastore.getPlayerData(constants.USER_KEY)
    player_data_cache.data = data
    player_data_cache.last_update = now
    return data
end

local function short_id(raw_id)
    if not raw_id then
        return "nil"
    end

    return string.sub(raw_id, 1, 8)
end

local function set_status(text)
    runtime.status = text
    if ui_refs.status_label then
        ui_refs.status_label.Text = "status: " .. text
    end
    if ui_refs.status_control then
        pcall(function()
            ui_refs.status_control:UpdateName("Status: " .. text)
        end)
    end
end

local function get_warrior_inventory()
    local data = get_player_data()
    local warrior_list = {}

    if not data or not data.warriors then
        return warrior_list
    end

    for warrior_id, warrior_data in pairs(data.warriors) do
        table.insert(warrior_list, {
            id = warrior_id,
            name = warrior_data.name,
            nickname = warrior_data.nickname,
            level = warrior_data.level or 1,
            tier = warrior_data.tier or 0,
            ascension = warrior_data.ascension or 0,
            locked = warrior_data.locked == true
        })
    end

    table.sort(warrior_list, function(left, right)
        if left.level == right.level then
            return left.name < right.name
        end

        return left.level > right.level
    end)

    return warrior_list
end

local function get_equipped_warrior_ids()
    local data = get_player_data()
    local equipped_ids = {}

    if not data or not data.equippedWarriors then
        return equipped_ids
    end

    for _, warrior_id in pairs(data.equippedWarriors) do
        table.insert(equipped_ids, warrior_id)
    end

    return equipped_ids
end

local function get_spawn_points()
    local result = {}
    local teleports = workspace:FindFirstChild("World")
    teleports = teleports and teleports:FindFirstChild("Teleports")
    teleports = teleports and teleports:FindFirstChild("Locations")

    if not teleports then
        return result
    end

    for _, part in ipairs(teleports:GetChildren()) do
        if part:IsA("BasePart") then
            result[part.Name] = part.CFrame
        end
    end

    return result
end

local function get_weapon_inventory()
    local data = get_player_data()
    local weapon_list = {}

    if not data or not data.weapons then
        return weapon_list
    end

    for weapon_id, weapon_data in pairs(data.weapons) do
        table.insert(weapon_list, {
            id = weapon_id,
            name = weapon_data.name,
            level = weapon_data.level or 1,
            locked = weapon_data.locked == true
        })
    end

    table.sort(weapon_list, function(left, right)
        if left.level == right.level then
            return left.name < right.name
        end

        return left.level > right.level
    end)

    return weapon_list
end

local function get_equipped_weapon_id()
    local data = get_player_data()
    if not data then
        return nil
    end

    return data.equippedWeapon
end

local function ensure_weapon_equipped()
    if not config.auto_equip_weapon then
        return
    end

    local equipped_weapon_id = get_equipped_weapon_id()
    if equipped_weapon_id and equipped_weapon_id ~= "" then
        local ok = safe_fire(weapons_equip, equipped_weapon_id)
        if ok then
            return
        end
    end

    local weapons = get_weapon_inventory()
    if #weapons == 0 then
        return
    end

    safe_fire(weapons_equip, weapons[1].id)
end

local function get_island_target_cframe(island_name)
    local world = workspace:FindFirstChild("World")
    local map_folder = world and world:FindFirstChild("Map")
    local island = map_folder and map_folder:FindFirstChild(island_name)

    if not island then
        return nil
    end

    local best_target = nil

    for _, obj in ipairs(island:GetDescendants()) do
        local root_part = nil
        local lowered_name = string.lower(obj.Name)

        if not string.find(lowered_name, "waystone", 1, true) then
            continue
        end

        if obj:IsA("Model") then
            root_part = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        elseif obj:IsA("BasePart") then
            root_part = obj
        end

        if root_part then
            best_target = root_part.CFrame
            break
        end
    end

    return best_target
end

local function stop_active_tween()
    if runtime.active_tween then
        runtime.active_tween:Cancel()
        runtime.active_tween = nil
    end
end

local function tween_to_cframe(target_cframe)
    if not runtime.root_part or not target_cframe then
        return false
    end

    stop_active_tween()

    local start_position = runtime.root_part.Position
    local goal_cframe = target_cframe + Vector3.new(0, config.tween_height, 0)
    local distance = (goal_cframe.Position - start_position).Magnitude
    
    -- Tránh tween nếu khoảng cách quá nhỏ
    if distance < 2 then
        runtime.root_part.CFrame = goal_cframe
        return true
    end

    local speed = math.max(config.tween_speed, 50)
    local tween_time = math.clamp(distance / speed, 0.1, 20)

    -- Vô hiệu hóa vật lý để tránh giật (stutter)
    local old_anchored = runtime.root_part.Anchored
    runtime.root_part.Anchored = true
    
    if runtime.humanoid then
        runtime.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end

    local tween = tween_service:Create(
        runtime.root_part,
        TweenInfo.new(tween_time, Enum.EasingStyle.Linear),
        { CFrame = goal_cframe }
    )

    runtime.active_tween = tween
    tween:Play()

    local finished = false
    local connection
    connection = tween.Completed:Connect(function()
        finished = true
    end)

    local timeout_at = os.clock() + tween_time + 1
    while runtime.running and runtime.active_tween == tween and not finished and os.clock() < timeout_at do
        if not runtime.root_part or not runtime.root_part.Parent then
            break
        end
        task.wait()
    end

    safe_disconnect(connection)

    -- Khôi phục trạng thái vật lý
    if runtime.root_part and runtime.root_part.Parent then
        runtime.root_part.Anchored = old_anchored
        runtime.root_part.CFrame = goal_cframe
    end

    if runtime.active_tween == tween then
        runtime.active_tween = nil
        return true
    end

    return false
end

local function get_island_names()
    local names = {}
    local seen = {}
    local spawn_points = get_spawn_points()

    for island_name in pairs(spawn_points) do
        if not seen[island_name] then
            seen[island_name] = true
            table.insert(names, island_name)
        end
    end

    table.sort(names)
    return names
end

local function ensure_default_selection()
    if next(config.selected_warriors) == nil then
        for _, warrior_id in ipairs(get_equipped_warrior_ids()) do
            config.selected_warriors[warrior_id] = true
        end
    end

    if next(config.selected_islands) == nil then
        for _, island_name in ipairs(get_island_names()) do
            config.selected_islands[island_name] = true
        end
    end
end

local function get_selected_warriors()
    local selected = {}

    for _, warrior in ipairs(get_warrior_inventory()) do
        if config.selected_warriors[warrior.id] then
            table.insert(selected, warrior)
        end
    end

    return selected
end

local function get_selected_warrior_ids()
    local warrior_ids = {}

    for _, warrior in ipairs(get_selected_warriors()) do
        table.insert(warrior_ids, warrior.id)
    end

    return warrior_ids
end

local function get_selected_islands()
    local islands = {}

    for _, island_name in ipairs(get_island_names()) do
        if config.selected_islands[island_name] then
            table.insert(islands, island_name)
        end
    end

    return islands
end

local function equip_selected_warriors()
    local selected = get_selected_warriors()

    if #selected == 0 then
        set_status("no selected warriors")
        return
    end

    local ok = safe_fire(warriors_unequip_all)
    if not ok then
        set_status("failed unequip_all")
        return
    end

    task.wait(0.35)

    local limit = math.min(#selected, 4)
    for index = 1, limit do
        safe_fire(warriors_equip, selected[index].id)
        task.wait(0.15)
    end

    set_status("equipped " .. tostring(limit) .. " selected warriors")
end

local function get_alive_enemies()
    local enemies_folder = workspace:FindFirstChild("World")
    enemies_folder = enemies_folder and enemies_folder:FindFirstChild("Enemies")

    local enemies = {}
    if not enemies_folder then
        return enemies
    end

    for _, enemy in ipairs(enemies_folder:GetChildren()) do
        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
        local root_part = enemy:FindFirstChild("HumanoidRootPart")
        local dead = enemy:GetAttribute("dead") == true

        if humanoid and root_part and not dead and humanoid.Health > 0 then
            table.insert(enemies, enemy)
        end
    end

    return enemies
end

local function is_enemy_alive(enemy)
    if not enemy or not enemy.Parent then
        return false
    end

    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    if enemy:GetAttribute("dead") == true then
        return false
    end

    return enemy:FindFirstChild("HumanoidRootPart") ~= nil
end

local function get_enemy_bounds_key(enemy)
    local bounds = enemy and enemy:GetAttribute("bounds")
    if typeof(bounds) ~= "Vector3" then
        return ""
    end

    return string.format("%.2f|%.2f|%.2f", bounds.X, bounds.Y, bounds.Z)
end

local function get_enemy_display_name(enemy)
    local exact_name = enemy_name_cache[get_enemy_signature(enemy)]
    if exact_name then
        return exact_name
    end

    local bounds_name = enemy_bounds_name_cache[get_enemy_bounds_key(enemy)]
    if bounds_name then
        return bounds_name
    end

    return short_id(enemy.Name)
end

local function get_enemy_anchor(enemy)
    local root_part = enemy and enemy:FindFirstChild("HumanoidRootPart")
    if not root_part then
        return nil
    end

    return {
        position = {
            x = root_part.Position.X,
            y = root_part.Position.Y,
            z = root_part.Position.Z
        },
        bounds_key = get_enemy_bounds_key(enemy)
    }
end

local function set_target_enemy(enemy)
    if not enemy then
        config.target_enemy_id = ""
        config.target_enemy_name = ""
        config.target_enemy_anchor = nil
        runtime.manual_target_selected = false
        return
    end

    config.target_enemy_id = enemy.Name
    config.target_enemy_name = get_enemy_display_name(enemy)
    config.target_enemy_anchor = get_enemy_anchor(enemy)
    runtime.manual_target_selected = true
end

local function move_to_enemy(enemy)
    if not enemy then
        return false
    end

    local root_part = enemy:FindFirstChild("HumanoidRootPart")
    if not root_part then
        return false
    end

    set_status("moving to " .. get_enemy_display_name(enemy))
    local moved = tween_to_cframe(root_part.CFrame)
    if moved then
        runtime.last_target_move_at = os.clock()
    end
    return moved
end

local function get_target_enemy()
    local enemies_folder = workspace:FindFirstChild("World")
    enemies_folder = enemies_folder and enemies_folder:FindFirstChild("Enemies")

    if config.target_enemy_id ~= "" and enemies_folder then
        local current_enemy = enemies_folder:FindFirstChild(config.target_enemy_id)
        if is_enemy_alive(current_enemy) then
            return current_enemy
        end

        config.target_enemy_id = ""
    end

    local alive_enemies = get_alive_enemies()
    local anchor = config.target_enemy_anchor
    local anchor_position = nil

    if anchor and anchor.position then
        anchor_position = Vector3.new(anchor.position.x, anchor.position.y, anchor.position.z)
        local best_enemy = nil
        local best_distance = math.huge

        for _, enemy in ipairs(alive_enemies) do
            local root_part = enemy:FindFirstChild("HumanoidRootPart")
            if root_part then
                local same_bounds = anchor.bounds_key == "" or get_enemy_bounds_key(enemy) == anchor.bounds_key
                if same_bounds then
                    local distance = (root_part.Position - anchor_position).Magnitude
                    if distance < best_distance then
                        best_distance = distance
                        best_enemy = enemy
                    end
                end
            end
        end

        if best_enemy then
            config.target_enemy_id = best_enemy.Name
            return best_enemy
        end
    end

    if config.target_enemy_name ~= "" then
        local best_named_enemy = nil
        local best_named_distance = math.huge

        for _, enemy in ipairs(alive_enemies) do
            if get_enemy_display_name(enemy) == config.target_enemy_name then
                if anchor_position then
                    local root_part = enemy:FindFirstChild("HumanoidRootPart")
                    if root_part then
                        local distance = (root_part.Position - anchor_position).Magnitude
                        if distance < best_named_distance then
                            best_named_distance = distance
                            best_named_enemy = enemy
                        end
                    end
                else
                    best_named_enemy = enemy
                    break
                end
            end
        end

        if best_named_enemy then
            config.target_enemy_id = best_named_enemy.Name
            return best_named_enemy
        end
    end

    return nil
end

local function retarget_current_enemy()
    if config.target_enemy_name == "" then
        set_status("select target npc")
        return false
    end

    local enemy = get_target_enemy()
    if not enemy then
        set_status("waiting " .. config.target_enemy_name)
        return false
    end

    set_target_enemy(enemy)
    local moved = move_to_enemy(enemy)
    if moved then
        set_status("retargeted " .. config.target_enemy_name)
    end
    return moved
end

local function reset_target_enemy()
    set_target_enemy(nil)
    runtime.last_target_enemy_id = ""
    runtime.last_target_move_at = 0
    refresh_warrior_list()
    set_status("target reset")
end

local function begin_click_target_selection()
    safe_disconnect(ui_refs.pick_target_connection)
    ui_refs.pick_target_connection = nil
    ui_refs.awaiting_target_click = true
    set_status("click npc to select target")

    local mouse = local_player:GetMouse()
    ui_refs.pick_target_connection = mouse.Button1Down:Connect(function()
        if not ui_refs.awaiting_target_click then
            return
        end

        ui_refs.awaiting_target_click = false
        local enemy = get_enemy_from_instance(mouse.Target)
        safe_disconnect(ui_refs.pick_target_connection)
        ui_refs.pick_target_connection = nil

        if not enemy or not is_enemy_alive(enemy) then
            set_status("invalid target click")
            return
        end

        set_target_enemy(enemy)
        refresh_warrior_list()
        set_status("selected target " .. config.target_enemy_name)
    end)
end

local function get_enemy_display_text(enemy)
    local enemy_name = get_enemy_display_name(enemy)
    local root_part = enemy:FindFirstChild("HumanoidRootPart")
    local position_text = "?,?"
    if root_part then
        position_text = string.format("%d,%d", math.floor(root_part.Position.X), math.floor(root_part.Position.Z))
    end

    local picked = config.target_enemy_name == enemy_name and "[x]" or "[ ]"
    return string.format("%s %s | %s", picked, enemy_name, position_text)
end

local function get_grouped_enemy_targets()
    local grouped = {}
    local ordered = {}
    local reference_position = runtime.root_part and runtime.root_part.Position or nil

    for _, enemy in ipairs(get_alive_enemies()) do
        local enemy_name = get_enemy_display_name(enemy)
        local root_part = enemy:FindFirstChild("HumanoidRootPart")
        local distance = math.huge

        if reference_position and root_part then
            distance = (root_part.Position - reference_position).Magnitude
        end

        local entry = grouped[enemy_name]
        if not entry then
            entry = {
                name = enemy_name,
                count = 0,
                enemy = enemy,
                distance = distance
            }
            grouped[enemy_name] = entry
            table.insert(ordered, entry)
        end

        entry.count += 1

        if distance < entry.distance then
            entry.distance = distance
            entry.enemy = enemy
        end
    end

    table.sort(ordered, function(left, right)
        if left.distance == right.distance then
            return left.name < right.name
        end

        return left.distance < right.distance
    end)

    return ordered
end

local function get_closest_enemy()
    if not runtime.root_part then
        return nil
    end

    local closest_enemy = nil
    local closest_distance = math.huge
    local root_position = runtime.root_part.Position

    for _, enemy in ipairs(get_alive_enemies()) do
        local enemy_root = enemy:FindFirstChild("HumanoidRootPart")
        if enemy_root then
            local distance = (enemy_root.Position - root_position).Magnitude
            if distance < closest_distance then
                closest_distance = distance
                closest_enemy = enemy
            end
        end
    end

    return closest_enemy
end

local function teleport_to_island(island_name)
    if not island_name or island_name == "" then
        return
    end

    local target_cframe = get_island_target_cframe(island_name)

    if not target_cframe then
        local spawn_points = get_spawn_points()
        target_cframe = spawn_points[island_name]
    end

    if target_cframe and runtime.root_part then
        set_status("tweening to " .. island_name)
        local success = tween_to_cframe(target_cframe)
        if success then
            set_status("arrived " .. island_name)
            return
        end
    end

    local success = safe_invoke(world_teleport_to_waystone, island_name)
    if success then
        set_status("waystone " .. island_name)
        return
    end

    set_status("tp failed " .. island_name)
end

local function step_auto_cycle_islands()
    if not config.auto_cycle_islands then
        return
    end

    local now = os.clock()
    if now - runtime.last_teleport < config.teleport_delay then
        return
    end

    local islands = get_selected_islands()
    if #islands == 0 then
        set_status("no selected islands")
        return
    end

    if runtime.island_index > #islands then
        runtime.island_index = 1
    end

    local island_name = islands[runtime.island_index]
    runtime.island_index += 1
    runtime.last_teleport = now

    teleport_to_island(island_name)
end

local last_equipment_check = 0
local function step_auto_farm()
    if not config.auto_farm then
        return
    end

    local now = os.clock()
    if now - last_equipment_check > 5 then
        last_equipment_check = now
        ensure_weapon_equipped()

        if config.auto_equip_selected then
            local equipped_ids = get_equipped_warrior_ids()
            local selected_ids = get_selected_warrior_ids()

            if #selected_ids > 0 then
                local matched = 0
                local equipped_lookup = {}

                for _, warrior_id in ipairs(equipped_ids) do
                    equipped_lookup[warrior_id] = true
                end

                for _, warrior_id in ipairs(selected_ids) do
                    if equipped_lookup[warrior_id] then
                        matched += 1
                    end
                end

                if matched == 0 then
                    equip_selected_warriors()
                    task.wait(0.5)
                end
            end
        end
    end

    if not runtime.manual_target_selected or config.target_enemy_name == "" then
        set_status("select target npc")
        return
    end

    local enemy = get_target_enemy()

    if not enemy then
        set_status("waiting " .. config.target_enemy_name)
        return
    end

    local enemy_root = enemy:FindFirstChild("HumanoidRootPart")
    local should_move_to_target = false

    if runtime.last_target_enemy_id ~= enemy.Name then
        runtime.last_target_enemy_id = enemy.Name
        should_move_to_target = true
    end

    if runtime.root_part and enemy_root then
        local distance = (runtime.root_part.Position - enemy_root.Position).Magnitude
        -- Tăng khoảng cách và thời gian chờ để giảm thiểu việc di chuyển liên tục gây giật
        if distance > 50 and os.clock() - runtime.last_target_move_at > 3 then
            should_move_to_target = true
        end
    end

    if should_move_to_target then
        move_to_enemy(enemy)
    end

    local selected_ids = get_equipped_warrior_ids()

    if #selected_ids == 0 then
        set_status("no warriors equipped")
        return
    end

    safe_fire(enemies_send_and_retreat, enemy.Name, selected_ids)

    for index = 1, #selected_ids do
        safe_fire(enemies_switch_enemy, selected_ids[index], enemy.Name)
    end

    set_status("all units farming " .. short_id(enemy.Name))
end

local function step_auto_open_egg()
    if not config.auto_open_egg then
        return
    end

    local now = os.clock()
    if now - runtime.last_egg_open < 1.2 then
        return
    end
    runtime.last_egg_open = now

    -- Anchor to prevent teleport from game scripts
    local old_anchored = false
    if runtime.root_part then
        old_anchored = runtime.root_part.Anchored
        runtime.root_part.Anchored = true
    end

    local success, result = safe_invoke(eggs_open, config.selected_egg, config.open_amount)
    
    -- Unanchor after a short delay
    task.delay(0.25, function()
        if runtime.root_part then
            runtime.root_part.Anchored = old_anchored
        end
    end)

    if success and result and typeof(result) == "table" then
        for _, unit_data in ipairs(result) do
            local unit_name = typeof(unit_data) == "table" and unit_data.name or unit_data
            if typeof(unit_name) ~= "string" then continue end
            
            local rarity = warrior_rarity_cache[unit_name] or "common"
            local min_rarity = config.webhook_rarity or "mythical"
            
            if rarity_order[rarity] >= rarity_order[min_rarity] then
                send_webhook(
                    "Unit Obtained! 🎉",
                    string.format("Player **%s** just obtained a **%s** (%s) from the **%s** egg!", 
                        local_player.Name, unit_name, string.upper(rarity), config.selected_egg),
                    rarity == "???" and 16711680 or 65535 -- Red for ???, Cyan/Blue for others
                )
            end
        end
    end
end

local function destroy_old_ui()
    local names = {
        "anime_warriors_iii_autofarm",
        "anime_warriors_status",
        "anime_warriors_toggle"
    }

    for index = 1, #names do
        local old_ui = core_gui:FindFirstChild(names[index])
        if old_ui then
            old_ui:Destroy()
        end
    end

    for _, descendant in ipairs(core_gui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text == "Anime Warriors III" then
            local root = descendant
            while root and root.Parent and not (root:IsA("ScreenGui") and root.Name == "ScreenGui") do
                root = root.Parent
            end

            if root and root:IsA("ScreenGui") and root.Parent == core_gui:FindFirstChild("RobloxGui") then
                pcall(function()
                    root:Destroy()
                end)
            end
        end
    end

    if ui_refs.window then
        pcall(function()
            ui_refs.window:Unload()
        end)
    end

    ui_refs.window = nil
    ui_refs.window_alive = nil
    ui_refs.status_control = nil
    ui_refs.target_dropdown = nil
    ui_refs.island_dropdown = nil
    ui_refs.target_lookup = nil
    ui_refs.awaiting_target_click = nil
    safe_disconnect(ui_refs.pick_target_connection)
    ui_refs.pick_target_connection = nil
    ui_refs.screen_gui = nil
    ui_refs.status_label = nil
    ui_refs.warrior_list = nil
    ui_refs.island_list = nil
end

local function make_button(parent, text, size, position)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(28, 36, 49)
    button.BorderSizePixel = 0
    button.Active = true
    button.Selectable = false
    button.TextColor3 = Color3.fromRGB(233, 240, 255)
    button.TextSize = 14
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.AutoButtonColor = true
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Parent = button
    stroke.Color = Color3.fromRGB(76, 102, 138)
    stroke.Thickness = 1.25

    return button
end

local function connect_button_click(button, callback)
    local busy = false

    button.MouseButton1Down:Connect(function()
        if busy then
            return
        end

        busy = true
        task.spawn(function()
            callback()
            task.wait(0.15)
            busy = false
        end)
    end)
end

local function clear_children(container)
    for _, child in ipairs(container:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local function call_first_method(control, method_names, ...)
    if not control then
        return false
    end

    for _, method_name in ipairs(method_names) do
        local method = control[method_name]
        if type(method) == "function" then
            local ok = pcall(method, control, ...)
            if ok then
                return true
            end
        end
    end

    return false
end

local function update_dropdown_options(control, options, selection)
    call_first_method(control, { "ClearOptions" })
    call_first_method(control, { "InsertOptions" }, options)

    if selection ~= nil then
        call_first_method(control, { "UpdateSelection", "SetValue", "Set" }, selection)
    end
end

local function refresh_warrior_list()
    if ui_refs.target_dropdown then
        local options = {}
        local enemy_lookup = {}
        local seen = {}

        for _, target in ipairs(get_grouped_enemy_targets()) do
            table.insert(options, target.name)
            enemy_lookup[target.name] = target.enemy
            seen[target.name] = true
        end

        if config.target_enemy_name ~= "" and not seen[config.target_enemy_name] then
            table.insert(options, 1, config.target_enemy_name)
        end

        ui_refs.target_lookup = enemy_lookup
        ui_refs.suppress_target_callback = true
        update_dropdown_options(ui_refs.target_dropdown, options, config.target_enemy_name ~= "" and config.target_enemy_name or nil)
        ui_refs.suppress_target_callback = nil
        return
    end

    if not ui_refs.warrior_list then
        return
    end

    clear_children(ui_refs.warrior_list)

    for _, target in ipairs(get_grouped_enemy_targets()) do
        local enemy = target.enemy
        local selected = config.target_enemy_name == target.name
        local button = make_button(
            ui_refs.warrior_list,
            string.format("[%s] %s x%d", selected and "x" or " ", target.name, target.count),
            UDim2.new(1, -8, 0, 28),
            UDim2.new()
        )

        button.BackgroundColor3 = selected and Color3.fromRGB(47, 129, 184) or Color3.fromRGB(28, 36, 49)
        button.TextXAlignment = Enum.TextXAlignment.Left

        connect_button_click(button, function()
            set_target_enemy(enemy)
            config.target_enemy_name = target.name
            move_to_enemy(enemy)
            refresh_warrior_list()
            set_status("target npc " .. target.name)
        end)
    end
end

local function refresh_island_list()
    if ui_refs.island_dropdown then
        update_dropdown_options(ui_refs.island_dropdown, get_island_names(), get_selected_islands())
        return
    end

    if not ui_refs.island_list then
        return
    end

    clear_children(ui_refs.island_list)

    for _, island_name in ipairs(get_island_names()) do
        local selected = config.selected_islands[island_name] == true
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 28)
        row.BackgroundTransparency = 1
        row.Active = true
        row.Parent = ui_refs.island_list

        local select_button = make_button(
            row,
            string.format("[%s] %s", selected and "x" or " ", island_name),
            UDim2.new(0.65, -4, 1, 0),
            UDim2.new(0, 0, 0, 0)
        )
        select_button.BackgroundColor3 = selected and Color3.fromRGB(50, 133, 95) or Color3.fromRGB(28, 36, 49)
        select_button.TextXAlignment = Enum.TextXAlignment.Left

        local teleport_button = make_button(
            row,
            "tp",
            UDim2.new(0.35, -4, 1, 0),
            UDim2.new(0.65, 4, 0, 0)
        )
        teleport_button.BackgroundColor3 = Color3.fromRGB(42, 92, 143)

        connect_button_click(select_button, function()
            config.selected_islands[island_name] = not config.selected_islands[island_name]
            refresh_island_list()
        end)

        connect_button_click(teleport_button, function()
            teleport_to_island(island_name)
        end)
    end
end

local function make_scroller(parent, size, position)
    local scroller = Instance.new("ScrollingFrame")
    scroller.Size = size
    scroller.Position = position
    scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroller.ScrollBarThickness = 4
    scroller.ScrollBarImageColor3 = Color3.fromRGB(82, 191, 255)
    scroller.BackgroundColor3 = Color3.fromRGB(17, 23, 33)
    scroller.BorderSizePixel = 0
    scroller.Active = true
    scroller.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = scroller

    local stroke = Instance.new("UIStroke")
    stroke.Parent = scroller
    stroke.Color = Color3.fromRGB(49, 63, 84)
    stroke.Thickness = 1.1

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = scroller

    return scroller
end

local function enable_drag(frame, drag_handle)
    local dragging = false
    local drag_start = nil
    local start_position = nil

    drag_handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            drag_start = input.Position
            start_position = frame.Position
        end
    end)

    drag_handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    table.insert(runtime.connections, user_input_service.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - drag_start
            frame.Position = UDim2.new(
                start_position.X.Scale,
                start_position.X.Offset + delta.X,
                start_position.Y.Scale,
                start_position.Y.Offset + delta.Y
            )
        end
    end))
end

local function build_ui_legacy()
    destroy_old_ui()
    ensure_default_selection()
    local blur = ensure_blur()

    local function protect_gui(gui)
        if syn and syn.protect_gui then
            pcall(function()
                syn.protect_gui(gui)
            end)
        end
        gui.Parent = core_gui
    end

    local screen_gui = Instance.new("ScreenGui")
    screen_gui.Name = "anime_warriors_iii_autofarm"
    screen_gui.ResetOnSpawn = false
    screen_gui.DisplayOrder = 20
    screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(screen_gui)
    ui_refs.screen_gui = screen_gui

    local status_gui = Instance.new("ScreenGui")
    status_gui.Name = "anime_warriors_status"
    status_gui.ResetOnSpawn = false
    status_gui.DisplayOrder = 10
    status_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(status_gui)

    local toggle_gui = Instance.new("ScreenGui")
    toggle_gui.Name = "anime_warriors_toggle"
    toggle_gui.ResetOnSpawn = false
    toggle_gui.DisplayOrder = 11
    toggle_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(toggle_gui)

    local status_holder = Instance.new("Frame")
    status_holder.Name = "status_holder"
    status_holder.Parent = status_gui
    status_holder.AnchorPoint = Vector2.new(0.5, 0.5)
    status_holder.BackgroundTransparency = 1
    status_holder.Position = UDim2.new(0.5, 0, 0.07, 0)
    status_holder.Size = UDim2.new(0, 430, 0, 64)

    local status_shadow = Instance.new("ImageLabel")
    status_shadow.Parent = status_holder
    status_shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    status_shadow.BackgroundTransparency = 1
    status_shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    status_shadow.Size = UDim2.new(1, 47, 1, 47)
    status_shadow.Image = "rbxassetid://6015897843"
    status_shadow.ImageColor3 = Color3.fromRGB(99, 67, 38)
    status_shadow.ImageTransparency = 0.72
    status_shadow.ScaleType = Enum.ScaleType.Slice
    status_shadow.SliceCenter = Rect.new(49, 49, 450, 450)

    local status_main = Instance.new("Frame")
    status_main.Parent = status_shadow
    status_main.AnchorPoint = Vector2.new(0.5, 0.5)
    status_main.Position = UDim2.new(0.5, 0, 0.5, 0)
    status_main.Size = UDim2.new(1, -52, 1, -54)
    status_main.BackgroundColor3 = Color3.fromRGB(250, 242, 229)
    status_main.BackgroundTransparency = 0.08
    status_main.BorderSizePixel = 0

    local status_corner = Instance.new("UICorner")
    status_corner.Parent = status_main
    status_corner.CornerRadius = UDim.new(0, 16)

    local status_stroke = Instance.new("UIStroke")
    status_stroke.Parent = status_main
    status_stroke.Color = Color3.fromRGB(221, 186, 132)
    status_stroke.Thickness = 1.6

    local status_top = Instance.new("TextLabel")
    status_top.Parent = status_main
    status_top.AnchorPoint = Vector2.new(0, 0)
    status_top.BackgroundTransparency = 1
    status_top.Position = UDim2.new(0, 16, 0, 10)
    status_top.Size = UDim2.new(0, 160, 0, 18)
    status_top.Font = Enum.Font.GothamBold
    status_top.Text = "Anime Warriors III"
    status_top.TextColor3 = Color3.fromRGB(126, 82, 32)
    status_top.TextSize = 15
    status_top.TextXAlignment = Enum.TextXAlignment.Left

    local status_label = Instance.new("TextLabel")
    status_label.Parent = status_main
    status_label.AnchorPoint = Vector2.new(0, 0)
    status_label.BackgroundTransparency = 1
    status_label.Position = UDim2.new(0, 16, 0, 30)
    status_label.Size = UDim2.new(1, -32, 0, 18)
    status_label.Font = Enum.Font.GothamBold
    status_label.Text = "Status: idle"
    status_label.TextColor3 = Color3.fromRGB(72, 51, 34)
    status_label.TextSize = 15
    status_label.TextXAlignment = Enum.TextXAlignment.Left
    ui_refs.status_label = status_label

    local status_sub = Instance.new("TextLabel")
    status_sub.Parent = status_main
    status_sub.AnchorPoint = Vector2.new(1, 0.5)
    status_sub.BackgroundTransparency = 1
    status_sub.Position = UDim2.new(1, -16, 0.5, 0)
    status_sub.Size = UDim2.new(0, 180, 0, 20)
    status_sub.Font = Enum.Font.GothamBold
    status_sub.Text = "waystone tween | sticky target"
    status_sub.TextColor3 = Color3.fromRGB(170, 122, 70)
    status_sub.TextSize = 12
    status_sub.TextXAlignment = Enum.TextXAlignment.Right

    local main_holder = Instance.new("Frame")
    main_holder.Parent = screen_gui
    main_holder.AnchorPoint = Vector2.new(0.5, 0.5)
    main_holder.BackgroundTransparency = 1
    main_holder.Position = UDim2.new(0.5, 0, 0.56, 0)
    main_holder.Size = UDim2.new(0, 860, 0, 520)
    main_holder.ZIndex = 1

    local shadow = Instance.new("ImageLabel")
    shadow.Parent = main_holder
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(1, 47, 1, 47)
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(118, 85, 45)
    shadow.ImageTransparency = 0.6

    local main = Instance.new("Frame")
    main.Parent = main_holder
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(1, -47, 1, -47)
    main.BackgroundColor3 = Color3.fromRGB(247, 240, 225)
    main.BackgroundTransparency = 0.02
    main.BorderSizePixel = 0

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 24)
    main_corner.Parent = main

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Parent = main
    main_stroke.Color = Color3.fromRGB(223, 195, 156)
    main_stroke.Thickness = 1.8

    local header_band = Instance.new("Frame")
    header_band.Parent = main
    header_band.BackgroundColor3 = Color3.fromRGB(236, 202, 144)
    header_band.BorderSizePixel = 0
    header_band.Size = UDim2.new(1, 0, 0, 92)

    local header_corner = Instance.new("UICorner")
    header_corner.Parent = header_band
    header_corner.CornerRadius = UDim.new(0, 24)

    local header_patch = Instance.new("Frame")
    header_patch.Parent = header_band
    header_patch.BackgroundColor3 = Color3.fromRGB(236, 202, 144)
    header_patch.BorderSizePixel = 0
    header_patch.Position = UDim2.new(0, 0, 1, -24)
    header_patch.Size = UDim2.new(1, 0, 0, 24)

    local chip = Instance.new("TextLabel")
    chip.Parent = header_band
    chip.BackgroundColor3 = Color3.fromRGB(255, 240, 212)
    chip.BorderSizePixel = 0
    chip.Position = UDim2.new(0, 24, 0, 18)
    chip.Size = UDim2.new(0, 94, 0, 28)
    chip.Font = Enum.Font.GothamBold
    chip.Text = "AUTO FARM"
    chip.TextColor3 = Color3.fromRGB(131, 84, 31)
    chip.TextSize = 12

    local chip_corner = Instance.new("UICorner")
    chip_corner.Parent = chip
    chip_corner.CornerRadius = UDim.new(0, 14)

    local chip_stroke = Instance.new("UIStroke")
    chip_stroke.Parent = chip
    chip_stroke.Color = Color3.fromRGB(229, 186, 116)
    chip_stroke.Thickness = 1

    local top_title = Instance.new("TextLabel")
    top_title.Parent = main
    top_title.BackgroundTransparency = 1
    top_title.Position = UDim2.new(0, 24, 0, 48)
    top_title.Size = UDim2.new(0, 430, 0, 24)
    top_title.Font = Enum.Font.GothamBold
    top_title.Text = "Anime Warriors III Desert Panel"
    top_title.TextColor3 = Color3.fromRGB(88, 55, 23)
    top_title.TextSize = 24
    top_title.TextXAlignment = Enum.TextXAlignment.Left

    local top_gradient = Instance.new("UIGradient")
    top_gradient.Parent = top_title
    top_gradient.Color = ColorSequence.new(Color3.fromRGB(153, 103, 48), Color3.fromRGB(221, 139, 47))

    local header_sub = Instance.new("TextLabel")
    header_sub.Parent = main
    header_sub.BackgroundTransparency = 1
    header_sub.Position = UDim2.new(0, 468, 0, 32)
    header_sub.Size = UDim2.new(0, 290, 0, 18)
    header_sub.Font = Enum.Font.GothamBold
    header_sub.Text = "farm controls + target npc + waystones"
    header_sub.TextColor3 = Color3.fromRGB(136, 93, 48)
    header_sub.TextSize = 12
    header_sub.TextXAlignment = Enum.TextXAlignment.Left

    local close_button = make_button(main, "hide", UDim2.new(0, 62, 0, 30), UDim2.new(1, -88, 0, 24))
    close_button.BackgroundColor3 = Color3.fromRGB(255, 232, 209)

    local left_panel = Instance.new("Frame")
    left_panel.Parent = main
    left_panel.Size = UDim2.new(0, 338, 0, 374)
    left_panel.Position = UDim2.new(0, 24, 0, 116)
    left_panel.BackgroundTransparency = 1

    local right_panel = Instance.new("Frame")
    right_panel.Parent = main
    right_panel.Size = UDim2.new(0, 404, 0, 374)
    right_panel.Position = UDim2.new(1, -428, 0, 116)
    right_panel.BackgroundTransparency = 1

    local left_card = Instance.new("Frame")
    left_card.Parent = left_panel
    left_card.Size = UDim2.new(1, 0, 1, 0)
    left_card.BackgroundColor3 = Color3.fromRGB(255, 250, 243)
    left_card.BorderSizePixel = 0

    local left_card_corner = Instance.new("UICorner")
    left_card_corner.Parent = left_card
    left_card_corner.CornerRadius = UDim.new(0, 20)

    local left_card_stroke = Instance.new("UIStroke")
    left_card_stroke.Parent = left_card
    left_card_stroke.Color = Color3.fromRGB(231, 214, 187)
    left_card_stroke.Thickness = 1.3

    local right_card = Instance.new("Frame")
    right_card.Parent = right_panel
    right_card.Size = UDim2.new(1, 0, 1, 0)
    right_card.BackgroundColor3 = Color3.fromRGB(255, 250, 243)
    right_card.BorderSizePixel = 0

    local right_card_corner = Instance.new("UICorner")
    right_card_corner.Parent = right_card
    right_card_corner.CornerRadius = UDim.new(0, 20)

    local right_card_stroke = Instance.new("UIStroke")
    right_card_stroke.Parent = right_card
    right_card_stroke.Color = Color3.fromRGB(231, 214, 187)
    right_card_stroke.Thickness = 1.3

    local left_strip = Instance.new("Frame")
    left_strip.Parent = left_card
    left_strip.BackgroundColor3 = Color3.fromRGB(255, 214, 151)
    left_strip.BorderSizePixel = 0
    left_strip.Size = UDim2.new(1, 0, 0, 8)

    local left_strip_corner = Instance.new("UICorner")
    left_strip_corner.Parent = left_strip
    left_strip_corner.CornerRadius = UDim.new(0, 20)

    local left_strip_fill = Instance.new("Frame")
    left_strip_fill.Parent = left_strip
    left_strip_fill.BackgroundColor3 = Color3.fromRGB(255, 214, 151)
    left_strip_fill.BorderSizePixel = 0
    left_strip_fill.Position = UDim2.new(0, 0, 0.5, 0)
    left_strip_fill.Size = UDim2.new(1, 0, 0.5, 0)

    local right_strip = Instance.new("Frame")
    right_strip.Parent = right_card
    right_strip.BackgroundColor3 = Color3.fromRGB(194, 225, 164)
    right_strip.BorderSizePixel = 0
    right_strip.Size = UDim2.new(1, 0, 0, 8)

    local right_strip_corner = Instance.new("UICorner")
    right_strip_corner.Parent = right_strip
    right_strip_corner.CornerRadius = UDim.new(0, 20)

    local right_strip_fill = Instance.new("Frame")
    right_strip_fill.Parent = right_strip
    right_strip_fill.BackgroundColor3 = Color3.fromRGB(194, 225, 164)
    right_strip_fill.BorderSizePixel = 0
    right_strip_fill.Position = UDim2.new(0, 0, 0.5, 0)
    right_strip_fill.Size = UDim2.new(1, 0, 0.5, 0)

    local left_panel_title = Instance.new("TextLabel")
    left_panel_title.Parent = left_card
    left_panel_title.BackgroundTransparency = 1
    left_panel_title.Position = UDim2.new(0, 18, 0, 18)
    left_panel_title.Size = UDim2.new(1, -36, 0, 22)
    left_panel_title.Font = Enum.Font.GothamBold
    left_panel_title.Text = "Farm Controls"
    left_panel_title.TextColor3 = Color3.fromRGB(82, 57, 36)
    left_panel_title.TextSize = 18
    left_panel_title.TextXAlignment = Enum.TextXAlignment.Left

    local left_panel_sub = Instance.new("TextLabel")
    left_panel_sub.Parent = left_card
    left_panel_sub.BackgroundTransparency = 1
    left_panel_sub.Position = UDim2.new(0, 18, 0, 42)
    left_panel_sub.Size = UDim2.new(1, -36, 0, 18)
    left_panel_sub.Font = Enum.Font.GothamMedium
    left_panel_sub.Text = "lock target npc, keep weapon equipped"
    left_panel_sub.TextColor3 = Color3.fromRGB(150, 117, 78)
    left_panel_sub.TextSize = 12
    left_panel_sub.TextXAlignment = Enum.TextXAlignment.Left

    local auto_farm_button = make_button(left_card, "Auto Farm: false", UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 18, 0, 74))
    local auto_cycle_button = make_button(left_card, "Auto Cycle: false", UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 0, 0, 74))
    local auto_equip_button = make_button(left_card, "Auto Equip: true", UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 18, 0, 118))
    local equip_now_button = make_button(left_card, "Equip Selected", UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 0, 0, 118))
    local retarget_button = make_button(left_card, "Retarget NPC", UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 18, 0, 162))
    local refresh_button = make_button(left_card, "Refresh Targets", UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 0, 0, 162))

    local warrior_title = Instance.new("TextLabel")
    warrior_title.Parent = left_card
    warrior_title.BackgroundTransparency = 1
    warrior_title.Position = UDim2.new(0, 18, 0, 214)
    warrior_title.Size = UDim2.new(1, -36, 0, 18)
    warrior_title.Font = Enum.Font.GothamBold
    warrior_title.Text = "Target NPCs"
    warrior_title.TextColor3 = Color3.fromRGB(82, 57, 36)
    warrior_title.TextSize = 15
    warrior_title.TextXAlignment = Enum.TextXAlignment.Left

    ui_refs.warrior_list = make_scroller(left_card, UDim2.new(1, -36, 1, -256), UDim2.new(0, 18, 0, 240))

    local right_panel_title = Instance.new("TextLabel")
    right_panel_title.Parent = right_card
    right_panel_title.BackgroundTransparency = 1
    right_panel_title.Position = UDim2.new(0, 18, 0, 18)
    right_panel_title.Size = UDim2.new(1, -36, 0, 22)
    right_panel_title.Font = Enum.Font.GothamBold
    right_panel_title.Text = "Waystone Islands"
    right_panel_title.TextColor3 = Color3.fromRGB(82, 57, 36)
    right_panel_title.TextSize = 18
    right_panel_title.TextXAlignment = Enum.TextXAlignment.Left

    local right_panel_sub = Instance.new("TextLabel")
    right_panel_sub.Parent = right_card
    right_panel_sub.BackgroundTransparency = 1
    right_panel_sub.Position = UDim2.new(0, 18, 0, 42)
    right_panel_sub.Size = UDim2.new(1, -36, 0, 18)
    right_panel_sub.Font = Enum.Font.GothamMedium
    right_panel_sub.Text = "choose islands and hop by waystone"
    right_panel_sub.TextColor3 = Color3.fromRGB(125, 124, 78)
    right_panel_sub.TextSize = 12
    right_panel_sub.TextXAlignment = Enum.TextXAlignment.Left

    local island_title = Instance.new("TextLabel")
    island_title.Parent = right_card
    island_title.BackgroundTransparency = 1
    island_title.Position = UDim2.new(0, 18, 0, 76)
    island_title.Size = UDim2.new(1, -36, 0, 18)
    island_title.Font = Enum.Font.GothamBold
    island_title.Text = "Selectable Islands"
    island_title.TextColor3 = Color3.fromRGB(82, 57, 36)
    island_title.TextSize = 15
    island_title.TextXAlignment = Enum.TextXAlignment.Left

    ui_refs.island_list = make_scroller(right_card, UDim2.new(1, -36, 0, 212), UDim2.new(0, 18, 0, 102))

    local next_island_button = make_button(right_card, "Teleport Next Selected", UDim2.new(1, -36, 0, 38), UDim2.new(0, 18, 0, 282))
    local spawn_button = make_button(right_card, "Teleport Spawn Point", UDim2.new(0.5, -12, 0, 38), UDim2.new(0, 18, 0, 328))
    local stop_button = make_button(right_card, "Stop All", UDim2.new(0.5, -12, 0, 38), UDim2.new(0.5, 0, 0, 328))
    stop_button.BackgroundColor3 = Color3.fromRGB(255, 215, 200)

    local toggle_frame = Instance.new("Frame")
    toggle_frame.Name = "toggle_frame"
    toggle_frame.Parent = toggle_gui
    toggle_frame.AnchorPoint = Vector2.new(0.1, 0.1)
    toggle_frame.Position = UDim2.new(0, 20, 0.1, -6)
    toggle_frame.Size = UDim2.new(0, 58, 0, 58)
    toggle_frame.BackgroundColor3 = Color3.fromRGB(255, 242, 222)
    toggle_frame.Active = true
    toggle_frame.Draggable = true

    local toggle_corner = Instance.new("UICorner")
    toggle_corner.CornerRadius = UDim.new(1, 0)
    toggle_corner.Parent = toggle_frame

    local toggle_stroke = Instance.new("UIStroke")
    toggle_stroke.Parent = toggle_frame
    toggle_stroke.Color = Color3.fromRGB(228, 194, 143)
    toggle_stroke.Thickness = 1.5

    local toggle_icon = Instance.new("ImageLabel")
    toggle_icon.Parent = toggle_frame
    toggle_icon.AnchorPoint = Vector2.new(0.5, 0.5)
    toggle_icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    toggle_icon.Size = UDim2.new(0, 40, 0, 40)
    toggle_icon.BackgroundTransparency = 1
    toggle_icon.Image = "rbxassetid://112485471724320"

    local toggle_button = Instance.new("TextButton")
    toggle_button.Parent = toggle_frame
    toggle_button.Size = UDim2.new(1, 0, 1, 0)
    toggle_button.BackgroundTransparency = 1
    toggle_button.Active = true
    toggle_button.Text = ""

    local zoomed_in = false
    local tween_info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fade_in = tween_service:Create(toggle_frame, tween_info, { BackgroundTransparency = 0.18 })
    local fade_out = tween_service:Create(toggle_frame, tween_info, { BackgroundTransparency = 0.02 })

    local function sync_buttons()
        auto_farm_button.Text = "Auto Farm: " .. tostring(config.auto_farm)
        auto_cycle_button.Text = "Auto Cycle: " .. tostring(config.auto_cycle_islands)
        auto_equip_button.Text = "Auto Equip: " .. tostring(config.auto_equip_selected)
    end

    local function set_hub_visible(state)
        main_holder.Visible = state
        status_holder.Visible = state
        blur.Size = state and 24 or 0
    end

    connect_button_click(close_button, function()
        set_hub_visible(false)
    end)

    toggle_button.MouseButton1Down:Connect(function()
        zoomed_in = not zoomed_in
        tween_service:Create(toggle_icon, tween_info, {
            Size = zoomed_in and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 40, 0, 40)
        }):Play()

        if main_holder.Visible then
            fade_in:Play()
            set_hub_visible(false)
        else
            fade_out:Play()
            set_hub_visible(true)
        end
    end)

    connect_button_click(auto_farm_button, function()
        config.auto_farm = not config.auto_farm
        sync_buttons()
    end)

    connect_button_click(auto_cycle_button, function()
        config.auto_cycle_islands = not config.auto_cycle_islands
        sync_buttons()
    end)

    connect_button_click(auto_equip_button, function()
        config.auto_equip_selected = not config.auto_equip_selected
        sync_buttons()
    end)

    connect_button_click(equip_now_button, function()
        equip_selected_warriors()
    end)

    connect_button_click(retarget_button, function()
        retarget_current_enemy()
    end)

    connect_button_click(refresh_button, function()
        refresh_warrior_list()
        refresh_island_list()
        set_status("lists refreshed")
    end)

    connect_button_click(next_island_button, function()
        local islands = get_selected_islands()
        if #islands == 0 then
            set_status("no selected islands")
            return
        end

        if runtime.island_index > #islands then
            runtime.island_index = 1
        end

        local island_name = islands[runtime.island_index]
        runtime.island_index += 1
        teleport_to_island(island_name)
    end)

    connect_button_click(spawn_button, function()
        local data = get_player_data()
        if data and data.spawnPoint then
            teleport_to_island(data.spawnPoint)
        end
    end)

    connect_button_click(stop_button, function()
        config.auto_farm = false
        config.auto_cycle_islands = false
        sync_buttons()
        set_status("stopped")
    end)

    sync_buttons()
    refresh_warrior_list()
    refresh_island_list()
    enable_drag(main_holder, main)
    set_hub_visible(true)
end

local function build_ui_fallback()
    destroy_old_ui()
    ensure_default_selection()
    local blur = ensure_blur()

    local function protect_gui(gui)
        if syn and syn.protect_gui then
            pcall(function()
                syn.protect_gui(gui)
            end)
        end
        gui.Parent = core_gui
    end

    local screen_gui = Instance.new("ScreenGui")
    screen_gui.Name = "anime_warriors_iii_autofarm"
    screen_gui.ResetOnSpawn = false
    screen_gui.DisplayOrder = 20
    screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(screen_gui)
    ui_refs.screen_gui = screen_gui

    local status_gui = Instance.new("ScreenGui")
    status_gui.Name = "anime_warriors_status"
    status_gui.ResetOnSpawn = false
    status_gui.DisplayOrder = 10
    status_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(status_gui)

    local toggle_gui = Instance.new("ScreenGui")
    toggle_gui.Name = "anime_warriors_toggle"
    toggle_gui.ResetOnSpawn = false
    toggle_gui.DisplayOrder = 11
    toggle_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(toggle_gui)

    local status_holder = Instance.new("Frame")
    status_holder.Name = "status_holder"
    status_holder.Parent = status_gui
    status_holder.AnchorPoint = Vector2.new(0.5, 0.5)
    status_holder.BackgroundTransparency = 1
    status_holder.Position = UDim2.new(0.5, 0, 0.08, 0)
    status_holder.Size = UDim2.new(0, 470, 0, 66)

    local status_shadow = Instance.new("ImageLabel")
    status_shadow.Parent = status_holder
    status_shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    status_shadow.BackgroundTransparency = 1
    status_shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    status_shadow.Size = UDim2.new(1, 47, 1, 47)
    status_shadow.Image = "rbxassetid://6015897843"
    status_shadow.ImageColor3 = Color3.fromRGB(6, 10, 18)
    status_shadow.ImageTransparency = 0.5
    status_shadow.ScaleType = Enum.ScaleType.Slice
    status_shadow.SliceCenter = Rect.new(49, 49, 450, 450)

    local status_main = Instance.new("Frame")
    status_main.Parent = status_shadow
    status_main.AnchorPoint = Vector2.new(0.5, 0.5)
    status_main.Position = UDim2.new(0.5, 0, 0.5, 0)
    status_main.Size = UDim2.new(1, -52, 1, -54)
    status_main.BackgroundColor3 = Color3.fromRGB(14, 19, 28)
    status_main.BackgroundTransparency = 0.04
    status_main.BorderSizePixel = 0

    local status_corner = Instance.new("UICorner")
    status_corner.Parent = status_main
    status_corner.CornerRadius = UDim.new(0, 16)

    local status_stroke = Instance.new("UIStroke")
    status_stroke.Parent = status_main
    status_stroke.Color = Color3.fromRGB(65, 116, 168)
    status_stroke.Thickness = 1.4

    local status_top = Instance.new("TextLabel")
    status_top.Parent = status_main
    status_top.BackgroundTransparency = 1
    status_top.Position = UDim2.new(0, 16, 0, 10)
    status_top.Size = UDim2.new(0, 160, 0, 18)
    status_top.Font = Enum.Font.GothamBold
    status_top.Text = "AW3 Control Grid"
    status_top.TextColor3 = Color3.fromRGB(121, 207, 255)
    status_top.TextSize = 14
    status_top.TextXAlignment = Enum.TextXAlignment.Left

    local status_label = Instance.new("TextLabel")
    status_label.Parent = status_main
    status_label.BackgroundTransparency = 1
    status_label.Position = UDim2.new(0, 16, 0, 30)
    status_label.Size = UDim2.new(1, -32, 0, 18)
    status_label.Font = Enum.Font.GothamBold
    status_label.Text = "status: idle"
    status_label.TextColor3 = Color3.fromRGB(236, 243, 255)
    status_label.TextSize = 15
    status_label.TextXAlignment = Enum.TextXAlignment.Left
    ui_refs.status_label = status_label

    local status_sub = Instance.new("TextLabel")
    status_sub.Parent = status_main
    status_sub.AnchorPoint = Vector2.new(1, 0.5)
    status_sub.BackgroundTransparency = 1
    status_sub.Position = UDim2.new(1, -16, 0.5, 0)
    status_sub.Size = UDim2.new(0, 220, 0, 20)
    status_sub.Font = Enum.Font.GothamBold
    status_sub.Text = "combat routing | island cycle | quick toggle"
    status_sub.TextColor3 = Color3.fromRGB(126, 145, 176)
    status_sub.TextSize = 12
    status_sub.TextXAlignment = Enum.TextXAlignment.Right

    local main_holder = Instance.new("Frame")
    main_holder.Parent = screen_gui
    main_holder.AnchorPoint = Vector2.new(0.5, 0.5)
    main_holder.BackgroundTransparency = 1
    main_holder.Position = UDim2.new(0.5, 0, 0.57, 0)
    main_holder.Size = UDim2.new(0, 940, 0, 560)
    main_holder.ZIndex = 1

    local shadow = Instance.new("ImageLabel")
    shadow.Parent = main_holder
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(1, 47, 1, 47)
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(6, 10, 18)
    shadow.ImageTransparency = 0.34

    local main = Instance.new("Frame")
    main.Parent = main_holder
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(1, -47, 1, -47)
    main.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    main.BackgroundTransparency = 0.02
    main.BorderSizePixel = 0

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 22)
    main_corner.Parent = main

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Parent = main
    main_stroke.Color = Color3.fromRGB(38, 59, 87)
    main_stroke.Thickness = 1.4

    local sidebar = Instance.new("Frame")
    sidebar.Parent = main
    sidebar.BackgroundColor3 = Color3.fromRGB(14, 20, 31)
    sidebar.BorderSizePixel = 0
    sidebar.Size = UDim2.new(0, 230, 1, 0)

    local sidebar_corner = Instance.new("UICorner")
    sidebar_corner.Parent = sidebar
    sidebar_corner.CornerRadius = UDim.new(0, 22)

    local sidebar_patch = Instance.new("Frame")
    sidebar_patch.Parent = sidebar
    sidebar_patch.BackgroundColor3 = Color3.fromRGB(14, 20, 31)
    sidebar_patch.BorderSizePixel = 0
    sidebar_patch.Position = UDim2.new(1, -22, 0, 0)
    sidebar_patch.Size = UDim2.new(0, 22, 1, 0)

    local sidebar_line = Instance.new("Frame")
    sidebar_line.Parent = sidebar
    sidebar_line.BackgroundColor3 = Color3.fromRGB(52, 109, 163)
    sidebar_line.BorderSizePixel = 0
    sidebar_line.Position = UDim2.new(1, -1, 0, 0)
    sidebar_line.Size = UDim2.new(0, 1, 1, 0)

    local nav_chip = Instance.new("TextLabel")
    nav_chip.Parent = sidebar
    nav_chip.BackgroundColor3 = Color3.fromRGB(28, 43, 66)
    nav_chip.BorderSizePixel = 0
    nav_chip.Position = UDim2.new(0, 18, 0, 20)
    nav_chip.Size = UDim2.new(0, 108, 0, 30)
    nav_chip.Font = Enum.Font.GothamBold
    nav_chip.Text = "CONTROL GRID"
    nav_chip.TextColor3 = Color3.fromRGB(132, 214, 255)
    nav_chip.TextSize = 11

    local nav_chip_corner = Instance.new("UICorner")
    nav_chip_corner.Parent = nav_chip
    nav_chip_corner.CornerRadius = UDim.new(0, 10)

    local nav_title = Instance.new("TextLabel")
    nav_title.Parent = sidebar
    nav_title.BackgroundTransparency = 1
    nav_title.Position = UDim2.new(0, 18, 0, 64)
    nav_title.Size = UDim2.new(1, -36, 0, 32)
    nav_title.Font = Enum.Font.GothamBold
    nav_title.Text = "Anime Warriors III"
    nav_title.TextColor3 = Color3.fromRGB(243, 247, 255)
    nav_title.TextSize = 22
    nav_title.TextWrapped = true
    nav_title.TextXAlignment = Enum.TextXAlignment.Left

    local nav_sub = Instance.new("TextLabel")
    nav_sub.Parent = sidebar
    nav_sub.BackgroundTransparency = 1
    nav_sub.Position = UDim2.new(0, 18, 0, 104)
    nav_sub.Size = UDim2.new(1, -36, 0, 40)
    nav_sub.Font = Enum.Font.GothamMedium
    nav_sub.Text = "New dashboard layout with streamlined controls."
    nav_sub.TextColor3 = Color3.fromRGB(133, 149, 173)
    nav_sub.TextSize = 12
    nav_sub.TextWrapped = true
    nav_sub.TextXAlignment = Enum.TextXAlignment.Left
    nav_sub.TextYAlignment = Enum.TextYAlignment.Top

    local nav_section = Instance.new("TextLabel")
    nav_section.Parent = sidebar
    nav_section.BackgroundTransparency = 1
    nav_section.Position = UDim2.new(0, 18, 0, 164)
    nav_section.Size = UDim2.new(1, -36, 0, 18)
    nav_section.Font = Enum.Font.GothamBold
    nav_section.Text = "QUICK ACTIONS"
    nav_section.TextColor3 = Color3.fromRGB(84, 192, 255)
    nav_section.TextSize = 12
    nav_section.TextXAlignment = Enum.TextXAlignment.Left

    local auto_farm_button = make_button(sidebar, "Auto Farm: false", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 194))
    local auto_cycle_button = make_button(sidebar, "Auto Cycle: false", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 238))
    local auto_equip_button = make_button(sidebar, "Auto Equip: true", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 282))
    local equip_now_button = make_button(sidebar, "Equip Selected", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 326))
    local retarget_button = make_button(sidebar, "Retarget NPC", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 370))
    local refresh_button = make_button(sidebar, "Refresh Lists", UDim2.new(1, -36, 0, 36), UDim2.new(0, 18, 0, 414))
    local stop_button = make_button(sidebar, "Stop All", UDim2.new(1, -36, 0, 40), UDim2.new(0, 18, 1, -58))
    stop_button.BackgroundColor3 = Color3.fromRGB(107, 46, 58)

    local content = Instance.new("Frame")
    content.Parent = main
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 248, 0, 18)
    content.Size = UDim2.new(1, -266, 1, -36)

    local header = Instance.new("Frame")
    header.Parent = content
    header.BackgroundColor3 = Color3.fromRGB(14, 20, 31)
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 86)

    local header_corner = Instance.new("UICorner")
    header_corner.Parent = header
    header_corner.CornerRadius = UDim.new(0, 18)

    local header_stroke = Instance.new("UIStroke")
    header_stroke.Parent = header
    header_stroke.Color = Color3.fromRGB(41, 66, 98)
    header_stroke.Thickness = 1.2

    local top_title = Instance.new("TextLabel")
    top_title.Parent = header
    top_title.BackgroundTransparency = 1
    top_title.Position = UDim2.new(0, 20, 0, 16)
    top_title.Size = UDim2.new(1, -160, 0, 26)
    top_title.Font = Enum.Font.GothamBold
    top_title.Text = "Target Router + Island Matrix"
    top_title.TextColor3 = Color3.fromRGB(241, 246, 255)
    top_title.TextSize = 24
    top_title.TextXAlignment = Enum.TextXAlignment.Left

    local header_sub = Instance.new("TextLabel")
    header_sub.Parent = header
    header_sub.BackgroundTransparency = 1
    header_sub.Position = UDim2.new(0, 20, 0, 46)
    header_sub.Size = UDim2.new(1, -180, 0, 18)
    header_sub.Font = Enum.Font.GothamMedium
    header_sub.Text = "Farm logic kept. Entire skin and layout rebuilt."
    header_sub.TextColor3 = Color3.fromRGB(131, 148, 173)
    header_sub.TextSize = 12
    header_sub.TextXAlignment = Enum.TextXAlignment.Left

    local close_button = make_button(header, "hide", UDim2.new(0, 92, 0, 34), UDim2.new(1, -112, 0, 24))
    close_button.BackgroundColor3 = Color3.fromRGB(31, 42, 58)

    local target_card = Instance.new("Frame")
    target_card.Parent = content
    target_card.BackgroundColor3 = Color3.fromRGB(14, 20, 31)
    target_card.BorderSizePixel = 0
    target_card.Position = UDim2.new(0, 0, 0, 104)
    target_card.Size = UDim2.new(1, 0, 0, 196)

    local target_card_corner = Instance.new("UICorner")
    target_card_corner.Parent = target_card
    target_card_corner.CornerRadius = UDim.new(0, 18)

    local target_card_stroke = Instance.new("UIStroke")
    target_card_stroke.Parent = target_card
    target_card_stroke.Color = Color3.fromRGB(41, 66, 98)
    target_card_stroke.Thickness = 1.2

    local target_title = Instance.new("TextLabel")
    target_title.Parent = target_card
    target_title.BackgroundTransparency = 1
    target_title.Position = UDim2.new(0, 18, 0, 14)
    target_title.Size = UDim2.new(1, -36, 0, 20)
    target_title.Font = Enum.Font.GothamBold
    target_title.Text = "Target NPCs"
    target_title.TextColor3 = Color3.fromRGB(240, 245, 255)
    target_title.TextSize = 18
    target_title.TextXAlignment = Enum.TextXAlignment.Left

    local target_sub = Instance.new("TextLabel")
    target_sub.Parent = target_card
    target_sub.BackgroundTransparency = 1
    target_sub.Position = UDim2.new(0, 18, 0, 36)
    target_sub.Size = UDim2.new(1, -36, 0, 16)
    target_sub.Font = Enum.Font.GothamMedium
    target_sub.Text = "Choose the NPC that all units will lock onto."
    target_sub.TextColor3 = Color3.fromRGB(126, 145, 176)
    target_sub.TextSize = 12
    target_sub.TextXAlignment = Enum.TextXAlignment.Left

    ui_refs.warrior_list = make_scroller(target_card, UDim2.new(1, -36, 1, -70), UDim2.new(0, 18, 0, 58))

    local island_card = Instance.new("Frame")
    island_card.Parent = content
    island_card.BackgroundColor3 = Color3.fromRGB(14, 20, 31)
    island_card.BorderSizePixel = 0
    island_card.Position = UDim2.new(0, 0, 0, 318)
    island_card.Size = UDim2.new(1, 0, 1, -318)

    local island_card_corner = Instance.new("UICorner")
    island_card_corner.Parent = island_card
    island_card_corner.CornerRadius = UDim.new(0, 18)

    local island_card_stroke = Instance.new("UIStroke")
    island_card_stroke.Parent = island_card
    island_card_stroke.Color = Color3.fromRGB(41, 66, 98)
    island_card_stroke.Thickness = 1.2

    local island_title = Instance.new("TextLabel")
    island_title.Parent = island_card
    island_title.BackgroundTransparency = 1
    island_title.Position = UDim2.new(0, 18, 0, 14)
    island_title.Size = UDim2.new(1, -36, 0, 20)
    island_title.Font = Enum.Font.GothamBold
    island_title.Text = "Waystone Islands"
    island_title.TextColor3 = Color3.fromRGB(240, 245, 255)
    island_title.TextSize = 18
    island_title.TextXAlignment = Enum.TextXAlignment.Left

    local island_sub = Instance.new("TextLabel")
    island_sub.Parent = island_card
    island_sub.BackgroundTransparency = 1
    island_sub.Position = UDim2.new(0, 18, 0, 36)
    island_sub.Size = UDim2.new(1, -36, 0, 16)
    island_sub.Font = Enum.Font.GothamMedium
    island_sub.Text = "Select islands for cycling, or teleport to one directly."
    island_sub.TextColor3 = Color3.fromRGB(126, 145, 176)
    island_sub.TextSize = 12
    island_sub.TextXAlignment = Enum.TextXAlignment.Left

    ui_refs.island_list = make_scroller(island_card, UDim2.new(1, -36, 1, -118), UDim2.new(0, 18, 0, 58))

    local next_island_button = make_button(island_card, "Teleport Next Selected", UDim2.new(0.5, -8, 0, 38), UDim2.new(0, 18, 1, -56))
    local spawn_button = make_button(island_card, "Teleport Spawn Point", UDim2.new(0.5, -8, 0, 38), UDim2.new(0.5, -10, 1, -56))
    spawn_button.BackgroundColor3 = Color3.fromRGB(35, 77, 121)

    local toggle_frame = Instance.new("Frame")
    toggle_frame.Name = "toggle_frame"
    toggle_frame.Parent = toggle_gui
    toggle_frame.AnchorPoint = Vector2.new(0.1, 0.1)
    toggle_frame.Position = UDim2.new(0, 20, 0.1, -6)
    toggle_frame.Size = UDim2.new(0, 58, 0, 58)
    toggle_frame.BackgroundColor3 = Color3.fromRGB(15, 22, 33)
    toggle_frame.Active = true
    toggle_frame.Draggable = true

    local toggle_corner = Instance.new("UICorner")
    toggle_corner.CornerRadius = UDim.new(1, 0)
    toggle_corner.Parent = toggle_frame

    local toggle_stroke = Instance.new("UIStroke")
    toggle_stroke.Parent = toggle_frame
    toggle_stroke.Color = Color3.fromRGB(60, 107, 156)
    toggle_stroke.Thickness = 1.25

    local toggle_icon = Instance.new("ImageLabel")
    toggle_icon.Parent = toggle_frame
    toggle_icon.AnchorPoint = Vector2.new(0.5, 0.5)
    toggle_icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    toggle_icon.Size = UDim2.new(0, 40, 0, 40)
    toggle_icon.BackgroundTransparency = 1
    toggle_icon.Image = "rbxassetid://112485471724320"

    local toggle_button = Instance.new("TextButton")
    toggle_button.Parent = toggle_frame
    toggle_button.Size = UDim2.new(1, 0, 1, 0)
    toggle_button.BackgroundTransparency = 1
    toggle_button.Active = true
    toggle_button.Text = ""

    local zoomed_in = false
    local tween_info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fade_in = tween_service:Create(toggle_frame, tween_info, { BackgroundTransparency = 0.18 })
    local fade_out = tween_service:Create(toggle_frame, tween_info, { BackgroundTransparency = 0.02 })

    local function sync_buttons()
        auto_farm_button.Text = "Auto Farm: " .. tostring(config.auto_farm)
        auto_cycle_button.Text = "Auto Cycle: " .. tostring(config.auto_cycle_islands)
        auto_equip_button.Text = "Auto Equip: " .. tostring(config.auto_equip_selected)
    end

    local function set_hub_visible(state)
        main_holder.Visible = state
        status_holder.Visible = state
        blur.Size = state and 24 or 0
    end

    connect_button_click(close_button, function()
        set_hub_visible(false)
    end)

    toggle_button.MouseButton1Down:Connect(function()
        zoomed_in = not zoomed_in
        tween_service:Create(toggle_icon, tween_info, {
            Size = zoomed_in and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 40, 0, 40)
        }):Play()

        if main_holder.Visible then
            fade_in:Play()
            set_hub_visible(false)
        else
            fade_out:Play()
            set_hub_visible(true)
        end
    end)

    connect_button_click(auto_farm_button, function()
        config.auto_farm = not config.auto_farm
        sync_buttons()
    end)

    connect_button_click(auto_cycle_button, function()
        config.auto_cycle_islands = not config.auto_cycle_islands
        sync_buttons()
    end)

    connect_button_click(auto_equip_button, function()
        config.auto_equip_selected = not config.auto_equip_selected
        sync_buttons()
    end)

    connect_button_click(equip_now_button, function()
        equip_selected_warriors()
    end)

    connect_button_click(retarget_button, function()
        retarget_current_enemy()
    end)

    connect_button_click(refresh_button, function()
        refresh_warrior_list()
        refresh_island_list()
        set_status("lists refreshed")
    end)

    connect_button_click(next_island_button, function()
        local islands = get_selected_islands()
        if #islands == 0 then
            set_status("no selected islands")
            return
        end

        if runtime.island_index > #islands then
            runtime.island_index = 1
        end

        local island_name = islands[runtime.island_index]
        runtime.island_index += 1
        teleport_to_island(island_name)
    end)

    connect_button_click(spawn_button, function()
        local data = get_player_data()
        if data and data.spawnPoint then
            teleport_to_island(data.spawnPoint)
        end
    end)

    connect_button_click(stop_button, function()
        config.auto_farm = false
        config.auto_cycle_islands = false
        sync_buttons()
        set_status("stopped")
    end)

    sync_buttons()
    refresh_warrior_list()
    refresh_island_list()
    enable_drag(main_holder, header)
    set_hub_visible(true)
end

local function build_ui()
    destroy_old_ui()
    ensure_default_selection()
    local WMacLib = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Wicikk/WMacLib/main/WMacLib.lua"))()
    local window = WMacLib:Window({
        Title = "Anime Warriors III",
        Subtitle = "WMacLib control panel",
        Size = UDim2.fromOffset(760, 540),
        DragStyle = 1,
        DisabledWindowControls = {},
        ShowUserInfo = true,
        Keybind = Enum.KeyCode.RightControl,
        AcrylicBlur = true,
    })

    WMacLib:SetFolder("AnimeWarriorsIII")

    ui_refs.window = window
    ui_refs.window_alive = true

    local groups = {
        main = window:TabGroup()
    }

    local tabs = {
        farm = groups.main:Tab({ Name = "Farm", Image = "lucide/layout-dashboard" }),
    }
    groups.main:Divider()
    tabs.routing = groups.main:Tab({ Name = "Routing", Image = "lucide/map-pinned" })
    tabs.summon = groups.main:Tab({ Name = "Summoning", Image = "lucide/sparkles" })
    tabs.tuning = groups.main:Tab({ Name = "Tuning", Image = "lucide/sliders-horizontal" })
    tabs.misc = groups.main:Tab({ Name = "Misc", Image = "lucide/settings" })
    tabs.config = groups.main:Tab({ Name = "Config", Image = "lucide/folder-cog" })

    local farm_left = tabs.farm:Section({})
    local farm_right = tabs.farm:Section({ Side = "Right" })

    farm_left:Header({
        Name = WMacLib:Gradient("Combat Controls", Color3.fromRGB(73, 230, 133), Color3.fromRGB(100, 150, 255))
    })

    ui_refs.status_control = farm_left:Label({
        Text = "Status: idle",
        Bold = true,
    })

    farm_left:Paragraph({
        Header = "Mode",
        Body = "Sticky target farming with island cycling and weapon upkeep."
    })

    farm_left:Toggle({
        Name = "Auto Farm",
        Default = config.auto_farm,
        Callback = function(value)
            config.auto_farm = value
            set_status((value and "enabled " or "disabled ") .. "auto farm")
        end,
    }, "AutoFarm")

    farm_left:Toggle({
        Name = "Auto Cycle Islands",
        Default = config.auto_cycle_islands,
        Callback = function(value)
            config.auto_cycle_islands = value
            set_status((value and "enabled " or "disabled ") .. "island cycle")
        end,
    }, "AutoCycleIslands")

    farm_left:Toggle({
        Name = "Auto Equip Selected",
        Default = config.auto_equip_selected,
        Callback = function(value)
            config.auto_equip_selected = value
        end,
    }, "AutoEquipSelected")

    farm_left:Toggle({
        Name = "Auto Equip Weapon",
        Default = config.auto_equip_weapon,
        Callback = function(value)
            config.auto_equip_weapon = value
        end,
    }, "AutoEquipWeapon")

    farm_left:Button({
        Name = "Equip Selected Now",
        Callback = function()
            equip_selected_warriors()
        end,
    })

    farm_left:Button({
        Name = "Retarget Current NPC",
        Callback = function()
            retarget_current_enemy()
        end,
    })

    farm_left:Button({
        Name = "Click NPC To Select",
        Callback = function()
            begin_click_target_selection()
        end,
    })

    farm_left:Button({
        Name = "Reset Target",
        Callback = function()
            reset_target_enemy()
        end,
    })

    farm_left:Button({
        Name = "Stop All",
        Callback = function()
            config.auto_farm = false
            config.auto_cycle_islands = false
            set_status("stopped")
        end,
    })

    farm_right:Header({
        Name = WMacLib:Gradient("Target NPC", Color3.fromRGB(122, 196, 255), Color3.fromRGB(88, 120, 255))
    })

    local target_dropdown = farm_right:Dropdown({
        Name = "Enemy Group",
        Search = true,
        Multi = false,
        Required = false,
        Options = {},
        Callback = function(value)
            if ui_refs.suppress_target_callback then
                return
            end

            if type(value) ~= "string" or value == "" then
                return
            end

            local enemy = ui_refs.target_lookup and ui_refs.target_lookup[value] or nil
            if enemy then
                set_target_enemy(enemy)
                config.target_enemy_name = value
                set_status("selected target " .. value)
            end
        end,
    }, "TargetNPC")
    ui_refs.target_dropdown = target_dropdown

    farm_right:Button({
        Name = "Refresh Targets",
        Callback = function()
            refresh_warrior_list()
            refresh_island_list()
            set_status("lists refreshed")
        end,
    })

    local routing_left = tabs.routing:Section({})
    local routing_right = tabs.routing:Section({ Side = "Right" })

    routing_left:Header({
        Name = WMacLib:Gradient("Routing", Color3.fromRGB(255, 180, 50), Color3.fromRGB(255, 80, 80))
    })

    routing_left:Label({
        Text = "Island cycle and teleport controls.",
    })

    routing_right:Header({
        Name = WMacLib:Gradient("Islands", Color3.fromRGB(73, 230, 133), Color3.fromRGB(255, 180, 50))
    })

    local island_dropdown = routing_right:Dropdown({
        Name = "Cycle Islands",
        Search = true,
        Multi = true,
        Required = false,
        Options = {},
        Default = {},
        Callback = function(value)
            local selected_lookup = {}

            if type(value) == "table" then
                for island_name, state in next, value do
                    if state then
                        selected_lookup[island_name] = true
                    end
                end
            end

            config.selected_islands = selected_lookup
        end,
    }, "SelectedIslands")
    ui_refs.island_dropdown = island_dropdown

    routing_right:Dropdown({
        Name = "Teleport To Island",
        Search = true,
        Multi = false,
        Required = false,
        Options = get_island_names(),
        Callback = function(value)
            if type(value) == "string" and value ~= "" then
                teleport_to_island(value)
            end
        end,
    }, "TeleportIsland")

    routing_right:Button({
        Name = "Teleport Next Selected",
        Callback = function()
            local islands = get_selected_islands()
            if #islands == 0 then
                set_status("no selected islands")
                return
            end

            if runtime.island_index > #islands then
                runtime.island_index = 1
            end

            local island_name = islands[runtime.island_index]
            runtime.island_index += 1
            teleport_to_island(island_name)
        end,
    })

    routing_right:Button({
        Name = "Teleport Spawn Point",
        Callback = function()
            local data = get_player_data()
            if data and data.spawnPoint then
                teleport_to_island(data.spawnPoint)
            end
        end,
    })

    local summon_left = tabs.summon:Section({})
    local summon_right = tabs.summon:Section({ Side = "Right" })

    summon_left:Header({
        Name = WMacLib:Gradient("Auto Summon", Color3.fromRGB(255, 100, 255), Color3.fromRGB(150, 100, 255))
    })

    summon_left:Toggle({
        Name = "Enable Auto Open",
        Default = config.auto_open_egg,
        Callback = function(value)
            config.auto_open_egg = value
        end,
    }, "AutoOpenEgg")

    summon_left:Dropdown({
        Name = "Select Egg",
        Options = {"Nemak", "Corps", "Ninja", "Sky"},
        Default = config.selected_egg,
        Callback = function(value)
            config.selected_egg = value
        end,
    }, "SelectedEgg")

    summon_left:Dropdown({
        Name = "Open Amount",
        Options = {"1", "3"},
        Default = tostring(config.open_amount),
        Callback = function(value)
            config.open_amount = tonumber(value)
        end,
    }, "OpenAmount")

    summon_right:Header({
        Name = WMacLib:Gradient("Webhook Notifications", Color3.fromRGB(100, 255, 255), Color3.fromRGB(100, 150, 255))
    })

    summon_right:Toggle({
        Name = "Enable Webhook",
        Default = config.webhook_enabled,
        Callback = function(value)
            config.webhook_enabled = value
        end,
    }, "WebhookEnabled")

    summon_right:Input({
        Name = "Webhook URL",
        Default = config.webhook_url,
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(value)
            config.webhook_url = value
        end,
    }, "WebhookURL")

    summon_right:Dropdown({
        Name = "Min Rarity Notify",
        Options = {"common", "rare", "epic", "legendary", "mythical", "exclusive", "???"},
        Default = config.webhook_rarity,
        Callback = function(value)
            config.webhook_rarity = value
        end,
    }, "WebhookRarity")

    local tuning = tabs.tuning:Section({})
    tuning:Header({
        Name = WMacLib:Gradient("Timing And Movement", Color3.fromRGB(255, 160, 90), Color3.fromRGB(255, 100, 140))
    })

    tuning:Slider({
        Name = "Farm Delay",
        Default = math.floor(config.farm_delay * 100),
        Minimum = 5,
        Maximum = 100,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            config.farm_delay = value / 100
        end,
    }, "FarmDelay")

    tuning:Slider({
        Name = "Teleport Delay",
        Default = math.floor(config.teleport_delay),
        Minimum = 3,
        Maximum = 60,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            config.teleport_delay = value
        end,
    }, "TeleportDelay")

    tuning:Slider({
        Name = "Tween Speed",
        Default = math.floor(config.tween_speed),
        Minimum = 50,
        Maximum = 500,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            config.tween_speed = value
        end,
    }, "TweenSpeed")

    tuning:Slider({
        Name = "Tween Height",
        Default = math.floor(config.tween_height),
        Minimum = 0,
        Maximum = 20,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            config.tween_height = value
        end,
    }, "TweenHeight")

    local misc = tabs.misc:Section({})
    misc:Header({
        Name = WMacLib:Gradient("Performance & Utils", Color3.fromRGB(150, 150, 255), Color3.fromRGB(100, 100, 255))
    })

    misc:Toggle({
        Name = "Anti-AFK",
        Default = config.anti_afk,
        Callback = function(value)
            config.anti_afk = value
        end,
    }, "AntiAFK")

    misc:Toggle({
        Name = "No Render (CPU Saver)",
        Default = config.no_render,
        Callback = function(value)
            config.no_render = value
            run_service:Set3dRenderingEnabled(not value)
        end,
    }, "NoRender")

    misc:Header({
        Text = "Window"
    })

    misc:Toggle({
        Name = "Acrylic Blur",
        Default = window:GetAcrylicBlurState(),
        Callback = function(value)
            window:SetAcrylicBlurState(value)
        end,
    })

    misc:Toggle({
        Name = "Notifications",
        Default = window:GetNotificationsState(),
        Callback = function(value)
            window:SetNotificationsState(value)
        end,
    })

    misc:Toggle({
        Name = "Show User Info",
        Default = window:GetUserInfoState(),
        Callback = function(value)
            window:SetUserInfoState(value)
        end,
    })

    misc:Button({
        Name = "Unload UI",
        Callback = function()
            window:Unload()
        end,
    })

    tabs.config:InsertConfigSection()

    window.onUnloaded(function()
        ui_refs.window_alive = false
    end)

    refresh_warrior_list()
    refresh_island_list()
    tabs.farm:Select()
    WMacLib:LoadAutoLoadConfig()
end

build_ui()

task.spawn(function()
    while runtime.running do
        step_auto_cycle_islands()
        step_auto_farm()
        step_auto_open_egg()
        task.wait(config.farm_delay)
    end
end)

task.spawn(function()
    while runtime.running do
        if ui_refs.window_alive == false then
            runtime.running = false
            break
        end

        task.wait(1)
    end
end)

return {
    refresh_warrior_list = refresh_warrior_list,
    refresh_island_list = refresh_island_list,
    equip_selected_warriors = equip_selected_warriors,
    teleport_to_island = teleport_to_island
}
