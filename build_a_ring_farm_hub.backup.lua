local SCRIPT_NAME = "Build A Ring Farm Hub"
local SCRIPT_TAG = "BuildARingFarmHub"
local VERSION = "3.0"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemotesRoot = ReplicatedStorage:WaitForChild("Remotes")
local SharedRoot = ReplicatedStorage:WaitForChild("Shared")
local RegistryModule = SharedRoot:WaitForChild("Registry")

local RUNTIME_KEY = SCRIPT_TAG .. "_Runtime"
local CONFIG_KEY = SCRIPT_TAG .. "_Config"
local INSTANCE_COUNTER_KEY = SCRIPT_TAG .. "_InstanceId"
local GUI_NAME = SCRIPT_TAG .. "UI"

local previous_runtime = getgenv()[RUNTIME_KEY]
if type(previous_runtime) == "table" then
    previous_runtime.running = false
    if type(previous_runtime.stop) == "function" then
        pcall(previous_runtime.stop, "reload")
    end
    task.wait(0.15)
end

getgenv()[INSTANCE_COUNTER_KEY] = (getgenv()[INSTANCE_COUNTER_KEY] or 0) + 1
local INSTANCE_ID = getgenv()[INSTANCE_COUNTER_KEY]

local function merge_defaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            merge_defaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local DEFAULT_CONFIG = {
    AutoSell = true,
    AutoClaimDaily = true,
    AutoBuyEggs = false,
    AutoBuyGears = false,
    AutoRollSeeds = true,
    AutoCompost = false,
    AutoEvents = true,
    TargetRarities = {
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = true,
        Secret = true,
        Divine = true,
        Exotic = true,
        Prismatic = true,
        Transcended = true,
    },
}

local config = merge_defaults(getgenv()[CONFIG_KEY] or {}, DEFAULT_CONFIG)
getgenv()[CONFIG_KEY] = config

local RARITY_ORDER = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Secret",
    "Divine",
    "Exotic",
    "Prismatic",
    "Transcended",
}

local REMOTES = {
    GetPlot = RemotesRoot:FindFirstChild("Plot") and RemotesRoot.Plot:FindFirstChild("GetPlot"),
    SellCrates = RemotesRoot:FindFirstChild("SellCrates"),
    UpdateDailyRewards = RemotesRoot:FindFirstChild("UpdateDailyRewards"),
    EggTransaction = RemotesRoot:FindFirstChild("EggShop") and RemotesRoot.EggShop:FindFirstChild("Transaction"),
    RollEgg = RemotesRoot:FindFirstChild("RollEgg"),
    GearTransaction = RemotesRoot:FindFirstChild("Gear") and RemotesRoot.Gear:FindFirstChild("Transaction"),
    BuySeed = RemotesRoot:FindFirstChild("BuySeed"),
    RollSeeds = RemotesRoot:FindFirstChild("RollSeeds"),
    ComposterRequestState = RemotesRoot:FindFirstChild("Composter") and RemotesRoot.Composter:FindFirstChild("RequestState"),
    ComposterPullLever = RemotesRoot:FindFirstChild("Composter") and RemotesRoot.Composter:FindFirstChild("PullLever"),
    ComposterInsertSeed = RemotesRoot:FindFirstChild("Composter") and RemotesRoot.Composter:FindFirstChild("InsertSeed"),
    PlantRushShoot = RemotesRoot:FindFirstChild("PlantRush") and RemotesRoot.PlantRush:FindFirstChild("Shoot"),
    PlantRushHit = RemotesRoot:FindFirstChild("PlantRush") and RemotesRoot.PlantRush:FindFirstChild("PlantHit"),
}

local runtime = {
    id = INSTANCE_ID,
    running = true,
    status = "Booting",
    last_error = nil,
    jobs = {},
    connections = {},
    ui = {
        screen_gui = nil,
        main = nil,
        mini = nil,
        status_label = nil,
        stat_labels = {},
    },
    metrics = {
        sells = 0,
        daily_claims = 0,
        seed_rolls = 0,
        seed_buys = 0,
        egg_buys = 0,
        gear_buys = 0,
        compost_pulls = 0,
        event_actions = 0,
        errors = 0,
    },
    event = {
        active = false,
        return_cframe = nil,
    },
    seed = {
        last_roll_at = 0,
        recent_buys = {},
    },
    cache = {
        plot = nil,
        replica = nil,
        last_replica_scan = 0,
        seed_slots_ref = nil,
        last_seed_scan = 0,
        modules = {
            shared_registry = nil,
            gear_registry = nil,
            egg_config = nil,
            compost_config = nil,
        },
    },
}

getgenv()[RUNTIME_KEY] = runtime

local function is_current_instance()
    return runtime.running and getgenv()[INSTANCE_COUNTER_KEY] == INSTANCE_ID
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(runtime.connections, connection)
    return connection
end

