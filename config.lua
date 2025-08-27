Config = {}

-- Log Buyer Configuration
Config.LogBuyer = {
    enabled = true,
    ped = {
        model = 's_m_m_trucker_01', -- Log buyer ped
        coords = vector4(-568.6981, 5272.9673, 70.2486, 130.7221), -- Location with heading
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- Makes ped look like they're working
        blip = {
            enabled = true,
            sprite = 569, -- Tree icon
            color = 25, -- Brown
            scale = 0.8,
            label = 'Log Buyer'
        }
    },
    distance = 3.0, -- Distance player needs to be to interact
    items = {
        wood_log = {
            price = 150, -- Price per log
            label = 'Wood Log'
        }
    },
    payment = {
        method = 'both', -- Options: 'cash', 'bank', 'both'
        default = 'cash' -- Default payment method when 'both' is selected
    }
}

-- UI Target Configuration
Config.UITarget = {
    enabled = true,
    targetSystem = 'ox_target', -- Options: 'ox_target' or 'qb-target'
    ped = {
        model = 's_m_m_trucker_01', -- Mining foreman ped
        coords = vector4(2944.2012, 2746.4907, 43.3682, 281.6006), -- New location with heading
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- Makes ped look like they're working
        blip = {
            enabled = true,
            sprite = 618, -- Mining icon
            color = 5, -- Yellow
            scale = 0.8,
            label = 'Mining Operations'
        }
    },
    distance = 3.0, -- Distance player needs to be to interact
    key = 'E' -- Key to open UI
}

-- Inventory System Configuration
Config.Inventory = {
    system = 'ox_inventory', -- Options: 'ox_inventory' or 'qb-inventory'
    items = {
        pickaxe = {
            name = 'pickaxe',
            label = 'Mining Pickaxe',
            weight = 1000,
            description = 'A sturdy pickaxe for mining operations'
        },
        mining_drill = {
            name = 'mining_drill',
            label = 'Mining Drill',
            weight = 2000,
            description = 'An advanced drilling tool for mining'
        },
        mining_laser = {
            name = 'mining_laser',
            label = 'Mining Laser',
            weight = 1500,
            description = 'A precision laser tool for mining'
        },
        hatchet = {
            name = 'hatchet',
            label = 'Hatchet',
            weight = 800,
            description = 'A sharp hatchet for chopping wood'
        },
        weapon_hatchet = {
            name = 'weapon_hatchet',
            label = 'Hatchet Weapon',
            weight = 800,
            description = 'A weaponized hatchet for chopping wood'
        }
    }
}

