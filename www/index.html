<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Neon Nebula</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Inter:wght@300;400;600&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <div class="app">
      <!-- Background Nebula Gradients -->
      <div class="nebula">
        <div class="nebula-blob nebula-indigo"></div>
        <div class="nebula-blob nebula-purple"></div>
        <div class="nebula-blob nebula-emerald"></div>
      </div>

      <!-- Game Layer -->
      <canvas id="game-canvas" tabindex="0" class="game-canvas hidden"></canvas>

      <!-- HUD Layer -->
      <div id="hud" class="hud hidden">
        <div class="hud-inner">
          <div class="hud-bar frosted-glass">
            <div class="hud-group">
              <div class="stack">
                <span class="label label-indigo">Commander Terminal</span>
                <span class="terminal-name">NEBULA PRIME</span>
              </div>
              <div class="hud-divider"></div>
              <div class="hud-group hud-group-tight">
                <div class="stack">
                  <span class="label">Score</span>
                  <span id="hud-score" class="stat-score neon-text-cyan">0</span>
                </div>
                <div class="stack">
                  <span class="label">High Score</span>
                  <span id="hud-highscore" class="stat-high">0</span>
                </div>
              </div>
            </div>

            <div id="hud-modes" class="hud-modes"></div>

            <div class="hud-group hud-group-right">
              <div class="hull">
                <div class="hull-labels">
                  <span>Hull Integrity</span>
                  <span id="hud-health-pct" class="hull-ok">100%</span>
                </div>
                <div class="hull-track">
                  <div id="hud-health-bar" class="hull-fill"></div>
                </div>
              </div>
              <button id="pause-btn" class="icon-button" title="Pause">
                <svg viewBox="0 0 24 24" fill="currentColor" class="icon"><rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/></svg>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Logged-in Pilot Chip (top right) -->
      <div id="user-chip" class="user-chip hidden">
        <span id="user-chip-role" class="user-chip-label">Pilot</span>
        <span id="user-chip-name" class="user-chip-name"></span>
        <button id="logout-link" class="user-chip-logout">Logout</button>
      </div>

      <!-- Logged-out Login Button (top right) -->
      <button id="login-btn" class="user-chip login-btn hidden">LOG IN</button>

      <!-- Login / Create Account Modal -->
      <div id="auth-modal" class="overlay overlay-settings hidden">
        <div class="panel panel-settings">
          <div class="settings-header">
            <div class="settings-header-left">
              <div class="settings-header-icon">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
              </div>
              <div>
                <h3 id="auth-modal-title" class="settings-title">PILOT LOGIN</h3>
                <p class="settings-subtitle">Save your scores on the leaderboard</p>
              </div>
            </div>
            <button id="auth-close" class="close-btn">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
          </div>

          <div id="am-google-slot" class="google-btn-slot"></div>
          <div class="auth-divider"><span>OR</span></div>

          <form id="am-login-form" class="auth-form">
            <input type="text" id="am-user" class="text-input" placeholder="Username or email" autocomplete="username" />
            <input type="password" id="am-pass" class="text-input" placeholder="Password" autocomplete="current-password" />
            <p id="am-login-error" class="auth-error hidden"></p>
            <button type="submit" class="btn btn-cyan btn-sm">LOG IN</button>
          </form>

          <form id="am-register-form" class="auth-form hidden">
            <input type="text" id="am-reg-username" class="text-input" placeholder="Call sign (username)" autocomplete="username" />
            <input type="email" id="am-reg-email" class="text-input" placeholder="Email" autocomplete="email" />
            <input type="password" id="am-reg-password" class="text-input" placeholder="Password (8+ characters)" autocomplete="new-password" />
            <p id="am-register-error" class="auth-error hidden"></p>
            <button type="submit" class="btn btn-cyan btn-sm">CREATE ACCOUNT</button>
          </form>

          <form id="am-forgot-form" class="auth-form hidden">
            <input type="email" id="am-forgot-email" class="text-input" placeholder="Email" autocomplete="email" />
            <p id="am-forgot-error" class="auth-error hidden"></p>
            <p id="am-forgot-sent" class="auth-success hidden"></p>
            <button type="submit" class="btn btn-cyan btn-sm">SEND RESET LINK</button>
          </form>

          <div class="auth-links">
            <button type="button" id="am-show-register" class="link-btn">Create account</button>
            <button type="button" id="am-show-forgot" class="link-btn">Forgot password?</button>
            <button type="button" id="am-show-login" class="link-btn hidden">Back to log in</button>
          </div>
        </div>
      </div>

      <!-- Persistent Top Left Settings Button -->
      <button id="settings-btn" class="settings-btn" title="Flight Control Settings">
        <svg viewBox="0 0 24 24" class="icon icon-stroke gear"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>
        <span class="settings-btn-text">Settings</span>
      </button>

      <!-- Start Screen -->
      <div id="start-screen" class="overlay overlay-start">
        <div class="menu-nebula">
          <span class="mn mn-1"></span>
          <span class="mn mn-2"></span>
          <span class="mn mn-3"></span>
        </div>
        <div id="start-stars" class="start-stars"></div>

        <button id="daily-chest" class="daily-chest">
          <svg viewBox="0 0 48 42">
            <rect x="4" y="18" width="40" height="20" rx="4" fill="#92400e" stroke="#78350f" stroke-width="2"/>
            <path d="M4 22 Q4 8 24 8 Q44 8 44 22 Z" fill="#b45309" stroke="#78350f" stroke-width="2"/>
            <rect x="10" y="9" width="4" height="29" fill="#78350f" opacity="0.55"/>
            <rect x="34" y="9" width="4" height="29" fill="#78350f" opacity="0.55"/>
            <rect x="20" y="16" width="8" height="12" rx="2" fill="#fbbf24" stroke="#b45309" stroke-width="1.5"/>
            <circle cx="24" cy="22" r="2" fill="#78350f"/>
          </svg>
          <span id="daily-chest-label" class="daily-chest-label">DAILY BONUS</span>
        </button>
        <div class="panel panel-start">
          <div class="panel-accent"></div>
          <div class="panel-accent-2"></div>
          <div id="home-rocket" class="home-rocket"></div>

          <!-- Main Menu -->
          <div id="menu-main" class="menu">
            <div class="title-block">
              <h1 class="title">NEON<br />NEBULA</h1>
              <div class="title-rule title-rule-cyan"></div>
            </div>
            <p class="subtitle">Galactic Tactical System // 4.0</p>

            <div class="home-stats">
              <div class="home-stat">
                <span id="home-best" class="home-stat-value home-stat-cyan">0</span>
                <span class="home-stat-label">Best Score</span>
              </div>
              <div class="home-stat">
                <span id="home-coins" class="home-stat-value home-stat-amber">0</span>
                <span class="home-stat-label">Coins</span>
              </div>
              <div class="home-stat">
                <span id="home-pilot" class="home-stat-value home-stat-indigo">GUEST</span>
                <span class="home-stat-label">Pilot</span>
              </div>
            </div>

            <div class="btn-stack">
              <div class="difficulty-buttons" data-mode="single"></div>

              <div class="btn-duo">
                <button class="btn btn-ghost-indigo" data-menu="two-player">
                  <span class="btn-sheen"></span>
                  <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  TWO PLAYER
                </button>

                <button class="btn btn-ghost-rose" data-menu="cpu">
                  <span class="btn-sheen"></span>
                  <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>
                  CPU CO-PILOT
                </button>
              </div>

              <div class="btn-duo">
                <button id="see-highscores" class="btn btn-ghost-cyan">
                  <span class="btn-sheen"></span>
                  <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>
                  HIGH SCORES
                </button>

                <button id="skins-btn" class="btn btn-ghost-indigo">
                  <span class="btn-sheen"></span>
                  <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/></svg>
                  ROCKET SKINS
                </button>
              </div>
            </div>
          </div>

          <!-- Two Player Menu -->
          <div id="menu-two-player" class="menu hidden">
            <button class="back-btn" data-menu="main">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="m12 19-7-7 7-7"/><path d="M19 12H5"/></svg>
              MAIN MENU
            </button>
            <div class="title-block">
              <h1 class="title title-sm">TWO PLAYER MODE</h1>
              <div class="title-rule title-rule-indigo"></div>
            </div>
            <p class="subtitle">Select Co-op Difficulty</p>
            <div class="btn-stack">
              <div class="difficulty-buttons" data-mode="local"></div>
            </div>
          </div>

          <!-- CPU Menu -->
          <div id="menu-cpu" class="menu hidden">
            <button class="back-btn" data-menu="main">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="m12 19-7-7 7-7"/><path d="M19 12H5"/></svg>
              MAIN MENU
            </button>
            <div class="title-block">
              <h1 class="title title-sm">CPU CO-PILOT MODE</h1>
              <div class="title-rule title-rule-rose"></div>
            </div>
            <p class="subtitle">Select AI Companion Difficulty</p>
            <div class="btn-stack">
              <div class="difficulty-buttons" data-mode="cpu"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Game Over Screen -->
      <div id="gameover-screen" class="overlay overlay-gameover hidden">
        <div class="panel panel-gameover">
          <div class="panel-topline"></div>
          <h2 class="gameover-title">SECTOR LOST</h2>
          <p class="gameover-sub">Critical Hull Failure Detected</p>

          <div class="score-card">
            <div class="score-card-label">Efficiency Rating</div>
            <div id="final-score" class="score-card-value">0</div>
            <div class="score-card-rule"></div>
            <div class="score-card-row">
              <span class="score-card-key">COINS EARNED</span>
              <span id="gameover-coins" class="score-card-peak coins-earned">+0</span>
            </div>
            <div class="score-card-row">
              <span class="score-card-key">HISTORICAL PEAK</span>
              <span id="final-highscore" class="score-card-peak neon-text-cyan">0</span>
            </div>
          </div>

          <div class="button-row">
            <button id="gameover-home" class="btn btn-muted btn-flex-1">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
              COMMAND
            </button>
            <button id="gameover-restart" class="btn btn-indigo btn-flex-2">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
              RESTART MISSION
            </button>
          </div>
        </div>
      </div>

      <!-- New High Score Screen -->
      <div id="newhigh-screen" class="overlay overlay-gameover hidden">
        <canvas id="newhigh-fireworks" class="fireworks-canvas"></canvas>
        <div class="panel panel-gameover panel-newhigh">
          <div class="panel-topline panel-topline-cyan"></div>
          <p id="newhigh-mode" class="newhigh-mode"></p>
          <h2 class="newhigh-title">NEW HIGH SCORE!</h2>
          <p class="newhigh-sub">Galactic Record Broken</p>

          <div class="score-card score-card-newhigh">
            <div class="score-card-label">Your New Record</div>
            <div id="newhigh-score" class="score-card-value newhigh-score-value">0</div>
            <p id="newhigh-coins" class="coins-earned coins-earned-big"></p>
          </div>

          <!-- Phase: offer (logged out) — log in / create account / forgot -->
          <div id="newhigh-auth" class="newhigh-phase hidden">
            <p class="newhigh-tagline">Log in to put your name on the leaderboard</p>
            <div id="google-btn-slot" class="google-btn-slot"></div>
            <div class="auth-divider"><span>OR</span></div>

            <form id="newhigh-login-form" class="auth-form">
              <input type="text" id="auth-user" class="text-input" placeholder="Username or email" autocomplete="username" />
              <input type="password" id="auth-pass" class="text-input" placeholder="Password" autocomplete="current-password" />
              <p id="login-error" class="auth-error hidden"></p>
              <button type="submit" class="btn btn-cyan btn-sm">LOG IN &amp; SAVE SCORE</button>
            </form>
            <div class="auth-links">
              <button type="button" id="show-register" class="link-btn">Create account</button>
              <button type="button" id="show-forgot" class="link-btn">Forgot password?</button>
            </div>
          </div>

          <!-- Phase: register -->
          <div id="newhigh-register" class="newhigh-phase hidden">
            <p class="newhigh-tagline">Create an account to save your score</p>
            <form id="newhigh-register-form" class="auth-form">
              <input type="text" id="reg-username" class="text-input" placeholder="Call sign (username)" autocomplete="username" />
              <input type="email" id="reg-email" class="text-input" placeholder="Email" autocomplete="email" />
              <input type="password" id="reg-password" class="text-input" placeholder="Password (8+ characters)" autocomplete="new-password" />
              <p id="register-error" class="auth-error hidden"></p>
              <button type="submit" class="btn btn-cyan btn-sm">CREATE ACCOUNT &amp; SAVE</button>
            </form>
            <div class="auth-links">
              <button type="button" id="show-login" class="link-btn">Back to log in</button>
            </div>
          </div>

          <!-- Phase: forgot password -->
          <div id="newhigh-forgot" class="newhigh-phase hidden">
            <p class="newhigh-tagline">We'll email you a reset link</p>
            <form id="newhigh-forgot-form" class="auth-form">
              <input type="email" id="forgot-email" class="text-input" placeholder="Email" autocomplete="email" />
              <p id="forgot-error" class="auth-error hidden"></p>
              <p id="forgot-sent" class="auth-success hidden"></p>
              <button type="submit" class="btn btn-cyan btn-sm">SEND RESET LINK</button>
            </form>
            <div class="auth-links">
              <button type="button" id="show-login-2" class="link-btn">Back to log in</button>
            </div>
          </div>

          <!-- Phase: submitting -->
          <div id="newhigh-submitting" class="newhigh-phase hidden">
            <p class="newhigh-tagline newhigh-transmitting">TRANSMITTING TO COMMAND&hellip;</p>
          </div>

          <!-- Phase: result -->
          <div id="newhigh-result" class="newhigh-phase hidden">
            <p id="newhigh-rank" class="newhigh-rank"></p>
            <div id="newhigh-leaderboard" class="lb-list lb-list-compact"></div>
            <p id="newhigh-submit-error" class="auth-error hidden"></p>
            <button id="newhigh-retry" class="btn btn-muted btn-sm hidden">RETRY TRANSMISSION</button>
          </div>

          <div class="button-row newhigh-buttons">
            <button id="newhigh-home" class="btn btn-muted btn-flex-1">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
              COMMAND
            </button>
            <button id="newhigh-restart" class="btn btn-indigo btn-flex-2">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
              RESTART MISSION
            </button>
          </div>
        </div>
      </div>

      <!-- Leaderboard Modal -->
      <div id="leaderboard-modal" class="overlay overlay-settings hidden">
        <div class="panel panel-settings">
          <div class="settings-header">
            <div class="settings-header-left">
              <div class="settings-header-icon">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>
              </div>
              <div>
                <h3 class="settings-title">GALACTIC LEADERBOARD</h3>
                <p class="settings-subtitle">Top 10 Commanders</p>
              </div>
            </div>
            <button id="leaderboard-close" class="close-btn">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
          </div>
          <div class="lb-tabs">
            <button class="lb-tab" data-mode="easy">EASY</button>
            <button class="lb-tab" data-mode="medium">MEDIUM</button>
            <button class="lb-tab" data-mode="hard">HARD</button>
            <button class="lb-tab" data-mode="super">SUPER</button>
          </div>
          <div id="leaderboard-list" class="lb-list"></div>
        </div>
      </div>

      <!-- Rocket Skins Modal -->
      <div id="skins-modal" class="overlay overlay-settings hidden">
        <div class="panel panel-settings">
          <div class="settings-header">
            <div class="settings-header-left">
              <div class="settings-header-icon">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/></svg>
              </div>
              <div>
                <h3 class="settings-title">SKIN HANGAR</h3>
                <p class="settings-subtitle">Earn coins by flying missions</p>
              </div>
            </div>
            <div class="skins-header-right">
              <span id="skins-coins" class="coin-chip">0</span>
              <button id="skins-close" class="close-btn">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
              </button>
            </div>
          </div>
          <div id="skins-grid" class="skins-grid"></div>
          <p id="skins-error" class="auth-error hidden"></p>
        </div>
      </div>

      <!-- Password Reset Modal (opened via emailed ?reset=TOKEN link) -->
      <div id="reset-modal" class="overlay overlay-settings hidden">
        <div class="panel panel-settings">
          <div class="settings-header">
            <div class="settings-header-left">
              <div class="settings-header-icon">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
              </div>
              <div>
                <h3 class="settings-title">RESET PASSWORD</h3>
                <p class="settings-subtitle">Choose a new password</p>
              </div>
            </div>
            <button id="reset-close" class="close-btn">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
          </div>
          <form id="reset-form" class="auth-form">
            <input type="password" id="reset-password-input" class="text-input" placeholder="New password (8+ characters)" autocomplete="new-password" />
            <p id="reset-error" class="auth-error hidden"></p>
            <button type="submit" class="btn btn-cyan btn-sm">SET NEW PASSWORD</button>
          </form>
        </div>
      </div>

      <!-- Pause Screen -->
      <div id="pause-screen" class="overlay overlay-pause hidden">
        <div class="panel panel-pause">
          <h2 class="pause-title">SUSPENDED</h2>
          <p class="pause-sub">Awaiting Further Orders</p>
          <div class="btn-stack">
            <button id="pause-resume" class="btn btn-indigo btn-lg">RESUME MISSION</button>
            <button id="pause-home" class="btn btn-muted">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
              RETURN TO HOME
            </button>
          </div>
        </div>
      </div>

      <!-- Settings Modal -->
      <div id="settings-modal" class="overlay overlay-settings hidden">
        <div class="panel panel-settings">
          <div class="settings-header">
            <div class="settings-header-left">
              <div class="settings-header-icon">
                <svg viewBox="0 0 24 24" class="icon icon-stroke"><line x1="21" x2="14" y1="4" y2="4"/><line x1="10" x2="3" y1="4" y2="4"/><line x1="21" x2="12" y1="12" y2="12"/><line x1="8" x2="3" y1="12" y2="12"/><line x1="21" x2="16" y1="20" y2="20"/><line x1="12" x2="3" y1="20" y2="20"/><line x1="14" x2="14" y1="2" y2="6"/><line x1="8" x2="8" y1="10" y2="14"/><line x1="16" x2="16" y1="18" y2="22"/></svg>
              </div>
              <div>
                <h3 class="settings-title">GAME SETTINGS</h3>
                <p class="settings-subtitle">Flight Control Configuration</p>
              </div>
            </div>
            <button id="settings-close" class="close-btn">
              <svg viewBox="0 0 24 24" class="icon icon-stroke"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
          </div>

          <div class="settings-section">
            <label class="settings-label">Player 1 Input Controls</label>
            <div id="control-options" class="control-options"></div>
          </div>

          <div id="dev-console" class="settings-section hidden">
            <label class="settings-label">Developer Accounts</label>
            <div class="dev-console-row">
              <input type="text" id="dev-username" class="text-input" placeholder="Pilot username" />
              <button id="dev-make" class="btn btn-cyan btn-sm">MAKE DEV</button>
              <button id="dev-remove" class="btn btn-muted btn-sm">REMOVE</button>
            </div>
            <p id="dev-console-msg" class="auth-error hidden"></p>
          </div>

          <div class="settings-section">
            <label class="settings-label">
              Rocket Speed
              <span id="speed-value" class="speed-value">100%</span>
            </label>
            <div class="speed-row">
              <span class="speed-end">SLOW</span>
              <input type="range" id="speed-slider" class="speed-slider" min="1" max="300" step="1" value="100" />
              <span class="speed-end">FAST</span>
            </div>
          </div>

          <div class="settings-footer">
            <button id="settings-done" class="btn btn-cyan btn-sm">DONE</button>
          </div>
        </div>
      </div>

      <!-- Subtle Grid Overlay -->
      <div class="grid-overlay"></div>
    </div>

    <script src="game.js"></script>
    <script src="auth.js"></script>
    <script src="ui.js"></script>
  </body>
</html>
