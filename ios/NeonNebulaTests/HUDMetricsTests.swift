import XCTest
@testable import NeonNebula

/// The in-flight bar's sizing rules: the web's `.hud` numbers on iPads and
/// the slim phone layout that keeps the bar under 15% of a 402pt screen.
nonisolated final class HUDMetricsTests: XCTestCase {

    @MainActor func testPhoneBarStaysUnder15PercentOfLandscapeHeight() {
        // iPhone 17 Pro landscape: 874×402 with 59pt side insets → 756 wide.
        let m = HUDMetrics(width: 756, compact: true)
        XCTAssertLessThanOrEqual(m.bottomEdge, 402 * 0.15)
        XCTAssertEqual(m.barHeight, 48)
        XCTAssertFalse(m.showsModes, "`.hud-modes` hides at 900px and below")
        XCTAssertFalse(m.showsTerminal)
        XCTAssertEqual(m.pauseSize, 40)
    }

    @MainActor func testPhoneBarClearsTheSettingsLauncher() {
        // 12pt chrome inset + 44pt icon-only launcher + 12pt gap.
        let m = HUDMetrics(width: 756, compact: true)
        XCTAssertEqual(m.sideInset, 12 + 44 + 12)
    }

    @MainActor func testIPadMatchesTheWebStylesheet() {
        // iPad Pro 13" landscape: 1376×1032. `.hud { padding: 1.5rem }`,
        // `.hud-bar { height: 5rem }`, `.hull { width: 12rem }`.
        let m = HUDMetrics(width: 1376, compact: false)
        XCTAssertEqual(m.topInset, 24)
        XCTAssertEqual(m.barHeight, 80)
        XCTAssertEqual(m.hullWidth, 192)
        XCTAssertEqual(m.pauseSize, 44)
        XCTAssertTrue(m.showsModes)
        XCTAssertTrue(m.showsTerminal)
        XCTAssertLessThan(m.bottomEdge, 1032 * 0.15)
    }

    @MainActor func testModeStripBreakpointFollowsTheMediaQuery() {
        XCTAssertFalse(HUDMetrics(width: 900, compact: false).showsModes, "max-width: 900px hides the strip")
        XCTAssertTrue(HUDMetrics(width: 901, compact: false).showsModes)
    }
}
