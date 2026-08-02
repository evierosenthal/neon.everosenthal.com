/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 *
 * Neon Nebula — canvas game engine (plain ES5+/ES6 JavaScript, no build step).
 * Port of the original GameCanvas React component.
 */

(function (global) {
  'use strict';

  var PLAYER_RADIUS = 15;
  var ASTEROID_MIN_RADIUS = 10;
  var ASTEROID_MAX_RADIUS = 30;
  var SPAWN_RATE = 0.03; // Base spawn rate; scaled by difficulty squared
  var STAR_COUNT = 50;

  var MOVE_KEYS = [
    'w', 'a', 's', 'd', 'W', 'A', 'S', 'D', 'KeyW', 'KeyA', 'KeyS', 'KeyD',
    'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight', 'Up', 'Left', 'Down', 'Right'
  ];

  var PREVENT_DEFAULT_KEYS = [
    'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', ' ', 'Up', 'Down', 'Left', 'Right'
  ];

  function randomId() {
    return Math.random().toString(36);
  }

  function createGame(canvas, callbacks) {
    var ctx = canvas.getContext('2d');

    var handlers = {
      onGameOver: (callbacks && callbacks.onGameOver) || function () {},
      onScoreUpdate: (callbacks && callbacks.onScoreUpdate) || function () {},
      onHealthUpdate: (callbacks && callbacks.onHealthUpdate) || function () {},
      onDifficultyUpdate: (callbacks && callbacks.onDifficultyUpdate) || function () {}
    };

    var config = {
      initialDifficulty: 1,
      isLocalMultiplayer: false,
      isCPUMultiplayer: false,
      controlModePreference: 'both'
    };

    var state = null;
    var keysPressed = {};
    var controlMode = 'mouse';
    var lastShotTime = 0;
    var lastShotTime2 = 0;
    var mousePos = { x: 0, y: 0 };
    var shake = 0;
    var animationId = 0;
    var stars = [];
    var mountTime = 0;
    var isPaused = false;
    var running = false;

    // --- Entity factories -------------------------------------------------

    function createParticle(x, y, color, isThruster) {
      var angle = Math.random() * Math.PI * 2;
      var speed = isThruster ? (Math.random() * 2 + 1) : (Math.random() * 3 + 1);
      var life = isThruster ? (8 + Math.random() * 8) : (20 + Math.random() * 10);
      return {
        id: randomId(),
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: isThruster ? (Math.random() * 2 + 1) : (Math.random() * 2.5 + 1),
        color: color,
        type: 'particle',
        life: life,
        maxLife: life
      };
    }

    function createCollectible(width, height) {
      return {
        id: randomId(),
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 1,
        vy: (Math.random() - 0.5) * 1,
        radius: 9,
        color: '#fbbf24', // Amber
        type: 'collectible'
      };
    }

    function createProjectile(x, y, angle, color) {
      var speed = 10;
      return {
        id: randomId(),
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: 4,
        color: color || '#00ffff',
        type: 'projectile',
        life: 100
      };
    }

    function createPowerUp(width, height, difficulty) {
      // Magnet is rare (~6% chance) and ONLY spawns in Medium mode (difficulty >= 0.6),
      // Hard mode, and Super Hard mode.
      var isMediumOrHigher = difficulty >= 0.6;
      var rand = Math.random();
      var type;
      if (isMediumOrHigher && rand < 0.06) {
        type = 'magnet';
      } else {
        var others = ['shield', 'speed', 'weapon'];
        type = others[Math.floor(Math.random() * others.length)];
      }
      var colors = { shield: '#a855f7', speed: '#22c55e', weapon: '#ef4444', magnet: '#c084fc' };

      return {
        id: randomId(),
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        radius: 12,
        color: colors[type],
        type: 'powerup',
        life: 1200, // 20 seconds at 60fps
        maxLife: 1200,
        subType: type
      };
    }

    function addFloatingText(x, y, text, color, scale) {
      state.floatingTexts.push({
        id: randomId(),
        x: x,
        y: y,
        text: text,
        color: color || '#ffffff',
        alpha: 1.0,
        life: 60,
        scale: scale === undefined ? 1.0 : scale
      });
    }

    function createShockwaveRing(x, y, color, count) {
      count = count || 8;
      for (var i = 0; i < count; i++) {
        var angle = (i / count) * Math.PI * 2;
        var speed = 3.0;
        var life = 18 + Math.random() * 10;
        state.particles.push({
          id: randomId(),
          x: x,
          y: y,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          radius: 2.5,
          color: color,
          type: 'particle',
          life: life,
          maxLife: life
        });
      }
    }

    function createAsteroid(width, height, difficulty) {
      var side = Math.floor(Math.random() * 4);
      var x = 0;
      var y = 0;
      if (side === 0) { x = Math.random() * width; y = -50; }
      else if (side === 1) { x = width + 50; y = Math.random() * height; }
      else if (side === 2) { x = Math.random() * width; y = height + 50; }
      else { x = -50; y = Math.random() * height; }

      var targetX = width / 2 + (Math.random() - 0.5) * width;
      var targetY = height / 2 + (Math.random() - 0.5) * height;
      var angle = Math.atan2(targetY - y, targetX - x) + (Math.random() - 0.5) * 0.2;
      var superHardSpeedBoost = difficulty >= 4.0 ? 2.5 : 1.0;
      // Medium-tier band gets a small speed-only boost (spawn rate unchanged),
      // keeping asteroid speed clearly above Easy but still below Hard's start.
      var mediumSpeedBoost = (difficulty >= 0.6 && difficulty < 1.2) ? 1.12 : 1.0;
      var speed = (Math.random() * 2.5 + 2.0) * difficulty * superHardSpeedBoost * mediumSpeedBoost;

      var vertexCount = 8 + Math.floor(Math.random() * 5);
      var vertices = [];
      for (var i = 0; i < vertexCount; i++) {
        vertices.push(0.85 + Math.random() * 0.3);
      }

      var craterCount = 2 + Math.floor(Math.random() * 2);
      var craters = [];
      for (var j = 0; j < craterCount; j++) {
        craters.push({
          rx: (Math.random() - 0.5) * 0.5,
          ry: (Math.random() - 0.5) * 0.5,
          r: 0.12 + Math.random() * 0.12
        });
      }

      return {
        id: randomId(),
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: ASTEROID_MIN_RADIUS + Math.random() * (ASTEROID_MAX_RADIUS - ASTEROID_MIN_RADIUS),
        color: 'hsl(' + (280 + Math.random() * 40) + ', 70%, 50%)', // Purples/Magentas
        type: 'asteroid',
        vertices: vertices,
        craters: craters,
        rotation: Math.random() * Math.PI * 2,
        spinSpeed: (Math.random() - 0.5) * 0.03
      };
    }

    function createPlayer(id, x, y, color) {
      return {
        id: id,
        x: x,
        y: y,
        vx: 0,
        vy: 0,
        radius: PLAYER_RADIUS,
        color: color,
        type: 'player'
      };
    }

    // --- Setup ------------------------------------------------------------

    function resizeCanvas() {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    }

    function reset() {
      var hasPlayer2 = config.isLocalMultiplayer || config.isCPUMultiplayer;
      var w = window.innerWidth;
      var h = window.innerHeight;

      state = {
        player: createPlayer('player1', w / (hasPlayer2 ? 3 : 2), h / 2, '#00ffff'),
        player2: hasPlayer2 ? createPlayer('player2', (w / 3) * 2, h / 2, '#fb7185') : null,
        asteroids: [],
        particles: [],
        collectibles: [],
        projectiles: [],
        powerUps: [],
        enemies: [],
        floatingTexts: [],
        score: 0,
        health: 100,
        isGameOver: false,
        difficulty: config.initialDifficulty,
        activeEffects: {
          shield: 0,
          speedBoost: 0,
          weaponUpgrade: 0,
          magnet: 0
        }
      };

      mousePos = { x: w / 2, y: h / 2 };

      // Spawn initial 'W' weapon power-up so player can grab it to enable shooting right away
      state.powerUps.push({
        id: 'initial_weapon',
        x: w / 2,
        y: h / 3,
        vx: (Math.random() - 0.5) * 1.5,
        vy: (Math.random() - 0.5) * 1.5,
        radius: 12,
        color: '#ef4444',
        type: 'powerup',
        life: 1800,
        maxLife: 1800,
        subType: 'weapon'
      });

      stars = [];
      for (var i = 0; i < STAR_COUNT; i++) {
        stars.push({
          x: Math.random() * w,
          y: Math.random() * h,
          s: Math.random() * 2 + 0.5
        });
      }

      keysPressed = {};
      controlMode = 'mouse';
      lastShotTime = 0;
      lastShotTime2 = 0;
      shake = 0;
      mountTime = Date.now();
    }

    // --- Update -----------------------------------------------------------

    function updatePlayer1(accel, friction, moveSpeed) {
      var player = state.player;
      var userControlMode = config.controlModePreference || 'both';

      if (config.isLocalMultiplayer) {
        // Local 2P mode: Player 1 uses WASD keyboard controls (so Player 2 can use Arrow keys)
        if (keysPressed['KeyW'] || keysPressed['w'] || keysPressed['W']) player.vy -= accel;
        if (keysPressed['KeyS'] || keysPressed['s'] || keysPressed['S']) player.vy += accel;
        if (keysPressed['KeyA'] || keysPressed['a'] || keysPressed['A']) player.vx -= accel;
        if (keysPressed['KeyD'] || keysPressed['d'] || keysPressed['D']) player.vx += accel;

        player.vx *= friction;
        player.vy *= friction;

        var speed1 = Math.sqrt(player.vx * player.vx + player.vy * player.vy);
        if (speed1 > moveSpeed) {
          player.vx = (player.vx / speed1) * moveSpeed;
          player.vy = (player.vy / speed1) * moveSpeed;
        }

        player.x += player.vx;
        player.y += player.vy;
        return;
      }

      // Single Player / CPU mode: obey controlModePreference ('mouse', 'keyboard', or 'both').
      // In 'both', whichever device was used last owns the ship: pressing a move
      // key hands control to the keyboard (suspending the mouse-follow so it
      // can't drag the ship back toward a stationary cursor), and moving the
      // mouse hands control back.
      var mouseDrives = userControlMode === 'mouse' ||
        (userControlMode === 'both' && controlMode === 'mouse');
      var keyboardDrives = userControlMode === 'keyboard' ||
        (userControlMode === 'both' && controlMode === 'keyboard');

      // Mouse Follow Component
      if (mouseDrives) {
        var followSpeed = state.activeEffects.speedBoost > 0 ? 0.15 : 0.08;
        var prevX = player.x;
        var prevY = player.y;
        player.x += (mousePos.x - player.x) * followSpeed;
        player.y += (mousePos.y - player.y) * followSpeed;
        player.vx = player.x - prevX;
        player.vy = player.y - prevY;
      }

      // Keyboard Component
      if (keyboardDrives) {
        if (keysPressed['KeyW'] || keysPressed['w'] || keysPressed['W'] || keysPressed['ArrowUp'] || keysPressed['Up']) {
          player.vy -= accel;
        }
        if (keysPressed['KeyS'] || keysPressed['s'] || keysPressed['S'] || keysPressed['ArrowDown'] || keysPressed['Down']) {
          player.vy += accel;
        }
        if (keysPressed['KeyA'] || keysPressed['a'] || keysPressed['A'] || keysPressed['ArrowLeft'] || keysPressed['Left']) {
          player.vx -= accel;
        }
        if (keysPressed['KeyD'] || keysPressed['d'] || keysPressed['D'] || keysPressed['ArrowRight'] || keysPressed['Right']) {
          player.vx += accel;
        }
        player.vx *= friction;
        player.vy *= friction;
        var kbSpeed = Math.sqrt(player.vx * player.vx + player.vy * player.vy);
        if (kbSpeed > moveSpeed) {
          player.vx = (player.vx / kbSpeed) * moveSpeed;
          player.vy = (player.vy / kbSpeed) * moveSpeed;
        }
        player.x += player.vx;
        player.y += player.vy;
      }

      // Clamp Player 1 within screen boundaries
      player.x = Math.max(player.radius, Math.min(canvas.width - player.radius, player.x));
      player.y = Math.max(player.radius, Math.min(canvas.height - player.radius, player.y));
    }

    function updatePlayer2(accel, friction, moveSpeed) {
      var p2 = state.player2;
      if (!p2) return;

      if (config.isLocalMultiplayer) {
        // Arrow Controls for Player 2 (Local Co-op ONLY)
        if (keysPressed['ArrowUp'] || keysPressed['Up']) p2.vy -= accel;
        if (keysPressed['ArrowDown'] || keysPressed['Down']) p2.vy += accel;
        if (keysPressed['ArrowLeft'] || keysPressed['Left']) p2.vx -= accel;
        if (keysPressed['ArrowRight'] || keysPressed['Right']) p2.vx += accel;

        p2.vx *= friction;
        p2.vy *= friction;

        var speed2 = Math.sqrt(p2.vx * p2.vx + p2.vy * p2.vy);
        if (speed2 > moveSpeed) {
          p2.vx = (p2.vx / speed2) * moveSpeed;
          p2.vy = (p2.vy / speed2) * moveSpeed;
        }

        p2.x += p2.vx;
        p2.y += p2.vy;
        return;
      }

      if (!config.isCPUMultiplayer) return;

      // CPU Wingman AI Controls
      var targetAsteroid = null;
      var minDistAsteroid = Infinity;
      for (var i = 0; i < state.asteroids.length; i++) {
        var ast = state.asteroids[i];
        var adx = ast.x - p2.x;
        var ady = ast.y - p2.y;
        var adist = Math.sqrt(adx * adx + ady * ady);
        if (adist < minDistAsteroid) {
          minDistAsteroid = adist;
          targetAsteroid = ast;
        }
      }

      var targetCollectible = null;
      var minDistCollectible = Infinity;
      var pickups = state.collectibles.concat(state.powerUps);
      for (var j = 0; j < pickups.length; j++) {
        var coll = pickups[j];
        var cdx = coll.x - p2.x;
        var cdy = coll.y - p2.y;
        var cdist = Math.sqrt(cdx * cdx + cdy * cdy);
        if (cdist < minDistCollectible) {
          minDistCollectible = cdist;
          targetCollectible = coll;
        }
      }

      // Determine AI steering vectors
      var desiredVx = 0;
      var desiredVy = 0;

      // Threat Mitigation: Evade nearby asteroids (distance threshold < 220)
      if (targetAsteroid && minDistAsteroid < 220) {
        var dx = p2.x - targetAsteroid.x;
        var dy = p2.y - targetAsteroid.y;

        if (Math.abs(dx) < 65) {
          // Asteroid is coming right at us. Sidestep horizontally
          desiredVx = dx > 0 ? moveSpeed : -moveSpeed;
        } else {
          desiredVx = Math.sign(dx) * moveSpeed;
        }

        if (minDistAsteroid < 110) {
          // Extremum evasive vertical push
          desiredVy = Math.sign(dy) * moveSpeed;
        } else {
          // Smoothly target the lower center combat sector
          desiredVy = (canvas.height * 0.75 - p2.y) * 0.05;
        }
      } else if (targetCollectible && minDistCollectible < 400) {
        // Resource Collection: Harvest active gold or powerups
        desiredVx = Math.sign(targetCollectible.x - p2.x) * moveSpeed * 0.85;
        desiredVy = Math.sign(targetCollectible.y - p2.y) * moveSpeed * 0.85;
      } else {
        // Co-pilot Formation Layer: Hover comfortably in visual range of Player 1
        var formationX = state.player.x + (p2.x > state.player.x ? 150 : -150);
        desiredVx = (formationX - p2.x) * 0.04;
        desiredVy = (canvas.height * 0.75 - p2.y) * 0.04;
      }

      // Accelerate with smooth interpolation
      p2.vx += (desiredVx - p2.vx) * 0.12;
      p2.vy += (desiredVy - p2.vy) * 0.12;

      p2.vx *= friction;
      p2.vy *= friction;

      var cpuSpeed = Math.sqrt(p2.vx * p2.vx + p2.vy * p2.vy);
      if (cpuSpeed > moveSpeed) {
        p2.vx = (p2.vx / cpuSpeed) * moveSpeed;
        p2.vy = (p2.vy / cpuSpeed) * moveSpeed;
      }

      p2.x += p2.vx;
      p2.y += p2.vy;
    }

    function updateShooting() {
      var now = Date.now();
      var fireRate = state.activeEffects.speedBoost > 0 ? 150 : 300;
      var angle = -Math.PI / 2;

      // Player 1 Shooting (Requires collecting 'W' Weapon power-up)
      if (state.activeEffects.weaponUpgrade > 0 && now - lastShotTime > fireRate) {
        lastShotTime = now;
        var p = state.player;
        if (state.activeEffects.weaponUpgrade > 1000) {
          state.projectiles.push(createProjectile(p.x - 10, p.y, angle));
          state.projectiles.push(createProjectile(p.x + 10, p.y, angle));
          state.projectiles.push(createProjectile(p.x, p.y, angle - 0.15));
          state.projectiles.push(createProjectile(p.x, p.y, angle + 0.15));
        } else {
          state.projectiles.push(createProjectile(p.x - 10, p.y, angle));
          state.projectiles.push(createProjectile(p.x + 10, p.y, angle));
        }
      }

      // Player 2 Shooting (Requires collecting 'W' Weapon power-up)
      if (state.player2 && state.activeEffects.weaponUpgrade > 0 && now - lastShotTime2 > fireRate) {
        lastShotTime2 = now;
        var p2 = state.player2;
        if (state.activeEffects.weaponUpgrade > 1000) {
          state.projectiles.push(createProjectile(p2.x - 10, p2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(p2.x + 10, p2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(p2.x, p2.y, angle - 0.15, '#fb7185'));
          state.projectiles.push(createProjectile(p2.x, p2.y, angle + 0.15, '#fb7185'));
        } else {
          state.projectiles.push(createProjectile(p2.x - 10, p2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(p2.x + 10, p2.y, angle, '#fb7185'));
        }
      }
    }

    function updateDifficulty() {
      // Difficulty increases gradually over time and with score up to mode-appropriate caps
      var initDiff = config.initialDifficulty;
      var maxDiffCap;
      if (initDiff >= 5.0) {
        maxDiffCap = 8.0; // Super Hard mode cap
      } else if (initDiff >= 1.0) {
        // Hard mode cap (gets significantly harder, but stays well below Super Hard's 6.0)
        maxDiffCap = 2.8;
      } else if (initDiff >= 0.6) {
        maxDiffCap = 1.1; // Medium mode cap (stays below Hard's 1.2 start)
      } else {
        maxDiffCap = 0.85; // Easy mode cap (reaches start of Medium mode)
      }

      var baseGrowthRate = 0.00008;
      var scoreGrowthRate = (state.score / 25000) * 0.00004;
      var totalGrowth = baseGrowthRate + scoreGrowthRate;

      if (state.difficulty < maxDiffCap) {
        state.difficulty = Math.min(maxDiffCap, state.difficulty + totalGrowth);
      }
      handlers.onDifficultyUpdate(state.difficulty);
    }

    function updateSpawns() {
      // Spawn asteroids. The medium-tier band gets a small density boost so it
      // clearly outnumbers Easy while staying below Hard's starting density.
      var mediumSpawnBoost = (state.difficulty >= 0.6 && state.difficulty < 1.2) ? 1.3 : 1.0;
      var spawnChance = SPAWN_RATE * Math.pow(state.difficulty, 2) * mediumSpawnBoost;
      while (spawnChance > 0) {
        if (Math.random() < Math.min(1, spawnChance)) {
          state.asteroids.push(createAsteroid(canvas.width, canvas.height, state.difficulty));
        }
        spawnChance -= 1;
      }

      // Spawn collectibles
      if (state.collectibles.length < 12 && Math.random() < 0.02 / Math.sqrt(state.difficulty)) {
        state.collectibles.push(createCollectible(canvas.width, canvas.height));
      }

      // Spawn power-ups (Easy Mode gets most power-ups, Medium slightly less, Hard less than Medium)
      var powerUpChance = 0.010; // Easy Mode (~0.3 difficulty)
      var maxPowerUps = 3;
      if (state.difficulty >= 5.0) {
        powerUpChance = 0.001; // Super Hard Mode (~6.0 difficulty)
        maxPowerUps = 2;
      } else if (state.difficulty >= 1.0) {
        powerUpChance = 0.0028; // Hard Mode (~1.2 difficulty)
        maxPowerUps = 2;
      } else if (state.difficulty >= 0.6) {
        powerUpChance = 0.0045; // Medium Mode (~0.85 difficulty)
        maxPowerUps = 2;
      }

      if (state.powerUps.length < maxPowerUps && Math.random() < powerUpChance) {
        state.powerUps.push(createPowerUp(canvas.width, canvas.height, state.difficulty));
      }
    }

    function updatePowerUps() {
      for (var i = state.powerUps.length - 1; i >= 0; i--) {
        var pu = state.powerUps[i];
        pu.x += pu.vx;
        pu.y += pu.vy;

        if (pu.life !== undefined) {
          pu.life -= 1;
          if (pu.life <= 0) {
            state.powerUps.splice(i, 1);
            continue;
          }
        }

        if (pu.x < 0 || pu.x > canvas.width) pu.vx *= -1;
        if (pu.y < 0 || pu.y > canvas.height) pu.vy *= -1;

        var collected = false;
        var players = [state.player, state.player2];
        for (var k = 0; k < players.length; k++) {
          var p = players[k];
          if (!p) continue;
          var dx = p.x - pu.x;
          var dy = p.y - pu.y;
          var dist = Math.sqrt(dx * dx + dy * dy);

          // Expanded pickup radius (+12px) for smooth collection without pixel precision frustration
          if (dist < pu.radius + p.radius + 12) {
            var type = pu.subType;
            var label = 'POWER-UP GRABBED';
            if (type === 'shield') {
              state.activeEffects.shield = Math.min(1000, state.activeEffects.shield + 500);
              label = 'DEFLECTOR SHIELD ACTIVE';
            } else if (type === 'speed') {
              state.activeEffects.speedBoost = Math.min(1000, state.activeEffects.speedBoost + 500);
              label = 'OVERTHRUSTERS BOOTED';
            } else if (type === 'weapon') {
              state.activeEffects.weaponUpgrade = Math.min(2000, state.activeEffects.weaponUpgrade + 1000);
              label = state.activeEffects.weaponUpgrade > 1000 ? 'PLASMA OVERDRIVE INITIATED' : 'TWIN BLASTER PROTOCOL';
            } else if (type === 'magnet') {
              state.activeEffects.magnet = Math.min(600, state.activeEffects.magnet + 600);
              label = 'MAGNET FIELD ACTIVATED!';
            }

            addFloatingText(pu.x, pu.y, label, pu.color, 1.2);
            createShockwaveRing(pu.x, pu.y, pu.color, 24);
            for (var n = 0; n < 10; n++) state.particles.push(createParticle(pu.x, pu.y, pu.color));
            collected = true;
            break;
          }
        }

        if (collected) {
          state.powerUps.splice(i, 1);
        }
      }
    }

    function updateCollectibles() {
      for (var i = state.collectibles.length - 1; i >= 0; i--) {
        var c = state.collectibles[i];

        // Magnetic pull when magnet power-up is active
        if (state.activeEffects.magnet > 0) {
          var closestPlayer = null;
          var minDist = Infinity;
          var candidates = [state.player, state.player2];
          for (var m = 0; m < candidates.length; m++) {
            var cp = candidates[m];
            if (!cp) continue;
            var mdx = cp.x - c.x;
            var mdy = cp.y - c.y;
            var mdist = Math.sqrt(mdx * mdx + mdy * mdy);
            if (mdist < minDist) {
              minDist = mdist;
              closestPlayer = cp;
            }
          }
          if (closestPlayer && minDist < 500) {
            // Magnetic suction force towards player
            c.vx += ((closestPlayer.x - c.x) / minDist) * 0.95;
            c.vy += ((closestPlayer.y - c.y) / minDist) * 0.95;
            var coinSpeed = Math.sqrt(c.vx * c.vx + c.vy * c.vy);
            if (coinSpeed > 10) {
              c.vx = (c.vx / coinSpeed) * 10;
              c.vy = (c.vy / coinSpeed) * 10;
            }
          }
        }

        c.x += c.vx;
        c.y += c.vy;

        if (c.x < 0 || c.x > canvas.width) c.vx *= -1;
        if (c.y < 0 || c.y > canvas.height) c.vy *= -1;

        var collected = false;
        var players = [state.player, state.player2];
        for (var k = 0; k < players.length; k++) {
          var p = players[k];
          if (!p) continue;
          var dx = p.x - c.x;
          var dy = p.y - c.y;
          var distance = Math.sqrt(dx * dx + dy * dy);

          // Expanded pickup radius (+10px) for smooth collection without pixel precision frustration
          if (distance < c.radius + p.radius + 10) {
            state.score += 100;
            var healAmount = (config.isLocalMultiplayer || config.isCPUMultiplayer) ? 7 : 5;
            state.health = Math.min(100, state.health + healAmount);
            handlers.onScoreUpdate(state.score);
            handlers.onHealthUpdate(state.health);
            addFloatingText(c.x, c.y, '+100', '#fbbf24', 0.95);
            createShockwaveRing(c.x, c.y, c.color, 10);
            for (var n = 0; n < 4; n++) state.particles.push(createParticle(c.x, c.y, c.color));
            collected = true;
            break;
          }
        }

        if (collected) {
          state.collectibles.splice(i, 1);
        }
      }
    }

    function updateAsteroids() {
      for (var i = state.asteroids.length - 1; i >= 0; i--) {
        var asteroid = state.asteroids[i];
        asteroid.x += asteroid.vx;
        asteroid.y += asteroid.vy;
        asteroid.rotation += asteroid.spinSpeed;

        var asteroidDestroyed = false;

        // Check collision with projectile
        for (var j = state.projectiles.length - 1; j >= 0; j--) {
          var proj = state.projectiles[j];
          var pdx = asteroid.x - proj.x;
          var pdy = asteroid.y - proj.y;
          var pdist = Math.sqrt(pdx * pdx + pdy * pdy);
          if (pdist < asteroid.radius + proj.radius) {
            state.score += 20;
            handlers.onScoreUpdate(state.score);
            addFloatingText(asteroid.x, asteroid.y, '+20', asteroid.color, 0.8);
            createShockwaveRing(asteroid.x, asteroid.y, asteroid.color, 12);
            for (var k = 0; k < 6; k++) state.particles.push(createParticle(proj.x, proj.y, asteroid.color));

            state.projectiles.splice(j, 1);
            asteroidDestroyed = true;
            break;
          }
        }

        if (asteroidDestroyed) {
          state.asteroids.splice(i, 1);
          continue;
        }

        // Check collision with player
        var players = [state.player, state.player2];
        for (var q = 0; q < players.length; q++) {
          var p = players[q];
          if (!p) continue;
          var dx = asteroid.x - p.x;
          var dy = asteroid.y - p.y;
          var distance = Math.sqrt(dx * dx + dy * dy);

          if (distance < asteroid.radius + p.radius) {
            if (state.activeEffects.speedBoost > 0) {
              // Ram asteroids aside while overthrusters are hot
              var nx = dx / distance;
              var ny = dy / distance;
              var dot = asteroid.vx * nx + asteroid.vy * ny;
              asteroid.vx = (asteroid.vx - 2 * dot * nx) * 1.2;
              asteroid.vy = (asteroid.vy - 2 * dot * ny) * 1.2;
              var overlap = (asteroid.radius + p.radius) - distance;
              asteroid.x += nx * overlap;
              asteroid.y += ny * overlap;
              shake = 5;
              for (var s = 0; s < 8; s++) state.particles.push(createParticle(asteroid.x, asteroid.y, '#22c55e'));
            } else if (state.activeEffects.shield > 0) {
              state.activeEffects.shield = Math.max(0, state.activeEffects.shield - 100);
              shake = 6;
              addFloatingText(p.x, p.y, 'SHIELD ABSORBED', '#a855f7', 0.95);
              createShockwaveRing(p.x, p.y, '#a855f7', 15);
              for (var t = 0; t < 10; t++) state.particles.push(createParticle(p.x, p.y, '#a855f7'));
              asteroidDestroyed = true;
              break;
            } else {
              var damage = (config.isLocalMultiplayer || config.isCPUMultiplayer) ? 18 : 25;
              state.health -= damage;
              handlers.onHealthUpdate(state.health);
              shake = 22;
              addFloatingText(p.x, p.y, '-' + damage + '% HULL DAMAGE', '#ff0000', 1.25);
              createShockwaveRing(p.x, p.y, '#ff0000', 20);
              for (var u = 0; u < 12; u++) state.particles.push(createParticle(p.x, p.y, '#ff0000'));
              asteroidDestroyed = true;

              if (state.health <= 0) {
                state.isGameOver = true;
                handlers.onGameOver(state.score);
              }
              break;
            }
          }
        }

        if (asteroidDestroyed) {
          state.asteroids.splice(i, 1);
          continue;
        }

        // Remove off-screen asteroids
        if (asteroid.x < -100 || asteroid.x > canvas.width + 100 ||
            asteroid.y < -100 || asteroid.y > canvas.height + 100) {
          state.asteroids.splice(i, 1);
          state.score += 10;
          handlers.onScoreUpdate(state.score);
        }
      }
    }

    function update() {
      if (isPaused || !state || state.isGameOver) return;

      // Background stars parallax
      for (var i = 0; i < stars.length; i++) {
        stars[i].y += stars[i].s * 0.5;
        if (stars[i].y > canvas.height) stars[i].y = 0;
      }

      var moveSpeed = state.activeEffects.speedBoost > 0 ? 8 : 5;
      var accel = 0.5;
      var friction = 0.92;

      for (var m = 0; m < MOVE_KEYS.length; m++) {
        if (keysPressed[MOVE_KEYS[m]]) {
          controlMode = 'keyboard';
          break;
        }
      }

      updatePlayer1(accel, friction, moveSpeed);
      updatePlayer2(accel, friction, moveSpeed);
      updateShooting();
      updateDifficulty();

      // Update active effects
      var effectKeys = Object.keys(state.activeEffects);
      for (var e = 0; e < effectKeys.length; e++) {
        if (state.activeEffects[effectKeys[e]] > 0) {
          state.activeEffects[effectKeys[e]] -= 1;
        }
      }

      // Boundary check players
      var players = [state.player, state.player2];
      for (var b = 0; b < players.length; b++) {
        var p = players[b];
        if (!p) continue;
        p.x = Math.max(p.radius, Math.min(canvas.width - p.radius, p.x));
        p.y = Math.max(p.radius, Math.min(canvas.height - p.radius, p.y));
      }

      updateSpawns();

      // Update Projectiles
      for (var pi = state.projectiles.length - 1; pi >= 0; pi--) {
        var proj = state.projectiles[pi];
        proj.x += proj.vx;
        proj.y += proj.vy;
        if (proj.y < -50 || proj.x < -100 || proj.x > canvas.width + 100) {
          state.projectiles.splice(pi, 1);
        }
      }

      updatePowerUps();

      // Magnet burns twice as fast as the other effects (also ticked in the effects loop above)
      if (state.activeEffects.magnet > 0) {
        state.activeEffects.magnet -= 1;
      }

      updateCollectibles();
      updateAsteroids();

      // Update Particles
      for (var pt = state.particles.length - 1; pt >= 0; pt--) {
        var particle = state.particles[pt];
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.life--;
        if (particle.life <= 0) {
          state.particles.splice(pt, 1);
        }
      }
      if (state.particles.length > 80) {
        state.particles.splice(0, state.particles.length - 80);
      }

      if (state.projectiles.length > 30) {
        state.projectiles.splice(0, state.projectiles.length - 30);
      }

      // Update Floating Texts
      for (var ft = state.floatingTexts.length - 1; ft >= 0; ft--) {
        var text = state.floatingTexts[ft];
        text.y -= 1.2;
        text.life -= 1;
        text.alpha = Math.max(0, text.life / 60);
        if (text.life <= 0) {
          state.floatingTexts.splice(ft, 1);
        }
      }
      if (state.floatingTexts.length > 12) {
        state.floatingTexts.splice(0, state.floatingTexts.length - 12);
      }

      // Handle screen shake
      if (shake > 0) shake *= 0.9;
    }

    // --- Draw -------------------------------------------------------------

    function drawStars() {
      ctx.fillStyle = 'white';
      for (var i = 0; i < stars.length; i++) {
        ctx.beginPath();
        ctx.arc(stars[i].x, stars[i].y, stars[i].s, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    function drawAtmosphere() {
      var gradient = ctx.createRadialGradient(
        state.player.x, state.player.y, 0,
        state.player.x, state.player.y, 400
      );
      gradient.addColorStop(0, 'rgba(0, 255, 255, 0.08)');
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    function drawCollectibles() {
      state.collectibles.forEach(function (c) {
        ctx.beginPath();
        ctx.arc(c.x, c.y, c.radius, 0, Math.PI * 2);
        ctx.fillStyle = c.color;
        ctx.shadowBlur = 15;
        ctx.shadowColor = c.color;
        ctx.fill();
        ctx.shadowBlur = 0;

        // Halo
        ctx.beginPath();
        ctx.arc(c.x, c.y, c.radius + 4 + Math.sin(Date.now() / 200) * 2, 0, Math.PI * 2);
        ctx.strokeStyle = c.color;
        ctx.lineWidth = 1;
        ctx.globalAlpha = 0.3;
        ctx.stroke();
        ctx.globalAlpha = 1.0;
      });
    }

    function drawPowerUps() {
      state.powerUps.forEach(function (pu) {
        // Blinking effect when expiring
        if (pu.life !== undefined && pu.life < 300 && Math.floor(pu.life / 10) % 2 === 0) return;

        ctx.beginPath();
        ctx.arc(pu.x, pu.y, pu.radius, 0, Math.PI * 2);
        ctx.fillStyle = pu.color;
        ctx.shadowBlur = 15;
        ctx.shadowColor = pu.color;
        ctx.fill();
        ctx.shadowBlur = 0;

        // Icon letter
        ctx.fillStyle = 'white';
        ctx.font = 'bold 10px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        var label = pu.subType === 'shield' ? 'S'
          : (pu.subType === 'speed' ? 'V'
          : (pu.subType === 'magnet' ? 'M' : 'W'));
        ctx.fillText(label, pu.x, pu.y);

        // Rotating ring
        ctx.beginPath();
        ctx.arc(pu.x, pu.y, pu.radius + 3, 0, Math.PI * 2);
        ctx.strokeStyle = pu.color;
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 5]);
        ctx.lineDashOffset = -Date.now() / 20;
        ctx.stroke();
        ctx.setLineDash([]);
      });
    }

    function drawProjectiles() {
      state.projectiles.forEach(function (p) {
        ctx.save();
        var angle = Math.atan2(p.vy, p.vx);
        var length = 18;

        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - Math.cos(angle) * length, p.y - Math.sin(angle) * length);

        ctx.strokeStyle = p.color;
        ctx.lineWidth = 3.5;
        ctx.lineCap = 'round';
        ctx.stroke();

        // Draw pristine inner core
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.2;
        ctx.stroke();
        ctx.restore();
      });
    }

    function drawParticles() {
      state.particles.forEach(function (p) {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.maxLife ? Math.max(0, p.life / p.maxLife) : Math.max(0, (p.life || 1) / 25);
        ctx.fill();
      });
      ctx.globalAlpha = 1;
    }

    function drawAsteroids() {
      state.asteroids.forEach(function (a) {
        ctx.save();
        ctx.beginPath();
        var steps = a.vertices.length;
        for (var i = 0; i < steps; i++) {
          var angle = (i / steps) * Math.PI * 2;
          var r = a.radius * a.vertices[i];
          var vx = a.x + Math.cos(angle + a.rotation) * r;
          var vy = a.y + Math.sin(angle + a.rotation) * r;
          if (i === 0) ctx.moveTo(vx, vy);
          else ctx.lineTo(vx, vy);
        }
        ctx.closePath();
        ctx.fillStyle = a.color;
        ctx.fill();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Draw rock textures / craters
        a.craters.forEach(function (crater) {
          ctx.beginPath();
          // rotate craters alongside the asteroid body
          var dist = Math.sqrt(crater.rx * crater.rx + crater.ry * crater.ry) * a.radius;
          var initialAngle = Math.atan2(crater.ry, crater.rx);
          var cx = a.x + Math.cos(initialAngle + a.rotation) * dist;
          var cy = a.y + Math.sin(initialAngle + a.rotation) * dist;
          ctx.arc(cx, cy, crater.r * a.radius, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(0, 0, 0, 0.25)';
          ctx.fill();
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
          ctx.lineWidth = 0.8;
          ctx.stroke();
        });
        ctx.restore();
      });
    }

    function drawShips() {
      [state.player, state.player2].forEach(function (p) {
        if (!p) return;

        // Calculate tilt based on horizontal speed
        var tilt;
        if (config.isLocalMultiplayer || config.isCPUMultiplayer || p.id === 'player2' || controlMode === 'keyboard') {
          tilt = p.vx * 0.04;
        } else {
          tilt = (mousePos.x - p.x) * 0.01;
        }
        tilt = Math.max(-0.45, Math.min(0.45, tilt));

        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(tilt);

        // Modular space fighter geometry
        ctx.beginPath();
        ctx.moveTo(0, -p.radius * 1.5);
        ctx.lineTo(-p.radius, p.radius);
        ctx.lineTo(0, p.radius * 0.5); // Wing Notch
        ctx.lineTo(p.radius, p.radius);
        ctx.closePath();

        ctx.fillStyle = p.color;
        ctx.shadowBlur = 20;
        ctx.shadowColor = p.color;
        ctx.fill();
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.8;
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Pilot Glass Canopy
        ctx.beginPath();
        ctx.moveTo(0, -p.radius * 0.82);
        ctx.lineTo(-p.radius * 0.35, p.radius * 0.1);
        ctx.lineTo(p.radius * 0.35, p.radius * 0.1);
        ctx.closePath();
        ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
        ctx.fill();

        // Shield Effect
        if (state.activeEffects.shield > 0) {
          ctx.beginPath();
          ctx.arc(0, 0, p.radius * 2, 0, Math.PI * 2);
          ctx.strokeStyle = '#a855f7';
          ctx.lineWidth = 3;
          ctx.globalAlpha = Math.min(1, state.activeEffects.shield / 100);
          ctx.setLineDash([10, 5]);
          ctx.lineDashOffset = Date.now() / 10;
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.globalAlpha = 1;

          ctx.beginPath();
          ctx.arc(0, 0, p.radius * 2 + 5, 0, Math.PI * 2);
          ctx.strokeStyle = '#a855f7';
          ctx.lineWidth = 1;
          ctx.globalAlpha = 0.2 * Math.min(1, state.activeEffects.shield / 100);
          ctx.stroke();
          ctx.globalAlpha = 1;
        }

        // Force Field Effect
        if (state.activeEffects.speedBoost > 0) {
          var pulse = Math.sin(Date.now() / 100) * 0.2 + 0.8;
          ctx.beginPath();
          ctx.arc(0, 0, p.radius * 2.2, 0, Math.PI * 2);
          ctx.strokeStyle = '#22c55e';
          ctx.globalAlpha = 0.6 * Math.min(1, state.activeEffects.speedBoost / 100);
          ctx.lineWidth = 2 * pulse;
          ctx.stroke();

          ctx.beginPath();
          ctx.arc(0, 0, p.radius * 2.2, 0, Math.PI * 2);
          ctx.fillStyle = '#22c55e';
          ctx.globalAlpha = 0.1 * Math.min(1, state.activeEffects.speedBoost / 100);
          ctx.fill();
          ctx.globalAlpha = 1;
        }

        // Magnet Aura Effect
        if (state.activeEffects.magnet > 0) {
          ctx.beginPath();
          ctx.arc(0, 0, p.radius * 2.5, 0, Math.PI * 2);
          ctx.strokeStyle = '#c084fc';
          ctx.lineWidth = 2;
          ctx.globalAlpha = 0.8 * Math.min(1, state.activeEffects.magnet / 60);
          ctx.setLineDash([4, 4]);
          ctx.lineDashOffset = -Date.now() / 25;
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.globalAlpha = 1;
        }

        ctx.restore();

        // Thruster effect (emitted outside the translated context so sparks trail in world space)
        if (!isPaused && !state.isGameOver) {
          var thrusterCount = state.activeEffects.speedBoost > 0 ? 2 : 1;
          var thrusterColor = state.activeEffects.speedBoost > 0
            ? '#22c55e'
            : (p.id === 'player1' ? '#ff00ff' : '#fb7185');
          // Thrusters stream from ship tail
          var streamX = p.x - Math.sin(tilt) * (p.radius * 0.8);
          var streamY = p.y + Math.cos(tilt) * p.radius;
          for (var i = 0; i < thrusterCount; i++) {
            state.particles.push(createParticle(streamX, streamY, thrusterColor, true));
          }
        }
      });
    }

    function drawFloatingTexts() {
      state.floatingTexts.forEach(function (ft) {
        ctx.save();
        ctx.globalAlpha = ft.alpha;
        ctx.fillStyle = ft.color;
        ctx.font = '900 ' + Math.round(14 * ft.scale) + 'px sans-serif';
        ctx.textAlign = 'center';
        ctx.shadowBlur = 10;
        ctx.shadowColor = ft.color;
        ctx.fillText(ft.text, ft.x, ft.y);
        ctx.restore();
      });
    }

    function roundedRect(x, y, w, h, r) {
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(x, y, w, h, r);
      } else {
        ctx.rect(x, y, w, h);
      }
    }

    function drawEffectsHud() {
      var effects = [
        { name: 'SHIELD', id: 'S', color: '#a855f7', value: state.activeEffects.shield, max: 1000 },
        { name: 'SPEED', id: 'V', color: '#22c55e', value: state.activeEffects.speedBoost, max: 1000 },
        { name: 'WEAPON', id: 'W', color: '#ef4444', value: state.activeEffects.weaponUpgrade, max: 2000 },
        { name: 'MAGNET', id: 'M', color: '#c084fc', value: state.activeEffects.magnet, max: 600 }
      ].filter(function (e) { return e.value > 0; });

      effects.forEach(function (eff, i) {
        var x = 50 + i * 140;
        var y = canvas.height - 40;

        ctx.save();
        ctx.shadowBlur = 10;
        ctx.shadowColor = eff.color;

        ctx.fillStyle = 'rgba(9, 12, 28, 0.75)';
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
        ctx.lineWidth = 1;

        roundedRect(x - 20, y - 15, 125, 30, 8);
        ctx.fill();
        ctx.stroke();

        // Arc meter
        ctx.beginPath();
        ctx.arc(x, y, 10, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
        ctx.lineWidth = 2.5;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(x, y, 10, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * (eff.value / eff.max)));
        ctx.strokeStyle = eff.color;
        ctx.lineWidth = 2.5;
        ctx.stroke();

        // Arc center character
        ctx.fillStyle = '#ffffff';
        ctx.font = '900 9px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(eff.id, x, y);

        // Label Text Next To It
        ctx.fillStyle = eff.color;
        ctx.font = 'bold 9px monospace';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillText(eff.name, x + 18, y - 5);

        // Remaining Countdown seconds
        ctx.fillStyle = '#ffffff';
        ctx.font = '8px monospace';
        ctx.globalAlpha = 0.6;
        ctx.fillText(Math.round(eff.value / 60) + 's left', x + 18, y + 5);

        ctx.restore();
      });
    }

    function drawTutorial() {
      var elapsed = Date.now() - mountTime;
      if (elapsed >= 6000) return;

      var alpha = elapsed < 4500 ? 0.9 : Math.max(0, 0.9 - (elapsed - 4500) / 1500);
      if (alpha <= 0) return;

      ctx.save();
      ctx.fillStyle = 'rgba(15, 23, 42, ' + (alpha * 0.9) + ')';
      ctx.strokeStyle = 'rgba(99, 102, 241, ' + (alpha * 0.55) + ')';
      ctx.lineWidth = 1.5;

      var w = 480;
      var h = 135;
      var x = canvas.width / 2 - w / 2;
      var y = canvas.height / 2 - h / 2 - 80;

      roundedRect(x, y, w, h, 20);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = 'rgba(255, 255, 255, ' + alpha + ')';
      ctx.font = 'bold 14px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'alphabetic';
      ctx.fillText('MISSION CONTROL PROTOCOLS', canvas.width / 2, y + 25);

      ctx.lineWidth = 1;
      ctx.strokeStyle = 'rgba(255, 255, 255, ' + (alpha * 0.15) + ')';
      ctx.beginPath();
      ctx.moveTo(x + 30, y + 36);
      ctx.lineTo(x + w - 30, y + 36);
      ctx.stroke();

      if (config.isLocalMultiplayer) {
        // Player 1 (Cyan)
        ctx.fillStyle = 'rgba(0, 255, 255, ' + alpha + ')';
        ctx.font = '900 12px monospace';
        ctx.textAlign = 'left';
        ctx.fillText('PLAYER 1 (CYAN SHIP)', x + 35, y + 58);

        ctx.fillStyle = 'rgba(226, 232, 240, ' + (alpha * 0.9) + ')';
        ctx.font = '600 11px monospace';
        ctx.fillText('Move: W, A, S, D Keys', x + 35, y + 78);
        ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 35, y + 96);

        // Player 2 (Pink)
        ctx.fillStyle = 'rgba(251, 113, 133, ' + alpha + ')';
        ctx.font = '900 12px monospace';
        ctx.fillText('PLAYER 2 (PINK SHIP)', x + 255, y + 58);

        ctx.fillStyle = 'rgba(226, 232, 240, ' + (alpha * 0.9) + ')';
        ctx.font = '600 11px monospace';
        ctx.fillText('Move: ARROW KEYS', x + 255, y + 78);
        ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 255, y + 96);
      } else if (config.isCPUMultiplayer) {
        // Player 1 (Cyan)
        ctx.fillStyle = 'rgba(0, 255, 255, ' + alpha + ')';
        ctx.font = '900 12px monospace';
        ctx.textAlign = 'left';
        ctx.fillText('PLAYER 1 (CYAN SHIP)', x + 35, y + 58);

        ctx.fillStyle = 'rgba(226, 232, 240, ' + (alpha * 0.9) + ')';
        ctx.font = '600 11px monospace';
        ctx.fillText('Controls: MOUSE / WASD', x + 35, y + 78);
        ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 35, y + 96);

        // CPU Co-pilot (Pink)
        ctx.fillStyle = 'rgba(251, 113, 133, ' + alpha + ')';
        ctx.font = '900 12px monospace';
        ctx.fillText('NEURAL CO-PILOT (AI)', x + 255, y + 58);

        ctx.fillStyle = 'rgba(226, 232, 240, ' + (alpha * 0.9) + ')';
        ctx.font = '600 11px monospace';
        ctx.fillText('Strategy: DODGE & ASSIST', x + 255, y + 78);
        ctx.fillText('System: AUTONOMOUS', x + 255, y + 96);
      } else {
        // Single player help
        ctx.fillStyle = 'rgba(0, 255, 255, ' + alpha + ')';
        ctx.font = '900 12px monospace';
        ctx.textAlign = 'center';
        ctx.fillText('SINGLE PLAYER STATUS: READY', canvas.width / 2, y + 58);

        ctx.fillStyle = 'rgba(226, 232, 240, ' + (alpha * 0.9) + ')';
        ctx.font = '600 11px monospace';
        ctx.fillText('Controls: MOVE MOUSE or keys W, A, S, D', canvas.width / 2, y + 78);
        ctx.fillText('Seamless auto-switching on key down', canvas.width / 2, y + 96);
      }

      ctx.fillStyle = 'rgba(99, 102, 241, ' + (alpha * 0.95) + ')';
      ctx.font = 'italic bold 9px monospace';
      ctx.textAlign = 'center';
      ctx.fillText('CLICK THE SCREEN IF CONTROLS DO NOT PERSIST', canvas.width / 2, y + h - 14);

      ctx.restore();
    }

    function draw() {
      if (!state) return;

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      ctx.save();
      if (shake > 1) {
        ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);
      }

      drawStars();
      drawAtmosphere();
      drawCollectibles();
      drawPowerUps();
      drawProjectiles();
      drawParticles();
      drawAsteroids();
      drawShips();
      drawFloatingTexts();
      drawEffectsHud();
      drawTutorial();

      ctx.restore();
    }

    function loop() {
      update();
      draw();
      animationId = requestAnimationFrame(loop);
    }

    // --- Input ------------------------------------------------------------

    function handleResize() {
      resizeCanvas();
    }

    function handleMouseMove(e) {
      mousePos = { x: e.clientX, y: e.clientY };
      controlMode = 'mouse';
    }

    function handleTouchMove(e) {
      if (e.touches[0]) {
        mousePos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
        controlMode = 'mouse';
      }
    }

    function handleKeyDown(e) {
      // Prevent browser default actions (scrolling) for game-critical keys
      if (PREVENT_DEFAULT_KEYS.indexOf(e.key) !== -1) e.preventDefault();
      keysPressed[e.key] = true;
      keysPressed[e.code] = true;
    }

    function handleKeyUp(e) {
      if (PREVENT_DEFAULT_KEYS.indexOf(e.key) !== -1) e.preventDefault();
      keysPressed[e.key] = false;
      keysPressed[e.code] = false;
    }

    function handleCanvasClick() {
      canvas.focus();
    }

    window.addEventListener('resize', handleResize);
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('touchmove', handleTouchMove);
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    canvas.addEventListener('click', handleCanvasClick);

    resizeCanvas();

    // --- Public API -------------------------------------------------------

    return {
      start: function (options) {
        options = options || {};
        config.initialDifficulty = options.initialDifficulty !== undefined ? options.initialDifficulty : 1;
        config.isLocalMultiplayer = !!options.isLocalMultiplayer;
        config.isCPUMultiplayer = !!options.isCPUMultiplayer;
        config.controlModePreference = options.controlModePreference || 'both';

        resizeCanvas();
        reset();
        isPaused = false;

        if (!running) {
          running = true;
          animationId = requestAnimationFrame(loop);
        }

        setTimeout(function () { canvas.focus(); }, 100);
      },

      stop: function () {
        running = false;
        cancelAnimationFrame(animationId);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      },

      setPaused: function (value) {
        isPaused = !!value;
        // Clear keys to avoid stuck button states when pausing or resuming
        keysPressed = {};
      },

      setControlModePreference: function (mode) {
        config.controlModePreference = mode;
      }
    };
  }

  global.NeonNebula = { createGame: createGame };
})(window);
