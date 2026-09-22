import Foundation

// Shared helpers for the simulation extensions.
extension GameEngine {
    /// In-place access to the running state. Every simulation function is
    /// only called while a round exists (`update()` returns early otherwise),
    /// so the force unwrap mirrors game.js reading the `state` closure var.
    /// `_modify` yields the storage itself: `s.asteroids[i].x += 1` mutates
    /// in place instead of copying the arrays.
    var s: GameState {
        _read { yield state! }
        _modify { yield &state! }
    }

    /// The equipped fire of the pilot flying `player` (game.js:1026, 1676).
    func flame(for player: Player) -> Flame? {
        player.id == .player1 ? config.flame : config.flame2
    }

    /// Damage / heal amounts depend on whether a second pilot is aboard
    /// (game.js:942, 1024).
    var hasSecondPilot: Bool {
        config.isLocalMultiplayer || config.isCPUMultiplayer || config.online != nil
    }
}

/// JavaScript's Number-to-string conversion for the values that end up inside
/// colour strings (game.js:387-388): shortest round-trip digits, and an
/// integer-valued double prints without a fraction ("70", not "70.0").
func jsNumberString(_ v: Double) -> String {
    if v.isFinite, v == v.rounded(.towardZero), abs(v) < 1e21 {
        return String(Int64(v))
    }
    return "\(v)"
}
