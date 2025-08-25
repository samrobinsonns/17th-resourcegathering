# Mining System SQL Implementation

This document describes the SQL database structure and implementation for the mining XP and statistics system.

## Database Schema

### Tables

#### `mining_players`
Stores the main mining data for each player.

| Column | Type | Description |
|--------|------|-------------|
| `id` | int(11) | Auto-increment primary key |
| `citizen_id` | varchar(50) | Unique player identifier |
| `mining_xp` | int(11) | Current mining experience points |
| `mining_level` | int(11) | Current mining level |
| `total_mined` | int(11) | Total number of mining operations |
| `total_smelted` | int(11) | Total number of items smelted |
| `last_mined` | timestamp | Last time player mined |
| `created_at` | timestamp | When record was created |
| `updated_at` | timestamp | When record was last updated |

#### `mining_history`
Tracks individual mining sessions for analytics.

| Column | Type | Description |
|--------|------|-------------|
| `id` | int(11) | Auto-increment primary key |
| `citizen_id` | varchar(50) | Player identifier |
| `tool_used` | varchar(50) | Tool used for mining |
| `xp_gained` | int(11) | XP gained from this session |
| `items_found` | text | JSON array of items found |
| `mined_at` | timestamp | When mining occurred |

### Views

#### `mining_leaderboard`
Provides a sorted view of top miners for easy querying.

## Installation

1. **Run the SQL script:**
   ```sql
   source mining_system.sql;
   ```

2. **Verify tables were created:**
   ```sql
   SHOW TABLES LIKE 'mining_%';
   ```

3. **Check table structure:**
   ```sql
   DESCRIBE mining_players;
   DESCRIBE mining_history;
   ```

## Usage Examples

### Get Player Mining Data
```sql
SELECT * FROM mining_players WHERE citizen_id = 'ABC123';
```

### Get Top 10 Miners
```sql
SELECT * FROM mining_leaderboard LIMIT 10;
```

### Get Player Mining History
```sql
SELECT * FROM mining_history 
WHERE citizen_id = 'ABC123' 
ORDER BY mined_at DESC 
LIMIT 20;
```

### Get Mining Statistics
```sql
SELECT 
    COUNT(*) as total_players,
    AVG(mining_level) as avg_level,
    SUM(total_mined) as total_operations,
    SUM(total_smelted) as total_items_smelted,
    MAX(mining_level) as highest_level
FROM mining_players;
```

## Server Integration

The server automatically:
- Creates new mining player records when needed
- Updates XP and level data after mining operations
- Logs mining history for analytics
- Provides leaderboard data to the UI

## Data Persistence

- **Player Data**: Automatically created on first mining operation
- **XP Tracking**: Persistent across server restarts
- **History Logging**: All mining sessions are logged with timestamps
- **Performance**: Indexed on key columns for fast queries

## Backup Considerations

Include these tables in your regular database backups:
- `mining_players`
- `mining_history`

## Migration from Metadata

If you were previously using player metadata for mining data, you can migrate existing data:

```sql
-- Example migration (adjust based on your existing structure)
INSERT INTO mining_players (citizen_id, mining_xp, mining_level, total_mined)
SELECT 
    citizen_id,
    COALESCE(JSON_EXTRACT(metadata, '$.mining_xp'), 0) as mining_xp,
    COALESCE(JSON_EXTRACT(metadata, '$.mining_level'), 1) as mining_level,
    COALESCE(JSON_EXTRACT(metadata, '$.total_mined'), 0) as total_mined
FROM players 
WHERE JSON_EXTRACT(metadata, '$.mining_xp') IS NOT NULL;
```

## Troubleshooting

### Common Issues

1. **Table not found**: Ensure you ran the SQL script
2. **Permission denied**: Check database user permissions
3. **Connection failed**: Verify MySQL connection settings

### Debug Queries

```sql
-- Check if player exists
SELECT * FROM mining_players WHERE citizen_id = 'YOUR_CITIZEN_ID';

-- Check recent mining history
SELECT * FROM mining_history ORDER BY mined_at DESC LIMIT 5;

-- Verify leaderboard view
SELECT * FROM mining_leaderboard LIMIT 5;
```

## Performance Notes

- Tables are indexed on frequently queried columns
- Leaderboard view optimizes sorting operations
- History table can be archived/cleaned periodically if needed
- Consider adding additional indexes based on your query patterns
