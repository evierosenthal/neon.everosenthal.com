import XCTest
@testable import NitroEngine

final class PhysicsTests: XCTestCase {
    /// Solo keyboard: kbAccel = 1.0, then friction -> vx 0.92.
    func testOneTickFullRightFromRest() {
        let (e, _) = makeEngine()
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.vx, 0.92, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player.vy, 0)
        XCTAssertEqual(e.state!.player.x, 400 + 0.92, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player.y, 300)
    }

    func testTopSpeedCapIsTen() {
        let (e, _) = makeEngine()
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        for _ in 0..<30 { e.tick() }
        XCTAssertEqual(e.state!.player.vx, 10, accuracy: 1e-9)
        XCTAssertLessThan(e.state!.player.x, 785)
    }

    func testDiagonalIsCappedByMagnitude() {
        let (e, _) = makeEngine()
        e.input.pilot1 = PilotInput(dx: 1, dy: 1)
        for _ in 0..<30 { e.tick() }
        let p = e.state!.player
        XCTAssertEqual((p.vx * p.vx + p.vy * p.vy).squareRoot(), 10, accuracy: 1e-9)
        XCTAssertEqual(p.vx, p.vy, accuracy: 1e-9)
    }

    func testMirrorFlameReversesSteering() {
        let (e, _) = makeEngine { $0.flame = GearCatalog.flame(id: "mirrorflame") }
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.vx, -0.92, accuracy: 1e-12)
    }

    func testWallClampKillsVelocity() {
        let (e, _) = makeEngine()
        e.state!.player.x = 784.5
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.x, 785)
        XCTAssertEqual(e.state!.player.vx, 0)
    }

    func testBouncyBlastReflectsOffWalls() {
        let (e, _) = makeEngine { $0.flame = GearCatalog.flame(id: "bouncyblast") }
        e.state!.player.x = 784.5
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.x, 785)
        XCTAssertEqual(e.state!.player.vx, -0.92 * 0.85, accuracy: 1e-12)
    }

    func testTinyAndGiantRadius() {
        let (tiny, _) = makeEngine { $0.flame = GearCatalog.flame(id: "pocketrocket") }
        XCTAssertEqual(tiny.state!.player.radius, 15 * 0.7)
        let (giant, _) = makeEngine { $0.flame = GearCatalog.flame(id: "megaburner") }
        XCTAssertEqual(giant.state!.player.radius, 15 * 1.45)
        // flame2 resizes ship 2 only
        let (two, _) = makeEngine {
            $0.isCPUMultiplayer = true
            $0.flame2 = GearCatalog.flame(id: "pocketrocket")
        }
        XCTAssertEqual(two.state!.player.radius, 15)
        XCTAssertEqual(two.state!.player2!.radius, 15 * 0.7)
    }

    func testFastAndSlowFlames() {
        let (fast, _) = makeEngine { $0.flame = GearCatalog.flame(id: "turbo") }
        fast.input.pilot1 = PilotInput(dx: 1, dy: 0)
        fast.tick()
        XCTAssertEqual(fast.state!.player.vx, 1.35 * 0.92, accuracy: 1e-12)

        let (slow, _) = makeEngine { $0.flame = GearCatalog.flame(id: "snail") }
        slow.input.pilot1 = PilotInput(dx: 1, dy: 0)
        slow.tick()
        XCTAssertEqual(slow.state!.player.vx, 0.65 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(GameConfig().flameSpeedMult, 1)
    }

    func testSpeedFactorClamp() {
        let (e, _) = makeEngine { $0.speedFactor = 10 }
        XCTAssertEqual(e.config.speedFactor, 3)
        e.setSpeedFactor(0)
        XCTAssertEqual(e.config.speedFactor, 0.01)
        e.setSpeedFactor(.nan)
        XCTAssertEqual(e.config.speedFactor, 1)
        e.setSpeedFactor(1.5)
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.vx, 1.5 * 0.92, accuracy: 1e-12)
    }

    func testSpeedBoostRaisesCap() {
        // Cap 16 with overthrusters, 10 without; accel is unchanged (0.5 * 2)
        let (e, _) = makeEngine()
        e.state!.activeEffects.speedBoost = 1000
        e.state!.player.vy = -20
        e.input.pilot1 = PilotInput(dx: 0, dy: -1)
        e.tick()
        XCTAssertEqual(e.state!.player.vy, -16, accuracy: 1e-9)
        let (plain, _) = makeEngine()
        plain.state!.player.vy = -20
        plain.input.pilot1 = PilotInput(dx: 0, dy: -1)
        plain.tick()
        XCTAssertEqual(plain.state!.player.vy, -10, accuracy: 1e-9)
    }

    func testLocalTwoPlayerUsesOneXThrustPerPilot() {
        let (e, _) = makeEngine { $0.isLocalMultiplayer = true }
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.input.pilot2 = PilotInput(dx: 0, dy: 1)
        e.tick()
        XCTAssertEqual(e.state!.player.vx, 0.5 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player2!.vy, 0.5 * 0.92, accuracy: 1e-12)
        for _ in 0..<40 { e.tick() }
        XCTAssertEqual(e.state!.player.vx, 5, accuracy: 1e-9)
        XCTAssertEqual(e.state!.player2!.vy, 5, accuracy: 1e-9)
    }

    func testTouchThrustScaleOnlyAffectsLocalTwoPlayer() {
        let (e, _) = makeEngine { $0.isLocalMultiplayer = true; $0.touchThrustScale = 2 }
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.vx, 1.0 * 0.92, accuracy: 1e-12)
        let (solo, _) = makeEngine { $0.touchThrustScale = 2 }
        solo.input.pilot1 = PilotInput(dx: 1, dy: 0)
        solo.tick()
        XCTAssertEqual(solo.state!.player.vx, 0.92, accuracy: 1e-12)
    }

    func testPointerIgnoredInKeyboardMode() {
        let (e, _) = makeEngine()
        e.input.pointer = WorldPoint(x: 100, y: 100)
        e.tick()
        XCTAssertEqual(e.state!.player.x, 400)
        XCTAssertEqual(e.state!.player.y, 300)
    }

    func testMouseFollowInBothModeHandsOffToKeyboard() {
        let (e, _) = makeEngine { $0.controlModePreference = .both }
        e.input.pointer = WorldPoint(x: 500, y: 300)
        e.tick()
        XCTAssertEqual(e.state!.player.x, 400 + 100 * 0.08, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player.vx, 8, accuracy: 1e-12)
        // A key press takes over; the stationary pointer no longer pulls.
        e.input.pilot1 = PilotInput(dx: -1, dy: 0)
        let before = e.state!.player.x
        e.tick()
        XCTAssertEqual(e.state!.player.vx, (8 - 1) * 0.92, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player.x, before + (8 - 1) * 0.92, accuracy: 1e-12)
    }

    func testWobbleSways() {
        let (e, _) = makeEngine { $0.flame = GearCatalog.flame(id: "wobblesmoke") }
        e.tickCount = 10
        e.tick()
        let t = 10 * GameConstants.tickMs
        XCTAssertEqual(e.state!.player.x, 400 + sin(t / 180) * 1.8, accuracy: 1e-12)
        XCTAssertEqual(e.state!.player.y, 300 + cos(t / 230) * 1.4, accuracy: 1e-12)
    }

    func testPauseFreezesAndClearsInput() {
        let (e, _) = makeEngine()
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.setPaused(true)
        XCTAssertTrue(e.input.pilot1.isZero)
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.state!.player.x, 400)
        XCTAssertEqual(e.tickCount, 0)
        e.setPaused(false)
        e.input.pilot1 = PilotInput(dx: 1, dy: 0)
        e.tick()
        XCTAssertEqual(e.tickCount, 1)
        XCTAssertGreaterThan(e.state!.player.x, 400)
    }
}
