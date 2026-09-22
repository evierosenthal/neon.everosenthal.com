import Foundation

// game.js:1130-1270 — update(), one simulation step. The order of every
// sub-step is the JavaScript's; see the line references inline.
extension GameEngine {
    func update() {
        simulate()
        // draw() runs after update() on the web and emits the thruster sparks
        // (plus two jitter randoms); see Thrusters.swift.
        emitThrusters()
    }

    private func simulate() {
        if isPaused || state == nil || s.isGameOver { return }

        // A pointer update is the web's mousemove: it hands control to the
        // mouse path (game.js:2380-2383).
        if let ptr = input.pointer, ptr != lastPointer {
            lastPointer = ptr
            mousePos = ptr
            controlMode = .mouse
        }

        if config.online == .guest {
            // The host simulates; we mirror it (L1133-1149). Star parallax
            // stays local so the backdrop is smooth between snapshots.
            scrollStars()
            if !input.pilot1.isZero { controlMode = .keyboard }
            if let snap = pendingSnapshot {
                pendingSnapshot = nil
                applySnapshot(snap)
            }
            return
        }

        if s.dying {
            updateDeathSequence()
            return
        }

        scrollStars()

        // L1162-1164
        let moveSpeed = (s.activeEffects.speedBoost > 0 ? 8.0 : 5.0) * config.speedFactor * config.flameSpeedMult
        let accel = 0.5 * config.speedFactor * config.flameSpeedMult
        let friction = 0.92

        // L1166-1171: any held move key hands control to the keyboard
        if !input.pilot1.isZero { controlMode = .keyboard }

        updatePlayer1(accel: accel, friction: friction, moveSpeed: moveSpeed)
        updatePlayer2(accel: accel, friction: friction, moveSpeed: moveSpeed)
        updateShooting()
        updateDifficulty()

        // Magnet Muzzle: the treat magnet never switches off (L1178-1182)
        if config.flame?.power == .magnet && s.activeEffects.magnet < 2 {
            s.activeEffects.magnet = 2
        }

        // Active effects tick down (L1184-1190, Object.keys order)
        if s.activeEffects.shield > 0 { s.activeEffects.shield -= 1 }
        if s.activeEffects.speedBoost > 0 { s.activeEffects.speedBoost -= 1 }
        if s.activeEffects.weaponUpgrade > 0 { s.activeEffects.weaponUpgrade -= 1 }
        if s.activeEffects.magnet > 0 { s.activeEffects.magnet -= 1 }

        // Boundary check both players (L1192-1207); only player 1 bounces
        let p1Bouncy = config.flame?.power == .bouncy
        clampToWorld(&s.player, bounce: p1Bouncy)
        if s.player2 != nil { clampToWorld(&s.player2!, bounce: false) }

        updateSpawns()

        // Projectiles (L1211-1219)
        var pi = s.projectiles.count - 1
        while pi >= 0 {
            s.projectiles[pi].x += s.projectiles[pi].vx
            s.projectiles[pi].y += s.projectiles[pi].vy
            let proj = s.projectiles[pi]
            if proj.y < -50 || proj.x < -100 || proj.x > worldSize.width + 100 {
                s.projectiles.remove(at: pi)
            }
            pi -= 1
        }

        updatePowerUps()

        updateCollectibles()
        updateAsteroids()

        // Magnet burns twice as fast as the other effects (L1226-1233). This
        // second tick comes AFTER updateCollectibles(): the Magnet Muzzle
        // tops the effect up to 2 each frame, and ticking twice before the
        // pull ran left it at 0 exactly when updateCollectibles() checked it.
        if s.activeEffects.magnet > 0 {
            s.activeEffects.magnet -= 1
        }

        // Particles (L1235-1248); the cap is skipped on the death frame
        var pt = s.particles.count - 1
        while pt >= 0 {
            s.particles[pt].x += s.particles[pt].vx
            s.particles[pt].y += s.particles[pt].vy
            s.particles[pt].life -= 1
            if s.particles[pt].life <= 0 {
                s.particles.remove(at: pt)
            }
            pt -= 1
        }
        if !s.dying && s.particles.count > 80 {
            s.particles.removeFirst(s.particles.count - 80)
        }

        if s.projectiles.count > 30 {
            s.projectiles.removeFirst(s.projectiles.count - 30)
        }

        // Floating texts (L1254-1266)
        var ft = s.floatingTexts.count - 1
        while ft >= 0 {
            s.floatingTexts[ft].y -= 1.2
            s.floatingTexts[ft].life -= 1
            s.floatingTexts[ft].alpha = max(0, Double(s.floatingTexts[ft].life) / 60)
            if s.floatingTexts[ft].life <= 0 {
                s.floatingTexts.remove(at: ft)
            }
            ft -= 1
        }
        if s.floatingTexts.count > 12 {
            s.floatingTexts.removeFirst(s.floatingTexts.count - 12)
        }

        // Screen shake (L1269)
        if shake > 0 { shake *= 0.9 }
    }

    /// Background star parallax (L1156-1160).
    private func scrollStars() {
        for i in 0..<stars.count {
            stars[i].y += stars[i].s * 0.5
            if stars[i].y > worldSize.height { stars[i].y = 0 }
        }
    }

    /// L1200-1206: zero any velocity still pressing into a wall (or bounce).
    private func clampToWorld(_ p: inout Player, bounce: Bool) {
        let clampedX = max(p.radius, min(worldSize.width - p.radius, p.x))
        let clampedY = max(p.radius, min(worldSize.height - p.radius, p.y))
        if clampedX != p.x { p.vx = bounce ? -p.vx * 0.85 : 0 }
        if clampedY != p.y { p.vy = bounce ? -p.vy * 0.85 : 0 }
        p.x = clampedX
        p.y = clampedY
    }
}
