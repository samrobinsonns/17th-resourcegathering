local QBCore = exports['17th-base']:GetCoreObject()
local inventory = exports['17th-inventory']

-- Database Functions for Mining System
local function GetMiningPlayerData(citizenId)
    local result = MySQL.query.await('SELECT * FROM mining_players WHERE citizen_id = ?', {citizenId})
    if result and result[1] then
        return result[1]
    end
    return nil
end

local function CreateMiningPlayer(citizenId)
    local success = MySQL.insert.await('INSERT INTO mining_players (citizen_id, mining_xp, mining_level, total_mined) VALUES (?, 0, 1, 0)', {citizenId})
    if success then
        return {
            citizen_id = citizenId,
            mining_xp = 0,
            mining_level = 1,
            total_mined = 0
        }
    end
    return nil
end

local function UpdateMiningPlayerData(citizenId, miningXP, miningLevel, totalMined)
    local success = MySQL.update.await('UPDATE mining_players SET mining_xp = ?, mining_level = ?, total_mined = ?, last_mined = CURRENT_TIMESTAMP WHERE citizen_id = ?', 
        {miningXP, miningLevel, totalMined, citizenId})
    return success
end

local function AddMiningHistory(citizenId, toolUsed, xpGained, itemsFound)
    local itemsJson = json.encode(itemsFound or {})
    local success = MySQL.insert.await('INSERT INTO mining_history (citizen_id, tool_used, xp_gained, items_found) VALUES (?, ?, ?, ?)', 
        {citizenId, toolUsed, xpGained, itemsJson})
    return success
end

local function GetMiningLeaderboard(limit)
    local result = MySQL.query.await('SELECT * FROM mining_leaderboard LIMIT ?', {limit or 10})
    return result or {}
end

-- XP System Functions
local function CalculateLevelXP(level)
    if level <= 1 then return 0 end
    
    local totalXP = 0
    for i = 2, level do
        totalXP = totalXP + (Config.XPSystem.xpPerLevel * math.pow(Config.XPSystem.xpMultiplier, i - 2))
    end
    return math.floor(totalXP)
end

local function GetLevelFromXP(xp)
    if xp <= 0 then return 1 end
    
    local level = 1
    local currentXP = 0
    
    while level < Config.XPSystem.maxLevel do
        local nextLevelXP = CalculateLevelXP(level + 1)
        if xp >= nextLevelXP then
            level = level + 1
            currentXP = xp
        else
            break
        end
    end
    
    return level, currentXP
end

local function GetXPForNextLevel(currentLevel)
    if currentLevel >= Config.XPSystem.maxLevel then return 0 end
    return CalculateLevelXP(currentLevel + 1)
end

local function GetXPProgress(currentLevel, currentXP)
    local levelStartXP = CalculateLevelXP(currentLevel)
    local levelEndXP = CalculateLevelXP(currentLevel + 1)
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
    
    local skillLevel = exports['17th-skills']:getSkill(tostring(src), 'resource_gathering').level or 0
    local tier = GetSkillTier(skillLevel)
    local item = GetRandomItem(skillLevel, zone.items)
    if not item then return end
    
    -- Apply skill-based amount multiplier
    local baseAmount = math.random(item.amount.min, item.amount.max)
    local amount = math.floor(baseAmount * tier.amount_multiplier)
    if amount < 1 then amount = 1 end -- Ensure at least 1 item
    
    local success = exports['17th-inventory']:AddItem(src, item.name, amount, nil)
    
    if success then
        local itemData = inventory:Items(item.name)
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'You found ' .. amount .. 'x ' .. itemData?.label or item.name, 'success')
        -- Award skill XP
        local xp = Config.SkillSettings.xp_rewards[activity] or 10
        exports['17th-skills']:addSkill(tostring(src), 'resource_gathering', xp)
    else
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Your inventory is full!', 'error')
    end
end)

RegisterNetEvent('resource:recycle', function(itemName, amount, risky)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not Config.RecyclingCenter.inputs[itemName] then
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Invalid item for recycling!', 'error')
        return
    end
    
    local itemCount = exports['17th-inventory']:GetItemCount(src, itemName)
    if not itemCount or itemCount < amount then
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'You don\'t have enough items!', 'error')
        return
    end
    
    local success = exports['17th-inventory']:RemoveItem(src, itemName, amount)
    if not success then
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Failed to remove items!', 'error')
        return
    end
    
    local output = Config.RecyclingCenter.outputs[itemName]
    if not output then
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'No output defined for this item!', 'error')
        return
    end
    
    local skillLevel = exports['17th-skills']:getSkill(tostring(src)).level or 0
    local tier = GetSkillTier(skillLevel)
    
    -- Calculate base output amount
    local outputAmount = math.floor(amount * output.ratio)
    if outputAmount < 1 then outputAmount = 1 end
    
    -- Apply skill-based output multiplier
    outputAmount = math.floor(outputAmount * tier.amount_multiplier)
    if outputAmount < 1 then outputAmount = 1 end
    
    -- Handle risky recycling with skill-based risk reduction
    if risky and amount >= 5 then
        local baseFailureChance = 0.5
        local riskReduction = Config.SkillSettings.recycling_risk_reduction[tier.name] or 0.0
        local failureChance = baseFailureChance * (1.0 - riskReduction)
        
        if math.random() < failureChance then
            TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Batch processing failed! You lost all items.', 'error')
            return
        else
            outputAmount = outputAmount * 2
            TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Batch processing success! You received double output.', 'success')
        end
    end
    
    local addSuccess = exports['17th-inventory']:AddItem(src, output.item, outputAmount)
    if addSuccess then
        local itemData = inventory:Items(output.item)
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'You received ' .. outputAmount .. 'x ' .. itemData?.label or output.item, 'success')
        TriggerClientEvent('resource:recycleEffect', src)
        -- Award skill XP
        local xp = Config.SkillSettings.xp_rewards.recycling or 25
        exports['17th-skills']:addSkill(tostring(src), xp)
    else
        -- Refund input items if inventory is full
        exports['17th-inventory']:AddItem(src, itemName, amount)
        TriggerClientEvent('Base17th:Notify', src, 'Materials', 'Your inventory is full! Items refunded.', 'error')
    end
