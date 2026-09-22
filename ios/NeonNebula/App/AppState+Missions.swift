import Foundation
import NeonEngine

// Launching, pausing and ending missions (ui.js:1336-1387, 1914-1959,
// 2523-2535), the celebration screen's score submission and the canvas size
// handshake. Online rounds launch through AppState+Online.swift.
//
// Engine start handshake: the engine needs the canvas's size as its world
// size, and the canvas only exists (and only knows its size) once the
// playing screen is on screen. So `startGame` stores the config in
// `pendingStart` and flips `phase` to `.playing`; RootView mounts the
// canvas, whose GeometryReader reports its bounds through
// `canvasDidLayout(size:)`, which starts the engine with that world size
// (or resizes a running engine). `canvasDidDisappear()` forgets the size so
// the next mission waits for a fresh layout.

extension AppState {
    /// startGame (ui.js:1914-1944).
    func startGame(difficulty diff: Double, mode: MissionMode) {
        score = 0
        health = 100
        pendingHUDScore = nil
        pendingHUDHealth = nil
        pendingGameOver = nil
        difficulty = diff
        isLocalMultiplayer = mode == .local
        isCPUMultiplayer = mode == .cpu
        isOnlineGame = false
        currentMode = GameMode.forMission(difficulty: diff, duo: isLocalMultiplayer)
        liveTier = currentMode.tier
        audio.rewindMusic() // each mission starts the track from the top
        lastMission = LastMission(diff: diff, mode: mode)
        store.lastMission = lastMission

        var config = GameConfig()
        config.initialDifficulty = diff
        config.isLocalMultiplayer = isLocalMultiplayer
        config.isCPUMultiplayer = isCPUMultiplayer
        config.controlModePreference = .keyboard
        config.speedFactor = Double(speedPercent) / 100
        let gear1 = loadout1.resolved
        config.skin = gear1.skin
        config.trail = gear1.trail
        config.flame = gear1.flame
        if isLocalMultiplayer {
            let gear2 = loadout2.resolved
            config.skin2 = gear2.skin
            config.trail2 = gear2.trail
            config.flame2 = gear2.flame
        }

        phase = .playing
        isPaused = false
        pendingStart = config
        if let size = canvasSize { launchPendingStart(worldSize: size) }
        sync()
    }