local function disconnect_all()
    for _, connection in ipairs(runtime.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    runtime.connections = {}
end

local function log(message)
    print(("[%s] %s"):format(SCRIPT_NAME, message))
end

local function set_status(text)
    runtime.status = text
    if runtime.ui.status_label then
        runtime.ui.status_label.Text = "Status: " .. text
    end
end

local function track_error(source, err)
    runtime.metrics.errors = runtime.metrics.errors + 1
    runtime.last_error = {
        source = source,
        message = tostring(err),
        time = os.clock(),
    }
    log(("Error in %s: %s"):format(source, tostring(err)))
    set_status(("Error in %s"):format(source))
end

local function run_safe(source, callback)
    if not is_current_instance() then
        return
    end

    local ok, err = pcall(callback)
    if not ok then
        track_error(source, err)
    end
end

local function get_gui_parent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and typeof(result) == "Instance" then
            return result
        end
    end
    return CoreGui
end

local function protect_gui(gui)
    if syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    elseif type(protectgui) == "function" then
        pcall(protectgui, gui)
    end
end

local function cleanup_existing_ui()
    local candidates = { get_gui_parent(), CoreGui, PlayerGui }
    local seen = {}
    for _, container in ipairs(candidates) do
        if container and not seen[container] then
            seen[container] = true
            local existing = container:FindFirstChild(GUI_NAME)
            if existing then
                pcall(function()
                    existing:Destroy()
                end)
            end
        end
    end
end

local function stop_runtime(reason)
    if not runtime.running then
        return
    end

    runtime.running = false
    disconnect_all()

    local screen_gui = runtime.ui.screen_gui
    runtime.ui = {
        screen_gui = nil,
        main = nil,
        mini = nil,
        status_label = nil,
        stat_labels = {},
    }

    if screen_gui then
        pcall(function()
            screen_gui:Destroy()
        end)
    end

    if getgenv()[RUNTIME_KEY] == runtime then
        getgenv()[RUNTIME_KEY] = nil
    end

    if reason then
        log("Stopped: " .. tostring(reason))
    end
end

runtime.stop = stop_runtime

local function safe_require(module_instance)
    if not module_instance then
        return nil
    end

    local ok, result = pcall(require, module_instance)
    if ok then
        return result
    end

    return nil
end

local function resolve_modules()
    local modules = runtime.cache.modules

    if modules.shared_registry == nil then
        modules.shared_registry = safe_require(RegistryModule)
    end

    if modules.gear_registry == nil then
        modules.gear_registry = safe_require(RegistryModule:FindFirstChild("Gear"))
    end

    if modules.egg_config == nil then
        modules.egg_config = safe_require(SharedRoot:FindFirstChild("EggConfig"))
    end

    if modules.compost_config == nil then
        modules.compost_config = safe_require(SharedRoot:FindFirstChild("CompostConfig"))
    end

    return modules
end

local function get_replica()
    local cached = runtime.cache.replica
    if type(cached) == "table" and type(cached.Data) == "table" then
        return cached
    end

    local now = os.clock()
    if now - runtime.cache.last_replica_scan < 5 then
        return nil
    end
    runtime.cache.last_replica_scan = now

    local player_scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local client_loader = player_scripts and player_scripts:FindFirstChild("ClientLoader")
    local modules_folder = client_loader and client_loader:FindFirstChild("Modules")
    local replica_client_module = modules_folder and modules_folder:FindFirstChild("ReplicaClient")
    if not replica_client_module then
        return nil
    end

    local replica_client = safe_require(replica_client_module)
    if type(replica_client) ~= "table" or type(replica_client.FromId) ~= "function" then
        return nil
    end

    local ok, upvalues = pcall(debug.getupvalues, replica_client.FromId)
    if not ok or type(upvalues) ~= "table" then
        return nil
    end

    for _, upvalue in pairs(upvalues) do
        if type(upvalue) == "table" then
            for _, candidate in pairs(upvalue) do
                if type(candidate) == "table" and type(candidate.Data) == "table" and candidate.Data.Cash ~= nil then
                    runtime.cache.replica = candidate
                    return candidate
                end
            end
        end
    end

    return nil
end

local function get_replica_data()
    local replica = get_replica()
    if replica then
        return replica.Data
    end
    return nil
end

local function get_plot()
    local cached = runtime.cache.plot
    if cached and cached.Parent then
        return cached
    end

    if not REMOTES.GetPlot then
        return nil
    end

    local ok, plot = pcall(function()
        return REMOTES.GetPlot:InvokeServer()
    end)
    if ok and plot then
        runtime.cache.plot = plot
        return plot
    end

    return nil
end

local function get_character()
    return LocalPlayer.Character
end

local function get_humanoid_root_part()
    local character = get_character()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function fire_remote(remote, ...)
    if not remote then
        return false
    end

    local args = table.pack(...)
    return pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
end

local function invoke_remote(remote, ...)
    if not remote then
        return false, "missing remote"
    end

    local args = table.pack(...)
    return pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
end

local function is_seed_slots_table(value, expected_count)
    if type(value) ~= "table" then
        return false
    end

    local slot_count = 0
    local string_value_count = 0
    for key, item in pairs(value) do
        local numeric_key = type(key) == "number" or tonumber(key) ~= nil
        if numeric_key then
            if type(item) ~= "string" then
                return false
            end
            if item == "GetPlantsForIndex" then
                return false
            end
            slot_count = slot_count + 1
            string_value_count = string_value_count + 1
        end
    end

    if slot_count == 0 or string_value_count ~= slot_count then
        return false
    end

    if expected_count and expected_count > 0 then
        return slot_count == expected_count
    end

    return slot_count >= 2 and slot_count <= 12
end

local function resolve_seed_slots(force_scan)
    local now = os.clock()
    if type(runtime.cache.seed_slots_ref) == "table" and not force_scan and now - runtime.cache.last_seed_scan < 15 then
        return runtime.cache.seed_slots_ref
    end

    if not force_scan and now - runtime.cache.last_seed_scan < 8 then
        return runtime.cache.seed_slots_ref
    end
    runtime.cache.last_seed_scan = now

    if type(getgc) ~= "function" then
        return nil
    end

    local ok, gc_list = pcall(getgc, true)
    if not ok or type(gc_list) ~= "table" then
        return nil
    end

    runtime.cache.seed_slots_ref = nil
    local replica_data = get_replica_data()
    local expected_count = tonumber(replica_data and replica_data.CurrentSeedRolls)
    local best_candidate = nil
    local best_count = -1

    for _, item in ipairs(gc_list) do
        if type(item) == "function" then
            local info_ok, info = pcall(debug.getinfo, item)
            if info_ok and type(info) == "table" and type(info.source) == "string" and string.find(info.source, "SeedRollClient", 1, true) then
                local upvalue_ok, upvalues = pcall(debug.getupvalues, item)
                if upvalue_ok and type(upvalues) == "table" then
                    for _, upvalue in ipairs(upvalues) do
                        if is_seed_slots_table(upvalue, expected_count) then
                            runtime.cache.seed_slots_ref = upvalue
                            return upvalue
                        elseif not expected_count and is_seed_slots_table(upvalue, nil) then
                            local count = 0
                            for key in pairs(upvalue) do
                                if type(key) == "number" or tonumber(key) ~= nil then
                                    count = count + 1
                                end
                            end
                            if count > best_count then
                                best_candidate = upvalue
                                best_count = count
                            end
                        end
                    end
                end
            end
        end
    end

    runtime.cache.seed_slots_ref = best_candidate

    return best_candidate
end

local function get_rolled_seed_slots()
    local seed_slots_ref = resolve_seed_slots(false)
    local rolled_slots = {}
    if type(seed_slots_ref) ~= "table" then
        return rolled_slots
    end

    for slot, seed_name in pairs(seed_slots_ref) do
        local numeric_slot = tonumber(slot)
        if numeric_slot and type(seed_name) == "string" and seed_name ~= "" then
            rolled_slots[numeric_slot] = seed_name
        end
    end

    return rolled_slots
end

local function format_number(value)
    local number_value = tonumber(value)
    if not number_value then
        return tostring(value or 0)
    end

    local sign = number_value < 0 and "-" or ""
    local integer = tostring(math.floor(math.abs(number_value) + 0.5))
    local updated = integer
    local changes = 0

    repeat
        updated, changes = string.gsub(updated, "^(%d+)(%d%d%d)", "%1,%2")
    until changes == 0

    return sign .. updated
end

local function get_cash_display()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local cash_value = leaderstats and leaderstats:FindFirstChild("Cash")
    if cash_value then
        if type(cash_value.Value) == "string" then
            return cash_value.Value
        end
        return "$" .. format_number(cash_value.Value)
    end

    local data = get_replica_data()
    if data and data.Cash ~= nil then
        if type(data.Cash) == "string" then
            return data.Cash
        end
        return "$" .. format_number(data.Cash)
    end

    return "$0"
end

local function get_plot_display()
    local plot = get_plot()
    if plot then
        return plot.Name
    end
    return "n/a"
end

local function get_target_rarity_count()
    local count = 0
    for _, rarity_name in ipairs(RARITY_ORDER) do
        if config.TargetRarities[rarity_name] then
            count = count + 1
        end
    end
    return count
end

local function get_plant_info(seed_name)
    local modules = resolve_modules()
    local shared_registry = modules.shared_registry
    local plants = shared_registry and shared_registry.Plants
    if plants then
        return plants[seed_name]
    end
    return nil
end

local function get_seed_rarity(seed_name)
    local plant_info = get_plant_info(seed_name)
    if plant_info and plant_info.Rarity then
        return plant_info.Rarity
    end
    return "Common"
end

local function has_seed_in_inventory(data, seed_name)
    local inventory = data and data.SeedsInventory
    if type(inventory) ~= "table" then
        return false
    end

    for _, item in pairs(inventory) do
        if type(item) == "table" and item.Name == seed_name and (tonumber(item.Count) or 0) > 0 then
            return true
        end
    end

    return false
end

local function prune_recent_seed_buys()
    local now = os.clock()
    for seed_name, timestamp in pairs(runtime.seed.recent_buys) do
        if now - timestamp > 4 then
            runtime.seed.recent_buys[seed_name] = nil
        end
    end
end

local function recently_bought_seed(seed_name)
    local timestamp = runtime.seed.recent_buys[seed_name]
    return timestamp ~= nil and (os.clock() - timestamp) < 2.5
end

local function find_tool_by_keywords(character, backpack, keywords)
    local function search(container)
        if not container then
            return nil
        end

        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lowered = string.lower(item.Name)
                for _, keyword in ipairs(keywords) do
                    if string.find(lowered, keyword, 1, true) then
                        return item
                    end
                end
            end
        end

        return nil
    end

    return search(backpack) or search(character)
end

local function equip_tool(tool)
    local character = get_character()
    if tool and character and tool.Parent == LocalPlayer.Backpack then
        tool.Parent = character
        task.wait(0.1)
    end
end

local function get_interaction_part(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    return instance:FindFirstAncestorWhichIsA("BasePart")
end

local function activate_prompt(prompt, offset)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local part = get_interaction_part(prompt.Parent)
    local hrp = get_humanoid_root_part()
    if not part or not hrp then
        return false
    end

    hrp.CFrame = part.CFrame * (offset or CFrame.new(0, 1.5, 0))
    task.wait(0.2)
    fireproximityprompt(prompt)
    task.wait(0.1)
    return true
end

local function touch_part(part)
    if type(firetouchinterest) ~= "function" then
        return false
    end

    local hrp = get_humanoid_root_part()
    if not hrp or not part then
        return false
    end

    hrp.CFrame = part.CFrame
    task.wait(0.15)
    firetouchinterest(hrp, part, 0)
    task.wait(0.05)
    firetouchinterest(hrp, part, 1)
    task.wait(0.05)
    return true
end

local function begin_event_mode(hrp)
    if not runtime.event.active then
        runtime.event.active = true
        runtime.event.return_cframe = hrp.CFrame
    end
end

local function end_event_mode(hrp)
    if not runtime.event.active then
        return
    end

    runtime.event.active = false
    local return_cframe = runtime.event.return_cframe
    runtime.event.return_cframe = nil

    if hrp and return_cframe then
        hrp.CFrame = return_cframe
        task.wait(0.1)
    end
end

local function with_seed_lever(action)
    local plot = get_plot()
    local hrp = get_humanoid_root_part()
    if not plot or not hrp then
        return false
    end

    local roll_platform = plot:FindFirstChild("RollPlatform")
    local lever = roll_platform and roll_platform:FindFirstChild("Lever")
    if not lever then
        return false
    end

    local target_cframe = lever:GetPivot() * CFrame.new(0, 3, 3)
    local original_cframe = hrp.CFrame
    local should_move = (hrp.Position - target_cframe.Position).Magnitude > 25

    if should_move then
        hrp.CFrame = target_cframe
        task.wait(0.25)
    end

    local ok, err = pcall(action, lever, hrp)

    if should_move and runtime.running and hrp.Parent then
        task.wait(0.05)
        hrp.CFrame = original_cframe
    end

    if not ok then
        error(err)
    end

    return true
end

local function refresh_context()
    local previous_plot = runtime.cache.plot
    resolve_modules()
    local plot = get_plot()
    get_replica()

    if config.AutoRollSeeds then
        resolve_seed_slots(false)
    end

    if plot and plot ~= previous_plot then
        set_status("Attached to plot " .. plot.Name)
    end
end

local function action_auto_sell()
    if not config.AutoSell or not REMOTES.SellCrates then
        return
    end

    local ok = fire_remote(REMOTES.SellCrates)
    if ok then
        runtime.metrics.sells = runtime.metrics.sells + 1
    end
end

local function action_auto_daily()
    if not config.AutoClaimDaily or not REMOTES.UpdateDailyRewards then
        return
    end

    local ok = fire_remote(REMOTES.UpdateDailyRewards)
    if ok then
        runtime.metrics.daily_claims = runtime.metrics.daily_claims + 1
    end
end

local function action_auto_buy_eggs()
    if not config.AutoBuyEggs or not REMOTES.EggTransaction then
        return
    end

    local data = get_replica_data()
    local egg_config = resolve_modules().egg_config
    if not data or type(egg_config) ~= "table" then
        return
    end

    local stock = data.EggShopStock
    local slots = stock and stock.Slots
    local unlock_prices = egg_config.UnlockPrices or {}
    local prices = egg_config.Prices or {}
    local cash = tonumber(data.Cash) or 0

    if type(slots) ~= "table" then
        return
    end

    for slot = 1, 5 do
        local podium_name = "Podium" .. slot
        local unlocked = slot == 1 or (type(data.UnlockedEggPodiums) == "table" and data.UnlockedEggPodiums[podium_name] == true)

        if not unlocked then
            local unlock_cost = tonumber(unlock_prices[podium_name])
            if unlock_cost and cash >= unlock_cost then
                local ok, success = invoke_remote(REMOTES.EggTransaction, "UnlockSlot", slot)
                if ok and success then
                    set_status(("Unlocked egg podium %d"):format(slot))
                    return
                end
            end
        else
            local egg_name = slots[slot]
            local cost = egg_name and tonumber(prices[egg_name])
            if type(egg_name) == "string" and egg_name ~= "" and cost and cash >= cost then
                local ok, success, _, rolled_egg = invoke_remote(REMOTES.EggTransaction, "BuyEgg", slot)
                if ok and success then
                    local egg_to_roll = rolled_egg or egg_name
                    if REMOTES.RollEgg then
                        fire_remote(REMOTES.RollEgg, egg_to_roll)
                    end
                    runtime.metrics.egg_buys = runtime.metrics.egg_buys + 1
                    set_status("Bought egg " .. tostring(egg_to_roll))
                    return
                end
            end
        end
    end
end

local function action_auto_buy_gears()
    if not config.AutoBuyGears or not REMOTES.GearTransaction then
        return
    end

    local data = get_replica_data()
    local gear_registry = resolve_modules().gear_registry
    if not data or type(gear_registry) ~= "table" then
        return
    end

    local stocks = data.GearShopStock and data.GearShopStock.Stocks
    if type(stocks) ~= "table" then
        return
    end

    local lookup = gear_registry[2] or gear_registry
    local cash = tonumber(data.Cash) or 0

    for gear_name, stock_count in pairs(stocks) do
        local gear_data = type(lookup) == "table" and lookup[gear_name] or nil
        local gear_cost = gear_data and tonumber(gear_data.Cost)
        if (tonumber(stock_count) or 0) > 0 and gear_cost and cash >= gear_cost then
            local ok, success = invoke_remote(REMOTES.GearTransaction, gear_name)
            if ok and success then
                runtime.metrics.gear_buys = runtime.metrics.gear_buys + 1
                set_status("Bought gear " .. tostring(gear_name))
                return
            end
        end
    end
end

local function action_auto_roll_seeds()
    if not config.AutoRollSeeds or not REMOTES.RollSeeds or not REMOTES.BuySeed then
        return
    end

    if get_target_rarity_count() == 0 then
        set_status("Select at least one rarity for Auto Roll")
        return
    end

    local data = get_replica_data()
    if not data then
        return
    end

    prune_recent_seed_buys()

    local rolled_slots = get_rolled_seed_slots()
    local wanted_slots = {}
    local slot_numbers = {}
    local slot_count = 0

    for slot, _ in pairs(rolled_slots) do
        slot_count = slot_count + 1
        table.insert(slot_numbers, slot)
    end
    table.sort(slot_numbers)

    for _, slot in ipairs(slot_numbers) do
        local seed_name = rolled_slots[slot]
        local rarity = get_seed_rarity(seed_name)
        local should_buy = config.TargetRarities[rarity] == true
        local already_owned = has_seed_in_inventory(data, seed_name) or recently_bought_seed(seed_name)
        if should_buy and not already_owned then
            table.insert(wanted_slots, {
                slot = slot,
                name = seed_name,
                rarity = rarity,
            })
        end
    end

    getgenv()[SCRIPT_TAG .. "Status"] = {
        has_rolled_slots = slot_count > 0,
        rolled_slot_count = slot_count,
        wanted_slot_count = #wanted_slots,
        last_roll_at = runtime.seed.last_roll_at,
        status = runtime.status,
    }

    if #wanted_slots > 0 then
        with_seed_lever(function()
            for _, wanted in ipairs(wanted_slots) do
                local ok = fire_remote(REMOTES.BuySeed, wanted.slot)
                if ok then
                    runtime.seed.recent_buys[wanted.name] = os.clock()
                    runtime.metrics.seed_buys = runtime.metrics.seed_buys + 1
                    set_status(("Bought seed %s (%s)"):format(wanted.name, wanted.rarity))
                    task.wait(0.18)
                end
            end
        end)
        return
    end

    if os.clock() - runtime.seed.last_roll_at < 2.5 then
        return
    end

    with_seed_lever(function()
        local ok = fire_remote(REMOTES.RollSeeds)
        if ok then
            runtime.seed.last_roll_at = os.clock()
            runtime.metrics.seed_rolls = runtime.metrics.seed_rolls + 1
            set_status("Rolled seed stand")
        end
    end)
end

local function action_auto_compost()
    if not config.AutoCompost or not REMOTES.ComposterRequestState or not REMOTES.ComposterInsertSeed or not REMOTES.ComposterPullLever then
        return
    end

    local data = get_replica_data()
    local modules = resolve_modules()
    local compost_config = modules.compost_config
    local shared_registry = modules.shared_registry
    local plants = shared_registry and shared_registry.Plants
    if not data or type(compost_config) ~= "table" or type(plants) ~= "table" then
        return
    end

    for floor = 2, 3 do
        local ok, state = invoke_remote(REMOTES.ComposterRequestState, floor)
        if ok and type(state) == "table" and state.Unlocked then
            local tiers = compost_config.Tiers and compost_config.Tiers[floor]
            local min_requirement = tiers and tiers[1] and tonumber(tiers[1].Min) or 5000000000
            local current_value = tonumber(state.Value) or 0

            if current_value >= min_requirement then
                local pull_ok, pull_result = invoke_remote(REMOTES.ComposterPullLever, floor)
                if pull_ok and type(pull_result) == "table" and pull_result.Success then
                    runtime.metrics.compost_pulls = runtime.metrics.compost_pulls + 1
                    set_status(("Pulled composter lever on floor %d"):format(floor))
                    return
                end
            else
                local sorted_seeds = {}
                local inventory = data.SeedsInventory
                if type(inventory) ~= "table" then
                    return
                end

                for inventory_key, item in pairs(inventory) do
                    if type(item) == "table" and (tonumber(item.Count) or 0) > 0 then
                        local plant_info = plants[item.Name]
                        local cost = plant_info and tonumber(plant_info.Cost) or 0
                        if cost > 0 then
                            table.insert(sorted_seeds, {
                                key = inventory_key,
                                name = item.Name,
                                count = tonumber(item.Count) or 0,
                                cost = cost,
                            })
                        end
                    end
                end

                table.sort(sorted_seeds, function(left, right)
                    return left.cost < right.cost
                end)

                for _, seed in ipairs(sorted_seeds) do
                    local needed_value = min_requirement - current_value
                    if needed_value <= 0 then
                        break
                    end

                    local amount_needed = math.ceil(needed_value / seed.cost)
                    local to_insert = math.min(seed.count, amount_needed)
                    if to_insert > 0 then
                        local insert_ok, insert_result = invoke_remote(REMOTES.ComposterInsertSeed, floor, seed.key, to_insert)
                        if insert_ok and type(insert_result) == "table" and insert_result.Success then
                            set_status(("Inserted %d x %s into composter"):format(to_insert, seed.name))
                            return
                        end
                    end
                end
            end
        end
    end
end

local function handle_queen_bee(interactive, character, hrp)
    local queen_bee = interactive:FindFirstChild("QueenBee")
    if not queen_bee then
        return false
    end

    local runtime_honeycombs = queen_bee:FindFirstChild("RuntimeHoneycombs")
    if runtime_honeycombs then
        for _, model in ipairs(runtime_honeycombs:GetChildren()) do
            local honeycomb = model:FindFirstChild("Honeycomb")
            local collect_prompt = honeycomb and honeycomb:FindFirstChild("CollectPrompt")
            if collect_prompt and collect_prompt.Enabled then
                begin_event_mode(hrp)
                if activate_prompt(collect_prompt, CFrame.new(0, 1.5, 0)) then
                    runtime.metrics.event_actions = runtime.metrics.event_actions + 1
                    set_status("Collected Queen Bee honeycomb")
                    return true
                end
            end
        end
    end

    local token = find_tool_by_keywords(character, LocalPlayer.Backpack, { "token", "bee", "honey" })
    local jar_model = queen_bee:FindFirstChild("HoneyJarMachine")
    local jar_machine = jar_model and jar_model:FindFirstChild("Honey Jar Machine")
    local insert_prompt = jar_machine and jar_machine:FindFirstChild("InsertPrompt")
    if token and insert_prompt and insert_prompt.Enabled then
        begin_event_mode(hrp)
        equip_tool(token)
        if activate_prompt(insert_prompt, CFrame.new(0, 2, 2.5)) then
            runtime.metrics.event_actions = runtime.metrics.event_actions + 1
            set_status("Inserted token at Queen Bee machine")
            return true
        end
    end

    return false
end

local function get_first_plant_rush_target(plant_rush)
    local boss_target = nil
    local normal_target = nil

    for _, object in ipairs(plant_rush:GetDescendants()) do
        if object:IsA("Model") then
            local target_part = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Head") or object:FindFirstChildOfClass("BasePart")
            if target_part then
                local lowered = string.lower(object.Name)
                if object.Name == "Boss Plant" or string.find(lowered, "boss", 1, true) then
                    boss_target = object
                    break
                elseif not normal_target then
                    normal_target = object
                end
            end
        end
    end

    return boss_target or normal_target
end

local function handle_plant_rush(interactive, character, hrp)
    local plant_rush = interactive:FindFirstChild("PlantRush")
    if not plant_rush then
        return false
    end

    local target = get_first_plant_rush_target(plant_rush)
    if target and REMOTES.PlantRushShoot and REMOTES.PlantRushHit then
        begin_event_mode(hrp)
        local tomato_tool = find_tool_by_keywords(character, LocalPlayer.Backpack, { "tomato", "shoot" })
        equip_tool(tomato_tool)

        local target_part = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head") or target:FindFirstChildOfClass("BasePart")
        if target_part then
            local camera = workspace.CurrentCamera
            if camera then
                camera.CFrame = CFrame.new(camera.CFrame.Position, target_part.Position)
            end
            task.wait(0.05)
            fire_remote(REMOTES.PlantRushShoot)
            task.wait(0.05)
            fire_remote(REMOTES.PlantRushHit, target)
            runtime.metrics.event_actions = runtime.metrics.event_actions + 1
            set_status("Plant Rush target hit: " .. target.Name)
            return true
        end
    end

    for _, object in ipairs(plant_rush:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            begin_event_mode(hrp)
            if activate_prompt(object, CFrame.new(0, 1.5, 0)) then
                runtime.metrics.event_actions = runtime.metrics.event_actions + 1
                set_status("Collected Plant Rush reward")
                return true
            end
        end
    end

    return false
end

local function handle_generic_events(interactive, hrp)
    for _, event_folder in ipairs(interactive:GetChildren()) do
        if event_folder.Name ~= "QueenBee" and event_folder.Name ~= "PlantRush" then
            for _, object in ipairs(event_folder:GetDescendants()) do
                if object:IsA("ProximityPrompt") and object.Enabled and object.Name ~= "InsertPrompt" then
                    begin_event_mode(hrp)
                    if activate_prompt(object, CFrame.new(0, 1.5, 0)) then
                        runtime.metrics.event_actions = runtime.metrics.event_actions + 1
                        set_status("Handled event prompt: " .. event_folder.Name)
                        return true
                    end
                end
            end

            for _, object in ipairs(event_folder:GetDescendants()) do
                if object:IsA("TouchTransmitter") then
                    local part = get_interaction_part(object.Parent)
                    if part then
                        begin_event_mode(hrp)
                        if touch_part(part) then
                            runtime.metrics.event_actions = runtime.metrics.event_actions + 1
                            set_status("Touched event checkpoint: " .. event_folder.Name)
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

local function action_auto_events()
    if not config.AutoEvents then
        return
    end

    local interactive = workspace:FindFirstChild("InteractiveEvents")
    local character = get_character()
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not interactive or not character or not hrp then
        return
    end

    local handled = handle_queen_bee(interactive, character, hrp)
    if not handled then
        handled = handle_plant_rush(interactive, character, hrp)
    end
    if not handled then
        handled = handle_generic_events(interactive, hrp)
    end

    if not handled then
        end_event_mode(hrp)
    end
end

local function refresh_stats_ui()
    local labels = runtime.ui.stat_labels
    if not labels then
        return
    end

    if labels.cash then
        labels.cash.Text = "Cash: " .. get_cash_display()
    end
    if labels.plot then
        labels.plot.Text = "Plot: " .. get_plot_display()
    end
    if labels.seed_rolls then
        labels.seed_rolls.Text = "Seed Rolls: " .. tostring(runtime.metrics.seed_rolls)
    end
    if labels.seed_buys then
        labels.seed_buys.Text = "Seed Buys: " .. tostring(runtime.metrics.seed_buys)
    end
    if labels.egg_buys then
        labels.egg_buys.Text = "Egg Buys: " .. tostring(runtime.metrics.egg_buys)
    end
    if labels.gear_buys then
        labels.gear_buys.Text = "Gear Buys: " .. tostring(runtime.metrics.gear_buys)
    end
    if labels.compost_pulls then
        labels.compost_pulls.Text = "Compost Pulls: " .. tostring(runtime.metrics.compost_pulls)
    end
    if labels.event_actions then
        labels.event_actions.Text = "Event Actions: " .. tostring(runtime.metrics.event_actions)
    end
    if labels.errors then
        labels.errors.Text = "Errors: " .. tostring(runtime.metrics.errors)
    end
end

local function add_job(name, interval, initial_delay, callback)
    table.insert(runtime.jobs, {
        name = name,
        interval = interval,
        next_run = os.clock() + (initial_delay or 0),
        callback = callback,
    })
end

local function make_draggable(handle, target)
    local dragging = false
    local drag_start = nil
    local start_position = nil

    local function update_position(input)
        local delta = input.Position - drag_start
        target.Position = UDim2.new(
            start_position.X.Scale,
            start_position.X.Offset + delta.X,
            start_position.Y.Scale,
            start_position.Y.Offset + delta.Y
        )
    end

    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            drag_start = input.Position
            start_position = target.Position

            local changed_connection
            changed_connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    changed_connection:Disconnect()
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update_position(input)
        end
    end)
end

local function bind_canvas(scroll, layout)
    local function update()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end

    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), update)
    update()
