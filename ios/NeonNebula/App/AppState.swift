import Foundation
import Observation
import SwiftUI
import NeonEngine

/// The whole UI state, a flat port of the ui.js module variables (L272-328).
/// Every screen reads from here; every button calls a method here. The
/// account, leaderboard, friends, lobby and online-round logic lives in the
/// `AppState+Auth/+Friends/+Lobby/+Online` extensions.
@Observable @MainActor
final class AppState {
    enum GamePhase: Sendable { case start, playing, gameOver, newHigh }
    enum MenuMode: Sendable { case main, twoPlayer, cpu }
    enum Modal: Sendable, Hashable { case auth, leaderboard, tailor, friends, lobby, reset }

    // MARK: Screen flow (ui.js:274-290)

    var phase: GamePhase = .start
    var isPaused = false
    var menuMode: MenuMode = .main
    var modal: Modal? = nil
    var isSettingsOpen = false
    /// We paused for the settings modal, so we resume on close.
    var settingsAutoPaused = false

    // MARK: The round in progress

    var score = 0
    var health = 100
    var difficulty: Double = 1
    var currentMode: GameMode = .easy
    /// The lit tile of the HUD strip; follows the engine's live difficulty.
    var liveTier: Tier = .easy
    var highScores: [GameMode: Int]
    var lastMission: LastMission?
    var isLocalMultiplayer = false
    var isCPUMultiplayer = false
    /// The round just finished (ui.js:288-289).
    var pendingScore: Int? = nil
    var pendingMode: GameMode? = nil
    var isNewRecord = false
    /// Coins paid for the round just finished (shown on both end screens).
    var earnedCoins = 0
    /// Snapshot of `connectionLost` for the game-over subtitle (ui.js:1340-1343).
    var lastRoundConnectionLost = false
    /// The engine config waiting for the canvas to report its size (see
    /// `canvasDidLayout(size:)` in AppState+Missions.swift).
    var pendingStart: GameConfig? = nil

    // MARK: Wallet & Tailor (ui.js:298-309)

    var coins = 0
    var ownedSkins: [String]
    var ownedTrails: [String]
    var ownedFlames: [String]
    var loadout1: LoadoutIDs
    var loadout2: LoadoutIDs
    var tailorTab: TailorTab = .skins
    /// 1 | 2 — whose loadout the Tailor is dressing.
    var tailorPilot = 1
    var tailorError: String? = nil
    /// Bumps once per chest claim so the coin burst can replay.
    var dailyClaimBurst = 0

    // MARK: Settings

    var speedPercent: Int
    var musicPercent: Int
    var sfxPercent: Int
    var hasAccount: Bool

    // MARK: Accounts, leaderboard, online

    var session = SessionState()
    var newHighPhase: NewHighPhase = .none
    /// The celebration screen's result phase (ui.js:1447-1462).
    var newHighRankText = ""
    var newHighRows: [APILeaderboardRow] = []
    var newHighSubmitError: String? = nil
    var newHighCanRetry = false
    /// `leaderboard.php` keyed by mode; nil until fetched.
    var leaderboards: [GameMode: [APILeaderboardRow]]? = nil
    var leaderboardFailed = false
    var leaderboardTab: Tier = .easy
    var leaderboard2pTab: Tier = .easy
    var authPhase: AuthPhase = .login
    var online: OnlineLobby? = nil
    var lobbyPhase: LobbyPhase = .setup
    var lobbyModeChoice: LobbyTier = .medium
    /// The setup phase's code field and the two notice lines (ui.js:2131-2132).
    var lobbyCodeField = ""
    var lobbySetupMessage: String? = nil
    var lobbyMessage: String? = nil
    var lobbyBusy = false
    var isOnlineGame = false
    var lastGameWasOnline = false
    var connectionLost = false
    var pendingInvites: [APIInvite] = []
    /// The Friends page's fields and notices (ui.js:1998-2002, 2094-2124).
    var inviteCodeField = ""
    var friendsInviteNotice: String? = nil
    var friendsInviteOK = false
    var friendsJoinError: String? = nil
    /// Settings → DELETE ACCOUNT… prompt state.
    var deleteAccountStep: DeleteAccountStep = .none
    /// A transient toast.
    var notice: String? = nil
    /// The lead-developer console's status line and whether it is an error.
    var devConsoleMessage: String? = nil
    var devConsoleIsError = false

    // MARK: Services

