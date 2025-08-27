local QBCore = exports['qb-core']:GetCoreObject()
local inventory = exports['ox_inventory']

-- Database storage for mining data (production ready)

-- Database Functions for Mining System
local function GetMiningPlayerData(citizenId)
    local result = exports.oxmysql:query_async('SELECT * FROM mining_players WHERE citizen_id = ?', {citizenId})
    if result and result[1] then
        print('^3[DEBUG] GetMiningPlayerData retrieved:^0')
        print('^3[DEBUG]   CitizenID:', result[1].citizen_id .. '^0')
        print('^3[DEBUG]   MiningXP:', result[1].mining_xp .. '^0')
        print('^3[DEBUG]   MiningLevel:', result[1].mining_level .. '^0')
        print('^3[DEBUG]   TotalMined:', result[1].total_mined .. '^0')
        print('^3[DEBUG]   TotalSmelted:', tostring(result[1].total_smelted) .. '^0')
        return result[1]
    end
    print('^3[DEBUG] GetMiningPlayerData: No data found for citizen:', citizenId .. '^0')
    return nil
end

local function CreateMiningPlayer(citizenId)
    local success = exports.oxmysql:insert_async('INSERT INTO mining_players (citizen_id, mining_xp, mining_level, total_mined, total_smelted) VALUES (?, 0, 1, 0, 0)', {citizenId})
    if success then
        return {
            citizen_id = citizenId,
            mining_xp = 0,
            mining_level = 1,
            total_mined = 0,
            total_smelted = 0
        }
    end
    return nil
end

local function UpdateMiningPlayerData(citizenId, miningXP, miningLevel, totalMined, totalSmelted)
    print('^3[DEBUG] UpdateMiningPlayerData called with:^0')
    print('^3[DEBUG]   CitizenID:', citizenId .. '^0')
    print('^3[DEBUG]   MiningXP:', miningXP .. '^0')
    print('^3[DEBUG]   MiningLevel:', miningLevel .. '^0')
    print('^3[DEBUG]   TotalMined:', totalMined .. '^0')
    print('^3[DEBUG]   TotalSmelted:', totalSmelted or 0 .. '^0')
    
    print('^3[DEBUG] Executing SQL: UPDATE mining_players SET mining_xp = ?, mining_level = ?, total_mined = ?, total_smelted = ?, last_mined = CURRENT_TIMESTAMP WHERE citizen_id = ?^0')
    print('^3[DEBUG] SQL Parameters:', miningXP, miningLevel, totalMined, (totalSmelted or 0), citizenId .. '^0')
    
    local success = exports.oxmysql:execute_async('UPDATE mining_players SET mining_xp = ?, mining_level = ?, total_mined = ?, total_smelted = ?, last_mined = CURRENT_TIMESTAMP WHERE citizen_id = ?', 
        {miningXP, miningLevel, totalMined, totalSmelted or 0, citizenId})
    
    print('^3[DEBUG] UpdateMiningPlayerData result:', tostring(success) .. '^0')
    if success then
        print('^2[SUCCESS] Database update executed successfully^0')
    else
        print('^1[ERROR] Database update failed^0')
    end
    return success
end

local function AddMiningHistory(citizenId, toolUsed, xpGained, itemsFound)
    local itemsJson = json.encode(itemsFound or {})
    local success = exports.oxmysql:insert_async('INSERT INTO mining_history (citizen_id, tool_used, xp_gained, items_found) VALUES (?, ?, ?, ?)', 
        {citizenId, toolUsed, xpGained, itemsJson})
    return success
end

-- Function to update smelting count specifically
local function UpdateSmeltingCount(citizenId, itemsSmelted)
    local success = exports.oxmysql:execute_async('UPDATE mining_players SET total_smelted = total_smelted + ? WHERE citizen_id = ?', 
        {itemsSmelted, citizenId})
    return success
end

