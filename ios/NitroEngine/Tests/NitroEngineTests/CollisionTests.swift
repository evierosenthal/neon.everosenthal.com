import XCTest
@testable import NeonEngine

final class CollisionTests: XCTestCase {
    func solo() -> (GameEngine, RecordingDelegate) {
        let (e, d) = makeEngine()
        e.clearField()
        return (e, d)
    }

    // MARK: Pickup radii

    func testCollectiblePickupRadiusIsPlusTen() {
        let (e, _) = solo()
        let p = e.state!.player
        e.addCollectible(x: p.x + 9 + 15 + 10 - 0.01, y: p.y)
        e.addCollectible(x: p.x, y: p.y + 9 + 15 + 10 + 0.01)
        e.updateCollectibles()
        XCTAssertEqual(e.state!.collectibles.count, 1)
        XCTAssertEqual(e.state!.score, 100)
    }

    func testPowerUpPickupRadiusIsPlusTwelve() {
        let (e, _) = solo()
        let p = e.state!.player
        e.addPowerUp(x: p.x + 12 + 15 + 12 - 0.01, y: p.y, .shield)
        e.addPowerUp(x: p.x, y: p.y + 12 + 15 + 12 + 0.01, .shield)
        e.updatePowerUps()
        XCTAssertEqual(e.state!.powerUps.count, 1)
        XCTAssertEqual(e.state!.activeEffects.shield, 500)
    }

