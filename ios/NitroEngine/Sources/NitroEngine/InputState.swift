import Foundation

/// A pilot's steering for this tick: a vector with magnitude 0...1. Full
/// deflection equals holding a key on the web (the key path adds ±accel per
/// axis; the online guest path already uses a unit vector, game.js:618-632).
public struct PilotInput: Hashable, Codable, Sendable {
    public var dx: Double
    public var dy: Double
    public static let zero = PilotInput(dx: 0, dy: 0)

    public init(dx: Double, dy: Double) { self.dx = dx; self.dy = dy }

    /// Clamped to the unit disc.
    public var clamped: PilotInput {
        let m = (dx * dx + dy * dy).squareRoot()
        return m > 1 ? PilotInput(dx: dx / m, dy: dy / m) : self
    }

    public var isZero: Bool { dx == 0 && dy == 0 }
}

/// Replaces `keysPressed` / `mousePos` / `controlMode` (game.js:169-173).
public struct InputState: Hashable, Codable, Sendable {
    public var pilot1 = PilotInput.zero
    public var pilot2 = PilotInput.zero
    /// Follow-target for the web's mouse path (nil on iOS: joystick only).
    public var pointer: WorldPoint? = nil

    public init() {}
}

public struct WorldPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
