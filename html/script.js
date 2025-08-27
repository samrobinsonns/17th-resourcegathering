// Resource Gathering UI - Main JavaScript
class ResourceGatheringUI {
    constructor() {
        this.testMode = false;
        this.playerData = {
            level: 1,
            xp: 0,
            totalMined: 0,
            totalSmelted: 0
        };
        this.equipment = {};
        this.equipmentConfig = {
            pickaxe: { 
                name: 'pickaxe',
                label: 'Mining Pickaxe', 
                description: 'A sturdy pickaxe for mining operations',
                icon: 'fas fa-hammer',
                unlockLevel: 0,
                weight: 1000,
                price: 500
            },
            mining_drill: { 
                name: 'mining_drill',
                label: 'Mining Drill', 
                description: 'An advanced drilling tool for mining',
                icon: 'fas fa-drill',
                unlockLevel: 2,
                weight: 2000,
                price: 1500
            },
            mining_laser: { 
                name: 'mining_laser',
                label: 'Mining Laser', 
                description: 'A precision laser tool for mining',
                icon: 'fas fa-laser-pointer',
                unlockLevel: 2,
                weight: 1500,
                price: 2500
            }
        };
        this.leaderboardData = [];
        this.currentFilter = 'level';
        
        this.init();
    }

    init() {
        try {
            this.setupEventListeners();
            this.loadPlayerData();
            this.updateUI();
        } catch (error) {
            console.error('Error initializing mining UI:', error);
        }
    }

