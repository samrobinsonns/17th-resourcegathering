# Resource Gathering UI - Sergei's Company

A modern, iPad-style UI for the FiveM Resource Gathering Script with a comprehensive progression system.

## Features

### 🎯 **Dashboard**
- Real-time player statistics (Level, XP, Tier)
- Zone status monitoring for all gathering activities
- Recent activity timeline with filtering options
- XP progress visualization with animated progress bars

### 🛠️ **Gathering System**
- **Foraging**: Natural resource gathering (no tools required)
- **Mining**: Mineral extraction (requires pickaxe)
- **Logging**: Wood harvesting (requires hatchet)
- **Scavenging**: Urban material collection (requires crowbar)
- Zone selection with real-time availability status
- Tool requirement validation
- Cooldown management

### ♻️ **Recycling Center**
- Item recycling with risk/reward system
- Efficiency tracking
- Real-time processing status

### 📈 **Progression System**
- **3 Tiers**: Beginner (0-20), Intermediate (21-50), Expert (51+)
- Skill-based multipliers for better yields
- Risk reduction for advanced players
- Visual progression roadmap
- Classification cards with unlock requirements

### 🏆 **Leaderboard**
- Player rankings by XP and gathering count
- Time-based filtering (All Time, Weekly, Monthly)
- Achievement badges for top performers

## Installation

1. **Copy Files**: Ensure all HTML files are in the `html/` directory
2. **Update fxmanifest.lua**: The manifest has been updated to include UI files
3. **Restart Resource**: Restart the resource to load the new UI

## Usage

### Opening the UI
- **Command**: `/resourcegathering`
- **Key Binding**: `F6` (default)
- **In-Game**: Use the command or key binding

### Gathering Resources
1. Navigate to the **Gathering** tab
2. Select your desired activity (Foraging, Mining, Logging, Scavenging)
3. Choose a zone from the dropdown
4. Ensure you have the required tool
5. Click **Start [Activity]**
6. Complete the minigame/skill check
7. Collect your resources and XP

### Recycling Items
1. Go to the **Recycling** tab
2. Select an item to recycle
3. Choose amount and risk level
4. Click **Start Recycling**
5. Wait for processing to complete

### Monitoring Progress
- **Dashboard**: Overview of current status
- **Progress**: Detailed progression tracking
- **Leaderboard**: Compare with other players

## Configuration

### Skill Tiers
The progression system uses three tiers with different bonuses:

```lua
Config.SkillSettings = {
    tiers = {
        { level = 0, name = "Beginner", chance_boost = 1.0, amount_multiplier = 1.0 },
        { level = 21, name = "Intermediate", chance_boost = 1.2, amount_multiplier = 1.5 },
        { level = 51, name = "Expert", chance_boost = 1.5, amount_multiplier = 2.0 }
    }
}
```

### XP Rewards
Configure XP rewards for different activities:

```lua
xp_rewards = {
    foraging = 10,
    cement = 10,
    logging = 15,
    mining = 20,
    scavenging = 15,
    recycling = 25,
    advanced_scavenging = 20
}
```

### Cooldowns
Set cooldown times for each activity:

```lua
Config.Cooldowns = {
    foraging = 1,
    cement = 1,
    logging = 1,
    mining = 1,
    scavenging = 1,
    recycling = 5,
    advanced_scavenging = 3
}
```

## Customization

### Colors and Theme
The UI uses CSS variables for easy customization. Edit `html/style.css`:

```css
:root {
    --primary-color: #000000;
    --secondary-color: #e74c3c;      /* Main accent color */
    --accent-color: #c0392b;         /* Secondary accent */
    --success-color: #27ae60;        /* Success states */
    --warning-color: #f39c12;        /* Warning states */
    --danger-color: #e74c3c;         /* Error states */
    --border-color: #e74c3c;         /* Border color */
}
```

### Adding New Activities
1. **Config**: Add new activity to `Config.Zones`
2. **HTML**: Add new job type button in `index.html`
3. **JavaScript**: Add event handlers in `script.js`
4. **CSS**: Style new elements in `style.css`

### Modifying Progression
1. **Tier Levels**: Update level thresholds in `script.js`
2. **Multipliers**: Modify bonus calculations
3. **Requirements**: Change unlock conditions

## Technical Details

### File Structure
```
html/
├── index.html          # Main UI structure
├── style.css           # Styling and animations
└── script.js           # UI logic and interactions
```

### Key Functions
- `ResourceGatheringUI` class manages all UI functionality
- `switchTab()` handles navigation between tabs
- `startGathering()` initiates resource gathering
- `updatePlayerStats()` refreshes player information
- `showNotification()` displays user feedback

### NUI Integration
- **Client → UI**: `SendNUIMessage()` for updates
- **UI → Client**: `RegisterNUICallback()` for actions
- **Focus Management**: `SetNuiFocus()` for input handling

## Troubleshooting

### UI Not Showing
- Check if HTML files are in correct directory
- Verify fxmanifest.lua includes UI files
- Restart the resource
- Check browser console for JavaScript errors

### Gathering Not Working
- Ensure player is in valid gathering zone
- Check if required tools are in inventory
- Verify cooldown has expired
- Check server logs for errors

### Performance Issues
- Reduce update frequency in `UpdatePlayerDataInUI()`
- Optimize zone calculations
- Limit concurrent UI updates

## Dependencies

- **17th-base**: Core framework
- **ox_lib**: Utility library
- **17th-skills**: Skills system (optional)
- **17th-inventory**: Inventory management
- **17th-minigames**: Minigame system

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review server logs for errors
3. Verify all dependencies are installed
4. Test with minimal configuration

## License

This UI is part of the Resource Gathering Script by Metromods.
Modify and distribute according to your server's licensing terms.

---

**Enjoy your enhanced resource gathering experience with Sergei's Company!** 🚛⛏️🌲
