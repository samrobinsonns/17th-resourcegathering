local QBCore = exports['qb-core']:GetCoreObject()
local cooldowns = {}
local mergedZones = {}
local zoneProps = {} -- Tracks props per merged zone
local activeZones = {} -- Tracks active sphere zones
local defaultMergeRadius = 200.0

-- New Tool Configuration System (following the pattern you showed)
local TOOL_CONFIG = {
    pickaxe = {
        prop = "prop_tool_pickaxe",
        scenario = nil,  -- no great scenario; we'll use a melee anim fallback
        anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },
        ptfx = { asset = "core", name = "ent_anim_mine_dust" },
        duration = nil  -- Will be loaded from config
    },
    mining_drill = {
        prop = "prop_tool_jackham",
        scenario = "WORLD_HUMAN_CONST_DRILL",  -- re-enabled jackhammer scenario
        anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },  -- fallback
        ptfx = { asset = "core", name = "ent_anim_mine_dust" },
        duration = nil  -- Will be loaded from config
    },
    mining_laser = {
        prop = "prop_cs_gascutter_1", -- blowtorch; alternative: "prop_tool_screwdvr02"
        scenario = "WORLD_HUMAN_WELDING",  -- solid & looped
        anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },  -- fallback
        ptfx = { asset = "core", name = "ent_amb_sparking_wires" },
        duration = nil  -- Will be loaded from config
    }
}

-- UI Target Variables
local uiTargetPed = nil
local uiTargetBlip = nil
local uiOpen = false

-- Table to track active particle effects
local activeParticleEffects = {}

-- Function to stop all particle effects for a ped
local function stopAllParticleEffects(ped)
    if activeParticleEffects[ped] then
        StopParticleFxLooped(activeParticleEffects[ped], false)
        activeParticleEffects[ped] = nil
        print("^2[DEBUG]^0 Stopped particle effects for ped")
    end
end

-- Function to get tool duration from config
local function getToolDuration(toolType)
    if not toolType then return 5000 end
    
    -- Check if mining activity has tool-specific durations
    if Config.ProgressBar and Config.ProgressBar.mining and Config.ProgressBar.mining.toolDurations then
        local duration = Config.ProgressBar.mining.toolDurations[toolType]
        if duration then
            print('^3[DEBUG]^0 Using config duration for', toolType .. ':', duration .. 'ms^0')
            return duration
        end
    end
    
    -- Fallback to default mining duration
    local defaultDuration = Config.ProgressBar and Config.ProgressBar.mining and Config.ProgressBar.mining.duration or 10000
    print('^3[DEBUG]^0 Using fallback duration for', toolType .. ':', defaultDuration .. 'ms^0')
    return defaultDuration
end

-- Function to get dynamic tool configuration
local function getToolConfig(toolType)
    if not toolType then return nil end
    
    -- Create dynamic tool config based on current tool type
    local baseConfig = {
        pickaxe = {
            prop = "prop_tool_pickaxe",
            scenario = nil,  -- no great scenario; we'll use a melee anim fallback
            anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },
            ptfx = { asset = "core", name = "ent_anim_mine_dust" }
        },
        mining_drill = {
            prop = "prop_tool_jackham",
            scenario = "WORLD_HUMAN_CONST_DRILL",  -- jackhammer scenario
            anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },  -- fallback
            ptfx = { asset = "core", name = "ent_anim_mine_dust" }
        },
        mining_laser = {
            prop = "prop_cs_gascutter_1", -- blowtorch
            scenario = "WORLD_HUMAN_WELDING",  -- welding scenario
            anim = { dict = "melee@large_wpn@streamed_core", name = "ground_attack_on_spot" },  -- fallback
            ptfx = { asset = "core", name = "ent_amb_sparking_wires" }
        }
    }
    
    local config = baseConfig[toolType]
    if config then
        -- Add duration from config
        config.duration = getToolDuration(toolType)
        print('^3[DEBUG]^0 Generated dynamic tool config for:', toolType, 'duration:', config.duration .. 'ms^0')
        return config
    end
    
    print('^1[ERROR]^0 No tool config found for:', toolType .. '^0')
    return nil
end

-- Utility functions for the new tool system
local function ensureModel(model)
    local m = GetHashKey(model)
    if not HasModelLoaded(m) then
        RequestModel(m)
        local t = GetGameTimer()
        while not HasModelLoaded(m) do
            Wait(10)
            if GetGameTimer() - t > 5000 then
                print("^1[ERROR]^0 Model load timeout:", model)
                break
            end
        end
    end
    return m
end

local function ensurePtfx(asset)
    if not HasNamedPtfxAssetLoaded(asset) then
        RequestNamedPtfxAsset(asset)
        local t = GetGameTimer()
        while not HasNamedPtfxAssetLoaded(asset) do
            Wait(10)
            if GetGameTimer() - t > 3000 then
                print("^1[ERROR]^0 PTFX load timeout:", asset)
                break
            end
        end
    end
end

