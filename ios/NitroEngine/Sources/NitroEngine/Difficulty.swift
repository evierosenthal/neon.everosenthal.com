import Foundation

// game.js:773-796 — updateDifficulty. Reported to the delegate every tick
// like the web's onDifficultyUpdate (the app throttles).
extension GameEngine {
    /// Cap by starting mode (game.js:777-786).
    static func maxDifficultyCap(initialDifficulty initDiff: Double) -> Double {
        if initDiff >= 5.0 { return 8.0 }      // Super Hard
        if initDiff >= 1.0 { return 2.8 }      // Hard
        if initDiff >= 0.6 { return 1.1 }      // Medium (stays below Hard's start)
        return 0.85                            // Easy (reaches start of Medium)
    }

    func updateDifficulty() {
        let maxDiffCap = GameEngine.maxDifficultyCap(initialDifficulty: config.initialDifficulty)

        let baseGrowthRate = 0.00008
        let scoreGrowthRate = (Double(s.score) / 25000) * 0.00004
        let totalGrowth = baseGrowthRate + scoreGrowthRate

        if s.difficulty < maxDiffCap {
            s.difficulty = min(maxDiffCap, s.difficulty + totalGrowth)
        }
        delegate?.engine(self, difficultyDidChange: s.difficulty)
    }
}
