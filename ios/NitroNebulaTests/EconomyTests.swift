import XCTest
import NitroEngine
@testable import NitroNebula

nonisolated final class EconomyTests: XCTestCase {
    @MainActor func testCoinFormula() {
        XCTAssertEqual(Economy.coinsEarned(score: 0, beatRecord: false, flamePower: nil), 0)
        XCTAssertEqual(Economy.coinsEarned(score: 24, beatRecord: false, flamePower: nil), 0)
        XCTAssertEqual(Economy.coinsEarned(score: 25, beatRecord: false, flamePower: nil), 1) // Math.round(0.5) == 1
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: false, flamePower: nil), 20)
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: true, flamePower: nil), 100)
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: false, flamePower: .lucky), 40)
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: false, flamePower: .jackpot), 60)
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: true, flamePower: .jackpot), 300)
        XCTAssertEqual(Economy.coinsEarned(score: 1000, beatRecord: true, flamePower: .fast), 100)
    }

    @MainActor func testBeatsRecord() {
        XCTAssertTrue(Economy.beatsRecord(score: 10, best: 0))
        XCTAssertFalse(Economy.beatsRecord(score: 0, best: 0))
        XCTAssertFalse(Economy.beatsRecord(score: 10, best: 10))
        XCTAssertTrue(Economy.beatsRecord(score: 11, best: 10))
    }

    @MainActor func testMidnightCountdown() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 21; comps.hour = 20; comps.minute = 30; comps.second = 0
        let evening = cal.date(from: comps)!
        XCTAssertEqual(Economy.minutesUntilMidnight(evening, calendar: cal), 210)
        XCTAssertEqual(Economy.untilMidnightLabel(evening, calendar: cal), "3H 30M")
        comps.hour = 23; comps.minute = 15; comps.second = 30
        let late = cal.date(from: comps)!
        XCTAssertEqual(Economy.untilMidnightLabel(late, calendar: cal), "45M") // ceil(44.5)
        comps.hour = 23; comps.minute = 59; comps.second = 59
        let lastSecond = cal.date(from: comps)!
        XCTAssertEqual(Economy.untilMidnightLabel(lastSecond, calendar: cal), "1M")
        XCTAssertEqual(Economy.chestLabel(claimed: false, now: evening), "DAILY BONUS")
        XCTAssertEqual(Economy.chestLabel(claimed: true, now: evening), "NEXT IN 3H 30M")
    }

    @MainActor func testDailyBonusAndBadge() {
        XCTAssertEqual(Economy.dailyBonus, 150)
        XCTAssertTrue(Catalog.anyAffordableUnowned(coins: 500, ownedSkins: ["cyan"], ownedTrails: ["classic"], ownedFlames: ["classic"], isDeveloper: false))
        XCTAssertFalse(Catalog.anyAffordableUnowned(coins: 499, ownedSkins: ["cyan"], ownedTrails: ["classic"], ownedFlames: ["classic"], isDeveloper: false))
        XCTAssertFalse(Catalog.anyAffordableUnowned(coins: 99999, ownedSkins: ["cyan"], ownedTrails: ["classic"], ownedFlames: ["classic"], isDeveloper: true))
        XCTAssertEqual(Economy.shortfallMessage(price: 1500, coins: 250), "Not enough coins — fly more missions! You need 1,250 more.")
    }

    @MainActor func testEnforceOwnedGear() {
        var l = LoadoutIDs(skin: "galaxy", trail: "rainbow", flame: "classic")
        XCTAssertTrue(l.enforceOwned(skins: ["cyan"], trails: ["classic"], flames: ["classic"]))
        XCTAssertEqual(l, LoadoutIDs())
        XCTAssertFalse(l.enforceOwned(skins: ["cyan"], trails: ["classic"], flames: ["classic"]))
    }
}
