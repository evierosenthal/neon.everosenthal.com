import Foundation

// game.js:834-1061 — updatePowerUps, updateCollectibles, updateAsteroids.
// The JS splices inside reverse loops; the port iterates indices downward
// and removes in place, so the surviving order and every random draw match.
extension GameEngine {

    /// game.js:834-890
    func updatePowerUps() {
        let w = worldSize.width, h = worldSize.height
        var i = s.powerUps.count - 1
        while i >= 0 {
            defer { i -= 1 }
            s.powerUps[i].x += s.powerUps[i].vx
            s.powerUps[i].y += s.powerUps[i].vy

            // life is always defined on the web's power-ups
            s.powerUps[i].life -= 1
            if s.powerUps[i].life <= 0 {
                s.powerUps.remove(at: i)
                continue
            }

            if s.powerUps[i].x < 0 || s.powerUps[i].x > w { s.powerUps[i].vx *= -1 }
            if s.powerUps[i].y < 0 || s.powerUps[i].y > h { s.powerUps[i].vy *= -1 }

            let pu = s.powerUps[i]
            var collected = false
            let players: [Player?] = [s.player, s.player2]
            for maybe in players {
                guard let p = maybe else { continue }
                let dx = p.x - pu.x
                let dy = p.y - pu.y
                let dist = (dx * dx + dy * dy).squareRoot()

                // Expanded pickup radius (+12px)
                if dist < pu.radius + p.radius + 12 {
                    var label = "POWER-UP GRABBED"
                    switch pu.subType {
                    case .shield:
                        s.activeEffects.shield = min(1000, s.activeEffects.shield + 500)
                        label = "DEFLECTOR SHIELD ACTIVE"
                    case .speed:
                        s.activeEffects.speedBoost = min(1000, s.activeEffects.speedBoost + 500)
                        label = "OVERTHRUSTERS BOOTED"
                    case .weapon:
                        s.activeEffects.weaponUpgrade = min(2000, s.activeEffects.weaponUpgrade + 1000)
                        label = s.activeEffects.weaponUpgrade > 1000 ? "PLASMA OVERDRIVE INITIATED" : "TWIN BLASTER PROTOCOL"
                    case .magnet:
                        s.activeEffects.magnet = min(600, s.activeEffects.magnet + 600)
                        label = "MAGNET FIELD ACTIVATED!"
                    }

                    addFloatingText(x: pu.x, y: pu.y, text: label, color: pu.color, scale: 1.2)
                    createShockwaveRing(x: pu.x, y: pu.y, color: pu.color, count: 24)
                    for _ in 0..<10 { s.particles.append(createParticle(x: pu.x, y: pu.y, color: pu.color)) }
                    collected = true
                    break
                }
            }

            if collected {
                s.powerUps.remove(at: i)
            }
        }
    }

    /// game.js:892-958
    func updateCollectibles() {
        let w = worldSize.width, h = worldSize.height
        var i = s.collectibles.count - 1
        while i >= 0 {
            defer { i -= 1 }

            // Magnetic pull when the magnet effect is active
            if s.activeEffects.magnet > 0 {
                let c = s.collectibles[i]
                var closestPlayer: Player? = nil
                var minDist = Double.infinity
                let candidates: [Player?] = [s.player, s.player2]
                for maybe in candidates {
                    guard let cp = maybe else { continue }
                    let mdx = cp.x - c.x
                    let mdy = cp.y - c.y
                    let mdist = (mdx * mdx + mdy * mdy).squareRoot()
                    if mdist < minDist {
                        minDist = mdist
                        closestPlayer = cp
                    }
                }
                if let cp = closestPlayer, minDist < 500 {
                    s.collectibles[i].vx += ((cp.x - c.x) / minDist) * 0.95
                    s.collectibles[i].vy += ((cp.y - c.y) / minDist) * 0.95
                    let coinSpeed = (s.collectibles[i].vx * s.collectibles[i].vx + s.collectibles[i].vy * s.collectibles[i].vy).squareRoot()
                    if coinSpeed > 10 {
                        s.collectibles[i].vx = (s.collectibles[i].vx / coinSpeed) * 10
                        s.collectibles[i].vy = (s.collectibles[i].vy / coinSpeed) * 10
                    }
                }
            }

            s.collectibles[i].x += s.collectibles[i].vx
            s.collectibles[i].y += s.collectibles[i].vy

            if s.collectibles[i].x < 0 || s.collectibles[i].x > w { s.collectibles[i].vx *= -1 }
            if s.collectibles[i].y < 0 || s.collectibles[i].y > h { s.collectibles[i].vy *= -1 }

            let c = s.collectibles[i]
            var collected = false
            let players: [Player?] = [s.player, s.player2]
            for maybe in players {
                guard let p = maybe else { continue }
                let dx = p.x - c.x
                let dy = p.y - c.y
                let distance = (dx * dx + dy * dy).squareRoot()

                // Expanded pickup radius (+10px)
                if distance < c.radius + p.radius + 10 {
                    s.score += 100
                    let healAmount = hasSecondPilot ? 7 : 5
                    s.health = min(100, s.health + healAmount)
                    delegate?.engine(self, scoreDidChange: s.score)
                    delegate?.engine(self, healthDidChange: s.health)
                    addFloatingText(x: c.x, y: c.y, text: "+100", color: "#fbbf24", scale: 0.95)
                    createShockwaveRing(x: c.x, y: c.y, color: c.color, count: 10)
                    for _ in 0..<4 { s.particles.append(createParticle(x: c.x, y: c.y, color: c.color)) }
                    collected = true
                    break
                }
            }

            if collected {
                s.collectibles.remove(at: i)
            }
        }
    }

