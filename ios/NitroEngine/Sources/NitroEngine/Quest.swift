import Foundation

// game.js:1312-1644 — the secret cookie quest. Everything here only runs for
// local (never online) Hard runs; see reset() for the eligibility rule and
// update() for where each piece sits in the frame. Every Math.random() maps
// to exactly one random()/randomId() here, in the JavaScript's order.
extension GameEngine {

    /// game.js:1347-1349 questLevelDef()
    var questLevelDef: QuestLevelDef {
        GameConstants.questLevels[s.quest!.level - 1]
    }

    /// game.js:1319-1343 updateDriftingCookie: the drifting cookie appears
    /// on `cookieSpawnFrame` (only while no quest is running — this is only
    /// called then), wobbles across the screen and starts the quest when a
    /// ship touches it. Runs in updateSpawns()'s slot, right after
    /// updateSpawns(). Randoms: the factory's three on the spawn frame; on a
    /// catch, startQuest()'s bursts and then the "SECRET LEVEL!" text id.
    func updateDriftingCookie() {
        if s.frame == s.cookieSpawnFrame && s.cookie == nil {
            s.cookie = createDriftingCookie(width: worldSize.width, height: worldSize.height)
        }
        guard s.cookie != nil else { return }
        s.cookie!.x += s.cookie!.vx
        s.cookie!.y += sin(Double(s.frame) / 25 + s.cookie!.wobble) * 0.7
        s.cookie!.rotation += s.cookie!.spin
        let c = s.cookie!
        let ships: [Player?] = [s.player, s.player2]
        for maybe in ships {
            guard let p = maybe else { continue }
            let dx = p.x - c.x
            let dy = p.y - c.y
            if (dx * dx + dy * dy).squareRoot() < c.radius + p.radius + 8 {
                let cx = c.x
                let cy = c.y
                startQuest()
                addFloatingText(x: cx, y: cy, text: "SECRET LEVEL!", color: GameConstants.cookieGold, scale: 1.6)
                shake = 8
                return
            }
        }
        // Gone once it is 60 px past the far edge
        if (c.vx > 0 && c.x > worldSize.width + 60) || (c.vx < 0 && c.x < -60) {
            s.cookie = nil
        }
    }

    /// game.js:1352-1372 startQuest: catching the cookie wipes the field —
    /// every asteroid bursts into 6 of its own-colored particles
    /// (createParticle, asteroid array order), then asteroids, orbs and
    /// treats are cleared — and level 1's intro begins.
    func startQuest() {
        for a in s.asteroids {
            for _ in 0..<6 { s.particles.append(createParticle(x: a.x, y: a.y, color: a.color)) }
        }
        s.asteroids = []
        s.powerUps = []
        s.collectibles = []
        s.cookie = nil
        s.quest = QuestState(
            level: 1,
            phase: .intro,
            phaseTimer: 120,  // frames left in a banner phase
            timer: 0,         // play frames elapsed in this level
            goal: GameConstants.questLevels[0].goal,
            collected: 0,
            cookies: [],
            boss: nil)
        delegate?.engine(self, questEvent: .start, level: 1)
    }

    /// game.js:1378-1398 beginQuestPlay — intro -> play: the blasters are
    /// granted for the whole level (plus 300 frames of slack) and level 3
    /// gets its boss. No randoms.
    func beginQuestPlay() {
        s.quest!.phase = .play
        s.quest!.timer = 0
        if s.quest!.level == 3 {
            s.quest!.boss = QuestBoss(
                x: worldSize.width / 2,
                y: worldSize.height * 0.28,
                vx: 4.8,
                vy: 2.9,
                radius: 58,
                hp: config.questBossHP ?? GameConstants.questBossHP,
                maxHp: config.questBossHP ?? GameConstants.questBossHP,
                rotation: 0,
                hitFlash: 0,
                contactCooldown: 0) // ship-bump immunity frames (see updateQuestBoss)
            for _ in 0..<GameConstants.questSunCount {
                s.quest!.suns.append(createQuestSun(width: worldSize.width, height: worldSize.height))
            }
            s.quest!.suns[0].hunter = true // the first sun hunts
        }
        // Every level drops a W orb: the blasters have to be picked up.
        s.powerUps.append(createQuestWeaponOrb(width: worldSize.width, height: worldSize.height))
    }

    func hasWeaponOrbWaiting() -> Bool {
        s.powerUps.contains { $0.subType == .weapon }
    }

    /// game.js:1400-1406
    func questLevelWon() {
        s.quest!.phase = .won
        s.quest!.phaseTimer = 120
        s.quest!.boss = nil
        s.quest!.suns = []
        delegate?.engine(self, questEvent: .levelWon, level: s.quest!.level)
    }

