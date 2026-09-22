import Foundation
import NitroEngine

/// The coin economy and daily chest (ui.js:54-65, 1136-1185, 1336-1360).
enum Economy {
    static let coinScoreDivisor = 50.0
    static let recordCoinMultiplier = 5
    static let dailyBonus = 150

    /// Mission pay (ui.js:1346-1351): score / 50 rounded like `Math.round`,
    /// times 5 on a new record, times 2 for Star Fire and times 3 for Money Storm.
    static func coinsEarned(score: Int, beatRecord: Bool, flamePower: FlamePower?) -> Int {
        var earned = Int(max(0, jsRound(Double(score) / coinScoreDivisor)))
        if beatRecord { earned *= recordCoinMultiplier }
        if flamePower == .lucky { earned *= 2 }
        if flamePower == .jackpot { earned *= 3 }
        return earned
    }

    /// `finalScore > highScores[currentMode] && finalScore > 0` (ui.js:1344).
    static func beatsRecord(score: Int, best: Int) -> Bool {
        score > best && score > 0
    }

    /// todayStamp() (ui.js:1138-1141): local `Y-M-D`, month and day unpadded.
    static func todayStamp(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// Whole minutes until the next local midnight, at least 1 (ui.js:1151-1154).
    static func minutesUntilMidnight(_ now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: start) else { return 1 }
        let seconds = midnight.timeIntervalSince(now)
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    /// untilMidnightLabel() (ui.js:1151-1158): "3H 12M" or "45M".
    static func untilMidnightLabel(_ now: Date = Date(), calendar: Calendar = .current) -> String {
        let mins = minutesUntilMidnight(now, calendar: calendar)
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)H \(m)M" : "\(m)M"
    }

    /// The chest label (ui.js:1164).
    static func chestLabel(claimed: Bool, now: Date = Date()) -> String {
        claimed ? "NEXT IN " + untilMidnightLabel(now) : "DAILY BONUS"
    }

    /// The "not enough coins" message (ui.js:1759-1760).
    static func shortfallMessage(price: Int, coins: Int) -> String {
        "Not enough coins — fly more missions! You need \(NumberFormat.integer(price - coins)) more."
    }
}
