import XCTest
@testable import NitroEngine

final class DeathSequenceTests: XCTestCase {
    func testFatalHitStartsDeathSequence() {
        let (e, d) = makeEngine()
        e.clearField()
        e.state!.health = 10
        let p = e.state!.player
        let a = e.addAsteroid(x: p.x, y: p.y)
        let rngBefore = e.rngCalls
        e.updateAsteroids()

        XCTAssertTrue(e.state!.dying)
        XCTAssertEqual(e.state!.deathTimer, 100)
        XCTAssertEqual(e.shake, 40)
        XCTAssertTrue(e.state!.shipsDestroyed)
        XCTAssertEqual(e.state!.health, -15)
        XCTAssertEqual(d.deaths, 1)
        XCTAssertEqual(d.hits, 0)                          // fatal hit is not a "hit"
        XCTAssertEqual(e.state!.hitCount, 0)
        XCTAssertFalse(e.state!.isGameOver)
        XCTAssertEqual(e.state!.asteroids.count, 0)        // the killer is removed too
        XCTAssertEqual(e.state!.floatingTexts.map(\.text), ["-25% HULL DAMAGE", "HULL DESTROYED"])
        XCTAssertEqual(e.state!.floatingTexts[1].y, p.y - 40)
        XCTAssertEqual(e.state!.floatingTexts[1].scale, 1.4)
        // Particles: hit (20 ring + 12) + asteroid explode (2 rings x 16 + 45) + ship explode (3 x 20 + 70)
        XCTAssertEqual(e.state!.particles.count, 32 + (32 + 45) + (60 + 70))
        XCTAssertEqual(e.state!.particles[32].color, a.color)
        // Debris is chunkier and lives 2.5x
        let debris = e.state!.particles[32 + 32]
        XCTAssertGreaterThanOrEqual(debris.radius, 2.5)
        XCTAssertGreaterThanOrEqual(debris.life, 50)
        XCTAssertEqual(debris.life, debris.maxLife)
        XCTAssertEqual(e.rngCalls, -1) // SeededRNG in use; counting checked below
        _ = rngBefore
    }

    func testDeathRandomDrawCount() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.5))
        e.clearField()
        e.state!.health = 10
        let p = e.state!.player
        _ = e.addAsteroid(x: p.x, y: p.y)
        let before = e.rngCalls
        e.updateAsteroids()
        // Hit: text 1 + ring 20x2 + 12 particles x5 = 101
        // Asteroid explode: 2 rings x 16 x 2 = 64, 45 sparks x (5 + 3) = 360
        // Ship explode: 3 rings x 20 x 2 = 120, 70 sparks x 8 = 560
        // HULL DESTROYED text: 1
        XCTAssertEqual(e.rngCalls - before, 101 + 64 + 360 + 120 + 560 + 1)
    }

    func testTwoShipsBothExplode() {
        let (e, _) = makeEngine { $0.isCPUMultiplayer = true }
        e.clearField()
        e.state!.health = 5
        let p2 = e.state!.player2!
        _ = e.addAsteroid(x: p2.x, y: p2.y)
        e.updateAsteroids()
        XCTAssertTrue(e.state!.dying)
        XCTAssertEqual(e.state!.particles.count, 32 + 77 + 130 * 2)
        XCTAssertEqual(e.state!.floatingTexts.last?.x, p2.x)
    }

    func testSecondFatalHitSameFrameIsIgnored() {
        let (e, d) = makeEngine()
        e.clearField()
        e.state!.health = 10
        let p = e.state!.player
        _ = e.addAsteroid(x: p.x, y: p.y)
        _ = e.addAsteroid(x: p.x + 1, y: p.y)
        e.updateAsteroids()
        XCTAssertEqual(d.deaths, 1)
        XCTAssertEqual(e.state!.deathTimer, 100)
        XCTAssertEqual(e.state!.health, -40)               // both hits still land
    }

    func testCountdownToGameOver() {
        let (e, d) = makeEngine()
        e.clearField()
        e.state!.health = 10
        e.state!.score = 1234
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y, vx: 1)
        e.tick()
        XCTAssertTrue(e.state!.dying)
        let particlesAtDeath = e.state!.particles.count
        XCTAssertGreaterThan(particlesAtDeath, 80)         // no cap on the death frame
        for i in 1...99 {
            e.tick()
            XCTAssertFalse(e.state!.isGameOver, "tick \(i)")
            XCTAssertEqual(e.state!.deathTimer, 100 - i)
        }
        XCTAssertNil(d.gameOverScore)
        e.tick()
        XCTAssertTrue(e.state!.isGameOver)
        XCTAssertEqual(d.gameOverScore, 1234)
        XCTAssertEqual(e.state!.score, 1234)
        // Frozen afterwards
        let pos = e.debugPositions
        e.tick()
        XCTAssertEqual(e.debugPositions, pos)
        XCTAssertLessThan(e.shake, 40 * pow(0.9, 90))
    }

    func testDeathAftermathKeepsDebrisMoving() {
        let (e, _) = makeEngine()
        e.clearField()
        e.state!.health = 10
        _ = e.addAsteroid(x: e.state!.player.x, y: e.state!.player.y)
        e.updateAsteroids()
        _ = e.addAsteroid(x: 100, y: 100, vx: 2, vy: 3)
        let debris = e.state!.particles[50]
        e.updateDeathSequence()
        XCTAssertEqual(e.state!.asteroids[0].x, 102)
        XCTAssertEqual(e.state!.asteroids[0].y, 103)
        let after = e.state!.particles[50]
        XCTAssertEqual(after.x, debris.x + debris.vx, accuracy: 1e-12)
        XCTAssertEqual(after.vx, debris.vx * 0.985, accuracy: 1e-12)
        XCTAssertEqual(after.life, debris.life - 1)
        XCTAssertEqual(e.state!.floatingTexts[0].life, 59)
        XCTAssertEqual(e.state!.floatingTexts[0].alpha, 59.0 / 60, accuracy: 1e-12)
        XCTAssertEqual(e.state!.deathTimer, 99)
    }
}
