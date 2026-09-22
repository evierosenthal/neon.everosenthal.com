import Foundation

// game.js:737-771 — updateShooting. Date.now() -> simMs, so the 300/150 ms
// fire rate is 18/9 ticks regardless of display rate.
extension GameEngine {
    func updateShooting() {
        let now = simMs
        let fireRate: Double = s.activeEffects.speedBoost > 0 ? 150 : 300
        let angle = -Double.pi / 2

        // Player 1 (requires the 'W' weapon power-up)
        if s.activeEffects.weaponUpgrade > 0 && now - lastShotTime > fireRate {
            lastShotTime = now
            let p = s.player
            if s.activeEffects.weaponUpgrade > 1000 {
                s.projectiles.append(createProjectile(x: p.x - 10, y: p.y, angle: angle))
                s.projectiles.append(createProjectile(x: p.x + 10, y: p.y, angle: angle))
                s.projectiles.append(createProjectile(x: p.x, y: p.y, angle: angle - 0.15))
                s.projectiles.append(createProjectile(x: p.x, y: p.y, angle: angle + 0.15))
            } else {
                s.projectiles.append(createProjectile(x: p.x - 10, y: p.y, angle: angle))
                s.projectiles.append(createProjectile(x: p.x + 10, y: p.y, angle: angle))
            }
        }

        // Player 2
        if let p2 = s.player2, s.activeEffects.weaponUpgrade > 0 && now - lastShotTime2 > fireRate {
            lastShotTime2 = now
            let rose: CSSColor = "#fb7185"
            if s.activeEffects.weaponUpgrade > 1000 {
                s.projectiles.append(createProjectile(x: p2.x - 10, y: p2.y, angle: angle, color: rose))
                s.projectiles.append(createProjectile(x: p2.x + 10, y: p2.y, angle: angle, color: rose))
                s.projectiles.append(createProjectile(x: p2.x, y: p2.y, angle: angle - 0.15, color: rose))
                s.projectiles.append(createProjectile(x: p2.x, y: p2.y, angle: angle + 0.15, color: rose))
            } else {
                s.projectiles.append(createProjectile(x: p2.x - 10, y: p2.y, angle: angle, color: rose))
                s.projectiles.append(createProjectile(x: p2.x + 10, y: p2.y, angle: angle, color: rose))
            }
        }
    }
}
