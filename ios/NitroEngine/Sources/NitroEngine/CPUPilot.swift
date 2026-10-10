import Foundation

// game.js — the CPU wingman's steering: flee the cookie quest's suns and
// jar, evade asteroids, harvest pickups, else hold formation.
extension GameEngine {
    func updateCPUPilot(friction: Double, moveSpeed baseMoveSpeed: Double) {
        var p2 = s.player2!
        // The wingman cruises a little faster than the pilots' base speed so
        // it can keep up with hazards (CPU_SPEED_MULT).
        let moveSpeed = baseMoveSpeed * GameConstants.cpuSpeedMult

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

        var afterburner = false
        if let hz = hazard, minHazardEdge < hazardReach {
            // Flee on the afterburner (double speed — the hunting sun is
            // faster than a cruising wingman) and sidestep across the hazard's
            // path rather than racing it: the escape line is the away vector
            // plus a perpendicular component toward the screen centre. Never
            // into a wall (drop that axis); if cornered, break out toward the centre.
            afterburner = true
            var ax = p2.x - hz.x, ay = p2.y - hz.y
            var ad = (ax * ax + ay * ay).squareRoot()
            if ad == 0 { ad = 1 }
            ax /= ad; ay /= ad
            // (the side is chosen from the hazard's position alone — the
            // perpendicular's dominant axis should point toward the screen
            // centre — so it doesn't flip every frame as we move)
            var px = -ay, py = ax
            let want = abs(px) >= abs(py) ? (worldSize.width / 2 - hz.x) * px : (worldSize.height / 2 - hz.y) * py
            if want < 0 { px = -px; py = -py }
            var fx = ax * 0.75 + px * 0.65, fy = ay * 0.75 + py * 0.65
            if (p2.x < 90 && fx < 0) || (p2.x > worldSize.width - 90 && fx > 0) { fx = 0 }
            if (p2.y < 90 && fy < 0) || (p2.y > worldSize.height - 90 && fy > 0) { fy = 0 }
            var fd = (fx * fx + fy * fy).squareRoot()
            if fd < 0.001 { fx = p2.x < worldSize.width / 2 ? 1 : -1; fy = 0; fd = 1 }
            desiredVx = (fx / fd) * moveSpeed * 2
            desiredVy = (fy / fd) * moveSpeed * 2
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
        let cpuCap = afterburner ? moveSpeed * 2 : moveSpeed
        if cpuSpeed > cpuCap {
            p2.vx = (p2.vx / cpuSpeed) * cpuCap
            p2.vy = (p2.vy / cpuSpeed) * cpuCap
        }

        p2.x += p2.vx
        p2.y += p2.vy
        s.player2 = p2
    }
}
