import Foundation

// game.js — the CPU wingman's steering: flee the cookie quest's suns and
// jar, evade asteroids, harvest pickups, else hold formation.
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

        // Nearest pickup: collectibles, power-ups, then the cookie quest's
        // raining cookies (concat order, game.js:846-847)
        var targetPickup: (x: Double, y: Double)? = nil
        var minDistCollectible = Double.infinity
        let pickups: [(x: Double, y: Double)] = s.collectibles.map { ($0.x, $0.y) } + s.powerUps.map { ($0.x, $0.y) }
            + (s.quest?.cookies ?? []).map { ($0.x, $0.y) }
        for coll in pickups {
            let cdx = coll.x - p2.x
            let cdy = coll.y - p2.y
            let cdist = (cdx * cdx + cdy * cdy).squareRoot()
            if cdist < minDistCollectible {
                minDistCollectible = cdist
                targetPickup = coll
            }
        }

        // Lethal hazards of the cookie quest's Cookie Jar level: the little
        // suns (instant death on touch, one of them hunting) and the jar
        // itself (a bump costs hull). Nearest by edge distance; no randoms.
        var hazard: (x: Double, y: Double)? = nil
        var minHazardEdge = Double.infinity
        var hazardReach = 0.0
        if let q = s.quest {
            for sn in q.suns {
                let sdx = sn.x - p2.x, sdy = sn.y - p2.y
                let sEdge = (sdx * sdx + sdy * sdy).squareRoot() - sn.radius
                if sEdge < minHazardEdge { minHazardEdge = sEdge; hazard = (sn.x, sn.y); hazardReach = 240 }
            }
            if let bz = q.boss {
                let bdx = bz.x - p2.x, bdy = bz.y - p2.y
                let bEdge = (bdx * bdx + bdy * bdy).squareRoot() - bz.radius
                if bEdge < minHazardEdge { minHazardEdge = bEdge; hazard = (bz.x, bz.y); hazardReach = 120 }
            }
        }

        var desiredVx = 0.0
        var desiredVy = 0.0

        if let hz = hazard, minHazardEdge < hazardReach {
            // Flee the hazard at full speed; never into a wall (drop that
            // axis), and if cornered break out along the screen toward the centre.
            var awayX = jsSign(p2.x - hz.x)
            var awayY = jsSign(p2.y - hz.y)
            if (p2.x < 90 && awayX < 0) || (p2.x > worldSize.width - 90 && awayX > 0) { awayX = 0 }
            if (p2.y < 90 && awayY < 0) || (p2.y > worldSize.height - 90 && awayY > 0) { awayY = 0 }
            if awayX == 0 && awayY == 0 { awayX = p2.x < worldSize.width / 2 ? 1 : -1 }
            desiredVx = awayX * moveSpeed
            desiredVy = awayY * moveSpeed
        } else if let ta = targetAsteroid, minDistAsteroid < 220 {
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