    /// game.js:960-1061
    func updateAsteroids() {
        let w = worldSize.width, h = worldSize.height
        var i = s.asteroids.count - 1
        while i >= 0 {
            defer { i -= 1 }
            s.asteroids[i].x += s.asteroids[i].vx
            s.asteroids[i].y += s.asteroids[i].vy
            s.asteroids[i].rotation += s.asteroids[i].spinSpeed

            var asteroidDestroyed = false

            // Projectile hits (reverse loop with splice, L970-986)
            var j = s.projectiles.count - 1
            while j >= 0 {
                let asteroid = s.asteroids[i]
                let proj = s.projectiles[j]
                let pdx = asteroid.x - proj.x
                let pdy = asteroid.y - proj.y
                let pdist = (pdx * pdx + pdy * pdy).squareRoot()
                if pdist < asteroid.radius + proj.radius {
                    s.score += 20
                    delegate?.engine(self, scoreDidChange: s.score)
                    addFloatingText(x: asteroid.x, y: asteroid.y, text: "+20", color: asteroid.color, scale: 0.8)
                    createShockwaveRing(x: asteroid.x, y: asteroid.y, color: asteroid.color, count: 12)
                    for _ in 0..<6 { s.particles.append(createParticle(x: proj.x, y: proj.y, color: asteroid.color)) }

                    s.projectiles.remove(at: j)
                    asteroidDestroyed = true
                    break
                }
                j -= 1
            }

            if asteroidDestroyed {
                s.asteroids.remove(at: i)
                continue
            }

            // Player hits (L994-1046)
            let players: [Player?] = [s.player, s.player2]
            for maybe in players {
                guard let p = maybe else { continue }
                let asteroid = s.asteroids[i]
                let dx = asteroid.x - p.x
                let dy = asteroid.y - p.y
                let distance = (dx * dx + dy * dy).squareRoot()

                if distance < asteroid.radius + p.radius {
                    if s.activeEffects.speedBoost > 0 {
                        // Ram asteroids aside while overthrusters are hot
                        let nx = dx / distance
                        let ny = dy / distance
                        let dot = asteroid.vx * nx + asteroid.vy * ny
                        s.asteroids[i].vx = (asteroid.vx - 2 * dot * nx) * 1.2
                        s.asteroids[i].vy = (asteroid.vy - 2 * dot * ny) * 1.2
                        let overlap = (asteroid.radius + p.radius) - distance
                        s.asteroids[i].x += nx * overlap
                        s.asteroids[i].y += ny * overlap
                        shake = 5
                        let ax = s.asteroids[i].x, ay = s.asteroids[i].y
                        for _ in 0..<8 { s.particles.append(createParticle(x: ax, y: ay, color: "#22c55e")) }
                    } else if s.activeEffects.shield > 0 {
                        s.activeEffects.shield = max(0, s.activeEffects.shield - 100)
                        shake = 6
                        addFloatingText(x: p.x, y: p.y, text: "SHIELD ABSORBED", color: "#a855f7", scale: 0.95)
                        createShockwaveRing(x: p.x, y: p.y, color: "#a855f7", count: 15)
                        for _ in 0..<10 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#a855f7")) }
                        asteroidDestroyed = true
                        break
                    } else {
                        var damage = hasSecondPilot ? 18 : 25
                        // Iron Forge shrugs hits off, Eggshell doubles them
                        let hitFlame = flame(for: p)
                        if hitFlame?.power == .armor { damage = Int(jsRound(Double(damage) * 0.6)) }
                        if hitFlame?.power == .fragile { damage *= 2 }
                        s.health -= damage
                        delegate?.engine(self, healthDidChange: s.health)
                        shake = 22
                        addFloatingText(x: p.x, y: p.y, text: "-\(damage)% HULL DAMAGE", color: "#ff0000", scale: 1.25)
                        createShockwaveRing(x: p.x, y: p.y, color: "#ff0000", count: 20)
                        for _ in 0..<12 { s.particles.append(createParticle(x: p.x, y: p.y, color: "#ff0000")) }
                        asteroidDestroyed = true

                        if s.health <= 0 {
                            startDeathSequence(deadPlayer: p, killerAsteroid: asteroid)
                        } else {
                            s.hitCount += 1
                            delegate?.engineDidTakeHit(self)
                        }
                        break
                    }
                }
            }

            if asteroidDestroyed {
                s.asteroids.remove(at: i)
                continue
            }

            // Remove off-screen asteroids (+10 score)
            let a = s.asteroids[i]
            if a.x < -100 || a.x > w + 100 || a.y < -100 || a.y > h + 100 {
                s.asteroids.remove(at: i)
                s.score += 10
                delegate?.engine(self, scoreDidChange: s.score)
            }
        }
    }
}