    setupEventListeners() {
        // Tab navigation
        const navButtons = document.querySelectorAll('.nav-item');
        navButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                this.switchTab(btn.dataset.tab);
            });
        });

        // Close button
        const closeBtn = document.getElementById('closeBtn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.closeUI();
            });
        }

        // Escape key handler
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeUI();
            }
        });

        // Equipment grid will be populated dynamically

        // Leaderboard filter selector
        const leaderboardFilter = document.getElementById('leaderboardFilter');
        if (leaderboardFilter) {
            leaderboardFilter.addEventListener('change', (e) => {
                this.currentFilter = e.target.value;
                this.updateLeaderboard();
            });
        }

        // Leaderboard refresh button
        const refreshLeaderboard = document.getElementById('refreshLeaderboard');
        if (refreshLeaderboard) {
            refreshLeaderboard.addEventListener('click', () => {
                this.updateLeaderboard();
            });
        }

        // Check if we're in browser test mode
        if (!window.invokeNative && !window.GetParentResourceName) {
            this.enableTestMode();
        }
    }

    switchTab(tabName) {
        // Hide all tab content
        const tabContents = document.querySelectorAll('.tab-pane');
        tabContents.forEach(tab => tab.classList.remove('active'));

        // Remove active class from all nav buttons
        const navButtons = document.querySelectorAll('.nav-item');
        navButtons.forEach(btn => btn.classList.remove('active'));

        // Show selected tab
        const selectedTab = document.getElementById(tabName);
        if (selectedTab) {
            selectedTab.classList.add('active');
        }

        // Add active class to clicked button
        const activeButton = document.querySelector(`[data-tab="${tabName}"]`);
        if (activeButton) {
            activeButton.classList.add('active');
        }
    }

    loadPlayerData() {
        try {
            // In test mode, use mock data
            if (this.testMode) {
                this.playerData = {
                    level: 2,
                    xp: 150,
                    totalMined: 5
                };
            }

            this.updatePlayerStats();
            this.updateEquipmentStatus(); // Make sure equipment status is updated after player data is loaded
        } catch (error) {
            console.error('Error loading player data:', error);
        }
    }

    updatePlayerStats() {
        try {
            // Update dashboard stats
            const totalMinedElement = document.getElementById('totalMined');
            if (totalMinedElement) {
                totalMinedElement.textContent = this.playerData.totalMined;
            }

            const totalMinedValueElement = document.getElementById('totalMinedValue');
            if (totalMinedValueElement) {
                totalMinedValueElement.textContent = this.playerData.totalMined;
            }

            const totalSmeltedElement = document.getElementById('totalSmelted');
            if (totalSmeltedElement) {
                totalSmeltedElement.textContent = this.playerData.totalSmelted || 0;
            }

            const totalSmeltedValueElement = document.getElementById('totalSmeltedValue');
            if (totalSmeltedValueElement) {
                totalSmeltedValueElement.textContent = this.playerData.totalSmelted || 0;
            }

            const miningLevelElement = document.getElementById('miningLevel');
            if (miningLevelElement) {
                miningLevelElement.textContent = `Level ${this.playerData.level}`;
            }

            const skillLevelElement = document.getElementById('skillLevel');
            if (skillLevelElement) {
                skillLevelElement.textContent = this.playerData.level;
            }

            const playerXPElement = document.getElementById('playerXP');
            if (playerXPElement) {
                playerXPElement.textContent = `${this.playerData.xp} XP`;
            }

            // Update leaderboard position if available
            const leaderboardPositionElement = document.getElementById('leaderboardPosition');
            if (leaderboardPositionElement) {
                const position = this.getPlayerLeaderboardPosition();

                
                if (position > 0) {
                    leaderboardPositionElement.textContent = `#${position}`;
                } else {
                    leaderboardPositionElement.textContent = '--';
                }
            }

            // Update XP progress
            this.updateXPProgress();
        } catch (error) {
            console.error('Error updating player stats:', error);
        }
    }

    updateXPProgress() {
        try {
            const currentXP = this.playerData.xp;
            const currentLevel = this.playerData.level;
            
            // Use server-calculated XP progress if available (preferred method)
            if (this.playerData.xpProgress !== undefined && this.playerData.xpForNextLevel !== undefined) {
                const progressPercentage = this.playerData.xpProgress;
                

                
                // Update XP bar
                const xpFill = document.getElementById('xpFill');
                if (xpFill) {
                    xpFill.style.width = Math.min(100, Math.max(0, progressPercentage)) + '%';
                }

                // Update XP progress bar in top bar
                const xpProgress = document.getElementById('xpProgress');
                if (xpProgress) {
                    xpProgress.style.width = Math.min(100, Math.max(0, progressPercentage)) + '%';
                }
                
                // Update XP text with server values
                const currentXPElement = document.getElementById('currentXP');
                if (currentXPElement) {
                    // Show current total XP
                    currentXPElement.textContent = currentXP;
                }
                
                const nextLevelXPElement = document.getElementById('nextLevelXP');
                if (nextLevelXPElement) {
                    nextLevelXPElement.textContent = this.playerData.xpForNextLevel;
                }
                
            } else {
                // Fallback to client-side calculation

                
                const currentLevelXP = this.getLevelXP(currentLevel);
                const nextLevelXP = this.getLevelXP(currentLevel + 1);
                
                // Calculate progress
                const xpInCurrentLevel = currentXP - currentLevelXP;
                const xpNeededForNextLevel = nextLevelXP - currentLevelXP;
                const progressPercentage = (xpInCurrentLevel / xpNeededForNextLevel) * 100;
                
                // Update XP bar
                const xpFill = document.getElementById('xpFill');
                if (xpFill) {
                    xpFill.style.width = Math.min(100, Math.max(0, progressPercentage)) + '%';
                }

                // Update XP progress bar in top bar
                const xpProgress = document.getElementById('xpProgress');
                if (xpProgress) {
                    xpProgress.style.width = Math.min(100, Math.max(0, progressPercentage)) + '%';
                }
                
                // Update XP text with fallback values
                const currentXPElement = document.getElementById('currentXP');
                if (currentXPElement) {
                    // Show current total XP
                    currentXPElement.textContent = currentXP;
                }
                
                const nextLevelXPElement = document.getElementById('nextLevelXP');
                if (nextLevelXPElement) {
                    nextLevelXPElement.textContent = xpNeededForNextLevel;
                }
            }
            

            
        } catch (error) {
            console.error('Error updating XP progress:', error);
        }
    }

    getLevelXP(level) {
        // Use server-provided XP values from config instead of hardcoded calculation
        // The server sends xpForNextLevel which contains the XP requirement for the next level
        if (this.playerData && this.playerData.xpForNextLevel !== undefined) {
            // For current level, we need to calculate backwards from next level
            if (level === this.playerData.level) {
                // Current level XP requirement
                return this.playerData.xp - (this.playerData.xpForNextLevel - this.playerData.xp);
            } else if (level === this.playerData.level + 1) {
                // Next level XP requirement
                return this.playerData.xpForNextLevel;
            }
        }
        
        // Fallback to config-based calculation if server data not available
        // This matches your config.XPSystem.levelRequirements structure
        const levelRequirements = {
            1: 0, 2: 100, 3: 250, 4: 450, 5: 700, 6: 1000, 7: 1350, 8: 1750, 9: 2200, 10: 2700,
            11: 3250, 12: 3850, 13: 4500, 14: 5200, 15: 5950, 16: 6750, 17: 7600, 18: 8500, 19: 9450, 20: 10450,
            21: 11500, 22: 12600, 23: 13750, 24: 14950, 25: 16200, 26: 17500, 27: 18850, 28: 20250, 29: 21700, 30: 23200,
            31: 24750, 32: 26350, 33: 28000, 34: 29700, 35: 31450, 36: 33250, 37: 35100, 38: 37000, 39: 38950, 40: 40950,
            41: 43000, 42: 45100, 43: 47250, 44: 49450, 45: 51700, 46: 54000, 47: 56350, 48: 58750, 49: 61200, 50: 63700, 51: 66250
        };
        
        return levelRequirements[level] || (level * 100); // Fallback to simple calculation
    }



    updateEquipmentStatus() {
        // Update all equipment status based on current player level

        
        Object.keys(this.equipmentConfig).forEach(toolKey => {
            const tool = this.equipmentConfig[toolKey];
            const statusElement = document.getElementById(`${toolKey}-status`);
            const buttonElement = document.getElementById(`${toolKey}-btn`);
            
            if (!statusElement || !buttonElement) {
    
                return;
            }
            
            const isUnlocked = this.playerData.level >= tool.unlockLevel;

            
            if (isUnlocked) {
                // Equipment is available
                statusElement.innerHTML = '<span class="status-available">Available</span>';
                buttonElement.className = 'btn btn-primary';
                buttonElement.disabled = false;
                buttonElement.textContent = `Get ${tool.label}`;

            } else {
                // Equipment is locked
                statusElement.innerHTML = '<span class="status-locked">Locked</span>';
                buttonElement.className = 'btn btn-secondary';
                buttonElement.disabled = true;
                buttonElement.textContent = `Level ${tool.unlockLevel} Required`;

            }
        });
    }

    getEquipment(equipmentType) {
        const tool = this.equipmentConfig[equipmentType];
        if (!tool) return;
        
        // Check if player has required level
        if (this.playerData.level < tool.unlockLevel) {
            this.showNotification(`You need level ${tool.unlockLevel} to get this equipment!`, 'error');
            return;
        }
        
        if (this.testMode) {
            // In test mode, just show a notification
            this.showNotification(`You got a ${tool.label}!`, 'success');
            this.equipment[equipmentType] = { unlocked: true, level: 1 };
            this.updateEquipmentStatus();
        } else {
            // In FiveM, purchase equipment through NUI callback
            fetch(`https://${GetParentResourceName()}/purchaseEquipment`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    toolType: equipmentType,
                    playerLevel: this.playerData.level
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.showNotification(data.message, 'success');
                    // Don't update equipment ownership here - wait for server confirmation
                    // The server will send a NUI message to update the UI
                } else {
                    this.showNotification(data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error purchasing equipment:', error);
                this.showNotification('Failed to purchase equipment', 'error');
            });
        }
    }

    updateLeaderboard() {
        try {
            if (this.testMode) {
                // Mock leaderboard data based on current filter
                this.leaderboardData = this.getMockLeaderboardData();
            } else {
                // Request leaderboard from server with current filter
                fetch(`https://${GetParentResourceName()}/getLeaderboardFiltered`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ filterType: this.currentFilter })
                });
            }

            this.displayLeaderboard();
            this.updateFilterInfo();
        } catch (error) {
            console.error('Error updating leaderboard:', error);
        }
    }

    getMockLeaderboardData() {
        // Generate mock data based on current filter
        const mockData = [];
        const names = ['Miner_Pro', 'RockCrusher', 'DiamondHunter', 'IronMaster', 'CoalCollector', 'StoneBreaker', 'GoldDigger', 'CrystalFinder', 'OreMaster', 'GemHunter'];
        
        for (let i = 0; i < 20; i++) {
            const mockPlayer = {
                rank: i + 1,
                name: names[i % names.length] + (i > 9 ? `_${Math.floor(i / 10)}` : ''),
                level: Math.max(1, 50 - i * 2),
                xp: Math.max(0, 5000 - i * 250),
                totalMined: Math.max(0, 1000 - i * 50),
                totalSmelted: Math.max(0, 500 - i * 25)
            };
            mockData.push(mockPlayer);
        }

        // Sort based on current filter
        if (this.currentFilter === 'level') {
            mockData.sort((a, b) => b.level - a.level);
        } else if (this.currentFilter === 'smelted') {
            mockData.sort((a, b) => b.totalSmelted - a.totalSmelted);
        } else if (this.currentFilter === 'mined') {
            mockData.sort((a, b) => b.totalMined - a.totalMined);
        }

        // For position calculation, we need a copy sorted by total mined
        this.leaderboardDataForPosition = [...mockData].sort((a, b) => b.totalMined - a.totalMined);

        return mockData;
    }

    getPlayerLeaderboardPosition() {
        try {
            // Use the position-specific leaderboard data if available, otherwise fall back to current
            const dataToUse = this.leaderboardDataForPosition || this.leaderboardData;
            
            if (!dataToUse || dataToUse.length === 0) {
                return 0;
            }

            // Always use total mined for position calculation
            const playerTotalMined = this.playerData.totalMined || 0;
            
            // Find player's position in the leaderboard by total mined
            let position = 1;
            for (const player of dataToUse) {
                if (player.totalMined > playerTotalMined) {
                    position++;
                }
            }
            
            // Cap position at 20 (top 20)
            return Math.min(position, 20);
        } catch (error) {
            console.error('Error getting player leaderboard position:', error);
            return 0;
        }
    }

    updateFilterInfo() {
        try {
            const filterInfo = document.getElementById('filterInfo');
            if (!filterInfo) return;

            const filterLabels = {
                'level': 'Mining Level',
                'smelted': 'Total Smelted',
                'mined': 'Total Mined'
            };

            const currentLabel = filterLabels[this.currentFilter] || 'Mining Level';
            filterInfo.textContent = `Showing top 20 by ${currentLabel}`;
        } catch (error) {
            console.error('Error updating filter info:', error);
        }
    }

    displayLeaderboard() {
        try {
            const leaderboardList = document.getElementById('leaderboardList');
            if (!leaderboardList) return;

            if (!this.leaderboardData || this.leaderboardData.length === 0) {
                leaderboardList.innerHTML = `
                    <div class="leaderboard-loading">
                        <i class="fas fa-spinner fa-spin"></i>
                        <p>Loading leaderboard...</p>
                    </div>
                `;
                return;
            }

            let leaderboardHTML = '';
            this.leaderboardData.forEach((player) => {
                leaderboardHTML += `
                    <div class="leaderboard-item">
                        <div class="rank">${player.rank || '?'}</div>
                        <div class="player-name">${player.name}</div>
                        <div class="player-level">${player.level}</div>
                        <div class="player-xp">${player.xp}</div>
                        <div class="total-mined">${player.totalMined}</div>
                        <div class="total-smelted">${player.totalSmelted}</div>
                    </div>
                `;
            });

            leaderboardList.innerHTML = leaderboardHTML;
            
            // Update the dashboard leaderboard position after displaying the leaderboard
            this.updatePlayerStats();
        } catch (error) {
            console.error('Error displaying leaderboard:', error);
        }
    }

    updateUI() {
        try {
            this.updatePlayerStats();
            this.populateEquipmentGrid();
            // Add a small delay to ensure DOM elements are created before updating status
            setTimeout(() => {
                this.updateEquipmentStatus();
            }, 100);
            this.updateLeaderboard();
        } catch (error) {
            console.error('Error updating UI:', error);
        }
    }

    populateEquipmentGrid() {
        try {
            const equipmentGrid = document.getElementById('equipmentGrid');
            if (!equipmentGrid) return;

            // Clear existing equipment
            equipmentGrid.innerHTML = '';

            // Populate equipment from config
            Object.keys(this.equipmentConfig).forEach(toolKey => {
                const tool = this.equipmentConfig[toolKey];
                const isUnlocked = this.playerData.level >= tool.unlockLevel;
                
                const equipmentItem = document.createElement('div');
                equipmentItem.className = 'equipment-item';
                equipmentItem.id = `${toolKey}-item`;
                
                equipmentItem.innerHTML = `
                    <div class="equipment-icon">
                        <i class="${tool.icon}"></i>
                    </div>
                    <div class="equipment-details">
                        <h3>${tool.label}</h3>
                        <p class="equipment-description">${tool.description}</p>
                        <div class="equipment-requirements">
                            <span class="requirement">Level Required: ${tool.unlockLevel}</span>
                            <span class="price">$${tool.price.toLocaleString()}</span>
                        </div>
                        <div class="equipment-status" id="${toolKey}-status">
                            <span class="${isUnlocked ? 'status-available' : 'status-locked'}">
                                ${isUnlocked ? 'Available' : 'Locked'}
                            </span>
                        </div>
                    </div>
                    <div class="equipment-actions">
                        <button class="btn ${isUnlocked ? 'btn-primary' : 'btn-secondary'}" 
                                id="${toolKey}-btn" 
                                ${!isUnlocked ? 'disabled' : ''}>
                            ${isUnlocked ? `Purchase $${tool.price.toLocaleString()}` : `Level ${tool.unlockLevel} Required`}
                        </button>
                    </div>
                `;

                // Add event listener for the button
                const button = equipmentItem.querySelector(`#${toolKey}-btn`);
                if (button) {
                    button.addEventListener('click', () => this.getEquipment(toolKey));
                }

                equipmentGrid.appendChild(equipmentItem);
            });
        } catch (error) {
            console.error('Error populating equipment grid:', error);
        }
    }

    // Test Mode Methods
    enableTestMode() {
        this.testMode = true;
        this.loadMockData();
        this.addTestControls();

    }

    loadMockData() {
        // Mock player data for testing
        this.playerData = {
            level: 2,
            xp: 150,
            totalMined: 5,
            xpForNextLevel: 50,
            xpProgress: 50.0
        };
        
        // Mock equipment data - will be populated from config
        this.equipment = {};
        
        // Mock inventory check for test mode
        this.checkInventoryStatus();
        
        // Mock leaderboard data
        this.leaderboardData = [
            { name: 'Miner_Pro', level: 45, totalMined: 892, totalSmelted: 156, xp: 5000 },
            { name: 'RockCrusher', level: 38, totalMined: 654, totalSmelted: 142, xp: 4750 },
            { name: 'DiamondHunter', level: 32, totalMined: 521, totalSmelted: 128, xp: 4500 },
            { name: 'IronMaster', level: 28, totalMined: 398, totalSmelted: 114, xp: 4250 },
            { name: 'CoalCollector', level: 25, totalMined: 312, totalSmelted: 100, xp: 4000 }
        ];
        
        // Create position-specific data sorted by total mined
        this.leaderboardDataForPosition = [...this.leaderboardData].sort((a, b) => b.totalMined - a.totalMined);
        
        // Update UI with mock data
        this.updatePlayerStats();
        this.updateLeaderboard();
    }

    addTestControls() {
        // Create test control panel
        const testPanel = document.createElement('div');
        testPanel.id = 'testControlPanel';
        testPanel.style.cssText = `
            position: fixed;
            top: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.9);
            border: 2px solid #e74c3c;
            border-radius: 12px;
            padding: 20px;
            color: white;
            font-family: 'Roboto', sans-serif;
            z-index: 10001;
            min-width: 300px;
            backdrop-filter: blur(10px);
        `;
        
        testPanel.innerHTML = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                <h3 style="margin: 0; color: #e74c3c; display: flex; align-items: center; gap: 10px;">
                    <i class="fas fa-mountain"></i> Mining Test Controls
                </h3>
                <button id="testCollapse" style="padding: 4px 8px; background: #34495e; border: none; border-radius: 4px; color: white; cursor: pointer; font-size: 12px;">
                    <i class="fas fa-chevron-up"></i>
                </button>
            </div>
            
            <div id="testControlsContent">
                <div style="margin-bottom: 15px;">
                    <label style="display: block; margin-bottom: 5px; color: #e74c3c;">Mining Level:</label>
                    <input type="range" id="testLevel" min="1" max="100" value="${this.playerData.level}" style="width: 100%;">
                    <span id="testLevelValue">${this.playerData.level}</span>
                </div>
                
                <div style="margin-bottom: 15px;">
                    <label style="display: block; margin-bottom: 5px; color: #e74c3c;">Mining XP:</label>
                    <input type="range" id="testXP" min="0" max="10000" value="${this.playerData.xp}" style="width: 100%;">
                    <span id="testXPValue">${this.playerData.xp}</span>
                </div>
                
                <div style="margin-bottom: 15px;">
                    <label style="display: block; margin-bottom: 5px; color: #e74c3c;">Total Mined:</label>
                    <input type="number" id="testMined" value="${this.playerData.totalMined}" style="width: 100%; padding: 5px; background: rgba(0,0,0,0.5); border: 1px solid #e74c3c; border-radius: 4px; color: white;">
                </div>
                
                <div style="margin-bottom: 20px;">
                    <button id="testRefresh" style="padding: 8px 12px; background: #e74c3c; border: none; border-radius: 4px; color: white; cursor: pointer; width: 100%;">
                        <i class="fas fa-sync-alt"></i> Refresh UI
                    </button>
                </div>
                
                <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #e74c3c; font-size: 0.8rem; opacity: 0.7;">
                    <strong>Mining Test Mode Active</strong><br>
                    Test mining operations and equipment
                </div>
                
                <div style="margin-top: 15px;">
                    <button id="testMining" style="padding: 8px 12px; background: #27ae60; border: none; border-radius: 4px; color: white; cursor: pointer; width: 100%;">
                        <i class="fas fa-mountain"></i> Simulate Mining
                    </button>
                </div>
            </div>
        `;
        
        document.body.appendChild(testPanel);
        
        // Add event listeners for test controls
        this.setupTestControls();
    }

    setupTestControls() {
        const levelSlider = document.getElementById('testLevel');
        const levelValue = document.getElementById('testLevelValue');
        const xpSlider = document.getElementById('testXP');
        const xpValue = document.getElementById('testXPValue');
        const minedInput = document.getElementById('testMined');
        const refreshBtn = document.getElementById('testRefresh');
        const collapseBtn = document.getElementById('testCollapse');
        const controlsContent = document.getElementById('testControlsContent');
        
        // Level slider
        if (levelSlider && levelValue) {
            levelSlider.addEventListener('input', (e) => {
                const level = parseInt(e.target.value);
                levelValue.textContent = level;
                this.playerData.level = level;
                this.updatePlayerStats();
                this.updateEquipmentStatus();
            });
        }
        
        // XP slider
        if (xpSlider && xpValue) {
            xpSlider.addEventListener('input', (e) => {
                const xp = parseInt(e.target.value);
                xpValue.textContent = xp;
                this.playerData.xp = xp;
                this.updatePlayerStats();
            });
        }
        
        // Total mined input
        if (minedInput) {
            minedInput.addEventListener('input', (e) => {
                this.playerData.totalMined = parseInt(e.target.value) || 0;
                this.updatePlayerStats();
            });
        }
        
        // Refresh button
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => {
                this.updateUI();
            });
        }
        
        // Collapse button
        if (collapseBtn && controlsContent) {
            collapseBtn.addEventListener('click', () => {
                const isCollapsed = controlsContent.style.display === 'none';
                controlsContent.style.display = isCollapsed ? 'block' : 'none';
                collapseBtn.innerHTML = isCollapsed ? '<i class="fas fa-chevron-up"></i>' : '<i class="fas fa-chevron-down"></i>';
            });
        }
        
        // Test mining button
        const testMiningBtn = document.getElementById('testMining');
        if (testMiningBtn) {
            testMiningBtn.addEventListener('click', () => {
                this.simulateMining();
            });
        }
    }

    showNotification(message, type = 'info') {
        // Simple notification system for test mode
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: ${type === 'success' ? '#2ecc71' : type === 'error' ? '#e74c3c' : '#3498db'};
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            z-index: 10000;
            max-width: 300px;
            animation: slideIn 0.3s ease;
        `;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        // Remove notification after 3 seconds
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    // FiveM Integration Methods
    sendToClient(eventName, data) {
        if (this.testMode) {
            // In test mode, simulate responses

            return;
        }
        
        // In FiveM, send to client
        fetch(`https://${GetParentResourceName()}/${eventName}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });
    }

    // Handle NUI messages from FiveM client
    handleNUIMessage(message) {
        switch (message.type) {
            case 'showUI':
                this.showUI();
                break;
            case 'hideUI':
                this.hideUI();
                break;
            case 'showMiningUI':
                this.showMiningUI();
                break;
            case 'hideMiningUI':
                this.hideMiningUI();
                break;
            case 'updatePlayerData':
                if (message.playerData) {
    
            
                    this.playerData = message.playerData;
                    this.updatePlayerStats();
                    // Update equipment status when player data changes
                    setTimeout(() => {
                        this.updateEquipmentStatus();
                    }, 100);
                }
                break;
            case 'updateEquipment':
                this.updateEquipmentOwnership(message.toolType, message.owned);
                break;
            case 'updateLeaderboard':
                if (message.leaderboardData) {
    
        
                    
                    this.leaderboardData = message.leaderboardData;
                    this.currentFilter = message.filterType || this.currentFilter;
                    
                    this.displayLeaderboard();
                    this.updateFilterInfo();
                }
                break;
            case 'gatheringSuccess':
                if (message.gatheringData) {
                    this.handleGatheringSuccess(message.gatheringData);
                }
                break;
            case 'showLoading':
                // this.showLoading(); // Removed
                break;
            case 'hideLoading':
                // this.hideLoading(); // Removed
                break;
        }
    }

    showUI() {
        const ipadFrame = document.getElementById('ipadFrame');
        if (ipadFrame) {
            ipadFrame.style.display = 'block';
        }
    }

    hideUI() {
        const ipadFrame = document.getElementById('ipadFrame');
        if (ipadFrame) {
            ipadFrame.style.display = 'none';
        }
    }

    showMiningUI() {
        const ipadFrame = document.getElementById('ipadFrame');
        if (ipadFrame) {
            ipadFrame.style.display = 'block';
        }
        
        // Request updated player data when UI opens
        if (!this.testMode && window.GetParentResourceName) {
            fetch(`https://${GetParentResourceName()}/getPlayerData`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        }
    }

    hideMiningUI() {
        const ipadFrame = document.getElementById('ipadFrame');
        if (ipadFrame) {
            ipadFrame.style.display = 'none';
        }
    }

    closeUI() {
        // Close the UI regardless of which type it is
        this.hideMiningUI();
        
        // If we're in FiveM, send the close event to the client
        if (!this.testMode && window.GetParentResourceName) {
            fetch(`https://${GetParentResourceName()}/closeUI`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        }
    }

    // Update equipment ownership status
    updateEquipmentOwnership(toolType, owned) {
        if (this.equipment[toolType]) {
            this.equipment[toolType].unlocked = owned;
            this.equipment[toolType].level = owned ? 1 : 0;
            this.updateEquipmentStatus();
        }
    }

    // Check inventory status for equipment
    checkInventoryStatus() {
        if (this.testMode) {
            // In test mode, simulate inventory check
    
            return;
        }
        
        // In FiveM, check actual inventory for equipment
        // This would be called when the UI opens to sync with actual inventory

    }

    // Handle successful gathering from FiveM
    handleGatheringSuccess(gatheringData) {
        // Update player data with new mining results
        if (gatheringData.xpGained) {
            this.playerData.xp += gatheringData.xpGained;
        }
        if (gatheringData.newTotalMined) {
            this.playerData.totalMined = gatheringData.newTotalMined;
        }
        
        // Check for level up
        const oldLevel = this.playerData.level;
        this.playerData.level = Math.floor(this.playerData.xp / 100) + 1;
        
        // Update XP progress
        this.playerData.xpProgress = (this.playerData.xp % 100) / 100 * 100;
        this.playerData.xpForNextLevel = 100 - (this.playerData.xp % 100);
        
        // Update UI
        this.updatePlayerStats();
        
        // Show success notification
        if (gatheringData.itemsFound) {
            this.showNotification(`Successfully gathered ${gatheringData.itemsFound.amount}x ${gatheringData.itemsFound.name}!`, 'success');
        }
        
        // Show level up notification if applicable
        if (this.playerData.level > oldLevel) {
            this.showNotification(`Level Up! You are now level ${this.playerData.level}!`, 'success');
        }
        
        
    }

    // Simulate mining operation for testing
    simulateMining() {
        if (!this.testMode) return;
        
        // Simulate XP gain
        const baseXP = 20;
        const bonusXP = Math.floor(Math.random() * 10); // Random bonus 0-9
        const totalXP = baseXP + bonusXP;
        
        // Update player data
        this.playerData.xp += totalXP;
        this.playerData.totalMined += 1;
        
        // Check for level up
        const oldLevel = this.playerData.level;
        this.playerData.level = Math.floor(this.playerData.xp / 100) + 1; // Simple level calculation for test
        
        // Update XP progress
        this.playerData.xpProgress = (this.playerData.xp % 100) / 100 * 100;
        this.playerData.xpForNextLevel = 100 - (this.playerData.xp % 100);
        
        // Update UI
        this.updatePlayerStats();
        
        // Show notification
        if (this.playerData.level > oldLevel) {
            this.showNotification(`Level Up! You are now level ${this.playerData.level}!`, 'success');
        } else {
            this.showNotification(`You gained ${totalXP} mining XP!`, 'success');
        }
        

    }
}

// Initialize UI when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.miningUI = new ResourceGatheringUI();
});

// Listen for NUI messages from FiveM client
window.addEventListener('message', (event) => {
    if (window.miningUI) {
        window.miningUI.handleNUIMessage(event.data);
    }
});

// Add CSS animation for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
`;
document.head.appendChild(style);