local function GetMiningLeaderboard(limit, filterType)
    local query = ''
    local params = {}
    
    if filterType == 'level' then
        -- Sort by mining level (highest first)
        query = 'SELECT citizen_id, mining_level, mining_xp, total_mined, total_smelted FROM mining_players ORDER BY mining_level DESC, mining_xp DESC LIMIT ?'
    elseif filterType == 'smelted' then
        -- Sort by total smelted (highest first)
        query = 'SELECT citizen_id, mining_level, mining_xp, total_mined, total_smelted FROM mining_players ORDER BY total_smelted DESC, mining_level DESC LIMIT ?'
    elseif filterType == 'mined' then
        -- Sort by total mined (highest first)
        query = 'SELECT citizen_id, mining_level, mining_xp, total_mined, total_smelted FROM mining_players ORDER BY total_mined DESC, mining_level DESC LIMIT ?'
    else
        -- Default: sort by level
        query = 'SELECT citizen_id, mining_level, mining_xp, total_mined, total_smelted FROM mining_players ORDER BY mining_level DESC, mining_xp DESC LIMIT ?'
    end
    
    params = {limit or 20}
    local result = exports.oxmysql:query_async(query, params)
    
    if result then
        -- Get player names for each citizen_id
        for i, player in ipairs(result) do
            local playerData = QBCore.Functions.GetPlayerByCitizenId(player.citizen_id)
            if playerData then
                player.player_name = playerData.PlayerData.charinfo.firstname .. ' ' .. playerData.PlayerData.charinfo.lastname
            else
                player.player_name = 'Unknown Player'
            end
        end
    end
    
    return result or {}
end

-- XP System Functions
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
    if xp <= 0 then return 1, 0 end
    
    local level = 1
    local currentXP = xp  -- Changed from 0 to xp - this is the key fix!
    
    -- Use the new array-based system for more accurate level calculation
    if Config.XPSystem.levelRequirements then
        for checkLevel = 2, Config.XPSystem.maxLevel do
            local requiredXP = Config.XPSystem.levelRequirements[checkLevel]
            if requiredXP and xp >= requiredXP then
                level = checkLevel
                -- Don't override currentXP here - keep the actual XP value
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
                -- Don't override currentXP here - keep the actual XP value
            else
                break
            end
        end
    end
    
    return level, currentXP  -- Now returns the actual XP value
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
    else
        -- Fallback to old calculation
        levelStartXP = CalculateLevelXP(currentLevel)
        levelEndXP = CalculateLevelXP(currentLevel + 1)
    end
    
    local xpInLevel = currentXP - levelStartXP
    local xpNeeded = levelEndXP - levelStartXP
    
    if xpNeeded <= 0 then return 100 end
    return math.min(100, (xpInLevel / xpNeeded) * 100)
end

-- Function to get the player's skill tier
local function GetSkillTier(skillLevel)
    for _, tier in ipairs(Config.SkillSettings.tiers) do
        if skillLevel >= tier.level then
            return tier
        end
    end
    return Config.SkillSettings.tiers[1] -- Default to Beginner
end

-- Function to get a random item with skill-based chance boost
local function GetRandomItem(skillLevel, items)
    local tier = GetSkillTier(skillLevel)
    local totalChance = 0
    for _, item in pairs(items) do
        totalChance = totalChance + (item.chance * tier.chance_boost)
    end
    
    local random = math.random(1, math.floor(totalChance))
    local currentChance = 0
    
    for _, item in pairs(items) do
        currentChance = currentChance + (item.chance * tier.chance_boost)
        if random <= currentChance then
            return item
        end
    end
    
    return items[1] -- Fallback to first item
end

