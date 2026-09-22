/**
 * Nitro Nebula — online two-player networking (plain JavaScript).
 *
 * Exposes window.NeonNet:
 *   NeonNet.lobby.*            thin wrappers over api/games.php (create, invite,
 *                              join, start, status, inbox, ...)
 *   NeonNet.connect(code, role) -> Promise<Session>
 *                              a peer-to-peer WebRTC data channel between host
 *                              and guest; the offer/answer travels through the
 *                              server (games.php 'signal' / 'signals'), after
 *                              that the server is out of the loop.
 *
 * Session: .send(obj) (JSON over a reliable, ordered channel), .close(),
 *          .onMessage = function (obj), .onClose = function (reason)
 */

(function () {
  'use strict';

  var ICE_SERVERS = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ];
  var SIGNAL_POLL_MS = 900;      // how often to ask the server for the other side's SDP
  var ICE_GATHER_WAIT_MS = 2500; // give STUN this long to add candidates, then send anyway
  var CONNECT_TIMEOUT_MS = 30000;

  function api() {
    return window.NeonAuth.api;
  }

  function debug(msg) {
    if (typeof NeonNet.debug === 'function') NeonNet.debug(msg);
  }

  // The browser game links over WebRTC; the iOS app links over Game Center.
  // The server pairs like with like, so every lobby call says which we are.
  var PLATFORM = 'web';

  var lobby = {
    create: function (code, mode) {
      return api().post('games.php', { action: 'create', code: code, mode: mode, platform: PLATFORM }).then(function (d) { return d.game; });
    },
    invite: function (username, code) {
      return api().post('games.php', { action: 'invite', username: username, code: code });
    },
    join: function (code) {
      return api().post('games.php', { action: 'join', code: code, platform: PLATFORM }).then(function (d) { return d.game; });
    },
    decline: function (id) {
      return api().post('games.php', { action: 'decline', id: id });
    },
    start: function (code) {
      return api().post('games.php', { action: 'start', code: code }).then(function (d) { return d.game; });
    },
    leave: function (code) {
      return api().post('games.php', { action: 'leave', code: code });
    },
    finish: function (code) {
      return api().post('games.php', { action: 'finish', code: code });
    },
    inbox: function () {
      return api().get('games.php?action=inbox');
    },
    status: function (code) {
      return api().get('games.php?action=status&code=' + encodeURIComponent(code)).then(function (d) { return d.game; });
    }
  };

  // Resolve once ICE gathering finishes (all candidates are then inside the
  // SDP, so one signal each way is enough), or after a short grace period.
  function waitForIce(pc) {
    return new Promise(function (resolve) {
      if (pc.iceGatheringState === 'complete') { resolve(); return; }
      var done = false;
      var finish = function () { if (!done) { done = true; resolve(); } };
      pc.addEventListener('icegatheringstatechange', function () {
        if (pc.iceGatheringState === 'complete') finish();
      });
      setTimeout(finish, ICE_GATHER_WAIT_MS);
    });
  }

  function Session(code, role) {
    this.code = code;
    this.role = role; // 'host' | 'guest'
    this.pc = null;
    this.channel = null;
    this.open = false;
    this.closed = false;
    this.onMessage = null;
    this.onClose = null;
    this._poll = null;
    this._lastSignalId = 0;
    this._pollFailures = 0;
    this._gotRemote = false;
  }

  Session.prototype.connect = function () {
    var self = this;
    var pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
    self.pc = pc;

    return new Promise(function (resolve, reject) {
      var settled = false;
      var timer = setTimeout(function () {
        if (!self.open) {
          self._close('timeout');
          fail(new Error('Could not connect to your friend. One of your networks may be blocking peer-to-peer play.'));
        }
      }, CONNECT_TIMEOUT_MS);

      function fail(err) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        self._close(err && err.message ? err.message : 'failed');
        reject(err);
      }

      function wire(channel) {
        self.channel = channel;
        channel.onopen = function () {
          debug('channel open (' + self.role + ')');
          self.open = true;
          self._stopPolling();
          clearTimeout(timer);
          if (!settled) { settled = true; resolve(self); }
        };
        channel.onmessage = function (ev) {
          var msg;
          try { msg = JSON.parse(ev.data); } catch (err) { return; }
          if (self.onMessage) self.onMessage(msg);
        };
        channel.onclose = function () { self._close('channel closed'); };
        channel.onerror = function () { self._close('channel error'); };
      }

      pc.onconnectionstatechange = function () {
        debug('connection ' + pc.connectionState);
        if (pc.connectionState === 'failed' || pc.connectionState === 'closed' ||
            (pc.connectionState === 'disconnected' && self.open)) {
          if (!self.open) fail(new Error('The connection to your friend failed.'));
          else self._close('connection ' + pc.connectionState);
        }
      };

      function postSignal(payload) {
        return api().post('games.php', { action: 'signal', code: self.code, payload: payload });
      }

      function handleSignal(msg) {
        if (!msg || self._gotRemote) return;
        if (self.role === 'host' && msg.type === 'answer') {
          self._gotRemote = true;
          pc.setRemoteDescription({ type: 'answer', sdp: msg.sdp }).catch(fail);
        } else if (self.role === 'guest' && msg.type === 'offer') {
          self._gotRemote = true;
          pc.setRemoteDescription({ type: 'offer', sdp: msg.sdp })
            .then(function () { return pc.createAnswer(); })
            .then(function (answer) { return pc.setLocalDescription(answer); })
            .then(function () { return waitForIce(pc); })
            .then(function () { return postSignal({ type: 'answer', sdp: pc.localDescription.sdp }); })
            .catch(fail);
        }
      }

      self._poll = setInterval(function () {
        api().get('games.php?action=signals&code=' + encodeURIComponent(self.code) + '&after=' + self._lastSignalId)
          .then(function (data) {
            self._pollFailures = 0;
            (data.messages || []).forEach(function (m) {
              if (m.id > self._lastSignalId) self._lastSignalId = m.id;
              handleSignal(m.payload);
            });
            if (data.status === 'finished' && !self.open) fail(new Error('The game was closed.'));
          })
          .catch(function (err) {
            self._pollFailures++;
            if (err && (err.code === 'not_found' || err.code === 'forbidden')) fail(new Error('The game was closed.'));
            else if (self._pollFailures > 12) fail(new Error('Lost contact with the server.'));
          });
      }, SIGNAL_POLL_MS);

      if (self.role === 'host') {
        wire(pc.createDataChannel('game', { ordered: true }));
        pc.createOffer()
          .then(function (offer) { return pc.setLocalDescription(offer); })
          .then(function () { return waitForIce(pc); })
          .then(function () { return postSignal({ type: 'offer', sdp: pc.localDescription.sdp }); })
          .catch(fail);
      } else {
        pc.ondatachannel = function (ev) { wire(ev.channel); };
      }
    });
  };

  Session.prototype.send = function (obj) {
    if (!this.channel || this.channel.readyState !== 'open') return false;
    try {
      this.channel.send(JSON.stringify(obj));
      return true;
    } catch (err) {
      return false;
    }
  };

  Session.prototype._stopPolling = function () {
    if (this._poll) { clearInterval(this._poll); this._poll = null; }
  };

  Session.prototype._close = function (reason) {
    if (this.closed) return;
    this.closed = true;
    this.open = false;
    this._stopPolling();
    try { if (this.channel) this.channel.close(); } catch (err) { /* already gone */ }
    try { if (this.pc) this.pc.close(); } catch (err) { /* already gone */ }
    debug('closed: ' + reason);
    if (this.onClose) this.onClose(reason);
  };

  Session.prototype.close = function () {
    var wasOpen = this.open;
    var onClose = this.onClose;
    this.onClose = null; // a deliberate close is not a "lost connection"
    this._close('closed by us');
    this.onClose = onClose;
    return wasOpen;
  };

  var NeonNet = {
    lobby: lobby,
    connect: function (code, role) {
      return new Session(code, role).connect();
    },
    supported: function () {
      return typeof RTCPeerConnection === 'function';
    },
    debug: null
  };
  window.NeonNet = NeonNet;
})();
