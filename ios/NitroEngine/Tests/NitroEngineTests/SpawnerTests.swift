import XCTest
@testable import NeonEngine

final class SpawnerTests: XCTestCase {
    func testCreateParticleDrawOrder() {
        // angle, speed, life, id, radius (set after start(), which burns the reset draws)
        let (e, _) = makeEngine()
        e.rng = ScriptedRNG([0.25, 0.5, 0.0, 0.99, 0.5])
        let before = e.rngCalls
        let p = e.createParticle(x: 1, y: 2, color: "#fff", isThruster: true)
        XCTAssertEqual(e.rngCalls - before, 5)
        XCTAssertEqual(p.vx, 0, accuracy: 1e-12)          // cos(pi/2) * 2
        XCTAssertEqual(p.vy, 2, accuracy: 1e-12)          // speed = 0.5*2+1
        XCTAssertEqual(p.life, 8)                          // 8 + 0*8
        XCTAssertEqual(p.maxLife, 8)
        XCTAssertEqual(p.radius, 2)                        // 0.5*2+1
        XCTAssertEqual(p.color, "#fff")
    }

    func testCreateParticleNonThrusterRanges() {
        let (e, _) = makeEngine()
        e.rng = ScriptedRNG([0.0, 0.5, 0.5, 0.1, 0.5])
        let p = e.createParticle(x: 0, y: 0, color: "#000")
        XCTAssertEqual(p.vx, 2.5, accuracy: 1e-12)        // 0.5*3+1 along angle 0
        XCTAssertEqual(p.vy, 0, accuracy: 1e-12)
        XCTAssertEqual(p.life, 25)                         // 20 + 0.5*10
        XCTAssertEqual(p.radius, 2.25)                     // 0.5*2.5+1
    }

    func testCreateCollectibleSundaeAndDonut() {
        let (e1, _) = makeEngine(rng: ConstantRNG(0.0))
        let b1 = e1.rngCalls
        let sundae = e1.createCollectible(width: 800, height: 600)
        XCTAssertEqual(sundae.kind, .sundae)
        XCTAssertEqual(sundae.sprinkles.count, 0)
        XCTAssertEqual(sundae.color, "#fde68a")
        XCTAssertEqual(e1.rngCalls - b1, 6)               // kind + id, x, y, vx, vy
        XCTAssertEqual(sundae.vx, -0.5)
        XCTAssertEqual(sundae.radius, 9)

        let (e2, _) = makeEngine(rng: ConstantRNG(0.6))
        let b2 = e2.rngCalls
        let donut = e2.createCollectible(width: 800, height: 600)
        XCTAssertEqual(donut.kind, .donut)
        XCTAssertEqual(donut.sprinkles.count, 7)
        XCTAssertEqual(donut.color, "#f472b6")
        XCTAssertEqual(e2.rngCalls - b2, 1 + 21 + 5)
        XCTAssertEqual(donut.sprinkles[5].color, "#fef08a") // i % 5
        XCTAssertEqual(donut.x, 480, accuracy: 1e-9)
    }

