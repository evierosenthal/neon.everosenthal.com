import XCTest
@testable import NitroEngine

final class CPUPilotTests: XCTestCase {
    func cpuEngine() -> GameEngine {
        let (e, _) = makeEngine { $0.isCPUMultiplayer = true }
        e.clearField()
        return e
    }

    func testFormationBesidePlayerOne() {
        let e = cpuEngine()
        // p1 at (266.67, 300), p2 at (533.33, 300): target x = p1 + 150, y = 450
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let p1 = e.state!.player, p2 = e.state!.player2!
        let desiredVx = (p1.x + 150 - (800 / 3 * 2)) * 0.04
        let desiredVy = (600 * 0.75 - 300) * 0.04
        XCTAssertEqual(p2.vx, desiredVx * 0.12 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(p2.vy, desiredVy * 0.12 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(p2.x, 800 / 3 * 2 + p2.vx, accuracy: 1e-12)
    }

    func testEvadesCloseAsteroidWithSidestepAndVerticalPush() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        _ = e.addAsteroid(x: p2.x + 30, y: p2.y - 100)   // |dx| < 65, dist ~104 < 110
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let after = e.state!.player2!
        XCTAssertEqual(after.vx, -5 * 0.12 * 0.92, accuracy: 1e-12)   // dx < 0 -> -moveSpeed
        XCTAssertEqual(after.vy, 5 * 0.12 * 0.92, accuracy: 1e-12)    // sign(dy = +100)
    }

    func testEvadesFartherAsteroidTowardCombatSector() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        _ = e.addAsteroid(x: p2.x - 150, y: p2.y - 100)  // dist ~180: < 220 but > 110, |dx| >= 65
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let after = e.state!.player2!
        XCTAssertEqual(after.vx, 5 * 0.12 * 0.92, accuracy: 1e-12)       // sign(dx = +150)
        XCTAssertEqual(after.vy, (450 - p2.y) * 0.05 * 0.12 * 0.92, accuracy: 1e-12)
    }

    func testHarvestsNearbyPickupAtReducedSpeed() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        e.addCollectible(x: p2.x - 200, y: p2.y)
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let after = e.state!.player2!
        XCTAssertEqual(after.vx, -5 * 0.85 * 0.12 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(after.vy, 0)                                        // jsSign(0) == 0
    }

    func testPowerUpsCountAsPickupsAndNearestWins() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        e.addCollectible(x: p2.x + 390, y: p2.y)
        e.addPowerUp(x: p2.x - 100, y: p2.y + 50, .shield)
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let after = e.state!.player2!
        XCTAssertLessThan(after.vx, 0)
        XCTAssertGreaterThan(after.vy, 0)
    }

    func testFarPickupIsIgnored() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        e.addCollectible(x: p2.x, y: p2.y - 410)
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        // Formation instead: heads down toward y = 450
        XCTAssertGreaterThan(e.state!.player2!.vy, 0)
    }

    func testAsteroidThreatBeatsPickup() {
        let e = cpuEngine()
        let p2 = e.state!.player2!
        e.addCollectible(x: p2.x + 50, y: p2.y)
        _ = e.addAsteroid(x: p2.x - 200, y: p2.y)        // within 220
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        XCTAssertEqual(e.state!.player2!.vx, 5 * 0.12 * 0.92, accuracy: 1e-12) // flee right
    }

    func testSpeedCap() {
        let e = cpuEngine()
        e.state!.player2!.vx = 100
        e.updateCPUPilot(friction: 0.92, moveSpeed: 5)
        let p2 = e.state!.player2!
        XCTAssertEqual((p2.vx * p2.vx + p2.vy * p2.vy).squareRoot(), 5, accuracy: 1e-9)
    }

    func testCPUShipIsClampedByUpdate() {
        let (e, _) = makeEngine { $0.isCPUMultiplayer = true }
        e.state!.player2!.x = 799
        e.state!.player2!.y = 599
        e.tick()
        XCTAssertLessThanOrEqual(e.state!.player2!.x, 785)
        XCTAssertLessThanOrEqual(e.state!.player2!.y, 585)
    }
}
