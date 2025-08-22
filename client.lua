local QBCore = exports['17th-base']:GetCoreObject()
local cooldowns = {}
local mergedZones = {}
local zoneProps = {} -- Tracks props per merged zone
local activeZones = {} -- Tracks active sphere zones
local defaultMergeRadius = 200.0

-- UI Target Variables
local uiTargetPed = nil
local uiTargetBlip = nil
local uiOpen = false

local function HasRequiredTool(activity)
    local ped = PlayerPedId()
    local tool = nil
    
    if activity == 'logging' then
        tool = 'weapon_hatchet'
    elseif activity == 'mining' then
        tool = 'pickaxe'
    elseif activity == 'scavenging' then
        tool = 'weapon_crowbar'
    elseif activity == 'foraging' then
        return true  
    end
    
    if not tool then return true end
    local count = exports['17th-inventory']:Search('count', tool)
    local hasItem = false
    if type(count) == 'table' then
        for item, val in pairs(count) do
            if item:lower() == tool:lower() then
                hasItem = val > 0
                break
            end
        end
    elseif type(count) == 'number' then
        hasItem = count > 0
    end

    if not hasItem then
        QBCore.Functions.Notify('Material', 'You need a ' .. tool .. ' for this activity!', 'error')
        return false
    end
    return true
end

-- Function to check cooldown
local function CheckCooldown(activity)
    if cooldowns[activity] and cooldowns[activity] > GetGameTimer() then
        local timeLeft = math.ceil((cooldowns[activity] - GetGameTimer()) / 1000)
        QBCore.Functions.Notify('Material', 'You need to wait ' .. timeLeft .. ' seconds before doing this again!', 'error')
        return false
    end
    return true
end

-- Function to set cooldown
local function SetCooldown(activity)
    cooldowns[activity] = GetGameTimer() + (Config.Cooldowns[activity] * 1000)
end

-- Utility: Get specific spawn coordinate from zone
local function GetSpawnCoordinate(zone, index)
    if zone.spawn_coords and zone.spawn_coords[index] then
        return zone.spawn_coords[index]
    end
    -- Fallback to center coords if no specific spawn coords are defined
    return zone.coords
end

local minigames = {
    function() return exports['17th-minigames']:timedBar(3, 1, "normal") end,
    -- function() return exports['17th-minigames']:timedButton(3, "normal") end,
    function() return exports['17th-minigames']:buttonMashing(5, 10) end,
    function() Wait(1000) return exports['17th-minigames']:quickTimeEvent("normal") end,
    -- function() return exports['17th-minigames']:typingGame("normal", 15) end,
    function() return lib.skillCheck({ 'easy', 'medium', 'medium' }, { 'w', 'a', 's', 'd' }) end,
}

