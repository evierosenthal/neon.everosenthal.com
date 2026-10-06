import XCTest
@testable import NitroEngine

/// Regression guard: a seeded solo run with scripted steering must keep
/// producing exactly the values captured when the port matched the
/// JavaScript oracle (OracleParityTests). If this changes, the simulation
/// changed; re-verify against game.js before updating the numbers.
final class GoldenRunTests: XCTestCase {
    func testSeed42Solo1200Ticks() {
        let (e, d) = makeEngine({
            $0.initialDifficulty = 0.62
            $0.controlModePreference = .keyboard
            $0.trail = GearCatalog.trail(id: "pulse")
            $0.flame = GearCatalog.flame(id: "bouncyblast")
        }, rng: SeededRNG(seed: 42))
        for frame in 0..<1200 {
            e.input.pilot1 = InputScript.pilot(frame, pilot: 0)
            e.tick()
        }
        let p = e.debugPositions!.p1!
        print("[golden] score \(e.state!.score) health \(e.state!.health) hits \(d.hits) p1 \(p) asteroids \(e.state!.asteroids.count) particles \(e.state!.particles.count) difficulty \(e.state!.difficulty)")
        XCTAssertEqual(e.state!.score, GOLDEN_SCORE)
        XCTAssertEqual(e.state!.health, GOLDEN_HEALTH)
        XCTAssertEqual(d.hits, GOLDEN_HITS)
        XCTAssertEqual(p.x, GOLDEN_P1.x)
        XCTAssertEqual(p.y, GOLDEN_P1.y)
        XCTAssertEqual(p.vx, GOLDEN_P1.vx)
        XCTAssertEqual(p.vy, GOLDEN_P1.vy)
        XCTAssertEqual(e.state!.asteroids.count, GOLDEN_ASTEROIDS)
    }

    func testSeed7CPU600Ticks() {
        let (e, d) = makeEngine({
            $0.initialDifficulty = 1.3
            $0.isCPUMultiplayer = true
            $0.controlModePreference = .keyboard
        }, rng: SeededRNG(seed: 7))
        for frame in 0..<600 {
            e.input.pilot1 = InputScript.pilot(frame, pilot: 0)
            e.tick()
        }
        let p2 = e.debugPositions!.p2!
        print("[golden] cpu score \(e.state!.score) health \(e.state!.health) hits \(d.hits) p2 \(p2)")
        XCTAssertEqual(e.state!.score, GOLDEN_CPU_SCORE)
        XCTAssertEqual(e.state!.health, GOLDEN_CPU_HEALTH)
        XCTAssertEqual(p2.x, GOLDEN_CPU_P2.x)
        XCTAssertEqual(p2.y, GOLDEN_CPU_P2.y)
    }

    // Captured from runs that passed OracleParityTests (the solo run is the
    // same seed/config/script as the oracle's "solo bouncy+pulse" scenario,
    // so its JavaScript run ends at the same numbers).
    // Re-verified against game.js (OracleParityTests.testSoloKeyboardParity
    // is this exact config) on 2026-10-05, when Medium runs gained the cookie
    // quest's spawn-frame draw in reset().
    let GOLDEN_SCORE = 1400
    let GOLDEN_HEALTH = 80
    let GOLDEN_HITS = 2
    let GOLDEN_P1 = (x: 678.5, y: 28.8, vx: -8.58, vy: -0.27)
    let GOLDEN_ASTEROIDS = 8
    // The CPU run is a Hard (1.3) start: since the secret cookie quest,
    // reset() draws one extra random there (the cookie's spawn frame), which
    // shifted this run. Re-captured after an oracle run of the same
    // seed/config/script ended at 520 / 100 with p2 matching frame by frame.
    let GOLDEN_CPU_SCORE = 520
    let GOLDEN_CPU_HEALTH = 100
    let GOLDEN_CPU_P2 = (x: 727.9, y: 401.8)
}