local function attachToolProp(ped, model)
    local bone = GetPedBoneIndex(ped, 57005) -- hand_r
    local obj = CreateObject(ensureModel(model), 0.0, 0.0, 0.0, true, true, false)
    
    -- Offsets tuned for blowtorch/jackhammer/pickaxe; tweak to taste:
    if model == "prop_cs_gascutter_1" then
        -- Blow torch positioning with 180 degree horizontal rotation
        AttachEntityToEntity(obj, ped, bone, 0.14, 0.04, -0.01, -90.0, 0.0, 180.0, true, true, false, true, 1, true)
    elseif model == "prop_tool_jackham" then
        -- Hammer/wrench positioning (more forward and angled)
        AttachEntityToEntity(obj, ped, bone, 0.18, 0.06, -0.02, -85.0, 15.0, 0.0, true, true, false, true, 1, true)
    else
        -- Default pickaxe positioning (original values)
        AttachEntityToEntity(obj, ped, bone, 0.12, 0.03, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
    
    return obj
end

local function startScenarioOrAnim(ped, cfg)
    if cfg.scenario then
        -- Scenarios are robust and loop automatically
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
        Wait(250)
        if not IsPedUsingAnyScenario(ped) then
            print("^3[DEBUG]^0 Scenario failed, will try anim fallback if provided")
        else
            print("^2[DEBUG]^0 Scenario started successfully:", cfg.scenario)
            return "scenario"
        end
    end
    
    if cfg.anim then
        RequestAnimDict(cfg.anim.dict)
        local t = GetGameTimer()
        while not HasAnimDictLoaded(cfg.anim.dict) do
            Wait(10)
            if GetGameTimer() - t > 4000 then
                print("^1[ERROR]^0 Failed to load anim dict:", cfg.anim.dict)
                return nil
            end
        end
        TaskPlayAnim(ped, cfg.anim.dict, cfg.anim.name, 1.0, 1.0, -1, 1, 0.0, false, false, false)
        print("^2[DEBUG]^0 Animation started successfully:", cfg.anim.dict, cfg.anim.name)
        return "anim"
    end
    
    return nil
end

local function playToolFx(ped, cfg)
    local asset, name = cfg.ptfx.asset, cfg.ptfx.name
    
    -- Safety check: prevent dangerous particle effects
    if not asset or not name then
        print("^1[WARNING]^0 Invalid particle effect config")
        return
    end
    
    -- Check if this is a known dangerous effect
    local dangerousEffects = {
        "ent_ray_meth_fires",  -- disabled due to fire issues
        "ent_anim_construction_dust"  -- disabled due to fire issues
    }
    
    for _, dangerous in ipairs(dangerousEffects) do
        if name == dangerous then
            print("^1[WARNING]^0 Dangerous particle effect detected:", name, "- skipping for safety")
            return
        end
    end
    
    ensurePtfx(asset)
    UseParticleFxAssetNextCall(asset)
    
    -- Attach to the hand so it sits near tool tip; adjust for your offsets/prop
    local bone = GetPedBoneIndex(ped, 57005)
    
    local particleEffect = nil
    
    if name == "ent_amb_sparking_wires" then
        -- Special positioning for mining laser sparking effect
        particleEffect = StartParticleFxLoopedOnEntityBone(name, ped, 0.12, 0.02, 0.0, 0.0, 0.0, 0.0, bone, 1.0, false, false, false)
        print("^2[DEBUG]^0 Laser sparking effect started")
    else
        -- Standard particle positioning for safe effects
        particleEffect = StartParticleFxLoopedOnEntityBone(name, ped, 0.12, 0.02, 0.0, 0.0, 0.0, 0.0, bone, 1.0, false, false, false)
        print("^2[DEBUG]^0 Particle effect started:", name)
    end
    
    -- Store the particle effect for cleanup
    if particleEffect then
        activeParticleEffects[ped] = particleEffect
        print("^3[DEBUG]^0 Stored particle effect for cleanup:", particleEffect)
    end
end

-- Local variable to store tool check results
local toolCheckResults = {}

-- Function to refresh tool check results for all mining tools
local function RefreshMiningToolChecks()
    if Config.Inventory.system == 'ox_inventory' then
        print('^3[DEBUG] Starting tool check refresh...^0')
        local miningTools = {'pickaxe', 'mining_drill', 'mining_laser'}
        
        -- Clear old results before checking
        toolCheckResults = {}
        print('^3[DEBUG] Cleared toolCheckResults^0')
        
        for _, toolName in ipairs(miningTools) do
            print('^3[DEBUG] Triggering server check for:', toolName .. '^0')
            TriggerServerEvent('mining:checkTool', toolName)
        end
        
        -- Wait for responses
        Wait(300)
        print('^3[DEBUG] Tool check refresh complete. Results:', json.encode(toolCheckResults or {}) .. '^0')
        
        -- Debug: Check what tools are available in config
        print('^3[DEBUG] Available tools in config:^0')
        for configKey, configItem in pairs(Config.Inventory.items) do
            print('^3[DEBUG]   Config key:', configKey, 'Item name:', configItem.name .. '^0')
        end
    end
end

-- Function to manually check current tool status (for debugging)
local function CheckCurrentToolStatus()
    print('^3[DEBUG] Current tool status check:^0')
    if toolCheckResults then
        for toolName, hasTool in pairs(toolCheckResults) do
            print('^3[DEBUG]   ' .. toolName .. ':', tostring(hasTool) .. '^0')
        end
    else
        print('^1[DEBUG]   toolCheckResults is nil^0')
    end
end

-- Utility: Get specific spawn coordinate from zone
local function GetSpawnCoordinate(zone, index)
    if zone.spawn_coords and zone.spawn_coords[index] then
        return zone.spawn_coords[index]
    end
    -- Fallback to center coords if no specific spawn coords are defined
    return zone.coords
end

-- Function to give item to player based on inventory system
local function GiveMiningTool(toolType)
    -- Check if this tool exists in config by searching through items
    local itemConfig = nil
    for configKey, configItem in pairs(Config.Inventory.items) do
        if configItem.name == toolType then
            itemConfig = configItem
            break
        end
    end
    
    if not itemConfig then return false end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system - trigger server event to give item
        TriggerServerEvent('mining:giveTool', toolType)
        return true -- We'll handle success/failure on server side
    elseif Config.Inventory.system == 'qb-inventory' then
        -- qb-inventory system
        local success = exports['qb-inventory']:AddItem(itemConfig.name, 1, false, {
            durability = 100,
            level = 1,
            bonus = 0
        })
        return success
    end
    
    return false
end

-- Function to check if player has item
local function HasMiningTool(toolType)
    -- Check if this tool exists in config by searching through items
    local itemConfig = nil
    for configKey, configItem in pairs(Config.Inventory.items) do
        if configItem.name == toolType then
            itemConfig = configItem
            break
        end
    end
    
    if not itemConfig then return false end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system - check stored result
        if toolCheckResults and toolCheckResults[toolType] ~= nil then
            return toolCheckResults[toolType]
        else
            -- If no stored result, trigger server check and return false for now
            TriggerServerEvent('mining:checkTool', toolType)
            return false
        end
    elseif Config.Inventory.system == 'qb-inventory' then
        -- qb-inventory system
        local hasItem = QBCore.Functions.HasItem(itemConfig.name)
        return hasItem
    end
    
    return false
end

local function HasRequiredTool(activity)
    local ped = PlayerPedId()
    local tool = nil
    
    if activity == 'logging' then
        -- For logging, check multiple possible hatchet names
        local hatchetNames = {'weapon_hatchet', 'hatchet', 'axe', 'woodcutter_axe'}
        print('^3[DEBUG] Checking logging tools. Inventory system:', Config.Inventory.system .. '^0')
        
        for _, hatchetName in ipairs(hatchetNames) do
            print('^3[DEBUG] Checking hatchet name:', hatchetName .. '^0')
            
            if Config.Inventory.system == 'ox_inventory' then
                -- Check if this tool exists in config
                local itemConfig = Config.Inventory.items[hatchetName]
                if itemConfig then
                    print('^2[DEBUG] Found item config for:', hatchetName .. '^0')
                    -- Trigger server check for ox_inventory
                    TriggerServerEvent('mining:checkTool', hatchetName)
                    Wait(100)
                    if toolCheckResults and toolCheckResults[hatchetName] then
                        print('^2[DEBUG] Tool check successful for:', hatchetName .. '^0')
                        tool = hatchetName
                        break
                    else
                        print('^1[DEBUG] Tool check failed for:', hatchetName .. '^0')
                    end
                else
                    print('^1[DEBUG] No item config found for:', hatchetName .. '^0')
                end
            elseif Config.Inventory.system == 'qb-inventory' then
                if QBCore.Functions.HasItem(hatchetName) then
                    print('^2[DEBUG] Found item in qb-inventory:', hatchetName .. '^0')
                    tool = hatchetName
                    break
                else
                    print('^1[DEBUG] Item not found in qb-inventory:', hatchetName .. '^0')
                end
            end
        end
        
        -- If no item found, check for weapon
        if not tool then
            for _, hatchetName in ipairs(hatchetNames) do
                if hatchetName:find('weapon_') then
                    local hasWeapon = HasPedGotWeapon(ped, GetHashKey(hatchetName), false)
                    if hasWeapon then
                        tool = hatchetName
                        break
                    end
                end
            end
        end
        
        -- If still no tool found, set default
        if not tool then
            tool = 'weapon_hatchet'
        end
    elseif activity == 'mining' then
        -- For mining, check if player has any of the mining tools
        local miningTools = {'pickaxe', 'mining_drill', 'mining_laser'}
        
        if Config.Inventory.system == 'ox_inventory' then
            -- Debug: Print current tool check results
            print('^3[DEBUG] Current toolCheckResults:', json.encode(toolCheckResults or {}) .. '^0')
            
            -- For ox_inventory, check stored results first
            for _, toolName in ipairs(miningTools) do
                if toolCheckResults and toolCheckResults[toolName] then
                    print('^2[DEBUG] Found tool in stored results:', toolName .. '^0')
                    return true
                end
            end
            
            print('^3[DEBUG] No stored results found, refreshing tool checks...^0')
            
            -- If no stored results, refresh all tool checks
            RefreshMiningToolChecks()
            
            -- Check results again after refresh
            for _, toolName in ipairs(miningTools) do
                if toolCheckResults and toolCheckResults[toolName] then
                    print('^2[DEBUG] Found tool after refresh:', toolName .. '^0')
                    return true
                end
            end
            
            print('^1[DEBUG] No tools found after refresh. toolCheckResults:', json.encode(toolCheckResults or {}) .. '^0')
            QBCore.Functions.Notify('You need a mining tool (pickaxe, mining_drill, or mining_laser) for this activity!', 'error')
            return false
        elseif Config.Inventory.system == 'qb-inventory' then
            -- qb-inventory system
            for _, toolName in ipairs(miningTools) do
                if QBCore.Functions.HasItem(toolName) then
                    return true
                end
            end
            QBCore.Functions.Notify('You need a mining tool (pickaxe, mining_drill, or mining_laser) for this activity!', 'error')
            return false
        end
    elseif activity == 'scavenging' then
        tool = 'weapon_crowbar'
    elseif activity == 'foraging' then
        return true  
    end
    
    if not tool then return true end
    
    -- Check if player has the required tool based on inventory system
    if Config.Inventory.system == 'ox_inventory' then
        -- For ox_inventory, we need to check if the tool exists in the config
        local itemConfig = Config.Inventory.items[tool]
        if itemConfig then
            -- Trigger server check for ox_inventory
            TriggerServerEvent('mining:checkTool', tool)
            -- Wait a bit for the result
            Wait(100)
            -- Check stored result
            if toolCheckResults and toolCheckResults[tool] then
                return true
            end
        end
        -- For weapon tools, we can check if player has the weapon
        if tool:find('weapon_') then
            local hasWeapon = HasPedGotWeapon(ped, GetHashKey(tool), false)
            if hasWeapon then
                return true
            end
        end
    elseif Config.Inventory.system == 'qb-inventory' then
        -- qb-inventory system
        local hasItem = QBCore.Functions.HasItem(tool)
        if hasItem then
            return true
        end
    end
    
    QBCore.Functions.Notify('You need a ' .. tool .. ' for this activity!', 'error')
    return false
end

-- Function to get the best available tool for an activity
local function GetBestAvailableTool(activity)
    local ped = PlayerPedId()
    local bestTool = 'default'
    
    print('^3[DEBUG] GetBestAvailableTool called for activity:', activity .. '^0')
    
    -- Define tool priority (best to worst)
    local toolPriority = {'mining_laser', 'mining_drill', 'pickaxe'}
    
    if activity == 'logging' then
        -- For logging, check multiple possible hatchet names
        local hatchetNames = {'weapon_hatchet', 'hatchet', 'axe', 'woodcutter_axe'}
        
        -- First check for items in inventory
        for _, hatchetName in ipairs(hatchetNames) do
            if Config.Inventory.system == 'ox_inventory' then
                local itemConfig = Config.Inventory.items[hatchetName]
                if itemConfig then
                    TriggerServerEvent('mining:checkTool', hatchetName)
                    Wait(100)
                    if toolCheckResults and toolCheckResults[hatchetName] then
                        return hatchetName
                    end
                end
            elseif Config.Inventory.system == 'qb-inventory' then
                if QBCore.Functions.HasItem(hatchetName) then
                    return hatchetName
                end
            end
        end
        
        -- Then check for weapons
        for _, hatchetName in ipairs(hatchetNames) do
            if hatchetName:find('weapon_') then
                if HasPedGotWeapon(ped, GetHashKey(hatchetName), false) then
                    return hatchetName
                end
            end
        end
        
        return 'default'
    elseif activity == 'mining' then
        -- For mining, check tools in priority order
        print('^3[DEBUG] Current toolCheckResults:', json.encode(toolCheckResults or {}) .. '^0')
        
        for _, tool in ipairs(toolPriority) do
            print('^3[DEBUG] Checking tool:', tool .. '^0')
            if Config.Inventory.system == 'ox_inventory' then
                -- Check if this tool exists in config by searching through items
                local itemConfig = nil
                for configKey, configItem in pairs(Config.Inventory.items) do
                    if configItem.name == tool then
                        itemConfig = configItem
                        break
                    end
                end
                
                if itemConfig then
                    print('^3[DEBUG] Tool found in config:', tool .. '^0')
                    -- Check if player has this tool using stored results
                    if toolCheckResults and toolCheckResults[tool] then
                        print('^2[DEBUG] Found best tool:', tool .. '^0')
                        return tool
                    else
                        print('^3[DEBUG] Tool not found in toolCheckResults:', tool, toolCheckResults and toolCheckResults[tool] or 'nil' .. '^0')
                    end
                else
                    print('^1[DEBUG] Tool not found in config:', tool .. '^0')
                end
            elseif Config.Inventory.system == 'qb-inventory' then
                if QBCore.Functions.HasItem(tool) then
                    return tool
                end
            end
        end
        print('^1[DEBUG] No tools found, returning default^0')
        return 'default'
    elseif activity == 'scavenging' then
        -- For scavenging, check weapon_crowbar first
        if HasPedGotWeapon(ped, GetHashKey('weapon_crowbar'), false) then
            return 'weapon_crowbar'
        end
        return 'default'
    elseif activity == 'foraging' then
        -- Foraging doesn't require tools
        return 'default'
    end
    
    return 'default'
end

-- Function to get the most recently used tool (for better tool switching)
local function GetMostRecentTool(activity)
    if Config.Inventory.system == 'ox_inventory' then
        -- Check stored results first
        if toolCheckResults then
            print('^3[DEBUG] GetMostRecentTool called for activity:', activity .. '^0')
            
            -- Return the first available tool (most recently checked)
            for toolType, hasTool in pairs(toolCheckResults) do
                if hasTool then
                    print('^2[DEBUG] Found most recent tool:', toolType .. '^0')
                    return toolType
                end
            end
        end
        
        print('^3[DEBUG] No tools found in stored results^0')
        return nil
    else
        -- For qb-inventory, use the existing logic
        local Player = QBCore.Functions.GetPlayerData()
        if Player and Player.items then
            for _, item in pairs(Player.items) do
                if item.name == 'pickaxe' then
                    return 'pickaxe'
                end
            end
        end
        return nil
    end
end

-- Function to get the player's preferred tool (allows manual selection)
local function GetPlayerPreferredTool(activity)
    if activity == 'mining' then
        -- For mining, always do a real-time check to get the current tool
        if Config.Inventory.system == 'ox_inventory' then
            print('^3[DEBUG] Doing real-time tool check for mining...^0')
            
            -- Force refresh tool checks to get current inventory state
            RefreshMiningToolChecks()
            
            -- Wait a bit for the server responses
            Wait(500)
            
            -- Now check what tools are available
            local availableTools = {}
            for toolType, hasTool in pairs(toolCheckResults or {}) do
                if hasTool then
                    table.insert(availableTools, toolType)
                    print('^3[DEBUG] Found available tool:', toolType .. '^0')
                end
            end
            
            if #availableTools > 0 then
                -- Use the first available tool (most recently acquired)
                local selectedTool = availableTools[1]
                print('^2[DEBUG] Selected tool for mining:', selectedTool .. '^0')
                return selectedTool
            else
                print('^1[WARNING] No mining tools found in real-time check^0')
            end
        end
    end
    
    -- Fall back to best available tool
    return GetBestAvailableTool(activity)
end

-- Function to check cooldown
local function CheckCooldown(activity)
    if cooldowns[activity] and cooldowns[activity] > GetGameTimer() then
        local timeLeft = math.ceil((cooldowns[activity] - GetGameTimer()) / 1000)
        QBCore.Functions.Notify('You need to wait ' .. timeLeft .. ' seconds before doing this again!', 'error')
        return false
    end
    return true
end

-- Function to set cooldown
local function SetCooldown(activity)
    cooldowns[activity] = GetGameTimer() + (Config.Cooldowns[activity] * 1000)
end

-- Show progress bar
local function ShowHarvestProgressBar(activity, toolType, cb)
    print('^3[DEBUG] ShowHarvestProgressBar called with:', activity, toolType .. '^0')
    
    local progress = Config.ProgressBar[activity]
    if not progress then 
        print('^1[DEBUG] No progress config found for activity:', activity .. '^0')
        return cb() 
    end
    
    print('^3[DEBUG] Progress config found:', json.encode(progress) .. '^0')
    
    local ped = PlayerPedId()
    local propEntity = nil
    
    -- Check if we should use the new tool system for mining
    if activity == 'mining' and toolType then
        print('^3[DEBUG] Using new tool system for:', toolType .. '^0')
        
        local cfg = getToolConfig(toolType)
        if not cfg then
            print('^1[ERROR]^0 Failed to get tool config for:', toolType .. '^0')
            return cb()
        end
        
        local duration = cfg.duration
        
        -- Attach tool prop
        propEntity = attachToolProp(ped, cfg.prop)
        if propEntity then
            print('^2[DEBUG] Tool prop attached successfully^0')
        end
        
        -- Start scenario or animation
        local played = startScenarioOrAnim(ped, cfg)
        if played then
            print('^2[DEBUG] Started', played, 'for tool:', toolType .. '^0')
        end
        
        -- Wait a moment to ensure pose/scenario is set before FX
        Wait(150)
        
        -- Start particle effects
        playToolFx(ped, cfg)
        
        -- Show progress bar
        print('^3[DEBUG] Starting progress bar with duration:', duration, 'and label:', progress.label .. '^0')
        
        -- Check if ox_lib is available
        if not lib or not lib.progressBar then
            print('^1[ERROR] ox_lib.progressBar is not available!^0')
            -- Fallback to simple progress
            Wait(duration)
            cb()
            return
        end
        
        local success = lib.progressBar({
            duration = duration,
            label = progress.label,
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = true,
                car = true,
                combat = true,
                mouse = false,
            },
        })
        
        print('^3[DEBUG] Progress bar result:', tostring(success) .. '^0')
        
        -- Clean up
        ClearPedTasks(ped)
        if propEntity and DoesEntityExist(propEntity) then
            DeleteEntity(propEntity)
        end
        
        -- Stop particle effects
        stopAllParticleEffects(ped)
        
        -- Handle result
        if success then
            print('^2[DEBUG] Progress bar successful, executing callback^0')
            cb()
        else
            print('^1[DEBUG] Progress bar failed or cancelled^0')
            -- Execute callback anyway to prevent getting stuck
            print('^3[DEBUG] Executing callback despite progress bar failure to prevent mining loop^0')
            cb()
            
            if lib and lib.notify then
                lib.notify({
                    title = 'Material',
                    description = 'Cancelled',
                    type = 'error'
                })
            else
                QBCore.Functions.Notify('Mining cancelled', 'error')
            end
        end
        
        return
    end
    
        -- Fallback to old system for non-mining activities or if tool config not found
    print('^3[DEBUG] Using fallback animation system for non-mining activity^0')
    
    local anim = Config.Animations[activity]
    if not anim then
        print('^1[DEBUG] No animation config found for activity:', activity .. '^0')
        return cb()
    end
    
    print('^3[DEBUG] Animation config found:', json.encode(anim) .. '^0')
    print('^3[DEBUG] Tool type received:', tostring(toolType) .. '^0')
    
    -- Use default duration for non-mining activities
    local duration = progress.duration

    -- Use default prop for non-mining activities
    local propToUse = anim.prop
    
    if propToUse then
        print('^3[DEBUG] Creating prop:', propToUse .. '^0')
        local propHash = GetHashKey(propToUse)
        RequestModel(propHash)
        
        -- Wait for model to load (simplified, no timeout)
        local modelLoadTimeout = 0
        while not HasModelLoaded(propHash) and modelLoadTimeout < 100 do 
            Wait(10)
            modelLoadTimeout = modelLoadTimeout + 1
        end
        
        if HasModelLoaded(propHash) then
            print('^2[DEBUG] Model loaded successfully^0')
            local coords = GetEntityCoords(ped)
            propEntity = CreateObject(propHash, coords.x, coords.y, coords.z + 0.2, true, true, true)
            
            if propEntity and DoesEntityExist(propEntity) then
                print('^2[DEBUG] Prop created successfully^0')
                -- Use default prop positioning for non-mining activities
                AttachEntityToEntity(propEntity, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.03, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
                print('^2[DEBUG] Prop attached to right hand^0')
            else
                print('^1[ERROR] Failed to create prop entity^0')
            end
        else
            print('^1[ERROR] Failed to load prop model:', propToUse .. '^0')
            -- Don't let prop failure stop the mining process
            print('^3[DEBUG] Continuing without prop^0')
        end
    else
        print('^3[DEBUG] No prop to create^0')
    end

    -- Play animation if specified (tool-specific or default)
    local animDict, animName
    
    if toolType and anim.toolAnimations and anim.toolAnimations[toolType] then
        -- Use tool-specific animation
        local toolAnim = anim.toolAnimations[toolType]
        animDict = toolAnim.dict
        animName = toolAnim.anim
        print('^3[DEBUG] Using tool-specific animation for', toolType .. ':', animDict, animName .. '^0')
    elseif toolType == 'mining_drill' and anim.toolAnimations and anim.toolAnimations.drill then
        -- Handle mining_drill -> drill mapping
        local toolAnim = anim.toolAnimations.drill
        animDict = toolAnim.dict
        animName = toolAnim.anim
        print('^3[DEBUG] Using mining_drill animation (drill):', animDict, animName .. '^0')
    elseif toolType == 'mining_laser' and anim.toolAnimations and anim.toolAnimations.laser then
        -- Handle mining_laser -> laser mapping
        local toolAnim = anim.toolAnimations.laser
        animDict = toolAnim.dict
        animName = toolAnim.anim
        print('^3[DEBUG] Using mining_laser animation (laser):', animDict, animName .. '^0')
    else
        -- Use default animation
        animDict = anim.dict
        animName = anim.anim
        print('^3[DEBUG] Using default animation:', animDict, animName .. '^0')
    end
    
    if animDict and animName then
        print('^3[DEBUG] Loading animation:', animDict, animName .. '^0')
        RequestAnimDict(animDict)
        
        local animLoadTimeout = 0
        while not HasAnimDictLoaded(animDict) and animLoadTimeout < 100 do 
            Wait(10)
            animLoadTimeout = animLoadTimeout + 1
        end
        
        if HasAnimDictLoaded(animDict) then
            print('^2[DEBUG] Animation loaded successfully^0')
            TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
            print('^2[DEBUG] Animation started^0')
        else
            print('^1[ERROR] Failed to load animation dictionary:', animDict .. '^0')
            print('^3[DEBUG] Falling back to default mining animation^0')
            -- Fallback to default mining animation if tool-specific animation fails
            local fallbackDict = "melee@large_wpn@streamed_core"
            local fallbackAnim = "ground_attack_on_spot"
            
            RequestAnimDict(fallbackDict)
            local fallbackTimeout = 0
            while not HasAnimDictLoaded(fallbackDict) and fallbackTimeout < 100 do 
                Wait(10)
                fallbackTimeout = fallbackTimeout + 1
            end
            
            if HasAnimDictLoaded(fallbackDict) then
                print('^2[DEBUG] Fallback animation loaded successfully^0')
                TaskPlayAnim(ped, fallbackDict, fallbackAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
                print('^2[DEBUG] Fallback animation started^0')
            else
                print('^1[ERROR] Failed to load fallback animation^0')
            end
        end
    else
        print('^3[DEBUG] No animation specified^0')
    end

    -- Show ox_lib progress bar
    print('^3[DEBUG] Starting progress bar with duration:', duration, 'and label:', progress.label .. '^0')
    
    -- Check if ox_lib is available
    if not lib or not lib.progressBar then
        print('^1[ERROR] ox_lib.progressBar is not available!^0')
        -- Fallback to simple progress
        Wait(duration)
        cb()
        return
    end
    
    local success = lib.progressBar({
        duration = duration,
        label = progress.label,
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },
    })
    
    print('^3[DEBUG] Progress bar result:', tostring(success) .. '^0')

    -- Clean up
    ClearPedTasks(ped)
    if propEntity and DoesEntityExist(propEntity) then
        DeleteEntity(propEntity)
    end
    
    -- Stop particle effects
    stopAllParticleEffects(ped)

    -- Handle result
    if success then
        print('^2[DEBUG] Progress bar successful, executing callback^0')
        cb()
    else
        print('^1[DEBUG] Progress bar failed or cancelled^0')
        -- Execute callback anyway to prevent getting stuck
        print('^3[DEBUG] Executing callback despite progress bar failure to prevent mining loop^0')
        cb()
        
        if lib and lib.notify then
            lib.notify({
                title = 'Material',
                description = 'Cancelled',
                type = 'error'
            })
        else
            QBCore.Functions.Notify('Mining cancelled', 'error')
        end
    end
end

-- Prop management
local spawnedProps = {}
local propStates = {}

-- Table to track animated props
local animatedProps = {}

-- Play particle effect at a location, using the correct particle for the activity and tool
local function PlayHarvestEffect(coords, activity, toolType)
    local particle = Config.Animations[activity] and Config.Animations[activity].particle
    
    print('^3[DEBUG] PlayHarvestEffect called for activity:', activity, 'toolType:', tostring(toolType) .. '^0')
    print('^3[DEBUG] Default particle:', json.encode(particle) .. '^0')
    
    -- Check if we should use the new tool system for mining
    if activity == 'mining' and toolType and TOOL_CONFIG[toolType] then
        print('^3[DEBUG] Using new tool system particles for:', toolType .. '^0')
        local cfg = TOOL_CONFIG[toolType]
        particle = cfg.ptfx
        print('^3[DEBUG] Using tool-specific particle from new system:', cfg.ptfx.name .. '^0')
    else
        -- Debug: Show available tool-specific configurations
        if Config.Animations[activity] and Config.Animations[activity].toolAnimations then
            print('^3[DEBUG] Available tool animations for', activity .. ':', json.encode(Config.Animations[activity].toolAnimations) .. '^0')
        end
        
        -- Check for tool-specific particle effects
        if toolType and Config.Animations[activity] and Config.Animations[activity].toolAnimations and Config.Animations[activity].toolAnimations[toolType] then
            local toolAnim = Config.Animations[activity].toolAnimations[toolType]
            print('^3[DEBUG] Found tool animation config for', toolType .. ':', json.encode(toolAnim) .. '^0')
            
            if toolAnim.particle and toolAnim.particle.asset and toolAnim.particle.name then
                particle = toolAnim.particle
                print('^3[DEBUG] Using tool-specific particle for', toolType .. ':', toolAnim.particle.name .. '^0')
            else
                print('^1[WARNING] Tool animation found but no particle config for', toolType .. '^0')
            end
        elseif toolType == 'mining_drill' and Config.Animations[activity] and Config.Animations[activity].toolAnimations and Config.Animations[activity].toolAnimations.drill then
            -- Handle mining_drill -> drill mapping for particles
            local toolAnim = Config.Animations[activity].toolAnimations.drill
            print('^3[DEBUG] Found mining_drill animation config (drill):', json.encode(toolAnim) .. '^0')
            
            if toolAnim.particle and toolAnim.particle.asset and toolAnim.particle.name then
                particle = toolAnim.particle
                print('^3[DEBUG] Using mining_drill particle (drill):', toolAnim.particle.name .. '^0')
            else
                print('^1[WARNING] Mining drill animation found but no particle config^0')
            end
        elseif toolType == 'mining_laser' and Config.Animations[activity] and Config.Animations[activity].toolAnimations and Config.Animations[activity].toolAnimations.laser then
            -- Handle mining_laser -> laser mapping for particles
            local toolAnim = Config.Animations[activity].toolAnimations.laser
            print('^3[DEBUG] Found mining_laser animation config (laser):', json.encode(toolAnim) .. '^0')
            
            if toolAnim.particle and toolAnim.particle.asset and toolAnim.particle.name then
                particle = toolAnim.particle
                print('^3[DEBUG] Using mining_laser particle (laser):', toolAnim.particle.name .. '^0')
            else
                print('^1[WARNING] Mining laser animation found but no particle config^0')
            end
        else
            print('^3[DEBUG] No tool-specific animation found for', tostring(toolType) .. '^0')
        end
    end
    
    if particle and particle.asset and particle.name then
        print('^3[DEBUG] Attempting to play particle effect:', particle.asset, particle.name .. '^0')
        UseParticleFxAssetNextCall(particle.asset)
        
        -- Special positioning for mining laser flame effect
        if toolType == 'mining_laser' and particle.name == 'ent_ray_meth_fires' then
            -- Position flame effect at the tip of the blow torch (slightly forward and up)
            StartParticleFxNonLoopedAtCoord(particle.name, coords.x + 0.5, coords.y, coords.z + 0.8, 0.0, 0.0, 0.0, 1.0, false, false, false)
            print('^2[DEBUG] Blow torch flame effect positioned at torch tip^0')
        else
            -- Standard particle positioning
            StartParticleFxNonLoopedAtCoord(particle.name, coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
        end
        
        print('^2[DEBUG] Particle effect started successfully^0')
    else
        -- fallback
        print('^1[WARNING] No valid particle config, using fallback^0')
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('ent_sht_plant', coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
        print('^3[DEBUG] Using fallback particle effect^0')
    end
    
    -- Play tool-specific sounds
    if toolType == 'mining_drill' then
        PlaySoundFromCoord(-1, 'Drill_Pin_Break', coords.x, coords.y, coords.z, '', false, 0, false)
        print('^3[DEBUG] Playing drill sound^0')
    elseif toolType == 'mining_laser' then
        PlaySoundFromCoord(-1, 'Drill_Pin_Break', coords.x, coords.y, coords.z, '', false, 0, false)
        print('^3[DEBUG] Playing laser/welding sound^0')
    else
        -- Default pickaxe sound
        PlaySoundFromCoord(-1, 'Pickup_Collect', coords.x, coords.y, coords.z, '', false, 0, false)
        print('^3[DEBUG] Playing pickaxe sound^0')
    end
end

-- Play smelting effect at smelting center
local function PlaySmeltingEffect()
    local c = Config.RecyclingCenter.coords
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_dst_gen_garbage', c.x, c.y, c.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    PlaySoundFromCoord(-1, 'Drill_Pin_Break', c.x, c.y, c.z, '', false, 0, false)
end

-- Smelting center functionality
local function OpenSmeltingMenu()
    local Player = QBCore.Functions.GetPlayerData()
    local items = {}
    
    -- For ox_inventory, we need to get items from server
    if Config.Inventory.system == 'ox_inventory' then
        TriggerServerEvent('mining:getRecyclableItems')
        return
    end
    
    -- For qb-inventory, use the existing logic
    for _, item in pairs(Player.items) do
        if Config.RecyclingCenter.inputs[item.name] then
            local count = exports['ox_inventory']:GetItemCount(item.name)
            if count > 0 then
                table.insert(items, {
                    title = item.label,
                    description = 'Amount: ' .. count,
                    icon = 'box',
                    onSelect = function()
                        local input = lib.inputDialog('Recycle ' .. item.label, {
                            {type = 'number', label = 'Amount to recycle', description = 'You have ' .. count .. ' available', default = 1, min = 1, max = count}
                        })
                        if input then
                            local amount = input[1]
                            if amount and amount > 0 and amount <= count then
                                -- Start smelting process (no more risky system)
                                TriggerServerEvent('resource:smelt', item.name, amount)
                            else
                                QBCore.Functions.Notify('Invalid amount!', 'error')
                            end
                        end
                    end
                })
            end
        end
    end
    
    if #items == 0 then
        QBCore.Functions.Notify('You don\'t have any items to smelt!', 'error')
        return
    end
    
    lib.registerContext({
        id = 'recycling_menu',
        title = 'Smelting Center',
        options = items
    })
    
    lib.showContext('recycling_menu')
end

-- Create smelting center
local function CreateSmeltingCenter()
    exports['ox_target']:addBoxZone({
        coords = Config.RecyclingCenter.coords,
        size = vector3(2, 2, 2),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'recycling_center',
                icon = 'fa-solid fa-recycle',
                label = 'Smelt Materials',
                onSelect = function()
                    if not CheckCooldown('smelting') then return end
                    OpenSmeltingMenu()
                end,
                distance = 2.0,
            }
        }
    })
end

-- Create second smelting center with ped
local function CreateSmeltingCenter2()
    -- Create the ped
    local pedModel = `s_m_m_autoshop_02` -- Mechanic ped
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(10)
    end
    
    local ped = CreatePed(4, pedModel, Config.SmeltingCenter2.coords.x, Config.SmeltingCenter2.coords.y, Config.SmeltingCenter2.coords.z - 1.0, Config.SmeltingCenter2.heading, false, true)
    SetEntityHeading(ped, Config.SmeltingCenter2.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Add target interaction to the ped
    exports['ox_target']:addLocalEntity(ped, {
        {
            name = 'smelting_center_2',
            icon = 'fa-solid fa-fire',
            label = 'Talk to Miner',
            onSelect = function()
                -- Open the mining UI instead of smelting
                SendNUIMessage({
                    type = 'showMiningUI'
                })
                SetNuiFocus(true, true)
            end,
            distance = 2.0,
        }
    })
    
    print('^2[DEBUG]^0 Second smelting center ped created at:', Config.SmeltingCenter2.coords.x, Config.SmeltingCenter2.coords.y, Config.SmeltingCenter2.coords.z .. '^0')
end

-- Blip creation
local function CreateGatheringBlips()
    -- Create blips for foraging and logging zones
    for activity, zones in pairs(Config.Zones) do
        if activity == 'foraging' or activity == 'logging' then
            for _, zone in ipairs(zones) do
                if zone.blip and zone.blip.enabled then
                    local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
                    SetBlipSprite(blip, zone.blip.sprite)
                    SetBlipDisplay(blip, 4)
                    SetBlipScale(blip, zone.blip.scale)
                    SetBlipColour(blip, zone.blip.color)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(zone.blip.label)
                    EndTextCommandSetBlipName(blip)
                    print('^2[DEBUG] ' .. activity .. ' blip created at:', zone.coords.x, zone.coords.y, zone.coords.z .. '^0')
                end
            end
        end
    end
    
    -- Create smelting center blip
    if Config.RecyclingCenter and Config.RecyclingCenter.blip and Config.RecyclingCenter.blip.enabled then
        local c = Config.RecyclingCenter.coords
        local blipCfg = Config.RecyclingCenter.blip
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, blipCfg.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, blipCfg.scale)
        SetBlipColour(blip, blipCfg.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipCfg.label)
        EndTextCommandSetBlipName(blip)
        print('^2[DEBUG] Smelting center blip created at:', c.x, c.y, c.z .. '^0')
    end
end

-- Function to spawn props for a merged zone
local function SpawnPropsForMergedZone(mergedZone, zoneId)
    if zoneProps[zoneId] then return end -- Props already spawned
    zoneProps[zoneId] = {}

    for _, z in ipairs(mergedZone.zones) do
        local activity = z.activity
        local zone = z.zone
        local zoneIndex = z.originalIndex
        local settings = Config.PropSettings[activity]
        if not settings then goto continue end

        local spawnCount = zone.spawn_coords and #zone.spawn_coords or settings.count
        for i = 1, spawnCount do
            local propId = activity .. '_' .. zoneIndex .. '_' .. i
            local pos = zone.spawn_coords[i] -- Use spawn_coords directly
            local model = settings.model
                    -- Capture zone data locally to avoid closure issues
        local capturedZone = zone
        local capturedActivity = activity
        local capturedZoneIndex = zoneIndex
        
        -- Debug: Validate captured data
        if not capturedZone then
            print('^1[ERROR] Zone is nil for activity ' .. tostring(activity) .. '^0')
            goto continue
        end
        if not capturedActivity then
            print('^1[ERROR] Activity is nil for zone ' .. tostring(zone) .. '^0')
            goto continue
        end
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(10) end

            -- Ensure proper ground positioning
            local ground, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 100.0, 0)
            if ground then
                pos = vector3(pos.x, pos.y, groundZ)
            else
                pos = vector3(pos.x, pos.y, pos.z - (settings.zFallback or 1.0))
            end

            local obj = CreateObject(model, pos.x, pos.y, pos.z, false, false, false)
            local minDim, maxDim = GetModelDimensions(model)
            local bottomOffset = minDim.z
            local objPos = GetEntityCoords(obj)
            SetEntityCoords(obj, objPos.x, objPos.y, objPos.z - bottomOffset, false, false, false, true)
            PlaceObjectOnGroundProperly(obj)
            SetEntityRotation(obj, 0.0, 0.0, math.random(0, 359) * 1.0, 2, true)
            FreezeEntityPosition(obj, true)
            SetEntityAsMissionEntity(obj, true, true)

            spawnedProps[propId] = obj
            propStates[propId] = true
            animatedProps[propId] = obj
            zoneProps[zoneId][propId] = obj

            exports['ox_target']:addLocalEntity(obj, {
                {
                    name = propId,
                    icon = 'fa-leaf',
                    label = 'Harvest',
                    onSelect = function()
                        if not propStates[propId] then return end
                        if not capturedActivity or not capturedZone then return end
                        if not HasRequiredTool(capturedActivity) then return end
                        if not CheckCooldown(capturedActivity) then return end
                        
                        local bestTool = GetPlayerPreferredTool(capturedActivity)
                        local capturedToolType = bestTool -- Capture tool type for closure
                        
                        ShowHarvestProgressBar(capturedActivity, bestTool, function()
                            propStates[propId] = false
                            SetEntityVisible(obj, false, false)
                            SetEntityCollision(obj, false, false)
                            animatedProps[propId] = nil
                            PlayHarvestEffect(GetEntityCoords(obj), capturedActivity, capturedToolType)
                            TriggerServerEvent('resource:gather', capturedActivity, capturedZone)
                            SetCooldown(capturedActivity)
                            Citizen.SetTimeout(15000, function()
                                if not capturedZone or not capturedZone.spawn_coords or not capturedZone.spawn_coords[i] then
                                    print('^1[ERROR] Invalid zone data for prop ' .. propId .. '^0')
                                    return
                                end
                                
                                if DoesEntityExist(obj) then
                                    DeleteEntity(obj)
                                    zoneProps[zoneId][propId] = nil
                                end
                                local newPos = capturedZone.spawn_coords[i] -- Use same spawn_coords
                                local ground, groundZ = GetGroundZFor_3dCoord(newPos.x, newPos.y, newPos.z + 100.0, 0)
                                if ground then
                                    newPos = vector3(newPos.x, newPos.y, groundZ)
                                else
                                    newPos = vector3(newPos.x, newPos.y, newPos.z - (settings.zFallback or 1.0))
                                end
                                RequestModel(model)
                                while not HasModelLoaded(model) do Wait(10) end
                                local newObj = CreateObject(model, newPos.x, newPos.y, newPos.z, false, false, false)
                                PlaceObjectOnGroundProperly(newObj)
                                FreezeEntityPosition(newObj, true)
                                SetEntityAsMissionEntity(newObj, true, true)
                                spawnedProps[propId] = newObj
                                propStates[propId] = true
                                animatedProps[propId] = newObj
                                zoneProps[zoneId][propId] = newObj
                                exports['ox_target']:addLocalEntity(newObj, {
                                    {
                                        name = propId,
                                        icon = 'fa-leaf',
                                        label = 'Harvest',
                                        distance = 2.0,
                                        onSelect = function()
                                            if not propStates[propId] then return end
                                            if not capturedActivity or not capturedZone then 
                                                print('^1[ERROR] Captured data is nil for prop ' .. propId .. '^0')
                                                return 
                                            end
                                            if not HasRequiredTool(capturedActivity) then return end
                                            if not CheckCooldown(capturedActivity) then return end
                                            
                                            local bestTool = GetPlayerPreferredTool(capturedActivity)
                                            local capturedToolType = bestTool -- Capture tool type for closure
                                            
                                            ShowHarvestProgressBar(capturedActivity, bestTool, function()
                                                propStates[propId] = false
                                                SetEntityVisible(newObj, false, false)
                                                SetEntityCollision(newObj, false, false)
                                                animatedProps[propId] = nil
                                                PlayHarvestEffect(GetEntityCoords(newObj), capturedActivity, capturedToolType)
                                                TriggerServerEvent('resource:gather', capturedActivity, capturedZone)
                                                SetCooldown(capturedActivity)
                                 end)
                                        end
                                    }
                                })
                            end)
                        end)
                    end
                }
            })
        end
        ::continue::
    end