    /// The canvas reported its bounds (on appear and whenever they change).
    func canvasDidLayout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let world = WorldSize(width: Double(size.width), height: Double(size.height))
        canvasSize = world
        if pendingStart != nil {
            launchPendingStart(worldSize: world)
        } else if engine.isRunning {
            engine.resize(worldSize: world)
        }
    }

    func canvasDidDisappear() {
        canvasSize = nil
    }

    func launchPendingStart(worldSize: WorldSize) {
        guard let config = pendingStart else { return }
        pendingStart = nil
        engine.start(config, worldSize: worldSize)
        engine.setSpeedFactor(Double(speedPercent) / 100)
        if config.online != nil { onlineEngineDidStart() }
    }

    /// The game-over / new-high RESTART button (ui.js:2523-2535).
    func restartLastMission() {
        if lastGameWasOnline {
            // An online round can't be replayed alone: back to the duo menu.
            returnToStart()
            menuMode = .twoPlayer
            return
        }
        startGame(difficulty: difficulty, mode: currentMissionMode)
    }

    /// returnToStart (ui.js:1946-1952).
    func returnToStart() {
        phase = .start
        menuMode = .main
        isPaused = false
        pendingStart = nil
        engine.stop()
        sync()
    }

    /// setPaused (ui.js:1954-1959): the host can't freeze the guest's screen.
    func setPaused(_ value: Bool) {
        if isOnlineGame { return }
        isPaused = value
        engine.setPaused(value)
        sync()
    }

    func togglePause() {
        setPaused(!isPaused)
    }

    /// handleGameOver (ui.js:1336-1387).
    func handleGameOver(score finalScore: Int) {
        engine.stop()
        pendingStart = nil
        lastGameWasOnline = isOnlineGame
        if isOnlineGame { endOnlineGame() }
        lastRoundConnectionLost = connectionLost
        connectionLost = false
        let beatRecord = Economy.beatsRecord(score: finalScore, best: currentBest)

        // Mission pay: coins scale with score, with a big bonus for a new
        // record. Star Fire doubles the take, Money Storm triples it.
        let earned = Economy.coinsEarned(score: finalScore, beatRecord: beatRecord,
                                         flamePower: loadout1.resolved.flame.power)
        if earned > 0 {
            coins += earned
            saveWallet()
        }
        earnedCoins = earned
        isNewRecord = beatRecord
        score = finalScore

        if beatRecord {
            setModeHighScore(currentMode, finalScore)
            phase = .newHigh
            pendingScore = finalScore
            pendingMode = currentMode
            audio.playFanfare() // fanfare leads the celebration in
            decideNewHighPhase()
        } else {
            phase = .gameOver
        }
        sync()
    }

    /// Which celebration sub-screen to show (ui.js:1373-1380): submit for a
    /// logged-in pilot, offer login when the server is reachable, celebrate
    /// silently offline.
    func decideNewHighPhase() {
        if session.user != nil {
            submitPendingScore()
        } else if !session.offline {
            newHighPhase = .offer
        } else {
            newHighPhase = .none
        }
    }

    /// The celebration screen's links and buttons (ui.js:2665-2697, 2536-2538).
    enum NewHighAction: Sendable { case login, register, forgot, skip, retry, backToLogin }

    func newHighAction(_ action: NewHighAction) {
        switch action {
        case .login, .backToLogin:
            newHighPhase = .offer
        case .register:
            newHighPhase = .register
        case .forgot:
            newHighPhase = .forgot
        case .skip:
            newHighPhase = .none
        case .retry:
            submitPendingScore()
        }
    }

    /// submitPendingScore (ui.js:1442-1464). A `rate_limited` reply keeps
    /// the score and offers RETRY, which waits out `retryAfter` first.
    func submitPendingScore() {
        guard let submitted = pendingScore, let mode = pendingMode else { return }
        newHighPhase = .submitting
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            if let at = self?.newHighRetryAt, at > Date() {
                try? await Task.sleep(for: .seconds(at.timeIntervalSinceNow))
            }
            guard let self, !Task.isCancelled else { return }
            await self.performScoreSubmit(score: submitted, mode: mode)
        }
    }

    func performScoreSubmit(score submitted: Int, mode: GameMode) async {
        do {
            let data = try await auth.submitScore(score: submitted, mode: mode.rawValue)
            guard pendingScore == submitted else { return }
            pendingScore = nil
            newHighRetryAt = nil
            if data.bestScore > (highScores[mode] ?? 0) { setModeHighScore(mode, data.bestScore) }
            newHighRankText = data.improved
                ? "GALACTIC RANK #\(data.rank ?? 0)"
                : "YOUR RECORD STANDS AT \(NumberFormat.integer(data.bestScore))"
            newHighRows = data.leaderboard
            newHighSubmitError = nil
            newHighCanRetry = false
            newHighPhase = .result
        } catch {
            let apiError = error as? APIError
            if apiError?.isUnauthorized == true { sessionExpired(); return }
            if apiError?.isRateLimited == true {
                newHighRetryAt = Date().addingTimeInterval(apiError?.retryAfter ?? AuthService.scoreMinInterval)
            }
            newHighRankText = ""
            newHighRows = []
            newHighSubmitError = "Transmission failed: " + (apiError?.message ?? error.localizedDescription)
            newHighCanRetry = true
            newHighPhase = .result
        }
    }

    /// setModeHighScore (ui.js:767-773).
    func setModeHighScore(_ mode: GameMode, _ value: Int) {
        highScores[mode] = value
        store.setHighScore(mode, value)
    }

    /// syncServerBests (ui.js:851-857): merge the server's per-mode bests.
    func syncServerBests(_ user: APIUser?) {
        guard let user else { return }
        for mode in GameMode.allCases {
            let serverBest = user.bestScores[mode.rawValue] ?? 0
            if serverBest > (highScores[mode] ?? 0) { setModeHighScore(mode, serverBest) }
        }
    }
}
