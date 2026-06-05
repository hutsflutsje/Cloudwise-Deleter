# Interactive Ladder Game Scaffolding Script
# This script creates the directory structure and files for the Electron game.

$projectName = "interactive-ladder-game"
New-Item -ItemType Directory -Path $projectName -Force
Set-Location -Path $projectName

# 1. package.json
$packageJson = @'
{
  "name": "interactive-ladder-game",
  "version": "1.0.0",
  "description": "TikTok Live Interactive Ladder Game",
  "main": "main.js",
  "scripts": {
    "start": "electron ."
  },
  "dependencies": {
    "ws": "^8.13.0"
  },
  "devDependencies": {
    "electron": "^25.0.0",
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
    width: 450,
    height: 800,
    transparent: true,
    frame: false,
    alwaysOnTop: true,
    resizable: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');

  // Set aspect ratio to 9:16
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
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="game-container">
        <canvas id="gameCanvas"></canvas>

        <div id="hud">
            <div id="height-display">0m</div>
            <div id="target-display">1000m = win</div>
        </div>

        <div id="gift-tracker">
            Gifts: <span id="gift-count">0</span>/10
        </div>

        <div id="sim-overlay" class="hidden">
            <h3>Simulation Overlay</h3>
            <button onclick="simulateEvent('like')">Simulate Like</button>
            <button onclick="simulateEvent('gift')">Simulate Gift</button>
            <p>Press 'H' to toggle</p>
        </div>
    </div>
    <script src="game.js"></script>
</body>
</html>
'@

# 4. style.css
$styleCss = @'
body {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: transparent;
    font-family: 'Comic Sans MS', 'Arial Rounded MT Bold', Helvetica, sans-serif;
}

#game-container {
    position: relative;
    width: 100vw;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    background: #1a2a6c;
}

canvas {
    background: #1a2a6c;
    box-shadow: 0 0 20px rgba(0,0,0,0.5);
}

#hud {
    position: absolute;
    top: 20px;
    width: 100%;
    text-align: center;
    color: white;
    text-shadow: -2px -2px 0 #000, 2px -2px 0 #000, -2px 2px 0 #000, 2px 2px 0 #000;
    pointer-events: none;
}

#height-display {
    font-size: 3rem;
    font-weight: bold;
}

#target-display {
    font-size: 1.2rem;
}

#gift-tracker {
    position: absolute;
    bottom: 30px;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(0, 100, 255, 0.8);
    padding: 10px 20px;
    border-radius: 25px;
    color: white;
    font-weight: bold;
    border: 2px solid white;
    box-shadow: 0 4px 10px rgba(0,0,0,0.3);
}

#sim-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(0, 0, 0, 0.8);
    color: white;
    padding: 20px;
    border-radius: 10px;
    text-align: center;
    z-index: 100;
}

#sim-overlay.hidden {
    display: none;
}

#sim-overlay button {
    display: block;
    width: 100%;
    margin: 10px 0;
    padding: 10px;
    cursor: pointer;
    background: #f39c12;
    border: none;
    border-radius: 5px;
    font-weight: bold;
}

#sim-overlay button:hover {
    background: #e67e22;
}
'@

# 5. game.js
$gameJs = @'
const WebSocket = require('ws');

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const heightDisplay = document.getElementById('height-display');
const giftCountDisplay = document.getElementById('gift-count');
const simOverlay = document.getElementById('sim-overlay');

let width, height;
let ladderX;
let characterY;
let climbSpeed = 0.5;
let currentHeight = 0;
let giftCount = 0;
let clouds = [];
let isTumbling = false;
let tumbleTimer = 0;

function resize() {
    const windowRatio = window.innerWidth / window.innerHeight;
    const targetRatio = 9 / 16;

    if (windowRatio > targetRatio) {
        height = window.innerHeight;
        width = height * targetRatio;
    } else {
        width = window.innerWidth;
        height = width / targetRatio;
    }

    canvas.width = width;
    canvas.height = height;
    ladderX = width / 2;
    characterY = height * 0.7;

    if (clouds.length === 0) {
        for (let i = 0; i < 5; i++) {
            clouds.push({
                x: Math.random() * width,
                y: Math.random() * height,
                size: 30 + Math.random() * 50,
                speed: 0.2 + Math.random() * 0.5
            });
        }
    }
}

window.addEventListener('resize', resize);
resize();