RegisterNetEvent('resource:gather', function(activity, zone)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    print('^3[DEBUG] resource:gather event received - Activity:', activity, 'Zone:', json.encode(zone) .. '^0')
    
    -- local skillLevel = exports['qb-skills']:getSkill(tostring(src), 'resource_gathering').level or 0
    local skillLevel = 1 -- Default level for testing
    local tier = GetSkillTier(skillLevel)
    local item = GetRandomItem(skillLevel, zone.items)
    if not item then return end
    
    -- Apply skill-based amount multiplier
    local baseAmount = math.random(item.amount.min, item.amount.max)
    local amount = math.floor(baseAmount * tier.amount_multiplier)
    if amount < 1 then amount = 1 end -- Ensure at least 1 item
    
    -- Debug: Check if item exists in ox_inventory
    local itemData = inventory:Items(item.name)
    if not itemData then
        print('^1[ERROR] Item not found in ox_inventory: ' .. item.name .. '^0')
        TriggerClientEvent('QBCore:Notify', src, 'Item not found in inventory system: ' .. item.name, 'error')
        return
    end
    
    local success = exports['ox_inventory']:AddItem(src, item.name, amount, nil)
    
    if success then
        -- Award skill XP and update mining data
        local xp = Config.XPSystem.rewards.mining or 20
        print('^3[DEBUG] Mining XP calculation - Base XP:', xp, 'Activity:', activity .. '^0')
        print('^3[DEBUG] Config.XPSystem.rewards.mining value:', Config.XPSystem.rewards.mining .. '^0')
        -- exports['17th-skills']:addSkill(tostring(src), 'resource_gathering', xp)
        -- Skills system disabled for basic testing
        
        -- Update player mining data in database
        local citizenId = Player.PlayerData.citizenid
        
        -- Get current mining data from database
        local miningData = GetMiningPlayerData(citizenId)
        if not miningData then
            -- Create new mining player if they don't exist
            miningData = CreateMiningPlayer(citizenId)
            if not miningData then
                print('^1[ERROR] Failed to create mining player data for: ' .. citizenId .. '^0')
                return
            end
        end
        
        -- Update mining data using proper XP system
        local currentXP = miningData.mining_xp + xp
        local currentTotalMined = miningData.total_mined + 1
        local currentLevel, actualXP = GetLevelFromXP(currentXP)
        
        print('^3[DEBUG] Mining XP update - Old XP:', miningData.mining_xp, 'New XP:', currentXP, 'Level:', currentLevel .. '^0')
        print('^3[DEBUG] GetLevelFromXP returned - Level:', currentLevel, 'ActualXP:', actualXP .. '^0')
        
        -- Update database with actual XP value (keep existing total_smelted)
        local currentTotalSmelted = miningData.total_smelted or 0
        print('^3[DEBUG] Mining update - XP:', actualXP, 'Level:', currentLevel, 'TotalMined:', currentTotalMined, 'TotalSmelted:', currentTotalSmelted .. '^0')
        
        print('^3[DEBUG] About to call UpdateMiningPlayerData with:^0')
        print('^3[DEBUG]   CitizenID:', citizenId .. '^0')
        print('^3[DEBUG]   MiningXP:', actualXP .. '^0')
        print('^3[DEBUG]   MiningLevel:', currentLevel .. '^0')
        print('^3[DEBUG]   TotalMined:', currentTotalMined .. '^0')
        print('^3[DEBUG]   TotalSmelted:', currentTotalSmelted .. '^0')
        
        local updateSuccess = UpdateMiningPlayerData(citizenId, actualXP, currentLevel, currentTotalMined, currentTotalSmelted)
        if not updateSuccess then
            print('^1[ERROR] Failed to update mining data for: ' .. citizenId .. '^0')
            return
        end
        
        print('^2[SUCCESS] Database update completed successfully^0')
        
        -- Add mining history
        AddMiningHistory(citizenId, 'pickaxe', xp, {name = item.name, amount = amount})
        
        print('^2[SUCCESS] Database updated successfully - XP:', actualXP, 'Level:', currentLevel, 'TotalMined:', currentTotalMined .. '^0')
        
        -- Send updated mining data to client for UI update (client will handle notifications)
        TriggerClientEvent('mining:updateMiningData', src, {
            xpGained = xp,
            itemsFound = {name = item.name, amount = amount},
            activity = activity,
            newTotalMined = currentTotalMined,
            newLevel = currentLevel,
            newXP = currentXP
        })
        
        print('^2[SUCCESS] Added ' .. amount .. 'x ' .. item.name .. ' to player ' .. src .. '^0')
    else
        -- Debug: Check why AddItem failed
        print('^1[ERROR] Failed to add ' .. amount .. 'x ' .. item.name .. ' to player ' .. src .. '^0')
        
        -- Check if player inventory is actually full
        local playerInventory = exports['ox_inventory']:GetInventory(src)
        if playerInventory then
            local totalWeight = playerInventory.weight or 0
            local maxWeight = playerInventory.maxWeight or 0
            print('^3[DEBUG] Player ' .. src .. ' inventory weight: ' .. totalWeight .. '/' .. maxWeight .. '^0')
        end
        
        -- Only send inventory full notification if the inventory is actually full
        TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full!', 'error')
    end
end)

