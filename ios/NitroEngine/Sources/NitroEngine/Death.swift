import Foundation

// game.js:1063-1128 — the fatal-hit explosion and its aftermath.
extension GameEngine {

    /// game.js:1065-1095
    func startDeathSequence(deadPlayer: Player, killerAsteroid: Asteroid) {
        if s.dying { return }
        s.dying = true
        s.deathTimer = 100 // ~1.7s at 60fps
        shake = 40
        delegate?.engineDidStartDeath(self)

        func explode(x: Double, y: Double, colors: [CSSColor], sparks: Int, ringSize: Int) {
            for color in colors {
                createShockwaveRing(x: x, y: y, color: color, count: ringSize)
            }
            for i in 0..<sparks {
                var debris = createParticle(x: x, y: y, color: colors[i % colors.count])
                debris.vx *= 1.2 + random() * 2.2 // fling debris harder than a normal hit
                debris.vy *= 1.2 + random() * 2.2
                debris.radius = 2.5 + random() * 4 // chunky, clearly-visible wreckage
                debris.life *= 2.5
                debris.maxLife = debris.life
                s.particles.append(debris)
            }
        }

        explode(x: killerAsteroid.x, y: killerAsteroid.y, colors: [killerAsteroid.color, "#fbbf24"], sparks: 45, ringSize: 16)
        let ships: [Player?] = [s.player, s.player2]
        for maybe in ships {
            guard let ship = maybe else { continue }
            explode(x: ship.x, y: ship.y, colors: ["#22d3ee", "#ff5533", "#ffffff"], sparks: 70, ringSize: 20)
        }
        addFloatingText(x: deadPlayer.x, y: deadPlayer.y - 40, text: "HULL DESTROYED", color: "#ff0000", scale: 1.4)

        s.shipsDestroyed = true // stop drawing the ships — they're debris now
    }

    /// game.js:1097-1128
    func updateDeathSequence() {
        // Aftermath only: debris flies, rings expand, asteroids keep drifting.
        for i in 0..<s.asteroids.count {
            s.asteroids[i].x += s.asteroids[i].vx
            s.asteroids[i].y += s.asteroids[i].vy
            s.asteroids[i].rotation += s.asteroids[i].spinSpeed
        }
        var pt = s.particles.count - 1
        while pt >= 0 {
            s.particles[pt].x += s.particles[pt].vx
            s.particles[pt].y += s.particles[pt].vy
            s.particles[pt].vx *= 0.985
            s.particles[pt].vy *= 0.985
            s.particles[pt].life -= 1
            if s.particles[pt].life <= 0 { s.particles.remove(at: pt) }
            pt -= 1
        }
        var ft = s.floatingTexts.count - 1
        while ft >= 0 {
            s.floatingTexts[ft].y -= 1.2
            s.floatingTexts[ft].life -= 1
            s.floatingTexts[ft].alpha = max(0, Double(s.floatingTexts[ft].life) / 60)
            if s.floatingTexts[ft].life <= 0 { s.floatingTexts.remove(at: ft) }
            ft -= 1
        }
        if shake > 0 { shake *= 0.9 }

        s.deathTimer -= 1
        if s.deathTimer <= 0 {
            s.isGameOver = true
            delegate?.engine(self, gameOverWithScore: s.score)
        }
    }
}