    /// game.js:1408-1414
    func questFailed() {
        s.quest!.phase = .failed
        s.quest!.phaseTimer = 120
        s.quest!.boss = nil
        s.quest!.suns = []
        delegate?.engine(self, questEvent: .failed, level: s.quest!.level)
    }

    /// game.js:1416-1486 updateQuest: phase machine + per-frame spawn rolls
    /// + boss motion. Runs in updateSpawns()'s slot while a quest is active,
    /// so no asteroids, treats or orbs spawn during a quest.
    /// Randoms per play frame, in order: the cookie-rain roll (levels 1-2;
    /// not rolled when `rain` is 0), then the burnt-cookie roll (levels 2-3;
    /// not rolled when `burnt` is 0), each followed by its factory's draws
    /// on a hit; then, on level 3 every 150th play frame, the 8 crumb ids.
    /// Banner phases and the intro draw nothing.
    func updateQuest() {
        let def = questLevelDef
        if s.quest!.phase == .intro {
            s.quest!.phaseTimer -= 1
            if s.quest!.phaseTimer <= 0 { beginQuestPlay() }
            return
        }
        if s.quest!.phase == .play {
            s.quest!.timer += 1
            if def.asteroids > 0 { spawnAsteroids(scale: def.asteroids) } // asteroid rolls first (game.js updateQuest)
            if def.rain > 0 && random() < def.rain {
                s.quest!.cookies.append(createQuestCookie(width: worldSize.width))
            }
            if def.burnt > 0 && random() < def.burnt {
                s.asteroids.append(createBurntCookie(width: worldSize.width, height: worldSize.height))
            }
            if var b = s.quest!.boss {
                b.x += b.vx
                b.y += b.vy
                b.rotation += 0.004
                // Bounce off the world bounds, `radius` in from each edge
                if b.x < b.radius { b.x = b.radius; b.vx = abs(b.vx) }
                if b.x > worldSize.width - b.radius { b.x = worldSize.width - b.radius; b.vx = -abs(b.vx) }
                if b.y < b.radius { b.y = b.radius; b.vy = abs(b.vy) }
                if b.y > worldSize.height - b.radius { b.y = worldSize.height - b.radius; b.vy = -abs(b.vy) }
                if b.hitFlash > 0 { b.hitFlash -= 1 }
                if b.contactCooldown > 0 { b.contactCooldown -= 1 }
                s.quest!.boss = b
                if s.quest!.timer % GameConstants.questBossFireInterval == 0 {
                    for i in 0..<8 {
                        let ang = (Double(i) / 8) * Double.pi * 2
                        s.asteroids.append(createCrumb(
                            x: b.x + cos(ang) * (b.radius + 12),
                            y: b.y + sin(ang) * (b.radius + 12),
                            angle: ang))
                    }
                    // ...and four burnt cookie asteroids on the diagonals between them
                    for k in 0..<4 {
                        let cang = ((Double(k) + 0.5) / 4) * Double.pi * 2
                        s.asteroids.append(createBossCookie(
                            x: b.x + cos(cang) * (b.radius + 18),
                            y: b.y + sin(cang) * (b.radius + 18),
                            angle: cang))
                    }
                }
            }
            if s.quest!.level == 3 && s.quest!.timer % GameConstants.questWeaponResupply == 0
                && s.activeEffects.weaponUpgrade <= 0 && !hasWeaponOrbWaiting() {
                s.powerUps.append(createQuestWeaponOrb(width: worldSize.width, height: worldSize.height))
            }
            if s.quest!.timer >= def.duration { questFailed() }
            return
        }
        // Banner phases: 'won', 'failed', 'complete'
        s.quest!.phaseTimer -= 1
        if s.quest!.phaseTimer > 0 { return }
        if s.quest!.phase == .won {
            if s.quest!.level < 3 {
                s.quest!.level += 1
                s.quest!.phase = .intro
                s.quest!.phaseTimer = 120
                s.quest!.timer = 0
                s.quest!.goal = GameConstants.questLevels[s.quest!.level - 1].goal
                s.quest!.collected = 0
                s.quest!.cookies = []
            } else {
                s.quest!.phase = .complete
                s.quest!.phaseTimer = 180
                delegate?.engineDidCompleteQuest(self)
            }
        } else {
            s.quest = nil // 'complete' or 'failed': back to the nebula
        }
    }