end

-- Function to despawn props for a merged zone
local function DespawnPropsForMergedZone(zoneId)
    if not zoneProps[zoneId] then return end
    for propId, obj in pairs(zoneProps[zoneId]) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
        spawnedProps[propId] = nil
        propStates[propId] = nil
        animatedProps[propId] = nil
        exports['ox_target']:removeLocalEntity(obj)
    end
    zoneProps[zoneId] = nil
end

-- Function to calculate distance between two 3D points
local function GetDistanceBetweenCoords(pos1, pos2)
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

-- Function to merge nearby zones
local function MergeNearbyZones()
    local tempZones = {}
    local defaultMergeRadius = 200.0 -- Reduced from 200.0 to avoid overly large zones

    -- Validate and collect zones
    for activity, zones in pairs(Config.Zones) do
        for i, zone in ipairs(zones) do
            if not zone.coords or not zone.coords.x or not zone.coords.y or not zone.coords.z then
                -- print(('Error: Invalid coords for %s zone %s'):format(activity, i))
                goto continue
            end
            local radius = Config.PropSettings[activity] and Config.PropSettings[activity].radius or 25.0
            table.insert(tempZones, {
                activity = activity,
                zone = zone,
                originalIndex = i,
                coords = vector3(zone.coords.x, zone.coords.y, zone.coords.z),
                radius = radius
            })
            ::continue::
        end
    end

    local merged = {}
    local processed = {}

    -- Merge zones within defaultMergeRadius
    for i, z1 in ipairs(tempZones) do
        if not processed[i] then
            local group = { zones = {{ activity = z1.activity, zone = z1.zone, originalIndex = z1.originalIndex }}, coords = z1.coords, radius = z1.radius }
            processed[i] = true

            for j, z2 in ipairs(tempZones) do
                if not processed[j] and i ~= j then
                    local dist = GetDistanceBetweenCoords(z1.coords, z2.coords)
                    if dist <= (Config.MergeRadius or defaultMergeRadius) then
                        table.insert(group.zones, { activity = z2.activity, zone = z2.zone, originalIndex = z2.originalIndex })
                        processed[j] = true
                        group.coords = group.coords + vector3(z2.coords.x, z2.coords.y, z2.coords.z)
                        group.radius = math.max(group.radius, z2.radius)
                    end
                end
            end

            -- Finalize coords by averaging
            group.coords = group.coords / #group.zones
            -- Adjust radius to encompass all zones
            for _, z in ipairs(group.zones) do
                local dist = GetDistanceBetweenCoords(group.coords, vector3(z.zone.coords.x, z.zone.coords.y, z.zone.coords.z))
                group.radius = math.max(group.radius, dist + (Config.PropSettings[z.activity] and Config.PropSettings[z.activity].radius or 25.0))
            end

            table.insert(merged, group)
        end
    end

    -- Debug output
    -- print(('Merged %s zones'):format(#merged))
    -- for i, group in ipairs(merged) do
    --     print(('Merged zone %s: coords=%s, radius=%s, zones=%s'):format(i, group.coords, group.radius, #group.zones))
    --     for _, z in ipairs(group.zones) do
    --         print(('  Activity=%s, coords=%s'):format(z.activity, z.zone.coords))
    --     end
    -- end

    return merged
end

-- Function to initialize sphere zones
local function InitializeSphereZones()
    if #activeZones > 0 then
        -- print('Error: Active zones already initialized')
        return
    end
    mergedZones = MergeNearbyZones()
    if #mergedZones == 0 then
        -- print('Error: No valid zones to initialize')
        return
    end

    for i, mergedZone in ipairs(mergedZones) do
        local zoneId = 'merged_zone_' .. i
        -- Validate coords and radius
        if not mergedZone.coords or not mergedZone.coords.x or not mergedZone.coords.y or not mergedZone.coords.z then
            -- print(('Error: Invalid coords for merged zone %s'):format(zoneId))
            goto continue
        end
        if not mergedZone.radius or mergedZone.radius <= 0 then
            -- print(('Error: Invalid radius for merged zone %s'):format(zoneId))
            mergedZone.radius = 25.0 -- Fallback radius
        end

        -- print(('Creating zone %s: coords=%s, radius=%s'):format(zoneId, mergedZone.coords, mergedZone.radius))
        local zone = lib.zones.sphere({
            coords = mergedZone.coords,
            radius = mergedZone.radius,
            debug = false,
            onEnter = function()
                -- print(('Entered zone %s'):format(zoneId))
                SpawnPropsForMergedZone(mergedZone, zoneId)
            end,
            onExit = function()
                -- print(('Exited zone %s'):format(zoneId))
                DespawnPropsForMergedZone(zoneId)
            end
        })
        activeZones[zoneId] = zone
        ::continue::
    end
end

-- Initialize zones and blips when resource starts
CreateThread(function()
    CreateGatheringBlips()
    CreateSmeltingCenter()
    CreateSmeltingCenter2()
    InitializeSphereZones()
end)

-- (Optional) Clean up props on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(spawnedProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function ()
    InitializeSphereZones()
end)

-- Play smelting effect when smelting
RegisterNetEvent('resource:smeltEffect', function()
    PlaySmeltingEffect()
end)

-- New smelting progress bar system
RegisterNetEvent('resource:startSmelting', function(data)
    local itemName = data.itemName
    local amount = data.amount
    local duration = data.duration
    local output = data.output
    local playerLevel = data.playerLevel
    
    print('^3[DEBUG] Starting smelting process - Item:', itemName, 'Amount:', amount, 'Duration:', duration, 'Level:', playerLevel .. '^0')
    
    -- Loop through smelting each item individually
    local function smeltNextItem(currentIndex)
        if currentIndex > amount then
            -- All items smelted, complete the process
            print('^2[DEBUG] All items smelted successfully^0')
            TriggerServerEvent('resource:completeSmelting', itemName, amount, output, playerLevel)
            return
        end
        
        -- Show progress bar for current item
        local label = string.format('Smelting %s (%d/%d)...', itemName, currentIndex, amount)
        print('^3[DEBUG] Starting smelting for item', currentIndex, 'of', amount .. '^0')
        
        if lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
            anim = {
                dict = 'amb@world_human_welding@male@base',
                clip = 'base'
            },
        }) then
            -- Progress bar completed successfully for this item
            print('^2[DEBUG] Smelting completed for item', currentIndex, 'of', amount .. '^0')
            
            -- Move to next item
            smeltNextItem(currentIndex + 1)
        else
            -- Progress bar was cancelled
            print('^1[DEBUG] Smelting cancelled at item', currentIndex, 'of', amount .. '^0')
            QBCore.Functions.Notify('Smelting cancelled!', 'error')
        end
    end
    
    -- Start smelting the first item
    smeltNextItem(1)
end)

-- UI Integration Functions
local function OpenResourceGatheringUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showUI'
    })
