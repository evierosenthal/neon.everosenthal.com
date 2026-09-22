import XCTest
import NitroEngine
@testable import NitroNebula

nonisolated final class SmokeTests: XCTestCase {
    @MainActor
    func testEngineLinks() {
        let engine = GameEngine(rng: SeededRNG(seed: 1))
        engine.start(GameConfig(), worldSize: WorldSize(width: 800, height: 600))
        XCTAssertNotNil(engine.state)
    }
}