end)

-- Mining XP Event
RegisterNetEvent('mining:addXP', function(amount, toolType, itemsFound)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not Config.XPSystem.enabled then return end
    
    local citizenId = Player.PlayerData.citizenid
    
    -- Get or create mining player data from database
    local miningData = GetMiningPlayerData(citizenId)
    if not miningData then
        miningData = CreateMiningPlayer(citizenId)
        if not miningData then
            print('Failed to create mining player data for: ' .. citizenId)
            return
        end
    end
    
    local currentMiningXP = miningData.mining_xp
    local currentMiningLevel = miningData.mining_level
    local totalMined = miningData.total_mined
    
    -- Calculate base XP
    local baseXP = Config.XPSystem.rewards.mining or 20
    
    -- Add tool bonus XP
    if toolType then
        baseXP = baseXP + Config.XPSystem.rewards.mining_bonus
    end
    
    -- Add amount bonus
    local finalXP = baseXP + (amount or 0)
    
    -- Update XP and level
    local newXP = currentMiningXP + finalXP
    local newLevel, actualXP = GetLevelFromXP(newXP)
    local newTotalMined = totalMined + 1
    
    -- Update database
    local updateSuccess = UpdateMiningPlayerData(citizenId, actualXP, newLevel, newTotalMined)
    if not updateSuccess then
        print('Failed to update mining data for: ' .. citizenId)
        return
    end
    
    -- Add mining history
    AddMiningHistory(citizenId, toolType, finalXP, itemsFound)
    
    -- Notify player of XP gain
    if newLevel > currentMiningLevel then
        TriggerClientEvent('Base17th:Notify', src, 'Mining', 'Level Up! You are now level ' .. newLevel .. '!', 'success')
    else
        TriggerClientEvent('Base17th:Notify', src, 'Mining', 'You gained ' .. finalXP .. ' mining XP!', 'success')
    end
    
    -- Send updated data to client
    local playerData = {
        level = newLevel,
        xp = actualXP,
        totalMined = newTotalMined,
        xpForNextLevel = GetXPForNextLevel(newLevel),
        xpProgress = GetXPProgress(newLevel, actualXP)
    }
    
    TriggerClientEvent('mining:updatePlayerData', src, playerData)
end)

-- Get Player Data Event
RegisterNetEvent('mining:getPlayerData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenId = Player.PlayerData.citizenid
    
    -- Get mining player data from database
    local miningData = GetMiningPlayerData(citizenId)
    if not miningData then
        -- Create new mining player if they don't exist
        miningData = CreateMiningPlayer(citizenId)
        if not miningData then
            print('Failed to create mining player data for: ' .. citizenId)
            return
        end
    end
    
    local playerData = {
        level = miningData.mining_level,
        xp = miningData.mining_xp,
        totalMined = miningData.total_mined,
        xpForNextLevel = GetXPForNextLevel(miningData.mining_level),
        xpProgress = GetXPProgress(miningData.mining_level, miningData.mining_xp)
    }
    
    TriggerClientEvent('mining:updatePlayerData', src, playerData)
end)

-- Get Mining Leaderboard Event
RegisterNetEvent('mining:getLeaderboard', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Get top 10 miners from database
    local leaderboardData = GetMiningLeaderboard(10)
    
    -- Format leaderboard data for client
    local formattedLeaderboard = {}
    for i, player in ipairs(leaderboardData) do
        -- Get player name from QBCore if available
        local playerName = "Unknown Player"
        local qbPlayer = QBCore.Functions.GetPlayerByCitizenId(player.citizen_id)
        if qbPlayer then
            playerName = qbPlayer.PlayerData.charinfo.firstname .. " " .. qbPlayer.PlayerData.charinfo.lastname
        end
        
        table.insert(formattedLeaderboard, {
            rank = i,
            name = playerName,
            level = player.mining_level,
            totalMined = player.total_mined,
            xp = player.mining_xp
        })
    end
    
    TriggerClientEvent('mining:updateLeaderboard', src, formattedLeaderboard)
end)