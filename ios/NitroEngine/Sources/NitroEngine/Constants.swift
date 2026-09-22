import Foundation

// Port of the module-level constants in www/game.js (L12-15, L105).
public enum GameConstants {
    public static let playerRadius: Double = 15
    public static let asteroidMinRadius: Double = 10
    public static let asteroidMaxRadius: Double = 30
    /// Base spawn rate; scaled by difficulty squared.
    public static let spawnRate: Double = 0.03
    public static let starCount = 50

    /// Simulation tick rate. game.js runs one `update()` per
    /// requestAnimationFrame at 60 Hz; every duration in the engine is a
    /// frame count, so the tick rate is part of the game's definition.
    public static let ticksPerSecond: Double = 60
    public static let tickMs: Double = 1000.0 / 60.0
}
