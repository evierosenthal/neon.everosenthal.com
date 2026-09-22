import Foundation

// The web emits thruster sparks while DRAWING the ships (game.js drawShips,
// L1970-1998) and burns two more randoms for the screen-shake jitter
// (draw(), L2189-2191) plus one per drawn ship for the exhaust flicker
// (L1720). Those are the only simulation side effects of draw(), and they
// consume Math.random() between one update() and the next, so the port
// performs them here, at the end of update(), in the same order draw() does:
// jitter, then per ship: flicker, sparks. Nothing else in draw() touches
// state or the RNG.
extension GameEngine {
    func emitThrusters() {
        guard state != nil else { return } // draw(): if (!state) return

        // draw() L2189-2191: `if (shake > 1) ctx.translate(rand, rand)`
        if shake > 1 {
            _ = random()
            _ = random()
        }

        // drawShips() L1660
        if s.shipsDestroyed { return }
        let ships: [Player?] = [s.player, s.player2]
        for maybe in ships {
            guard let p = maybe else { continue }

            // Tilt from horizontal speed (mouse-driven solo ships tilt toward the pointer)
            var tilt: Double
            if config.isLocalMultiplayer || config.isCPUMultiplayer || config.online != nil
                || p.id == .player2 || controlMode == .keyboard {
                tilt = p.vx * 0.04
            } else {
                tilt = (mousePos.x - p.x) * 0.01
            }
            tilt = max(-0.45, min(0.45, tilt))

            // Exhaust flicker (L1717-1720): one random per ship while flying
            if !isPaused && !s.isGameOver && !s.dying {
                _ = random()
            }

            // Thruster sparks (L1971-1997)
            if !isPaused && !s.isGameOver {
                let trail = p.id == .player1 ? config.trail : config.trail2
                let thrusterCount = (s.activeEffects.speedBoost > 0 ? 2 : 1) +
                    (trail.map { $0.count > 1 ? $0.count - 1 : 0 } ?? 0)
                let streamX = p.x - sin(tilt) * (p.radius * 1.3)
                let streamY = p.y + cos(tilt) * (p.radius * 1.3) // below the nozzle
                for _ in 0..<thrusterCount {
                    let thrusterColor: CSSColor
                    if let t = trail, t.animated {
                        let hue = Int(((simMs / 8 + random() * 80).truncatingRemainder(dividingBy: 360)).rounded(.down))
                        thrusterColor = CSSColor("hsl(\(hue), 90%, 65%)")
                    } else if let t = trail {
                        thrusterColor = t.colors[jsRandomIndex(&rng, t.colors.count)]
                    } else {
                        thrusterColor = s.activeEffects.speedBoost > 0
                            ? "#22c55e"
                            : (p.id == .player1 ? "#ff00ff" : "#fb7185")
                    }
                    var spark = createParticle(x: streamX, y: streamY, color: thrusterColor, isThruster: true)
                    if trail != nil {
                        // Bought trails burn brighter and linger longer than stock
                        spark.life *= 1.8
                        spark.maxLife = spark.life
                        spark.radius += 0.8
                    }
                    s.particles.append(spark)
                }
            }
        }
    }
}