RegisterNetEvent('resource:smelt', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    print('^3[DEBUG]^0 resource:smelt event received - Item:', itemName, 'Amount:', amount .. '^0')
    
    if not Config.RecyclingCenter.inputs[itemName] then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid item for smelting!', 'error')
        return
    end
    
    local itemCount = exports['ox_inventory']:GetItemCount(src, itemName)
    if not itemCount or itemCount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough ' .. itemName .. '!', 'error')
        return
    end
    
    local output = Config.RecyclingCenter.outputs[itemName]
    if not output then
        TriggerClientEvent('QBCore:Notify', src, 'No output defined for this item!', 'error')
        return
    end
    
    -- Get player's mining level for speed calculation
    local citizenId = Player.PlayerData.citizenid
    local miningData = GetMiningPlayerData(citizenId)
    local playerLevel = 1 -- Default level
    
    if miningData then
        playerLevel = miningData.mining_level or 1
    end
    
    -- Calculate smelting duration based on player level
    local smeltingConfig = Config.RecyclingCenter.smelting
    local baseDuration = smeltingConfig.baseDuration or 5000
    local duration = baseDuration
    
    -- Apply level-based speed bonus
    if smeltingConfig.levelMultipliers and smeltingConfig.levelMultipliers[playerLevel] then
        duration = math.floor(baseDuration * smeltingConfig.levelMultipliers[playerLevel])
    else
        -- Calculate speed bonus based on level
        local speedBonus = math.min(playerLevel * smeltingConfig.levelSpeedBonus, smeltingConfig.maxSpeedBonus)
        duration = math.floor(baseDuration * (1.0 - speedBonus))
    end
    
    -- Ensure duration stays within bounds
    duration = math.max(smeltingConfig.minDuration, math.min(smeltingConfig.maxDuration, duration))
    
    print('^3[DEBUG]^0 Smelting duration - Level:', playerLevel, 'Base:', baseDuration, 'Final:', duration .. '^0')
    
    -- Start smelting process with progress bar
    TriggerClientEvent('resource:startSmelting', src, {
        itemName = itemName,
        amount = amount,
        duration = duration,
        output = output,
        playerLevel = playerLevel
    })
end)

-- Smelting XP Event (DISABLED - Using new database system instead)
-- This old event was conflicting with the working smelting XP system
-- The new system handles smelting XP through resource:completeSmelting event
-- RegisterNetEvent('smelting:addXP', function(amount, itemsFound)
--     -- Event disabled to prevent conflicts
-- end)

-- Test command for leaderboard system
RegisterCommand('testleaderboard', function(source, args)
    local src = source
    if src == 0 then
        print('^1[ERROR] This command must be run by a player!^0')
        return
    end
    
    local filterType = args[1] or 'level'
    print('^3[DEBUG] Testing leaderboard with filter:', filterType .. '^0')
    
    -- Test the leaderboard system
    TriggerEvent('mining:getLeaderboardFiltered', src, filterType)
    
    print('^2[DEBUG] Leaderboard test completed for filter:', filterType .. '^0')
end, false)

-- Test command for database connection
RegisterCommand('testdb', function(source, args)
    local src = source
    if src == 0 then
        print('^1[ERROR] This command must be run by a player!^0')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenId = Player.PlayerData.citizenid
    print('^3[DEBUG] Testing database connection for player:', citizenId .. '^0')
    
    -- Test basic database operations
    local miningData = GetMiningPlayerData(citizenId)
    if miningData then
        print('^2[SUCCESS] Retrieved mining data:^0')
        print('^3[DEBUG]   XP:', miningData.mining_xp .. '^0')
        print('^3[DEBUG]   Level:', miningData.mining_level .. '^0')
        print('^3[DEBUG]   TotalMined:', miningData.total_mined .. '^0')
        print('^3[DEBUG]   TotalSmelted:', tostring(miningData.total_smelted) .. '^0')
    else
        print('^3[DEBUG] No mining data found, creating new player...^0')
        local newData = CreateMiningPlayer(citizenId)
        if newData then
            print('^2[SUCCESS] Created new mining player^0')
        else
            print('^1[ERROR] Failed to create mining player^0')
        end
    end
end, false)

-- Simple ping test event
RegisterNetEvent('test:ping', function(message)
    local src = source
    print('^2[DEBUG]^0 Received ping from player', src, 'Message:', message .. '^0')
    TriggerClientEvent('QBCore:Notify', src, 'Server received your ping!', 'success')
end)

-- Command to fix missing total_smelted values in database
RegisterCommand('fixsmeltingdb', function(source, args)
    local src = source
    if src ~= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'This command can only be run from console!', 'error')
        return
    end
    
    print('^3[DEBUG] Fixing missing total_smelted values in database...^0')
    
    -- Update all existing records to set total_smelted = 0 if it's NULL
    local success = exports.oxmysql:execute_async('UPDATE mining_players SET total_smelted = 0 WHERE total_smelted IS NULL')
    if success then
        print('^2[SUCCESS] Fixed missing total_smelted values^0')
    else
        print('^1[ERROR] Failed to fix total_smelted values^0')
    end
    
    -- Show current database state
    local result = exports.oxmysql:query_async('SELECT COUNT(*) as total, COUNT(total_smelted) as with_smelting FROM mining_players')
    if result and result[1] then
        print('^3[DEBUG] Database state:^0')
        print('^3[DEBUG]   Total players:', result[1].total .. '^0')
        print('^3[DEBUG]   Players with total_smelted:', result[1].with_smelting .. '^0')
    end
end, true)

