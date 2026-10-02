import Foundation
import NitroEngine

// The secret cookie quest's app side (ui.js: handleQuestEvent,
// handleQuestComplete, showGameToast). The engine runs the quest itself;
// here we show the notices, pay the reward and unlock the secret skins.

extension AppState {
    /// The three skins the quest awards (ui.js `SECRET_SKIN_IDS`).
    static var secretSkinIDs: [String] { GearCatalog.secretSkinIDs }

    /// Whether the quest has been finished on this device.
    var cookieQuestDone: Bool { store.cookieQuestDone }

    // MARK: Engine callbacks (see AppState+Engine.swift for the others)

    /// onQuestEvent (ui.js handleQuestEvent): start / failed get a toast;
    /// a cleared level is celebrated by the canvas banner.
    func engine(_ engine: GameEngine, questEvent: QuestEvent, level: Int) {
        switch questEvent {
        case .start:
            audio.setQuestMusic(true)
            sync()
            showGameToast("SECRET LEVEL FOUND · THE COOKIE QUEST BEGINS", seconds: 4)
        case .failed:
            audio.setQuestMusic(false)
            sync()
            showGameToast("COOKIE QUEST OVER · BACK TO THE NEBULA", seconds: 4)
        case .levelWon:
            break
        }
    }

    /// onQuestComplete: deferred to `flushTick()` like the other wallet-touching
    /// callbacks so the observable state changes once per frame.
    func engineDidCompleteQuest(_ engine: GameEngine) {
        pendingQuestComplete = true
    }

    // MARK: Reward

    /// handleQuestComplete (ui.js): pay out (fire coin powers apply like
    /// mission pay), unlock the three secret skins, remember it, celebrate.
    func handleQuestComplete() {
        audio.setQuestMusic(false) // the mission loop returns under the fanfare
        sync()
        let earned = Economy.applyCoinPowers(Economy.cookieQuestCoins, flamePower: loadout1.resolved.flame.power)
        coins += earned
        for id in AppState.secretSkinIDs where !ownedSkins.contains(id) {
            ownedSkins.append(id)
        }
        store.cookieQuestDone = true
        saveWallet()
        showGameToast("SECRET QUEST COMPLETE · +\(NumberFormat.integer(earned)) COINS · 3 SKINS UNLOCKED", seconds: 5)
        audio.playFanfare()
    }

    // MARK: Toast

    /// showGameToast (ui.js): a small notice at the bottom of the HUD that
    /// hides itself after `seconds`.
    func showGameToast(_ message: String, seconds: Double) {
        questToastTask?.cancel()
        questToast = message
        questToastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            if self.questToast == message { self.questToast = nil }
        }
    }

    /// Clear the toast immediately (leaving the mission).
    func hideGameToast() {
        questToastTask?.cancel()
        questToastTask = nil
        questToast = nil
    }
}
