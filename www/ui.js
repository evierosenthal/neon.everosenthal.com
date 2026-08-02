/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 *
 * Neon Nebula — menus, HUD and screen flow (plain JavaScript).
 * Port of the original App React component.
 */

(function () {
  'use strict';

  var HIGHSCORE_KEY = 'neon_nebula_highscore';
  var CONTROL_KEY = 'neon_nebula_control_mode';

  var ZAP_ICON = '<svg viewBox="0 0 24 24" class="icon icon-stroke">' +
    '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>';

  var DIFFICULTIES = [
    { label: 'EASY MODE', value: 0.3, className: 'btn btn-emerald' },
    { label: 'MEDIUM MODE', value: 0.85, className: 'btn btn-indigo btn-medium' },
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

  var gameState = 'START'; // 'START' | 'PLAYING' | 'GAMEOVER'
  var menuMode = 'main'; // 'main' | 'two-player' | 'cpu'
  var isLocalMultiplayer = false;
  var isCPUMultiplayer = false;
  var score = 0;
  var highScore = 0;
  var health = 100;
  var isPaused = false;
  var difficulty = 1;
  var controlModePreference = 'both';
  var isSettingsOpen = false;

  var el = {
    canvas: document.getElementById('game-canvas'),
    hud: document.getElementById('hud'),
    hudScore: document.getElementById('hud-score'),
    hudHighScore: document.getElementById('hud-highscore'),
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
    menus: {
      'main': document.getElementById('menu-main'),
      'two-player': document.getElementById('menu-two-player'),
      'cpu': document.getElementById('menu-cpu')
    }
  };

  var game = window.NeonNebula.createGame(el.canvas, {
    onGameOver: handleGameOver,
    onScoreUpdate: setScore,
    onHealthUpdate: setHealth
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

  function setHighScore(value) {
    highScore = value;
    el.hudHighScore.textContent = formatNumber(highScore);
    el.finalHighScore.textContent = formatNumber(highScore);
  }

  function render() {
    var playing = gameState === 'PLAYING';
    show(el.canvas, playing);
    show(el.hud, playing);
    show(el.startScreen, gameState === 'START');
    show(el.gameoverScreen, gameState === 'GAMEOVER');
    show(el.pauseScreen, playing && isPaused);
    show(el.settingsModal, isSettingsOpen);

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
    gameState = 'GAMEOVER';
    game.stop();
    el.finalScore.textContent = formatNumber(finalScore);
    if (finalScore > highScore) {
      setHighScore(finalScore);
      try {
        localStorage.setItem(HIGHSCORE_KEY, String(finalScore));
      } catch (err) { /* storage unavailable — keep the session high score */ }
    }
    render();
  }

  function startGame(diff, localMultiplayer, cpuMultiplayer) {
    setScore(0);
    setHealth(100);
    difficulty = diff;
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
    var savedScore = null;
    var savedControl = null;
    try {
      savedScore = localStorage.getItem(HIGHSCORE_KEY);
      savedControl = localStorage.getItem(CONTROL_KEY);
    } catch (err) { /* storage unavailable — start with defaults */ }

    if (savedScore) setHighScore(parseInt(savedScore, 10) || 0);
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
      else if (gameState === 'PLAYING') setPaused(!isPaused);
    });

    setScore(0);
    setHealth(100);
    render();
  }

  init();
})();