end

local function build_ui()
    cleanup_existing_ui()

    local theme = {
        bg = Color3.fromRGB(13, 16, 20),
        panel = Color3.fromRGB(20, 24, 30),
        soft = Color3.fromRGB(29, 34, 42),
        line = Color3.fromRGB(55, 64, 77),
        text = Color3.fromRGB(239, 243, 248),
        muted = Color3.fromRGB(155, 164, 176),
        accent = Color3.fromRGB(120, 205, 150),
        accent_off = Color3.fromRGB(215, 110, 110),
    }

    local screen_gui = Instance.new("ScreenGui")
    screen_gui.Name = GUI_NAME
    screen_gui.ResetOnSpawn = false
    screen_gui.IgnoreGuiInset = true
    screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(screen_gui)
    screen_gui.Parent = get_gui_parent()

    runtime.ui.screen_gui = screen_gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(700, 430)
    main.Position = UDim2.new(0.5, -350, 0.5, -215)
    main.BackgroundColor3 = theme.bg
    main.BorderSizePixel = 0
    main.Parent = screen_gui
    runtime.ui.main = main

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 12)
    main_corner.Parent = main

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Color = theme.line
    main_stroke.Thickness = 1
    main_stroke.Transparency = 0.2
    main_stroke.Parent = main

    local top = Instance.new("Frame")
    top.Name = "Top"
    top.Size = UDim2.new(1, 0, 0, 48)
    top.BackgroundColor3 = theme.panel
    top.BorderSizePixel = 0
    top.Parent = main

    local top_corner = Instance.new("UICorner")
    top_corner.CornerRadius = UDim.new(0, 12)
    top_corner.Parent = top

    local top_fix = Instance.new("Frame")
    top_fix.Size = UDim2.new(1, 0, 0, 12)
    top_fix.Position = UDim2.fromOffset(0, 36)
    top_fix.BackgroundColor3 = theme.panel
    top_fix.BorderSizePixel = 0
    top_fix.Parent = top

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(16, 6)
    title.Size = UDim2.new(1, -180, 0, 18)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = theme.text
    title.Text = SCRIPT_NAME
    title.Parent = top

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.fromOffset(16, 24)
    subtitle.Size = UDim2.new(1, -180, 0, 16)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = theme.muted
    subtitle.Text = ("v%s | LeftControl = hide | Native UI | State-driven"):format(VERSION)
    subtitle.Parent = top

    local function create_top_button(text, x_offset, color)
        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(28, 28)
        button.Position = UDim2.new(1, x_offset, 0, 10)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.TextColor3 = theme.text
        button.Text = text
        button.Parent = top

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button

        return button
    end

    local minimize_button = create_top_button("-", -70, theme.soft)
    local close_button = create_top_button("X", -36, theme.accent_off)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Position = UDim2.fromOffset(12, 60)
    content.Size = UDim2.new(1, -24, 1, -104)
    content.BackgroundTransparency = 1
    content.Parent = main

    local left = Instance.new("ScrollingFrame")
    left.Name = "Left"
    left.Size = UDim2.fromOffset(320, 266)
    left.BackgroundColor3 = theme.panel
    left.BorderSizePixel = 0
    left.ScrollBarThickness = 4
    left.CanvasSize = UDim2.new()
    left.Parent = content

    local left_corner = Instance.new("UICorner")
    left_corner.CornerRadius = UDim.new(0, 10)
    left_corner.Parent = left

    local left_padding = Instance.new("UIPadding")
    left_padding.PaddingTop = UDim.new(0, 12)
    left_padding.PaddingBottom = UDim.new(0, 12)
    left_padding.PaddingLeft = UDim.new(0, 12)
    left_padding.PaddingRight = UDim.new(0, 12)
    left_padding.Parent = left

    local left_layout = Instance.new("UIListLayout")
    left_layout.Padding = UDim.new(0, 10)
    left_layout.SortOrder = Enum.SortOrder.LayoutOrder
    left_layout.Parent = left
    bind_canvas(left, left_layout)

    local right = Instance.new("ScrollingFrame")
    right.Name = "Right"
    right.Position = UDim2.fromOffset(336, 0)
    right.Size = UDim2.new(1, -336, 0, 266)
    right.BackgroundColor3 = theme.panel
    right.BorderSizePixel = 0
    right.ScrollBarThickness = 4
    right.CanvasSize = UDim2.new()
    right.Parent = content

    local right_corner = Instance.new("UICorner")
    right_corner.CornerRadius = UDim.new(0, 10)
    right_corner.Parent = right

    local right_padding = Instance.new("UIPadding")
    right_padding.PaddingTop = UDim.new(0, 12)
    right_padding.PaddingBottom = UDim.new(0, 12)
    right_padding.PaddingLeft = UDim.new(0, 12)
    right_padding.PaddingRight = UDim.new(0, 12)
    right_padding.Parent = right

    local right_layout = Instance.new("UIListLayout")
    right_layout.Padding = UDim.new(0, 10)
    right_layout.SortOrder = Enum.SortOrder.LayoutOrder
    right_layout.Parent = right
    bind_canvas(right, right_layout)

    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.Position = UDim2.fromOffset(12, 336)
    footer.Size = UDim2.new(1, -24, 0, 82)
    footer.BackgroundColor3 = theme.panel
    footer.BorderSizePixel = 0
    footer.Parent = main

    local footer_corner = Instance.new("UICorner")
    footer_corner.CornerRadius = UDim.new(0, 10)
    footer_corner.Parent = footer

    local footer_padding = Instance.new("UIPadding")
    footer_padding.PaddingTop = UDim.new(0, 12)
    footer_padding.PaddingBottom = UDim.new(0, 12)
    footer_padding.PaddingLeft = UDim.new(0, 12)
    footer_padding.PaddingRight = UDim.new(0, 12)
    footer_padding.Parent = footer

    local status_label = Instance.new("TextLabel")
    status_label.BackgroundTransparency = 1
    status_label.Size = UDim2.new(1, 0, 0, 18)
    status_label.Font = Enum.Font.GothamSemibold
    status_label.TextSize = 13
    status_label.TextXAlignment = Enum.TextXAlignment.Left
    status_label.TextColor3 = theme.text
    status_label.Text = "Status: Booting"
    status_label.Parent = footer
    runtime.ui.status_label = status_label

    local footer_note = Instance.new("TextLabel")
    footer_note.BackgroundTransparency = 1
    footer_note.Position = UDim2.fromOffset(0, 24)
    footer_note.Size = UDim2.new(1, 0, 0, 44)
    footer_note.Font = Enum.Font.Gotham
    footer_note.TextSize = 12
    footer_note.TextWrapped = true
    footer_note.TextXAlignment = Enum.TextXAlignment.Left
    footer_note.TextYAlignment = Enum.TextYAlignment.Top
    footer_note.TextColor3 = theme.muted
    footer_note.Text = "This rebuild removes dead config, reduces repeated GC scans, and limits each job to small remote bursts for better long-run stability."
    footer_note.Parent = footer

    local mini = Instance.new("TextButton")
    mini.Name = "Mini"
    mini.Size = UDim2.fromOffset(46, 46)
    mini.Position = main.Position
    mini.BackgroundColor3 = theme.panel
    mini.BorderSizePixel = 0
    mini.Font = Enum.Font.GothamBold
    mini.TextSize = 16
    mini.TextColor3 = theme.text
    mini.Text = "BR"
    mini.Visible = false
    mini.Parent = screen_gui
    runtime.ui.mini = mini

    local mini_corner = Instance.new("UICorner")
    mini_corner.CornerRadius = UDim.new(1, 0)
    mini_corner.Parent = mini

    local mini_stroke = Instance.new("UIStroke")
    mini_stroke.Color = theme.line
    mini_stroke.Thickness = 1
    mini_stroke.Transparency = 0.2
    mini_stroke.Parent = mini

    local function create_card(parent, title_text)
        local card = Instance.new("Frame")
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.Size = UDim2.new(1, 0, 0, 0)
        card.BackgroundColor3 = theme.soft
        card.BorderSizePixel = 0
        card.Parent = parent

        local card_corner = Instance.new("UICorner")
        card_corner.CornerRadius = UDim.new(0, 8)
        card_corner.Parent = card

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
        padding.Parent = card

        local title_label = Instance.new("TextLabel")
        title_label.BackgroundTransparency = 1
        title_label.Size = UDim2.new(1, 0, 0, 16)
        title_label.Font = Enum.Font.GothamSemibold
        title_label.TextSize = 12
        title_label.TextXAlignment = Enum.TextXAlignment.Left
        title_label.TextColor3 = theme.text
        title_label.Text = title_text
        title_label.Parent = card

        local body = Instance.new("Frame")
        body.BackgroundTransparency = 1
        body.Position = UDim2.fromOffset(0, 22)
        body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.Parent = card

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = body

        return body
    end

    local function create_toggle_row(parent, label_text, default_value, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -78, 1, 0)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = theme.text
        label.Text = label_text
        label.Parent = row

        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(68, 28)
        button.Position = UDim2.new(1, -68, 0, 2)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.Parent = row

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = button

        local state = default_value == true
        local function apply()
            button.BackgroundColor3 = state and theme.accent or theme.accent_off
            button.TextColor3 = state and Color3.fromRGB(20, 28, 24) or theme.text
            button.Text = state and "ON" or "OFF"
        end

        apply()

        connect(button.MouseButton1Click, function()
            state = not state
            callback(state)
            apply()
        end)

        return button
    end

    local function create_action_button(parent, label_text, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 30)
        button.BackgroundColor3 = theme.panel
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.TextColor3 = theme.text
        button.Text = label_text
        button.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = button

        connect(button.MouseButton1Click, callback)
        return button
    end

    local function create_stat_label(parent, key, label_text)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 16)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = theme.text
        label.Text = label_text
        label.Parent = parent
        runtime.ui.stat_labels[key] = label
        return label
    end

    local automation_card = create_card(left, "Automation")
    create_toggle_row(automation_card, "Auto Sell Crates", config.AutoSell, function(value)
        config.AutoSell = value
    end)
    create_toggle_row(automation_card, "Auto Claim Daily", config.AutoClaimDaily, function(value)
        config.AutoClaimDaily = value
    end)
    create_toggle_row(automation_card, "Auto Buy Eggs", config.AutoBuyEggs, function(value)
        config.AutoBuyEggs = value
    end)
    create_toggle_row(automation_card, "Auto Buy Gears", config.AutoBuyGears, function(value)
        config.AutoBuyGears = value
    end)
    create_toggle_row(automation_card, "Auto Roll Seeds", config.AutoRollSeeds, function(value)
        config.AutoRollSeeds = value
    end)
    create_toggle_row(automation_card, "Auto Compost", config.AutoCompost, function(value)
        config.AutoCompost = value
    end)
    create_toggle_row(automation_card, "Auto Events", config.AutoEvents, function(value)
        config.AutoEvents = value
    end)

    local actions_card = create_card(left, "Actions")
    create_action_button(actions_card, "Refresh Plot Cache", function()
        runtime.cache.plot = nil
        local plot = get_plot()
        if plot then
            set_status("Refreshed plot cache: " .. plot.Name)
        else
            set_status("Plot cache refresh failed")
        end
    end)
    create_action_button(actions_card, "Rescan Seed Stand Cache", function()
        runtime.cache.seed_slots_ref = nil
        runtime.cache.last_seed_scan = 0
        resolve_seed_slots(true)
        set_status("Seed stand cache rescanned")
    end)
    create_action_button(actions_card, "Stop Script", function()
        stop_runtime("stopped from UI")
    end)

    local rarity_card = create_card(right, "Seed Rarity Targets")
    for _, rarity_name in ipairs(RARITY_ORDER) do
        create_toggle_row(rarity_card, rarity_name, config.TargetRarities[rarity_name], function(value)
            config.TargetRarities[rarity_name] = value
        end)
    end

    local stats_card = create_card(right, "Session Stats")
    create_stat_label(stats_card, "cash", "Cash: $0")
    create_stat_label(stats_card, "plot", "Plot: n/a")
    create_stat_label(stats_card, "seed_rolls", "Seed Rolls: 0")
    create_stat_label(stats_card, "seed_buys", "Seed Buys: 0")
    create_stat_label(stats_card, "egg_buys", "Egg Buys: 0")
    create_stat_label(stats_card, "gear_buys", "Gear Buys: 0")
    create_stat_label(stats_card, "compost_pulls", "Compost Pulls: 0")
    create_stat_label(stats_card, "event_actions", "Event Actions: 0")
    create_stat_label(stats_card, "errors", "Errors: 0")

    local hidden = false
    local minimized = false

    local function apply_visibility()
        if hidden then
            main.Visible = false
            mini.Visible = false
        else
            main.Visible = not minimized
            mini.Visible = minimized
        end
    end

    connect(minimize_button.MouseButton1Click, function()
        minimized = true
        mini.Position = main.Position
        apply_visibility()
    end)

    connect(mini.MouseButton1Click, function()
        minimized = false
        apply_visibility()
    end)

    connect(close_button.MouseButton1Click, function()
        stop_runtime("closed from UI")
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            hidden = not hidden
            apply_visibility()
        end
    end)

    make_draggable(top, main)
    make_draggable(mini, mini)
    apply_visibility()
    refresh_stats_ui()
