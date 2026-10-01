import Foundation

/// The `callbacks` handed to `createGame` (game.js:123-130) plus the online
/// `send` (config.online.send, game.js:139). All calls happen on the tick
/// thread, once per tick at most for the frequent ones.
/// `onQuestEvent(kind, level)` kinds (game.js:168): the quest started, a
/// level was won (1...3), or the level's clock ran out.
public enum QuestEvent: String, Sendable {
    case start, levelWon, failed
}

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
    /// Secret cookie quest finished: fired once, when level 3's 'complete'
    /// banner starts (game.js onQuestComplete). The app pays the 1000 coins
    /// (fire coin powers apply) and unlocks the three secret skins.
    func engineDidCompleteQuest(_ engine: GameEngine)
    /// Secret cookie quest notices (game.js onQuestEvent): `.start` level 1,
    /// `.levelWon` 1...3, `.failed` the level whose clock ran out.
    func engine(_ engine: GameEngine, questEvent: QuestEvent, level: Int)
}

public extension GameEngineDelegate {
    func engine(_ engine: GameEngine, send message: NetMessage) {}
    func engineDidCompleteQuest(_ engine: GameEngine) {}
    func engine(_ engine: GameEngine, questEvent: QuestEvent, level: Int) {}
}
