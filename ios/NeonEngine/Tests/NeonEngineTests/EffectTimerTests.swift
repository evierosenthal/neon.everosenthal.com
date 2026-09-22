import XCTest
@testable import NeonEngine

final class EffectTimerTests: XCTestCase {
    func testEffectsTickDownOncePerFrameExceptMagnetTwice() {
        let (e, _) = makeEngine()
        e.clearField()
        e.state!.activeEffects = ActiveEffects(shield: 10, speedBoost: 10, weaponUpgrade: 10, magnet: 10)
        e.tick()
        XCTAssertEqual(e.state!.activeEffects, ActiveEffects(shield: 9, speedBoost: 9, weaponUpgrade: 9, magnet: 8))
        for _ in 0..<4 { e.tick() }
        XCTAssertEqual(e.state!.activeEffects, ActiveEffects(shield: 5, speedBoost: 5, weaponUpgrade: 5, magnet: 0))
        for _ in 0..<10 { e.tick() }
        XCTAssertEqual(e.state!.activeEffects, ActiveEffects())
    }

    func testMagnetOddValueEndsAtZero() {
        let (e, _) = makeEngine()
        e.clearField()
        e.state!.activeEffects.magnet = 1
        e.tick()
        XCTAssertEqual(e.state!.activeEffects.magnet, 0)
    }

    func testMagnetMuzzleKeepsPullActiveDuringCollectibles() {
        let (e, _) = makeEngine({ $0.flame = GearCatalog.flame(id: "magnetmuzzle") }, rng: ConstantRNG(0.99))
        e.clearField()
        let p = e.state!.player
        e.addCollectible(x: p.x + 300, y: p.y)
        e.tick()
        // Topped up to 2, one tick in the effects loop leaves 1 (> 0) when
        // updateCollectibles runs, then the second tick brings it to 0.
        XCTAssertEqual(e.state!.activeEffects.magnet, 0)
        XCTAssertEqual(e.state!.collectibles.count, 1)
        let c = e.state!.collectibles[0]
        XCTAssertEqual(c.vx, -0.95, accuracy: 1e-12)
        XCTAssertEqual(c.x, p.x + 300 - 0.95, accuracy: 1e-12)
        // Keeps pulling every frame
        for _ in 0..<20 { e.tick() }
        XCTAssertLessThan(e.state!.collectibles[0].x, p.x + 300 - 0.95 * 20)
    }

    func testNoMagnetNoPull() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.99))
        e.clearField()
        let p = e.state!.player
        e.addCollectible(x: p.x + 300, y: p.y)
        e.tick()
        XCTAssertEqual(e.state!.collectibles[0].x, p.x + 300)
    }

    func testMagnetOrbPullsFromBothPlayers() {
        let (e, _) = makeEngine({ $0.isCPUMultiplayer = true }, rng: ConstantRNG(0.99))
        e.clearField()
        e.state!.activeEffects.magnet = 600
        let p2 = e.state!.player2!
        e.addCollectible(x: p2.x + 100, y: p2.y)        // nearer to ship 2
        e.updateCollectibles()
        XCTAssertEqual(e.state!.collectibles[0].vx, -0.95, accuracy: 1e-12)
    }

    func testMagnetPullSpeedCapAndRange() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.99))
        e.clearField()
        e.state!.activeEffects.magnet = 600
        let p = e.state!.player
        e.addCollectible(x: p.x + 300, y: p.y, vx: -30)
        e.addCollectible(x: 900, y: 900)                   // 781 away (> 500): untouched
        e.updateCollectibles()
        XCTAssertEqual(e.state!.collectibles[0].vx, -10, accuracy: 1e-12)   // -30.95 capped to 10
        XCTAssertEqual(e.state!.collectibles[0].vy, 0)
        XCTAssertEqual(e.state!.collectibles[1].vx, 0)
        XCTAssertEqual(e.state!.collectibles[1].vy, 0)
    }

    func testFloatingTextsFadeAndCap() {
        let (e, _) = makeEngine()
        e.clearField()
        for i in 0..<15 { e.addFloatingText(x: 0, y: 0, text: "\(i)") }
        e.tick()
        XCTAssertEqual(e.state!.floatingTexts.count, 12)
        XCTAssertEqual(e.state!.floatingTexts[0].text, "3")   // oldest dropped
        XCTAssertEqual(e.state!.floatingTexts[0].life, 59)
        XCTAssertEqual(e.state!.floatingTexts[0].y, -1.2, accuracy: 1e-12)
        for _ in 0..<59 { e.tick() }
        XCTAssertEqual(e.state!.floatingTexts.count, 0)
    }

    func testParticleAndProjectileCaps() {
        let (e, _) = makeEngine()
        e.clearField()
        for _ in 0..<100 { e.state!.particles.append(e.createParticle(x: 400, y: 100, color: "#fff")) }
        for i in 0..<40 { e.state!.projectiles.append(Projectile(id: "\(i)", x: 400, y: 300, vx: 0, vy: 0, color: "#fff")) }
        e.tick()
        XCTAssertEqual(e.state!.particles.count, 80 + 1)  // cap, then the thruster spark
        XCTAssertEqual(e.state!.projectiles.count, 30)
    }
}
