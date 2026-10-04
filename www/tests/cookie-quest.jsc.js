// Headless test for the secret cookie quest in www/game.js.
//
// Run from the repo root with Apple's JavaScriptCore shell:
//   /System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc www/tests/cookie-quest.jsc.js
//
// It reuses the browser stubs + seeded Math.random from the iOS parity
// harness (so the quest's random-call contract is exercised the same way
// the Swift port's OracleParityTests exercise it) and drives game.js with
// synthetic arrow keys. Any failure throws, which makes jsc exit non-zero.

load('ios/NitroEngine/Tests/NitroEngineTests/Fixtures/oracle_harness.js');
load('www/game.js');

var failures = 0;
function check(cond, message) {
  if (!cond) {
    failures++;
    print('FAIL: ' + message);
  }
}
function section(name) { print('--- ' + name); }

// Count every Math.random() so the "Hard draws exactly one extra random in
// reset()" rule can be asserted.
var randomCalls = 0;
var seededRandom = Math.random;
Math.random = function () { randomCalls++; return seededRandom(); };

var MAGNET_FLAME = { id: 'magnetmuzzle', name: 'Magnet Muzzle', price: 2000, style: 'rings', power: 'magnet' };

function newGame(extraCallbacks) {
  var cb = {};
  Object.keys(__callbacks).forEach(function (k) { cb[k] = __callbacks[k]; });
  Object.keys(extraCallbacks || {}).forEach(function (k) { cb[k] = extraCallbacks[k]; });
  __events.score = 0; __events.health = 100; __events.difficulty = 0;
  __events.deaths = 0; __events.hits = 0; __events.gameOver = null;
  __frame = 0;
  __keys = {};
  return NeonNebula.createGame(canvas, cb);
}

function releaseKeys() {
  ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].forEach(function (k) { __setKey(k, k, false); });
}

function steer(dx, dy) {
  var dead = 6;
  __setKey('ArrowRight', 'ArrowRight', dx > dead);
  __setKey('ArrowLeft', 'ArrowLeft', dx < -dead);
  __setKey('ArrowDown', 'ArrowDown', dy > dead);
  __setKey('ArrowUp', 'ArrowUp', dy < -dead);
}

// Shared steering for the scripted runs. Picks the lane (x) with the least
// predicted asteroid traffic over the next 60 frames around `rowY`, with a
// pull toward `wantX` (a cookie, the jar...) and, when `avoidCookies` is
// set, a push away from raining cookies (the fail path must not win).
function safeLaneX(d, p, wantX, rowY, avoidCookies) {
  var bestX = p.x, bestDanger = Infinity;
  for (var lane = 60; lane <= 740; lane += 40) {
    var danger = Math.abs(lane - wantX) / 150;
    d.asteroids.forEach(function (a) {
      var closest = Infinity;
      for (var t = 0; t <= 60; t += 4) {
        var ax = a.x + a.vx * t, ay = a.y + a.vy * t;
        var ddx = ax - lane, ddy = ay - rowY;
        var dist = Math.sqrt(ddx * ddx + ddy * ddy) - a.r - 15;
        if (dist < closest) closest = dist;
      }
      if (closest < 70) danger += 3 * (70 - closest) / 70;
    });
    if (avoidCookies) {
      d.questCookies.forEach(function (c) {
        if (c.y < rowY && Math.abs(c.x - lane) < 50) danger += 1.5;
      });
    }
    if (danger < bestDanger) { bestDanger = danger; bestX = lane; }
  }
  return bestX;
}

// Before the quest: dodge, and intercept the drifting cookie once it shows.
function preQuestTarget(d, p) {
  if (d.cookie) return { x: safeLaneX(d, p, d.cookie.x, d.cookie.y, false), y: d.cookie.y };
  return { x: safeLaneX(d, p, 400, 300, false), y: 300 };
}

// ---------------------------------------------------------------------------
section('random-call contract of start()');

function randomsInStart(options) {
  __rng.seed(7);
  var game = newGame();
  var before = randomCalls;
  game.start(options);
  var used = randomCalls - before;
  game.stop();
  return used;
}