    /// game.js:1492-1524 updateQuestCookies: quest cookies fall (magnet
    /// pulls them exactly like treats) and are picked up during the play
    /// phase: +50, collected++. Runs right after updateCollectibles().
    /// Randoms per pickup, in order: the "+50" text id, then
    /// createShockwaveRing's 6 particles (life + id each).
    func updateQuestCookies() {
        let w = worldSize.width, h = worldSize.height
        var i = s.quest!.cookies.count - 1
        while i >= 0 {
            defer { i -= 1 }
            var pulled = s.quest!.cookies[i]
            applyMagnetPull(&pulled)
            s.quest!.cookies[i] = pulled
            s.quest!.cookies[i].x += s.quest!.cookies[i].vx
            s.quest!.cookies[i].y += s.quest!.cookies[i].vy
            s.quest!.cookies[i].rotation += s.quest!.cookies[i].spin
            let c = s.quest!.cookies[i]
            // Gone below the screen (or flung far off by the magnet)
            if c.y > h + 40 || c.y < -300 || c.x < -300 || c.x > w + 300 {
                s.quest!.cookies.remove(at: i)
                continue
            }
            if s.quest!.phase != .play { continue }
            let players: [Player?] = [s.player, s.player2]
            for maybe in players {
                guard let p = maybe else { continue }
                let dx = p.x - c.x
                let dy = p.y - c.y
                if (dx * dx + dy * dy).squareRoot() < c.radius + p.radius + 10 {
                    s.score += 50
                    s.quest!.collected += 1
                    delegate?.engine(self, scoreDidChange: s.score)
                    addFloatingText(x: c.x, y: c.y, text: "+50", color: GameConstants.cookieGold, scale: 0.95)
                    createShockwaveRing(x: c.x, y: c.y, color: GameConstants.cookieColor, count: 6)
                    s.quest!.cookies.remove(at: i)
                    if s.quest!.collected >= s.quest!.goal && s.quest!.level < 3 { questLevelWon() }
                    break
                }
            }
        }
    }

    /// game.js:1526-1644 updateQuestBoss: the Giant Cookie's collisions.
    /// Runs right after updateAsteroids(), only while `quest.boss` exists.
    /// Projectiles within radius + 4 hit (+5, hp--, flash, ring); a ship
    /// touching it is pushed out along the normal with its inward velocity
    /// zeroed and takes the asteroid damage path (overthrusters: no damage,
    /// the boss is NOT destroyed; shield absorbs; else hull damage with the
    /// armor/fragile rules), with a 45-frame contact cooldown so one bump
    /// doesn't drain the hull every frame. Randoms, in order: per projectile
    /// hit (projectile array order, last to first; the loop stops once hp
    /// reaches 0) the ring's 5 particles; if hp <= 0: 3 rings of 16, 40
    /// createParticle, the "COOKIE JAR CRACKED!" text id; else per ship bump
    /// the same particles/text as the matching asteroid-hit branch.
    /// game.js updateQuestSuns: level 3's suns fly, bounce, warm up, and burn
    /// any ship that touches one once armed — instant death, no shield, no
    /// armor. Randoms on a burn, in order: the "SOLAR FLARE!" text id, the
    /// ring's 22 particles, then 16 createParticle.
    func updateQuestSuns() {
        let w = worldSize.width, h = worldSize.height
        for i in s.quest!.suns.indices {
            var sun = s.quest!.suns[i]
            if sun.hunter {
                // Steer toward the nearest ship, capped at the hunter's speed
                var target: Player? = nil
                var best = Double.infinity
                for sp in [s.player, s.player2].compactMap({ $0 }) {
                    let tdx = sp.x - sun.x, tdy = sp.y - sun.y
                    let td = (tdx * tdx + tdy * tdy).squareRoot()
                    if td < best { best = td; target = sp }
                }
                if let target, best > 0 {
                    sun.vx += ((target.x - sun.x) / best) * GameConstants.questHunterAccel
                    sun.vy += ((target.y - sun.y) / best) * GameConstants.questHunterAccel
                    let sp2 = (sun.vx * sun.vx + sun.vy * sun.vy).squareRoot()
                    if sp2 > GameConstants.questHunterSpeed {
                        sun.vx = (sun.vx / sp2) * GameConstants.questHunterSpeed
                        sun.vy = (sun.vy / sp2) * GameConstants.questHunterSpeed
                    }
                }
            }
            sun.x += sun.vx
            sun.y += sun.vy
            if sun.x < sun.radius { sun.x = sun.radius; sun.vx = abs(sun.vx) }
            if sun.x > w - sun.radius { sun.x = w - sun.radius; sun.vx = -abs(sun.vx) }
            if sun.y < sun.radius { sun.y = sun.radius; sun.vy = abs(sun.vy) }
            if sun.y > h - sun.radius { sun.y = h - sun.radius; sun.vy = -abs(sun.vy) }
            if sun.armTimer > 0 { sun.armTimer -= 1 }
            s.quest!.suns[i] = sun
        }
        if s.quest!.phase != .play || s.dying { return }
        for hot in s.quest!.suns where hot.armTimer <= 0 {
            for p in [s.player, s.player2].compactMap({ $0 }) {
                let dx = p.x - hot.x
                let dy = p.y - hot.y
                if (dx * dx + dy * dy).squareRoot() >= hot.radius + p.radius - 2 { continue }
                s.health = 0
                delegate?.engine(self, healthDidChange: s.health)
                shake = 24
                addFloatingText(x: p.x, y: p.y, text: "SOLAR FLARE!", color: GameConstants.sunColor, scale: 1.3)
                createShockwaveRing(x: hot.x, y: hot.y, color: GameConstants.sunColor, count: 22)
                for _ in 0..<16 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#fde68a")) }
                startDeathSequence(deadPlayer: p, killerX: hot.x, killerY: hot.y, killerColor: GameConstants.sunColor)
                return
            }
        }
    }