    @ObservationIgnored let store: LocalStore
    @ObservationIgnored let audio: AudioEngine
    @ObservationIgnored let engine = GameEngine()
    @ObservationIgnored let api: APIClient
    @ObservationIgnored let auth: AuthService
    @ObservationIgnored let lobby: LobbyService
    @ObservationIgnored let google = GoogleAuth()
    @ObservationIgnored let apple = AppleAuth()
    /// Game Center in the app; a loopback fake in tests.
    @ObservationIgnored let matchmaking: any OnlineMatchmaking

    /// Delegate callbacks land here and are applied to the observable
    /// properties once per frame in `flushTick()`, so SwiftUI is not
    /// invalidated several times per engine tick.
    @ObservationIgnored var pendingHUDScore: Int? = nil
    @ObservationIgnored var pendingHUDHealth: Int? = nil
    @ObservationIgnored var pendingGameOver: Int? = nil
    /// The canvas's current size while it is on screen (nil when unmounted).
    @ObservationIgnored var canvasSize: WorldSize? = nil

    // Online plumbing (ui.js:319-325): the data channel, the other side's
    // hello and the pollers.
    @ObservationIgnored var netSession: NetSession? = nil
    @ObservationIgnored var peerHello: NetMessage.Hello? = nil
    @ObservationIgnored var inboxPollTask: Task<Void, Never>? = nil
    @ObservationIgnored var lobbyPollTask: Task<Void, Never>? = nil
    @ObservationIgnored var connectTask: Task<Void, Never>? = nil
    @ObservationIgnored var retryTask: Task<Void, Never>? = nil
    /// The guest launched but the engine has not started yet (the canvas
    /// must lay out first); `ready` goes out once it has.
    @ObservationIgnored var sendReadyOnLaunch = false
    /// Earliest moment a rate-limited score may be resubmitted.
    @ObservationIgnored var newHighRetryAt: Date? = nil
    @ObservationIgnored var didBootstrap = false
    @ObservationIgnored var wasBackgrounded = false
    #if DEBUG
    /// Screenshot helper: keep the session DebugLaunch staged, never talk
    /// to session.php.
    @ObservationIgnored var debugStagedSession = false
    #endif

    init(store: LocalStore = LocalStore(), audio: AudioEngine = AudioEngine(),
         client: APIClient = APIClient(), matchmaking: (any OnlineMatchmaking)? = nil) {
        self.store = store
        self.audio = audio
        api = client
        auth = AuthService(client: client)
        lobby = LobbyService(client: client)
        self.matchmaking = matchmaking ?? GameCenterService()

        // init() (ui.js:2397-2480): restore everything with the same
        // validation rules the browser applies.
        highScores = store.allHighScores()
        coins = store.coins
        ownedSkins = store.owned(.skins)
        ownedTrails = store.owned(.trails)
        ownedFlames = store.owned(.flames)
        loadout1 = store.loadout(pilot: 1)
        loadout2 = store.loadout(pilot: 2)
        lastMission = store.lastMission
        speedPercent = store.speedPercent
        musicPercent = store.musicPercent
        sfxPercent = store.sfxPercent
        hasAccount = store.hasAccount

        // The joystick is the keyboard path; keep the web's key in step.
        if store.string(LocalStore.Key.controlMode) == nil { store.controlMode = .keyboard }

        engine.delegate = self
        engine.setControlModePreference(.keyboard)
        engine.setSpeedFactor(Double(speedPercent) / 100)
        audio.applySettings(musicPercent: musicPercent, sfxPercent: sfxPercent)
        audio.onRouteLost = { [weak self] in self?.audioRouteLost() }
        sync()
    }

    // MARK: Derived values the screens share

    var isPlaying: Bool { phase == .playing }
    var isDeveloper: Bool { session.user?.isDeveloper ?? false }
    var isLeadDeveloper: Bool { session.user?.isLeadDeveloper ?? false }
    var anyModalOpen: Bool { isSettingsOpen || modal != nil }
    var currentUser: APIUser? { session.user }

    /// The all-time best across every mode (home "Best Score").
    var bestOverall: Int { GameMode.allCases.map { highScores[$0] ?? 0 }.max() ?? 0 }
    /// The best two-player record (duo menu "Duo Best").
    var duoBest: Int { GameMode.duo.map { highScores[$0] ?? 0 }.max() ?? 0 }
    var rankStanding: Rank.Standing { Rank.standing(best: bestOverall) }
    var currentBest: Int { highScores[currentMode] ?? 0 }