end

local function CloseResourceGatheringUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideUI'
    })
end

-- Command to open the UI
RegisterCommand('resourcegathering', function()
    OpenResourceGatheringUI()
end, false)

-- Key binding (F6 by default)
RegisterKeyMapping('resourcegathering', 'Open Resource Gathering UI', 'keyboard', 'F6')

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    CloseResourceGatheringUI()
    cb('ok')
end)

RegisterNUICallback('startGathering', function(data, cb)
    local activity = data.activity
    local zoneIndex = data.zoneIndex
    
    -- Check if player is in a valid gathering zone
    local playerCoords = GetEntityCoords(PlayerPedId())
    local inZone = false
    
    for zoneId, zone in pairs(activeZones) do
        local zoneCoords = zone.coords
        local distance = #(playerCoords - zoneCoords)
        if distance <= zone.radius then
            inZone = true
            break
        end
    end
    
    if not inZone then
        QBCore.Functions.Notify('You must be in a gathering zone to start!', 'error')
        cb('error')
        return
    end
    
    -- Start the gathering process
    StartGatheringProcess(activity, zoneIndex)
    cb('ok')
end)

RegisterNUICallback('startRecycling', function(data, cb)
    local item = data.item
    local amount = data.amount
    
    -- Check if player is at recycling center
    local playerCoords = GetEntityCoords(PlayerPedId())
    local recyclingCenter = Config.RecyclingCenter.coords
    local distance = #(playerCoords - recyclingCenter)
    
    if distance > 10.0 then
        QBCore.Functions.Notify('You must be at the smelting center to smelt items!', 'error')
        cb('error')
        return
    end
    
    -- Start recycling process
            TriggerServerEvent('resource:smelt', item, amount)
    cb('ok')
end)

