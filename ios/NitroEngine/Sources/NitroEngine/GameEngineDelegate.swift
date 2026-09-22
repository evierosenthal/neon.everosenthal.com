import Foundation

/// The `callbacks` handed to `createGame` (game.js:123-130) plus the online
/// `send` (config.online.send, game.js:139). All calls happen on the tick
/// thread, once per tick at most for the frequent ones.
public protocol GameEngineDelegate: AnyObject {
    func engine(_ engine: GameEngine, gameOverWithScore score: Int)
    func engine(_ engine: GameEngine, scoreDidChange score: Int)
    func engine(_ engine: GameEngine, healthDidChange health: Int)
    func engine(_ engine: GameEngine, difficultyDidChange difficulty: Double)
    /// Fatal crash started (death sequence begins).
    func engineDidStartDeath(_ engine: GameEngine)
    /// Asteroid hit that hurts but doesn't kill.
    func engineDidTakeHit(_ engine: GameEngine)
    /// Online: a message for the other side (host: snapshots; guest: input).
    func engine(_ engine: GameEngine, send message: NetMessage)
}

public extension GameEngineDelegate {
    func engine(_ engine: GameEngine, send message: NetMessage) {}
}
