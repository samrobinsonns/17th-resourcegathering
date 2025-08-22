// Resource Gathering UI - Main JavaScript
class ResourceGatheringUI {
    constructor() {
        this.testMode = false;
        this.playerData = {
            level: 1,
            xp: 0,
            totalMined: 0
        };
        this.equipment = {
            pickaxe: { unlocked: true, level: 1 },
            drill: { unlocked: false, level: 0 },
            laser: { unlocked: false, level: 0 }
        };
        this.leaderboardData = [];
        
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

        // Equipment buttons
        const pickaxeBtn = document.getElementById('pickaxe-btn');
        if (pickaxeBtn) {
            pickaxeBtn.addEventListener('click', () => this.getEquipment('pickaxe'));
        }

        const drillBtn = document.getElementById('drill-btn');
        if (drillBtn) {
            drillBtn.addEventListener('click', () => this.getEquipment('drill'));
        }

        const laserBtn = document.getElementById('laser-btn');
        if (laserBtn) {
            laserBtn.addEventListener('click', () => this.getEquipment('laser'));
        }

        // Leaderboard period selector
        const leaderboardPeriod = document.getElementById('leaderboardPeriod');
        if (leaderboardPeriod) {
            leaderboardPeriod.addEventListener('change', (e) => {
                this.updateLeaderboard(e.target.value);
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
                    level: 25,
                    xp: 3450,
                    totalMined: 156
                };
            }

            this.updatePlayerStats();
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
            
            // Use server-calculated XP progress if available
            if (this.playerData.xpProgress !== undefined) {
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
            }
            
            // Update XP text
            const currentXPElement = document.getElementById('currentXP');
            if (currentXPElement) {
                const xpInCurrentLevel = currentXP - this.getLevelXP(currentLevel);
                currentXPElement.textContent = Math.max(0, xpInCurrentLevel);
            }
            
            const nextLevelXPElement = document.getElementById('nextLevelXP');
            if (nextLevelXPElement) {
                if (this.playerData.xpForNextLevel !== undefined) {
                    nextLevelXPElement.textContent = this.playerData.xpForNextLevel;
                } else {
                    const nextLevelXP = this.getLevelXP(currentLevel + 1);
                    const currentLevelXP = this.getLevelXP(currentLevel);
                    nextLevelXPElement.textContent = nextLevelXP - currentLevelXP;
                }
            }
        } catch (error) {
            console.error('Error updating XP progress:', error);
        }
    }

    getLevelXP(level) {
        // Simple XP calculation: each level requires level * 100 XP
        return level * 100;
    }

    updateEquipmentDisplay() {
        try {
            // Update equipment status based on player level
            this.updateEquipmentStatus('pickaxe', 1);
            this.updateEquipmentStatus('drill', 25);
            this.updateEquipmentStatus('laser', 50);
        } catch (error) {
            console.error('Error updating equipment display:', error);
        }
    }

    updateEquipmentStatus(equipmentType, requiredLevel) {
        const statusElement = document.getElementById(`${equipmentType}-status`);
        const buttonElement = document.getElementById(`${equipmentType}-btn`);
        
        if (!statusElement || !buttonElement) return;
        
        if (this.playerData.level >= requiredLevel) {
            // Equipment is available
            statusElement.innerHTML = '<span class="status-available">Available</span>';
            buttonElement.className = 'btn btn-primary';
            buttonElement.disabled = false;
            buttonElement.textContent = `Get ${equipmentType.charAt(0).toUpperCase() + equipmentType.slice(1)}`;
        } else {
            // Equipment is locked
            statusElement.innerHTML = '<span class="status-locked">Locked</span>';
            buttonElement.className = 'btn btn-secondary';
            buttonElement.disabled = true;
            buttonElement.textContent = `Level ${requiredLevel} Required`;
        }
    }

