import XCTest
@testable import NitroEngine

final class DifficultyTests: XCTestCase {
    func testCapsByMode() {
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 0.3), 0.85)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 0.62), 1.1)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 1.3), 2.8)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 6.0), 8.0)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 0.6), 1.1)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 1.0), 2.8)
        XCTAssertEqual(GameEngine.maxDifficultyCap(initialDifficulty: 5.0), 8.0)
    }

    func testBaseGrowthPerTick() {
        let (e, d) = makeEngine { $0.initialDifficulty = 0.62 }
        e.updateDifficulty()
        XCTAssertEqual(e.state!.difficulty, 0.62 + 0.00008, accuracy: 1e-15)
        XCTAssertEqual(d.difficulties, [e.state!.difficulty])
    }

    func testScoreAcceleratesGrowth() {
        let (e, _) = makeEngine { $0.initialDifficulty = 0.62 }
        e.state!.score = 25000
        e.updateDifficulty()
        XCTAssertEqual(e.state!.difficulty, 0.62 + 0.00008 + 0.00004, accuracy: 1e-15)
    }

    func testCapIsNeverExceeded() {
        let (e, d) = makeEngine { $0.initialDifficulty = 0.62 }
        e.state!.difficulty = 1.1 - 0.00001
        e.updateDifficulty()
        XCTAssertEqual(e.state!.difficulty, 1.1)
        e.updateDifficulty()
        XCTAssertEqual(e.state!.difficulty, 1.1)
        // Reported every tick even when unchanged, like onDifficultyUpdate
        XCTAssertEqual(d.difficulties.count, 2)
    }

    func testAboveCapStaysPut() {
        let (e, _) = makeEngine { $0.initialDifficulty = 0.62 }
        e.state!.difficulty = 5
        e.updateDifficulty()
        XCTAssertEqual(e.state!.difficulty, 5)
    }
}
