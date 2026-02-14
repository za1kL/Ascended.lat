<?php
// Get the User-Agent header
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';

// Check if it's a browser (has Mozilla, Chrome, Safari, Edge, etc.)
$isBrowser = preg_match('/(Mozilla|Chrome|Safari|Edge|Opera|Firefox)/i', $userAgent);

// Your Lua script code
$luaScript = <<<'LUA'
-- Your Lua/Luau script here
print("Hello from Ascended!")

-- Example script
for i = 1, 10 do
    print("Line " .. i)
end

print("Script loaded successfully!")
LUA;

// If it's NOT a browser (like Roblox HttpGet), return raw script
if (!$isBrowser || strpos($userAgent, 'Roblox') !== false) {
    header('Content-Type: text/plain');
    echo $luaScript;
    exit;
}

// If it IS a browser, show the Access Denied page
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Access Denied</title>
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --ancient-yellow: #c9a961;
            --ancient-yellow-light: #e8d4a0;
            --ancient-yellow-dark: #a68845;
            --bg: #000000;
        }

        body {
            background: var(--bg);
            font-family: 'JetBrains Mono', monospace;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
            position: relative;
        }

        .stars {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 0;
        }

        .star {
            position: absolute;
            background: var(--ancient-yellow);
            border-radius: 50%;
            box-shadow: 0 0 8px rgba(201, 169, 97, 0.8),
                        0 0 15px rgba(232, 212, 160, 0.4);
            animation: twinkle 3s ease-in-out infinite;
        }

        .star-small { width: 2px; height: 2px; }
        .star-medium { width: 3px; height: 3px; }
        .star-large { width: 4px; height: 4px; }

        @keyframes twinkle {
            0%, 100% { opacity: 0.2; transform: scale(0.8); }
            50% { opacity: 1; transform: scale(1.2); }
        }

        #smoke-canvas {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 1;
        }

        .container {
            position: relative;
            z-index: 2;
            text-align: center;
            padding: 40px;
            background: rgba(10, 10, 10, 0.7);
            border: 2px solid rgba(201, 169, 97, 0.4);
            backdrop-filter: blur(10px);
            box-shadow: 0 0 60px rgba(201, 169, 97, 0.15),
                        inset 0 0 40px rgba(201, 169, 97, 0.05);
            animation: containerGlow 3s ease-in-out infinite;
        }

        @keyframes containerGlow {
            0%, 100% {
                box-shadow: 0 0 60px rgba(201, 169, 97, 0.15),
                            inset 0 0 40px rgba(201, 169, 97, 0.05);
            }
            50% {
                box-shadow: 0 0 80px rgba(201, 169, 97, 0.25),
                            inset 0 0 60px rgba(201, 169, 97, 0.08);
            }
        }

        h1 {
            font-size: 72px;
            font-weight: 600;
            color: var(--ancient-yellow);
            text-shadow: 0 0 20px rgba(201, 169, 97, 0.8),
                         0 0 40px rgba(232, 212, 160, 0.5);
            margin-bottom: 30px;
            letter-spacing: 8px;
            animation: titleFlicker 2s ease-in-out infinite;
        }

        @keyframes titleFlicker {
            0%, 100% {
                opacity: 1;
                text-shadow: 0 0 20px rgba(201, 169, 97, 0.8),
                             0 0 40px rgba(232, 212, 160, 0.5);
            }
            50% {
                opacity: 0.9;
                text-shadow: 0 0 30px rgba(201, 169, 97, 1),
                             0 0 60px rgba(232, 212, 160, 0.7);
            }
        }

        .subtitle {
            font-size: 18px;
            color: rgba(201, 169, 97, 0.7);
            margin-top: 20px;
            letter-spacing: 2px;
        }

        .error-code {
            font-size: 14px;
            color: rgba(166, 136, 69, 0.6);
            margin-top: 30px;
            font-weight: 500;
            letter-spacing: 3px;
        }

        .scanline {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 3px;
            background: linear-gradient(to bottom, rgba(201, 169, 97, 0.4), rgba(201, 169, 97, 0.1));
            animation: scan 4s linear infinite;
            z-index: 3;
        }

        @keyframes scan {
            0% { transform: translateY(0); }
            100% { transform: translateY(100vh); }
        }

        @media (max-width: 600px) {
            h1 { font-size: 48px; letter-spacing: 4px; }
            .container { padding: 30px 20px; margin: 0 20px; }
            .subtitle { font-size: 14px; }
            .error-code { font-size: 12px; }
        }
    </style>
</head>
<body>
    <div class="stars" id="stars"></div>
    <canvas id="smoke-canvas"></canvas>
    <div class="scanline"></div>

    <div class="container">
        <h1>ACCESS DENIED</h1>
        <div class="subtitle">You do not have permission to view this resource.</div>
        <div class="error-code">ERROR CODE: 403_FORBIDDEN</div>
    </div>

    <script>
        const starsContainer = document.getElementById('stars');
        const starSizes = ['star-small', 'star-medium', 'star-large'];
        
        for (let i = 0; i < 150; i++) {
            const star = document.createElement('div');
            star.className = 'star ' + starSizes[Math.floor(Math.random() * starSizes.length)];
            star.style.left = Math.random() * 100 + '%';
            star.style.top = Math.random() * 100 + '%';
            star.style.animationDelay = Math.random() * 3 + 's';
            star.style.animationDuration = (Math.random() * 2 + 2) + 's';
            starsContainer.appendChild(star);
        }

        const canvas = document.getElementById('smoke-canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;

        class FogParticle {
            constructor() { this.reset(); }
            reset() {
                this.x = Math.random() * canvas.width;
                this.y = canvas.height + 100;
                this.maxSize = Math.random() * 300 + 200;
                this.size = 0;
                this.speedY = Math.random() * 0.3 + 0.1;
                this.speedX = (Math.random() - 0.5) * 0.2;
                this.maxOpacity = Math.random() * 0.08 + 0.04;
                this.life = 0;
                this.maxLife = Math.random() * 600 + 400;
                this.peakLife = this.maxLife * 0.5;
            }
            update() {
                this.y -= this.speedY;
                this.x += this.speedX;
                this.life++;
                if (this.life < this.peakLife) {
                    const growRatio = this.life / this.peakLife;
                    this.size = this.maxSize * growRatio;
                    this.opacity = this.maxOpacity * growRatio;
                } else {
                    const shrinkRatio = (this.maxLife - this.life) / (this.maxLife - this.peakLife);
                    this.size = this.maxSize * shrinkRatio;
                    this.opacity = this.maxOpacity * shrinkRatio;
                }
                if (this.life > this.maxLife || this.y < -this.maxSize) this.reset();
            }
            draw() {
                const gradient = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, this.size);
                gradient.addColorStop(0, `rgba(201, 169, 97, ${this.opacity})`);
                gradient.addColorStop(0.3, `rgba(232, 212, 160, ${this.opacity * 0.8})`);
                gradient.addColorStop(0.6, `rgba(166, 136, 69, ${this.opacity * 0.5})`);
                gradient.addColorStop(1, 'rgba(201, 169, 97, 0)');
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        const fogParticles = [];
        for (let i = 0; i < 60; i++) fogParticles.push(new FogParticle());

        function animateFog() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            fogParticles.forEach(p => { p.update(); p.draw(); });
            requestAnimationFrame(animateFog);
        }
        animateFog();

        window.addEventListener('resize', () => {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
        });
    </script>
</body>
</html>
