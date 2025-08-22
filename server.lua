local QBCore = exports['17th-base']:GetCoreObject()
local inventory = exports['17th-inventory']

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
RegisterNetEvent('mining:addXP', function(amount, toolType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not Config.XPSystem.enabled then return end
    
    -- Get current mining XP from player metadata
    local currentMiningXP = Player.PlayerData.metadata.mining_xp or 0
    local currentMiningLevel = Player.PlayerData.metadata.mining_level or 1
    local totalMined = Player.PlayerData.metadata.total_mined or 0
    
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
    
    -- Update player metadata
    Player.Functions.SetMetaData('mining_xp', actualXP)
    Player.Functions.SetMetaData('mining_level', newLevel)
    Player.Functions.SetMetaData('total_mined', totalMined + 1)
    
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
        totalMined = totalMined + 1,
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
    
    local currentMiningXP = Player.PlayerData.metadata.mining_xp or 0
    local currentMiningLevel = Player.PlayerData.metadata.mining_level or 1
    local totalMined = Player.PlayerData.metadata.total_mined or 0
    
    local playerData = {
        level = currentMiningLevel,
        xp = currentMiningXP,
        totalMined = totalMined,
        xpForNextLevel = GetXPForNextLevel(currentMiningLevel),
        xpProgress = GetXPProgress(currentMiningLevel, currentMiningXP)
    }
    
    TriggerClientEvent('mining:updatePlayerData', src, playerData)
end)