    func updateQuestBoss() {
        if s.quest!.phase != .play { return }
        var j = s.projectiles.count - 1
        while j >= 0 {
            let b = s.quest!.boss!
            let proj = s.projectiles[j]
            let pdx = proj.x - b.x
            let pdy = proj.y - b.y
            if (pdx * pdx + pdy * pdy).squareRoot() < b.radius + 4 {
                s.projectiles.remove(at: j)
                s.quest!.boss!.hp -= 1
                s.quest!.boss!.hitFlash = 8
                s.score += 5
                delegate?.engine(self, scoreDidChange: s.score)
                createShockwaveRing(x: proj.x, y: proj.y, color: GameConstants.cookieColor, count: 5)
                if s.quest!.boss!.hp <= 0 { break }
            }
            j -= 1
        }
        let b = s.quest!.boss!
        if b.hp <= 0 {
            let colors: [CSSColor] = [GameConstants.cookieColor, "#8b5a2b", "#fde68a"]
            for r in 0..<3 { createShockwaveRing(x: b.x, y: b.y, color: colors[r], count: 16) }
            for n in 0..<40 { s.particles.append(createParticle(x: b.x, y: b.y, color: colors[n % 3])) }
            addFloatingText(x: b.x, y: b.y, text: "COOKIE JAR CRACKED!", color: GameConstants.cookieGold, scale: 1.8)
            s.score += 500
            delegate?.engine(self, scoreDidChange: s.score)
            shake = 18
            questLevelWon()
            return
        }
        for k in 0..<2 {
            // ships = [state.player, state.player2]; `p` is a reference in the
            // JS, so the push-out below is written back to the state.
            guard var p = (k == 0 ? s.player : s.player2) else { continue }
            let dx = p.x - b.x
            let dy = p.y - b.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist >= b.radius + p.radius { continue }
            let nx = dist > 0 ? dx / dist : 0
            let ny = dist > 0 ? dy / dist : -1
            // Push the ship out along the normal and kill its inward velocity
            p.x = b.x + nx * (b.radius + p.radius)
            p.y = b.y + ny * (b.radius + p.radius)
            let dot = p.vx * nx + p.vy * ny
            if dot < 0 {
                p.vx -= dot * nx
                p.vy -= dot * ny
            }
            if k == 0 { s.player = p } else { s.player2 = p }
            if s.activeEffects.speedBoost > 0 {
                // Ramming only bounces the ship off — the jar doesn't budge
                shake = 5
                for _ in 0..<8 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#22c55e")) }
                continue
            }
            if s.quest!.boss!.contactCooldown > 0 { continue }
            s.quest!.boss!.contactCooldown = GameConstants.questBossContactCooldown
            if s.activeEffects.shield > 0 {
                s.activeEffects.shield = max(0, s.activeEffects.shield - 100)
                shake = 6
                addFloatingText(x: p.x, y: p.y, text: "SHIELD ABSORBED", color: "#a855f7", scale: 0.95)
                createShockwaveRing(x: p.x, y: p.y, color: "#a855f7", count: 15)
                for _ in 0..<10 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#a855f7")) }
            } else {
                var damage = hasSecondPilot ? 18 : 25
                let hitFlame = flame(for: p)
                if hitFlame?.power == .armor { damage = Int(jsRound(Double(damage) * 0.6)) }
                if hitFlame?.power == .fragile { damage *= 2 }
                s.health -= damage
                delegate?.engine(self, healthDidChange: s.health)
                shake = 22
                addFloatingText(x: p.x, y: p.y, text: "-\(damage)% HULL DAMAGE", color: "#ff0000", scale: 1.25)
                createShockwaveRing(x: p.x, y: p.y, color: "#ff0000", count: 20)
                for _ in 0..<12 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#ff0000")) }
                if s.health <= 0 {
                    startDeathSequence(deadPlayer: p, killerX: b.x, killerY: b.y, killerColor: GameConstants.cookieColor)
                    return
                }
                s.hitCount += 1
                delegate?.engineDidTakeHit(self)
            }
        }
    }
}
