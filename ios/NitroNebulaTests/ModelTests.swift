import XCTest
@testable import NeonNebula

nonisolated final class ModelTests: XCTestCase {
    @MainActor func testModeRawValuesMatchServer() {
        XCTAssertEqual(GameMode.allCases.map(\.rawValue),
                       ["easy", "medium", "hard", "super", "2p_easy", "2p_medium", "2p_hard", "2p_super"])
        XCTAssertEqual(GameMode(rawValue: "super"), .superHard)
        XCTAssertEqual(GameMode(rawValue: "2p_super"), .duoSuperHard)
    }

    @MainActor func testLabels() {
        XCTAssertEqual(GameMode.easy.label, "EASY MODE")
        XCTAssertEqual(GameMode.superHard.label, "SUPER HARD MODE")
        XCTAssertEqual(GameMode.duoMedium.label, "TWO PLAYER — MEDIUM")
        XCTAssertEqual(Tier.superHard.label, "SUPER")
        XCTAssertEqual(Tier.superHard.hudLabel, "Super Hard")
        XCTAssertEqual(Tier.easy.hudLabel, "easy")
    }

    @MainActor func testTierAndDuo() {
        XCTAssertEqual(GameMode.duoHard.tier, .hard)
        XCTAssertTrue(GameMode.duoHard.isDuo)
        XCTAssertFalse(GameMode.hard.isDuo)
        XCTAssertEqual(GameMode.forMission(difficulty: 1.3, duo: true), .duoHard)
    }

    @MainActor func testFromDifficultyThresholds() {
        XCTAssertEqual(GameMode.fromDifficulty(0.3), .easy)
        XCTAssertEqual(GameMode.fromDifficulty(0.59), .easy)
        XCTAssertEqual(GameMode.fromDifficulty(0.6), .medium)
        XCTAssertEqual(GameMode.fromDifficulty(0.62), .medium)
        XCTAssertEqual(GameMode.fromDifficulty(0.99), .medium)
        XCTAssertEqual(GameMode.fromDifficulty(1.0), .hard)
        XCTAssertEqual(GameMode.fromDifficulty(4.99), .hard)
        XCTAssertEqual(GameMode.fromDifficulty(5.0), .superHard)
        XCTAssertEqual(GameMode.fromDifficulty(6.0), .superHard)
    }

    @MainActor func testDifficultyTable() {
        XCTAssertEqual(Difficulty.all.map(\.value), [0.3, 0.62, 1.3, 6.0])
        XCTAssertEqual(Difficulty.all.map(\.label), ["EASY MODE", "MEDIUM MODE", "HARD MODE", "SUPER HARD"])
        XCTAssertTrue(Difficulty.all[3].zap)
        XCTAssertEqual(LobbyTier.medium.difficulty, 0.62)
    }

    @MainActor func testRanks() {
        XCTAssertEqual(Rank.standing(best: 0).name, "CADET")
        XCTAssertEqual(Rank.standing(best: 999).name, "CADET")
        XCTAssertEqual(Rank.standing(best: 1000).name, "ENSIGN")
        XCTAssertEqual(Rank.standing(best: 3000).name, "LIEUTENANT")
        XCTAssertEqual(Rank.standing(best: 6000).name, "CAPTAIN")
        XCTAssertEqual(Rank.standing(best: 12000).name, "COMMANDER")
        XCTAssertEqual(Rank.standing(best: 25000).name, "ADMIRAL")
        XCTAssertEqual(Rank.standing(best: 50000).name, "LEGEND")
        XCTAssertEqual(Rank.standing(best: 99999).name, "LEGEND")
        XCTAssertEqual(Rank.standing(best: 500).progress, 0.5, accuracy: 1e-9)
        XCTAssertEqual(Rank.standing(best: 2000).progress, 0.5, accuracy: 1e-9)
        XCTAssertEqual(Rank.standing(best: 60000).progress, 1)
        XCTAssertNil(Rank.standing(best: 60000).next)
        XCTAssertEqual(Rank.standing(best: 500).tooltip(best: 500), "500 more points to reach ENSIGN")
        XCTAssertEqual(Rank.standing(best: 60000).tooltip(best: 60000), "Highest rank achieved")
    }

    @MainActor func testMissionLabel() {
        XCTAssertEqual(LastMission(diff: 0.62, mode: .single).label, "MEDIUM")
        XCTAssertEqual(LastMission(diff: 6, mode: .local).label, "TWO PLAYER SUPER")
        XCTAssertEqual(LastMission(diff: 0.3, mode: .cpu).label, "CO-PILOT EASY")
    }

    @MainActor func testNumberFormat() {
        XCTAssertEqual(NumberFormat.integer(1234567), "1,234,567")
        XCTAssertEqual(NumberFormat.integer(-5), "0")
        XCTAssertEqual(NumberFormat.integer(2.5), "3")
    }
}
