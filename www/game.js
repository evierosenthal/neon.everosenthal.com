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

  // Asteroid color schemes: most are dark purple, some are hot pink.
  var ASTEROID_PALETTES = {
    purple: {
      gradient: ['#8b5cf6', '#5b21b6', '#2e1065'],
      craterFill: 'rgba(15, 5, 36, 0.6)',
      craterRim: 'rgba(196, 181, 253, 0.35)',
      speckle: 'rgba(233, 213, 255, 0.2)',
      glow: 'rgba(139, 92, 246, 0.45)',
      base: '#5b21b6',
      outline: '#2e1065',
      facet: 'rgba(167, 139, 250, 0.35)',
      facetSoft: 'rgba(167, 139, 250, 0.18)',
      hole: '#1e1b4b',
      blobBase: '#6d28d9',
      blobOutline: '#3b0f6e',
      lit: 'rgba(167, 139, 250, 0.22)',
      blobCrater: '#1a0b38',
      blobRim: 'rgba(196, 181, 253, 0.4)'
    },
    pink: {
      gradient: ['#f9a8d4', '#db2777', '#831843'],
      craterFill: 'rgba(50, 5, 30, 0.6)',
      craterRim: 'rgba(251, 207, 232, 0.4)',
      speckle: 'rgba(252, 231, 243, 0.25)',
      glow: 'rgba(236, 72, 153, 0.5)',
      base: '#db2777',
      outline: '#831843',
      facet: 'rgba(249, 168, 212, 0.4)',
      facetSoft: 'rgba(249, 168, 212, 0.2)',
      hole: '#500724',
      blobBase: '#ec4899',
      blobOutline: '#9d174d',
      lit: 'rgba(251, 207, 232, 0.25)',
      blobCrater: '#500724',
      blobRim: 'rgba(251, 207, 232, 0.45)'
    },
    gray: { // the rocky photo's natural stone gray
      gradient: ['#e2e8f0', '#94a3b8', '#475569'],
      craterFill: 'rgba(15, 23, 42, 0.5)',
      craterRim: 'rgba(255, 255, 255, 0.35)',
      speckle: 'rgba(255, 255, 255, 0.25)',
      glow: 'rgba(148, 163, 184, 0.4)',
      base: '#94a3b8',
      outline: '#475569',
      facet: 'rgba(226, 232, 240, 0.4)',
      facetSoft: 'rgba(226, 232, 240, 0.2)',
      hole: '#1e293b',
      blobBase: '#94a3b8',
      blobOutline: '#475569',
      lit: 'rgba(241, 245, 249, 0.25)',
      blobCrater: '#1e293b',
      blobRim: 'rgba(255, 255, 255, 0.35)'
    },
    blue: { // the low-poly art's royal blue
      gradient: ['#93c5fd', '#2563eb', '#1e3a8a'],
      craterFill: 'rgba(11, 20, 60, 0.6)',
      craterRim: 'rgba(191, 219, 254, 0.4)',
      speckle: 'rgba(219, 234, 254, 0.25)',
      glow: 'rgba(59, 130, 246, 0.45)',
      base: '#2563eb',
      outline: '#1e3a8a',
      facet: 'rgba(147, 197, 253, 0.45)',
      facetSoft: 'rgba(147, 197, 253, 0.22)',
      hole: '#172554',
      blobBase: '#2563eb',
      blobOutline: '#1e3a8a',
      lit: 'rgba(147, 197, 253, 0.25)',
      blobCrater: '#172554',
      blobRim: 'rgba(191, 219, 254, 0.4)'
    },
    darkblue: { // the round cartoon's deep blue
      gradient: ['#60a5fa', '#1e40af', '#172554'],
      craterFill: 'rgba(5, 10, 40, 0.65)',
      craterRim: 'rgba(147, 197, 253, 0.4)',
      speckle: 'rgba(191, 219, 254, 0.22)',
      glow: 'rgba(37, 99, 235, 0.4)',
      base: '#1e40af',
      outline: '#172554',
      facet: 'rgba(96, 165, 250, 0.35)',
      facetSoft: 'rgba(96, 165, 250, 0.18)',
      hole: '#0f172a',
      blobBase: '#1e40af',
      blobOutline: '#172554',
      lit: 'rgba(96, 165, 250, 0.25)',
      blobCrater: '#0f172a',
      blobRim: 'rgba(147, 197, 253, 0.4)'
    }
  };
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
      onDifficultyUpdate: (callbacks && callbacks.onDifficultyUpdate) || function () {},
      onDeath: (callbacks && callbacks.onDeath) || function () {},
      onHit: (callbacks && callbacks.onHit) || function () {} // asteroid hit that hurts but doesn't kill
    };

    var config = {
      initialDifficulty: 1,
      isLocalMultiplayer: false,
      isCPUMultiplayer: false,
      controlModePreference: 'both',
      speedFactor: 1 // 0.5-2.0, from the Settings rocket-speed slider
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
      // Treats instead of coins: half sundaes, half donuts.
      var kind = Math.random() < 0.5 ? 'sundae' : 'donut';
      var sprinkles = [];
      if (kind === 'donut') {
        var sprinkleColors = ['#fef08a', '#86efac', '#93c5fd', '#fca5a5', '#f0abfc'];
        for (var i = 0; i < 7; i++) {
          sprinkles.push({
            a: Math.random() * Math.PI * 2,
            d: 0.55 + Math.random() * 0.35,
            rot: Math.random() * Math.PI,
            color: sprinkleColors[i % sprinkleColors.length]
          });
        }
      }
      return {
        id: randomId(),
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 1,
        vy: (Math.random() - 0.5) * 1,
        radius: 9,
        color: kind === 'donut' ? '#f472b6' : '#fde68a', // halo/particle tint
        type: 'collectible',
        kind: kind,
        sprinkles: sprinkles
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
      var mediumSpeedBoost = (difficulty >= 0.6 && difficulty < 1.2) ? 1.2 : 1.0;
      var speed = (Math.random() * 2.5 + 2.0) * difficulty * superHardSpeedBoost * mediumSpeedBoost;

      // Three dark-purple looks, mixed at random:
      // 'rocky'   — shaded cratered rock (mini of the photo reference)
      // 'faceted' — chunky cel-shaded rock with angular potholes
      // 'blobby'  — smooth round rock with big rimmed craters
      var style = ['rocky', 'faceted', 'blobby'][Math.floor(Math.random() * 3)];
      // Each style wears its reference picture's original color:
      // rocky = stone gray, faceted = royal blue, blobby = dark blue.
      var tint = style === 'rocky' ? 'gray' : (style === 'faceted' ? 'blue' : 'darkblue');

      var vertexCount, roundness, spread;
      if (style === 'blobby') {
        vertexCount = 10 + Math.floor(Math.random() * 3);
        roundness = 0.92;
        spread = 0.14;
      } else if (style === 'faceted') {
        vertexCount = 9 + Math.floor(Math.random() * 4);
        roundness = 0.78;
        spread = 0.38;
      } else {
        vertexCount = 8 + Math.floor(Math.random() * 5);
        roundness = 0.85;
        spread = 0.3;
      }
      var vertices = [];
      for (var i = 0; i < vertexCount; i++) {
        vertices.push(roundness + Math.random() * spread);
      }

      var craterCount, craterBase, craterVar;
      if (style === 'blobby') { craterCount = 3; craterBase = 0.16; craterVar = 0.14; }
      else if (style === 'faceted') { craterCount = 4 + Math.floor(Math.random() * 3); craterBase = 0.08; craterVar = 0.1; }
      else { craterCount = 2 + Math.floor(Math.random() * 2); craterBase = 0.12; craterVar = 0.12; }
      var craters = [];
      for (var j = 0; j < craterCount; j++) {
        craters.push({
          rx: (Math.random() - 0.5) * (style === 'blobby' ? 0.8 : 0.5),
          ry: (Math.random() - 0.5) * (style === 'blobby' ? 0.8 : 0.5),
          r: craterBase + Math.random() * craterVar,
          rot: Math.random() * Math.PI * 2
        });
      }

      var speckles = [];
      if (style === 'rocky') {
        for (var k = 0; k < 5; k++) {
          speckles.push({
            rx: (Math.random() - 0.5) * 1.1,
            ry: (Math.random() - 0.5) * 1.1,
            r: 0.02 + Math.random() * 0.04
          });
        }
      }

      return {
        id: randomId(),
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: ASTEROID_MIN_RADIUS + Math.random() * (ASTEROID_MAX_RADIUS - ASTEROID_MIN_RADIUS),
        color: tint === 'gray'
          ? 'hsl(215, 15%, ' + (65 + Math.random() * 10) + '%)'  // silvery debris/shockwaves
          : 'hsl(' + (218 + Math.random() * 12) + ', 80%, ' + (tint === 'darkblue' ? 55 : 65) + '%)',
        type: 'asteroid',
        style: style,
        tint: tint,
        vertices: vertices,
        craters: craters,
        speckles: speckles,
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
        dying: false,
        deathTimer: 0,
        shipsDestroyed: false,
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
        var followSpeed = Math.min(0.4, (state.activeEffects.speedBoost > 0 ? 0.15 : 0.08) * config.speedFactor);
        var prevX = player.x;
        var prevY = player.y;
        player.x += (mousePos.x - player.x) * followSpeed;
        player.y += (mousePos.y - player.y) * followSpeed;
        player.vx = player.x - prevX;
        player.vy = player.y - prevY;
      }

      // Keyboard Component — much quicker than the mouse glide
      if (keyboardDrives) {
        var kbAccel = accel * 2.0;
        var kbTopSpeed = moveSpeed * 2.0;
        if (keysPressed['KeyW'] || keysPressed['w'] || keysPressed['W'] || keysPressed['ArrowUp'] || keysPressed['Up']) {
          player.vy -= kbAccel;
        }
        if (keysPressed['KeyS'] || keysPressed['s'] || keysPressed['S'] || keysPressed['ArrowDown'] || keysPressed['Down']) {
          player.vy += kbAccel;
        }
        if (keysPressed['KeyA'] || keysPressed['a'] || keysPressed['A'] || keysPressed['ArrowLeft'] || keysPressed['Left']) {
          player.vx -= kbAccel;
        }
        if (keysPressed['KeyD'] || keysPressed['d'] || keysPressed['D'] || keysPressed['ArrowRight'] || keysPressed['Right']) {
          player.vx += kbAccel;
        }
        player.vx *= friction;
        player.vy *= friction;
        var kbSpeed = Math.sqrt(player.vx * player.vx + player.vy * player.vy);
        if (kbSpeed > kbTopSpeed) {
          player.vx = (player.vx / kbSpeed) * kbTopSpeed;
          player.vy = (player.vy / kbSpeed) * kbTopSpeed;
        }
        player.x += player.vx;
        player.y += player.vy;
      }

      // Clamp Player 1 within screen boundaries (kill into-wall velocity so
      // the ship slides freely along edges instead of sticking)
      var clampedPX = Math.max(player.radius, Math.min(canvas.width - player.radius, player.x));
      var clampedPY = Math.max(player.radius, Math.min(canvas.height - player.radius, player.y));
      if (clampedPX !== player.x) player.vx = 0;
      if (clampedPY !== player.y) player.vy = 0;
      player.x = clampedPX;
      player.y = clampedPY;
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
      var mediumSpawnBoost = (state.difficulty >= 0.6 && state.difficulty < 1.2) ? 1.45 : 1.0;
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
                startDeathSequence(p, asteroid); // fatal hit has its own crash sound
              } else {
                handlers.onHit();
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

    // Fatal hit: blow the ship(s) and the killer asteroid apart on-canvas,
    // hold for a beat so the explosion plays out, then raise game over.
    function startDeathSequence(deadPlayer, killerAsteroid) {
      if (state.dying) return;
      state.dying = true;
      state.deathTimer = 100; // ~1.7s at 60fps
      shake = 40;
      handlers.onDeath();

      function explode(x, y, colors, sparks, ringSize) {
        colors.forEach(function (color) {
          createShockwaveRing(x, y, color, ringSize);
        });
        for (var i = 0; i < sparks; i++) {
          var debris = createParticle(x, y, colors[i % colors.length]);
          debris.vx *= 1.2 + Math.random() * 2.2; // fling debris harder than a normal hit
          debris.vy *= 1.2 + Math.random() * 2.2;
          debris.radius = 2.5 + Math.random() * 4; // chunky, clearly-visible wreckage
          debris.life *= 2.5;
          debris.maxLife = debris.life;
          state.particles.push(debris);
        }
      }

      explode(killerAsteroid.x, killerAsteroid.y, [killerAsteroid.color || '#a855f7', '#fbbf24'], 45, 16);
      [state.player, state.player2].forEach(function (ship) {
        if (!ship) return;
        explode(ship.x, ship.y, ['#22d3ee', '#ff5533', '#ffffff'], 70, 20);
      });
      addFloatingText(deadPlayer.x, deadPlayer.y - 40, 'HULL DESTROYED', '#ff0000', 1.4);

      state.shipsDestroyed = true; // stop drawing the ships — they're debris now
    }

    function updateDeathSequence() {
      // Aftermath only: debris flies, rings expand, asteroids keep drifting.
      for (var i = 0; i < state.asteroids.length; i++) {
        var a = state.asteroids[i];
        a.x += a.vx;
        a.y += a.vy;
        a.rotation += a.spinSpeed;
      }
      for (var pt = state.particles.length - 1; pt >= 0; pt--) {
        var particle = state.particles[pt];
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.vx *= 0.985;
        particle.vy *= 0.985;
        particle.life--;
        if (particle.life <= 0) state.particles.splice(pt, 1);
      }
      for (var ft = state.floatingTexts.length - 1; ft >= 0; ft--) {
        var text = state.floatingTexts[ft];
        text.y -= 1.2;
        text.life -= 1;
        text.alpha = Math.max(0, text.life / 60);
        if (text.life <= 0) state.floatingTexts.splice(ft, 1);
      }
      if (shake > 0) shake *= 0.9;

      state.deathTimer--;
      if (state.deathTimer <= 0) {
        state.isGameOver = true;
        handlers.onGameOver(state.score);
      }
    }

    function update() {
      if (isPaused || !state || state.isGameOver) return;
      if (state.dying) {
        updateDeathSequence();
        return;
      }

      // Background stars parallax
      for (var i = 0; i < stars.length; i++) {
        stars[i].y += stars[i].s * 0.5;
        if (stars[i].y > canvas.height) stars[i].y = 0;
      }

      var moveSpeed = (state.activeEffects.speedBoost > 0 ? 8 : 5) * config.speedFactor;
      var accel = 0.5 * config.speedFactor;
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

      // Boundary check players. Zero any velocity still pressing into a wall,
      // otherwise the speed cap keeps normalizing against it and the ship
      // can barely slide along the edge.
      var players = [state.player, state.player2];
      for (var b = 0; b < players.length; b++) {
        var p = players[b];
        if (!p) continue;
        var clampedX = Math.max(p.radius, Math.min(canvas.width - p.radius, p.x));
        var clampedY = Math.max(p.radius, Math.min(canvas.height - p.radius, p.y));
        if (clampedX !== p.x) p.vx = 0;
        if (clampedY !== p.y) p.vy = 0;
        p.x = clampedX;
        p.y = clampedY;
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
      // (skip the cap on the death frame so the full explosion survives)
      if (!state.dying && state.particles.length > 80) {
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
      if (state.shipsDestroyed || !state.player) return;
      var gradient = ctx.createRadialGradient(
        state.player.x, state.player.y, 0,
        state.player.x, state.player.y, 400
      );
      gradient.addColorStop(0, 'rgba(0, 255, 255, 0.08)');
      gradient.addColorStop(1, 'transparent');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    function drawDonut(c) {
      var R = c.radius * 1.25;
      ctx.shadowBlur = 12;
      ctx.shadowColor = c.color;

      // Dough rim, then pink frosting on top
      ctx.beginPath();
      ctx.arc(0, 0, R, 0, Math.PI * 2);
      ctx.fillStyle = '#d9a066';
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.beginPath();
      ctx.arc(0, 0, R * 0.9, 0, Math.PI * 2);
      ctx.fillStyle = '#f472b6';
      ctx.fill();

      // Hole
      ctx.beginPath();
      ctx.arc(0, 0, R * 0.38, 0, Math.PI * 2);
      ctx.fillStyle = '#09090b';
      ctx.fill();

      // Sprinkles on the frosting band
      ctx.lineWidth = 1.5;
      ctx.lineCap = 'round';
      c.sprinkles.forEach(function (s) {
        var sx = Math.cos(s.a) * R * s.d;
        var sy = Math.sin(s.a) * R * s.d;
        ctx.strokeStyle = s.color;
        ctx.beginPath();
        ctx.moveTo(sx - Math.cos(s.rot) * 2, sy - Math.sin(s.rot) * 2);
        ctx.lineTo(sx + Math.cos(s.rot) * 2, sy + Math.sin(s.rot) * 2);
        ctx.stroke();
      });
    }

    // Mini waffle-cone sundae: three scoops, whipped cream with sprinkles,
    // cherry on top and sparkles — a tiny take on the reference art.
    function drawSundae(c) {
      var R = c.radius * 1.35;
      ctx.shadowBlur = 10;
      ctx.shadowColor = c.color;

      // Waffle cone
      ctx.beginPath();
      ctx.moveTo(-R * 0.55, R * 0.15);
      ctx.lineTo(R * 0.55, R * 0.15);
      ctx.lineTo(0, R * 1.5);
      ctx.closePath();
      ctx.fillStyle = '#e8a33d';
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = '#b45309';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(-R * 0.4, R * 0.35);
      ctx.lineTo(R * 0.15, R * 1.15);
      ctx.moveTo(-R * 0.1, R * 0.2);
      ctx.lineTo(R * 0.35, R * 0.85);
      ctx.moveTo(R * 0.4, R * 0.35);
      ctx.lineTo(-R * 0.15, R * 1.15);
      ctx.moveTo(R * 0.1, R * 0.2);
      ctx.lineTo(-R * 0.35, R * 0.85);
      ctx.stroke();

      // Three scoops: lemon, blueberry, strawberry in front
      ctx.beginPath();
      ctx.arc(-R * 0.42, -R * 0.15, R * 0.42, 0, Math.PI * 2);
      ctx.fillStyle = '#fde68a';
      ctx.fill();
      ctx.beginPath();
      ctx.arc(R * 0.42, -R * 0.15, R * 0.42, 0, Math.PI * 2);
      ctx.fillStyle = '#93c5fd';
      ctx.fill();
      ctx.beginPath();
      ctx.arc(0, -R * 0.05, R * 0.48, 0, Math.PI * 2);
      ctx.fillStyle = '#f9a8d4';
      ctx.fill();

      // Whipped cream swirl with sprinkles
      ctx.beginPath();
      ctx.arc(0, -R * 0.6, R * 0.4, 0, Math.PI * 2);
      ctx.fillStyle = '#fff7ed';
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.lineCap = 'round';
      [['#ef4444', -0.2, -0.65, 0.6], ['#22c55e', 0.15, -0.5, -0.4],
       ['#3b82f6', 0.02, -0.78, 0.1], ['#f59e0b', -0.12, -0.45, -0.9]].forEach(function (s) {
        ctx.strokeStyle = s[0];
        ctx.beginPath();
        ctx.moveTo(s[1] * R - Math.cos(s[3]) * 1.6, s[2] * R - Math.sin(s[3]) * 1.6);
        ctx.lineTo(s[1] * R + Math.cos(s[3]) * 1.6, s[2] * R + Math.sin(s[3]) * 1.6);
        ctx.stroke();
      });

      // Cherry with stem
      ctx.strokeStyle = '#7c2d12';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, -R * 1.0);
      ctx.quadraticCurveTo(R * 0.12, -R * 1.25, R * 0.2, -R * 1.35);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(0, -R * 0.98, R * 0.2, 0, Math.PI * 2);
      ctx.fillStyle = '#ef4444';
      ctx.shadowBlur = 8;
      ctx.shadowColor = '#ef4444';
      ctx.fill();
      ctx.shadowBlur = 0;

      // Sparkles
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
      ctx.lineWidth = 1;
      [[0.62, -0.6], [-0.68, 0.25]].forEach(function (pos) {
        var sx = pos[0] * R;
        var sy = pos[1] * R;
        ctx.beginPath();
        ctx.moveTo(sx - 3, sy);
        ctx.lineTo(sx + 3, sy);
        ctx.moveTo(sx, sy - 3);
        ctx.lineTo(sx, sy + 3);
        ctx.stroke();
      });
    }

    function drawCollectibles() {
      state.collectibles.forEach(function (c) {
        ctx.save();
        ctx.translate(c.x, c.y);
        if (c.kind === 'donut') drawDonut(c);
        else drawSundae(c);
        ctx.restore();

        // Halo
        ctx.beginPath();
        ctx.arc(c.x, c.y, c.radius + 6 + Math.sin(Date.now() / 200) * 2, 0, Math.PI * 2);
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

    // Trace the asteroid's outline in local (translated/rotated) coordinates.
    function traceAsteroidPath(a) {
      ctx.beginPath();
      var steps = a.vertices.length;
      for (var i = 0; i < steps; i++) {
        var angle = (i / steps) * Math.PI * 2;
        var r = a.radius * a.vertices[i];
        if (i === 0) ctx.moveTo(Math.cos(angle) * r, Math.sin(angle) * r);
        else ctx.lineTo(Math.cos(angle) * r, Math.sin(angle) * r);
      }
      ctx.closePath();
    }

    // Shaded cratered rock — mini of the photo reference.
    function drawRockyAsteroid(a) {
      var R = a.radius;
      var P = ASTEROID_PALETTES[a.tint] || ASTEROID_PALETTES.purple;
      var g = ctx.createLinearGradient(-R, -R, R, R);
      g.addColorStop(0, P.gradient[0]);
      g.addColorStop(0.45, P.gradient[1]);
      g.addColorStop(1, P.gradient[2]);
      ctx.fillStyle = g;
      ctx.shadowBlur = 10;
      ctx.shadowColor = P.glow;
      ctx.fill();
      ctx.shadowBlur = 0;

      ctx.save();
      ctx.clip();
      a.craters.forEach(function (crater) {
        var cx = crater.rx * R;
        var cy = crater.ry * R;
        var cr = crater.r * R;
        ctx.beginPath();
        ctx.arc(cx, cy, cr, 0, Math.PI * 2);
        ctx.fillStyle = P.craterFill;
        ctx.fill();
        // sunlit rim on the lower-right of each crater
        ctx.beginPath();
        ctx.arc(cx, cy, cr, Math.PI * 0.1, Math.PI * 0.9);
        ctx.strokeStyle = P.craterRim;
        ctx.lineWidth = 1.2;
        ctx.stroke();
      });
      a.speckles.forEach(function (dot) {
        ctx.beginPath();
        ctx.arc(dot.rx * R, dot.ry * R, dot.r * R + 0.6, 0, Math.PI * 2);
        ctx.fillStyle = P.speckle;
        ctx.fill();
      });
      ctx.restore();
    }

    // Chunky cel-shaded rock with angular potholes — mini of the low-poly art.
    function drawFacetedAsteroid(a) {
      var R = a.radius;
      var P = ASTEROID_PALETTES[a.tint] || ASTEROID_PALETTES.purple;
      ctx.fillStyle = P.base;
      ctx.fill();
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = P.outline;
      ctx.stroke();

      ctx.save();
      ctx.clip();
      // Two flat facet highlights toward the light
      ctx.fillStyle = P.facet;
      ctx.beginPath();
      ctx.moveTo(-R, -R);
      ctx.lineTo(R * 0.25, -R * 0.55);
      ctx.lineTo(-R * 0.3, R * 0.15);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = P.facetSoft;
      ctx.beginPath();
      ctx.moveTo(R * 0.1, -R);
      ctx.lineTo(R * 0.8, -R * 0.3);
      ctx.lineTo(R * 0.25, -R * 0.1);
      ctx.closePath();
      ctx.fill();

      // Angular hexagon potholes
      ctx.fillStyle = P.hole;
      a.craters.forEach(function (crater) {
        var cx = crater.rx * R;
        var cy = crater.ry * R;
        var cr = crater.r * R * 1.2;
        ctx.beginPath();
        for (var i = 0; i < 6; i++) {
          var ha = crater.rot + (i / 6) * Math.PI * 2;
          var hx = cx + Math.cos(ha) * cr;
          var hy = cy + Math.sin(ha) * cr;
          if (i === 0) ctx.moveTo(hx, hy);
          else ctx.lineTo(hx, hy);
        }
        ctx.closePath();
        ctx.fill();
      });
      ctx.restore();
    }

    // Smooth round rock with big rimmed craters — mini of the round cartoon art.
    function drawBlobbyAsteroid(a) {
      var R = a.radius;
      var P = ASTEROID_PALETTES[a.tint] || ASTEROID_PALETTES.purple;
      ctx.fillStyle = P.blobBase;
      ctx.shadowBlur = 8;
      ctx.shadowColor = P.glow;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = P.blobOutline;
      ctx.stroke();

      ctx.save();
      ctx.clip();
      // Lit side
      ctx.fillStyle = P.lit;
      ctx.beginPath();
      ctx.arc(-R * 0.35, -R * 0.35, R * 1.05, 0, Math.PI * 2);
      ctx.fill();

      // Big organic craters with light rims
      a.craters.forEach(function (crater) {
        var cx = crater.rx * R;
        var cy = crater.ry * R;
        var cr = crater.r * R;
        ctx.beginPath();
        ctx.ellipse(cx, cy, cr * 1.35, cr * 0.95, crater.rot, 0, Math.PI * 2);
        ctx.fillStyle = P.blobCrater;
        ctx.fill();
        ctx.strokeStyle = P.blobRim;
        ctx.lineWidth = 1.5;
        ctx.stroke();
      });
      ctx.restore();
    }

    function drawAsteroids() {
      state.asteroids.forEach(function (a) {
        ctx.save();
        ctx.translate(a.x, a.y);
        ctx.rotate(a.rotation);
        traceAsteroidPath(a);
        if (a.style === 'faceted') drawFacetedAsteroid(a);
        else if (a.style === 'blobby') drawBlobbyAsteroid(a);
        else drawRockyAsteroid(a);
        ctx.restore();
      });
    }

    function drawShips() {
      if (state.shipsDestroyed) return;
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

        var R = p.radius;

        // Player 1 flies the equipped skin; player 2 keeps its own colors.
        var skin = (p.id === 'player1' && config.skin) ? config.skin : null;
        var accent = skin ? skin.accent : p.color;
        if (skin && skin.animated) {
          accent = 'hsl(' + Math.floor((Date.now() / 15) % 360) + ', 85%, 65%)';
        }
        // Gradient accents, applied per part (fins / nose / stripe each get the
        // full color run) — exactly how the hangar card's SVG paints them.
        var finFill = accent;
        var noseFill = accent;
        var stripeFill = accent;
        if (skin && skin.accentGradient) {
          var mkAccentGrad = function (y0, y1) {
            var g = ctx.createLinearGradient(0, y0, 0, y1);
            g.addColorStop(0, skin.accentGradient[0]);
            g.addColorStop(0.5, skin.accentGradient[1]);
            g.addColorStop(1, skin.accentGradient[2]);
            return g;
          };
          finFill = mkAccentGrad(p.radius * 0.15, p.radius * 1.05);
          noseFill = mkAccentGrad(-p.radius * 1.6, -p.radius * 0.72);
          stripeFill = mkAccentGrad(p.radius * 0.45, p.radius * 0.63);
          accent = skin.accentGradient[1]; // glows stay a solid mid-tone
        } else {
          finFill = accent;
          noseFill = accent;
          stripeFill = accent;
        }
        var hullStops = (skin && skin.hull) || ['#94a3b8', '#f1f5f9', '#e2e8f0', '#64748b'];
        var winStops = (skin && skin.window) || ['#e0f2fe', '#67e8f9', '#0e7490'];

        // --- Rocket exhaust flame (behind the body) ---
        if (!isPaused && !state.isGameOver && !state.dying) {
          var flick = 0.8 + 0.35 * Math.abs(Math.sin(Date.now() / 47 + p.x)) + Math.random() * 0.15;
          var flameLen = R * 1.0 * flick;
          // outer orange tongue
          ctx.beginPath();
          ctx.moveTo(-R * 0.34, R * 1.1);
          ctx.quadraticCurveTo(-R * 0.28, R * 1.1 + flameLen * 0.7, 0, R * 1.1 + flameLen);
          ctx.quadraticCurveTo(R * 0.28, R * 1.1 + flameLen * 0.7, R * 0.34, R * 1.1);
          ctx.closePath();
          ctx.fillStyle = 'rgba(249, 115, 22, 0.85)';
          ctx.shadowBlur = 18;
          ctx.shadowColor = '#fb923c';
          ctx.fill();
          ctx.shadowBlur = 0;
          // middle yellow tongue
          ctx.beginPath();
          ctx.moveTo(-R * 0.22, R * 1.1);
          ctx.quadraticCurveTo(-R * 0.18, R * 1.1 + flameLen * 0.5, 0, R * 1.1 + flameLen * 0.68);
          ctx.quadraticCurveTo(R * 0.18, R * 1.1 + flameLen * 0.5, R * 0.22, R * 1.1);
          ctx.closePath();
          ctx.fillStyle = 'rgba(251, 191, 36, 0.95)';
          ctx.fill();
          // hot white-blue core
          ctx.beginPath();
          ctx.moveTo(-R * 0.11, R * 1.1);
          ctx.quadraticCurveTo(-R * 0.09, R * 1.1 + flameLen * 0.3, 0, R * 1.1 + flameLen * 0.4);
          ctx.quadraticCurveTo(R * 0.09, R * 1.1 + flameLen * 0.3, R * 0.11, R * 1.1);
          ctx.closePath();
          ctx.fillStyle = 'rgba(224, 242, 254, 0.95)';
          ctx.fill();
        }

        // --- Swept tail fins (tinted per player) ---
        ctx.beginPath();
        ctx.moveTo(-R * 0.6, R * 0.15);
        ctx.lineTo(-R * 1.15, R * 1.05);
        ctx.lineTo(-R * 0.55, R * 0.95);
        ctx.closePath();
        ctx.moveTo(R * 0.6, R * 0.15);
        ctx.lineTo(R * 1.15, R * 1.05);
        ctx.lineTo(R * 0.55, R * 0.95);
        ctx.closePath();
        ctx.fillStyle = finFill;
        ctx.shadowBlur = 12;
        ctx.shadowColor = accent;
        ctx.fill();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
        ctx.lineWidth = 1.2;
        ctx.stroke();
        ctx.shadowBlur = 0;

        // --- Hull: cylinder with a rounded nose cone ---
        var hull = ctx.createLinearGradient(-R * 0.7, 0, R * 0.7, 0);
        hull.addColorStop(0, hullStops[0]);
        hull.addColorStop(0.35, hullStops[1]);
        hull.addColorStop(0.65, hullStops[2]);
        hull.addColorStop(1, hullStops[3]);
        ctx.beginPath();
        ctx.moveTo(-R * 0.62, R * 0.95);
        ctx.lineTo(-R * 0.62, -R * 0.45);
        ctx.quadraticCurveTo(-R * 0.62, -R * 1.35, 0, -R * 1.6);
        ctx.quadraticCurveTo(R * 0.62, -R * 1.35, R * 0.62, -R * 0.45);
        ctx.lineTo(R * 0.62, R * 0.95);
        ctx.closePath();
        ctx.fillStyle = hull;
        ctx.shadowBlur = 14;
        ctx.shadowColor = accent;
        ctx.fill();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.lineWidth = 1.3;
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Nose-cone tip in the player color
        ctx.beginPath();
        ctx.moveTo(-R * 0.58, -R * 0.72);
        ctx.quadraticCurveTo(-R * 0.55, -R * 1.32, 0, -R * 1.6);
        ctx.quadraticCurveTo(R * 0.55, -R * 1.32, R * 0.58, -R * 0.72);
        ctx.quadraticCurveTo(0, -R * 0.92, -R * 0.58, -R * 0.72);
        ctx.closePath();
        ctx.fillStyle = noseFill;
        ctx.fill();

        // Body stripe in the player color
        ctx.fillStyle = stripeFill;
        ctx.fillRect(-R * 0.62, R * 0.45, R * 1.24, R * 0.18);

        // --- Porthole window ---
        var glass = ctx.createRadialGradient(-R * 0.1, -R * 0.32, R * 0.04, 0, -R * 0.22, R * 0.34);
        glass.addColorStop(0, winStops[0]);
        glass.addColorStop(0.5, winStops[1]);
        glass.addColorStop(1, winStops[2]);
        ctx.beginPath();
        ctx.arc(0, -R * 0.22, R * 0.32, 0, Math.PI * 2);
        ctx.fillStyle = glass;
        ctx.fill();
        ctx.strokeStyle = '#cbd5e1';
        ctx.lineWidth = R * 0.1;
        ctx.stroke();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.lineWidth = 1;
        ctx.stroke();
        // glint
        ctx.beginPath();
        ctx.arc(-R * 0.11, -R * 0.33, R * 0.07, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
        ctx.fill();

        // --- Engine nozzle skirt ---
        ctx.beginPath();
        ctx.moveTo(-R * 0.45, R * 0.95);
        ctx.lineTo(R * 0.45, R * 0.95);
        ctx.lineTo(R * 0.58, R * 1.18);
        ctx.lineTo(-R * 0.58, R * 1.18);
        ctx.closePath();
        ctx.fillStyle = '#475569';
        ctx.fill();
        ctx.strokeStyle = '#94a3b8';
        ctx.lineWidth = 1;
        ctx.stroke();

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
          var streamX = p.x - Math.sin(tilt) * (p.radius * 1.3);
          var streamY = p.y + Math.cos(tilt) * (p.radius * 1.3); // below the nozzle
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
        config.skin = options.skin || null; // player 1's rocket skin

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
      },

      setSpeedFactor: function (factor) {
        config.speedFactor = Math.max(0.01, Math.min(3, Number(factor) || 1));
      }
    };
  }

  global.NeonNebula = { createGame: createGame };
})(window);
