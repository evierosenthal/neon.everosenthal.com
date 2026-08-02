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

  var MODES = ['easy', 'medium', 'hard', 'super'];
  var MODE_LABELS = {
    easy: 'EASY MODE',
    medium: 'MEDIUM MODE',
    hard: 'HARD MODE',
    super: 'SUPER HARD MODE'
  };

  var ZAP_ICON = '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
    '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>';

  var DIFFICULTIES = [
    { label: 'EASY MODE', value: 0.3, className: 'btn btn-emerald' },
    { label: 'MEDIUM MODE', value: 0.8, className: 'btn btn-indigo btn-medium' },
    { label: 'HARD MODE', value: 1.2, className: 'btn btn-rose' },
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
  var pendingScore = null; // new high score awaiting server submission
  var pendingMode = null; // mode the pending score was earned in
  var newhighPhase = 'offer'; // 'offer' | 'register' | 'forgot' | 'submitting' | 'result' | 'none'
  var isLeaderboardOpen = false;
  var leaderboards = null; // {easy: [...], medium: [...], ...} cache for the modal
  var leaderboardTab = 'easy';
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
    onDeath: playDeathSound // crash boom at the moment of impact, with the explosion
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

  function render() {
    var playing = gameState === 'PLAYING';
    show(el.canvas, playing);
    show(el.hud, playing);
    show(el.startScreen, gameState === 'START');
    show(el.gameoverScreen, gameState === 'GAMEOVER');
    show(el.newhighScreen, gameState === 'NEWHIGH');
    show(el.pauseScreen, playing && isPaused);
    show(el.settingsModal, isSettingsOpen);
    show(el.leaderboardModal, isLeaderboardOpen);
    show(el.resetModal, isResetOpen);

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

    if (beatRecord) {
      setModeHighScore(currentMode, Math.round(finalScore));

      gameState = 'NEWHIGH';
      pendingScore = Math.round(finalScore);
      pendingMode = currentMode;
      el.newhighMode.textContent = MODE_LABELS[currentMode];
      el.newhighScore.textContent = formatNumber(finalScore);

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
    isLocalMultiplayer = !!localMultiplayer;
    isCPUMultiplayer = !!cpuMultiplayer;
    gameState = 'PLAYING';
    isPaused = false;
    render();

    game.start({
      initialDifficulty: difficulty,
      isLocalMultiplayer: isLocalMultiplayer,
      isCPUMultiplayer: isCPUMultiplayer,
      controlModePreference: controlModePreference
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
    } catch (err) { /* storage unavailable — start with defaults */ }
    refreshHighScoreDisplays();
    if (savedControl === 'mouse' || savedControl === 'keyboard' || savedControl === 'both') {
      controlModePreference = savedControl;
      game.setControlModePreference(savedControl);
    }

    buildDifficultyButtons();
    buildControlOptions();
    renderControlOptions();

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

    el.settingsBtn.addEventListener('click', function () {
      isSettingsOpen = true;
      render();
    });
    function closeSettings() {
      isSettingsOpen = false;
      render();
    }
    el.settingsClose.addEventListener('click', closeSettings);
    el.settingsDone.addEventListener('click', closeSettings);

    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (isSettingsOpen) closeSettings();
      else if (isLeaderboardOpen) { isLeaderboardOpen = false; render(); }
      else if (isResetOpen) { isResetOpen = false; render(); }
      else if (gameState === 'PLAYING') setPaused(!isPaused);
    });

    setScore(0);
    setHealth(100);
    render();
  }

  init();
})();