    func testAsteroidHitUsesExactRadii() {
        let (e, _) = solo()
        let p = e.state!.player
        _ = e.addAsteroid(x: p.x + 20 + 15 + 0.5, y: p.y, radius: 20)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 100)
        _ = e.addAsteroid(x: p.x + 20 + 15 - 0.5, y: p.y, radius: 20)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 75)
    }

    // MARK: Heal and scoring

    func testHealAmountsAndScore() {
        let (e, d) = solo()
        e.state!.health = 50
        e.addCollectible(x: e.state!.player.x, y: e.state!.player.y)
        e.updateCollectibles()
        XCTAssertEqual(e.state!.health, 55)
        XCTAssertEqual(e.state!.score, 100)
        XCTAssertEqual(d.scores, [100])
        XCTAssertEqual(d.healths, [55])
        XCTAssertEqual(e.state!.floatingTexts.last?.text, "+100")
        XCTAssertEqual(e.state!.particles.count, 10 + 4)

        let (cpu, _) = makeEngine { $0.isCPUMultiplayer = true }
        cpu.clearField()
        cpu.state!.health = 50
        cpu.addCollectible(x: cpu.state!.player.x, y: cpu.state!.player.y)
        cpu.updateCollectibles()
        XCTAssertEqual(cpu.state!.health, 57)
    }

    func testHealCapsAtHundred() {
        let (e, _) = solo()
        e.state!.health = 98
        e.addCollectible(x: e.state!.player.x, y: e.state!.player.y)
        e.updateCollectibles()
        XCTAssertEqual(e.state!.health, 100)
    }

    func testProjectileKillScoresTwenty() {
        let (e, d) = solo()
        _ = e.addAsteroid(x: 100, y: 100, radius: 20)
        e.state!.projectiles.append(Projectile(id: "j", x: 100, y: 110, vx: 0, vy: -10, color: "#00ffff"))
        e.updateAsteroids()
        XCTAssertEqual(e.state!.asteroids.count, 0)
        XCTAssertEqual(e.state!.projectiles.count, 0)
        XCTAssertEqual(e.state!.score, 20)
        XCTAssertEqual(d.scores, [20])
        XCTAssertEqual(e.state!.floatingTexts.last?.text, "+20")
        XCTAssertEqual(e.state!.particles.count, 12 + 6)
    }

    func testOffscreenAsteroidScoresTen() {
        let (e, _) = solo()
        _ = e.addAsteroid(x: -90, y: 100, vx: -20)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.asteroids.count, 0)
        XCTAssertEqual(e.state!.score, 10)
        _ = e.addAsteroid(x: 100, y: 690, vy: 20)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.score, 20)
    }

    // MARK: Damage variants

    func testDamageSoloIsTwentyFive() {
        let (e, d) = solo()
        let p = e.state!.player
        _ = e.addAsteroid(x: p.x, y: p.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 75)
        XCTAssertEqual(d.healths, [75])
        XCTAssertEqual(d.hits, 1)
        XCTAssertEqual(e.state!.hitCount, 1)
        XCTAssertEqual(e.shake, 22)
        XCTAssertEqual(e.state!.floatingTexts.last?.text, "-25% HULL DAMAGE")
        XCTAssertEqual(e.state!.asteroids.count, 0)
        XCTAssertEqual(e.state!.particles.count, 20 + 12)
    }

    func testDamageWithSecondPilotIsEighteen() {
        for mode in ["cpu", "local", "online"] {
            let (e, _) = makeEngine {
                if mode == "cpu" { $0.isCPUMultiplayer = true }
                if mode == "local" { $0.isLocalMultiplayer = true }
                if mode == "online" { $0.online = .host }
            }
            e.clearField()
            let p2 = e.state!.player2!
            _ = e.addAsteroid(x: p2.x, y: p2.y)
            e.updateAsteroids()
            XCTAssertEqual(e.state!.health, 82, mode)
        }
    }

    func testArmorRoundsDamage() {
        let (e, _) = makeEngine { $0.flame = GearCatalog.flame(id: "ironforge") }
        e.clearField()
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 85)                // round(25 * 0.6) = 15

        let (two, _) = makeEngine { $0.isCPUMultiplayer = true; $0.flame = GearCatalog.flame(id: "ironforge") }
        two.clearField()
        _ = two.addAsteroid(x: two.state!.player.x, y: two.state!.player.y)
        two.updateAsteroids()
        XCTAssertEqual(two.state!.health, 89)              // round(18 * 0.6 = 10.8) = 11
        XCTAssertEqual(two.state!.floatingTexts.last?.text, "-11% HULL DAMAGE")
    }

    func testFragileDoublesDamage() {
        let (e, _) = makeEngine { $0.flame = GearCatalog.flame(id: "eggshell") }
        e.clearField()
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 50)
    }

    func testFlame2AppliesToShipTwoOnly() {
        let (e, _) = makeEngine {
            $0.isCPUMultiplayer = true
            $0.flame = GearCatalog.flame(id: "ironforge")
            $0.flame2 = GearCatalog.flame(id: "eggshell")
        }
        e.clearField()
        _ = e.addAsteroid(x: e.state!.player2!.x, y: e.state!.player2!.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 100 - 36)          // fragile on ship 2
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.health, 100 - 36 - 11)     // armor on ship 1
    }

    // MARK: Shield and ram

    func testShieldAbsorbsHit() {
        let (e, d) = solo()
        e.state!.activeEffects.shield = 250
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.activeEffects.shield, 150)
        XCTAssertEqual(e.state!.health, 100)
        XCTAssertEqual(e.shake, 6)
        XCTAssertEqual(e.state!.asteroids.count, 0)
        XCTAssertEqual(d.hits, 0)
        XCTAssertEqual(e.state!.floatingTexts.last?.text, "SHIELD ABSORBED")
        XCTAssertEqual(e.state!.particles.count, 15 + 10)
        // Never below zero
        e.state!.activeEffects.shield = 50
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        XCTAssertEqual(e.state!.activeEffects.shield, 0)
    }

    func testSpeedBoostRamReflectsAsteroid() {
        let (e, _) = solo()
        e.state!.activeEffects.speedBoost = 100
        let p = e.state!.player
        _ = e.addAsteroid(x: p.x + 30, y: p.y, vx: -3, vy: 0, radius: 20) // moves to x+27: overlap 8
        e.updateAsteroids()
        XCTAssertEqual(e.state!.asteroids.count, 1)
        let a = e.state!.asteroids[0]
        XCTAssertEqual(a.vx, 3 * 1.2, accuracy: 1e-12)    // reflected along the +x normal
        XCTAssertEqual(a.vy, 0, accuracy: 1e-12)
        XCTAssertEqual(a.x, p.x + 35, accuracy: 1e-9)     // pushed out to touching
        XCTAssertEqual(e.shake, 5)
        XCTAssertEqual(e.state!.health, 100)
        XCTAssertEqual(e.state!.particles.count, 8)
    }

    // MARK: Effect caps and weapons

    func testEffectCaps() {
        let (e, _) = solo()
        e.state!.activeEffects = ActiveEffects(shield: 800, speedBoost: 900, weaponUpgrade: 1500, magnet: 300)
        let p = e.state!.player
        for t in [PowerUpType.shield, .speed, .weapon, .magnet] {
            e.addPowerUp(x: p.x, y: p.y, t)
            e.updatePowerUps()
        }
        XCTAssertEqual(e.state!.activeEffects, ActiveEffects(shield: 1000, speedBoost: 1000, weaponUpgrade: 2000, magnet: 600))
        XCTAssertEqual(e.state!.floatingTexts.map(\.text), [
            "DEFLECTOR SHIELD ACTIVE", "OVERTHRUSTERS BOOTED", "PLASMA OVERDRIVE INITIATED", "MAGNET FIELD ACTIVATED!"
        ])
        XCTAssertEqual(e.state!.floatingTexts[0].scale, 1.2)
    }

    func testWeaponLabelsByTier() {
        let (e, _) = solo()
        e.addPowerUp(x: e.state!.player.x, y: e.state!.player.y, .weapon)
        e.updatePowerUps()
        XCTAssertEqual(e.state!.activeEffects.weaponUpgrade, 1000)
        XCTAssertEqual(e.state!.floatingTexts.last?.text, "TWIN BLASTER PROTOCOL")
    }

    func testPowerUpExpires() {
        let (e, _) = solo()
        e.addPowerUp(x: 100, y: 100, .shield)
        e.state!.powerUps[0].life = 1
        e.updatePowerUps()
        XCTAssertEqual(e.state!.powerUps.count, 0)
    }

    func testTwoAndFourShotPatterns() {
        let (e, _) = solo()
        e.tickCount = 100 // simMs > fire rate
        e.state!.activeEffects.weaponUpgrade = 500
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 2)
        XCTAssertEqual(e.state!.projectiles[0].x, e.state!.player.x - 10)
        XCTAssertEqual(e.state!.projectiles[1].x, e.state!.player.x + 10)
        XCTAssertEqual(e.state!.projectiles[0].vy, -10, accuracy: 1e-12)
        // Fire rate: nothing within 300 ms
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 2)
        e.tickCount = 100 + 19
        e.state!.activeEffects.weaponUpgrade = 1500
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 6)
        XCTAssertEqual(e.state!.projectiles[4].vx, cos(-Double.pi / 2 - 0.15) * 10, accuracy: 1e-12)
        XCTAssertEqual(e.state!.projectiles[5].vx, cos(-Double.pi / 2 + 0.15) * 10, accuracy: 1e-12)
    }

    func testSpeedBoostDoublesFireRateAndPlayerTwoShootsRose() {
        let (e, _) = makeEngine { $0.isCPUMultiplayer = true }
        e.clearField()
        e.tickCount = 100
        e.state!.activeEffects.weaponUpgrade = 500
        e.state!.activeEffects.speedBoost = 100
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 4)
        XCTAssertEqual(e.state!.projectiles[2].color, "#fb7185")
        e.tickCount = 100 + 10 // 166 ms > 150
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 8)
    }

    func testNoShootingWithoutWeapon() {
        let (e, _) = solo()
        e.tickCount = 100
        e.updateShooting()
        XCTAssertEqual(e.state!.projectiles.count, 0)
    }
}