-- Function to start gathering process
function StartGatheringProcess(activity, zoneIndex)
    if not HasRequiredTool(activity) then
        return
    end
    
    if not CheckCooldown(activity) then
        return
    end
    
    -- Start the skill check/minigame
            local bestTool = GetPlayerPreferredTool(activity)
        ShowHarvestProgressBar(activity, bestTool, function()
        -- Get player coords and find nearest zone
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestZone = nil
        local minDistance = math.huge
        
        for zoneId, zone in pairs(activeZones) do
            local distance = #(playerCoords - zone.coords)
            if distance <= zone.radius and distance < minDistance then
                minDistance = distance
                nearestZone = zone
            end
        end
        
        if nearestZone then
            -- Find the activity in the merged zone
            for _, zoneData in ipairs(nearestZone.zones) do
                if zoneData.activity == activity then
                    -- Trigger server event for gathering
                    TriggerServerEvent('resource:gather', activity, zoneData.zone)
                    
                    -- Set cooldown
                    SetCooldown(activity)
                    
                    -- Success notification will be handled by the mining:updateMiningData event
                    
                    -- Update UI
                    SendNUIMessage({
                        type = 'gatheringSuccess',
                        gatheringData = {
                            activity = activity,
                            zoneIndex = zoneIndex
                        }
                    })
                    
                    break
                end
            end
        end
    end)
end

-- Local variables to track mining data
local miningData = {
    level = 1,
    xp = 0,
    totalMined = 0,
    totalSmelted = 0,
    tier = 'Beginner'
}

-- XP System Functions (moved to top to avoid nil errors)
local function CalculateLevelXP(level)
    if level <= 1 then return 0 end
    
    -- Use the new array-based XP requirements
    if Config.XPSystem.levelRequirements and Config.XPSystem.levelRequirements[level] then
        return Config.XPSystem.levelRequirements[level]
    end
    
    -- Fallback to old calculation if array not found
    local totalXP = 0
    for i = 2, level do
        if Config.XPSystem.levelRequirements and Config.XPSystem.levelRequirements[i] then
            totalXP = totalXP + Config.XPSystem.levelRequirements[i]
        else
            -- Fallback calculation
            totalXP = totalXP + (100 * math.pow(1.2, i - 2))
        end
    end
    return math.floor(totalXP)
end

local function GetLevelFromXP(xp)
    if xp <= 0 then return 1 end
    
    local level = 1
    local currentXP = 0
    
    -- Use the new array-based system for more accurate level calculation
    if Config.XPSystem.levelRequirements then
        for checkLevel = 2, Config.XPSystem.maxLevel do
            local requiredXP = Config.XPSystem.levelRequirements[checkLevel]
            if requiredXP and xp >= requiredXP then
                level = checkLevel
                currentXP = xp
            else
                break
            end
        end
    else
        -- Fallback to old calculation
        while level < Config.XPSystem.maxLevel do
            local nextLevelXP = CalculateLevelXP(level + 1)
            if xp >= nextLevelXP then
                level = level + 1
                currentXP = xp
            else
                break
            end
        end
    end
    
    return level, currentXP
end

local function GetXPForNextLevel(currentLevel)
    if currentLevel >= Config.XPSystem.maxLevel then return 0 end
    
    -- Use the new array-based system for more accurate XP requirements
    if Config.XPSystem.levelRequirements and Config.XPSystem.levelRequirements[currentLevel + 1] then
        return Config.XPSystem.levelRequirements[currentLevel + 1]
    end
    
    -- Fallback to old calculation
    return CalculateLevelXP(currentLevel + 1)
end

local function GetXPProgress(currentLevel, currentXP)
    local levelStartXP = 0
    local levelEndXP = 0
    
    -- Use the new array-based system for more accurate progress calculation
    if Config.XPSystem.levelRequirements then
        levelStartXP = Config.XPSystem.levelRequirements[currentLevel] or 0
        levelEndXP = Config.XPSystem.levelRequirements[currentLevel + 1] or levelStartXP
    end
    
    local xpInLevel = currentXP - levelStartXP
    local xpNeeded = levelEndXP - levelStartXP
    
    if xpNeeded <= 0 then return 100 end
    return math.min(100, (xpInLevel / xpNeeded) * 100)
end

-- Update player data in UI
local function UpdatePlayerDataInUI()
    local playerData = {
        level = miningData.level,
        xp = miningData.xp,
        tier = miningData.tier,
        totalGathered = miningData.totalMined,
        totalSmelted = miningData.totalSmelted or 0
    }
    
    print('^3[DEBUG] UpdatePlayerDataInUI sending to UI:', json.encode(playerData) .. '^0')
    
    -- Get actual data from your skills system
    -- playerData.level = exports['qb-skills']:getSkill(GetPlayerServerId(PlayerId()), 'resource_gathering').level or 1
    -- playerData.xp = exports['qb-skills']:getSkill(GetPlayerServerId(PlayerId()), 'resource_gathering').xp or 0
    
    SendNUIMessage({
        type = 'updatePlayerData',
        playerData = playerData
    })
end

-- Update UI when player data changes
CreateThread(function()
    while true do
        Wait(5000) -- Update every 5 seconds
        if uiOpen then -- Only update if UI is actually open
            UpdatePlayerDataInUI()
        end
    end
end)

-- UI Target Functions
local function CreateUITarget()
    if not Config.UITarget.enabled then return end
    
    -- Create the ped
    local pedModel = GetHashKey(Config.UITarget.ped.model)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end
    
    uiTargetPed = CreatePed(4, pedModel, Config.UITarget.ped.coords.x, Config.UITarget.ped.coords.y, Config.UITarget.ped.coords.z - 1.0, Config.UITarget.ped.heading, false, true)
    SetEntityHeading(uiTargetPed, Config.UITarget.ped.heading)
    FreezeEntityPosition(uiTargetPed, true)
    SetEntityInvincible(uiTargetPed, true)
    SetBlockingOfNonTemporaryEvents(uiTargetPed, true)
    
    -- Set ped scenario
    if Config.UITarget.ped.scenario then
        TaskStartScenarioInPlace(uiTargetPed, Config.UITarget.ped.scenario, 0, true)
    end
    
    -- Create blip if enabled
    if Config.UITarget.ped.blip.enabled then
        uiTargetBlip = AddBlipForCoord(Config.UITarget.ped.coords.x, Config.UITarget.ped.coords.y, Config.UITarget.ped.coords.z)
        SetBlipSprite(uiTargetBlip, Config.UITarget.ped.blip.sprite)
        SetBlipDisplay(uiTargetBlip, 4)
        SetBlipScale(uiTargetBlip, Config.UITarget.ped.blip.scale)
        SetBlipColour(uiTargetBlip, Config.UITarget.ped.blip.color)
        SetBlipAsShortRange(uiTargetBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.UITarget.ped.blip.label)
        EndTextCommandSetBlipName(uiTargetBlip)
    end
    
    -- Add target interaction based on config
    if Config.UITarget.targetSystem == 'ox_target' then
        -- ox_target system
        exports['ox_target']:addLocalEntity(uiTargetPed, {
            {
                name = 'mining_ui_target',
                icon = 'fas fa-mountain',
                label = 'Access Mining Operations',
                distance = Config.UITarget.distance,
                onSelect = function()
                    OpenMiningUI()
                end
            }
        })
    elseif Config.UITarget.targetSystem == 'qb-target' then
        -- qb-target system
        exports['ox_target']:addLocalEntity(uiTargetPed, {
            {
                name = 'mining_ui_target',
                icon = 'fas fa-mountain',
                label = 'Access Mining Operations',
                distance = Config.UITarget.distance,
                onSelect = function()
                    OpenMiningUI()
                end
            }
        })
    end
    
    print('Mining UI Target created at:', Config.UITarget.ped.coords)
