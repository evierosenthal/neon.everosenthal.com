import Foundation
import NeonEngine

// The engine's callbacks (createGame's `callbacks`, ui.js:722-729). The
// engine ticks on the main actor (the canvas view drives it from its display
// link), so the conformance is main-actor isolated. Frequent callbacks are
// coalesced into `pending*` slots and applied once per frame in
// `flushTick()`, which the canvas calls through `onTick`.

extension AppState: @MainActor GameEngineDelegate {
    func engine(_ engine: GameEngine, gameOverWithScore score: Int) {
        // Deferred to flushTick so engine.stop() never runs mid-update.
        pendingGameOver = score
    }

    func engine(_ engine: GameEngine, scoreDidChange score: Int) {
        pendingHUDScore = score
    }

    func engine(_ engine: GameEngine, healthDidChange health: Int) {
        pendingHUDHealth = health
    }

    func engine(_ engine: GameEngine, difficultyDidChange difficulty: Double) {
        handleDifficultyUpdate(difficulty)
    }

    func engineDidStartDeath(_ engine: GameEngine) {
        audio.playDeath()
    }

    func engineDidTakeHit(_ engine: GameEngine) {
        audio.playHit()
    }

    /// Online: host snapshots / guest steering go down the data channel.
    func engine(_ engine: GameEngine, send message: NetMessage) {
        netSession?.send(message)
    }

    /// Called by the canvas once per rendered frame after the engine ticked.
    func flushTick() {
        if let s = pendingHUDScore {
            pendingHUDScore = nil
            if s != score { score = s }
        }
        if let h = pendingHUDHealth {
            pendingHUDHealth = nil
            if h != health { health = h }
        }
        if let final = pendingGameOver {
            pendingGameOver = nil
            handleGameOver(score: final)
        }
    }

    /// handleDifficultyUpdate (ui.js:804-810): super runs keep their single lit tile.
    func handleDifficultyUpdate(_ diff: Double) {
        if currentMode.tier == .superHard { return }
        let tier = Tier.fromDifficulty(diff)
        if tier != liveTier { liveTier = tier }
    }
}
