import Foundation

// The account / online state AppState carries. The wire types themselves
// (`APIUser`, `APILeaderboardRow`, `APIInvite`, `GamePayload`) live in
// Net/APIModels.swift; this file adds what the screens need on top of them.

/// `window.NeonAuth.state` plus the session.php payload.
struct SessionState: Sendable, Hashable {
    var user: APIUser?
    var csrf: String?
    /// The server could not be reached — celebrate records locally only.
    var offline = false
    var googleClientId: String?
}

/// The `user` object session.php / login.php return, as the UI reads it.
extension APIUser {
    var isDeveloper: Bool { role == "developer" || role == "lead_developer" }
    var isLeadDeveloper: Bool { role == "lead_developer" }

    /// The user chip's role label (ui.js:1231-1232).
    var roleLabel: String {
        switch role {
        case "lead_developer": return "Lead Dev"
        case "developer": return "Dev"
        default: return "Pilot"
        }
    }
}

/// One line of a leaderboard (leaderboard.php); ranks are unique per board.
extension APILeaderboardRow: Identifiable {
    var id: Int { rank }
}

/// `online` (ui.js:320) while in a lobby or an online round.
struct OnlineLobby: Sendable, Hashable {
    var code: String
    var mode: LobbyTier
    var role: OnlineRoleName
    /// "open" | "started" | "finished"
    var status: String
    /// The last lobby payload the server returned.
    var game: GamePayload?

    var isHost: Bool { role == .host }

    init(game: GamePayload, role: OnlineRoleName) {
        code = game.code
        mode = LobbyTier(rawValue: game.mode) ?? .medium
        self.role = role
        status = game.status
        self.game = game
    }
}

/// "host" | "guest" as the server and the wire spell it.
enum OnlineRoleName: String, Sendable, Hashable {
    case host, guest
}

/// `newhighPhase` (ui.js:290).
enum NewHighPhase: String, Sendable, Hashable {
    case offer, register, forgot, submitting, result, none
}

/// `authModalPhase` (ui.js:297).
enum AuthPhase: String, Sendable, Hashable {
    case login, register, forgot
}

/// `lobbyPhase` (ui.js:318).
enum LobbyPhase: String, Sendable, Hashable {
    case setup, wait, connecting
}

/// Settings → DELETE ACCOUNT…: which prompt is up.
enum DeleteAccountStep: Sendable, Hashable {
    case none
    /// "Delete your account? …" confirmation.
    case confirm
    /// Password accounts type their password first.
    case password
    /// The request is in flight.
    case working
}