end

local function DeleteUITarget()
    if uiTargetPed and DoesEntityExist(uiTargetPed) then
        DeleteEntity(uiTargetPed)
        uiTargetPed = nil
    end
    
    if uiTargetBlip and DoesBlipExist(uiTargetBlip) then
        RemoveBlip(uiTargetBlip)
        uiTargetBlip = nil
    end
end

-- Function to open mining UI
function OpenMiningUI()
    if uiOpen then return end
    
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'showMiningUI'
    })
    
    -- Refresh tool checks to ensure accurate status
    RefreshMiningToolChecks()
    
    -- Get player data and update UI
    UpdatePlayerDataInUI()
end

-- Function to close mining UI
function CloseMiningUI()
    if not uiOpen then return end
    
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideMiningUI'
    })
end

-- Function to update player data in UI
function UpdatePlayerDataInUI()
    if not uiOpen then return end
    
    -- Get player data from server
    TriggerServerEvent('mining:getPlayerData')
end

-- Function to send player data to UI
function SendPlayerDataToUI(playerData)
    SendNUIMessage({
        type = 'updatePlayerData',
        playerData = playerData
    })
end

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    CloseMiningUI()
    cb('ok')
end)

-- NUI Callback for closing mining UI specifically
RegisterNUICallback('closeMiningUI', function(data, cb)
    CloseMiningUI()
    cb('ok')
end)

