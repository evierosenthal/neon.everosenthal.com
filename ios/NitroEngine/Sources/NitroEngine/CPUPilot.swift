import Foundation

// game.js:656-735 — the CPU wingman's steering.
extension GameEngine {
    func updateCPUPilot(friction: Double, moveSpeed: Double) {
        var p2 = s.player2!

        // Nearest asteroid
        var targetAsteroid: Asteroid? = nil
        var minDistAsteroid = Double.infinity
        for ast in s.asteroids {
            let adx = ast.x - p2.x
            let ady = ast.y - p2.y
            let adist = (adx * adx + ady * ady).squareRoot()
            if adist < minDistAsteroid {
                minDistAsteroid = adist
                targetAsteroid = ast
            }
        }

        // Nearest pickup: collectibles then power-ups (concat order, L674)
        var targetPickup: (x: Double, y: Double)? = nil
        var minDistCollectible = Double.infinity
        let pickups: [(x: Double, y: Double)] = s.collectibles.map { ($0.x, $0.y) } + s.powerUps.map { ($0.x, $0.y) }
        for coll in pickups {
            let cdx = coll.x - p2.x
            let cdy = coll.y - p2.y
            let cdist = (cdx * cdx + cdy * cdy).squareRoot()
            if cdist < minDistCollectible {
                minDistCollectible = cdist
                targetPickup = coll
            }
        }

        var desiredVx = 0.0
        var desiredVy = 0.0

        if let ta = targetAsteroid, minDistAsteroid < 220 {
            // Threat mitigation: evade (L691-708)
            let dx = p2.x - ta.x
            let dy = p2.y - ta.y

            if abs(dx) < 65 {
                // Coming right at us: sidestep horizontally
                desiredVx = dx > 0 ? moveSpeed : -moveSpeed
            } else {
                desiredVx = jsSign(dx) * moveSpeed
            }

            if minDistAsteroid < 110 {
                desiredVy = jsSign(dy) * moveSpeed
            } else {
                desiredVy = (worldSize.height * 0.75 - p2.y) * 0.05
            }
        } else if let tc = targetPickup, minDistCollectible < 400 {
            // Resource collection (L709-712)
            desiredVx = jsSign(tc.x - p2.x) * moveSpeed * 0.85
            desiredVy = jsSign(tc.y - p2.y) * moveSpeed * 0.85
        } else {
            // Formation: hover beside Player 1 (L713-718)
            let formationX = s.player.x + (p2.x > s.player.x ? 150 : -150)
            desiredVx = (formationX - p2.x) * 0.04
            desiredVy = (worldSize.height * 0.75 - p2.y) * 0.04
        }

        // Smooth interpolation (L721-722)
        p2.vx += (desiredVx - p2.vx) * 0.12
        p2.vy += (desiredVy - p2.vy) * 0.12

        p2.vx *= friction
        p2.vy *= friction

        let cpuSpeed = (p2.vx * p2.vx + p2.vy * p2.vy).squareRoot()
        if cpuSpeed > moveSpeed {
            p2.vx = (p2.vx / cpuSpeed) * moveSpeed
            p2.vy = (p2.vy / cpuSpeed) * moveSpeed
        }

        p2.x += p2.vx
        p2.y += p2.vy
        s.player2 = p2
    }
}
