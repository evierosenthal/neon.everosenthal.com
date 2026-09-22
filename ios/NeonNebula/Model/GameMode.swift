import Foundation
import SwiftUI

// Port of the mode tables at the top of www/ui.js (L23-52, 231-236, 315,
// 755-760, 878-887). Raw values are the server's mode ids and must not change.

/// The eight leaderboard modes: four solo tiers and their two-player twins.
enum GameMode: String, CaseIterable, Codable, Sendable, Hashable {
    case easy, medium, hard
    case superHard = "super"
    case duoEasy = "2p_easy"
    case duoMedium = "2p_medium"
    case duoHard = "2p_hard"
    case duoSuperHard = "2p_super"

    static let solo: [GameMode] = [.easy, .medium, .hard, .superHard]
    static let duo: [GameMode] = [.duoEasy, .duoMedium, .duoHard, .duoSuperHard]

    /// MODE_LABELS (ui.js:38-47).
    var label: String {
        switch self {
        case .easy: return "EASY MODE"
        case .medium: return "MEDIUM MODE"
        case .hard: return "HARD MODE"
        case .superHard: return "SUPER HARD MODE"
        case .duoEasy: return "TWO PLAYER — EASY"
        case .duoMedium: return "TWO PLAYER — MEDIUM"
        case .duoHard: return "TWO PLAYER — HARD"
        case .duoSuperHard: return "TWO PLAYER — SUPER HARD"
        }
    }

    /// tierOf() (ui.js:50-52).
    var tier: Tier {
        switch self {
        case .easy, .duoEasy: return .easy
        case .medium, .duoMedium: return .medium
        case .hard, .duoHard: return .hard
        case .superHard, .duoSuperHard: return .superHard
        }
    }

    var isDuo: Bool { rawValue.hasPrefix("2p_") }

    /// modeFromDifficulty() (ui.js:755-760) — the solo mode for a difficulty.
    static func fromDifficulty(_ diff: Double) -> GameMode {
        Tier.fromDifficulty(diff).soloMode
    }

    /// `(localMultiplayer ? '2p_' : '') + modeFromDifficulty(diff)` (ui.js:1918).
    static func forMission(difficulty: Double, duo: Bool) -> GameMode {
        let tier = Tier.fromDifficulty(difficulty)
        return duo ? tier.duoMode : tier.soloMode
    }
}

/// The four difficulty rungs shared by solo and duo play.
enum Tier: String, CaseIterable, Codable, Sendable, Hashable {
    case easy, medium, hard
    case superHard = "super"

    /// TIER_LABELS (ui.js:48).
    var label: String {
        switch self {
        case .easy: return "EASY"
        case .medium: return "MEDIUM"
        case .hard: return "HARD"
        case .superHard: return "SUPER"
        }
    }

    /// The HUD strip's tile text (ui.js:790).
    var hudLabel: String { self == .superHard ? "Super Hard" : rawValue }

    var soloMode: GameMode {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        case .superHard: return .superHard
        }
    }

    var duoMode: GameMode {
        switch self {
        case .easy: return .duoEasy
        case .medium: return .duoMedium
        case .hard: return .duoHard
        case .superHard: return .duoSuperHard
        }
    }

    /// modeFromDifficulty() thresholds (ui.js:755-760).
    static func fromDifficulty(_ diff: Double) -> Tier {
        if diff >= 5.0 { return .superHard }
        if diff >= 1.0 { return .hard }
        if diff >= 0.6 { return .medium }
        return .easy
    }
}

/// DIFFICULTIES (ui.js:231-236): the four launch buttons.
struct Difficulty: Identifiable, Hashable, Sendable {
    enum Variant: Sendable { case emerald, indigo, rose, superHard }

    let label: String
    let value: Double
    let variant: Variant
    /// SUPER HARD wears pulsing lightning bolts.
    let zap: Bool

    var id: Double { value }
    var tier: Tier { Tier.fromDifficulty(value) }

    static let all: [Difficulty] = [
        Difficulty(label: "EASY MODE", value: 0.3, variant: .emerald, zap: false),
        Difficulty(label: "MEDIUM MODE", value: 0.62, variant: .indigo, zap: false),
        Difficulty(label: "HARD MODE", value: 1.3, variant: .rose, zap: false),
        Difficulty(label: "SUPER HARD", value: 6.0, variant: .superHard, zap: true)
    ]
}

/// LOBBY_TIER_DIFF (ui.js:315): online rounds only go up to Hard.
enum LobbyTier: String, CaseIterable, Codable, Sendable, Hashable {
    case easy, medium, hard

    var difficulty: Double {
        switch self {
        case .easy: return 0.3
        case .medium: return 0.62
        case .hard: return 1.3
        }
    }

    var tier: Tier {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .hard: return .hard
        }
    }

    var label: String { tier.label }
}

/// RANKS (ui.js:23-31): pilot rank by all-time best score.
struct Rank: Hashable, Sendable {
    let name: String
    let min: Int

    static let all: [Rank] = [
        Rank(name: "CADET", min: 0),
        Rank(name: "ENSIGN", min: 1000),
        Rank(name: "LIEUTENANT", min: 3000),
        Rank(name: "CAPTAIN", min: 6000),
        Rank(name: "COMMANDER", min: 12000),
        Rank(name: "ADMIRAL", min: 25000),
        Rank(name: "LEGEND", min: 50000)
    ]

    /// rankFor() (ui.js:878-887).
    struct Standing: Hashable, Sendable {
        let rank: Rank
        let next: Rank?
        /// 0...1 progress toward `next` (1 at the top rung).
        let progress: Double

        var name: String { rank.name }

        /// The pilot tile's tooltip (ui.js:901-903).
        func tooltip(best: Int) -> String {
            guard let next else { return "Highest rank achieved" }
            return "\(NumberFormat.integer(next.min - best)) more points to reach \(next.name)"
        }
    }

    static func standing(best: Int) -> Standing {
        var idx = 0
        for (i, rank) in all.enumerated() where best >= rank.min { idx = i }
        let rank = all[idx]
        let next: Rank? = idx + 1 < all.count ? all[idx + 1] : nil
        let progress: Double
        if let next {
            progress = Double(best - rank.min) / Double(next.min - rank.min)
        } else {
            progress = 1
        }
        return Standing(rank: rank, next: next, progress: Swift.max(0, Swift.min(1, progress)))
    }
}

/// How a mission was launched (`lastMission.mode`, ui.js:312, 1924).
enum MissionMode: String, Codable, Sendable, Hashable {
    case single, local, cpu
}

/// `lastMission` (ui.js:312): what Enter replays and which button wears LAST.
struct LastMission: Codable, Hashable, Sendable {
    var diff: Double
    var mode: MissionMode

    var isLocalMultiplayer: Bool { mode == .local }
    var isCPUMultiplayer: Bool { mode == .cpu }

    /// missionLabel() (ui.js:995-1000).
    var label: String {
        let tier = Tier.fromDifficulty(diff).label
        switch mode {
        case .local: return "TWO PLAYER " + tier
        case .cpu: return "CO-PILOT " + tier
        case .single: return tier
        }
    }
}

/// formatNumber() (ui.js:737-739): `toLocaleString()` of the rounded value.
enum NumberFormat {
    nonisolated(unsafe) private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 0
        return f
    }()

    static func integer(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: max(0, value))) ?? String(max(0, value))
    }

    static func integer(_ value: Double) -> String {
        integer(Int(max(0, (value + 0.5).rounded(.down))))
    }
}