function drawCharacter(x, y, scale = 1) {
    ctx.save();
    ctx.translate(x, y);
    if (isTumbling) {
        ctx.rotate(tumbleTimer * 0.2);
    }

    ctx.fillStyle = '#ffdb4d';
    ctx.beginPath();
    ctx.arc(0, 0, 20 * scale, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = '#000';
    ctx.beginPath();
    ctx.arc(-7 * scale, -5 * scale, 3 * scale, 0, Math.PI * 2);
    ctx.arc(7 * scale, -5 * scale, 3 * scale, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    if (isTumbling) {
        ctx.arc(0, 10 * scale, 5 * scale, Math.PI, 0, false);
    } else {
        ctx.arc(0, 5 * scale, 5 * scale, 0, Math.PI, false);
    }
    ctx.stroke();

    ctx.restore();
}

function drawLadder() {
    const ladderWidth = 60;
    const rungSpacing = 40;
    const scrollOffset = (currentHeight * 5) % rungSpacing;

    ctx.strokeStyle = '#8b4513';
    ctx.lineWidth = 8;

    ctx.beginPath();
    ctx.moveTo(ladderX - ladderWidth/2, 0);
    ctx.lineTo(ladderX - ladderWidth/2, height);
    ctx.moveTo(ladderX + ladderWidth/2, 0);
    ctx.lineTo(ladderX + ladderWidth/2, height);
    ctx.stroke();

    ctx.lineWidth = 4;
    for (let y = -rungSpacing; y < height + rungSpacing; y += rungSpacing) {
        ctx.beginPath();
        ctx.moveTo(ladderX - ladderWidth/2, y + scrollOffset);
        ctx.lineTo(ladderX + ladderWidth/2, y + scrollOffset);
        ctx.stroke();
    }
}

function drawBackground() {
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#4facfe');
    gradient.addColorStop(1, '#00f2fe');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    ctx.fillStyle = 'white';
    clouds.forEach(cloud => {
        ctx.beginPath();
        ctx.arc(cloud.x, cloud.y, cloud.size, 0, Math.PI * 2);
        ctx.arc(cloud.x + cloud.size * 0.5, cloud.y - cloud.size * 0.3, cloud.size * 0.6, 0, Math.PI * 2);
        ctx.arc(cloud.x + cloud.size, cloud.y, cloud.size * 0.8, 0, Math.PI * 2);
        ctx.fill();

        cloud.y += cloud.speed + climbSpeed;
        if (cloud.y > height + 100) {
            cloud.y = -100;
            cloud.x = Math.random() * width;
        }
    });
}

function update() {
    if (isTumbling) {
        tumbleTimer++;
        currentHeight -= 2;
        if (currentHeight < 0) currentHeight = 0;
        if (tumbleTimer > 60) {
            isTumbling = false;
            tumbleTimer = 0;
        }
    } else {
        currentHeight += climbSpeed / 10;
    }

    heightDisplay.textContent = Math.floor(currentHeight) + 'm';
    giftCountDisplay.textContent = giftCount;
}

function draw() {
    ctx.clearRect(0, 0, width, height);
    drawBackground();
    drawLadder();
    drawCharacter(ladderX, characterY);

    requestAnimationFrame(() => {
        update();
        draw();
    });
}

const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            handleEvent(data);
        } catch (e) {
            console.error('Invalid JSON', e);
        }
    });
});

function handleEvent(data) {
    if (data.event === 'like') {
        currentHeight += 5;
    } else if (data.event === 'gift') {
        giftCount++;
        isTumbling = true;
        tumbleTimer = 0;
        const loss = data.value || 10;
        currentHeight -= loss;
        if (currentHeight < 0) currentHeight = 0;
    }
}

window.simulateEvent = function(type) {
    if (type === 'like') {
        handleEvent({ event: 'like' });
    } else if (type === 'gift') {
        handleEvent({ event: 'gift', value: 15 });
    }
};

window.addEventListener('keydown', (e) => {
    if (e.key.toLowerCase() === 'h') {
        simOverlay.classList.toggle('hidden');
    }
});

draw();
'@

# Writing files
$packageJson | Out-File -FilePath "package.json" -Encoding utf8
$mainJs | Out-File -FilePath "main.js" -Encoding utf8
$indexHtml | Out-File -FilePath "index.html" -Encoding utf8
$styleCss | Out-File -FilePath "style.css" -Encoding utf8
$gameJs | Out-File -FilePath "game.js" -Encoding utf8

Write-Host "Scaffolding complete!" -ForegroundColor Green
Write-Host "To run the game:"
Write-Host "1. cd $projectName"
Write-Host "2. npm install"
Write-Host "3. npm start"
