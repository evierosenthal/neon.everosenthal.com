/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 *
 * Nitro Nebula — canvas game engine (plain ES5+/ES6 JavaScript, no build step).
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
    },
    burnt: { // the cookie quest's charred cookies: dark chocolate browns
      gradient: ['#6b4423', '#3b2314', '#1f1008'],
      craterFill: 'rgba(18, 8, 3, 0.7)',
      craterRim: 'rgba(212, 163, 115, 0.3)',
      speckle: 'rgba(212, 163, 115, 0.2)',
      glow: 'rgba(120, 72, 32, 0.45)',
      base: '#3b2314',
      outline: '#1f1008',
      facet: 'rgba(160, 82, 45, 0.35)',
      facetSoft: 'rgba(160, 82, 45, 0.18)',
      hole: '#120803',
      blobBase: '#4a2c17',
      blobOutline: '#1f1008',
      lit: 'rgba(212, 163, 115, 0.18)',
      blobCrater: '#120803',
      blobRim: 'rgba(212, 163, 115, 0.3)'
    }
  };
  var STAR_COUNT = 50;

  // --- Secret cookie quest ---------------------------------------------------
  // In a Hard run a lone cookie drifts across the screen once; catching it
  // starts a three-level side quest (startQuest / updateQuest below).
  // Durations are frames at 60 fps; `rain` / `burnt` are per-frame spawn
  // chances during that level's play phase; `asteroids` keeps the normal
  // asteroid spawns running during the level, scaled by that factor (0 =
  // none; 0.65 = about two thirds of the frozen difficulty's density).
  var QUEST_LEVELS = [
    { name: 'COOKIE CRUMBS', duration: 1800, goal: 10, rain: 0.045, burnt: 0, asteroids: 0.65,
      hint: 'COLLECT 10 COOKIES · MIND THE ASTEROIDS' },
    { name: 'CRUMB STORM', duration: 2100, goal: 15, rain: 0.04, burnt: 0.02,
      hint: 'COLLECT 15 COOKIES · DODGE THE BURNT ONES' },
    { name: 'THE COOKIE JAR', duration: 2700, goal: 1, rain: 0, burnt: 0.012,
      hint: 'CRACK THE COOKIE JAR · DON\'T TOUCH THE SUNS' }
  ];
  var QUEST_BOSS_HP = 50;
  // Level 3's little suns: touch one and the ship is gone instantly. They
  // fly around and bounce; harmless while they warm up (QUEST_SUN_ARM_FRAMES).
  var QUEST_SUN_COUNT = 3;
  var QUEST_SUN_RADIUS = 14;
  var QUEST_SUN_ARM_FRAMES = 90;
  var SUN_COLOR = '#fbbf24';
  // The first sun is a hunter: it homes in on the nearest ship (slower than
  // a ship at full thrust, so you can outrun it but never stop).
  var QUEST_HUNTER_SPEED = 2.8;
  var QUEST_HUNTER_ACCEL = 0.1;
  var QUEST_BOSS_FIRE_INTERVAL = 150; // play frames between crumb rings
  // Blasters are earned, not granted: a W orb drops in at the start of every
  // level, and level 3 re-supplies one every QUEST_WEAPON_RESUPPLY play
  // frames while the ship is unarmed (and no orb is already waiting).
  var QUEST_WEAPON_RESUPPLY = 450;
  var QUEST_BOSS_CONTACT_COOLDOWN = 45; // frames a ship is immune after bumping the boss
  var COOKIE_COLOR = '#d4a373';
  var COOKIE_GOLD = '#fbbf24';
  // Crumb outline (no randoms): ten near-round vertices
  var CRUMB_VERTICES = [1, 0.96, 1.02, 0.95, 1, 0.97, 1.03, 0.96, 1, 0.98];
  // Chocolate chips, hand-scattered so they don't read as a pattern: three
  // layouts of [x, y, radius] as fractions of the cookie radius; each cookie
  // picks one from its id (cookieChipLayout). Nothing is random at draw time.
  var COOKIE_CHIP_LAYOUTS = [
    [[-0.42, -0.30, 0.17], [0.15, -0.48, 0.14], [0.47, -0.05, 0.16], [-0.05, 0.08, 0.13],
      [-0.48, 0.33, 0.15], [0.22, 0.46, 0.17], [0.50, 0.40, 0.11]],
    [[-0.20, -0.52, 0.15], [0.35, -0.35, 0.17], [-0.52, -0.02, 0.14], [0.08, -0.02, 0.16],
      [0.52, 0.22, 0.13], [-0.28, 0.40, 0.17], [0.18, 0.50, 0.12]],
    [[0.02, -0.50, 0.16], [-0.45, -0.22, 0.13], [0.45, -0.28, 0.14], [-0.15, 0.15, 0.17],
      [0.30, 0.12, 0.15], [-0.40, 0.48, 0.14], [0.25, 0.50, 0.16]]
  ];
  // Darker charred chips on the burnt cookies, likewise scattered.
  var BURNT_CHIPS = [[-0.35, -0.28, 0.15], [0.30, -0.40, 0.13], [0.42, 0.15, 0.16], [-0.45, 0.30, 0.14], [0.0, 0.42, 0.12]];

  function cookieChipLayout(id) {
    var h = 0;
    for (var i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) & 0xffff;
    return COOKIE_CHIP_LAYOUTS[h % COOKIE_CHIP_LAYOUTS.length];
  }

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
      onHit: (callbacks && callbacks.onHit) || function () {}, // asteroid hit that hurts but doesn't kill
      // Secret cookie quest: fired once when level 3 is won (start of the
      // 'complete' banner) — ui.js pays the coins and unlocks the skins.
      onQuestComplete: (callbacks && callbacks.onQuestComplete) || function () {},
      // (kind, level) with kind 'start' | 'levelWon' | 'failed'
      onQuestEvent: (callbacks && callbacks.onQuestEvent) || function () {}
    };

    var config = {
      initialDifficulty: 1,
      isLocalMultiplayer: false,
      isCPUMultiplayer: false,
      controlModePreference: 'both',
      speedFactor: 1, // from the Settings rocket-speed slider
      flameSpeedMult: 1, // from the equipped fire's power (fast/slow)
      online: null, // {role: 'host'|'guest', send: fn(obj)} for an internet two-player game
      // Test hooks for the secret cookie quest (www/tests/cookie-quest.jsc.js):
      //  cookieSpawnFrame — a number replaces the random spawn-frame draw in
      //    reset() (that Math.random() is NOT consumed when this is given);
      //  cookieAimAtShip — true spawns the cookie at the player's y (the y
      //    Math.random() is still consumed and ignored, so the random count
      //    is identical with or without the hook);
      //  questBossHP — a number overrides the Giant Cookie's hit points so a
      //    scripted run can reach the quest's ending (no randoms involved).
      cookieSpawnFrame: undefined,
      cookieAimAtShip: false,
      questBossHP: undefined
    };

    // --- Online play ----------------------------------------------------------
    // The host runs the real simulation and streams compact snapshots; the
    // guest steers player 2 by sending a direction vector and draws whatever
    // the latest snapshot says. Nothing here runs for local games.
    var remoteInput = { dx: 0, dy: 0 }; // host: the guest's latest steering
    var pendingSnapshot = null;         // guest: newest snapshot not yet applied
    var sentIds = {};                   // host: entities the guest already has in full
    var knownEntities = {};             // guest: id -> full entity object
    var netFrame = 0;
    var finalSnapshotSent = false;
    var lastInputSent = 0;
    var lastInput = { dx: 0, dy: 0 };
    var reported = { score: null, health: null, hit: 0, dying: false, over: false };

    function resetNet() {
      remoteInput = { dx: 0, dy: 0 };
      pendingSnapshot = null;
      sentIds = {};
      knownEntities = {};
      netFrame = 0;
      finalSnapshotSent = false;
      lastInputSent = 0;
      lastInput = { dx: 0, dy: 0 };
      reported = { score: null, health: null, hit: 0, dying: false, over: false };
    }

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

    // --- Secret cookie quest factories ------------------------------------
    // The Math.random() order is part of the iOS parity contract; each
    // factory lists its draws in the order they happen.

    // The lone cookie that drifts across a Hard run. Randoms, in order:
    // 1 side (left/right), 2 y (drawn and ignored with cookieAimAtShip),
    // 3 wobble phase.
    function createDriftingCookie(width, height) {
      var fromLeft = Math.random() < 0.5;             // 1: side
      var y = height * (0.2 + Math.random() * 0.6);   // 2: y
      if (config.cookieAimAtShip) y = state.player.y; // test hook (random above still consumed)
      var wobble = Math.random() * Math.PI * 2;       // 3: wobble phase
      return {
        id: 'secret_cookie',
        x: fromLeft ? -30 : width + 30,
        y: y,
        vx: fromLeft ? 2.4 : -2.4,
        radius: 11, // donut-sized (a donut draws at 9 * 1.25)
        wobble: wobble,
        rotation: 0,
        spin: 0.01,
        type: 'cookie'
      };
    }

    // A cookie raining down in quest levels 1 and 2. Randoms, in order:
    // 1 x, 2 vx, 3 vy, 4 rotation, 5 spin, 6 id (randomId).
    function createQuestCookie(width) {
      var x = 30 + Math.random() * (width - 60);      // 1
      var vx = (Math.random() - 0.5) * 1.2;           // 2
      var vy = 2.2 + Math.random() * 1.6;             // 3
      var rotation = Math.random() * Math.PI * 2;     // 4
      var spin = (Math.random() - 0.5) * 0.08;        // 5
      return {
        id: randomId(),                                // 6
        x: x,
        y: -30,
        vx: vx,
        vy: vy,
        radius: 13,
        rotation: rotation,
        spin: spin,
        type: 'cookie'
      };
    }

    // Burnt cookie: a regular asteroid object (style/tint 'burnt') so every
    // asteroid rule — collisions, shield, ram, shooting, +20 on destroy,
    // debris — applies unchanged; only the off-screen +10 is skipped.
    // Randoms, in order: 1 radius, 2 x, 3 vx, 4 vy, 5 rotation, 6 spinSpeed,
    // 7–16 the ten vertices, 17 id (randomId).
    function createBurntCookie(width, height) {
      var radius = 14 + Math.random() * 10;           // 1
      var x = Math.random() * width;                  // 2
      var vx = (Math.random() - 0.5) * 1.5;           // 3
      var vy = 2.8 + Math.random() * 2.2;             // 4
      var rotation = Math.random() * Math.PI * 2;     // 5
      var spinSpeed = (Math.random() - 0.5) * 0.05;   // 6
      var vertices = [];
      for (var i = 0; i < 10; i++) {
        vertices.push(0.9 + Math.random() * 0.12);    // 7..16
      }
      return {
        id: randomId(),                                // 17
        x: x,
        y: -40,
        vx: vx,
        vy: vy,
        radius: radius,
        color: '#3b2314',
        type: 'asteroid',
        style: 'burnt',
        tint: 'burnt',
        vertices: vertices,
        craters: [],
        speckles: [],
        rotation: rotation,
        spinSpeed: spinSpeed
      };
    }

    // The quest's W orb: appears low on the screen (away from the Giant
    // Cookie's lair at the top) and drifts like the mission's opening orb.
    // Randoms, in order: 1 vx, 2 vy, 3 id (randomId).
    function createQuestWeaponOrb(width, height) {
      var vx = (Math.random() - 0.5) * 1.5;   // 1
      var vy = (Math.random() - 0.5) * 1.5;   // 2
      return {
        id: randomId(),                        // 3
        x: width / 2,
        y: height * 0.72,
        vx: vx,
        vy: vy,
        radius: 12,
        color: '#ef4444',
        type: 'powerup',
        life: 1800,
        maxLife: 1800,
        subType: 'weapon'
      };
    }

    // A little sun for level 3, somewhere in the upper half of the screen,
    // flying in a random direction. Randoms, in order: 1 x, 2 y, 3 angle,
    // 4 speed.
    function createQuestSun(width, height) {
      var x = 60 + Math.random() * (width - 120);          // 1
      var y = 90 + Math.random() * (height * 0.5);         // 2
      var angle = Math.random() * Math.PI * 2;             // 3
      var speed = 1.6 + Math.random() * 0.8;               // 4
      return {
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: QUEST_SUN_RADIUS,
        armTimer: QUEST_SUN_ARM_FRAMES, // harmless (and faint) until this hits 0
        hunter: false // set on the first sun: it chases the nearest ship
      };
    }

    // A burnt cookie asteroid fired by the Giant Cookie between its crumbs:
    // bigger and slower than a crumb, launched along `angle` at 2.4 px/frame
    // with the same ten-vertex outline as the rained ones. Randoms, in
    // order: 1 radius, 2–11 the ten vertices, 12 id (randomId).
    function createBossCookie(x, y, angle) {
      var radius = 20 + Math.random() * 10;           // 1
      var vertices = [];
      for (var i = 0; i < 10; i++) {
        vertices.push(0.9 + Math.random() * 0.12);    // 2..11
      }
      return {
        id: randomId(),                                // 12
        x: x,
        y: y,
        vx: Math.cos(angle) * 2.4,
        vy: Math.sin(angle) * 2.4,
        radius: radius,
        color: '#3b2314',
        type: 'asteroid',
        style: 'burnt',
        tint: 'burnt',
        vertices: vertices,
        craters: [],
        speckles: [],
        rotation: angle,
        spinSpeed: 0.03
      };
    }

    // A crumb fired by the Giant Cookie: a burnt cookie chunk flying along
    // `angle` at 3.2 px/frame. Only random: id (randomId).
    function createCrumb(x, y, angle) {
      return {
        id: randomId(),
        x: x,
        y: y,
        vx: Math.cos(angle) * 3.2,
        vy: Math.sin(angle) * 3.2,
        radius: 13,
        color: '#3b2314',
        type: 'asteroid',
        style: 'burnt',
        tint: 'burnt',
        vertices: CRUMB_VERTICES.slice(),
        craters: [],
        speckles: [],
        rotation: angle,
        spinSpeed: 0.04
      };
    }

    // --- Setup ------------------------------------------------------------

    // --- Phone layout -------------------------------------------------------
    // A phone held upright gets the whole app rotated a quarter turn by CSS
    // (html.rotated) so the game plays landscape. Canvas size and pointer
    // coordinates pass through here so the engine always works in that
    // rotated (landscape) space. Tablets and desktops are never rotated.
    var layout = {
      rotated: false,
      width: function () { return layout.rotated ? window.innerHeight : window.innerWidth; },
      height: function () { return layout.rotated ? window.innerWidth : window.innerHeight; },
      // Screen point -> app point. The CSS transform is rotate(90deg)
      // translateY(-100%) about the top-left corner, so screen x runs down
      // the app's y axis and screen y runs along the app's x axis.
      point: function (sx, sy) {
        return layout.rotated ? { x: sy, y: window.innerWidth - sx } : { x: sx, y: sy };
      },
      update: function () {
        var root = document.documentElement;
        root.style.setProperty('--vw', window.innerWidth + 'px');
        root.style.setProperty('--vh', window.innerHeight + 'px');
        var touch = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
        var phone = touch && Math.min(window.innerWidth, window.innerHeight) <= 600;
        layout.rotated = !!phone && window.innerHeight > window.innerWidth;
        root.classList.toggle('rotated', layout.rotated);
      }
    };
    window.NeonLayout = layout;
    layout.update();

    function resizeCanvas() {
      canvas.width = layout.width();
      canvas.height = layout.height();
    }

    function reset() {
      var hasPlayer2 = config.isLocalMultiplayer || config.isCPUMultiplayer || !!config.online;
      var w = layout.width();
      var h = layout.height();

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
        hitCount: 0,
        difficulty: config.initialDifficulty,
        activeEffects: {
          shield: 0,
          speedBoost: 0,
          weaponUpgrade: 0,
          magnet: 0
        },
        // Secret cookie quest (see QUEST_LEVELS)
        frame: 0,             // update() calls so far this run
        cookieSpawnFrame: -1, // frame the drifting cookie appears on (-1: never)
        cookie: null,         // the drifting cookie while it is on screen
        quest: null           // active quest, see startQuest()
      };

      mousePos = { x: w / 2, y: h / 2 };

      // Fire powers that resize the hull (visuals and collisions both follow radius)
      if (config.flame && config.flame.power === 'tiny') state.player.radius *= 0.7;
      if (config.flame && config.flame.power === 'giant') state.player.radius *= 1.45;
      if (state.player2 && config.flame2 && config.flame2.power === 'tiny') state.player2.radius *= 0.7;
      if (state.player2 && config.flame2 && config.flame2.power === 'giant') state.player2.radius *= 1.45;

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

      // Secret cookie quest: Hard runs only (not Super Hard, never online).
      // One Math.random() here, AFTER the stars and only when eligible, so
      // Easy / Medium / Super Hard / online runs draw exactly what they did
      // before the quest existed.
      var questEligible = config.initialDifficulty >= 1.0 && config.initialDifficulty < 5.0 && !config.online;
      if (!questEligible) {
        state.cookieSpawnFrame = -1;
      } else if (typeof config.cookieSpawnFrame === 'number') {
        state.cookieSpawnFrame = config.cookieSpawnFrame; // test hook: no random consumed
      } else {
        state.cookieSpawnFrame = 1200 + Math.floor(Math.random() * 2401); // 20–60 s in
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
        var followSpeed = Math.min(0.4, (state.activeEffects.speedBoost > 0 ? 0.15 : 0.08) * config.speedFactor * config.flameSpeedMult);
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
        // Mirror Flame's power: keyboard steering is reversed
        if (config.flame && config.flame.power === 'mirror') kbAccel = -kbAccel;
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

      // Wobble Smoke's power: the ship sways like it's a little dizzy
      if (config.flame && config.flame.power === 'wobble') {
        player.x += Math.sin(Date.now() / 180) * 1.8;
        player.y += Math.cos(Date.now() / 230) * 1.4;
      }

      // Clamp Player 1 within screen boundaries (kill into-wall velocity so
      // the ship slides freely along edges instead of sticking — or bounce,
      // if the Bouncy Blast fire is equipped)
      var p1Bounce = config.flame && config.flame.power === 'bouncy';
      var clampedPX = Math.max(player.radius, Math.min(canvas.width - player.radius, player.x));
      var clampedPY = Math.max(player.radius, Math.min(canvas.height - player.radius, player.y));
      if (clampedPX !== player.x) player.vx = p1Bounce ? -player.vx * 0.85 : 0;
      if (clampedPY !== player.y) player.vy = p1Bounce ? -player.vy * 0.85 : 0;
      player.x = clampedPX;
      player.y = clampedPY;
    }

    function updatePlayer2(accel, friction, moveSpeed) {
      var p2 = state.player2;
      if (!p2) return;

      if (config.online) {
        // Online: the guest's ship follows the direction they sent (unit
        // vector), with the same feel as the local arrow keys.
        p2.vx += remoteInput.dx * accel;
        p2.vy += remoteInput.dy * accel;
        p2.vx *= friction;
        p2.vy *= friction;
        var speedNet = Math.sqrt(p2.vx * p2.vx + p2.vy * p2.vy);
        if (speedNet > moveSpeed) {
          p2.vx = (p2.vx / speedNet) * moveSpeed;
          p2.vy = (p2.vy / speedNet) * moveSpeed;
        }
        p2.x += p2.vx;
        p2.y += p2.vy;
        return;
      }

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
      // (the wingman also harvests the cookie quest's raining cookies)
      var pickups = state.collectibles.concat(state.powerUps, state.quest ? state.quest.cookies : []);
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

    // Spawn asteroids. The medium-tier band gets a small density boost so it
    // clearly outnumbers Easy while staying below Hard's starting density.
    // (Also used by cookie quest levels that keep asteroids, with `scale`
    // thinning the density; the random-roll loop is the same either way.)
    function spawnAsteroids(scale) {
      var mediumSpawnBoost = (state.difficulty >= 0.6 && state.difficulty < 1.2) ? 1.45 : 1.0;
      var spawnChance = SPAWN_RATE * Math.pow(state.difficulty, 2) * mediumSpawnBoost * (scale || 1);
      while (spawnChance > 0) {
        if (Math.random() < Math.min(1, spawnChance)) {
          state.asteroids.push(createAsteroid(canvas.width, canvas.height, state.difficulty));
        }
        spawnChance -= 1;
      }
    }

    function updateSpawns() {
      spawnAsteroids(1);

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

    // Magnetic pull when the magnet power-up is active: `c` (a treat, or a
    // quest cookie — both use exactly this math) is sucked toward the
    // nearest ship within 500 px, capped at 10 px/frame. No randoms.
    function applyMagnetPull(c) {
      if (state.activeEffects.magnet <= 0) return;
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

    function updateCollectibles() {
      for (var i = state.collectibles.length - 1; i >= 0; i--) {
        var c = state.collectibles[i];

        applyMagnetPull(c);

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
            var healAmount = (config.isLocalMultiplayer || config.isCPUMultiplayer || config.online) ? 7 : 5;
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
              var damage = (config.isLocalMultiplayer || config.isCPUMultiplayer || config.online) ? 18 : 25;
              // Fire powers: Iron Forge shrugs hits off, Eggshell doubles them
              var hitFlame = p.id === 'player1' ? config.flame : config.flame2;
              if (hitFlame && hitFlame.power === 'armor') damage = Math.round(damage * 0.6);
              if (hitFlame && hitFlame.power === 'fragile') damage *= 2;
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
                state.hitCount++;
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

        // Remove off-screen asteroids (burnt cookies from the cookie quest
        // pay nothing for leaving)
        if (asteroid.x < -100 || asteroid.x > canvas.width + 100 ||
            asteroid.y < -100 || asteroid.y > canvas.height + 100) {
          state.asteroids.splice(i, 1);
          if (asteroid.style !== 'burnt') {
            state.score += 10;
            handlers.onScoreUpdate(state.score);
          }
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

    // --- Secret cookie quest ------------------------------------------------
    // Everything below only runs for local (never online) Hard runs; see
    // reset() for the eligibility rule and update() for where each piece
    // sits in the frame.

    // The drifting cookie: appears on state.cookieSpawnFrame (only while no
    // quest is running — this is only called then), wobbles across the
    // screen and starts the quest when a ship touches it. Runs in
    // updateSpawns()'s slot, right after updateSpawns(). Randoms: the
    // factory's three on the spawn frame; on a catch, startQuest()'s bursts
    // and then the "SECRET LEVEL!" text id.
    function updateDriftingCookie() {
      if (state.frame === state.cookieSpawnFrame && !state.cookie) {
        state.cookie = createDriftingCookie(canvas.width, canvas.height);
      }
      var c = state.cookie;
      if (!c) return;
      c.x += c.vx;
      c.y += Math.sin(state.frame / 25 + c.wobble) * 0.7;
      c.rotation += c.spin;
      var ships = [state.player, state.player2];
      for (var k = 0; k < ships.length; k++) {
        var p = ships[k];
        if (!p) continue;
        var dx = p.x - c.x;
        var dy = p.y - c.y;
        if (Math.sqrt(dx * dx + dy * dy) < c.radius + p.radius + 8) {
          var cx = c.x;
          var cy = c.y;
          startQuest();
          addFloatingText(cx, cy, 'SECRET LEVEL!', COOKIE_GOLD, 1.6);
          shake = 8;
          return;
        }
      }
      // Gone once it is 60 px past the far edge
      if ((c.vx > 0 && c.x > canvas.width + 60) || (c.vx < 0 && c.x < -60)) {
        state.cookie = null;
      }
    }

    // Catching the cookie: wipe the field — every asteroid bursts into 6 of
    // its own-colored particles (createParticle, asteroid array order), then
    // asteroids, orbs and treats are cleared — and level 1's intro begins.
    function startQuest() {
      for (var i = 0; i < state.asteroids.length; i++) {
        var a = state.asteroids[i];
        for (var n = 0; n < 6; n++) state.particles.push(createParticle(a.x, a.y, a.color));
      }
      state.asteroids = [];
      state.powerUps = [];
      state.collectibles = [];
      state.cookie = null;
      state.quest = {
        level: 1,
        phase: 'intro',   // 'intro' | 'play' | 'won' | 'complete' | 'failed'
        phaseTimer: 120,  // frames left in a banner phase
        timer: 0,         // play frames elapsed in this level
        goal: QUEST_LEVELS[0].goal,
        collected: 0,
        cookies: [],      // the raining quest cookies
        boss: null,       // the Giant Cookie (level 3 only)
        suns: []          // the lethal little suns (level 3 only)
      };
      handlers.onQuestEvent('start', 1);
    }

    function questLevelDef() {
      return QUEST_LEVELS[state.quest.level - 1];
    }

    // intro -> play: level 3 gets its boss (no randoms) and then its
    // QUEST_SUN_COUNT suns (createQuestSun's 4 draws each); every level then
    // drops a W orb (createQuestWeaponOrb's 3 draws) — the blasters have to
    // be picked up.
    function beginQuestPlay() {
      var q = state.quest;
      q.phase = 'play';
      q.timer = 0;
      if (q.level === 3) {
        q.boss = {
          x: canvas.width / 2,
          y: canvas.height * 0.28,
          vx: 4.8,
          vy: 2.9,
          radius: 58,
          hp: config.questBossHP || QUEST_BOSS_HP,
          maxHp: config.questBossHP || QUEST_BOSS_HP,
          rotation: 0,
          hitFlash: 0,
          contactCooldown: 0 // ship-bump immunity frames (see updateQuestBoss)
        };
        for (var i = 0; i < QUEST_SUN_COUNT; i++) {
          q.suns.push(createQuestSun(canvas.width, canvas.height));
        }
        q.suns[0].hunter = true; // the first sun hunts
      }
      state.powerUps.push(createQuestWeaponOrb(canvas.width, canvas.height));
    }

    function hasWeaponOrbWaiting() {
      for (var i = 0; i < state.powerUps.length; i++) {
        if (state.powerUps[i].subType === 'weapon') return true;
      }
      return false;
    }

    function questLevelWon() {
      var q = state.quest;
      q.phase = 'won';
      q.phaseTimer = 120;
      q.boss = null;
      q.suns = [];
      handlers.onQuestEvent('levelWon', q.level);
    }

    function questFailed() {
      var q = state.quest;
      q.phase = 'failed';
      q.phaseTimer = 120;
      q.boss = null;
      q.suns = [];
      handlers.onQuestEvent('failed', q.level);
    }

    // Phase machine + per-frame spawn rolls + boss motion. Runs in
    // updateSpawns()'s slot while a quest is active (after the players,
    // shooting, the effects tick and the wall clamp; before projectiles
    // move), so no asteroids, treats or orbs spawn during a quest.
    // Randoms per play frame, in order: the normal asteroid spawn rolls
    // (levels with `asteroids`, exactly as spawnAsteroids() draws them), then
    // the cookie-rain roll (levels 1–2;
    // not rolled when `rain` is 0), then the burnt-cookie roll (levels 2–3;
    // not rolled when `burnt` is 0), each followed by its factory's draws on
    // a hit; then, on level 3 every 150th play frame, the 8 crumb ids followed
    // by the 4 boss cookies' draws (createBossCookie, on the diagonals); then,
    // on level 3 every 450th play frame with the ship unarmed and no W orb
    // waiting, the re-supply orb's 3 draws. Banner phases and the intro draw
    // nothing.
    function updateQuest() {
      var q = state.quest;
      var def = questLevelDef();
      if (q.phase === 'intro') {
        q.phaseTimer--;
        if (q.phaseTimer <= 0) beginQuestPlay();
        return;
      }
      if (q.phase === 'play') {
        q.timer++;
        if (def.asteroids) spawnAsteroids(def.asteroids);
        if (def.rain > 0 && Math.random() < def.rain) {
          q.cookies.push(createQuestCookie(canvas.width));
        }
        if (def.burnt > 0 && Math.random() < def.burnt) {
          state.asteroids.push(createBurntCookie(canvas.width, canvas.height));
        }
        var b = q.boss;
        if (b) {
          b.x += b.vx;
          b.y += b.vy;
          b.rotation += 0.004;
          // Bounce off the world bounds, `radius` in from each edge
          if (b.x < b.radius) { b.x = b.radius; b.vx = Math.abs(b.vx); }
          if (b.x > canvas.width - b.radius) { b.x = canvas.width - b.radius; b.vx = -Math.abs(b.vx); }
          if (b.y < b.radius) { b.y = b.radius; b.vy = Math.abs(b.vy); }
          if (b.y > canvas.height - b.radius) { b.y = canvas.height - b.radius; b.vy = -Math.abs(b.vy); }
          if (b.hitFlash > 0) b.hitFlash--;
          if (b.contactCooldown > 0) b.contactCooldown--;
          if (q.timer % QUEST_BOSS_FIRE_INTERVAL === 0) {
            for (var i = 0; i < 8; i++) {
              var ang = (i / 8) * Math.PI * 2;
              state.asteroids.push(createCrumb(
                b.x + Math.cos(ang) * (b.radius + 12),
                b.y + Math.sin(ang) * (b.radius + 12),
                ang));
            }
            // ...and four burnt cookie asteroids on the diagonals between them
            for (var k = 0; k < 4; k++) {
              var cang = ((k + 0.5) / 4) * Math.PI * 2;
              state.asteroids.push(createBossCookie(
                b.x + Math.cos(cang) * (b.radius + 18),
                b.y + Math.sin(cang) * (b.radius + 18),
                cang));
            }
          }
        }
        if (q.level === 3 && q.timer % QUEST_WEAPON_RESUPPLY === 0 &&
            state.activeEffects.weaponUpgrade <= 0 && !hasWeaponOrbWaiting()) {
          state.powerUps.push(createQuestWeaponOrb(canvas.width, canvas.height));
        }
        if (q.timer >= def.duration) questFailed();
        return;
      }
      // Banner phases: 'won', 'failed', 'complete'
      q.phaseTimer--;
      if (q.phaseTimer > 0) return;
      if (q.phase === 'won') {
        if (q.level < 3) {
          q.level++;
          q.phase = 'intro';
          q.phaseTimer = 120;
          q.timer = 0;
          q.goal = QUEST_LEVELS[q.level - 1].goal;
          q.collected = 0;
          q.cookies = [];
        } else {
          q.phase = 'complete';
          q.phaseTimer = 180;
          handlers.onQuestComplete();
        }
      } else {
        state.quest = null; // 'complete' or 'failed': back to the nebula
      }
    }

    // Quest cookies fall (magnet pulls them exactly like treats) and are
    // picked up during the play phase: +50, collected++. Runs right after
    // updateCollectibles(). Randoms per pickup, in order: the "+50" text
    // id, then createShockwaveRing's 6 particles (life + id each).
    function updateQuestCookies() {
      var q = state.quest;
      for (var i = q.cookies.length - 1; i >= 0; i--) {
        var c = q.cookies[i];
        applyMagnetPull(c);
        c.x += c.vx;
        c.y += c.vy;
        c.rotation += c.spin;
        // Gone below the screen (or flung far off by the magnet)
        if (c.y > canvas.height + 40 || c.y < -300 || c.x < -300 || c.x > canvas.width + 300) {
          q.cookies.splice(i, 1);
          continue;
        }
        if (q.phase !== 'play') continue;
        var players = [state.player, state.player2];
        for (var k = 0; k < players.length; k++) {
          var p = players[k];
          if (!p) continue;
          var dx = p.x - c.x;
          var dy = p.y - c.y;
          if (Math.sqrt(dx * dx + dy * dy) < c.radius + p.radius + 10) {
            state.score += 50;
            q.collected++;
            handlers.onScoreUpdate(state.score);
            addFloatingText(c.x, c.y, '+50', COOKIE_GOLD, 0.95);
            createShockwaveRing(c.x, c.y, COOKIE_COLOR, 6);
            q.cookies.splice(i, 1);
            if (q.collected >= q.goal && q.level < 3) questLevelWon();
            break;
          }
        }
      }
    }

    // The Giant Cookie's collisions. Runs right after updateAsteroids().
    // Projectiles within radius + 4 hit (+5, hp--, flash, ring); a ship
    // touching it is pushed out along the normal with its inward velocity
    // zeroed and takes the asteroid damage path (overthrusters: no damage,
    // the boss is NOT destroyed; shield absorbs; else hull damage with the
    // armor/fragile rules), with a 45-frame contact cooldown so one bump
    // doesn't drain the hull every frame. Randoms, in order: per projectile
    // hit (projectile array order, last to first; the loop stops once hp
    // reaches 0) the ring's 5 particles; if hp <= 0: 3 rings of 16, 40
    // createParticle, the "COOKIE JAR CRACKED!" text id; else per ship bump
    // the same particles/text as the matching asteroid-hit branch.
    // Level 3's suns: fly (the hunter steers toward the nearest ship, the
    // others bounce off the world bounds), warm up, and burn any ship that
    // touches one once armed — instant death, no shield, no armor. Runs right
    // after updateQuestBoss(). Randoms on a burn, in order: the "SOLAR
    // FLARE!" text id, the ring's 22 particles, then 16 createParticle.
    function updateQuestSuns() {
      var q = state.quest;
      for (var i = 0; i < q.suns.length; i++) {
        var sun = q.suns[i];
        if (sun.hunter) {
          // Steer toward the nearest ship, capped at the hunter's speed
          var target = null, best = Infinity;
          [state.player, state.player2].forEach(function (sp) {
            if (!sp) return;
            var tdx = sp.x - sun.x, tdy = sp.y - sun.y;
            var td = Math.sqrt(tdx * tdx + tdy * tdy);
            if (td < best) { best = td; target = sp; }
          });
          if (target && best > 0) {
            sun.vx += ((target.x - sun.x) / best) * QUEST_HUNTER_ACCEL;
            sun.vy += ((target.y - sun.y) / best) * QUEST_HUNTER_ACCEL;
            var sp2 = Math.sqrt(sun.vx * sun.vx + sun.vy * sun.vy);
            if (sp2 > QUEST_HUNTER_SPEED) {
              sun.vx = (sun.vx / sp2) * QUEST_HUNTER_SPEED;
              sun.vy = (sun.vy / sp2) * QUEST_HUNTER_SPEED;
            }
          }
        }
        sun.x += sun.vx;
        sun.y += sun.vy;
        if (sun.x < sun.radius) { sun.x = sun.radius; sun.vx = Math.abs(sun.vx); }
        if (sun.x > canvas.width - sun.radius) { sun.x = canvas.width - sun.radius; sun.vx = -Math.abs(sun.vx); }
        if (sun.y < sun.radius) { sun.y = sun.radius; sun.vy = Math.abs(sun.vy); }
        if (sun.y > canvas.height - sun.radius) { sun.y = canvas.height - sun.radius; sun.vy = -Math.abs(sun.vy); }
        if (sun.armTimer > 0) sun.armTimer--;
      }
      if (q.phase !== 'play' || state.dying) return;
      var ships = [state.player, state.player2];
      for (var s = 0; s < q.suns.length; s++) {
        var hot = q.suns[s];
        if (hot.armTimer > 0) continue;
        for (var k = 0; k < ships.length; k++) {
          var p = ships[k];
          if (!p) continue;
          var dx = p.x - hot.x;
          var dy = p.y - hot.y;
          if (Math.sqrt(dx * dx + dy * dy) >= hot.radius + p.radius - 2) continue;
          state.health = 0;
          handlers.onHealthUpdate(state.health);
          shake = 24;
          addFloatingText(p.x, p.y, 'SOLAR FLARE!', SUN_COLOR, 1.3);
          createShockwaveRing(hot.x, hot.y, SUN_COLOR, 22);
          for (var n = 0; n < 16; n++) state.particles.push(createParticle(p.x, p.y, '#fde68a'));
          startDeathSequence(p, { x: hot.x, y: hot.y, color: SUN_COLOR });
          return;
        }
      }
    }

    function updateQuestBoss() {
      var q = state.quest;
      var b = q.boss;
      if (q.phase !== 'play') return;
      for (var j = state.projectiles.length - 1; j >= 0; j--) {
        var proj = state.projectiles[j];
        var pdx = proj.x - b.x;
        var pdy = proj.y - b.y;
        if (Math.sqrt(pdx * pdx + pdy * pdy) < b.radius + 4) {
          state.projectiles.splice(j, 1);
          b.hp--;
          b.hitFlash = 8;
          state.score += 5;
          handlers.onScoreUpdate(state.score);
          createShockwaveRing(proj.x, proj.y, COOKIE_COLOR, 5);
          if (b.hp <= 0) break;
        }
      }
      if (b.hp <= 0) {
        var colors = [COOKIE_COLOR, '#8b5a2b', '#fde68a'];
        for (var r = 0; r < 3; r++) createShockwaveRing(b.x, b.y, colors[r], 16);
        for (var n = 0; n < 40; n++) state.particles.push(createParticle(b.x, b.y, colors[n % 3]));
        addFloatingText(b.x, b.y, 'COOKIE JAR CRACKED!', COOKIE_GOLD, 1.8);
        state.score += 500;
        handlers.onScoreUpdate(state.score);
        shake = 18;
        questLevelWon();
        return;
      }
      var ships = [state.player, state.player2];
      for (var k = 0; k < ships.length; k++) {
        var p = ships[k];
        if (!p) continue;
        var dx = p.x - b.x;
        var dy = p.y - b.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist >= b.radius + p.radius) continue;
        var nx = dist > 0 ? dx / dist : 0;
        var ny = dist > 0 ? dy / dist : -1;
        // Push the ship out along the normal and kill its inward velocity
        p.x = b.x + nx * (b.radius + p.radius);
        p.y = b.y + ny * (b.radius + p.radius);
        var dot = p.vx * nx + p.vy * ny;
        if (dot < 0) {
          p.vx -= dot * nx;
          p.vy -= dot * ny;
        }
        if (state.activeEffects.speedBoost > 0) {
          // Ramming only bounces the ship off — the jar doesn't budge
          shake = 5;
          for (var s = 0; s < 8; s++) state.particles.push(createParticle(p.x, p.y, '#22c55e'));
          continue;
        }
        if (b.contactCooldown > 0) continue;
        b.contactCooldown = QUEST_BOSS_CONTACT_COOLDOWN;
        if (state.activeEffects.shield > 0) {
          state.activeEffects.shield = Math.max(0, state.activeEffects.shield - 100);
          shake = 6;
          addFloatingText(p.x, p.y, 'SHIELD ABSORBED', '#a855f7', 0.95);
          createShockwaveRing(p.x, p.y, '#a855f7', 15);
          for (var t = 0; t < 10; t++) state.particles.push(createParticle(p.x, p.y, '#a855f7'));
        } else {
          var damage = (config.isLocalMultiplayer || config.isCPUMultiplayer || config.online) ? 18 : 25;
          var hitFlame = p.id === 'player1' ? config.flame : config.flame2;
          if (hitFlame && hitFlame.power === 'armor') damage = Math.round(damage * 0.6);
          if (hitFlame && hitFlame.power === 'fragile') damage *= 2;
          state.health -= damage;
          handlers.onHealthUpdate(state.health);
          shake = 22;
          addFloatingText(p.x, p.y, '-' + damage + '% HULL DAMAGE', '#ff0000', 1.25);
          createShockwaveRing(p.x, p.y, '#ff0000', 20);
          for (var u = 0; u < 12; u++) state.particles.push(createParticle(p.x, p.y, '#ff0000'));
          if (state.health <= 0) {
            startDeathSequence(p, { x: b.x, y: b.y, color: COOKIE_COLOR });
            return;
          }
          state.hitCount++;
          handlers.onHit();
        }
      }
    }

    function update() {
      if (isPaused || !state || state.isGameOver) return;
      state.frame++; // counts every simulated frame (cookie quest timing)

      if (config.online && config.online.role === 'guest') {
        // The host simulates; we mirror it. Keep the star parallax local so
        // the backdrop stays smooth between snapshots.
        for (var gs = 0; gs < stars.length; gs++) {
          stars[gs].y += stars[gs].s * 0.5;
          if (stars[gs].y > canvas.height) stars[gs].y = 0;
        }
        for (var gm = 0; gm < MOVE_KEYS.length; gm++) {
          if (keysPressed[MOVE_KEYS[gm]]) { controlMode = 'keyboard'; break; }
        }
        if (pendingSnapshot) {
          var snap = pendingSnapshot;
          pendingSnapshot = null;
          applySnapshot(snap);
        }
        return;
      }

      if (state.dying) {
        updateDeathSequence();
        return;
      }

      // Background stars parallax
      for (var i = 0; i < stars.length; i++) {
        stars[i].y += stars[i].s * 0.5;
        if (stars[i].y > canvas.height) stars[i].y = 0;
      }

      var moveSpeed = (state.activeEffects.speedBoost > 0 ? 8 : 5) * config.speedFactor * config.flameSpeedMult;
      var accel = 0.5 * config.speedFactor * config.flameSpeedMult;
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
      if (!state.quest) updateDifficulty(); // difficulty is frozen during the cookie quest

      // Magnet Muzzle: the treat magnet never switches off (kept one tick
      // ahead of the per-frame decay below)
      if (config.flame && config.flame.power === 'magnet' && state.activeEffects.magnet < 2) {
        state.activeEffects.magnet = 2;
      }

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
      var p1Bouncy = config.flame && config.flame.power === 'bouncy';
      for (var b = 0; b < players.length; b++) {
        var p = players[b];
        if (!p) continue;
        var clampedX = Math.max(p.radius, Math.min(canvas.width - p.radius, p.x));
        var clampedY = Math.max(p.radius, Math.min(canvas.height - p.radius, p.y));
        var bounce = p1Bouncy && p === state.player;
        if (clampedX !== p.x) p.vx = bounce ? -p.vx * 0.85 : 0;
        if (clampedY !== p.y) p.vy = bounce ? -p.vy * 0.85 : 0;
        p.x = clampedX;
        p.y = clampedY;
      }

      if (state.quest) {
        // Cookie quest: no asteroid/treat/orb spawns; cookie rain, burnt
        // cookies and the boss's motion instead.
        updateQuest();
      } else {
        updateSpawns();
        updateDriftingCookie(); // the secret cookie: spawn on its frame, drift, catch
      }

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

      updateCollectibles();
      if (state.quest) updateQuestCookies(); // raining cookies: fall, magnet, pickup
      updateAsteroids();
      if (state.quest && state.quest.boss) updateQuestBoss(); // Giant Cookie: shots, ship bumps, death
      if (state.quest && state.quest.suns.length) updateQuestSuns(); // level 3's lethal suns

      // Magnet burns twice as fast as the other effects (also ticked in the
      // effects loop above). This second tick must come AFTER
      // updateCollectibles(): the Magnet Muzzle fire power tops the effect up
      // to 2 each frame, and ticking twice before the pull ran left it at 0
      // exactly when updateCollectibles() checked it, so the power did nothing.
      if (state.activeEffects.magnet > 0) {
        state.activeEffects.magnet -= 1;
      }

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

    // Charred cookie — the cookie quest's burnt cookies and crumbs. A round
    // silhouette from the vertex list, a charred edge and 5 darker chips
    // placed from the vertices, so nothing is random at draw time.
    function drawBurntCookie(a) {
      var R = a.radius;
      var P = ASTEROID_PALETTES.burnt;
      var g = ctx.createRadialGradient(-R * 0.3, -R * 0.3, R * 0.1, 0, 0, R);
      g.addColorStop(0, P.gradient[0]);
      g.addColorStop(0.6, P.gradient[1]);
      g.addColorStop(1, P.gradient[2]);
      ctx.fillStyle = g;
      ctx.shadowBlur = 10;
      ctx.shadowColor = P.glow;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = P.outline; // charred edge
      ctx.stroke();

      ctx.save();
      ctx.clip();
      ctx.fillStyle = P.hole;
      for (var k = 0; k < BURNT_CHIPS.length; k++) {
        var chip = BURNT_CHIPS[k];
        ctx.beginPath();
        ctx.arc(chip[0] * R, chip[1] * R, chip[2] * R, 0, Math.PI * 2);
        ctx.fill();
      }
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
        else if (a.style === 'burnt') drawBurntCookie(a);
        else drawRockyAsteroid(a);
        ctx.restore();
      });
    }

    // --- Secret cookie quest: drawing (no Math.random() anywhere here) ------

    // A chocolate-chip cookie disc in local coordinates: tan dough with a
    // soft glow and a scattered handful of chips (one of the layouts above).
    function drawCookieDisc(R, rotation, chips) {
      ctx.save();
      ctx.rotate(rotation);
      var g = ctx.createRadialGradient(-R * 0.3, -R * 0.3, R * 0.1, 0, 0, R);
      g.addColorStop(0, '#f1c27d');
      g.addColorStop(0.7, '#d4a373');
      g.addColorStop(1, '#a86f3a');
      ctx.beginPath();
      ctx.arc(0, 0, R, 0, Math.PI * 2);
      ctx.fillStyle = g;
      ctx.shadowBlur = 14;
      ctx.shadowColor = COOKIE_COLOR;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = '#8b5a2b';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.fillStyle = '#3b2314';
      for (var i = 0; i < chips.length; i++) {
        ctx.beginPath();
        ctx.arc(chips[i][0] * R, chips[i][1] * R, chips[i][2] * R, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    // Outline of a cookie with a bite out of its upper right, as one path:
    // the disc's arc around to the bite, then the bite circle's inner arc
    // back to the start (so it can be filled, stroked and clipped as one).
    function traceBittenCookie(R) {
      var TAU = Math.PI * 2;
      var theta = -Math.PI / 4; // bite direction
      var d = R * 0.92;         // bite circle center distance
      var r = R * 0.42;         // bite circle radius
      var cx = Math.cos(theta) * d;
      var cy = Math.sin(theta) * d;
      var alpha = Math.acos((R * R + d * d - r * r) / (2 * R * d));
      var a1 = theta + alpha;
      var a2 = theta - alpha;
      var p1x = Math.cos(a1) * R;
      var p1y = Math.sin(a1) * R;
      var p2x = Math.cos(a2) * R;
      var p2y = Math.sin(a2) * R;
      ctx.beginPath();
      ctx.arc(0, 0, R, a1, a2 + TAU);
      var b2 = Math.atan2(p2y - cy, p2x - cx);
      var b1 = Math.atan2(p1y - cy, p1x - cx);
      var mid = theta + Math.PI; // the bite arc inside the disc faces the center
      var clockwise = ((mid - b2 + TAU * 2) % TAU) < ((b1 - b2 + TAU * 2) % TAU);
      ctx.arc(cx, cy, r, b2, b1, !clockwise);
      ctx.closePath();
    }

    // The Giant Cookie: a big bitten cookie with chips, a white flash while
    // hitFlash > 0 and an hp bar above it.
    function drawQuestBoss(b) {
      var R = b.radius;
      ctx.save();
      ctx.translate(b.x, b.y);
      ctx.rotate(b.rotation);
      traceBittenCookie(R);
      var g = ctx.createRadialGradient(-R * 0.3, -R * 0.3, R * 0.1, 0, 0, R);
      g.addColorStop(0, '#f1c27d');
      g.addColorStop(0.7, '#d4a373');
      g.addColorStop(1, '#a86f3a');
      ctx.fillStyle = g;
      ctx.shadowBlur = 28;
      ctx.shadowColor = COOKIE_COLOR;
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = '#8b5a2b';
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.save();
      ctx.clip();
      ctx.fillStyle = '#3b2314';
      var chips = [[-0.45, -0.35], [0.1, -0.55], [-0.6, 0.2], [0, 0.05], [0.5, 0.3], [-0.25, 0.6], [0.3, 0.65]];
      for (var i = 0; i < chips.length; i++) {
        ctx.beginPath();
        ctx.arc(chips[i][0] * R, chips[i][1] * R, R * (0.11 + 0.02 * (i % 3)), 0, Math.PI * 2);
        ctx.fill();
      }
      if (b.hitFlash > 0) {
        ctx.fillStyle = 'rgba(255, 255, 255, ' + (0.7 * b.hitFlash / 8) + ')';
        ctx.fillRect(-R, -R, R * 2, R * 2);
      }
      ctx.restore();
      ctx.restore();

      // HP bar above the jar: dark track, gold fill
      var w = 110;
      var h = 7;
      var x = b.x - w / 2;
      var y = b.y - R - 22;
      ctx.save();
      ctx.fillStyle = 'rgba(9, 12, 28, 0.8)';
      roundedRect(x - 1, y - 1, w + 2, h + 2, 4);
      ctx.fill();
      ctx.fillStyle = COOKIE_GOLD;
      ctx.shadowBlur = 8;
      ctx.shadowColor = COOKIE_GOLD;
      roundedRect(x, y, w * Math.max(0, b.hp / b.maxHp), h, 3);
      ctx.fill();
      ctx.restore();
    }

    // A little sun in classic clipart style: a bright yellow disc with a bold
    // orange outline and a ring of 12 pointed triangular rays (long and
    // short alternating), slowly turning. No face. Faint and pulsing while
    // it is still warming up. Nothing random here.
    function drawQuestSun(sun) {
      var R = sun.radius;
      var t = Date.now() / 1000;
      var arming = sun.armTimer > 0;
      ctx.save();
      ctx.translate(sun.x, sun.y);
      ctx.rotate(t * (sun.hunter ? 1.8 : 0.6));
      ctx.globalAlpha = arming ? 0.35 + 0.35 * (1 - sun.armTimer / QUEST_SUN_ARM_FRAMES) + 0.15 * Math.sin(t * 18) : 1;
      ctx.lineJoin = 'round';
      ctx.shadowBlur = 18;
      ctx.shadowColor = sun.hunter ? '#ef4444' : SUN_COLOR;
      // Rays: triangles rooted just inside the disc edge (red-hot on the hunter)
      ctx.fillStyle = sun.hunter ? '#f87171' : '#fb923c';
      ctx.strokeStyle = sun.hunter ? '#991b1b' : '#c2410c';
      ctx.lineWidth = 1.5;
      for (var i = 0; i < 12; i++) {
        var a = i * (Math.PI / 6);
        var tip = R * (i % 2 ? 1.6 : 2.0);
        var half = 0.26; // half the ray's angular width at its base
        ctx.beginPath();
        ctx.moveTo(Math.cos(a - half) * R * 0.92, Math.sin(a - half) * R * 0.92);
        ctx.lineTo(Math.cos(a) * tip, Math.sin(a) * tip);
        ctx.lineTo(Math.cos(a + half) * R * 0.92, Math.sin(a + half) * R * 0.92);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }
      ctx.shadowBlur = 0;
      // Body: yellow disc shading to orange at the rim, bold outline
      var g = ctx.createRadialGradient(-R * 0.25, -R * 0.25, R * 0.1, 0, 0, R);
      g.addColorStop(0, '#fef9c3');
      g.addColorStop(0.5, '#fde047');
      g.addColorStop(1, '#f59e0b');
      ctx.beginPath();
      ctx.arc(0, 0, R, 0, Math.PI * 2);
      ctx.fillStyle = g;
      ctx.fill();
      ctx.strokeStyle = '#c2410c';
      ctx.lineWidth = 2.2;
      ctx.stroke();
      ctx.restore();
    }

    // Drifting cookie, raining quest cookies, the boss and its suns — drawn
    // after the asteroids and before the ships.
    function drawCookies() {
      if (state.cookie) {
        ctx.save();
        ctx.translate(state.cookie.x, state.cookie.y);
        drawCookieDisc(state.cookie.radius, state.cookie.rotation, cookieChipLayout(state.cookie.id));
        ctx.restore();
      }
      if (!state.quest) return;
      state.quest.cookies.forEach(function (c) {
        ctx.save();
        ctx.translate(c.x, c.y);
        drawCookieDisc(c.radius, c.rotation, cookieChipLayout(c.id));
        ctx.restore();
      });
      if (state.quest.boss) drawQuestBoss(state.quest.boss);
      state.quest.suns.forEach(drawQuestSun);
    }

    function formatClock(frames) {
      var secs = Math.max(0, Math.ceil(frames / 60));
      var m = Math.floor(secs / 60);
      var s = secs % 60;
      return m + ':' + (s < 10 ? '0' : '') + s;
    }

    // Quest status line under the HUD bar plus the phase banners (drawn
    // last, after the tutorial card).
    function drawQuestOverlay() {
      var q = state.quest;
      if (!q) return;
      var def = QUEST_LEVELS[q.level - 1];
      var cx = canvas.width / 2;
      ctx.save();
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      var progress = q.level === 3
        ? 'GIANT COOKIE ' + (q.boss ? (q.boss.maxHp - q.boss.hp) + '/' + q.boss.maxHp : QUEST_BOSS_HP + '/' + QUEST_BOSS_HP)
        : q.collected + '/' + q.goal + ' COOKIES';
      ctx.font = '12px monospace';
      ctx.fillStyle = '#fde68a';
      ctx.shadowBlur = 10;
      ctx.shadowColor = COOKIE_GOLD;
      ctx.fillText('SECRET LEVEL ' + q.level + '/3 · ' + def.name + ' · ' + progress + ' · ' +
        formatClock(def.duration - q.timer), cx, 120);

      var title = null;
      var sub = null;
      var total = 0;
      if (q.phase === 'intro') {
        title = 'SECRET LEVEL ' + q.level;
        sub = def.name + ' · ' + def.hint;
        total = 120;
      } else if (q.phase === 'won') {
        title = 'LEVEL CLEARED!';
        total = 120;
      } else if (q.phase === 'failed') {
        title = "TIME'S UP";
        sub = 'BACK TO THE NEBULA';
        total = 120;
      } else if (q.phase === 'complete') {
        title = 'COOKIE QUEST COMPLETE!';
        sub = '+1000 COINS · 3 SECRET SKINS UNLOCKED';
        total = 180;
      }
      if (title) {
        // fade in over the first 15 frames, out over the last 20
        var alpha = Math.max(0, Math.min(1, (total - q.phaseTimer) / 15, q.phaseTimer / 20));
        ctx.globalAlpha = alpha;
        ctx.font = '900 34px sans-serif';
        ctx.fillStyle = COOKIE_GOLD;
        ctx.shadowBlur = 24;
        ctx.shadowColor = COOKIE_GOLD;
        ctx.fillText(title, cx, canvas.height / 2 - 30);
        if (sub) {
          ctx.font = 'bold 14px monospace';
          ctx.fillStyle = '#fde68a';
          ctx.shadowBlur = 10;
          ctx.fillText(sub, cx, canvas.height / 2 + 10);
        }
      }
      ctx.restore();
    }

    function drawShips() {
      if (state.shipsDestroyed) return;
      [state.player, state.player2].forEach(function (p) {
        if (!p) return;

        // Calculate tilt based on horizontal speed
        var tilt;
        if (config.isLocalMultiplayer || config.isCPUMultiplayer || config.online || p.id === 'player2' || controlMode === 'keyboard') {
          tilt = p.vx * 0.04;
        } else {
          tilt = (mousePos.x - p.x) * 0.01;
        }
        tilt = Math.max(-0.45, Math.min(0.45, tilt));

        ctx.save();
        ctx.translate(p.x, p.y);
        // The Ring Burner's power: the ship pinwheels nonstop (visual only)
        var ownFlame = p.id === 'player1' ? config.flame : config.flame2;
        var flameSpin = (ownFlame && ownFlame.power === 'spin' &&
          !isPaused && !state.isGameOver && !state.dying)
          ? (Date.now() / 200) % (Math.PI * 2) : 0;
        ctx.rotate(tilt + flameSpin);

        var R = p.radius;

        // Each pilot flies their own Tailor skin (player 2 only has one in
        // local two-player; the CPU wingman keeps stock colors).
        var skin = (p.id === 'player1' ? config.skin : config.skin2) || null;
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

        // --- Rocket exhaust (behind the body); the fire style is Tailor gear ---
        if (!isPaused && !state.isGameOver && !state.dying) {
          var flameDef = ownFlame || null;
          var fStyle = flameDef ? flameDef.style : 'classic';
          var flick = 0.8 + 0.35 * Math.abs(Math.sin(Date.now() / 47 + p.x)) + Math.random() * 0.15;

          if (fStyle === 'rings') {
            // Expanding exhaust rings instead of a flame
            var ringCols = (flameDef && flameDef.ringColors) || ['#fb923c', '#fbbf24', '#fde68a'];
            ctx.lineWidth = 3;
            for (var ri = 0; ri < 3; ri++) {
              ctx.beginPath();
              ctx.arc(0, R * (1.4 + ri * 0.5 * flick), R * (0.3 - ri * 0.06), 0, Math.PI * 2);
              ctx.strokeStyle = ringCols[ri % ringCols.length];
              ctx.globalAlpha = 1 - ri * 0.28;
              ctx.shadowBlur = 12;
              ctx.shadowColor = ringCols[0];
              ctx.stroke();
            }
            ctx.globalAlpha = 1;
            ctx.shadowBlur = 0;
          } else if (fStyle === 'smoke') {
            // Chuffing smoke puffs
            for (var si = 0; si < 3; si++) {
              ctx.beginPath();
              ctx.arc(Math.sin(Date.now() / 150 + si * 2) * R * 0.15,
                R * (1.32 + si * 0.45), R * (0.28 + si * 0.05) * flick, 0, Math.PI * 2);
              ctx.fillStyle = ((flameDef && flameDef.smokeColors) || ['#94a3b8', '#cbd5e1', '#e2e8f0'])[si];
              ctx.globalAlpha = 0.75 - si * 0.22;
              ctx.fill();
            }
            ctx.globalAlpha = 1;
          } else if (fStyle === 'stars') {
            // Twinkling star sparks
            var sa = Date.now() / 250;
            var starCol = (flameDef && flameDef.starColor) || '#fde047';
            for (var ti = 0; ti < 3; ti++) {
              var sr = R * (0.24 - ti * 0.04) * flick;
              ctx.save();
              ctx.translate(Math.sin(sa + ti * 2) * R * 0.14, R * (1.38 + ti * 0.5));
              ctx.rotate(sa + ti);
              ctx.strokeStyle = starCol;
              ctx.lineWidth = 2;
              ctx.shadowBlur = 10;
              ctx.shadowColor = starCol;
              ctx.globalAlpha = 1 - ti * 0.25;
              ctx.beginPath();
              ctx.moveTo(-sr, 0);
              ctx.lineTo(sr, 0);
              ctx.moveTo(0, -sr);
              ctx.lineTo(0, sr);
              ctx.stroke();
              ctx.restore();
            }
            ctx.globalAlpha = 1;
            ctx.shadowBlur = 0;
          } else {
            // Layered flame tongues: classic orange, blue, the narrow jet, or
            // any custom palette (pal/glow) the equipped fire specifies.
            var pal, glow, wMul, lMul;
            if (fStyle === 'blue') {
              pal = ['rgba(37, 99, 235, 0.85)', 'rgba(96, 165, 250, 0.95)', 'rgba(224, 242, 254, 0.95)'];
              glow = '#60a5fa'; wMul = 1; lMul = 1;
            } else if (fStyle === 'jet') {
              pal = ['rgba(34, 211, 238, 0.85)', 'rgba(165, 243, 252, 0.95)', 'rgba(255, 255, 255, 0.95)'];
              glow = '#22d3ee'; wMul = 0.55; lMul = 1.6;
            } else {
              pal = ['rgba(249, 115, 22, 0.85)', 'rgba(251, 191, 36, 0.95)', 'rgba(224, 242, 254, 0.95)'];
              glow = '#fb923c'; wMul = 1; lMul = 1;
            }
            if (flameDef && flameDef.animatedPal) {
              var fh = Math.floor((Date.now() / 12) % 360);
              pal = ['hsla(' + fh + ', 90%, 55%, 0.85)', 'hsla(' + ((fh + 45) % 360) + ', 90%, 65%, 0.95)', 'rgba(255, 255, 255, 0.95)'];
              glow = 'hsl(' + fh + ', 90%, 60%)';
            } else if (flameDef && flameDef.pal) {
              pal = flameDef.pal;
              glow = flameDef.glow || '#fb923c';
            }
            if (flameDef && flameDef.style === 'jet' && flameDef.pal) {
              wMul = 0.55; lMul = 1.6;
            }
            var flameLen = R * 1.0 * flick * lMul;
            ctx.beginPath();
            ctx.moveTo(-R * 0.34 * wMul, R * 1.1);
            ctx.quadraticCurveTo(-R * 0.28 * wMul, R * 1.1 + flameLen * 0.7, 0, R * 1.1 + flameLen);
            ctx.quadraticCurveTo(R * 0.28 * wMul, R * 1.1 + flameLen * 0.7, R * 0.34 * wMul, R * 1.1);
            ctx.closePath();
            ctx.fillStyle = pal[0];
            ctx.shadowBlur = 18;
            ctx.shadowColor = glow;
            ctx.fill();
            ctx.shadowBlur = 0;
            ctx.beginPath();
            ctx.moveTo(-R * 0.22 * wMul, R * 1.1);
            ctx.quadraticCurveTo(-R * 0.18 * wMul, R * 1.1 + flameLen * 0.5, 0, R * 1.1 + flameLen * 0.68);
            ctx.quadraticCurveTo(R * 0.18 * wMul, R * 1.1 + flameLen * 0.5, R * 0.22 * wMul, R * 1.1);
            ctx.closePath();
            ctx.fillStyle = pal[1];
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(-R * 0.11 * wMul, R * 1.1);
            ctx.quadraticCurveTo(-R * 0.09 * wMul, R * 1.1 + flameLen * 0.3, 0, R * 1.1 + flameLen * 0.4);
            ctx.quadraticCurveTo(R * 0.09 * wMul, R * 1.1 + flameLen * 0.3, R * 0.11 * wMul, R * 1.1);
            ctx.closePath();
            ctx.fillStyle = pal[2];
            ctx.fill();
          }
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
          var trail = (p.id === 'player1' ? config.trail : config.trail2) || null;
          var thrusterCount = (state.activeEffects.speedBoost > 0 ? 2 : 1) +
            (trail && trail.count > 1 ? trail.count - 1 : 0);
          // Thrusters stream from ship tail
          var streamX = p.x - Math.sin(tilt) * (p.radius * 1.3);
          var streamY = p.y + Math.cos(tilt) * (p.radius * 1.3); // below the nozzle
          for (var i = 0; i < thrusterCount; i++) {
            var thrusterColor;
            if (trail && trail.animated) {
              thrusterColor = 'hsl(' + Math.floor((Date.now() / 8 + Math.random() * 80) % 360) + ', 90%, 65%)';
            } else if (trail) {
              thrusterColor = trail.colors[Math.floor(Math.random() * trail.colors.length)];
            } else {
              thrusterColor = state.activeEffects.speedBoost > 0
                ? '#22c55e'
                : (p.id === 'player1' ? '#ff00ff' : '#fb7185');
            }
            var spark = createParticle(streamX, streamY, thrusterColor, true);
            if (trail) {
              // Bought trails burn brighter and linger longer than stock
              spark.life *= 1.8;
              spark.maxLife = spark.life;
              spark.radius += 0.8;
            }
            state.particles.push(spark);
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
      drawCookies(); // secret cookie, quest cookies, the Giant Cookie
      drawShips();
      drawFloatingTexts();
      drawEffectsHud();
      drawTutorial();
      drawQuestOverlay(); // quest status line and banners

      ctx.restore();
    }

    // --- Online: snapshots (host -> guest) and steering (guest -> host) --------

    function r1(v) { return Math.round(v * 10) / 10; }

    function packPlayer(p) {
      return [r1(p.x), r1(p.y), r1(p.vx), r1(p.vy), r1(p.radius)];
    }

    function buildSnapshot() {
      // The secret cookie quest never runs online (cookieSpawnFrame is -1
      // whenever config.online is set), so snapshots carry no quest fields.
      var snap = {
        t: 's',
        sc: Math.round(state.score),
        h: r1(state.health),
        d: state.difficulty,
        dy: state.dying ? 1 : 0,
        go: state.isGameOver ? 1 : 0,
        sd: state.shipsDestroyed ? 1 : 0,
        sh: r1(shake),
        hc: state.hitCount,
        fx: [state.activeEffects.shield, state.activeEffects.speedBoost,
          state.activeEffects.weaponUpgrade, state.activeEffects.magnet],
        p: packPlayer(state.player),
        p2: state.player2 ? packPlayer(state.player2) : null,
        a: [], an: [], c: [], cn: [], u: [], un: [], j: [], pt: [], ft: []
      };
      // Asteroids, treats and orbs travel in full once (shape, colors...) and
      // as id + position afterwards.
      state.asteroids.forEach(function (a) {
        if (!sentIds[a.id]) { sentIds[a.id] = 1; snap.an.push(a); }
        snap.a.push([a.id, r1(a.x), r1(a.y), Math.round(a.rotation * 1000) / 1000]);
      });
      state.collectibles.forEach(function (c) {
        if (!sentIds[c.id]) { sentIds[c.id] = 1; snap.cn.push(c); }
        snap.c.push([c.id, r1(c.x), r1(c.y)]);
      });
      state.powerUps.forEach(function (u) {
        if (!sentIds[u.id]) { sentIds[u.id] = 1; snap.un.push(u); }
        snap.u.push([u.id, r1(u.x), r1(u.y), u.life]);
      });
      state.projectiles.forEach(function (j) {
        snap.j.push([r1(j.x), r1(j.y), j.radius, j.color]);
      });
      var particles = state.particles.length > 60 ? state.particles.slice(-60) : state.particles;
      particles.forEach(function (pt) {
        snap.pt.push([r1(pt.x), r1(pt.y), r1(pt.radius), pt.color, Math.round(pt.life), Math.round(pt.maxLife)]);
      });
      state.floatingTexts.forEach(function (ft) {
        snap.ft.push([r1(ft.x), r1(ft.y), ft.text, ft.color, r1(ft.alpha), ft.scale]);
      });
      // Forget ids that are gone so the "already sent" set stays small.
      if (netFrame % 300 === 0) {
        var live = {};
        state.asteroids.concat(state.collectibles, state.powerUps).forEach(function (e) { live[e.id] = 1; });
        sentIds = live;
      }
      return snap;
    }

    function maybeSendSnapshot() {
      netFrame++;
      if (state.isGameOver) {
        if (finalSnapshotSent) return;
        finalSnapshotSent = true; // the last word: score + game over
      } else if (netFrame % 3 !== 0) {
        return; // 20 snapshots a second is plenty
      }
      config.online.send(buildSnapshot());
    }

    function unpackPlayer(p, row) {
      p.x = row[0]; p.y = row[1]; p.vx = row[2]; p.vy = row[3]; p.radius = row[4];
    }

    function rebuildList(rows, fullList, apply) {
      (fullList || []).forEach(function (e) { knownEntities[e.id] = e; });
      var out = [];
      for (var i = 0; i < rows.length; i++) {
        var e = knownEntities[rows[i][0]];
        if (!e) continue; // its full record hasn't arrived yet
        apply(e, rows[i]);
        out.push(e);
      }
      return out;
    }

    function applySnapshot(s) {
      state.score = s.sc;
      state.health = s.h;
      state.difficulty = s.d;
      state.dying = !!s.dy;
      state.isGameOver = !!s.go;
      state.shipsDestroyed = !!s.sd;
      shake = s.sh;
      state.activeEffects = { shield: s.fx[0], speedBoost: s.fx[1], weaponUpgrade: s.fx[2], magnet: s.fx[3] };
      unpackPlayer(state.player, s.p);
      if (s.p2) {
        if (!state.player2) state.player2 = createPlayer('player2', s.p2[0], s.p2[1], '#fb7185');
        unpackPlayer(state.player2, s.p2);
      }
      state.asteroids = rebuildList(s.a, s.an, function (a, row) { a.x = row[1]; a.y = row[2]; a.rotation = row[3]; });
      state.collectibles = rebuildList(s.c, s.cn, function (c, row) { c.x = row[1]; c.y = row[2]; });
      state.powerUps = rebuildList(s.u, s.un, function (u, row) { u.x = row[1]; u.y = row[2]; u.life = row[3]; });
      state.projectiles = s.j.map(function (row) {
        return { x: row[0], y: row[1], radius: row[2], color: row[3], type: 'projectile' };
      });
      state.particles = s.pt.map(function (row) {
        return { x: row[0], y: row[1], radius: row[2], color: row[3], life: row[4], maxLife: row[5], type: 'particle' };
      });
      state.floatingTexts = s.ft.map(function (row) {
        return { x: row[0], y: row[1], text: row[2], color: row[3], alpha: row[4], scale: row[5] };
      });
      if (netFrame++ % 300 === 0) {
        var live = {};
        state.asteroids.concat(state.collectibles, state.powerUps).forEach(function (e) { live[e.id] = e; });
        knownEntities = live;
      }

      // Mirror the host's callbacks so the HUD, sounds and game-over flow match.
      if (s.sc !== reported.score) { reported.score = s.sc; handlers.onScoreUpdate(s.sc); }
      if (s.h !== reported.health) { reported.health = s.h; handlers.onHealthUpdate(s.h); }
      if (s.hc > reported.hit) { reported.hit = s.hc; handlers.onHit(); }
      if (state.dying && !reported.dying) { reported.dying = true; handlers.onDeath(); }
      handlers.onDifficultyUpdate(s.d);
      if (state.isGameOver && !reported.over) { reported.over = true; handlers.onGameOver(state.score); }
    }

    function maybeSendInput() {
      var dx = 0;
      var dy = 0;
      var pref = config.controlModePreference || 'both';
      var keyboardDrives = pref === 'keyboard' || (pref === 'both' && controlMode === 'keyboard');
      var mouseDrives = pref === 'mouse' || (pref === 'both' && controlMode === 'mouse');
      if (keyboardDrives) {
        if (keysPressed['KeyW'] || keysPressed['w'] || keysPressed['W'] || keysPressed['ArrowUp'] || keysPressed['Up']) dy -= 1;
        if (keysPressed['KeyS'] || keysPressed['s'] || keysPressed['S'] || keysPressed['ArrowDown'] || keysPressed['Down']) dy += 1;
        if (keysPressed['KeyA'] || keysPressed['a'] || keysPressed['A'] || keysPressed['ArrowLeft'] || keysPressed['Left']) dx -= 1;
        if (keysPressed['KeyD'] || keysPressed['d'] || keysPressed['D'] || keysPressed['ArrowRight'] || keysPressed['Right']) dx += 1;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len > 1) { dx /= len; dy /= len; }
      } else if (mouseDrives && state.player2) {
        var ddx = mousePos.x - state.player2.x;
        var ddy = mousePos.y - state.player2.y;
        var dist = Math.sqrt(ddx * ddx + ddy * ddy);
        if (dist > 14) { dx = ddx / dist; dy = ddy / dist; }
      }
      dx = Math.round(dx * 100) / 100;
      dy = Math.round(dy * 100) / 100;
      var now = Date.now();
      if (dx !== lastInput.dx || dy !== lastInput.dy || now - lastInputSent > 250) {
        lastInput = { dx: dx, dy: dy };
        lastInputSent = now;
        config.online.send({ t: 'in', x: dx, y: dy });
      }
    }

    function loop() {
      update();
      draw();
      if (config.online && state) {
        if (config.online.role === 'host') maybeSendSnapshot();
        else if (!state.isGameOver) maybeSendInput();
      }
      if (running) animationId = requestAnimationFrame(loop);
    }

    // --- Input ------------------------------------------------------------

    function handleResize() {
      layout.update();
      resizeCanvas();
    }

    function handleMouseMove(e) {
      mousePos = layout.point(e.clientX, e.clientY);
      controlMode = 'mouse';
    }

    function handleTouchMove(e) {
      if (e.touches[0]) {
        mousePos = layout.point(e.touches[0].clientX, e.touches[0].clientY);
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
      // Clear every variant of the key. Pressing 'a' then releasing it with
      // Shift or Caps Lock active reports the release as 'A' — without this,
      // the stale lowercase entry keeps thrusting forever and pins the ship
      // against a wall.
      keysPressed[e.key] = false;
      if (e.key.length === 1) {
        keysPressed[e.key.toLowerCase()] = false;
        keysPressed[e.key.toUpperCase()] = false;
      }
      keysPressed[e.code] = false;
    }

    // Releases outside the window never fire keyup — drop all held keys when
    // focus leaves so no ghost thrust survives.
    function handleWindowBlur() {
      keysPressed = {};
    }

    function handleCanvasClick() {
      canvas.focus();
    }

    window.addEventListener('resize', handleResize);
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('touchmove', handleTouchMove);
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('blur', handleWindowBlur);
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
        config.trail = options.trail || null; // player 1's thruster trail
        config.flame = options.flame || null; // player 1's fire style (may carry a power)
        config.skin2 = options.skin2 || null; // player 2's gear (local two-player only)
        config.trail2 = options.trail2 || null;
        config.flame2 = options.flame2 || null;
        config.flameSpeedMult = 1;
        if (config.flame && config.flame.power === 'fast') config.flameSpeedMult = 1.35;
        if (config.flame && config.flame.power === 'slow') config.flameSpeedMult = 0.65;
        config.online = options.online || null; // {role, send} for internet play
        // Cookie quest test hooks (see config): a fixed spawn frame and/or a
        // cookie aimed at the ship's y. Production callers pass neither.
        config.cookieSpawnFrame = typeof options.cookieSpawnFrame === 'number' ? options.cookieSpawnFrame : undefined;
        config.cookieAimAtShip = !!options.cookieAimAtShip;
        config.questBossHP = typeof options.questBossHP === 'number' ? options.questBossHP : undefined;
        resetNet();

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
      },

      // Online play: hand a message from the other side to the engine.
      // Host takes steering ({t:'in'}); guest takes snapshots ({t:'s'}).
      receive: function (msg) {
        if (!config.online || !msg) return;
        if (config.online.role === 'host' && msg.t === 'in') {
          remoteInput = {
            dx: Math.max(-1, Math.min(1, Number(msg.x) || 0)),
            dy: Math.max(-1, Math.min(1, Number(msg.y) || 0))
          };
        } else if (config.online.role === 'guest' && msg.t === 's') {
          pendingSnapshot = msg;
        }
      },

      // Score of the round in progress (used when a connection drops).
      getScore: function () {
        return state ? state.score : 0;
      },

      // Read-only ship telemetry (debug/testing)
      getDebugPositions: function () {
        if (!state) return null;
        var out = { keys: Object.keys(keysPressed).filter(function (k) { return keysPressed[k]; }) };
        [['p1', state.player], ['p2', state.player2]].forEach(function (pair) {
          if (pair[1]) {
            out[pair[0]] = {
              x: Math.round(pair[1].x * 10) / 10,
              y: Math.round(pair[1].y * 10) / 10,
              vx: Math.round(pair[1].vx * 100) / 100,
              vy: Math.round(pair[1].vy * 100) / 100
            };
          }
        });
        // Secret cookie quest telemetry (compared by the iOS parity test)
        out.frame = state.frame;
        out.cookieSpawnFrame = state.cookieSpawnFrame;
        out.cookie = state.cookie ? { x: r1(state.cookie.x), y: r1(state.cookie.y) } : null;
        out.quest = state.quest ? {
          level: state.quest.level,
          phase: state.quest.phase,
          collected: state.quest.collected,
          timer: state.quest.timer,
          bossHp: state.quest.boss ? state.quest.boss.hp : null
        } : null;
        out.questCookies = state.quest ? state.quest.cookies.map(function (c) {
          return { x: r1(c.x), y: r1(c.y) };
        }) : [];
        out.boss = state.quest && state.quest.boss ? {
          x: r1(state.quest.boss.x), y: r1(state.quest.boss.y),
          vx: r1(state.quest.boss.vx), vy: r1(state.quest.boss.vy), hp: state.quest.boss.hp
        } : null;
        out.weapon = state.activeEffects.weaponUpgrade;
        out.powerUps = state.powerUps.map(function (pu) {
          return { x: r1(pu.x), y: r1(pu.y), type: pu.subType };
        });
        out.suns = state.quest ? state.quest.suns.map(function (sn) {
          return { x: r1(sn.x), y: r1(sn.y), vx: r1(sn.vx), vy: r1(sn.vy) };
        }) : [];
        out.asteroids = state.asteroids.map(function (a) {
          return { x: r1(a.x), y: r1(a.y), vx: r1(a.vx), vy: r1(a.vy), r: r1(a.radius), style: a.style };
        });
        return out;
      }
    };
  }

  global.NeonNebula = { createGame: createGame };
})(window);