-- Command to manually add XP for testing
RegisterCommand('addxp', function(source, args)
    local src = source
    if src == 0 then
        print('^1[ERROR] This command must be run by a player!^0')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local xpAmount = tonumber(args[1]) or 50
    local activity = args[2] or 'mining'
    
    print('^3[DEBUG] Manually adding XP - Player:', src, 'Amount:', xpAmount, 'Activity:', activity .. '^0')
    
    local citizenId = Player.PlayerData.citizenid
    local miningData = GetMiningPlayerData(citizenId)
    
    if not miningData then
        miningData = CreateMiningPlayer(citizenId)
        if not miningData then
            print('^1[ERROR] Failed to create mining player data^0')
            return
        end
    end
    
    -- Add XP and update level
    local currentXP = miningData.mining_xp + xpAmount
    local currentLevel, actualXP = GetLevelFromXP(currentXP)
    
    print('^3[DEBUG] XP Update - Old XP:', miningData.mining_xp, 'New XP:', currentXP, 'Level:', currentLevel .. '^0')
    
    -- Update database
    local updateSuccess = UpdateMiningPlayerData(citizenId, actualXP, currentLevel, miningData.total_mined, miningData.total_smelted or 0)
    if updateSuccess then
        print('^2[SUCCESS] XP updated successfully^0')
        TriggerClientEvent('QBCore:Notify', src, 'Added ' .. xpAmount .. ' XP! New total: ' .. currentXP, 'success')
        
        -- Send updated data to client
        TriggerClientEvent('mining:updateMiningData', src, {
            xpGained = xpAmount,
            itemsFound = {name = 'manual_xp', amount = 1},
            activity = activity,
            newTotalMined = miningData.total_mined,
            newTotalSmelted = miningData.total_smelted or 0,
            newLevel = currentLevel,
            newXP = currentXP
        })
    else
        print('^1[ERROR] Failed to update XP^0')
        TriggerClientEvent('QBCore:Notify', src, 'Failed to update XP!', 'error')
    end
end, false)

-- Mining XP Event (DISABLED - Using new database system instead)
-- This old event was causing conflicts with the new database-based XP system
-- The new system handles XP through the mining activity events automatically
-- RegisterNetEvent('mining:addXP', function(amount, toolType, itemsFound)
--     -- Event disabled to prevent conflicts
-- end)

-- Get Player Data Event
RegisterNetEvent('mining:getPlayerData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenId = Player.PlayerData.citizenid
    
    -- Database functions temporarily disabled for testing
    -- local miningData = GetMiningPlayerData(citizenId)
    -- if not miningData then
    --     -- Create new mining player if they don't exist
    --     miningData = CreateMiningPlayer(citizenId)
    --     if not miningData then
    --         print('Failed to create mining player data for: ' .. citizenId)
    --         return
    --     end
    -- end
    
    -- Get mining data from database
    local miningData = GetMiningPlayerData(citizenId)
    if not miningData then
        -- Create new mining player if they don't exist
        miningData = CreateMiningPlayer(citizenId)
        if not miningData then
            print('^1[ERROR] Failed to create mining player data for: ' .. citizenId .. '^0')
            return
        end
    end
    
    -- Calculate proper XP values using the XP system functions
    local currentLevel, actualXP = GetLevelFromXP(miningData.mining_xp)
    local xpForNextLevel = GetXPForNextLevel(currentLevel)
    local xpProgress = GetXPProgress(currentLevel, miningData.mining_xp)
    
    local playerData = {
        level = currentLevel,
        xp = miningData.mining_xp,
        totalMined = miningData.total_mined,
        totalSmelted = miningData.total_smelted or 0,
        xpForNextLevel = xpForNextLevel,
        xpProgress = xpProgress
    }
    
    TriggerClientEvent('mining:updatePlayerData', src, playerData)
end)

-- Debug command to set player XP (temporary for testing)
RegisterCommand('setminingxp', function(source, args, rawCommand)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local targetXP = tonumber(args[1]) or 100 -- Default to 100 XP (level 2)
    local citizenId = Player.PlayerData.citizenid
    
    local miningData = GetMiningPlayerData(citizenId)
    if not miningData then
        miningData = CreateMiningPlayer(citizenId)
        if not miningData then
            print('^1[ERROR] Failed to create mining player data for: ' .. citizenId .. '^0')
            return
        end
    end
    
    local currentLevel, actualXP = GetLevelFromXP(targetXP)
    local updateSuccess = UpdateMiningPlayerData(citizenId, actualXP, currentLevel, miningData.total_mined)
    
    if updateSuccess then
        TriggerClientEvent('QBCore:Notify', src, 'Mining XP set to ' .. targetXP .. ' (Level ' .. currentLevel .. ')', 'success')
        print('^2[DEBUG] Set player ' .. src .. ' mining XP to ' .. targetXP .. ' (Level ' .. currentLevel .. ')^0')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to update mining XP', 'error')
    end
end, false)