    func testCreateProjectile() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.3))
        let b = e.rngCalls
        let p = e.createProjectile(x: 5, y: 6, angle: -Double.pi / 2)
        XCTAssertEqual(e.rngCalls - b, 1)
        XCTAssertEqual(p.vy, -10, accuracy: 1e-12)
        XCTAssertEqual(p.color, "#00ffff")
        XCTAssertEqual(p.radius, 4)
        XCTAssertEqual(p.life, 100)
        XCTAssertEqual(e.createProjectile(x: 0, y: 0, angle: 0, color: "#fb7185").color, "#fb7185")
    }

    func testCreatePowerUpMagnetOnlyFromMedium() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.0))
        var b = e.rngCalls
        let magnet = e.createPowerUp(width: 800, height: 600, difficulty: 0.62)
        XCTAssertEqual(magnet.subType, .magnet)
        XCTAssertEqual(magnet.color, "#c084fc")
        XCTAssertEqual(e.rngCalls - b, 6)                 // rand + id, x, y, vx, vy

        b = e.rngCalls
        let easy = e.createPowerUp(width: 800, height: 600, difficulty: 0.3)
        XCTAssertEqual(easy.subType, .shield)              // others[floor(0*3)]
        XCTAssertEqual(e.rngCalls - b, 7)                 // rand + index + 5
        XCTAssertEqual(easy.life, 1200)
        XCTAssertEqual(easy.maxLife, 1200)
        XCTAssertEqual(easy.radius, 12)

        let (e2, _) = makeEngine(rng: ConstantRNG(0.5))
        XCTAssertEqual(e2.createPowerUp(width: 800, height: 600, difficulty: 0.62).subType, .speed)
        let (e3, _) = makeEngine(rng: ConstantRNG(0.9))
        XCTAssertEqual(e3.createPowerUp(width: 800, height: 600, difficulty: 6).subType, .weapon)
    }

    func testAddFloatingTextAndShockwave() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.5))
        e.clearField()
        var b = e.rngCalls
        e.addFloatingText(x: 1, y: 2, text: "+100", color: "#fbbf24", scale: 0.95)
        XCTAssertEqual(e.rngCalls - b, 1)
        XCTAssertEqual(e.state!.floatingTexts.count, 1)
        XCTAssertEqual(e.state!.floatingTexts[0].life, 60)
        XCTAssertEqual(e.state!.floatingTexts[0].alpha, 1)
        e.addFloatingText(x: 1, y: 2, text: "x")
        XCTAssertEqual(e.state!.floatingTexts[1].color, "#ffffff")
        XCTAssertEqual(e.state!.floatingTexts[1].scale, 1)

        b = e.rngCalls
        e.createShockwaveRing(x: 10, y: 10, color: "#f00", count: 12)
        XCTAssertEqual(e.rngCalls - b, 24)                // life + id per ring particle
        XCTAssertEqual(e.state!.particles.count, 12)
        XCTAssertEqual(e.state!.particles[0].vx, 3, accuracy: 1e-12)
        XCTAssertEqual(e.state!.particles[3].vy, 3, accuracy: 1e-12) // angle = pi/2
        XCTAssertEqual(e.state!.particles[0].life, 23)
        XCTAssertEqual(e.state!.particles[0].radius, 2.5)
        b = e.rngCalls
        e.createShockwaveRing(x: 0, y: 0, color: "#f00")
        XCTAssertEqual(e.rngCalls - b, 16)                // default count 8
    }

    func testCreateAsteroidRockyDrawCount() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.0))
        let b = e.rngCalls
        let a = e.createAsteroid(width: 800, height: 600, difficulty: 1)
        // side, x, targetX, targetY, angle jitter, speed, style, vertexCount,
        // 8 vertices, craterCount, 2 craters x4, 5 speckles x3, id, radius,
        // color, rotation, spinSpeed
        XCTAssertEqual(e.rngCalls - b, 7 + 1 + 8 + 1 + 8 + 15 + 5)
        XCTAssertEqual(a.style, .rocky)
        XCTAssertEqual(a.tint, .gray)
        XCTAssertEqual(a.vertices.count, 8)
        XCTAssertEqual(a.vertices[0], 0.85)
        XCTAssertEqual(a.craters.count, 2)
        XCTAssertEqual(a.speckles.count, 5)
        XCTAssertEqual(a.radius, 10)
        XCTAssertEqual(a.rotation, 0)
        XCTAssertEqual(a.spinSpeed, -0.015)
        XCTAssertEqual(a.color, "hsl(215, 15%, 65%)")
        XCTAssertEqual(a.x, 0); XCTAssertEqual(a.y, -50)  // side 0
    }

    func testCreateAsteroidBlobbyDrawCount() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.7))
        let b = e.rngCalls
        let a = e.createAsteroid(width: 800, height: 600, difficulty: 0.62)
        XCTAssertEqual(a.style, .blobby)
        XCTAssertEqual(a.tint, .darkblue)
        XCTAssertEqual(a.vertices.count, 12)              // 10 + floor(2.1)
        XCTAssertEqual(a.craters.count, 3)                // fixed, no random
        XCTAssertEqual(a.speckles.count, 0)
        XCTAssertEqual(e.rngCalls - b, 7 + 1 + 12 + 0 + 12 + 0 + 5)
        XCTAssertTrue(a.color.css.hasPrefix("hsl(226."), a.color.css)
        XCTAssertTrue(a.color.css.hasSuffix(", 80%, 55%)"), a.color.css)
        XCTAssertEqual(a.x, 560)                           // side floor(2.8) = 2: x = 0.7 * 800, y = h + 50
        XCTAssertEqual(a.y, 650)
        // medium band speed boost 1.2 (speed = (0.7*2.5+2) * 0.62 * 1.2)
        let speed = (a.vx * a.vx + a.vy * a.vy).squareRoot()
        XCTAssertEqual(speed, (0.7 * 2.5 + 2.0) * 0.62 * 1.2, accuracy: 1e-9)
    }

    func testCreateAsteroidFacetedAndSuperHardSpeed() {
        let (e, _) = makeEngine(rng: ConstantRNG(0.4))
        let a = e.createAsteroid(width: 800, height: 600, difficulty: 6)
        XCTAssertEqual(a.style, .faceted)                  // floor(1.2)
        XCTAssertEqual(a.tint, .blue)
        XCTAssertEqual(a.vertices.count, 10)              // 9 + floor(1.6)
        XCTAssertEqual(a.craters.count, 5)                // 4 + floor(1.2)
        let speed = (a.vx * a.vx + a.vy * a.vy).squareRoot()
        XCTAssertEqual(speed, (0.4 * 2.5 + 2.0) * 6 * 2.5, accuracy: 1e-9)
    }

    func testUpdateSpawnsMultiSpawnLoop() {
        // Super Hard: spawnChance = 0.03 * 36 = 1.08 -> two rolls: the first
        // always spawns, the second with p = 0.08.
        let (e, _) = makeEngine({ $0.initialDifficulty = 6.0 }, rng: ConstantRNG(0.05))
        e.clearField()
        e.updateSpawns()
        XCTAssertEqual(e.state!.asteroids.count, 2)

        let (e2, _) = makeEngine({ $0.initialDifficulty = 6.0 }, rng: ConstantRNG(0.5))
        e2.clearField()
        e2.updateSpawns()
        XCTAssertEqual(e2.state!.asteroids.count, 1)
    }

    func testUpdateSpawnsCollectiblesAndPowerUpCaps() {
        // Easy: powerUpChance 0.010, max 3; collectibles 0.02/sqrt(0.3) = 0.0365
        let (e, _) = makeEngine({ $0.initialDifficulty = 0.3 }, rng: ConstantRNG(0.005))
        e.clearField()
        e.updateSpawns()
        XCTAssertEqual(e.state!.asteroids.count, 0)       // 0.005 < 0.03 * 0.3^2 = 0.0027 fails
        XCTAssertEqual(e.state!.collectibles.count, 1)
        XCTAssertEqual(e.state!.powerUps.count, 1)

        // Full lists stop the collectible (12) and power-up (3) spawns
        e.state!.collectibles = []
        for _ in 0..<12 { e.addCollectible(x: 0, y: 0) }
        e.state!.powerUps = []
        for _ in 0..<3 { e.addPowerUp(x: 0, y: 0, .shield) }
        e.updateSpawns()
        XCTAssertEqual(e.state!.collectibles.count, 12)
        XCTAssertEqual(e.state!.powerUps.count, 3)
    }
}
