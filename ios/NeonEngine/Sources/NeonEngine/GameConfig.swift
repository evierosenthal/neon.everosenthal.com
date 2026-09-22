import Foundation

/// Which device steers pilot 1 in solo/CPU modes. On iOS the joystick is the
/// keyboard path; `mouse`/`both` exist for parity with the web setting
/// (neon_nebula_control_mode) and a future follow-finger scheme.
public enum ControlModePreference: String, Codable, Sendable, CaseIterable {
    case both, mouse, keyboard
}

public enum OnlineRole: String, Codable, Sendable {
    case host, guest
}

/// `config` in game.js (L132-140) merged with the `start(options)` fields
/// (L2432-2447). Built by the app from Settings and the equipped gear.
public struct GameConfig: Hashable, Codable, Sendable {
    public var initialDifficulty: Double = 1
    public var isLocalMultiplayer = false
    public var isCPUMultiplayer = false
    public var controlModePreference: ControlModePreference = .keyboard
    /// Settings "Rocket Speed" percent / 100, clamped to 0.01...3 by the engine.
    public var speedFactor: Double = 1
    public var skin: Skin? = nil
    public var trail: Trail? = nil
    public var flame: Flame? = nil
    /// Pilot 2's gear (local two-player and online).
    public var skin2: Skin? = nil
    public var trail2: Trail? = nil
    public var flame2: Flame? = nil
    public var online: OnlineRole? = nil
    /// Multiplier applied to joystick thrust in local two-player, where the
    /// web uses 1x accel/moveSpeed (arrow keys) instead of the solo 2x.
    /// Web-identical default; kept as a knob for playtesting.
    public var touchThrustScale: Double = 1

    public init() {}

    /// game.js:2444-2446 — the equipped fire's speed power.
    public var flameSpeedMult: Double {
        switch flame?.power {
        case .fast: return 1.35
        case .slow: return 0.65
        default: return 1
        }
    }

    public var hasPlayer2: Bool { isLocalMultiplayer || isCPUMultiplayer || online != nil }
}
