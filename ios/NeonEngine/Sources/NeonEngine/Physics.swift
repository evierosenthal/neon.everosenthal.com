import Foundation

// game.js:521-654 — updatePlayer1 / updatePlayer2 (non-CPU branches).
//
// Input model: `input.pilot1` / `input.pilot2` are steering vectors. Each
// held key on the web adds ±accel on one axis, so a full deflection (dx = 1)
// is exactly one key, and diagonals map to (±1, ±1) like two keys.
extension GameEngine {

    /// game.js:521-612
    func updatePlayer1(accel: Double, friction: Double, moveSpeed: Double) {
        let userControlMode = config.controlModePreference
        let pilot = input.pilot1

        if config.isLocalMultiplayer {
            // Local 2P: Player 1 on WASD (L527-543) at 1x accel/moveSpeed.
            // Returns before the wobble and the in-function clamp, like the JS.
            let a = accel * config.touchThrustScale
            s.player.vy += pilot.dy * a
            s.player.vx += pilot.dx * a

            s.player.vx *= friction
            s.player.vy *= friction

            let speed1 = (s.player.vx * s.player.vx + s.player.vy * s.player.vy).squareRoot()
            if speed1 > moveSpeed {
                s.player.vx = (s.player.vx / speed1) * moveSpeed
                s.player.vy = (s.player.vy / speed1) * moveSpeed
            }

            s.player.x += s.player.vx
            s.player.y += s.player.vy
            return
        }

        // Solo / CPU: obey controlModePreference; in 'both' the last device
        // used owns the ship (L546-554). The mouse path additionally needs a
        // pointer (nil on iOS: joystick only).
        let mouseDrives = input.pointer != nil &&
            (userControlMode == .mouse || (userControlMode == .both && controlMode == .mouse))
        let keyboardDrives = userControlMode == .keyboard ||
            (userControlMode == .both && controlMode == .keyboard)

        // Mouse Follow Component (L556-565)
        if mouseDrives {
            let followSpeed = min(0.4, (s.activeEffects.speedBoost > 0 ? 0.15 : 0.08) * config.speedFactor * config.flameSpeedMult)
            let prevX = s.player.x
            let prevY = s.player.y
            s.player.x += (mousePos.x - s.player.x) * followSpeed
            s.player.y += (mousePos.y - s.player.y) * followSpeed
            s.player.vx = s.player.x - prevX
            s.player.vy = s.player.y - prevY
        }

        // Keyboard Component — much quicker than the mouse glide (L567-594)
        if keyboardDrives {
            var kbAccel = accel * 2.0
            let kbTopSpeed = moveSpeed * 2.0
            // Mirror Flame's power: steering is reversed
            if config.flame?.power == .mirror { kbAccel = -kbAccel }
            // W/S then A/D in the JS; each axis is independent so the order
            // only matters for exactness of the same float ops, kept anyway.
            s.player.vy += pilot.dy * kbAccel
            s.player.vx += pilot.dx * kbAccel
            s.player.vx *= friction
            s.player.vy *= friction
            let kbSpeed = (s.player.vx * s.player.vx + s.player.vy * s.player.vy).squareRoot()
            if kbSpeed > kbTopSpeed {
                s.player.vx = (s.player.vx / kbSpeed) * kbTopSpeed
                s.player.vy = (s.player.vy / kbSpeed) * kbTopSpeed
            }
            s.player.x += s.player.vx
            s.player.y += s.player.vy
        }

        // Wobble Smoke's power (L596-600); Date.now() -> simMs
        if config.flame?.power == .wobble {
            s.player.x += sin(simMs / 180) * 1.8
            s.player.y += cos(simMs / 230) * 1.4
        }

        // Clamp within the world; kill into-wall velocity or bounce with
        // the Bouncy Blast fire (L602-611)
        let p1Bounce = config.flame?.power == .bouncy
        let r = s.player.radius
        let clampedPX = max(r, min(worldSize.width - r, s.player.x))
        let clampedPY = max(r, min(worldSize.height - r, s.player.y))
        if clampedPX != s.player.x { s.player.vx = p1Bounce ? -s.player.vx * 0.85 : 0 }
        if clampedPY != s.player.y { s.player.vy = p1Bounce ? -s.player.vy * 0.85 : 0 }
        s.player.x = clampedPX
        s.player.y = clampedPY
    }

    /// game.js:614-654 (online host L618-632, local 2P L635-654) then the
    /// CPU wingman (CPUPilot.swift).
    func updatePlayer2(accel: Double, friction: Double, moveSpeed: Double) {
        guard s.player2 != nil else { return }

        if config.online != nil {
            // Online: the guest's ship follows the unit vector they sent.
            s.player2!.vx += remoteInput.dx * accel
            s.player2!.vy += remoteInput.dy * accel
            s.player2!.vx *= friction
            s.player2!.vy *= friction
            let speedNet = (s.player2!.vx * s.player2!.vx + s.player2!.vy * s.player2!.vy).squareRoot()
            if speedNet > moveSpeed {
                s.player2!.vx = (s.player2!.vx / speedNet) * moveSpeed
                s.player2!.vy = (s.player2!.vy / speedNet) * moveSpeed
            }
            s.player2!.x += s.player2!.vx
            s.player2!.y += s.player2!.vy
            return
        }

        if config.isLocalMultiplayer {
            // Arrow keys for Player 2 (L637-652)
            let a = accel * config.touchThrustScale
            let pilot = input.pilot2
            s.player2!.vy += pilot.dy * a
            s.player2!.vx += pilot.dx * a

            s.player2!.vx *= friction
            s.player2!.vy *= friction

            let speed2 = (s.player2!.vx * s.player2!.vx + s.player2!.vy * s.player2!.vy).squareRoot()
            if speed2 > moveSpeed {
                s.player2!.vx = (s.player2!.vx / speed2) * moveSpeed
                s.player2!.vy = (s.player2!.vy / speed2) * moveSpeed
            }

            s.player2!.x += s.player2!.vx
            s.player2!.y += s.player2!.vy
            return
        }

        if !config.isCPUMultiplayer { return }
        updateCPUPilot(friction: friction, moveSpeed: moveSpeed)
    }
}