-- Randomize function execution
local function StartBoiiSkillCircle(successCb, failCb)
    math.randomseed(GetGameTimer()) -- ensures better randomness
    local randomIndex = math.random(1, #minigames)
    local result = minigames[randomIndex]()

    if result then
        successCb()
    else
        failCb()
    end
end

-- Show progress bar
local function ShowHarvestProgressBar(activity, cb)
    local progress = Config.ProgressBar[activity]
    if not progress then return cb() end
    
    local anim = Config.Animations[activity]
    local ped = PlayerPedId()
    local propEntity = nil

    -- Attach prop before starting progress bar
    if anim.prop then
        local propHash = GetHashKey(anim.prop)
        RequestModel(propHash)
        while not HasModelLoaded(propHash) do Wait(10) end
        local coords = GetEntityCoords(ped)
        propEntity = CreateObject(propHash, coords.x, coords.y, coords.z + 0.2, true, true, true)
        AttachEntityToEntity(propEntity, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.03, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
    end

    -- Play animation if specified
    if anim.dict and anim.anim then
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do Wait(10) end
        TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    -- Show ox_lib progress bar
    local success = lib.progressBar({
        duration = progress.duration,
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

    -- Clean up
    ClearPedTasks(ped)
    if propEntity and DoesEntityExist(propEntity) then
        DeleteEntity(propEntity)
    end

    -- Handle result
    if success then
        cb()
    else
        lib.notify({
            title = 'Material',
            description = 'Cancelled',
            type = 'error'
        })
    end
end

-- Prop management
local spawnedProps = {}
local propStates = {}

-- Table to track animated props
local animatedProps = {}

-- Play particle effect at a location, using the correct particle for the activity
local function PlayHarvestEffect(coords, activity)
    local particle = Config.Animations[activity] and Config.Animations[activity].particle
    if particle and particle.asset and particle.name then
        UseParticleFxAssetNextCall(particle.asset)
        StartParticleFxNonLoopedAtCoord(particle.name, coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    else
        -- fallback
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('ent_sht_plant', coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
    -- Play sound
    PlaySoundFromCoord(-1, 'Pickup_Collect', coords.x, coords.y, coords.z, '', false, 0, false)
end

-- Play recycling effect at recycling center
local function PlayRecyclingEffect()
    local c = Config.RecyclingCenter.coords
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_dst_gen_garbage', c.x, c.y, c.z + 1.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    PlaySoundFromCoord(-1, 'Drill_Pin_Break', c.x, c.y, c.z, '', false, 0, false)
end

-- Recycling center functionality
local function OpenRecyclingMenu()
    local Player = QBCore.Functions.GetPlayerData()
    local items = {}
    

    for _, item in pairs(Player.items) do
        if Config.RecyclingCenter.inputs[item.name] then
            local count = exports.ox_inventory:GetItemCount(item.name)
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
                                if amount >= 5 then
                                    local confirm = lib.alertDialog({
                                        header = 'Bulk Processing Risk',
                                        content = 'You are about to bulk process ' .. amount .. ' items. You have a 50% chance to double your output, but a 50% chance to lose everything! Continue?',
                                        centered = true,
                                        cancel = true
                                    })
                                    if confirm == 'confirm' then
                                        TriggerServerEvent('resource:recycle', item.name, amount, true)
                                    end
                                else
                                    TriggerServerEvent('resource:recycle', item.name, amount, false)
                                end
                            else
                                QBCore.Functions.Notify('Material', 'Invalid amount!', 'error')
                            end
                        end
                    end
                })
            end
        end
    end
    
    if #items == 0 then
        QBCore.Functions.Notify('Material', 'You don\'t have any items to recycle!', 'error')
        return
    end
    
    lib.registerContext({
        id = 'recycling_menu',
        title = 'Recycling Center',
        options = items
    })
    
    lib.showContext('recycling_menu')
end

-- Create recycling center
local function CreateRecyclingCenter()
    exports['17th-target']:addBoxZone({
        coords = Config.RecyclingCenter.coords,
        size = vector3(2, 2, 2),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'recycling_center',
                icon = 'fa-solid fa-recycle',
                label = 'Recycle Materials',
                onSelect = function()
                    if not CheckCooldown('recycling') then return end
                    OpenRecyclingMenu()
                end,
                distance = 2.0,
            }
        }
    })
end

-- Blip creation
local function CreateGatheringBlips()
    if not Config.Blips or not Config.Blips.enabled then return end
    for activity, zones in pairs(Config.Zones) do
        local blipCfg = Config.Blips[activity]
        if blipCfg and blipCfg.enabled then
            for _, zone in ipairs(zones) do
                local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
                SetBlipSprite(blip, blipCfg.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, blipCfg.scale)
                SetBlipColour(blip, blipCfg.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(blipCfg.label)
                EndTextCommandSetBlipName(blip)
            end
        end
    end
    -- Recycling center blip
    local recycleCfg = Config.Blips.recycling
    if recycleCfg and recycleCfg.enabled and Config.RecyclingCenter and Config.RecyclingCenter.coords then
        local c = Config.RecyclingCenter.coords
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, recycleCfg.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, recycleCfg.scale)
        SetBlipColour(blip, recycleCfg.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(recycleCfg.label)
        EndTextCommandSetBlipName(blip)
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

            exports['17th-target']:addLocalEntity(obj, {
                {
                    name = propId,
                    icon = 'fa-leaf',
                    label = 'Harvest',
                    onSelect = function()
                        if not propStates[propId] then return end
                        if not HasRequiredTool(activity) then return end
                        if not CheckCooldown(activity) then return end
                        StartBoiiSkillCircle(
                            function()
                                ShowHarvestProgressBar(activity, function()
                                    propStates[propId] = false
                                    SetEntityVisible(obj, false, false)
                                    SetEntityCollision(obj, false, false)
                                    animatedProps[propId] = nil
                                    PlayHarvestEffect(GetEntityCoords(obj), activity)
                                    TriggerServerEvent('resource:gather', activity, zone)
                                    SetCooldown(activity)
                                    QBCore.Functions.Notify('Material', 'Success!', 'success')
                                    Citizen.SetTimeout(15000, function()
                                        if DoesEntityExist(obj) then
                                            DeleteEntity(obj)
                                            zoneProps[zoneId][propId] = nil
                                        end
                                        local newPos = zone.spawn_coords[i] -- Use same spawn_coords
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
                                        exports['17th-target']:addLocalEntity(newObj, {
                                            {
                                                name = propId,
                                                icon = 'fa-leaf',
                                                label = 'Harvest',
                                                distance = 2.0,
                                                onSelect = function()
                                                    if not propStates[propId] then return end
                                                    if not HasRequiredTool(activity) then return end
                                                    if not CheckCooldown(activity) then return end
                                                    StartBoiiSkillCircle(
                                                        function()
                                                            ShowHarvestProgressBar(activity, function()
                                                                propStates[propId] = false
                                                                SetEntityVisible(newObj, false, false)
                                                                SetEntityCollision(newObj, false, false)
                                                                animatedProps[propId] = nil
                                                                PlayHarvestEffect(GetEntityCoords(newObj), activity)
                                                                TriggerServerEvent('resource:gather', activity, zone)
                                                                SetCooldown(activity)
                                                                QBCore.Functions.Notify('Material', 'Success!', 'success')
                                                            end)
                                                        end,
                                                        function()
                                                            QBCore.Functions.Notify('Material', 'Failed mini-game!', 'error')
                                                        end
                                                    )
                                                end
                                            }
                                        })
                                    end)
                                end)
                            end,
                            function()
                                QBCore.Functions.Notify('Material', 'Failed mini-game!', 'error')
                            end
                        )
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
        exports['17th-target']:removeLocalEntity(obj)
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
    CreateRecyclingCenter()
    InitializeSphereZones()
end)

-- (Optional) Clean up props on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(spawnedProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)

AddEventHandler('Base17th:Client:OnPlayerLoaded', function ()
    InitializeSphereZones()
end)

-- Play recycling effect when recycling
RegisterNetEvent('resource:recycleEffect', function()
    PlayRecyclingEffect()
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
        QBCore.Functions.Notify('Material', 'You must be in a gathering zone to start!', 'error')
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
    local risky = data.risky
    
    -- Check if player is at recycling center
    local playerCoords = GetEntityCoords(PlayerPedId())
    local recyclingCenter = Config.RecyclingCenter.coords
    local distance = #(playerCoords - recyclingCenter)
    
    if distance > 10.0 then
        QBCore.Functions.Notify('Material', 'You must be at the recycling center to recycle items!', 'error')
        cb('error')
        return
    end
    
    -- Start recycling process
    TriggerServerEvent('resource:recycle', item, amount, risky)
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
    StartBoiiSkillCircle(
        function() -- Success callback
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
                        
                        -- Show success notification
                        QBCore.Functions.Notify('Material', 'Successfully gathered resources!', 'success')
                        
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
        end,
        function() -- Fail callback
            QBCore.Functions.Notify('Material', 'Failed to gather resources!', 'error')
        end
    )
end

-- Update player data in UI
local function UpdatePlayerDataInUI()
    local playerData = {
        level = 1, -- This should come from your skills system
        xp = 0,   -- This should come from your skills system
        tier = 'Beginner',
        totalGathered = 0,
        totalRecycled = 0
    }
    
    -- Get actual data from your skills system
    -- playerData.level = exports['17th-skills']:getSkill(GetPlayerServerId(PlayerId()), 'resource_gathering').level or 1
    -- playerData.xp = exports['17th-skills']:getSkill(GetPlayerServerId(PlayerId()), 'resource_gathering').xp or 0
    
    SendNUIMessage({
        type = 'updatePlayerData',
        playerData = playerData
    })
end

-- Update UI when player data changes
CreateThread(function()
    while true do
        Wait(5000) -- Update every 5 seconds
        UpdatePlayerDataInUI()
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
        exports['qb-target']:AddTargetEntity(uiTargetPed, {
            options = {
                {
                    type = "client",
                    event = "mining:openUI",
                    icon = "fas fa-mountain",
                    label = "Access Mining Operations",
                    distance = Config.UITarget.distance
                }
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
        type = 'showUI'
    })
    
    -- Get player data and update UI
    UpdatePlayerDataInUI()
end

-- Function to close mining UI
function CloseMiningUI()
    if not uiOpen then return end
    
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideUI'
    })
end

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    CloseMiningUI()
    cb('ok')
end)

-- NUI Callback for purchasing equipment
RegisterNUICallback('purchaseEquipment', function(data, cb)
    local toolType = data.toolType
    local playerLevel = data.playerLevel
    
    -- Check if player meets level requirement
    local requiredLevel = 0
    if toolType == 'pickaxe' then
        requiredLevel = 0
    elseif toolType == 'drill' then
        requiredLevel = 21
    elseif toolType == 'laser' then
        requiredLevel = 51
    end
    
    if playerLevel < requiredLevel then
        cb({ success = false, message = 'Level ' .. requiredLevel .. ' required for ' .. toolType })
        return
    end
    
    -- Check if player already has the tool
    if HasMiningTool(toolType) then
        cb({ success = false, message = 'You already own this tool' })
        return
    end
    
    -- Give the tool to player
    local success = GiveMiningTool(toolType)
    if success then
        cb({ success = true, message = 'Tool purchased successfully!' })
        -- Update UI to reflect new ownership
        SendNUIMessage({
            type = 'updateEquipment',
            toolType = toolType,
            owned = true
        })
    else
        cb({ success = false, message = 'Failed to give tool. Inventory might be full.' })
    end
end)

-- qb-target event handler
RegisterNetEvent('mining:openUI', function()
    OpenMiningUI()
end)

-- Function to give item to player based on inventory system
local function GiveMiningTool(toolType)
    local itemConfig = Config.Inventory.items[toolType]
    if not itemConfig then return false end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system
        local success = exports.ox_inventory:AddItem(itemConfig.name, 1, {
            durability = 100,
            level = 1,
            bonus = 0
        })
        return success
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
    local itemConfig = Config.Inventory.items[toolType]
    if not itemConfig then return false end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system
        local count = exports.ox_inventory:GetItemCount(itemConfig.name)
        return count > 0
    elseif Config.Inventory.system == 'qb-inventory' then
        -- qb-inventory system
        local hasItem = QBCore.Functions.HasItem(itemConfig.name)
        return hasItem
    end
    
    return false
end

-- Create UI target when resource starts
CreateThread(function()
    Wait(1000) -- Wait for everything to load
    CreateUITarget()
end)

-- Cleanup when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeleteUITarget()
    end
end) 