    /// The HUD difficulty strip (buildModeStrip, ui.js:781-795).
    var hudTiers: [Tier] {
        let base: [Tier] = [.easy, .medium, .hard]
        let tier = currentMode.tier
        if tier == .superHard { return [.superHard] }
        return Array(base.drop { $0 != tier })
    }

    /// The Tailor button's NEW badge (refreshTailorBadge, ui.js:977-993).
    var showTailorBadge: Bool {
        Catalog.anyAffordableUnowned(coins: coins, ownedSkins: ownedSkins, ownedTrails: ownedTrails,
                                     ownedFlames: ownedFlames, isDeveloper: isDeveloper)
    }

    /// The Tailor's PILOT 1 / PILOT 2 switch shows only from the duo menu.
    var tailorShowsPilots: Bool { menuMode == .twoPlayer }

    func owned(_ tab: TailorTab) -> [String] {
        switch tab {
        case .skins: return ownedSkins
        case .trails: return ownedTrails
        case .flames: return ownedFlames
        }
    }

    func loadout(pilot: Int) -> LoadoutIDs { pilot == 2 ? loadout2 : loadout1 }

    /// The mission mode of the round in progress / just finished.
    var currentMissionMode: MissionMode {
        isLocalMultiplayer ? .local : (isCPUMultiplayer ? .cpu : .single)
    }

    // MARK: render() side effects (ui.js:1207-1260)

    /// Audio follows the screen: gameplay music while playing and not
    /// paused, home music on the start screen, fanfare only on the
    /// celebration screen. Views show/hide themselves from `phase`.
    func sync() {
        let playing = phase == .playing
        audio.setMusicPlaying(playing && !isPaused)
        audio.setHomeMusicPlaying(phase == .start)
        if phase != .newHigh { audio.stopFanfare() }
        // A coasting ship sends no touches, so keep the screen awake while a
        // mission is running; the pause and menu screens may sleep as usual.
        UIApplication.shared.isIdleTimerDisabled = playing && !isPaused
    }

    // MARK: Modals

    func openModal(_ which: Modal) {
        switch which {
        case .auth:
            // First-timers land on account creation; returning pilots on login.
            authPhase = hasAccount ? .login : .register
        case .leaderboard:
            // Both sections open on the tier just played (ui.js:1897-1898).
            leaderboardTab = currentMode.tier
            leaderboard2pTab = currentMode.tier
            loadLeaderboards()
        case .tailor:
            tailorError = nil
        default:
            break
        }
        modal = which
    }

    func closeModal() {
        if modal == .friends { closeFriends(); return }
        modal = nil
    }

    // MARK: Hardware keyboard (ui.js:2832-2853)

    /// Enter on the start screen replays the last mission.
    func enterPressed() -> Bool {
        guard phase == .start, let last = lastMission, !anyModalOpen else { return false }
        startGame(difficulty: last.diff, mode: last.mode)
        return true
    }

    /// Escape closes whatever is on top, in the web's priority order.
    func escapePressed() -> Bool {
        if isSettingsOpen { closeSettings(); return true }
        if let modal {
            switch modal {
            case .lobby:
                if lobbyPhase == .connecting { return true }
                leaveLobby(notifyServer: true, message: nil)
            default:
                closeModal()
            }
            return true
        }
        if phase == .playing {
            // The host can't freeze the guest's screen (ui.js:1955).
            if !isOnlineGame { setPaused(!isPaused) }
            return true
        }
        return false
    }

    // MARK: App lifecycle

    /// Backgrounded (or the switcher opened) mid-mission: freeze the ship.
    /// Fully backgrounded: the online round or lobby can't survive it.
    func scenePhaseChanged(_ scene: ScenePhase) {
        switch scene {
        case .inactive:
            if phase == .playing && !isPaused { setPaused(true) }
        case .background:
            if phase == .playing && !isPaused { setPaused(true) }
            wasBackgrounded = true
            willResignActiveOnlineHook()
        case .active:
            if wasBackgrounded {
                wasBackgrounded = false
                Task { await bootstrapSession() }
            }
        @unknown default:
            break
        }
    }

    /// Headphones unplugged mid-mission: pause so the sudden silence doesn't
    /// cost the pilot a hull.
    private func audioRouteLost() {
        if phase == .playing && !isPaused { setPaused(true) }
    }
}