var easy = randomsInStart({ initialDifficulty: 0.3 });
var medium = randomsInStart({ initialDifficulty: 0.62 });
var hard = randomsInStart({ initialDifficulty: 1.3 });
var hardHooked = randomsInStart({ initialDifficulty: 1.3, cookieSpawnFrame: 300 });
var superHard = randomsInStart({ initialDifficulty: 6.0 });
var online = randomsInStart({ initialDifficulty: 1.3, online: { role: 'host', send: function () {} } });
check(medium === easy, 'Medium start draws the same randoms as Easy (' + medium + ' vs ' + easy + ')');
check(superHard === easy, 'Super Hard start draws the same randoms as Easy (' + superHard + ' vs ' + easy + ')');
check(online === easy, 'online Hard start draws the same randoms as Easy (' + online + ' vs ' + easy + ')');
check(hardHooked === easy, 'Hard with cookieSpawnFrame hook draws no extra random (' + hardHooked + ' vs ' + easy + ')');
check(hard === easy + 1, 'Hard start draws exactly one extra random (' + hard + ' vs ' + easy + ')');

// ---------------------------------------------------------------------------
section('fail path: catch the cookie, dodge, let level 1 time out');

(function () {
  __rng.seed(8);
  var events = [];
  var game = newGame({
    onQuestEvent: function (kind, level) { events.push(kind + ':' + level); },
    onQuestComplete: function () { events.push('complete'); }
  });
  game.start({ initialDifficulty: 1.3, cookieSpawnFrame: 120, cookieAimAtShip: true });
  releaseKeys();

  var sawCookie = false, cookieStartX = null, cookieEndX = null;
  var questStartFrame = -1, playStartFrame = -1, failedFrame = -1, clearedFrame = -1;
  var lastDifficultyFrame = -1, lastDifficulty = __events.difficulty;
  var asteroidsDuringPlay = 0, burntDuringL1 = 0, maxCollected = 0;
  var maxFrames = 120 + 400 + 120 + 1800 + 120 + 600;
  for (var f = 0; f < maxFrames; f++) {
    var d = game.getDebugPositions();
    var p = d.p1;
    // Dodge while waiting for the cookie and intercept it; then keep to the
    // safest lane and steer away from cookies so level 1 runs out of time
    // instead of being won.
    var target = d.quest ? { x: safeLaneX(d, p, p.x, 330, true), y: 330 } : preQuestTarget(d, p);
    var dx = target.x - p.x, dy = target.y - p.y;
    steer(dx, dy);
    __step(f);
    d = game.getDebugPositions();
    if (__events.difficulty !== lastDifficulty) { lastDifficulty = __events.difficulty; lastDifficultyFrame = f; }
    if (d.cookie) {
      if (!sawCookie) { sawCookie = true; cookieStartX = d.cookie.x; check(d.frame === 120, 'cookie appears on its spawn frame (frame ' + d.frame + ')'); }
      cookieEndX = d.cookie.x;
    }
    if (d.quest) {
      if (questStartFrame < 0) {
        questStartFrame = f;
        check(d.quest.phase === 'intro' && d.quest.level === 1, 'quest opens on level 1 intro');
        check(d.asteroids.length === 0, 'field is cleared when the cookie is caught');
      }
      if (d.quest.phase === 'play') {
        if (playStartFrame < 0) playStartFrame = f;
        asteroidsDuringPlay += d.asteroids.length;
        maxCollected = Math.max(maxCollected, d.quest.collected);
        d.asteroids.forEach(function (a) { if (a.style === 'burnt') burntDuringL1++; });
      }
      if (d.quest.phase === 'failed' && failedFrame < 0) failedFrame = f;
    } else if (failedFrame >= 0 && clearedFrame < 0) {
      clearedFrame = f;
    }
    if (clearedFrame >= 0 && f > clearedFrame + 60) break;
    if (__events.gameOver !== null) break;
  }
  check(sawCookie, 'the drifting cookie appeared');
  check(cookieEndX !== cookieStartX, 'the cookie drifted');
  check(questStartFrame > 0, 'the still ship caught the cookie aimed at it');
  check(playStartFrame === questStartFrame + 120, 'intro banner lasts 120 frames (' + questStartFrame + ' -> ' + playStartFrame + ')');
  check(__events.gameOver === null, 'ship survived through the quest (died at score ' + __events.gameOver + ', collected ' + maxCollected + ')');
  check(failedFrame === playStartFrame + 1800, 'level 1 times out after 1800 play frames (' + playStartFrame + ' -> ' + failedFrame + ', collected ' + maxCollected + '/10)');
  check(clearedFrame === failedFrame + 120, 'failed banner lasts 120 frames then the quest ends');
  check(asteroidsDuringPlay > 0, 'the normal asteroids keep spawning during level 1');
  check(burntDuringL1 === 0, 'no burnt cookies in level 1');
  check(lastDifficultyFrame < questStartFrame || lastDifficultyFrame > clearedFrame, 'difficulty is frozen during the quest');
  check(events.join(',') === 'start:1,failed:1', 'events: ' + events.join(','));
  print('fail path: collected ' + maxCollected + '/10, health ' + __events.health + ', hits ' + __events.hits);
  game.stop();
})();