-- NUI Callback for purchasing equipment
RegisterNUICallback('purchaseEquipment', function(data, cb)
    local toolType = data.toolType
    local playerLevel = data.playerLevel
    
    -- Check if player meets level requirement from config
    local requiredLevel = 0
    if toolType == 'pickaxe' then
        requiredLevel = Config.XPSystem.levelBonuses.tool_unlocks.pickaxe or 0
    elseif toolType == 'mining_drill' then
        requiredLevel = Config.XPSystem.levelBonuses.tool_unlocks.drill or 2
    elseif toolType == 'mining_laser' then
        requiredLevel = Config.XPSystem.levelBonuses.tool_unlocks.laser or 2
    end
    
    if playerLevel < requiredLevel then
        cb({ success = false, message = 'Level ' .. requiredLevel .. ' required for ' .. toolType })
        return
    end
    
    -- For ox_inventory, check if player already has the tool
    if Config.Inventory.system == 'ox_inventory' then
        -- Trigger server check first
        TriggerServerEvent('mining:checkTool', toolType)
        -- Wait a bit for the result
        Wait(100)
    end
    
    -- Check if player already has the tool
    if HasMiningTool(toolType) then
        cb({ success = false, message = 'You already own this tool' })
        return
    end
    
    -- Check if equipment shop is enabled
    if not Config.EquipmentShop.enabled then
        cb({ success = false, message = 'Equipment shop is currently disabled' })
        return
    end
    
    -- Get tool price from config
    local toolPrice = Config.EquipmentShop.items[toolType] and Config.EquipmentShop.items[toolType].price
    if not toolPrice then
        cb({ success = false, message = 'Tool price not configured' })
        return
    end
    
    -- Determine payment method based on config
    local paymentMethod = Config.EquipmentShop.payment.method
    if paymentMethod == 'both' then
        paymentMethod = Config.EquipmentShop.payment.default
    end
    
    -- Show payment confirmation dialog
    local confirm = lib.alertDialog({
        header = 'Purchase Equipment',
        content = string.format('Purchase %s for $%d?\n\nPayment: %s', 
            Config.EquipmentShop.items[toolType].label, 
            toolPrice, 
            paymentMethod:upper()),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Purchase',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        -- Trigger server event to purchase tool with payment
        TriggerServerEvent('17th-resourcegathering:server:purchaseTool', toolType, paymentMethod)
        
        -- Return success immediately - server will handle the actual purchase
        -- and send confirmation via NUI message
        cb({ success = true, message = 'Processing purchase...' })
    else
        cb({ success = false, message = 'Purchase cancelled' })
    end
end)

-- NUI Callback for getting leaderboard
RegisterNUICallback('getLeaderboard', function(data, cb)
    TriggerServerEvent('mining:getLeaderboard', 'level')
    cb('ok')
end)

-- NUI Callback for getting filtered leaderboard
RegisterNUICallback('getLeaderboardFiltered', function(data, cb)
    local filterType = data.filterType or 'level'
    
    if filterType ~= 'level' and filterType ~= 'smelted' and filterType ~= 'mined' then
        filterType = 'level' -- Default to level if invalid
    end
    
    print('^3[DEBUG]^0 NUI requested leaderboard with filter:', filterType .. '^0')
    TriggerServerEvent('mining:getLeaderboardFiltered', filterType)
    cb('ok')
end)

-- NUI Callback for getting player data
RegisterNUICallback('getPlayerData', function(data, cb)
    TriggerServerEvent('mining:getPlayerData')
    cb('ok')
end)

-- qb-target event handler
RegisterNetEvent('mining:openUI', function()
    OpenMiningUI()
end)

-- Mining XP Update Event
RegisterNetEvent('mining:updatePlayerData', function(playerData)
    -- Update local mining data with server data
    if playerData then
        miningData.level = playerData.level or miningData.level
        miningData.xp = playerData.xp or miningData.xp
        miningData.totalMined = playerData.totalMined or miningData.totalMined
        miningData.totalSmelted = playerData.totalSmelted or miningData.totalSmelted
    end
    
    SendPlayerDataToUI(playerData)
end)

-- Mining Data Update Event (for successful gathering)
RegisterNetEvent('mining:updateMiningData', function(data)
    print('^3[DEBUG] mining:updateMiningData received data:', json.encode(data) .. '^0')
    
    -- Update local mining data with server data
    if data.newXP then
        miningData.xp = data.newXP
    else
        miningData.xp = miningData.xp + (data.xpGained or 0)
    end
    
    if data.newTotalMined then
        miningData.totalMined = data.newTotalMined
    else
        miningData.totalMined = miningData.totalMined + 1
    end
    
    if data.newTotalSmelted then
        miningData.totalSmelted = data.newTotalSmelted
        print('^2[DEBUG] Updated totalSmelted to:', miningData.totalSmelted .. '^0')
    end
    
    if data.newLevel then
        miningData.level = data.newLevel
    else
        -- Check for level up (simple level calculation for now)
        local newLevel = math.floor(miningData.xp / 100) + 1
        if newLevel > miningData.level then
            miningData.level = newLevel
            QBCore.Functions.Notify('Level Up! You are now level ' .. newLevel .. '!', 'success', 5000)
        end
    end
    
    -- Show success notification with item details
    if data.itemsFound and data.itemsFound.name and data.itemsFound.amount then
        QBCore.Functions.Notify('Successfully gathered ' .. data.itemsFound.amount .. 'x ' .. data.itemsFound.name .. '!', 'primary', 3500)
    else
        QBCore.Functions.Notify('Successfully gathered resources!', 'primary', 3500)
    end
    
    -- Update UI with new data
    UpdatePlayerDataInUI()
    
    -- Send success message to UI
    SendNUIMessage({
        type = 'gatheringSuccess',
        gatheringData = {
            activity = data.activity,
            xpGained = data.xpGained,
            itemsFound = data.itemsFound,
            newTotalMined = miningData.totalMined
        }
    })
    
    -- Use server-provided XP values instead of calculating locally
    -- This ensures consistency with the server's config-based XP system
    SendNUIMessage({
        type = 'updatePlayerData',
        playerData = {
            level = miningData.level,
            xp = miningData.xp,
            tier = miningData.tier,
            totalGathered = miningData.totalMined,
            totalSmelted = miningData.totalSmelted or 0,
            xpForNextLevel = data.xpForNextLevel or GetXPForNextLevel(miningData.level),
            xpProgress = data.xpProgress or GetXPProgress(miningData.level, miningData.xp)
        }
    })
end)

-- Mining Leaderboard Update Event
RegisterNetEvent('mining:updateLeaderboard', function(leaderboardData, filterType)
    print('^3[DEBUG]^0 Received leaderboard data:', #leaderboardData, 'players, filter:', filterType or 'unknown' .. '^0')
    
    SendNUIMessage({
        type = 'updateLeaderboard',
        leaderboardData = leaderboardData,
        filterType = filterType or 'level'
    })
end)

-- Tool check result event
RegisterNetEvent('mining:toolCheckResult', function(toolType, hasItem)
    -- Store the result for the current tool check
    if not toolCheckResults then toolCheckResults = {} end
    toolCheckResults[toolType] = hasItem
    
    print('^2[DEBUG] Tool check result received -', toolType .. ':', tostring(hasItem) .. '^0')
    print('^3[DEBUG] Updated toolCheckResults:', json.encode(toolCheckResults) .. '^0')
    
    -- Debug: Show all available tools in config for comparison
    print('^3[DEBUG] Available tools in config for comparison:^0')
    for configKey, configItem in pairs(Config.Inventory.items) do
        print('^3[DEBUG]   Config key:', configKey, 'Item name:', configItem.name, 'Matches toolType:', configItem.name == toolType .. '^0')
    end
end)

-- Smeltable items event
RegisterNetEvent('mining:recyclableItems', function(items)
    if #items == 0 then
        QBCore.Functions.Notify('You don\'t have any items to smelt!', 'error')
        return
    end
    
    local menuItems = {}
    for _, item in pairs(items) do
        table.insert(menuItems, {
            title = item.label,
            description = 'Amount: ' .. item.count,
            icon = 'box',
            onSelect = function()
                local input = lib.inputDialog('Smelt ' .. item.label, {
                    {type = 'number', label = 'Amount to smelt', description = 'You have ' .. item.count .. ' available', default = 1, min = 1, max = item.count}
                })
                if input then
                    local amount = input[1]
                    if amount and amount > 0 and amount <= item.count then
                                                        -- Start smelting process (no more risky system)
                                TriggerServerEvent('resource:smelt', item.name, amount)
                    else
                        QBCore.Functions.Notify('Invalid amount!', 'error')
                    end
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'recycling_menu',
        title = 'Smelting Center',
        options = menuItems
    })
    
    lib.showContext('recycling_menu')
end)



-- Debug command to check tool status
RegisterCommand('checktools', function()
    CheckCurrentToolStatus()
    RefreshMiningToolChecks()
    Wait(500)
    CheckCurrentToolStatus()
end, false)

-- Command to manually select preferred tool
RegisterCommand('selecttool', function(source, args)
    if not args[1] then
        print('^3[USAGE] /selecttool <tool_name>^0')
        print('^3[AVAILABLE TOOLS] pickaxe, mining_drill, mining_laser^0')
        return
    end
    
    local selectedTool = args[1]
    if selectedTool == 'pickaxe' or selectedTool == 'mining_drill' or selectedTool == 'mining_laser' then
        -- Check if player has this tool
        if toolCheckResults and toolCheckResults[selectedTool] then
            -- Set this as the preferred tool by moving it to the front of the results
            local newResults = {}
            newResults[selectedTool] = true
            
            -- Add other available tools after
            for toolType, hasTool in pairs(toolCheckResults) do
                if toolType ~= selectedTool and hasTool then
                    newResults[toolType] = true
                end
            end
            
            toolCheckResults = newResults
            print('^2[SUCCESS] Preferred tool set to:', selectedTool .. '^0')
            print('^3[DEBUG] Updated toolCheckResults:', json.encode(toolCheckResults) .. '^0')
        else
            print('^1[ERROR] You do not have the tool:', selectedTool .. '^0')
        end
    else
        print('^1[ERROR] Invalid tool name. Use: pickaxe, mining_drill, or mining_laser^0')
    end
end, false)

-- Command to test mining with specific tool
RegisterCommand('testmining', function(source, args)
    if not args[1] then
        print('^3[USAGE] /testmining <tool_name>^0')
        print('^3[AVAILABLE TOOLS] pickaxe, mining_drill, mining_laser^0')
        return
    end
    
    local testTool = args[1]
    if testTool == 'pickaxe' or testTool == 'mining_drill' or testTool == 'mining_laser' then
        print('^3[DEBUG] Testing mining with tool:', testTool .. '^0')
        
        -- Simulate mining with the specified tool
        ShowHarvestProgressBar('mining', testTool, function()
            print('^2[DEBUG] Mining test completed with tool:', testTool .. '^0')
            -- Play the effect to test particles
            local playerCoords = GetEntityCoords(PlayerPedId())
            PlayHarvestEffect(playerCoords, 'mining', testTool)
        end)
    else
        print('^1[ERROR] Invalid tool name. Use: pickaxe, mining_drill, or mining_laser^0')
    end
end, false)

-- Command to test different animations
RegisterCommand('testanim', function(source, args)
    if not args[1] then
        print('^3[USAGE] /testanim <animation_dict>^0')
        print('^3[EXAMPLES] /testanim melee@large_wpn@streamed_core^0')
        return
    end
    
    local animDict = args[1]
    local ped = PlayerPedId()
    
    print('^3[DEBUG] Testing animation dictionary:', animDict .. '^0')
    RequestAnimDict(animDict)
    
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(animDict) then
        print('^2[DEBUG] Animation loaded successfully, playing...^0')
        TaskPlayAnim(ped, animDict, "ground_attack_on_spot", 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        print('^1[ERROR] Failed to load animation dictionary:', animDict .. '^0')
    end
end, false)

-- Command to test the new tool system
RegisterCommand('testnewtool', function(source, args)
    if not args[1] then
        print('^3[USAGE] /testnewtool <tool_name>^0')
        print('^3[AVAILABLE TOOLS] pickaxe, mining_drill, mining_laser^0')
        return
    end
    
    local testTool = args[1]
    if testTool == 'pickaxe' or testTool == 'mining_drill' or testTool == 'mining_laser' then
        print('^3[DEBUG] Testing new tool system with:', testTool .. '^0')
        
        local cfg = getToolConfig(testTool)
        if not cfg then
            print('^1[ERROR] Failed to get tool config for:', testTool .. '^0')
            return
        end
        local ped = PlayerPedId()
        
        print('^3[DEBUG] Tool config:', json.encode(cfg) .. '^0')
        
        -- Attach tool prop
        local prop = attachToolProp(ped, cfg.prop)
        if prop then
            print('^2[DEBUG] Tool prop attached successfully^0')
        end
        
        -- Start scenario or animation
        local played = startScenarioOrAnim(ped, cfg)
        if played then
            print('^2[DEBUG] Started', played, 'for tool:', testTool .. '^0')
        end
        
        -- Wait a moment to ensure pose/scenario is set before FX
        Wait(150)
        
        -- Start particle effects
        playToolFx(ped, cfg)
        
        -- Wait for duration
        local duration = cfg.duration or 5000
        print('^3[DEBUG] Waiting for duration:', duration .. '^0')
        Wait(duration)
        
        -- Cleanup
        ClearPedTasks(ped)
        if prop and DoesEntityExist(prop) then 
            DeleteEntity(prop)
            print('^2[DEBUG] Tool prop cleaned up^0')
        end
        
        -- Stop particle effects
        stopAllParticleEffects(ped)
        
        print('^2[DEBUG] New tool system test completed for:', testTool .. '^0')
    else
        print('^1[ERROR] Invalid tool name. Use: pickaxe, mining_drill, or mining_laser^0')
    end
end, false)

-- Command to safely test mining drill (no dangerous effects)
RegisterCommand('testdrill', function(source, args)
    print('^3[DEBUG] Testing mining drill safely (no dangerous effects)^0')
    
    local testTool = 'mining_drill'
            local cfg = getToolConfig(testTool)
        if not cfg then
            print('^1[ERROR] Failed to get tool config for:', testTool .. '^0')
            return
        end
    local ped = PlayerPedId()
    
    print('^3[DEBUG] Tool config:', json.encode(cfg) .. '^0')
    
    -- Attach tool prop
    local prop = attachToolProp(ped, cfg.prop)
    if prop then
        print('^2[DEBUG] Tool prop attached successfully^0')
    end
    
    -- Start animation (no scenario)
    local played = startScenarioOrAnim(ped, cfg)
    if played then
        print('^2[DEBUG] Started', played, 'for tool:', testTool .. '^0')
    end
    
    -- Wait a moment to ensure pose is set
    Wait(150)
    
    -- Skip particle effects for safety
    print('^3[DEBUG] Skipping particle effects for safety^0')
    
    -- Wait for duration
    local duration = cfg.duration or 5000
    print('^3[DEBUG] Waiting for duration:', duration .. '^0')
    Wait(duration)
    
    -- Cleanup
    ClearPedTasks(ped)
    if prop and DoesEntityExist(prop) then 
        DeleteEntity(prop)
        print('^2[DEBUG] Tool prop cleaned up^0')
    end
    
    print('^2[DEBUG] Safe mining drill test completed^0')
end, false)

-- Command to test tool switching
RegisterCommand('testtoolswitch', function(source, args)
    print('^3[DEBUG] Testing tool switching...^0')
    
    local tools = {'pickaxe', 'mining_drill', 'mining_laser'}
    local ped = PlayerPedId()
    
    for i, toolType in ipairs(tools) do
        print('^3[DEBUG] Testing tool:', toolType .. '^0')
        
        local cfg = getToolConfig(toolType)
        if not cfg then
            print('^1[ERROR] Failed to get tool config for:', toolType .. '^0')
            goto continue
        end
        
        print('^3[DEBUG] Tool config:', json.encode(cfg) .. '^0')
        
        -- Attach tool prop
        local prop = attachToolProp(ped, cfg.prop)
        if prop then
            print('^2[DEBUG] Tool prop attached successfully^0')
        end
        
        -- Start scenario or animation
        local played = startScenarioOrAnim(ped, cfg)
        if played then
            print('^2[DEBUG] Started', played, 'for tool:', toolType .. '^0')
        end
        
        -- Wait a moment to ensure pose is set
        Wait(150)
        
        -- Start particle effects
        playToolFx(ped, cfg)
        
        -- Wait for duration
        local duration = cfg.duration or 5000
        print('^3[DEBUG] Waiting for duration:', duration .. '^0')
        Wait(duration)
        
        -- Cleanup
        ClearPedTasks(ped)
        if prop and DoesEntityExist(prop) then 
            DeleteEntity(prop)
            print('^2[DEBUG] Tool prop cleaned up^0')
        end
        
        -- Stop particle effects
        stopAllParticleEffects(ped)
        
        print('^2[DEBUG] Tool test completed for:', toolType .. '^0')
        
        -- Wait between tools
        Wait(1000)
        
        ::continue::
    end
    
    print('^2[DEBUG] Tool switching test completed^0')
end, false)

-- Command to manually refresh tool checks
RegisterCommand('refreshtools', function(source, args)
    print('^3[DEBUG] Manually refreshing tool checks...^0')
    RefreshMiningToolChecks()
    print('^2[DEBUG] Tool checks refreshed. Use /checktools to see results.^0')
end, false)

-- Command to test real-time tool detection
RegisterCommand('testrealtimetool', function(source, args)
    print('^3[DEBUG] Testing real-time tool detection...^0')
    
    local activity = 'mining'
    local detectedTool = GetPlayerPreferredTool(activity)
    
    if detectedTool then
        print('^2[DEBUG] Real-time tool detection successful. Tool:', detectedTool .. '^0')
        
        -- Test the tool configuration
        local cfg = getToolConfig(detectedTool)
        if cfg then
            print('^3[DEBUG] Tool config generated:', json.encode(cfg) .. '^0')
        else
            print('^1[ERROR] Failed to generate tool config^0')
        end
    else
        print('^1[ERROR] Real-time tool detection failed^0')
    end
end, false)

-- Command to test smelting XP system
RegisterCommand('testsmeltingxp', function(source, args)
    print('^3[DEBUG] Testing smelting XP system...^0')
    
    -- Test the actual smelting process
    TriggerServerEvent('resource:smelt', 'copper_ore', 1)
    
    print('^2[DEBUG] Smelting test event triggered^0')
end, false)

-- Command to test config values
RegisterCommand('testconfig', function(source, args)
    print('^3[DEBUG] Testing config values...^0')
    print('^3[DEBUG] Config.XPSystem.rewards.smelting:', Config.XPSystem.rewards.smelting .. '^0')
    print('^3[DEBUG] Config.XPSystem.rewards.mining:', Config.XPSystem.rewards.mining .. '^0')
    print('^3[DEBUG] Config.XPSystem.rewards.mining_bonus:', Config.XPSystem.rewards.mining_bonus .. '^0')
    print('^3[DEBUG] Config.XPSystem.enabled:', tostring(Config.XPSystem.enabled) .. '^0')
    print('^3[DEBUG] Config.XPSystem.maxLevel:', Config.XPSystem.maxLevel .. '^0')
    
    -- Show XP requirements for first few levels
    if Config.XPSystem.levelRequirements then
        print('^3[DEBUG] XP Requirements (Levels 1-5):^0')
        for i = 1, 5 do
            if Config.XPSystem.levelRequirements[i] then
                print('^3[DEBUG]   Level', i, 'requires:', Config.XPSystem.levelRequirements[i], 'XP^0')
            end
        end
    end
    
    print('^3[DEBUG] Config.SkillSettings.xp_rewards.mining:', Config.SkillSettings.xp_rewards.mining .. '^0')
    print('^3[DEBUG] Config.SkillSettings.xp_rewards.smelting:', Config.SkillSettings.xp_rewards.smelting .. '^0')
end, false)

-- Command to test mining XP system
RegisterCommand('testminingxp', function(source, args)
    print('^3[DEBUG] Testing mining XP system...^0')
    
    -- Test the mining XP event
    TriggerServerEvent('mining:addXP', 20, 'pickaxe', {name = 'iron_ore', amount = 1})
    
    print('^2[DEBUG] Mining XP test event triggered^0')
end, false)

-- Command to test XP calculations
RegisterCommand('testxpcalc', function(source, args)
    print('^3[DEBUG] Testing XP calculations...^0')
    
    local testLevel = tonumber(args[1]) or 1
    print('^3[DEBUG] Testing level:', testLevel .. '^0')
    
    local levelXP = CalculateLevelXP(testLevel)
    local nextLevelXP = GetXPForNextLevel(testLevel)
    local progress = GetXPProgress(testLevel, levelXP)
    
    print('^3[DEBUG] Level', testLevel, 'requires:', levelXP, 'XP^0')
    print('^3[DEBUG] Next level requires:', nextLevelXP, 'XP^0')
    print('^3[DEBUG] Progress at level start:', progress, '%^0')
    
    -- Test with some XP in the level
    local xpInLevel = 50
    local progressWithXP = GetXPProgress(testLevel, levelXP + xpInLevel)
    print('^3[DEBUG] Progress with', xpInLevel, 'XP in level:', progressWithXP, '%^0')
    
    -- Show config values
    print('^3[DEBUG] Config.XPSystem.maxLevel:', Config.XPSystem.maxLevel .. '^0')
    if Config.XPSystem.levelRequirements then
        print('^3[DEBUG] Array-based XP system enabled^0')
        print('^3[DEBUG] Level 2 requires:', Config.XPSystem.levelRequirements[2], 'XP^0')
        print('^3[DEBUG] Level 10 requires:', Config.XPSystem.levelRequirements[10], 'XP^0')
        print('^3[DEBUG] Level 25 requires:', Config.XPSystem.levelRequirements[25], 'XP^0')
        print('^3[DEBUG] Level 51 requires:', Config.XPSystem.levelRequirements[51], 'XP^0')
    else
        print('^1[WARNING] Array-based XP system not found, using fallback^0')
    end
end, false)

-- Command to test smelting tracking
RegisterCommand('testsmeltingtrack', function(source, args)
    print('^3[DEBUG] Testing smelting tracking...^0')
    print('^3[DEBUG] Current mining data:^0')
    print('^3[DEBUG]   Total Mined:', miningData.totalMined or 0 .. '^0')
    print('^3[DEBUG]   Total Smelted:', miningData.totalSmelted or 0 .. '^0')
    print('^3[DEBUG]   Level:', miningData.level or 0 .. '^0')
    print('^3[DEBUG]   XP:', miningData.xp or 0 .. '^0')
    
    -- Test smelting some items
    print('^3[DEBUG] Testing smelting 5 iron ore...^0')
    TriggerServerEvent('resource:smelt', 'iron_ore', 5)
end, false)

-- Command to test mining system
RegisterCommand('testminingsystem', function(source, args)
    print('^3[DEBUG] Testing mining system...^0')
    print('^3[DEBUG] Current mining data:^0')
    print('^3[DEBUG]   Total Mined:', miningData.totalMined or 0 .. '^0')
    print('^3[DEBUG]   Total Smelted:', miningData.totalSmelted or 0 .. '^0')
    print('^3[DEBUG]   Level:', miningData.level or 0 .. '^0')
    print('^3[DEBUG]   XP:', miningData.xp or 0 .. '^0')
    
    -- Test mining at a rock
    print('^3[DEBUG] Testing mining at rock...^0')
    -- This will trigger the mining event when you mine a rock
    QBCore.Functions.Notify('Go mine a rock to test the system!', 'primary', 5000)
end, false)

-- Command to manually trigger mining event for testing
RegisterCommand('testminingevent', function(source, args)
    print('^3[DEBUG] Manually triggering mining event...^0')
    
    -- Create a test zone
    local testZone = {
        items = {
            {name = 'iron_ore', amount = {min = 1, max = 3}, chance = 100}
        }
    }
    
    -- Trigger the server event directly
    TriggerServerEvent('resource:gather', 'mining', testZone)
    
    print('^3[DEBUG] Mining event triggered^0')
end, false)

-- Command to manually trigger smelting event for testing
RegisterCommand('testsmeltingevent', function(source, args)
    print('^3[DEBUG] Manually triggering smelting event...^0')
    
    local itemName = args[1] or 'iron_ore'
    local amount = tonumber(args[2]) or 3
    
    print('^3[DEBUG] Smelting', amount, 'x', itemName .. '^0')
    
    -- Trigger the server event directly
    TriggerServerEvent('resource:smelt', itemName, amount)
    
    print('^3[DEBUG] Smelting event triggered^0')
end, false)

-- Command to test smelting center interaction
RegisterCommand('testsmeltingcenter', function(source, args)
    print('^3[DEBUG] Testing smelting center...^0')
    
    -- Check if player has iron ore
    local hasIronOre = exports['ox_inventory']:GetItemCount(GetPlayerServerId(PlayerId()), 'iron_ore')
    print('^3[DEBUG] Player has', hasIronOre, 'iron ore^0')
    
    if hasIronOre > 0 then
        print('^3[DEBUG] Testing smelting 1 iron ore...^0')
        TriggerServerEvent('resource:smelt', 'iron_ore', 1)
    else
        print('^3[DEBUG] No iron ore found, testing with 0 amount...^0')
        TriggerServerEvent('resource:smelt', 'iron_ore', 1)
    end
end, false)

-- Command to test basic server communication
RegisterCommand('testserver', function(source, args)
    print('^3[DEBUG] Testing server communication...^0')
    
    -- Test a simple server event
    TriggerServerEvent('test:ping', 'Hello Server!')
    
    print('^2[DEBUG] Test ping sent to server^0')
end, false)

-- Command to test different leaderboard filters
RegisterCommand('testleaderboard', function(source, args)
    local filterType = args[1] or 'level'
    
    if filterType ~= 'level' and filterType ~= 'smelted' and filterType ~= 'mined' then
        print('^1[ERROR] Invalid filter type. Use: level, smelted, or mined^0')
        return
    end
    
    print('^3[DEBUG] Testing leaderboard with filter:', filterType .. '^0')
    
    -- Request leaderboard with specific filter
    TriggerServerEvent('mining:getLeaderboardFiltered', filterType)
    
    print('^2[DEBUG] Leaderboard request sent for filter:', filterType .. '^0')
end, false)

-- Command to test all leaderboard filters
RegisterCommand('testallleaderboards', function(source, args)
    print('^3[DEBUG] Testing all leaderboard filters...^0')
    
    local filters = {'level', 'smelted', 'mined'}
    
    for i, filter in ipairs(filters) do
        print('^3[DEBUG] Testing filter:', filter .. '^0')
        TriggerServerEvent('mining:getLeaderboardFiltered', filter)
        Wait(1000) -- Wait 1 second between requests
    end
    
    print('^2[DEBUG] All leaderboard tests completed^0')
end, false)

-- Command to test the new smelting progress bar system
RegisterCommand('testsmeltingbar', function(source, args)
    print('^3[DEBUG] Testing smelting progress bar system...^0')
    
    -- Test the progress bar directly
    if lib.progressBar({
        duration = 3000,
        label = 'Testing smelting progress bar...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'amb@world_human_welding@male@base',
            clip = 'base'
        },
    }) then
        print('^2[DEBUG] Progress bar completed successfully^0')
        QBCore.Functions.Notify('Progress bar test completed!', 'success')
    else
        print('^1[DEBUG] Progress bar was cancelled^0')
        QBCore.Functions.Notify('Progress bar test cancelled!', 'error')
    end
end, false)

-- Command to test the looping smelting system
RegisterCommand('testloopsmelting', function(source, args)
    local amount = tonumber(args[1]) or 5
    print('^3[DEBUG] Testing looping smelting system with', amount, 'items...^0')
    
    -- Simulate the looping smelting process
    local function smeltNextItem(currentIndex)
        if currentIndex > amount then
            print('^2[DEBUG] All test items completed^0')
            QBCore.Functions.Notify('Test smelting completed!', 'success')
            return
        end
        
        local label = string.format('Test Smelting (%d/%d)...', currentIndex, amount)
        print('^3[DEBUG] Starting test smelting for item', currentIndex, 'of', amount .. '^0')
        
        if lib.progressBar({
            duration = 2000, -- Faster for testing
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
            anim = {
                dict = 'amb@world_human_welding@male@base',
                clip = 'base'
            },
        }) then
            print('^2[DEBUG] Test smelting completed for item', currentIndex, 'of', amount .. '^0')
            -- Move to next item
            smeltNextItem(currentIndex + 1)
        else
            print('^1[DEBUG] Test smelting cancelled at item', currentIndex, 'of', amount .. '^0')
            QBCore.Functions.Notify('Test smelting cancelled!', 'error')
        end
    end
    
    -- Start the test
    smeltNextItem(1)
end, false)

-- Command to test the new XP per item system
RegisterCommand('testxppermitem', function(source, args)
    local amount = tonumber(args[1]) or 3
    print('^3[DEBUG] Testing XP per item system with', amount, 'items...^0')
    
    -- Test the new XP calculation
    local baseXP = 10 -- Config.XPSystem.rewards.smelting
    local totalXP = baseXP * amount
    local baseTime = 10000 -- 10 seconds base duration
    
    print('^3[DEBUG] XP Calculation:^0')
    print('^3[DEBUG]   Base XP per item:', baseXP .. '^0')
    print('^3[DEBUG]   Items to smelt:', amount .. '^0')
    print('^3[DEBUG]   Total XP will be:', totalXP .. '^0')
    print('^3[DEBUG]   Base time per item:', baseTime / 1000, 'seconds^0')
    print('^3[DEBUG]   Total time will be:', (baseTime * amount) / 1000, 'seconds^0')
    
    QBCore.Functions.Notify('XP per item test completed! Check console for details.', 'success')
end, false)

-- Log Buyer Variables
local logBuyerPed = nil
local logBuyerBlip = nil

-- Function to create log buyer ped
local function CreateLogBuyerPed()
    if not Config.LogBuyer.enabled then return end
    
    -- Request the ped model
    local pedModel = GetHashKey(Config.LogBuyer.ped.model)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(1)
    end
    
    -- Create the ped
    logBuyerPed = CreatePed(4, pedModel, Config.LogBuyer.ped.coords.x, Config.LogBuyer.ped.coords.y, Config.LogBuyer.ped.coords.z - 1.0, Config.LogBuyer.ped.coords.w, false, true)
    
    -- Set ped properties
    SetEntityHeading(logBuyerPed, Config.LogBuyer.ped.coords.w)
    FreezeEntityPosition(logBuyerPed, true)
    SetEntityInvincible(logBuyerPed, true)
    SetBlockingOfNonTemporaryEvents(logBuyerPed, true)
    
    -- Set ped scenario
    if Config.LogBuyer.ped.scenario then
        TaskStartScenarioInPlace(logBuyerPed, Config.LogBuyer.ped.scenario, 0, true)
    end
    
    -- Create blip if enabled
    if Config.LogBuyer.ped.blip.enabled then
        logBuyerBlip = AddBlipForCoord(Config.LogBuyer.ped.coords.x, Config.LogBuyer.ped.coords.y, Config.LogBuyer.ped.coords.z)
        SetBlipSprite(logBuyerBlip, Config.LogBuyer.ped.blip.sprite)
        SetBlipDisplay(logBuyerBlip, 4)
        SetBlipScale(logBuyerBlip, Config.LogBuyer.ped.blip.scale)
        SetBlipColour(logBuyerBlip, Config.LogBuyer.ped.blip.color)
        SetBlipAsShortRange(logBuyerBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.LogBuyer.ped.blip.label)
        EndTextCommandSetBlipName(logBuyerBlip)
    end
    
    -- Add ox_target interaction
    exports['ox_target']:addLocalEntity(logBuyerPed, {
        {
            name = 'log_buyer_sell',
            icon = 'fas fa-tree',
            label = 'Sell Logs',
            distance = Config.LogBuyer.distance,
            onSelect = function()
                OpenLogSellingUI()
            end
        }
    })
    
    print('^2[DEBUG] Log buyer ped created successfully^0')
end

-- Function to delete log buyer ped
local function DeleteLogBuyerPed()
    if logBuyerPed then
        if DoesEntityExist(logBuyerPed) then
            DeleteEntity(logBuyerPed)
        end
        logBuyerPed = nil
    end
    
    if logBuyerBlip then
        RemoveBlip(logBuyerBlip)
        logBuyerBlip = nil
    end
    
    print('^2[DEBUG] Log buyer ped deleted^0')
end

-- Function to open log selling UI
function OpenLogSellingUI()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return end
    
    -- Get player's wood logs
    local woodLogs = exports.ox_inventory:GetItemCount('wood_log')
    
    if woodLogs <= 0 then
        QBCore.Functions.Notify('You don\'t have any wood logs to sell!', 'error')
        return
    end
    
    -- Calculate total value
    local pricePerLog = Config.LogBuyer.items.wood_log.price
    local totalValue = woodLogs * pricePerLog
    
    -- Determine payment method based on config
    local paymentMethod = Config.LogBuyer.payment.method
    if paymentMethod == 'both' then
        paymentMethod = Config.LogBuyer.payment.default
    end
    
    -- Show confirmation dialog
    local confirm = lib.alertDialog({
        header = 'Sell Wood Logs',
        content = string.format('Sell %d wood logs for $%d?\n\nPayment: %s', woodLogs, totalValue, paymentMethod:upper()),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Sell',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        -- Trigger server event to sell logs
        TriggerServerEvent('17th-resourcegathering:server:sellLogs', woodLogs, paymentMethod)
    end
end

-- Create log buyer when resource starts
CreateThread(function()
    Wait(1000) -- Wait for everything to load
    CreateUITarget()
    CreateLogBuyerPed()
end)

-- Event handler for successful tool purchase
RegisterNetEvent('17th-resourcegathering:client:toolPurchaseSuccess', function(toolType)
    -- Update tool check results
    if toolCheckResults then
        toolCheckResults[toolType] = true
    end
    
    -- Update UI to reflect new ownership
    SendNUIMessage({
        type = 'updateEquipment',
        toolType = toolType,
        owned = true
    })
    
    -- Refresh all tool checks to ensure consistency
    RefreshMiningToolChecks()
    
    print('^2[DEBUG]^0 Tool purchase successful for:', toolType)
end)

-- Event handler for failed tool purchase
RegisterNetEvent('17th-resourcegathering:client:toolPurchaseFailed', function(toolType)
    -- Update tool check results
    if toolCheckResults then
        toolCheckResults[toolType] = false
    end
    
    -- Update UI to reflect failed purchase
    SendNUIMessage({
        type = 'updateEquipment',
        toolType = toolType,
        owned = false
    })
    
    print('^1[DEBUG]^0 Tool purchase failed for:', toolType)
end)

-- Cleanup when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeleteUITarget()
        DeleteLogBuyerPed()
    end
end) 