-- XP System Configuration
-- This section controls all XP-related settings for mining and smelting
-- To change XP rewards, modify the values below:
--   - mining: XP gained per mining operation
--   - smelting: XP gained per smelting operation
--   - mining_bonus: Additional XP for using better tools
Config.XPSystem = {
    enabled = true,
    -- Individual XP requirements for each level (level 1 = 0 XP, level 2 = 100 XP, etc.)
    -- You can customize each level's difficulty individually
    levelRequirements = {
        -- Level 1-10: Easy progression for beginners
        [1] = 0,      -- Level 1 starts at 0 XP
        [2] = 100,    -- Level 2 requires 100 XP
        [3] = 250,    -- Level 3 requires 250 XP
        [4] = 450,    -- Level 4 requires 450 XP
        [5] = 700,    -- Level 5 requires 700 XP
        [6] = 1000,   -- Level 6 requires 1000 XP
        [7] = 1350,   -- Level 7 requires 1350 XP
        [8] = 1750,   -- Level 8 requires 1750 XP
        [9] = 2200,   -- Level 9 requires 2200 XP
        [10] = 2700,  -- Level 10 requires 2700 XP
        
        -- Level 11-20: Moderate progression
        [11] = 3250,  -- Level 11 requires 3250 XP
        [12] = 3850,  -- Level 12 requires 3850 XP
        [13] = 4500,  -- Level 13 requires 4500 XP
        [14] = 5200,  -- Level 14 requires 5200 XP
        [15] = 5950,  -- Level 15 requires 5950 XP
        [16] = 6750,  -- Level 16 requires 6750 XP
        [17] = 7600,  -- Level 17 requires 7600 XP
        [18] = 8500,  -- Level 18 requires 8500 XP
        [19] = 9450,  -- Level 19 requires 9450 XP
        [20] = 10450, -- Level 20 requires 10450 XP
        
        -- Level 21-30: Challenging progression
        [21] = 11500, -- Level 21 requires 11500 XP
        [22] = 12600, -- Level 22 requires 12600 XP
        [23] = 13750, -- Level 23 requires 13750 XP
        [24] = 14950, -- Level 24 requires 14950 XP
        [25] = 16200, -- Level 25 requires 16200 XP
        [26] = 17500, -- Level 26 requires 17500 XP
        [27] = 18850, -- Level 27 requires 18850 XP
        [28] = 20250, -- Level 28 requires 20250 XP
        [29] = 21700, -- Level 29 requires 21700 XP
        [30] = 23200, -- Level 30 requires 23200 XP
        
        -- Level 31-40: Expert progression
        [31] = 24750, -- Level 31 requires 24750 XP
        [32] = 26350, -- Level 32 requires 26350 XP
        [33] = 28000, -- Level 33 requires 28000 XP
        [34] = 29700, -- Level 34 requires 29700 XP
        [35] = 31450, -- Level 35 requires 31450 XP
        [36] = 33250, -- Level 36 requires 33250 XP
        [37] = 35100, -- Level 37 requires 35100 XP
        [38] = 37000, -- Level 38 requires 37000 XP
        [39] = 38950, -- Level 39 requires 38950 XP
        [40] = 40950, -- Level 40 requires 40950 XP
        
        -- Level 41-51: Master progression
        [41] = 43000, -- Level 41 requires 43000 XP
        [42] = 45100, -- Level 42 requires 45100 XP
        [43] = 47250, -- Level 43 requires 47250 XP
        [44] = 49450, -- Level 44 requires 49450 XP
        [45] = 51700, -- Level 45 requires 51700 XP
        [46] = 54000, -- Level 46 requires 54000 XP
        [47] = 56350, -- Level 47 requires 56350 XP
        [48] = 58750, -- Level 48 requires 58750 XP
        [49] = 61200, -- Level 49 requires 61200 XP
        [50] = 63700, -- Level 50 requires 63700 XP
        [51] = 66250, -- Level 51 requires 66250 XP
    },
    maxLevel = 51, -- Maximum level cap (matches the array)
    
    -- XP rewards for different activities
    rewards = {
        mining = 20, -- Base XP for mining
        mining_bonus = 5, -- Bonus XP for using better tools
        smelting = 10, -- XP for smelting materials
        -- Note: These are now the primary XP values used by the system
    },
    
    -- Level-based bonuses
    levelBonuses = {
        -- Mining efficiency increases with level
        mining_efficiency = 0.02, -- 2% increase per level
        -- Better tool unlock levels
        tool_unlocks = {
            pickaxe = 0,
            drill = 20,
            laser = 40
        }
    }
}

Config.SkillSettings = {
    tiers = {
        { level = 0, name = "Beginner", chance_boost = 1.0, amount_multiplier = 1.0 },
        { level = 21, name = "Intermediate", chance_boost = 1.2, amount_multiplier = 1.5 },
        { level = 51, name = "Expert", chance_boost = 1.5, amount_multiplier = 2.0 }
    },
    xp_rewards = {
        foraging = 10,
        cement = 10,
        logging = 15,
        mining = 20, -- This should match Config.XPSystem.rewards.mining
        scavenging = 15,
        smelting = 30, -- This should match Config.XPSystem.rewards.smelting
        advanced_scavenging = 20
    },
    recycling_risk_reduction = {
        Beginner = 0.0,
        Intermediate = 0.2,
        Expert = 0.4
    }
}

Config.Cooldowns = {
    foraging = 1,
    cement = 1,
    logging = 1,
    mining = 1,
    scavenging = 1,
    smelting = 5,
    advanced_scavenging = 3
}

