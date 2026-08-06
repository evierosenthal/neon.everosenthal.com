/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 *
 * Neon Nebula — menus, HUD and screen flow (plain JavaScript).
 * Port of the original App React component.
 */

(function () {
  'use strict';

  var HIGHSCORE_PREFIX = 'neon_nebula_highscore_'; // + mode
  var CONTROL_KEY = 'neon_nebula_control_mode';
  var SPEED_KEY = 'neon_nebula_speed'; // rocket speed percent, 50-200

  var MODES = ['easy', 'medium', 'hard', 'super'];
  var MODE_LABELS = {
    easy: 'EASY MODE',
    medium: 'MEDIUM MODE',
    hard: 'HARD MODE',
    super: 'SUPER HARD MODE'
  };

  // --- Rocket skins & coin economy --------------------------------------
  // Coins: score / 50 per mission, times 5 on a new high score.
  var COINS_KEY = 'neon_nebula_coins';
  var DAILY_KEY = 'neon_nebula_daily_claim';
  var DAILY_BONUS = 150;
  var SKIN_KEY = 'neon_nebula_skin';
  var SKINS_OWNED_KEY = 'neon_nebula_skins_owned';
  var COIN_SCORE_DIVISOR = 50;
  var RECORD_COIN_MULTIPLIER = 5;

  var SKINS = [
    { id: 'cyan', name: 'Neon Classic', price: 0, accent: '#22d3ee' },
    { id: 'rose', name: 'Rose Racer', price: 250, accent: '#fb7185' },
    { id: 'emerald', name: 'Emerald Comet', price: 250, accent: '#34d399' },
    { id: 'ice', name: 'Ice Crystal', price: 400, accent: '#7dd3fc',
      hull: ['#93c5fd', '#f8fafc', '#e0f2fe', '#60a5fa'],
      window: ['#f0f9ff', '#bae6fd', '#1d4ed8'] },
    { id: 'candy', name: 'Candy Sundae', price: 500, accent: '#f472b6',
      hull: ['#d9a066', '#fff7ed', '#fde68a', '#b45309'],
      window: ['#fdf2f8', '#f9a8d4', '#9d174d'] },
    { id: 'toxic', name: 'Toxic Venom', price: 600, accent: '#a3e635',
      hull: ['#14532d', '#86efac', '#4ade80', '#052e16'],
      window: ['#f7fee7', '#bef264', '#3f6212'] },
    { id: 'gold', name: 'Solar Flare', price: 750, accent: '#fbbf24',
      hull: ['#b45309', '#fef9c3', '#fde68a', '#a16207'] },
    { id: 'magma', name: 'Magma Core', price: 900, accent: '#f97316',
      hull: ['#7f1d1d', '#fca5a5', '#ef4444', '#450a0a'],
      window: ['#fff7ed', '#fdba74', '#7c2d12'] },
    { id: 'amethyst', name: 'Royal Amethyst', price: 1200, accent: '#fbbf24',
      hull: ['#4c1d95', '#c4b5fd', '#8b5cf6', '#2e1065'],
      window: ['#fefce8', '#fde047', '#713f12'] },
    { id: 'void', name: 'Void Shadow', price: 1500, accent: '#c084fc',
      hull: ['#1e293b', '#64748b', '#475569', '#0f172a'],
      window: ['#f5d0fe', '#e879f9', '#701a75'] },
    { id: 'stealth', name: 'Stealth Ops', price: 2000, accent: '#64748b',
      hull: ['#0f172a', '#334155', '#1e293b', '#020617'],
      window: ['#fecaca', '#ef4444', '#450a0a'] },
    { id: 'galaxy', name: 'Galaxy Prism', price: 3000, accent: '#22d3ee', animated: true }
  ];

  var ZAP_ICON = '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
    '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>';

  var DIFFICULTIES = [
    { label: 'EASY MODE', value: 0.3, className: 'btn btn-emerald' },
    { label: 'MEDIUM MODE', value: 0.74, className: 'btn btn-indigo btn-medium' },
    { label: 'HARD MODE', value: 1.3, className: 'btn btn-rose' },
    { label: 'SUPER HARD', value: 6.0, className: 'btn btn-super', zap: true }
  ];

  var CONTROL_OPTIONS = [
    {
      id: 'both',
      title: 'Both (Mouse & Keyboard)',
      desc: 'Tracks mouse cursor + WASD/Arrow keys for instant thrust',
      badge: 'Recommended',
      icon: '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
        '<line x1="21" x2="14" y1="4" y2="4"/><line x1="10" x2="3" y1="4" y2="4"/>' +
        '<line x1="21" x2="12" y1="12" y2="12"/><line x1="8" x2="3" y1="12" y2="12"/>' +
        '<line x1="21" x2="16" y1="20" y2="20"/><line x1="12" x2="3" y1="20" y2="20"/>' +
        '<line x1="14" x2="14" y1="2" y2="6"/><line x1="8" x2="8" y1="10" y2="14"/>' +
        '<line x1="16" x2="16" y1="18" y2="22"/></svg>'
    },
    {
      id: 'mouse',
      title: 'Mouse Only',
      desc: 'Ship smoothly tracks mouse position across space',
      icon: '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
        '<path d="M12.586 12.586 19 19"/>' +
        '<path d="M3.688 3.037a.497.497 0 0 0-.651.651l6.5 15.999a.501.501 0 0 0 .947-.062l1.569-6.083a2 2 0 0 1 1.448-1.479l6.124-1.579a.5.5 0 0 0 .063-.947z"/></svg>'
    },
    {
      id: 'keyboard',
      title: 'Keyboard Only',
      desc: 'Manual WASD or Arrow keys vector thrust control',
      icon: '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
        '<path d="M10 8h.01"/><path d="M12 12h.01"/><path d="M14 8h.01"/><path d="M16 12h.01"/>' +
        '<path d="M18 8h.01"/><path d="M6 8h.01"/><path d="M7 16h10"/><path d="M8 12h.01"/>' +
        '<rect width="20" height="16" x="2" y="4" rx="2"/></svg>'
    }
  ];

  var CHECK_ICON = '<svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M20 6 9 17l-5-5"/></svg>';

  // --- App state ---------------------------------------------------------

  var gameState = 'START'; // 'START' | 'PLAYING' | 'GAMEOVER' | 'NEWHIGH'
  var menuMode = 'main'; // 'main' | 'two-player' | 'cpu'
  var isLocalMultiplayer = false;
  var isCPUMultiplayer = false;
  var score = 0;
  var highScores = { easy: 0, medium: 0, hard: 0, super: 0 };
  var currentMode = 'easy';
  var health = 100;
  var isPaused = false;
  var difficulty = 1;
  var controlModePreference = 'both';
  var isSettingsOpen = false;
  var settingsAutoPaused = false; // we paused for the settings modal, so we resume on close
  var pendingScore = null; // new high score awaiting server submission
  var pendingMode = null; // mode the pending score was earned in
  var newhighPhase = 'offer'; // 'offer' | 'register' | 'forgot' | 'submitting' | 'result' | 'none'
  var isLeaderboardOpen = false;
  var leaderboards = null; // {easy: [...], medium: [...], ...} cache for the modal
  var leaderboardTab = 'easy';
  var isSkinsOpen = false;
  var coins = 0;
  var ownedSkins = ['cyan'];
  var selectedSkin = 'cyan';
  var isResetOpen = false;
  var resetToken = null;

  var el = {
    canvas: document.getElementById('game-canvas'),
    hud: document.getElementById('hud'),
    hudScore: document.getElementById('hud-score'),
    hudHighScore: document.getElementById('hud-highscore'),
    hudModes: document.getElementById('hud-modes'),
    hudHealthPct: document.getElementById('hud-health-pct'),
    hudHealthBar: document.getElementById('hud-health-bar'),
    pauseBtn: document.getElementById('pause-btn'),
    startScreen: document.getElementById('start-screen'),
    gameoverScreen: document.getElementById('gameover-screen'),
    pauseScreen: document.getElementById('pause-screen'),
    settingsModal: document.getElementById('settings-modal'),
    settingsBtn: document.getElementById('settings-btn'),
    settingsClose: document.getElementById('settings-close'),
    speedSlider: document.getElementById('speed-slider'),
    speedValue: document.getElementById('speed-value'),
    settingsDone: document.getElementById('settings-done'),
    controlOptions: document.getElementById('control-options'),
    finalScore: document.getElementById('final-score'),
    finalHighScore: document.getElementById('final-highscore'),
    gameoverHome: document.getElementById('gameover-home'),
    gameoverRestart: document.getElementById('gameover-restart'),
    pauseResume: document.getElementById('pause-resume'),
    pauseHome: document.getElementById('pause-home'),
    userChip: document.getElementById('user-chip'),
    userChipName: document.getElementById('user-chip-name'),
    logoutLink: document.getElementById('logout-link'),
    newhighScreen: document.getElementById('newhigh-screen'),
    newhighMode: document.getElementById('newhigh-mode'),
    newhighScore: document.getElementById('newhigh-score'),
    newhighPhases: {
      'offer': document.getElementById('newhigh-auth'),
      'register': document.getElementById('newhigh-register'),
      'forgot': document.getElementById('newhigh-forgot'),
      'submitting': document.getElementById('newhigh-submitting'),
      'result': document.getElementById('newhigh-result')
    },
    googleBtnSlot: document.getElementById('google-btn-slot'),
    loginForm: document.getElementById('newhigh-login-form'),
    authUser: document.getElementById('auth-user'),
    authPass: document.getElementById('auth-pass'),
    loginError: document.getElementById('login-error'),
    registerForm: document.getElementById('newhigh-register-form'),
    regUsername: document.getElementById('reg-username'),
    regEmail: document.getElementById('reg-email'),
    regPassword: document.getElementById('reg-password'),
    registerError: document.getElementById('register-error'),
    forgotForm: document.getElementById('newhigh-forgot-form'),
    forgotEmail: document.getElementById('forgot-email'),
    forgotError: document.getElementById('forgot-error'),
    forgotSent: document.getElementById('forgot-sent'),
    showRegister: document.getElementById('show-register'),
    showForgot: document.getElementById('show-forgot'),
    showLogin: document.getElementById('show-login'),
    showLogin2: document.getElementById('show-login-2'),
    newhighRank: document.getElementById('newhigh-rank'),
    newhighLeaderboard: document.getElementById('newhigh-leaderboard'),
    newhighSubmitError: document.getElementById('newhigh-submit-error'),
    newhighRetry: document.getElementById('newhigh-retry'),
    newhighHome: document.getElementById('newhigh-home'),
    newhighRestart: document.getElementById('newhigh-restart'),
    leaderboardModal: document.getElementById('leaderboard-modal'),
    leaderboardList: document.getElementById('leaderboard-list'),
    leaderboardClose: document.getElementById('leaderboard-close'),
    seeHighscores: document.getElementById('see-highscores'),
    startStars: document.getElementById('start-stars'),
    dailyChest: document.getElementById('daily-chest'),
    dailyChestLabel: document.getElementById('daily-chest-label'),
    homeRocket: document.getElementById('home-rocket'),
    homeBest: document.getElementById('home-best'),
    homeCoins: document.getElementById('home-coins'),
    homePilot: document.getElementById('home-pilot'),
    skinsBtn: document.getElementById('skins-btn'),
    skinsModal: document.getElementById('skins-modal'),
    skinsClose: document.getElementById('skins-close'),
    skinsGrid: document.getElementById('skins-grid'),
    skinsCoins: document.getElementById('skins-coins'),
    skinsError: document.getElementById('skins-error'),
    gameoverCoins: document.getElementById('gameover-coins'),
    newhighCoins: document.getElementById('newhigh-coins'),
    resetModal: document.getElementById('reset-modal'),
    resetForm: document.getElementById('reset-form'),
    resetPasswordInput: document.getElementById('reset-password-input'),
    resetError: document.getElementById('reset-error'),
    resetClose: document.getElementById('reset-close'),
    menus: {
      'main': document.getElementById('menu-main'),
      'two-player': document.getElementById('menu-two-player'),
      'cpu': document.getElementById('menu-cpu')
    }
  };

  // Background music: original synthwave loop composed for the game
  // (8 bars, 112 BPM, Am-F-C-G — kick/snare/hats, pumped saw pads, square
  // arp). Loops during play, pauses with the game, and stops on death so
  // the crash/fanfare take the stage. Missing file = silent game.
  var bgMusic = new Audio('sounds/background-music.m4a');
  bgMusic.preload = 'auto';
  bgMusic.loop = true;
  bgMusic.volume = 0.35;

  function setMusicPlaying(playing) {
    if (playing) {
      bgMusic.play().catch(function () { /* file missing or autoplay blocked */ });
    } else {
      bgMusic.pause();
    }
  }

  // "You Win" fanfare by floraphonic (pixabay.com, sound #183950) — played
  // when the new-high-score screen opens.
  var newHighSound = new Audio('sounds/new-high-score.mp3');
  newHighSound.preload = 'auto';
  newHighSound.volume = 0.8;

  // "Spacecraft crashing" by freesound_community (pixabay.com, sound #88048) —
  // only its final seconds play, on the asteroid hit that destroys the ship
  // (not on ordinary health-losing hits).
  var DEATH_SOUND_TAIL_SEC = 3;
  var deathSound = new Audio('sounds/crash-death.mp3');
  deathSound.preload = 'auto';
  deathSound.volume = 0.9;

  // "Sci-fi whoosh spectral glide" by Rescopic Sound (pixabay.com, sound
  // #228310) — its final 2 seconds play on asteroid hits that hurt but don't
  // kill (the fatal hit gets the crash sound instead).
  var HIT_SOUND_TAIL_SEC = 2;
  var hitSound = new Audio('sounds/asteroid-hit.mp3');
  hitSound.preload = 'auto';
  hitSound.volume = 0.7;

  function playHitSound() {
    try {
      var dur = hitSound.duration;
      hitSound.currentTime = (isFinite(dur) && dur > HIT_SOUND_TAIL_SEC)
        ? dur - HIT_SOUND_TAIL_SEC
        : 0;
      hitSound.play().catch(function () { /* autoplay blocked */ });
    } catch (err) { /* audio unavailable */ }
  }

  function playDeathSound() {
    try {
      var dur = deathSound.duration;
      deathSound.currentTime = (isFinite(dur) && dur > DEATH_SOUND_TAIL_SEC)
        ? dur - DEATH_SOUND_TAIL_SEC
        : 0;
      deathSound.play().catch(function () { /* autoplay blocked — die silently */ });
    } catch (err) { /* audio unavailable */ }
  }

  var game = window.NeonNebula.createGame(el.canvas, {
    onGameOver: handleGameOver,
    onScoreUpdate: setScore,
    onHealthUpdate: setHealth,
    onDifficultyUpdate: handleDifficultyUpdate,
    onDeath: playDeathSound, // crash boom at the moment of impact, with the explosion
    onHit: playHitSound // whoosh on hull damage that isn't fatal
  });

  // --- Helpers -----------------------------------------------------------

  function show(node, visible) {
    node.classList.toggle('hidden', !visible);
  }

  function formatNumber(value) {
    return Math.max(0, Math.round(value)).toLocaleString();
  }

  function setScore(value) {
    score = value;
    el.hudScore.textContent = formatNumber(score);
  }

  function setHealth(value) {
    health = value;
    var pct = Math.max(0, Math.min(100, health));
    el.hudHealthPct.textContent = Math.max(0, Math.round(health)) + '%';
    el.hudHealthPct.className = health > 30 ? 'hull-ok' : 'hull-critical';
    el.hudHealthBar.style.width = pct + '%';
    el.hudHealthBar.classList.toggle('critical', health <= 30);
  }

  function modeFromDifficulty(diff) {
    if (diff >= 5.0) return 'super';
    if (diff >= 1.0) return 'hard';
    if (diff >= 0.6) return 'medium';
    return 'easy';
  }

  function refreshHighScoreDisplays() {
    el.hudHighScore.textContent = formatNumber(highScores[currentMode]);
    el.finalHighScore.textContent = formatNumber(highScores[currentMode]);
  }

  function setModeHighScore(mode, value) {
    highScores[mode] = value;
    try {
      localStorage.setItem(HIGHSCORE_PREFIX + mode, String(value));
    } catch (err) { /* storage unavailable — keep the session high score */ }
    refreshHighScoreDisplays();
  }

  // --- HUD difficulty strip ----------------------------------------------
  // Shows the tiers from the starting mode upward; the lit tile follows the
  // engine's live difficulty as it grows across tier boundaries.

  var liveTier = 'easy';

  function buildModeStrip() {
    var base = ['easy', 'medium', 'hard'];
    var tiers = currentMode === 'super' ? ['super'] : base.slice(base.indexOf(currentMode));
    el.hudModes.innerHTML = '';
    tiers.forEach(function (tier) {
      var span = document.createElement('span');
      span.className = 'hud-mode';
      span.setAttribute('data-tier', tier);
      span.textContent = tier === 'super' ? 'Super Hard' : tier;
      el.hudModes.appendChild(span);
    });
    liveTier = currentMode;
    highlightModeStrip();
  }

  function highlightModeStrip() {
    var tiles = el.hudModes.children;
    for (var i = 0; i < tiles.length; i++) {
      tiles[i].classList.toggle('active', tiles[i].getAttribute('data-tier') === liveTier);
    }
  }

  function handleDifficultyUpdate(diff) {
    if (currentMode === 'super') return; // super runs keep their single lit tile
    var tier = modeFromDifficulty(diff);
    if (tier === liveTier) return;
    liveTier = tier;
    highlightModeStrip();
  }

  // Merge the server's per-mode bests into the local records (new-device sync).
  function syncServerBests(user) {
    if (!user || !user.bestScores) return;
    MODES.forEach(function (mode) {
      var serverBest = user.bestScores[mode] || 0;
      if (serverBest > highScores[mode]) setModeHighScore(mode, serverBest);
    });
  }

  function refreshHomeStats() {
    var best = Math.max(highScores.easy, highScores.medium, highScores.hard, highScores.super);
    el.homeBest.textContent = formatNumber(best);
    el.homeCoins.textContent = formatNumber(coins);
    var user = window.NeonAuth ? window.NeonAuth.state.user : null;
    el.homePilot.textContent = user ? user.username : 'GUEST';

    // The equipped skin poses beside the title; re-render only on change.
    if (el.homeRocket.getAttribute('data-skin') !== selectedSkin) {
      el.homeRocket.setAttribute('data-skin', selectedSkin);
      el.homeRocket.innerHTML = skinSvg(getSkin(selectedSkin));
    }

    refreshDailyChest();
  }

  function buildStartStars() {
    var palette = ['#ffffff', '#ffffff', '#a5f3fc', '#c7d2fe'];
    for (var i = 0; i < 42; i++) {
      var star = document.createElement('span');
      star.className = 'start-star';
      var size = 1 + Math.random() * 1.8;
      star.style.width = size + 'px';
      star.style.height = size + 'px';
      star.style.left = (Math.random() * 100) + '%';
      star.style.top = (Math.random() * 100) + '%';
      star.style.background = palette[Math.floor(Math.random() * palette.length)];
      star.style.animationDelay = (Math.random() * 4) + 's';
      star.style.animationDuration = (2.2 + Math.random() * 3) + 's';
      el.startStars.appendChild(star);
    }

    // Slow drifting treats & rocks behind the panel, for depth
    var DONUT_SVG = '<svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="16" fill="#d9a066"/>' +
      '<circle cx="20" cy="20" r="14" fill="#f472b6"/><circle cx="20" cy="20" r="6" fill="#0b0716"/>' +
      '<circle cx="13" cy="14" r="1.5" fill="#fef08a"/><circle cx="27" cy="15" r="1.5" fill="#86efac"/>' +
      '<circle cx="25" cy="26" r="1.5" fill="#93c5fd"/><circle cx="14" cy="25" r="1.5" fill="#fca5a5"/></svg>';
    var BLUE_ROCK_SVG = '<svg viewBox="0 0 40 40"><path d="M8 14 L20 4 L34 12 L36 26 L24 37 L9 32 Z" ' +
      'fill="#2563eb" stroke="#1e3a8a" stroke-width="2"/><path d="M14 18 L20 14 L26 19 L23 25 L15 24 Z" fill="#172554"/></svg>';
    var GRAY_ROCK_SVG = '<svg viewBox="0 0 40 40"><path d="M6 16 L16 5 L31 8 L36 22 L27 35 L10 33 Z" ' +
      'fill="#94a3b8" stroke="#475569" stroke-width="2"/><circle cx="18" cy="18" r="4" fill="#334155" opacity="0.7"/>' +
      '<circle cx="27" cy="26" r="3" fill="#334155" opacity="0.7"/></svg>';
    [
      { html: DONUT_SVG, size: 32, top: '16%', left: '10%', dur: 26 },
      { html: GRAY_ROCK_SVG, size: 46, top: '72%', left: '7%', dur: 36 },
      { html: BLUE_ROCK_SVG, size: 30, top: '26%', left: '87%', dur: 30 },
      { html: DONUT_SVG, size: 22, top: '80%', left: '86%', dur: 22 }
    ].forEach(function (d) {
      var node = document.createElement('span');
      node.className = 'drifter';
      node.style.width = d.size + 'px';
      node.style.height = d.size + 'px';
      node.style.top = d.top;
      node.style.left = d.left;
      node.style.setProperty('--dur', d.dur + 's');
      node.innerHTML = d.html;
      el.startStars.appendChild(node);
    });

    // Every so often the equipped rocket cruises across the backdrop
    setInterval(function () {
      if (gameState !== 'START') return;
      var fly = document.createElement('span');
      fly.className = 'flyby';
      fly.style.setProperty('--y', (12 + Math.random() * 65) + '%');
      fly.style.setProperty('--t', (5 + Math.random() * 3) + 's');
      fly.innerHTML = '<span class="flyby-inner">' + skinSvg(getSkin(selectedSkin)) + '</span>';
      el.startStars.appendChild(fly);
      setTimeout(function () { fly.remove(); }, 8500);
    }, 17000);

    // A shooting star streaks by every few seconds while on the menu
    setInterval(function () {
      if (gameState !== 'START') return;
      var s = document.createElement('span');
      s.className = 'shooting-star';
      s.style.left = (10 + Math.random() * 70) + '%';
      s.style.top = (5 + Math.random() * 45) + '%';
      var angleDeg = 15 + Math.random() * 30;
      var dir = Math.random() < 0.5 ? 1 : -1;
      var dist = 260 + Math.random() * 220;
      var rad = angleDeg * Math.PI / 180;
      s.style.setProperty('--angle', (dir === 1 ? angleDeg : 180 - angleDeg) + 'deg');
      s.style.setProperty('--dx', (Math.cos(rad) * dist * dir) + 'px');
      s.style.setProperty('--dy', (Math.sin(rad) * dist) + 'px');
      el.startStars.appendChild(s);
      setTimeout(function () { s.remove(); }, 1400);
    }, 2800);
  }

  // --- Daily bonus chest -------------------------------------------------

  function todayStamp() {
    var d = new Date();
    return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
  }

  function dailyClaimed() {
    try {
      return localStorage.getItem(DAILY_KEY) === todayStamp();
    } catch (err) {
      return true; // no storage — hide the freebie rather than gift it every visit
    }
  }

  function refreshDailyChest() {
    var claimed = dailyClaimed();
    el.dailyChest.classList.toggle('available', !claimed);
    el.dailyChest.classList.toggle('claimed', claimed);
    el.dailyChestLabel.textContent = claimed ? 'COME BACK TOMORROW' : 'DAILY BONUS';
  }

  function claimDailyBonus() {
    if (dailyClaimed()) return;
    try {
      localStorage.setItem(DAILY_KEY, todayStamp());
    } catch (err) { /* storage unavailable */ }
    coins += DAILY_BONUS;
    saveWallet();
    for (var i = 0; i < 12; i++) {
      var pop = document.createElement('span');
      pop.className = 'coin-pop';
      pop.style.setProperty('--dx', ((Math.random() - 0.5) * 140) + 'px');
      pop.style.setProperty('--dy', -(30 + Math.random() * 100) + 'px');
      pop.style.animationDelay = (Math.random() * 0.15) + 's';
      el.dailyChest.appendChild(pop);
      (function (node) { setTimeout(function () { node.remove(); }, 1100); })(pop);
    }
    refreshHomeStats();
    refreshDailyChest();
  }

  // The menu panel leans a few degrees toward the cursor (3D-card feel).
  function wireStartParallax() {
    var panel = document.querySelector('#start-screen .panel-start');
    el.startScreen.addEventListener('mousemove', function (e) {
      var rect = panel.getBoundingClientRect();
      var dx = (e.clientX - (rect.left + rect.width / 2)) / rect.width;
      var dy = (e.clientY - (rect.top + rect.height / 2)) / rect.height;
      dx = Math.max(-0.7, Math.min(0.7, dx));
      dy = Math.max(-0.7, Math.min(0.7, dy));
      panel.style.transform = 'perspective(1400px) rotateY(' + (dx * 4).toFixed(2) + 'deg) rotateX(' + (-dy * 3).toFixed(2) + 'deg)';
    });
    el.startScreen.addEventListener('mouseleave', function () {
      panel.style.transform = '';
    });
  }

  function render() {
    var playing = gameState === 'PLAYING';
    if (gameState === 'START') refreshHomeStats();
    show(el.canvas, playing);
    show(el.hud, playing);
    show(el.startScreen, gameState === 'START');
    show(el.gameoverScreen, gameState === 'GAMEOVER');
    show(el.newhighScreen, gameState === 'NEWHIGH');
    show(el.pauseScreen, playing && isPaused);
    show(el.settingsModal, isSettingsOpen);
    show(el.leaderboardModal, isLeaderboardOpen);
    show(el.skinsModal, isSkinsOpen);
    show(el.resetModal, isResetOpen);

    setMusicPlaying(playing && !isPaused);

    var user = window.NeonAuth ? window.NeonAuth.state.user : null;
    show(el.userChip, !!user && !playing);
    if (user) el.userChipName.textContent = user.username;

    Object.keys(el.newhighPhases).forEach(function (key) {
      show(el.newhighPhases[key], gameState === 'NEWHIGH' && key === newhighPhase);
    });

    if (gameState === 'NEWHIGH') {
      fireworks.start();
    } else {
      fireworks.stop();
      if (!newHighSound.paused) {
        newHighSound.pause();
        newHighSound.currentTime = 0;
      }
    }

    Object.keys(el.menus).forEach(function (key) {
      show(el.menus[key], key === menuMode);
    });
  }

  // --- Menu construction -------------------------------------------------

  function buildDifficultyButtons() {
    var containers = document.querySelectorAll('.difficulty-buttons');
    Array.prototype.forEach.call(containers, function (container) {
      var mode = container.getAttribute('data-mode');
      DIFFICULTIES.forEach(function (diff) {
        var button = document.createElement('button');
        button.className = diff.className;
        button.innerHTML = '<span class="btn-sheen"></span>' +
          (diff.zap ? ZAP_ICON : '') +
          diff.label +
          (diff.zap ? ZAP_ICON : '');
        button.addEventListener('click', function () {
          startGame(diff.value, mode === 'local', mode === 'cpu');
        });
        container.appendChild(button);
      });
    });
  }

  function buildControlOptions() {
    CONTROL_OPTIONS.forEach(function (option) {
      var button = document.createElement('button');
      button.className = 'control-option';
      button.setAttribute('data-control', option.id);
      button.innerHTML =
        '<div class="control-option-left">' +
          '<div class="control-option-icon">' + option.icon + '</div>' +
          '<div>' +
            '<div class="control-option-title">' +
              '<span>' + option.title + '</span>' +
              (option.badge ? '<span class="control-option-badge">' + option.badge + '</span>' : '') +
            '</div>' +
            '<p class="control-option-desc">' + option.desc + '</p>' +
          '</div>' +
        '</div>' +
        '<div class="control-option-check">' + CHECK_ICON + '</div>';
      button.addEventListener('click', function () {
        handleControlChange(option.id);
      });
      el.controlOptions.appendChild(button);
    });
  }

  function renderControlOptions() {
    var buttons = el.controlOptions.querySelectorAll('.control-option');
    Array.prototype.forEach.call(buttons, function (button) {
      button.classList.toggle('selected', button.getAttribute('data-control') === controlModePreference);
    });
  }

  // --- Actions -----------------------------------------------------------

  function applySpeedSetting() {
    var pct = parseInt(el.speedSlider.value, 10) || 100;
    el.speedValue.textContent = pct + '%';
    game.setSpeedFactor(pct / 100);
  }

  function handleControlChange(mode) {
    controlModePreference = mode;
    try {
      localStorage.setItem(CONTROL_KEY, mode);
    } catch (err) { /* storage unavailable — keep the in-memory preference */ }
    game.setControlModePreference(mode);
    renderControlOptions();
  }

  function handleGameOver(finalScore) {
    game.stop();
    var beatRecord = finalScore > highScores[currentMode] && finalScore > 0;

    // Mission pay: coins scale with score, with a big bonus for a new record.
    var earned = Math.max(0, Math.round(finalScore / COIN_SCORE_DIVISOR));
    if (beatRecord) earned *= RECORD_COIN_MULTIPLIER;
    if (earned > 0) {
      coins += earned;
      saveWallet();
    }

    if (beatRecord) {
      setModeHighScore(currentMode, Math.round(finalScore));

      gameState = 'NEWHIGH';
      pendingScore = Math.round(finalScore);
      pendingMode = currentMode;
      el.newhighMode.textContent = MODE_LABELS[currentMode];
      el.newhighScore.textContent = formatNumber(finalScore);
      el.newhighCoins.textContent = '+' + formatNumber(earned) + ' COINS — ' + RECORD_COIN_MULTIPLIER + '× RECORD BONUS!';

      // Fanfare leads the celebration in (the fireworks start on render()).
      try {
        newHighSound.currentTime = 0;
        newHighSound.play().catch(function () { /* autoplay blocked — celebrate silently */ });
      } catch (err) { /* audio unavailable */ }

      var auth = window.NeonAuth;
      if (auth && auth.state.user) {
        submitPendingScore();
      } else if (auth && !auth.state.offline) {
        setNewhighPhase('offer');
      } else {
        newhighPhase = 'none'; // no server available — celebration only
      }
    } else {
      gameState = 'GAMEOVER';
      el.finalScore.textContent = formatNumber(finalScore);
      el.gameoverCoins.textContent = '+' + formatNumber(earned);
    }
    render();
  }

  // --- New-high-score / leaderboard helpers ------------------------------

  function setNewhighPhase(phase) {
    newhighPhase = phase;
    if (phase === 'offer') {
      window.NeonAuth.renderGoogleButton(el.googleBtnSlot);
    }
    render();
  }

  function setFormError(node, message) {
    node.textContent = message || '';
    show(node, !!message);
  }

  function buildLeaderboardList(container, rows) {
    var user = window.NeonAuth ? window.NeonAuth.state.user : null;
    container.innerHTML = '';
    if (!rows || !rows.length) {
      var empty = document.createElement('div');
      empty.className = 'lb-empty';
      empty.textContent = 'No scores transmitted yet — be the first commander on the board.';
      container.appendChild(empty);
      return;
    }
    rows.forEach(function (row) {
      var div = document.createElement('div');
      div.className = 'lb-row' + (user && user.username === row.username ? ' lb-me' : '');
      var rank = document.createElement('span');
      rank.className = 'lb-rank';
      rank.textContent = '#' + row.rank;
      var name = document.createElement('span');
      name.className = 'lb-name';
      name.textContent = row.username;
      var scoreEl = document.createElement('span');
      scoreEl.className = 'lb-score';
      scoreEl.textContent = formatNumber(row.score);
      div.appendChild(rank);
      div.appendChild(name);
      div.appendChild(scoreEl);
      container.appendChild(div);
    });
  }

  function submitPendingScore() {
    if (pendingScore == null) return;
    setNewhighPhase('submitting');
    var submitted = pendingScore;
    var mode = pendingMode;
    window.NeonAuth.submitScore(submitted, mode).then(function (data) {
      pendingScore = null;
      if (data.bestScore > highScores[mode]) setModeHighScore(mode, data.bestScore);
      el.newhighRank.textContent = data.improved
        ? 'GALACTIC RANK #' + data.rank
        : 'YOUR RECORD STANDS AT ' + formatNumber(data.bestScore);
      buildLeaderboardList(el.newhighLeaderboard, data.leaderboard);
      setFormError(el.newhighSubmitError, '');
      show(el.newhighRetry, false);
      setNewhighPhase('result');
    }).catch(function (err) {
      el.newhighRank.textContent = '';
      el.newhighLeaderboard.innerHTML = '';
      setFormError(el.newhighSubmitError, 'Transmission failed: ' + err.message);
      show(el.newhighRetry, true);
      setNewhighPhase('result');
    });
  }

  // Celebration fireworks behind the new-high-score panel. Runs only while
  // that screen is visible; render() starts/stops it.
  var fireworks = (function () {
    var canvas = document.getElementById('newhigh-fireworks');
    var ctx = canvas.getContext('2d');
    var running = false;
    var rockets = [];
    var sparks = [];
    var frame = 0;
    var COLORS = ['#22d3ee', '#34d399', '#fbbf24', '#f43f5e', '#818cf8', '#c084fc'];

    function resize() {
      canvas.width = canvas.clientWidth;
      canvas.height = canvas.clientHeight;
    }

    function launch() {
      rockets.push({
        x: canvas.width * (0.1 + Math.random() * 0.8),
        y: canvas.height,
        vx: (Math.random() - 0.5) * 1.2,
        vy: -(canvas.height * (0.009 + Math.random() * 0.004)),
        targetY: canvas.height * (0.15 + Math.random() * 0.35),
        color: COLORS[Math.floor(Math.random() * COLORS.length)]
      });
    }

    function explode(rocket) {
      var count = 40 + Math.floor(Math.random() * 30);
      for (var i = 0; i < count; i++) {
        var angle = (Math.PI * 2 * i) / count + Math.random() * 0.2;
        var speed = 1.5 + Math.random() * 3.5;
        sparks.push({
          x: rocket.x,
          y: rocket.y,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          life: 1,
          decay: 0.008 + Math.random() * 0.012,
          color: rocket.color
        });
      }
    }

    function tick() {
      if (!running) return;
      frame++;

      // Fade the previous frame toward transparent so sparks leave glowing trails.
      ctx.globalCompositeOperation = 'destination-out';
      ctx.fillStyle = 'rgba(0, 0, 0, 0.16)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = 'lighter';

      if (frame % 45 === 0 || (rockets.length === 0 && sparks.length < 30)) launch();

      for (var i = rockets.length - 1; i >= 0; i--) {
        var r = rockets[i];
        r.x += r.vx;
        r.y += r.vy;
        r.vy += 0.03;
        ctx.globalAlpha = 1;
        ctx.fillStyle = r.color;
        ctx.fillRect(r.x - 1.5, r.y - 1.5, 3, 3);
        if (r.y <= r.targetY || r.vy >= 0) {
          explode(r);
          rockets.splice(i, 1);
        }
      }

      for (var j = sparks.length - 1; j >= 0; j--) {
        var s = sparks[j];
        s.x += s.vx;
        s.y += s.vy;
        s.vx *= 0.985;
        s.vy = s.vy * 0.985 + 0.045; // drag + gravity
        s.life -= s.decay;
        if (s.life <= 0) {
          sparks.splice(j, 1);
          continue;
        }
        ctx.globalAlpha = s.life;
        ctx.fillStyle = s.color;
        ctx.fillRect(s.x - 1.5, s.y - 1.5, 3, 3);
      }
      ctx.globalAlpha = 1;

      requestAnimationFrame(tick);
    }

    window.addEventListener('resize', function () {
      if (running) resize();
    });

    return {
      start: function () {
        if (running) return;
        running = true;
        resize();
        rockets = [];
        sparks = [];
        frame = 0;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        launch();
        requestAnimationFrame(tick);
      },
      stop: function () {
        running = false;
      }
    };
  })();

  // --- Skins shop --------------------------------------------------------

  function getSkin(id) {
    for (var i = 0; i < SKINS.length; i++) {
      if (SKINS[i].id === id) return SKINS[i];
    }
    return SKINS[0];
  }

  function saveWallet() {
    try {
      localStorage.setItem(COINS_KEY, String(coins));
      localStorage.setItem(SKINS_OWNED_KEY, JSON.stringify(ownedSkins));
      localStorage.setItem(SKIN_KEY, selectedSkin);
    } catch (err) { /* storage unavailable — session-only wallet */ }
  }

  function skinSvg(skin) {
    var hull = skin.hull || ['#94a3b8', '#f1f5f9', '#e2e8f0', '#64748b'];
    var win = (skin.window || ['#e0f2fe', '#67e8f9', '#0e7490'])[1];
    var accent = skin.animated ? 'url(#prism-' + skin.id + ')' : skin.accent;
    var defs = skin.animated
      ? '<defs><linearGradient id="prism-' + skin.id + '" x1="0" y1="0" x2="0" y2="1">' +
        '<stop offset="0" stop-color="#f472b6"/><stop offset="0.5" stop-color="#a855f7"/>' +
        '<stop offset="1" stop-color="#22d3ee"/></linearGradient></defs>'
      : '';
    return '<svg viewBox="0 0 40 64">' + defs +
      '<path d="M12 34 L3 52 L13 48 Z" fill="' + accent + '"/>' +
      '<path d="M28 34 L37 52 L27 48 Z" fill="' + accent + '"/>' +
      '<path d="M12 48 L12 22 Q12 6 20 4 Q28 6 28 22 L28 48 Z" fill="' + hull[1] + '" stroke="#fff" stroke-width="0.8"/>' +
      '<path d="M12.5 18 Q13 7 20 4 Q27 7 27.5 18 Q20 13 12.5 18 Z" fill="' + accent + '"/>' +
      '<rect x="12" y="38" width="16" height="3.5" fill="' + accent + '"/>' +
      '<circle cx="20" cy="26" r="4.6" fill="' + win + '" stroke="#cbd5e1" stroke-width="1.6"/>' +
      '<path d="M14 48 L26 48 L28 53 L12 53 Z" fill="#475569"/>' +
      '<path d="M16 54 Q20 63 24 54 Q20 57 16 54 Z" fill="#fb923c"/>' +
      '</svg>';
  }

  function renderSkinsGrid() {
    el.skinsCoins.textContent = formatNumber(coins);
    el.skinsGrid.innerHTML = '';
    SKINS.forEach(function (skin) {
      var owned = ownedSkins.indexOf(skin.id) !== -1;
      var card = document.createElement('button');
      card.className = 'skin-card' + (selectedSkin === skin.id ? ' selected' : (owned ? '' : ' locked'));
      card.innerHTML = skinSvg(skin) +
        '<span class="skin-name">' + skin.name + '</span>' +
        (owned
          ? '<span class="skin-status">' + (selectedSkin === skin.id ? 'EQUIPPED' : 'TAP TO EQUIP') + '</span>'
          : '<span class="skin-status price">' + formatNumber(skin.price) + '</span>');
      card.addEventListener('click', function () { handleSkinClick(skin); });
      el.skinsGrid.appendChild(card);
    });
  }

  function handleSkinClick(skin) {
    setFormError(el.skinsError, '');
    if (ownedSkins.indexOf(skin.id) === -1) {
      if (coins < skin.price) {
        setFormError(el.skinsError,
          'Not enough coins — fly more missions! You need ' + formatNumber(skin.price - coins) + ' more.');
        return;
      }
      coins -= skin.price;
      ownedSkins.push(skin.id);
    }
    selectedSkin = skin.id;
    saveWallet();
    renderSkinsGrid();
  }

  function renderLeaderboardTab() {
    var tabs = el.leaderboardModal.querySelectorAll('.lb-tab');
    Array.prototype.forEach.call(tabs, function (tab) {
      tab.classList.toggle('active', tab.getAttribute('data-mode') === leaderboardTab);
    });
    if (leaderboards) buildLeaderboardList(el.leaderboardList, leaderboards[leaderboardTab]);
  }

  function openLeaderboard() {
    isLeaderboardOpen = true;
    leaderboardTab = currentMode;
    el.leaderboardList.innerHTML = '<div class="lb-empty">Contacting command&hellip;</div>';
    render();
    renderLeaderboardTab();
    window.NeonAuth.getLeaderboards().then(function (boards) {
      leaderboards = boards;
      renderLeaderboardTab();
    }).catch(function () {
      el.leaderboardList.innerHTML = '<div class="lb-empty">COMMS OFFLINE — leaderboard unavailable.</div>';
    });
  }

  function startGame(diff, localMultiplayer, cpuMultiplayer) {
    setScore(0);
    setHealth(100);
    difficulty = diff;
    currentMode = modeFromDifficulty(diff);
    refreshHighScoreDisplays();
    buildModeStrip();
    try {
      bgMusic.currentTime = 0; // each mission starts the track from the top
    } catch (err) { /* metadata not loaded yet */ }
    isLocalMultiplayer = !!localMultiplayer;
    isCPUMultiplayer = !!cpuMultiplayer;
    gameState = 'PLAYING';
    isPaused = false;
    render();

    game.start({
      initialDifficulty: difficulty,
      isLocalMultiplayer: isLocalMultiplayer,
      isCPUMultiplayer: isCPUMultiplayer,
      controlModePreference: controlModePreference,
      skin: getSkin(selectedSkin)
    });
  }

  function returnToStart() {
    gameState = 'START';
    menuMode = 'main';
    isPaused = false;
    game.stop();
    render();
  }

  function setPaused(value) {
    isPaused = value;
    game.setPaused(value);
    render();
  }

  // --- Wiring ------------------------------------------------------------

  function init() {
    var savedControl = null;
    try {
      MODES.forEach(function (mode) {
        var saved = localStorage.getItem(HIGHSCORE_PREFIX + mode);
        if (saved) highScores[mode] = parseInt(saved, 10) || 0;
      });
      savedControl = localStorage.getItem(CONTROL_KEY);

      coins = parseInt(localStorage.getItem(COINS_KEY), 10) || 0;
      var savedOwned = JSON.parse(localStorage.getItem(SKINS_OWNED_KEY) || '[]');
      if (savedOwned instanceof Array && savedOwned.length) {
        if (savedOwned.indexOf('cyan') === -1) savedOwned.push('cyan');
        ownedSkins = savedOwned;
      }
      var savedSkin = localStorage.getItem(SKIN_KEY);
      if (savedSkin && ownedSkins.indexOf(savedSkin) !== -1) selectedSkin = savedSkin;
    } catch (err) { /* storage unavailable — start with defaults */ }
    refreshHighScoreDisplays();
    if (savedControl === 'mouse' || savedControl === 'keyboard' || savedControl === 'both') {
      controlModePreference = savedControl;
      game.setControlModePreference(savedControl);
    }

    var savedSpeed = null;
    try {
      savedSpeed = parseInt(localStorage.getItem(SPEED_KEY), 10);
    } catch (err) { /* storage unavailable */ }
    if (savedSpeed >= 1 && savedSpeed <= 300) {
      el.speedSlider.value = savedSpeed;
    }
    applySpeedSetting();
    el.speedSlider.addEventListener('input', function () {
      applySpeedSetting();
      try {
        localStorage.setItem(SPEED_KEY, el.speedSlider.value);
      } catch (err) { /* storage unavailable — keep for this session */ }
    });

    buildDifficultyButtons();
    buildControlOptions();
    renderControlOptions();
    buildStartStars();
    wireStartParallax();

    Array.prototype.forEach.call(document.querySelectorAll('[data-menu]'), function (button) {
      button.addEventListener('click', function () {
        menuMode = button.getAttribute('data-menu');
        render();
      });
    });

    el.pauseBtn.addEventListener('click', function () { setPaused(!isPaused); });
    el.pauseResume.addEventListener('click', function () { setPaused(false); });
    el.pauseHome.addEventListener('click', returnToStart);
    el.gameoverHome.addEventListener('click', returnToStart);
    el.gameoverRestart.addEventListener('click', function () {
      startGame(difficulty, isLocalMultiplayer, isCPUMultiplayer);
    });
    el.newhighHome.addEventListener('click', returnToStart);
    el.newhighRestart.addEventListener('click', function () {
      startGame(difficulty, isLocalMultiplayer, isCPUMultiplayer);
    });
    el.newhighRetry.addEventListener('click', function () {
      submitPendingScore();
    });

    // --- Auth wiring -----------------------------------------------------

    var auth = window.NeonAuth;

    auth.init(function (authState) {
      // New-device sync: the server bests may beat this browser's localStorage.
      syncServerBests(authState.user);
      render();
    });

    auth.onAuthChange(function (user) {
      if (user) {
        syncServerBests(user);
        if (gameState === 'NEWHIGH' && pendingScore != null) {
          submitPendingScore();
        }
      }
      render();
    });

    auth.onGoogleReady = function () {
      if (gameState === 'NEWHIGH' && newhighPhase === 'offer') {
        auth.renderGoogleButton(el.googleBtnSlot);
      }
    };
    auth.onGoogleError = function (err) {
      setNewhighPhase('offer');
      setFormError(el.loginError, err.message);
    };

    el.logoutLink.addEventListener('click', function () {
      auth.logout().catch(function () { /* stale session — chip clears on next load */ });
    });

    el.showRegister.addEventListener('click', function () { setNewhighPhase('register'); });
    el.showForgot.addEventListener('click', function () { setNewhighPhase('forgot'); });
    el.showLogin.addEventListener('click', function () { setNewhighPhase('offer'); });
    el.showLogin2.addEventListener('click', function () { setNewhighPhase('offer'); });

    el.loginForm.addEventListener('submit', function (e) {
      e.preventDefault();
      setFormError(el.loginError, '');
      auth.login(el.authUser.value.trim(), el.authPass.value).catch(function (err) {
        setFormError(el.loginError, err.message);
      });
    });

    el.registerForm.addEventListener('submit', function (e) {
      e.preventDefault();
      setFormError(el.registerError, '');
      auth.register(el.regUsername.value.trim(), el.regEmail.value.trim(), el.regPassword.value)
        .catch(function (err) {
          setFormError(el.registerError, err.message);
        });
    });

    el.forgotForm.addEventListener('submit', function (e) {
      e.preventDefault();
      setFormError(el.forgotError, '');
      show(el.forgotSent, false);
      auth.requestReset(el.forgotEmail.value.trim()).then(function (data) {
        el.forgotSent.textContent = data.message;
        show(el.forgotSent, true);
      }).catch(function (err) {
        setFormError(el.forgotError, err.message);
      });
    });

    el.resetForm.addEventListener('submit', function (e) {
      e.preventDefault();
      setFormError(el.resetError, '');
      auth.resetPassword(resetToken, el.resetPasswordInput.value).then(function () {
        isResetOpen = false;
        resetToken = null;
        render();
      }).catch(function (err) {
        setFormError(el.resetError, err.message);
      });
    });
    el.resetClose.addEventListener('click', function () {
      isResetOpen = false;
      render();
    });

    // Arriving via an emailed password-reset link (?reset=TOKEN).
    var resetMatch = /[?&]reset=([a-f0-9]{64})/.exec(window.location.search);
    if (resetMatch) {
      resetToken = resetMatch[1];
      isResetOpen = true;
      try {
        window.history.replaceState(null, '', window.location.pathname);
      } catch (err) { /* history API unavailable — the token stays in the URL */ }
    }

    el.seeHighscores.addEventListener('click', openLeaderboard);
    el.leaderboardClose.addEventListener('click', function () {
      isLeaderboardOpen = false;
      render();
    });
    Array.prototype.forEach.call(el.leaderboardModal.querySelectorAll('.lb-tab'), function (tab) {
      tab.addEventListener('click', function () {
        leaderboardTab = tab.getAttribute('data-mode');
        renderLeaderboardTab();
      });
    });

    el.dailyChest.addEventListener('click', claimDailyBonus);

    el.skinsBtn.addEventListener('click', function () {
      setFormError(el.skinsError, '');
      renderSkinsGrid();
      isSkinsOpen = true;
      render();
    });
    el.skinsClose.addEventListener('click', function () {
      isSkinsOpen = false;
      render();
    });

    el.settingsBtn.addEventListener('click', function () {
      isSettingsOpen = true;
      // Never let the pilot die while fiddling with settings mid-flight.
      if (gameState === 'PLAYING' && !isPaused) {
        settingsAutoPaused = true;
        setPaused(true);
      }
      render();
    });
    function closeSettings() {
      isSettingsOpen = false;
      // Resume only if it was our auto-pause; a manual pause stays paused.
      if (settingsAutoPaused) {
        settingsAutoPaused = false;
        if (gameState === 'PLAYING') setPaused(false);
      }
      render();
    }
    el.settingsClose.addEventListener('click', closeSettings);
    el.settingsDone.addEventListener('click', closeSettings);

    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (isSettingsOpen) closeSettings();
      else if (isLeaderboardOpen) { isLeaderboardOpen = false; render(); }
      else if (isSkinsOpen) { isSkinsOpen = false; render(); }
      else if (isResetOpen) { isResetOpen = false; render(); }
      else if (gameState === 'PLAYING') setPaused(!isPaused);
    });

    setScore(0);
    setHealth(100);
    render();
  }

  init();
})();
