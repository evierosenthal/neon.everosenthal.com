import Foundation

#if DEBUG
/// Screenshot and QA helper: `NEON_SCREEN=<name>` in the environment (or
/// `-NeonScreen <name>` as a launch argument) opens a screen right after
/// launch, so `xcrun simctl launch` can capture any state without tapping.
/// Names: settings, tailor, tailor2p, twoplayer, cpu, gameover, newhigh,
/// newhigh-offer, newhigh-register, newhigh-forgot, newhigh-submitting,
/// newhigh-result, pause, playing, auth, leaderboard, friends, lobby,
/// lobby-wait. `NEON_USER=<name>` stages a logged-in session (no server
/// call is made) so the account-gated screens can be captured;
/// `NEON_DIFF=<difficulty>` (0.3 / 0.62 / 1.3 / 6) picks the mission the
/// `playing` / `pause` screens launch. Debug only.
enum DebugLaunch {
    static func apply(to app: AppState) {
        let env = ProcessInfo.processInfo.environment
        var screen = env["NEON_SCREEN"]
        if screen == nil, let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-NeonScreen"),
           i + 1 < ProcessInfo.processInfo.arguments.count {
            screen = ProcessInfo.processInfo.arguments[i + 1]
        }
        if let coins = env["NEON_COINS"].flatMap(Int.init) { app.coins = coins }
        if let best = env["NEON_BEST"].flatMap(Int.init) { app.highScores[.medium] = best }
        if env["NEON_LAST"] == "1" { app.lastMission = LastMission(diff: 0.62, mode: .single) }
        if let name = env["NEON_USER"], !name.isEmpty {
            app.debugStagedSession = true
            app.session.user = APIUser(id: 0, username: name, role: "normal", bestScores: [:],
                                       email: nil, provider: "password", hasPassword: true)
            app.hasAccount = true
        }
        guard let screen else { return }
        let diff = env["NEON_DIFF"].flatMap(Double.init) ?? 0.62
        switch screen {
        case "settings":
            app.openSettings()
        case "tailor":
            app.openTailor(tab: .skins, pilot: 1)
        case "tailor2p":
            app.menuMode = .twoPlayer
            app.openTailor(tab: .flames, pilot: 2)
        case "twoplayer":
            app.menuMode = .twoPlayer
        case "cpu":
            app.menuMode = .cpu
        case "gameover":
            app.currentMode = .medium
            app.score = 1240
            app.earnedCoins = 25
            app.phase = .gameOver
            app.sync()
        case "newhigh":
            app.currentMode = .hard
            app.pendingMode = .hard
            app.pendingScore = 4210
            app.score = 4210
            app.earnedCoins = 420
            app.newHighPhase = .none
            app.phase = .newHigh
            app.sync()
        case "newhigh-offer", "newhigh-register", "newhigh-forgot", "newhigh-submitting", "newhigh-result":
            app.currentMode = .hard
            app.pendingMode = .hard
            app.pendingScore = 4210
            app.score = 4210
            app.earnedCoins = 420
            switch screen {
            case "newhigh-register": app.newHighPhase = .register
            case "newhigh-forgot": app.newHighPhase = .forgot
            case "newhigh-submitting": app.newHighPhase = .submitting
            case "newhigh-result":
                app.newHighPhase = .result
                app.newHighRankText = "GALACTIC RANK #3"
                app.newHighRows = (1...10).map { APILeaderboardRow(rank: $0, username: $0 == 3 ? (app.session.user?.username ?? "eve") : "pilot\($0)", score: 9000 - $0 * 500) }
            default: app.newHighPhase = .offer
            }
            app.phase = .newHigh
            app.sync()
        case "auth":
            app.openModal(.auth)
        case "leaderboard":
            app.openModal(.leaderboard)
        case "friends":
            app.openFriends()
        case "lobby":
            app.openLobby()
        case "lobby-wait":
            app.debugStagedSession = true
            let game = GamePayload(code: "NEBULA", mode: "medium", status: "open", host: app.session.user?.username ?? "eve",
                                   guest: nil, you: "host", hostOnline: true, guestOnline: false,
                                   hostPlatform: "ios", guestPlatform: nil)
            app.online = OnlineLobby(game: game, role: .host)
            app.modal = .lobby
            app.lobbyPhase = .wait
        case "pause":
            app.startGame(difficulty: diff, mode: .single)
            app.setPaused(true)
        case "playing":
            app.startGame(difficulty: diff, mode: .single)
        default:
            break
        }
    }
}
#endif
