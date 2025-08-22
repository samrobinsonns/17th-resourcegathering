Config = {}

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
        mining = 20,
        scavenging = 15,
        recycling = 25,
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
    recycling = 5,
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
    coords = vector3(720.73, 1291.61, 360.3),
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
    mining = {
        dict = "melee@large_wpn@streamed_core",
        anim = "ground_attack_on_spot",
        duration = 5000,
        prop = "prop_tool_pickaxe",
        particle = { asset = 'core', name = 'ent_anim_mine_dust' }
    },
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
    },
    cement = {
        label = "Grabbing Cement...",
        duration = 5000
    },
    logging = {
        label = "Chopping wood...",
        duration = 8000
    },
    mining = {
        label = "Mining...",
        duration = 10000
    },
    scavenging = {
        label = "Searching for scrap...",
        duration = 6000
    },
    recycling = {
        label = "Recycling materials...",
        duration = 7000
    },
    advanced_scavenging = {
        label = "Searching for advanced components...",
        duration = 6000
    }
}

Config.Blips = {
    enabled = false,
    foraging = {
        enabled = true,
        sprite = 496,
        color = 2,
        scale = 0.8,
        label = 'Foraging Zone'
    },
    logging = {
        enabled = true,
        sprite = 285,
        color = 25,
        scale = 0.8,
        label = 'Logging Zone'
    },
    cement = {
        enabled = false,
        sprite = 285,
        color = 25,
        scale = 0.8,
        label = 'Cement Zone'
    },
    mining = {
        enabled = true,
        sprite = 618,
        color = 28,
        scale = 0.8,
        label = 'Mining Zone'
    },
    scavenging = {
        enabled = true,
        sprite = 365,
        color = 46,
        scale = 0.8,
        label = 'Scavenging Zone'
    },
    recycling = {
        enabled = true,
        sprite = 467,
        color = 43,
        scale = 0.8,
        label = 'Recycling Center'
    },
    advanced_scavenging = {
        enabled = true,
        sprite = 365,
        color = 46,
        scale = 0.8,
        label = 'Advanced Scavenging Zone'
    }
}