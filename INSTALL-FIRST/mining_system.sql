-- Mining System Database Schema
-- This file contains the SQL structure for the mining XP and statistics system

-- Create mining_players table to store player mining data
CREATE TABLE IF NOT EXISTS `mining_players` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizen_id` varchar(50) NOT NULL,
    `mining_xp` int(11) NOT NULL DEFAULT 0,
    `mining_level` int(11) NOT NULL DEFAULT 1,
    `total_mined` int(11) NOT NULL DEFAULT 0,
    `total_smelted` int(11) NOT NULL DEFAULT 0,
    `last_mined` timestamp NULL DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizen_id` (`citizen_id`),
    KEY `mining_level` (`mining_level`),
    KEY `mining_xp` (`mining_xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create mining_history table to track individual mining sessions
CREATE TABLE IF NOT EXISTS `mining_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizen_id` varchar(50) NOT NULL,
    `tool_used` varchar(50) DEFAULT NULL,
    `xp_gained` int(11) NOT NULL DEFAULT 0,
    `items_found` text DEFAULT NULL,
    `mined_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizen_id` (`citizen_id`),
    KEY `mined_at` (`mined_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create mining_leaderboard view for easy querying
CREATE OR REPLACE VIEW `mining_leaderboard` AS
SELECT 
    mp.citizen_id,
    mp.mining_level,
    mp.mining_xp,
    mp.total_mined,
    mp.last_mined
FROM mining_players mp
ORDER BY mp.mining_level DESC, mp.mining_xp DESC, mp.total_mined DESC;