    getEquipment(equipmentType) {
        if (this.testMode) {
            // In test mode, just show a notification
            this.showNotification(`You got a ${equipmentType}!`, 'success');
            this.equipment[equipmentType].unlocked = true;
            this.equipment[equipmentType].level = 1;
            this.updateEquipmentDisplay();
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
                    // Update equipment ownership
                    this.equipment[equipmentType].unlocked = true;
                    this.equipment[equipmentType].level = 1;
                    this.updateEquipmentDisplay();
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

    updateLeaderboard(period = 'weekly') {
        try {
            if (this.testMode) {
                // Mock leaderboard data
                this.leaderboardData = [
                    { name: 'Miner_Pro', level: 45, totalMined: 892 },
                    { name: 'RockCrusher', level: 38, totalMined: 654 },
                    { name: 'DiamondHunter', level: 32, totalMined: 521 },
                    { name: 'IronMaster', level: 28, totalMined: 398 },
                    { name: 'CoalCollector', level: 25, totalMined: 312 }
                ];
            } else {
                // Request leaderboard from server
                fetch(`https://${GetParentResourceName()}/getLeaderboard`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ period: period })
                });
            }

            this.displayLeaderboard();
        } catch (error) {
            console.error('Error updating leaderboard:', error);
        }
    }

    displayLeaderboard() {
        try {
            const leaderboardList = document.getElementById('leaderboardList');
            if (!leaderboardList) return;

            let leaderboardHTML = '';
            this.leaderboardData.forEach((player, index) => {
                leaderboardHTML += `
                    <div class="leaderboard-item">
                        <div class="rank">${index + 1}</div>
                        <div class="player-info">
                            <div class="player-name">${player.name}</div>
                            <div class="player-level">Level ${player.level}</div>
                        </div>
                        <div class="player-stats">
                            <div class="total-mined">${player.totalMined} Mined</div>
                        </div>
                    </div>
                `;
            });

            leaderboardList.innerHTML = leaderboardHTML;
        } catch (error) {
            console.error('Error displaying leaderboard:', error);
        }
    }

    updateUI() {
        try {
            this.updatePlayerStats();
            this.updateEquipmentDisplay();
            this.updateLeaderboard();
        } catch (error) {
            console.error('Error updating UI:', error);
        }
    }

    // Test Mode Methods
    enableTestMode() {
        this.testMode = true;
        this.loadMockData();
        this.addTestControls();
        console.log('🧪 Test Mode Enabled - Using Mock Data');
    }

    loadMockData() {
        // Mock player data for testing
        this.playerData = {
            level: 25,
            xp: 3450,
            totalMined: 156,
            xpForNextLevel: 120,
            xpProgress: 75.5
        };
        
        // Mock equipment data
        this.equipment = {
            pickaxe: { unlocked: true, level: 1 },
            drill: { unlocked: false, level: 0 },
            laser: { unlocked: false, level: 0 }
        };
        
        // Mock inventory check for test mode
        this.checkInventoryStatus();
        
        // Mock leaderboard data
        this.leaderboardData = [
            { name: 'Miner_Pro', level: 45, totalMined: 892 },
            { name: 'RockCrusher', level: 38, totalMined: 654 },
            { name: 'DiamondHunter', level: 32, totalMined: 521 },
            { name: 'IronMaster', level: 28, totalMined: 398 },
            { name: 'CoalCollector', level: 25, totalMined: 312 }
        ];
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
                this.updateEquipmentDisplay();
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
            console.log(`[TEST MODE] Simulating ${eventName}:`, data);
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
            case 'updatePlayerData':
                if (message.playerData) {
                    this.playerData = message.playerData;
                    this.updatePlayerStats();
                }
                break;
            case 'updateEquipment':
                this.updateEquipmentOwnership(message.toolType, message.owned);
                break;
            case 'updateLeaderboard':
                if (message.leaderboardData) {
                    this.leaderboardData = message.leaderboardData;
                    this.displayLeaderboard();
                }
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

    // Update equipment ownership status
    updateEquipmentOwnership(toolType, owned) {
        if (this.equipment[toolType]) {
            this.equipment[toolType].unlocked = owned;
            this.equipment[toolType].level = owned ? 1 : 0;
            this.updateEquipmentDisplay();
        }
    }

    // Check inventory status for equipment
    checkInventoryStatus() {
        if (this.testMode) {
            // In test mode, simulate inventory check
            console.log('🧪 Test Mode: Checking inventory status for equipment');
            return;
        }
        
        // In FiveM, check actual inventory for equipment
        // This would be called when the UI opens to sync with actual inventory
        console.log('Checking actual inventory for mining equipment...');
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
        
        console.log(`🧪 Test Mining: +${totalXP} XP, Total: ${this.playerData.xp}, Level: ${this.playerData.level}`);
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