-- Get Mining Leaderboard Event
RegisterNetEvent('mining:getLeaderboard', function(filterType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Default to level filter if none specified
    filterType = filterType or 'level'
    
    print('^3[DEBUG]^0 Getting leaderboard with filter:', filterType .. '^0')
    
    -- Get leaderboard data from database (top 20)
    local leaderboardData = GetMiningLeaderboard(20, filterType)
    
    -- Format leaderboard data for UI
    local formattedLeaderboard = {}
    for i, player in ipairs(leaderboardData) do
        table.insert(formattedLeaderboard, {
            rank = i,
            name = player.player_name or 'Unknown',
            level = player.mining_level or 1,
            xp = player.mining_xp or 0,
            totalMined = player.total_mined or 0,
            totalSmelted = player.total_smelted or 0
        })
    end
    
    print('^3[DEBUG]^0 Sending leaderboard with', #formattedLeaderboard, 'players, filter:', filterType .. '^0')
    
    TriggerClientEvent('mining:updateLeaderboard', src, formattedLeaderboard, filterType)
end)

-- Get Leaderboard with Specific Filter Event
RegisterNetEvent('mining:getLeaderboardFiltered', function(filterType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not filterType or (filterType ~= 'level' and filterType ~= 'smelted' and filterType ~= 'mined') then
        filterType = 'level' -- Default to level filter
    end
    
    print('^3[DEBUG]^0 Getting filtered leaderboard:', filterType .. '^0')
    
    -- Get leaderboard data with specific filter
    local leaderboardData = GetMiningLeaderboard(20, filterType)
    
    -- Format leaderboard data for UI
    local formattedLeaderboard = {}
    for i, player in ipairs(leaderboardData) do
        table.insert(formattedLeaderboard, {
            rank = i,
            name = player.player_name or 'Unknown',
            level = player.mining_level or 1,
            xp = player.mining_xp or 0,
            totalMined = player.total_mined or 0,
            totalSmelted = player.total_smelted or 0
        })
    end
    
    print('^3[DEBUG]^0 Sending filtered leaderboard with', #formattedLeaderboard, 'players, filter:', filterType .. '^0')
    
    TriggerClientEvent('mining:updateLeaderboard', src, formattedLeaderboard, filterType)
end)

-- Give tool to player (DEPRECATED - Use purchaseTool event instead)
RegisterNetEvent('mining:giveTool', function(toolType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check if equipment shop is enabled and require payment
    if Config.EquipmentShop.enabled then
        TriggerClientEvent('QBCore:Notify', src, 'Tools must be purchased through the equipment shop!', 'error')
        return
    end
    
    -- Check if this tool exists in config by searching through items
    local itemConfig = nil
    for configKey, configItem in pairs(Config.Inventory.items) do
        if configItem.name == toolType then
            itemConfig = configItem
            break
        end
    end
    
    if not itemConfig then return end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system
        local success = exports['ox_inventory']:AddItem(src, itemConfig.name, 1, {
            durability = 100,
            level = 1,
            bonus = 0
        })
        
        if success then
            TriggerClientEvent('QBCore:Notify', src, 'You received a ' .. itemConfig.label .. '!', 'primary')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to give tool. Inventory might be full.', 'error')
        end
    end
end)

-- Check if player has tool
RegisterNetEvent('mining:checkTool', function(toolType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check if this tool exists in config by searching through items
    local itemConfig = nil
    for configKey, configItem in pairs(Config.Inventory.items) do
        if configItem.name == toolType then
            itemConfig = configItem
            break
        end
    end
    
    if not itemConfig then return end
    
    if Config.Inventory.system == 'ox_inventory' then
        -- ox_inventory system
        local count = exports['ox_inventory']:GetItemCount(src, itemConfig.name)
        TriggerClientEvent('mining:toolCheckResult', src, toolType, count > 0)
    end
end)

-- Get recyclable items for ox_inventory
RegisterNetEvent('mining:getRecyclableItems', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if Config.Inventory.system == 'ox_inventory' then
        local items = {}
        
        -- Get all items from ox_inventory
        local inventory = exports['ox_inventory']:GetInventory(src)
        if inventory and inventory.items then
            for _, item in pairs(inventory.items) do
                if Config.RecyclingCenter.inputs[item.name] then
                    table.insert(items, {
                        name = item.name,
                        label = item.label or item.name,
                        count = item.count
                    })
                end
            end
        end
        
        TriggerClientEvent('mining:recyclableItems', src, items)
    end
end)

-- New smelting completion event (called after progress bar finishes)
RegisterNetEvent('resource:completeSmelting', function(itemName, amount, output, playerLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    print('^3[DEBUG]^0 Smelting completed - Item:', itemName, 'Amount:', amount, 'Level:', playerLevel .. '^0')
    
    -- Calculate output amount
    local outputAmount = math.floor(amount * output.ratio)
    if outputAmount < 1 then outputAmount = 1 end
    
    -- Add smelted items to player inventory
    local addSuccess = exports['ox_inventory']:AddItem(src, output.item, outputAmount)
    if addSuccess then
        local itemData = inventory:Items(output.item)
        TriggerClientEvent('QBCore:Notify', src, 'You received ' .. outputAmount .. 'x ' .. (itemData?.label or output.item), 'primary')
        TriggerClientEvent('resource:smeltEffect', src)
        
        -- Award smelting XP PER ITEM (not per process)
        local baseXP = Config.XPSystem.rewards.smelting or 30
        local totalXP = baseXP * amount -- XP per item × number of items
        print('^3[DEBUG]^0 Smelting XP calculation - Base XP per item:', baseXP, 'Items smelted:', amount, 'Total XP:', totalXP .. '^0')
        
        -- Update player mining data in database
        local citizenId = Player.PlayerData.citizenid
        local miningData = GetMiningPlayerData(citizenId)
        if not miningData then
            miningData = CreateMiningPlayer(citizenId)
            if not miningData then
                print('^1[ERROR] Failed to create mining player data for: ' .. citizenId .. '^0')
                return
            end
        end
        
        -- Update mining data - total smelted increases by actual items processed
        local currentXP = miningData.mining_xp + totalXP
        local currentTotalMined = miningData.total_mined + 1
        local currentTotalSmelted = (miningData.total_smelted or 0) + amount -- Increase by items processed, not output
        local currentLevel, actualXP = GetLevelFromXP(currentXP)
        
        print('^3[DEBUG]^0 Smelting database update - XP gained:', totalXP, 'Total items processed:', amount, 'New total smelted:', currentTotalSmelted .. '^0')
        
        local updateSuccess = UpdateMiningPlayerData(citizenId, actualXP, currentLevel, currentTotalMined, currentTotalSmelted)
        if not updateSuccess then
            print('^1[ERROR] Failed to update mining data for: ' .. citizenId .. '^0')
            return
        end
        
        -- Add mining history for each item processed
        AddMiningHistory(citizenId, 'smelting', totalXP, {name = output.item, amount = outputAmount})
        
        -- Trigger client update for UI
        TriggerClientEvent('mining:updateMiningData', src, {
            xpGained = totalXP,
            itemsFound = {name = output.item, amount = outputAmount},
            activity = 'smelting',
            newTotalMined = currentTotalMined,
            newTotalSmelted = currentTotalSmelted,
            newLevel = currentLevel,
            newXP = currentXP
        })
        
        print('^2[SUCCESS]^0 Smelting completed - Total XP:', totalXP, 'Level:', currentLevel, 'TotalSmelted:', currentTotalSmelted .. '^0')
    else
        -- Refund input items if inventory is full
        exports['ox_inventory']:AddItem(src, itemName, amount)
        TriggerClientEvent('QBCore:Notify', src, 'Your inventory is full! Items refunded.', 'error')
    end
end)

-- Log selling event
RegisterNetEvent('17th-resourcegathering:server:sellLogs', function(amount, paymentMethod)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Validate amount
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid amount!', 'error')
        return
    end
    
    -- Check if player has enough wood logs
    local playerLogs = exports['ox_inventory']:GetItemCount(src, 'wood_log')
    if playerLogs < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough wood logs!', 'error')
        return
    end
    
    -- Calculate payment
    local pricePerLog = Config.LogBuyer.items.wood_log.price
    local totalPayment = amount * pricePerLog
    
    -- Remove wood logs from player
    local removeSuccess = exports['ox_inventory']:RemoveItem(src, 'wood_log', amount)
    if not removeSuccess then
        TriggerClientEvent('QBCore:Notify', src, 'Failed to remove wood logs!', 'error')
        return
    end
    
    -- Add payment to player
    if paymentMethod == 'cash' then
        Player.Functions.AddMoney('cash', totalPayment, 'wood-logs-sold')
    elseif paymentMethod == 'bank' then
        Player.Functions.AddMoney('bank', totalPayment, 'wood-logs-sold')
    else
        -- Default to bank if invalid payment method
        Player.Functions.AddMoney('bank', totalPayment, 'wood-logs-sold')
    end
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', src, string.format('Sold %d wood logs for $%d (%s)', amount, totalPayment, paymentMethod:upper()), 'success')
    
    print('^2[SUCCESS]^0 Player ' .. Player.PlayerData.name .. ' sold ' .. amount .. ' wood logs for $' .. totalPayment .. ' (' .. paymentMethod .. ')')
end)

-- Tool purchase event with payment
RegisterNetEvent('17th-resourcegathering:server:purchaseTool', function(toolType, paymentMethod)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check if equipment shop is enabled
    if not Config.EquipmentShop.enabled then
        TriggerClientEvent('QBCore:Notify', src, 'Equipment shop is currently disabled!', 'error')
        return
    end
    
    -- Get tool configuration
    local toolConfig = Config.EquipmentShop.items[toolType]
    if not toolConfig then
        TriggerClientEvent('QBCore:Notify', src, 'Tool not found in shop configuration!', 'error')
        return
    end
    
    -- Get tool price
    local toolPrice = toolConfig.price
    if not toolPrice or toolPrice <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Tool price not configured!', 'error')
        return
    end
    
    -- Check if player already has the tool
    local hasTool = exports['ox_inventory']:GetItemCount(src, toolType)
    if hasTool > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You already own this tool!', 'error')
        return
    end
    
    -- Additional validation: check if the tool exists in the inventory system
    local itemExists = exports['ox_inventory']:Items(toolType)
    if not itemExists then
        TriggerClientEvent('QBCore:Notify', src, 'This tool is not available in the inventory system!', 'error')
        return
    end
    
    -- Check if player has enough money
    local playerMoney = 0
    if paymentMethod == 'cash' then
        playerMoney = Player.PlayerData.money.cash
    elseif paymentMethod == 'bank' then
        playerMoney = Player.PlayerData.money.bank
    else
        TriggerClientEvent('QBCore:Notify', src, 'Invalid payment method!', 'error')
        return
    end
    
    if playerMoney < toolPrice then
        TriggerClientEvent('QBCore:Notify', src, string.format('You need $%d to purchase this tool!', toolPrice), 'error')
        return
    end
    
    -- Check if player has inventory space (this is a basic check)
    local inventory = exports['ox_inventory']:GetInventory(src)
    if inventory and inventory.weight and inventory.maxWeight then
        local availableWeight = inventory.maxWeight - inventory.weight
        local toolWeight = itemExists.weight or 1000 -- Default weight if not specified
        if availableWeight < toolWeight then
            TriggerClientEvent('QBCore:Notify', src, 'Your inventory is too full to carry this tool!', 'error')
            return
        end
    end
    
    -- Remove money from player
    if paymentMethod == 'cash' then
        Player.Functions.RemoveMoney('cash', toolPrice, 'tool-purchase-' .. toolType)
    elseif paymentMethod == 'bank' then
        Player.Functions.RemoveMoney('bank', toolPrice, 'tool-purchase-' .. toolType)
    end
    
    -- Give tool to player
    local success = exports['ox_inventory']:AddItem(src, toolType, 1, {
        durability = 100,
        level = 1,
        bonus = 0
    })
    
    if success then
        TriggerClientEvent('QBCore:Notify', src, string.format('Successfully purchased %s for $%d!', toolConfig.label, toolPrice), 'success')
        
        -- Send NUI message to update equipment ownership
        TriggerClientEvent('17th-resourcegathering:client:toolPurchaseSuccess', src, toolType)
        
        print('^2[SUCCESS]^0 Player ' .. Player.PlayerData.name .. ' purchased ' .. toolType .. ' for $' .. toolPrice .. ' (' .. paymentMethod .. ')')
    else
        -- Refund money if tool couldn't be given
        if paymentMethod == 'cash' then
            Player.Functions.AddMoney('cash', toolPrice, 'tool-purchase-refund-' .. toolType)
        elseif paymentMethod == 'bank' then
            Player.Functions.AddMoney('bank', toolPrice, 'tool-purchase-refund-' .. toolType)
        end
        TriggerClientEvent('QBCore:Notify', src, 'Failed to give tool. Your money has been refunded.', 'error')
        
        -- Send NUI message to indicate purchase failure
        TriggerClientEvent('17th-resourcegathering:client:toolPurchaseFailed', src, toolType)
        
        print('^1[ERROR]^0 Failed to give tool to player ' .. Player.PlayerData.name .. ' for ' .. toolType .. '. Money refunded.')
    end
end)