Config.PropSettings = {
    foraging = {
        model = 'prop_stoneshroom1',
        count = 8,
        radius = 25.0,
        zFallback = 3.0,
    },
    cement = {
        model = 'prop_cementbags01',
        count = 8,
        radius = 25.0,
        zFallback = 3.0,
    },
    logging = {
        model = 'prop_log_01',
        count = 6,
        radius = 30.0
    },
    mining = {
        model = 'prop_rock_3_c',
        count = 6,
        radius = 28.0
    },
    scavenging = {
        model = 'prop_bin_05a',
        count = 5,
        radius = 20.0
    },
    advanced_scavenging = {
        model = 'prop_bin_05a',
        count = 5,
        radius = 20.0
    }
}

Config.Zones = {
    foraging = {
        {
            coords = vector3(-229.7190, 4484.6187, 52.4840),
            spawn_coords = {
                vector3(-229.7190, 4484.6187, 52.4840),
                vector3(-232.2374, 4482.4644, 52.8865),
                vector3(-236.2730, 4481.3130, 53.4322),
                vector3(-235.7493, 4478.1118, 53.2252),
                vector3(-224.9789, 4497.5620, 53.6765),
                vector3(-222.2147, 4468.8652, 54.0710),
                vector3(-216.7725, 4468.3159, 53.6581),
                vector3(-216.7721, 4463.1416, 53.5277)
            },
            items = {
                {name = 'red_mushroom', chance = 30, amount = {min = 1, max = 4}} -- 1,1 → 2,2
            },
            blip = {
                enabled = true,
                sprite = 496, -- Plant icon
                color = 2, -- Green
                scale = 0.7,
                label = 'Foraging Area'
            }
        },
    },
    cement = {
        {
            coords = vector3(308.5701, 2878.0188, 43.5068),
            spawn_coords = {
                vector3(299.7848, 2880.3477, 43.5344),
                vector3(303.5524, 2874.0498, 43.5343),
                vector3(306.6356, 2868.7727, 43.5357),
                vector3(312.5717, 2866.1851, 43.5065),
                vector3(316.9382, 2863.8445, 43.5219),
                vector3(325.0663, 2864.7451, 43.4413)
            },
            items = {
                {name = 'cement', chance = 100, amount = {min = 1, max = 2}} -- 1,1 → 2,2
            }
        },
    },
    logging = {
        {
            coords = vector3(1631.45, 1769.32, 106.37),
            spawn_coords = {
                vector3(1628.34, 1772.18, 106.37),
                vector3(1635.67, 1766.89, 106.37),
                vector3(1620.2958, 1758.1666, 106.7854),
                vector3(1638.91, 1762.73, 106.37),
                vector3(1633.78, 1778.56, 105.37),
                vector3(1640.23, 1768.12, 105.37)
            },
            items = {
                {name = 'wood_log', chance = 100, amount = {min = 2, max = 4}} -- 1,2 → 2,4
            },
            blip = {
                enabled = true,
                sprite = 569, -- Tree icon
                color = 25, -- Brown
                scale = 0.7,
                label = 'Logging Area'
            }
        },
    },
    mining = {
        {
            coords = vector3(2955.04, 2795.18, 40.89),
            spawn_coords = {
                vector3(2958.73, 2798.45, 40.89),
                vector3(2921.3503, 2805.0361, 42.6441),
                vector3(2927.5950, 2795.9563, 40.8503),
                vector3(2934.2217, 2788.4189, 39.8870),
                vector3(2942.3052, 2777.5298, 39.2781),
                vector3(2949.5466, 2773.1692, 39.0919),
                vector3(2951.22, 2792.67, 40.89),
                vector3(2960.11, 2790.34, 40.89),
                vector3(2948.67, 2797.89, 40.89),
                vector3(2963.45, 2793.12, 40.89),
                vector3(2952.89, 2785.78, 40.89)
            },
            items = {
                {name = 'iron_ore', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                {name = 'steel', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                {name = 'gold_ore', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                {name = 'sodium', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                -- {name = 'silver_ore', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                {name = 'copper_ore', chance = 20, amount = {min = 2, max = 2}}, -- 1,1 → 2,2
                {name = 'coal_chunk', chance = 20, amount = {min = 2, max = 2}} -- 1,1 → 2,2
            }
        },
    },
    scavenging = {
        {
            coords = vector3(2049.45, 3181.73, 45.24),
            spawn_coords = {
                vector3(2052.18, 3184.67, 45.24),
                vector3(2046.73, 3178.91, 45.24),
                vector3(2054.89, 3179.34, 45.24),
                vector3(2044.12, 3185.56, 45.24),
                vector3(2051.67, 3176.89, 45.24)
            },
            items = {
                {name = 'scrapmetal', chance = 20, amount = {min = 2, max = 6}}, -- 1,3 → 2,6
                {name = 'small_components', chance = 20, amount = {min = 2, max = 6}}, -- 1,3 → 2,6
                {name = 'glaz', chance = 20, amount = {min = 2, max = 6}}, -- 1,3 → 2,6
                {name = 'steel', chance = 20, amount = {min = 2, max = 6}}, -- 1,3 → 2,6
                {name = 'plastic_piece', chance = 20, amount = {min = 2, max = 7}}, -- 1,4 → 2,7
                {name = 'wires', chance = 20, amount = {min = 1, max = 1}} -- 1,2 → 2,4
            }
        },
    },
    advanced_scavenging = {
        {
            coords = vector3(2100.00, 3200.00, 45.50),
            spawn_coords = {
                vector3(2102.50, 3202.75, 45.50),
                vector3(2097.25, 3198.50, 45.50),
                vector3(2104.00, 3199.00, 45.50),
                vector3(2095.50, 3203.25, 45.50),
                vector3(2101.75, 3196.75, 45.50)
            },
            items = {
                {name = 'aluminum', chance = 25, amount = {min = 2, max = 4}},
                {name = 'chip', chance = 20, amount = {min = 2, max = 2}},
                {name = 'board', chance = 20, amount = {min = 2, max = 2}},
                {name = 'rubber', chance = 25, amount = {min = 3, max = 7}},
                {name = 'electronic_parts', chance = 10, amount = {min = 2, max = 4}}
            }
        },
    }
}

Config.RecyclingCenter = {
    coords = vector3(1110.6523, -2008.3479, 31.8346),
    inputs = {
        copper_ore = true,
        iron_ore = true,
        gold_ore = true,
    },
    outputs = {
        copper_ore = {
            item = 'copper',
            label = 'Copper',
            ratio = 0.5
        },
        iron_ore = {
            item = 'iron',
            label = 'Iron',
            ratio = 0.5
        },
        gold_ore = {
            item = 'gold',
            label = 'Gold',
            ratio = 0.33
        },
    },
    blip = {
        enabled = true,
        sprite = 436, -- Furnace icon
        color = 1, -- Red
        scale = 0.8,
        label = 'Smelting Center'
    },
    -- New simplified smelting system
    smelting = {
        enabled = true,
        baseDuration = 10000, -- Base duration in milliseconds (10 seconds)
        levelSpeedBonus = 0.02, -- 2% faster per level (more gradual progression)
        maxSpeedBonus = 0.92, -- Maximum 92% speed bonus (at level 46)
        minDuration = 800, -- Minimum duration (0.8 seconds)
        maxDuration = 15000, -- Maximum duration (15 seconds)
        -- Level-based duration multipliers for 50 levels
        levelMultipliers = {
            -- Early levels (1-10): Slow progression, harder to advance
            [1] = 1.0,   -- Level 1: 100% (10.0 seconds)
            [2] = 0.98,  -- Level 2: 98% (9.8 seconds)
            [3] = 0.96,  -- Level 3: 96% (9.6 seconds)
            [4] = 0.94,  -- Level 4: 94% (9.4 seconds)
            [5] = 0.92,  -- Level 5: 92% (9.2 seconds)
            [6] = 0.90,  -- Level 6: 90% (9.0 seconds)
            [7] = 0.88,  -- Level 7: 88% (8.8 seconds)
            [8] = 0.86,  -- Level 8: 86% (8.6 seconds)
            [9] = 0.84,  -- Level 9: 84% (8.4 seconds)
            [10] = 0.82, -- Level 10: 82% (8.2 seconds)
            
            -- Mid levels (11-25): Steady progression
            [15] = 0.75, -- Level 15: 75% (7.5 seconds)
            [20] = 0.65, -- Level 20: 65% (6.5 seconds)
            [25] = 0.55, -- Level 25: 55% (5.5 seconds)
            
            -- High levels (26-40): Faster progression
            [30] = 0.40, -- Level 30: 40% (4.0 seconds)
            [35] = 0.25, -- Level 35: 25% (2.5 seconds)
            [40] = 0.15, -- Level 40: 15% (1.5 seconds)
            
            -- Elite levels (41-50): Maximum speed
            [45] = 0.10, -- Level 45: 10% (1.0 seconds)
            [50] = 0.08, -- Level 50: 8% (0.8 seconds)
        }
    }
}

-- Additional smelting center location (no blip)
Config.SmeltingCenter2 = {
    coords = vector3(1103.5281, -2013.7279, 30.8835),
    heading = 344.1929,
    inputs = {
        copper_ore = true,
        iron_ore = true,
        gold_ore = true,
    },
    outputs = {
        copper_ore = {
            item = 'copper',
            label = 'Copper',
            ratio = 0.5
        },
        iron_ore = {
            item = 'iron',
            label = 'Iron',
            ratio = 0.5
        },
        gold_ore = {
            item = 'gold',
            label = 'Gold',
            ratio = 0.33
        },
    }
}

Config.Items = {
    metal_parts = {
        label = 'Metal Parts',
        weight = 100,
        stack = true,
        close = true,
        description = 'Refined metal parts'
    },
    rubber_bits = {
        label = 'Rubber Bits',
        weight = 50,
        stack = true,
        close = true,
        description = 'Small rubber pieces'
    },
    electronic_parts = {
        label = 'Electronic Parts',
        weight = 75,
        stack = true,
        close = true,
        description = 'Small electronic components'
    },
    aluminum = {
        label = 'Aluminum',
        weight = 80,
        stack = true,
        close = true,
        description = 'Lightweight metal'
    },
    chip = {
        label = 'Microchip',
        weight = 20,
        stack = true,
        close = true,
        description = 'Electronic microchip'
    },
    board = {
        label = 'Circuit Board',
        weight = 50,
        stack = true,
        close = true,
        description = 'Electronic circuit board'
    },
    rubber = {
        label = 'Rubber',
        weight = 60,
        stack = true,
        close = true,
        description = 'Flexible rubber material'
    },
    red_mushroom = {
        label = 'Red Mushroom',
        weight = 30,
        stack = true,
        close = true,
        description = 'A red mushroom'
    },
    cement = {
        label = 'Cement',
        weight = 100,
        stack = true,
        close = true,
        description = 'Construction cement'
    },
    wood_log = {
        label = 'Wood Log',
        weight = 150,
        stack = true,
        close = true,
        description = 'A log of wood'
    },
    iron_ore = {
        label = 'Iron Ore',
        weight = 120,
        stack = true,
        close = true,
        description = 'Raw iron ore'
    },
    steel = {
        label = 'Steel',
        weight = 100,
        stack = true,
        close = true,
        description = 'Refined steel'
    },
    gold_ore = {
        label = 'Gold Ore',
        weight = 130,
        stack = true,
        close = true,
        description = 'Raw gold ore'
    },
    sodium = {
        label = 'Sodium',
        weight = 50,
        stack = true,
        close = true,
        description = 'Sodium material'
    },
    -- silver_ore = {
    --     label = 'Silver Ore',
    --     weight = 110,
    --     stack = true,
    --     close = true,
    --     description = 'Raw silver ore'
    -- },
    copper_ore = {
        label = 'Copper Ore',
        weight = 110,
        stack = true,
        close = true,
        description = 'Raw copper ore'
    },
    coal_chunk = {
        label = 'Coal Chunk',
        weight = 90,
        stack = true,
        close = true,
        description = 'A chunk of coal'
    },
    scrapmetal = {
        label = 'Scrap Metal',
        weight = 80,
        stack = true,
        close = true,
        description = 'Pieces of scrap metal'
    },
    small_components = {
        label = 'Small Components',
        weight = 40,
        stack = true,
        close = true,
        description = 'Small mechanical parts'
    },
    glaz = {
        label = 'Glass',
        weight = 70,
        stack = true,
        close = true,
        description = 'Glass pieces'
    },
    plastic_piece = {
        label = 'Plastic Piece',
        weight = 30,
        stack = true,
        close = true,
        description = 'Small plastic pieces'
    },
    wires = {
        label = 'Wires',
        weight = 50,
        stack = true,
        close = true,
        description = 'Electrical wires'
    },
    copper = {
        label = 'Copper',
        weight = 90,
        stack = true,
        close = true,
        description = 'Refined copper'
    },
    iron = {
        label = 'Iron',
        weight = 100,
        stack = true,
        close = true,
        description = 'Refined iron'
    },
    gold = {
        label = 'Gold',
        weight = 120,
        stack = true,
        close = true,
        description = 'Refined gold'
    },
    -- Mining Equipment Items
    mining_pickaxe = {
        label = 'Mining Pickaxe',
        weight = 1000,
        stack = false,
        close = true,
        description = 'A sturdy pickaxe for mining operations'
    },
    mining_drill = {
        label = 'Mining Drill',
        weight = 2000,
        stack = false,
        close = true,
        description = 'An advanced drilling tool for mining'
    },
    mining_laser = {
        label = 'Mining Laser',
        weight = 1500,
        stack = false,
        close = true,
        description = 'A precision laser tool for mining'
    }
}

-- Equipment Shop Configuration
Config.EquipmentShop = {
    enabled = true,
    payment = {
        method = 'both', -- Options: 'cash', 'bank', 'both'
        default = 'bank' -- Default payment method when 'both' is selected
    },
    items = {
        pickaxe = {
            price = 500,
            label = 'Mining Pickaxe'
        },
        mining_drill = {
            price = 1500,
            label = 'Mining Drill'
        },
        mining_laser = {
            price = 2500,
            label = 'Mining Laser'
        }
    }
}

Config.Animations = {
    foraging = {
        dict = "amb@world_human_gardener_plant@male@base",
        anim = "base",
        duration = 5000,
        prop = nil,
        particle = { asset = 'core', name = 'ent_sht_plant' }
    },
    logging = {
        dict = "melee@large_wpn@streamed_core",
        anim = "ground_attack_on_spot",
        duration = 5000,
        prop = "prop_w_me_hatchet",
        particle = { asset = 'core', name = 'ent_anim_tree_fall_dust' }
    },
    -- Mining animations are now handled by the new tool system in client.lua
    -- This provides better reliability with GTA V scenarios and built-in animations
    scavenging = {
        dict = "amb@prop_human_bum_bin@base",
        anim = "base",
        duration = 5000,
        prop = nil,
        particle = { asset = 'core', name = 'ent_anim_paper' }
    },
    cement = {
        dict = "amb@prop_human_bum_bin@base",
        anim = "base",
        duration = 10000,
        prop = nil,
        particle = { asset = 'core', name = 'ent_anim_paper' }
    },
    recycling = {
        dict = "mp_common",
        anim = "givetake1_a",
        duration = 2000,
        prop = nil
    },
    advanced_scavenging = {
        dict = "amb@prop_human_bum_bin@base",
        anim = "base",
        duration = 6000,
        prop = nil,
        particle = { asset = 'core', name = 'ent_anim_elec' }
    }
}

Config.ProgressBar = {
    foraging = {
        label = "Foraging...",
        duration = 5000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    },
    cement = {
        label = "Grabbing Cement...",
        duration = 5000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    },
    logging = {
        label = "Chopping wood...",
        duration = 8000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    },
    mining = {
        label = "Mining...",
        duration = 10000,  -- Default fallback duration (10 seconds)
        -- Tool-specific durations for mining activities (in milliseconds)
        -- Modify these values to change mining speed for each tool
        toolDurations = {
            pickaxe = 9000,      -- 9 seconds (slowest)
            mining_drill = 6500,  -- 6.5 seconds (medium)
            mining_laser = 3000   -- 3 seconds (fastest)
        }
    },
    scavenging = {
        label = "Searching for scrap...",
        duration = 6000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    },
    smelting = {
        label = "Smelting materials...",
        duration = 7000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    },
    advanced_scavenging = {
        label = "Searching for advanced components...",
        duration = 6000
        -- Tool-specific durations are now handled by the new tool system in client.lua
    }
}

