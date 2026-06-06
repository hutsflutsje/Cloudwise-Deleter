# Interactive Ladder Game Scaffolding Script
$projectName = "interactive-ladder-game"
New-Item -ItemType Directory -Path $projectName -Force
Set-Location -Path $projectName

# 1. package.json
$packageJson = @'
{
  "name": "interactive-ladder-game",
  "version": "1.0.0",
  "description": "Interactive Ladder TikTok Live Game",
  "main": "main.js",
  "scripts": {
    "start": "electron ."
  },
  "dependencies": {
    "ws": "^8.17.0"
  },
  "devDependencies": {
    "electron": "^31.0.0",
    "electron-builder": "^24.4.0"
  }
}
'@

# 2. main.js
$mainJs = @'
const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 540,
    height: 960,
    resizable: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');
  mainWindow.setAspectRatio(9/16);
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});
'@

# 3. index.html
$indexHtml = @'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Interactive Ladder</title>
    <style>
        body { margin: 0; padding: 0; overflow: hidden; font-family: 'Comic Sans MS', 'Arial Rounded MT Bold', Helvetica, sans-serif; background-color: #000; }
        #game-container { position: relative; width: 540px; height: 960px; margin: 0 auto; background: #1a2a6c; }
        canvas { display: block; width: 100%; height: 100%; }
        #hud { position: absolute; top: 0; left: 0; width: 100%; padding: 20px; box-sizing: border-box; color: white; text-shadow: -2px -2px 0 #000, 2px -2px 0 #000, -2px 2px 0 #000, 2px 2px 0 #000; pointer-events: none; z-index: 10; }
        #height-info { text-align: center; margin: 10px 0; }
        #current-height { font-size: 3.5rem; font-weight: bold; text-align: center; }
        #target-note { font-size: 1.2rem; color: #f1c40f; text-align: center; }
        #event-stats { background: rgba(0,0,0,0.6); padding: 10px; border-radius: 5px; font-size: 0.9rem; margin-top: 10px; border: 1px solid white; }
        #gift-info { position: absolute; bottom: 40px; left: 50%; transform: translateX(-50%); background: #2980b9; padding: 10px 20px; border-radius: 25px; border: 3px solid white; font-weight: bold; }
        #menu-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0, 0, 0, 0.85); display: flex; justify-content: center; align-items: center; z-index: 100; }
        .menu-screen { width: 85%; text-align: center; color: white; }
        h1 { font-size: 3rem; margin-bottom: 20px; color: #f39c12; }
        input[type="text"], input[type="number"], select { width: 100%; padding: 12px; margin: 8px 0; border-radius: 5px; border: 2px solid #f39c12; font-size: 1rem; box-sizing: border-box; }
        button { width: 100%; padding: 15px; margin: 10px 0; background: #e67e22; color: white; border: none; border-radius: 5px; font-size: 1.2rem; font-weight: bold; cursor: pointer; border-bottom: 4px solid #d35400; }
        button:hover { background: #d35400; }
        .setting-group { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
        .setting-group label { flex: 1; text-align: left; font-size: 0.9rem; }
        .setting-group input, .setting-group select { flex: 0.6; }
        .hidden { display: none !important; }
        #sim-overlay { position: absolute; bottom: 110px; right: 20px; background: rgba(0,0,0,0.8); padding: 10px; border-radius: 10px; border: 1px solid #f39c12; color: white; z-index: 200; pointer-events: auto; }
        #sim-overlay button { padding: 5px; font-size: 0.8rem; margin: 2px 0; border-bottom: 2px solid #d35400; }
    </style>
</head>
<body>
    <div id="game-container">
        <canvas id="gameCanvas"></canvas>
        <div id="hud" class="hidden">
            <div id="user-info">User: <span id="display-username">Player</span></div>
            <div id="height-info">
                <div id="current-height">0m</div>
                <div id="target-note">1000m = win</div>
            </div>
            <div id="event-stats">
                Likes: <span id="stat-likes">0/10</span> |
                Follows: <span id="stat-follows">0/1</span> |
                Shares: <span id="stat-shares">0/1</span> |
                Comments: <span id="stat-comments">0/5</span>
            </div>
            <div id="gift-info">Gifts: <span id="gift-count">0/10</span></div>
        </div>
        <div id="sim-overlay" class="hidden">
            <strong>SIMULATION</strong>
            <button onclick="simulateEvent('like')">Like</button>
            <button onclick="simulateEvent('follow')">Follow</button>
            <button onclick="simulateEvent('share')">Share</button>
            <button onclick="simulateEvent('comment')">Comment</button>
            <button onclick="simulateEvent('gift')">Gift</button>
            <p>H: Toggle</p>
        </div>
        <div id="menu-overlay">
            <div id="main-menu" class="menu-screen">
                <h1>LADDER CLIMB</h1>
                <input type="text" id="username-input" placeholder="TikTok Username" value="Player123">
                <button onclick="startGame()">START GAME</button>
                <button onclick="showScreen('event-settings')">EVENT SETTINGS</button>
                <button onclick="showScreen('threshold-settings')">THRESHOLDS</button>
            </div>
            <div id="event-settings" class="menu-screen hidden">
                <h2>EVENT SETTINGS (m)</h2>
                <div class="setting-group"><label>Like:</label><select id="set-like-val"><option value="5" selected>+5</option><option value="10">+10</option><option value="15">+15</option><option value="-5">-5</option><option value="-10">-10</option></select></div>
                <div class="setting-group"><label>Follow:</label><select id="set-follow-val"><option value="10" selected>+10</option><option value="20">+20</option><option value="-10">-10</option><option value="-20">-20</option></select></div>
                <div class="setting-group"><label>Share:</label><select id="set-share-val"><option value="15" selected>+15</option><option value="25">+25</option><option value="-15">-15</option><option value="-25">-25</option></select></div>
                <div class="setting-group"><label>Comment:</label><select id="set-comment-val"><option value="3" selected>+3</option><option value="5">+5</option><option value="-3">-3</option><option value="-5">-5</option></select></div>
                <div class="setting-group"><label>Gift:</label><select id="set-gift-val"><option value="-10" selected>-10</option><option value="-20">-20</option><option value="-30">-30</option><option value="-40">-40</option><option value="-50">-50</option></select></div>
                <button onclick="showScreen('main-menu')">BACK</button>
            </div>
            <div id="threshold-settings" class="menu-screen hidden">
                <h2>THRESHOLDS</h2>
                <div class="setting-group"><label>Likes:</label><input type="number" id="thresh-likes" value="10"></div>
                <div class="setting-group"><label>Follows:</label><input type="number" id="thresh-follows" value="1"></div>
                <div class="setting-group"><label>Shares:</label><input type="number" id="thresh-shares" value="1"></div>
                <div class="setting-group"><label>Comments:</label><input type="number" id="thresh-comments" value="5"></div>
                <div class="setting-group"><label>Gift Coins:</label><input type="number" id="thresh-gifts" value="10"></div>
                <button onclick="showScreen('main-menu')">BACK</button>
            </div>
            <div id="pause-menu" class="menu-screen hidden">
                <h1>PAUSED</h1>
                <button onclick="togglePause()">RESUME</button>
                <button onclick="location.reload()">MAIN MENU</button>
            </div>
            <div id="win-screen" class="menu-screen hidden">
                <h1 style="color: #f1c40f;">YOU WIN!</h1>
                <p>1000m REACHED!</p>
                <button onclick="location.reload()">RESTART</button>
            </div>
            <div id="gameover-screen" class="menu-screen hidden">
                <h1 style="color: #e74c3c;">GAME OVER</h1>
                <p>You fell to 0m!</p>
                <button onclick="location.reload()">RESTART</button>
            </div>
        </div>
    </div>
    <script src="game.js"></script>
</body>
</html>
'@

# 4. game.js
$gameJs = @'
const WebSocket = require('ws');
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
let gameState = 'MENU'; let currentHeight = 10; let giftCount = 0; let username = "Player"; let isPaused = false;
let counters = { likes: 0, follows: 0, shares: 0, comments: 0 };
let thresholds = { likes: 10, follows: 1, shares: 1, comments: 5, gifts: 10 };
let eventValues = { like: 5, follow: 10, share: 15, comment: 3, gift: -10 };
let clouds = []; let character = { y: 0, isFalling: false, tumble: 0 };
function init() {
    canvas.width = 540; canvas.height = 960; character.y = canvas.height * 0.7;
    for (let i = 0; i < 8; i++) clouds.push({ x: Math.random() * canvas.width, y: Math.random() * canvas.height, size: 30 + Math.random() * 60, speed: 0.1 + Math.random() * 0.4 });
}
window.showScreen = (id) => { document.querySelectorAll('.menu-screen').forEach(s => s.classList.add('hidden')); document.getElementById(id).classList.remove('hidden'); };
window.startGame = () => {
    username = document.getElementById('username-input').value || "Player"; document.getElementById('display-username').textContent = username;
    thresholds.likes = parseInt(document.getElementById('thresh-likes').value); thresholds.follows = parseInt(document.getElementById('thresh-follows').value);
    thresholds.shares = parseInt(document.getElementById('thresh-shares').value); thresholds.comments = parseInt(document.getElementById('thresh-comments').value); thresholds.gifts = parseInt(document.getElementById('thresh-gifts').value);
    eventValues.like = parseInt(document.getElementById('set-like-val').value); eventValues.follow = parseInt(document.getElementById('set-follow-val').value);
    eventValues.share = parseInt(document.getElementById('set-share-val').value); eventValues.comment = parseInt(document.getElementById('set-comment-val').value); eventValues.gift = parseInt(document.getElementById('set-gift-val').value);
    gameState = 'PLAYING'; document.getElementById('menu-overlay').classList.add('hidden'); document.getElementById('hud').classList.remove('hidden'); updateStats();
};
window.togglePause = () => { if (gameState !== 'PLAYING' && gameState !== 'PAUSED') return; isPaused = !isPaused; gameState = isPaused ? 'PAUSED' : 'PLAYING'; if (isPaused) { document.getElementById('menu-overlay').classList.remove('hidden'); showScreen('pause-menu'); } else { document.getElementById('menu-overlay').classList.add('hidden'); } };
function updateStats() {
    document.getElementById('current-height').textContent = Math.floor(currentHeight) + 'm'; document.getElementById('gift-count').textContent = `${giftCount}/10`;
    document.getElementById('stat-likes').textContent = `${counters.likes}/${thresholds.likes}`; document.getElementById('stat-follows').textContent = `${counters.follows}/${thresholds.follows}`;
    document.getElementById('stat-shares').textContent = `${counters.shares}/${thresholds.shares}`; document.getElementById('stat-comments').textContent = `${counters.comments}/${thresholds.comments}`;
}
function handleClimb(amount) {
    if (gameState !== 'PLAYING') return; currentHeight += amount; if (amount < 0) { character.isFalling = true; character.tumble = 40; }
    if (currentHeight >= 1000) { currentHeight = 1000; gameState = 'WIN'; document.getElementById('menu-overlay').classList.remove('hidden'); showScreen('win-screen'); }
    else if (currentHeight <= 0) { currentHeight = 0; gameState = 'GAMEOVER'; document.getElementById('menu-overlay').classList.remove('hidden'); showScreen('gameover-screen'); }
    updateStats();
}
window.addEventListener('keydown', (e) => { if (e.code === 'Space') handleClimb(10); if (e.key.toLowerCase() === 'm') togglePause(); if (e.key.toLowerCase() === 'h') document.getElementById('sim-overlay').classList.toggle('hidden'); });
const wss = new WebSocket.Server({ port: 8080 });
wss.on('connection', (ws) => { ws.on('message', (msg) => { try { processEvent(JSON.parse(msg)); } catch (err) {} }); });
function processEvent(data) {
    if (gameState !== 'PLAYING') return;
    switch(data.event) {
        case 'like': counters.likes++; if (counters.likes >= thresholds.likes) { counters.likes = 0; handleClimb(eventValues.like); } break;
        case 'follow': counters.follows++; if (counters.follows >= thresholds.follows) { counters.follows = 0; handleClimb(eventValues.follow); } break;
        case 'share': counters.shares++; if (counters.shares >= thresholds.shares) { counters.shares = 0; handleClimb(eventValues.share); } break;
        case 'comment': counters.comments++; if (counters.comments >= thresholds.comments) { counters.comments = 0; handleClimb(eventValues.comment); } break;
        case 'gift': if (data.value >= thresholds.gifts) { giftCount++; handleClimb(eventValues.gift); } break;
    }
    updateStats();
}
window.simulateEvent = (type) => { if (type === 'gift') processEvent({event: 'gift', value: thresholds.gifts}); else processEvent({event: type}); };
function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height); const skyGrad = ctx.createLinearGradient(0, 0, 0, canvas.height); skyGrad.addColorStop(0, '#4facfe'); skyGrad.addColorStop(1, '#00f2fe'); ctx.fillStyle = skyGrad; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.9)'; clouds.forEach(c => { ctx.beginPath(); ctx.arc(c.x, c.y, c.size, 0, Math.PI*2); ctx.arc(c.x + c.size*0.5, c.y - c.size*0.3, c.size*0.6, 0, Math.PI*2); ctx.fill(); if (gameState === 'PLAYING') { c.y += c.speed; if (c.y > canvas.height + 100) { c.y = -100; c.x = Math.random() * canvas.width; } } });
    const ladderX = canvas.width / 2; const rungSpacing = 60; const scrollOffset = (currentHeight * 8) % rungSpacing;
    ctx.strokeStyle = '#8b4513'; ctx.lineWidth = 14; ctx.beginPath(); ctx.moveTo(ladderX - 45, 0); ctx.lineTo(ladderX - 45, canvas.height); ctx.moveTo(ladderX + 45, 0); ctx.lineTo(ladderX + 45, canvas.height); ctx.stroke(); ctx.lineWidth = 8;
    for (let y = -rungSpacing; y < canvas.height + rungSpacing; y += rungSpacing) { ctx.beginPath(); ctx.moveTo(ladderX - 45, y + scrollOffset); ctx.lineTo(ladderX + 45, y + scrollOffset); ctx.stroke(); }
    ctx.save(); ctx.translate(ladderX, character.y); if (character.tumble > 0) { ctx.rotate(character.tumble * 0.15); character.tumble--; } else { character.isFalling = false; }
    ctx.fillStyle = '#f1c40f'; ctx.beginPath(); ctx.arc(0, 0, 30, 0, Math.PI*2); ctx.fill(); ctx.strokeStyle = '#000'; ctx.lineWidth = 3; ctx.stroke(); ctx.fillStyle = '#000'; ctx.beginPath(); ctx.arc(-10, -8, 5, 0, Math.PI*2); ctx.fill(); ctx.beginPath(); ctx.arc(10, -8, 5, 0, Math.PI*2); ctx.fill();
    ctx.beginPath(); if (character.isFalling) ctx.arc(0, 15, 10, Math.PI, 0, false); else ctx.arc(0, 5, 10, 0, Math.PI, false); ctx.stroke(); ctx.restore(); requestAnimationFrame(draw);
}
init(); draw();
'@

# Writing files
$packageJson | Out-File -FilePath "package.json" -Encoding utf8
$mainJs | Out-File -FilePath "main.js" -Encoding utf8
$indexHtml | Out-File -FilePath "index.html" -Encoding utf8
$gameJs | Out-File -FilePath "game.js" -Encoding utf8

Write-Host "`nScaffolding Complete! Project folder: $projectName" -ForegroundColor Green
Write-Host "----------------------------------------------------"
Write-Host "To Start Your Game:" -ForegroundColor Yellow
Write-Host "1. cd $projectName"
Write-Host "2. npm install"
Write-Host "3. npm start"
Write-Host "----------------------------------------------------"
Write-Host "Controls: SPACE to climb, M for menu, H for Simulation overlay.`n"