end

connect(LocalPlayer.CharacterAdded, function()
    runtime.event.active = false
    runtime.event.return_cframe = nil
    runtime.cache.plot = nil
    runtime.cache.replica = nil
    set_status("Character respawned; refreshing caches")
end)

run_safe("build_ui", build_ui)
run_safe("initial_context", refresh_context)

add_job("refresh_context", 5.0, 0.0, refresh_context)
add_job("auto_sell", 1.5, 0.2, action_auto_sell)
add_job("auto_daily", 30.0, 0.4, action_auto_daily)
add_job("auto_buy_eggs", 1.6, 0.6, action_auto_buy_eggs)
add_job("auto_buy_gears", 1.8, 0.8, action_auto_buy_gears)
add_job("auto_roll_seeds", 1.0, 1.0, action_auto_roll_seeds)
add_job("auto_compost", 4.5, 1.2, action_auto_compost)
add_job("auto_events", 1.4, 1.4, action_auto_events)

task.spawn(function()
    while is_current_instance() do
        local now = os.clock()
        for _, job in ipairs(runtime.jobs) do
            if now >= job.next_run then
                job.next_run = now + job.interval
                run_safe(job.name, job.callback)
            end
        end
        task.wait(0.15)
    end
end)

task.spawn(function()
    while is_current_instance() do
        run_safe("refresh_stats_ui", refresh_stats_ui)
        task.wait(0.5)
    end
end)

set_status("Loaded")
log("Initialized v" .. VERSION)