// ---------------------------------------------------------------------------
section('complete path: magnet flame, homing ship, crack the jar');

(function () {
  __rng.seed(1234);
  var events = [];
  var completes = 0;
  var game = newGame({
    onQuestEvent: function (kind, level) { events.push(kind + ':' + level); },
    onQuestComplete: function () { completes++; events.push('complete'); }
  });
  game.start({ initialDifficulty: 1.3, cookieSpawnFrame: 120, cookieAimAtShip: true, flame: MAGNET_FLAME });
  releaseKeys();

  var lastScore = __events.score;
  var badDeltas = [];
  var completeFrame = -1, endFrame = -1, maxBossHp = 0, sawBurnt = false;
  var maxFrames = 9000;
  for (var f = 0; f < maxFrames; f++) {
    var d = game.getDebugPositions();
    var p = d.p1;
    var q = d.quest;
    var dx = 0, dy = 0;
    if (q && q.phase === 'play' && d.boss) {
      // Level 3: shadow the jar from ~170 px below along the safest lane
      // (the planner dodges its crumbs and cookies) and let the blasters work.
      var rowY = Math.min(d.boss.y + 170, 560);
      dx = safeLaneX(d, p, d.boss.x + 30, rowY, false) - p.x;
      dy = rowY - p.y;
      maxBossHp = Math.max(maxBossHp, d.boss.hp);
    } else if (q && q.phase === 'play') {
      // Levels 1–2: head for the nearest cookie above us (the magnet drags
      // them in) along the safest lane past the asteroids / burnt cookies.
      var wantX = 400, ty = 330, best = Infinity;
      d.questCookies.forEach(function (c) {
        var dist = Math.abs(c.x - p.x) + Math.abs(c.y - p.y);
        if (c.y < p.y + 40 && dist < best) { best = dist; wantX = c.x; ty = Math.max(c.y + 60, 200); }
      });
      d.asteroids.forEach(function (a) { if (a.style === 'burnt') sawBurnt = true; });
      dx = safeLaneX(d, p, wantX, ty, false) - p.x; dy = ty - p.y;
    } else if (!q) {
      var pre = preQuestTarget(d, p);
      dx = pre.x - p.x; dy = pre.y - p.y;
    }
    steer(dx, dy);
    __step(f);

    var delta = __events.score - lastScore;
    lastScore = __events.score;
    // Level 2 has only burnt cookies (no regular asteroids), so a +10 there
    // can only be a burnt cookie wrongly paid for leaving the screen.
    if (q && q.phase === 'play' && q.level === 2 && (delta === 10 || delta === 30)) badDeltas.push(f + ':' + delta);
    if (completes === 1 && completeFrame < 0) completeFrame = f;
    var after = game.getDebugPositions();
    if (completeFrame >= 0 && !after.quest && endFrame < 0) { endFrame = f; break; }
    if (__events.gameOver !== null) break;
  }
  check(__events.gameOver === null, 'ship survived the complete path (died at score ' + __events.gameOver + ', events ' + events.join(',') + ')');
  check(completes === 1, 'onQuestComplete fired exactly once (' + completes + '); events ' + events.join(','));
  check(events.join(',') === 'start:1,levelWon:1,levelWon:2,levelWon:3,complete', 'event order: ' + events.join(','));
  check(maxBossHp > 0 && maxBossHp <= 50, 'boss hp is within 50 when first seen (' + maxBossHp + ')');
  check(sawBurnt, 'burnt cookies fell during level 2');
  check(badDeltas.length === 0, 'burnt cookies never pay the off-screen +10 in level 2 (deltas ' + badDeltas.join(' ') + ')');
  check(endFrame > 0 && endFrame === completeFrame + 180, 'complete banner lasts 180 frames (' + completeFrame + ' -> ' + endFrame + ')');
  print('complete path: ' + (endFrame + 1) + ' frames, score ' + __events.score + ', health ' + __events.health + ', hits ' + __events.hits);
  game.stop();
})();

// ---------------------------------------------------------------------------
if (failures > 0) {
  throw new Error(failures + ' cookie quest check(s) failed');
}
print('cookie-quest: all checks passed');
