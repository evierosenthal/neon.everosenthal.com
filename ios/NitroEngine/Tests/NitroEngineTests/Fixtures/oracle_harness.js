// Headless browser stubs so www/game.js runs inside JavaScriptCore for the
// parity tests (OracleParityTests.swift). Evaluated before game.js.
var window = this;
window.innerWidth = 800;
window.innerHeight = 600;
var __listeners = {};
window.addEventListener = function (name, fn) { (__listeners[name] = __listeners[name] || []).push(fn); };
window.removeEventListener = function () {};
window.matchMedia = function () { return { matches: false }; };
var __raf = null;
window.requestAnimationFrame = function (cb) { __raf = cb; return 1; };
window.cancelAnimationFrame = function () { __raf = null; };
window.setTimeout = function () { return 0; };
window.clearTimeout = function () {};
var document = {
  documentElement: {
    style: { setProperty: function () {} },
    classList: { toggle: function () {} }
  }
};
window.document = document;

// A 2d context whose every method is a no-op returning the context itself
// (so gradient.addColorStop() chains work) and whose properties accept any
// assignment.
var __ctx = new Proxy({}, {
  get: function (t, k) { return k in t ? t[k] : function () { return __ctx; }; },
  set: function (t, k, v) { t[k] = v; return true; }
});
var canvas = {
  width: 0,
  height: 0,
  getContext: function () { return __ctx; },
  focus: function () {},
  addEventListener: function () {}
};

// Seeded Math.random: xorshift128+ over a splitmix64-expanded seed, the
// same construction as SeededRNG in Sources/NeonEngine/JSMath.swift.
var __rng = (function () {
  var M = (1n << 64n) - 1n;
  var s0 = 0n, s1 = 0n;
  function seed(v) {
    var x = BigInt(v);
    function splitmix() {
      x = (x + 0x9E3779B97F4A7C15n) & M;
      var z = x;
      z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M;
      z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M;
      return z ^ (z >> 31n);
    }
    s0 = splitmix();
    s1 = splitmix();
    if (s0 === 0n && s1 === 0n) s1 = 1n;
  }
  function next() {
    var a = s0, b = s1;
    s0 = b;
    a ^= (a << 23n) & M;
    a ^= a >> 17n;
    a ^= b ^ (b >> 26n);
    s1 = a;
    return (a + b) & M;
  }
  return {
    seed: seed,
    random: function () { return Number(next() >> 11n) / 9007199254740992; }
  };
})();
Math.random = __rng.random;

// Date.now() advances with the frame counter the test drives.
var __frame = 0;
Date.now = function () { return (1000 / 60) * __frame; };

var __events = { score: 0, health: 100, difficulty: 0, deaths: 0, hits: 0, gameOver: null };
var __callbacks = {
  onGameOver: function (sc) { __events.gameOver = sc; },
  onScoreUpdate: function (v) { __events.score = v; },
  onHealthUpdate: function (v) { __events.health = v; },
  onDifficultyUpdate: function (v) { __events.difficulty = v; },
  onDeath: function () { __events.deaths++; },
  onHit: function () { __events.hits++; }
};

var __keys = {};
function __setKey(key, code, down) {
  if (!!__keys[key] === down) return;
  __keys[key] = down;
  var e = { key: key, code: code, preventDefault: function () {} };
  (__listeners[down ? 'keydown' : 'keyup'] || []).forEach(function (fn) { fn(e); });
}

// Run one requestAnimationFrame callback (game.js loop(): update + draw).
function __step(frame) {
  __frame = frame;
  var cb = __raf;
  __raf = null;
  if (cb) cb();
}

function __snapshot(game) {
  var pos = game.getDebugPositions();
  return JSON.stringify({ p1: pos.p1 || null, p2: pos.p2 || null, score: __events.score,
    health: __events.health, hits: __events.hits, deaths: __events.deaths, gameOver: __events.gameOver });
}
