/**
 * Neon Nebula — auth + leaderboard client (plain JavaScript).
 *
 * Talks to the PHP endpoints in api/. Exposes window.NeonAuth. Never blocks
 * the game: if the API is unreachable, state.offline is set and the game
 * falls back to localStorage-only high scores.
 */

(function () {
  'use strict';

  var state = {
    user: null,       // {id, username, bestScores: {easy,medium,hard,super}} | null
    csrf: null,
    googleClientId: null,
    offline: false,
    ready: false
  };

  var authChangeHandlers = [];
  var googleLoaded = false;

  function emitAuthChange() {
    authChangeHandlers.forEach(function (fn) {
      try { fn(state.user); } catch (err) { /* listener errors stay local */ }
    });
  }

  function request(path, options) {
    return fetch('api/' + path, options).then(function (res) {
      return res.json().then(function (data) {
        if (!res.ok) {
          var err = new Error(data.message || 'Request failed');
          err.code = data.error || 'server_error';
          throw err;
        }
        return data;
      }, function () {
        var err = new Error('Server returned an unreadable response');
        err.code = 'server_error';
        throw err;
      });
    });
  }

  function post(path, body) {
    return request(path, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': state.csrf || ''
      },
      body: JSON.stringify(body || {})
    });
  }

  function applySession(data) {
    if (data.csrf) state.csrf = data.csrf;
    state.user = data.user || null;
  }

  function loadGoogle() {
    if (googleLoaded || !state.googleClientId || state.offline) return;
    googleLoaded = true;
    var script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.onload = function () {
      if (!window.google || !window.google.accounts) return;
      window.google.accounts.id.initialize({
        client_id: state.googleClientId,
        callback: function (response) {
          post('google.php', { credential: response.credential })
            .then(function (data) {
              applySession(data);
              emitAuthChange();
            })
            .catch(function (err) {
              if (window.NeonAuth.onGoogleError) window.NeonAuth.onGoogleError(err);
            });
        }
      });
      if (window.NeonAuth.onGoogleReady) window.NeonAuth.onGoogleReady();
    };
    document.head.appendChild(script);
  }

  window.NeonAuth = {
    state: state,

    // Hooks ui.js can assign: onGoogleReady(), onGoogleError(err)
    onGoogleReady: null,
    onGoogleError: null,

    init: function (callback) {
      request('session.php', { credentials: 'same-origin' })
        .then(function (data) {
          applySession(data);
          state.googleClientId = data.googleClientId || null;
          state.offline = !!data.offline;
          state.ready = true;
          loadGoogle();
          if (callback) callback(state);
          if (state.user) emitAuthChange();
        })
        .catch(function () {
          state.offline = true;
          state.ready = true;
          if (callback) callback(state);
        });
    },

    onAuthChange: function (fn) {
      authChangeHandlers.push(fn);
    },

    renderGoogleButton: function (containerEl) {
      if (!window.google || !window.google.accounts || !containerEl) return false;
      containerEl.innerHTML = '';
      window.google.accounts.id.renderButton(containerEl, {
        theme: 'filled_black',
        size: 'large',
        shape: 'pill',
        text: 'continue_with',
        width: 280
      });
      return true;
    },

    register: function (username, email, password) {
      return post('register.php', { username: username, email: email, password: password })
        .then(function (data) {
          applySession(data);
          emitAuthChange();
          return state.user;
        });
    },

    login: function (usernameOrEmail, password) {
      return post('login.php', { usernameOrEmail: usernameOrEmail, password: password })
        .then(function (data) {
          applySession(data);
          emitAuthChange();
          return state.user;
        });
    },

    logout: function () {
      return post('logout.php', {}).then(function (data) {
        applySession(data);
        emitAuthChange();
      });
    },

    submitScore: function (score, mode) {
      return post('submit-score.php', { score: score, mode: mode });
    },

    getLeaderboards: function () {
      return request('leaderboard.php', { credentials: 'same-origin' })
        .then(function (data) { return data.leaderboards; });
    },

    requestReset: function (email) {
      return post('request-reset.php', { email: email });
    },

    setRole: function (username, role) {
      return post('set-role.php', { username: username, role: role });
    },

    runMigrations: function () {
      return post('run-migrations.php', {});
    },

    resetPassword: function (token, newPassword) {
      return post('reset-password.php', { token: token, newPassword: newPassword })
        .then(function (data) {
          applySession(data);
          emitAuthChange();
          return state.user;
        });
    }
  };
})();
