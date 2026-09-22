import Foundation

// Codable mirrors of every JSON shape www/api/*.php returns. Field names are
// the JSON keys verbatim so the PHP and Swift sides can be diffed by eye.
//
// `nonisolated`: the app builds with SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor;
// these plain value types must be usable from the APIClient actor and from
// URLSession callbacks, so they opt out of main-actor isolation explicitly.

/// `user_payload()` in api/_bootstrap.php. Also the app's user model
/// (Model/Session.swift adds the role helpers).
nonisolated struct APIUser: Codable, Sendable, Hashable {
    var id: Int
    var username: String
    var role: String
    var bestScores: [String: Int]
    var email: String?
    var provider: String?      // 'password' | 'google' | 'apple'
    var hasPassword: Bool?
}

/// One row of `leaderboard_rows()` (Identifiable by rank, see Model/Session.swift).
nonisolated struct APILeaderboardRow: Codable, Sendable, Hashable {
    var rank: Int
    var username: String
    var score: Int
}

/// session.php, login.php, register.php, google.php, apple.php, logout.php,
/// reset-password.php and delete-account.php all answer with this shape (the
/// optional fields are only on session.php / delete-account.php).
nonisolated struct SessionResponse: Codable, Sendable, Equatable {
    var loggedIn: Bool
    var user: APIUser?
    var csrf: String?
    var googleClientId: String?
    var offline: Bool?
    var apiVersion: Int?
    var ok: Bool?

    init(loggedIn: Bool, user: APIUser? = nil, csrf: String? = nil, googleClientId: String? = nil,
         offline: Bool? = nil, apiVersion: Int? = nil, ok: Bool? = nil) {
        self.loggedIn = loggedIn
        self.user = user
        self.csrf = csrf
        self.googleClientId = googleClientId
        self.offline = offline
        self.apiVersion = apiVersion
        self.ok = ok
    }

    /// What auth.js does when session.php cannot be reached: logged out,
    /// `offline` set, and the game carries on with local high scores.
    static let offlineFallback = SessionResponse(loggedIn: false, offline: true)

    var isOffline: Bool { offline ?? false }
}

/// submit-score.php
nonisolated struct ScoreSubmitResponse: Codable, Sendable, Equatable {
    var mode: String
    var bestScore: Int
    var improved: Bool
    var rank: Int?
    var leaderboard: [APILeaderboardRow]
}

/// leaderboard.php: top 10 per mode, keyed by mode name (GAME_MODES).
nonisolated struct LeaderboardsResponse: Codable, Sendable, Equatable {
    var leaderboards: [String: [APILeaderboardRow]]
}

/// `{ok: true}` (+ an optional `message`, e.g. request-reset.php).
nonisolated struct OkResponse: Codable, Sendable, Equatable {
    var ok: Bool
    var message: String?
}

/// games.php `game_payload()`.
nonisolated struct GamePayload: Codable, Sendable, Hashable {
    var code: String
    var mode: String
    var status: String          // 'open' | 'started' | 'finished'
    var host: String
    var guest: String?
    var you: String?            // 'host' | 'guest' | nil
    var hostOnline: Bool
    var guestOnline: Bool
    var hostPlatform: String?   // 'web' | 'ios'
    var guestPlatform: String?

    var isHost: Bool { you == "host" }
    var isGuest: Bool { you == "guest" }
}

/// games.php `{"game": ...}` wrapper (create / join / start / status).
nonisolated struct GameResponse: Codable, Sendable, Equatable {
    var game: GamePayload
}

/// One pending invite in the inbox.
nonisolated struct APIInvite: Codable, Sendable, Hashable, Identifiable {
    var id: Int
    var code: String
    var from: String
    var mode: String
}

/// games.php?action=inbox
nonisolated struct InboxResponse: Codable, Sendable, Equatable {
    var invites: [APIInvite]
    var game: GamePayload?
}

/// games.php action=invite: `{ok, to, code}`.
nonisolated struct InviteResponse: Codable, Sendable, Equatable {
    var ok: Bool
    var to: String
    var code: String
}

/// games.php?action=signals: relayed messages from the other side.
nonisolated struct SignalsResponse: Codable, Sendable, Equatable {
    var messages: [SignalMessage]
    var status: String
}

/// A relayed `signal` payload. The iOS app only ever exchanges
/// `{type: 'gc', gamePlayerID}`; the web's SDP offers/answers also fit.
nonisolated struct SignalMessage: Codable, Sendable, Equatable {
    var id: Int
    var payload: SignalPayload
}

nonisolated struct SignalPayload: Codable, Sendable, Equatable {
    var type: String
    var gamePlayerID: String?
    var sdp: String?

    init(type: String, gamePlayerID: String? = nil, sdp: String? = nil) {
        self.type = type
        self.gamePlayerID = gamePlayerID
        self.sdp = sdp
    }

    static func gameCenter(gamePlayerID: String) -> SignalPayload {
        SignalPayload(type: "gc", gamePlayerID: gamePlayerID)
    }
}

/// set-role.php: `{ok, username, role}`.
nonisolated struct RoleResponse: Codable, Sendable, Equatable {
    var ok: Bool
    var username: String
    var role: String
}

/// run-migrations.php: `{ok, results: {"01_x.sql": "applied" | "already applied"}}`.
nonisolated struct MigrationsResponse: Codable, Sendable, Equatable {
    var ok: Bool
    var results: [String: String]
}

/// The `{error, message}` body every `json_error()` produces, plus the
/// client-side fallbacks auth.js adds (auth.js:29-44, 116-120).
nonisolated struct APIError: Error, Sendable, Equatable, LocalizedError {
    /// Machine code: `bad_csrf`, `unauthorized`, `rate_limited`,
    /// `platform_mismatch`, ... or the client's own `server_error` / `offline`.
    var code: String
    var message: String
    /// HTTP status (0 for a transport failure).
    var status: Int
    /// For `rate_limited`: how long to wait before retrying, in seconds.
    var retryAfter: TimeInterval?

    init(code: String, message: String, status: Int, retryAfter: TimeInterval? = nil) {
        self.code = code
        self.message = message
        self.status = status
        self.retryAfter = retryAfter
    }

    /// The server answered with something that is not JSON (auth.js:38-42).
    static func serverError(status: Int) -> APIError {
        APIError(code: "server_error", message: "Server returned an unreadable response", status: status)
    }

    /// The request never got an answer (auth.js:116-120 → `state.offline`).
    static func offline(_ underlying: Error? = nil) -> APIError {
        APIError(code: "offline", message: underlying?.localizedDescription ?? "Could not reach the server.", status: 0)
    }

    var errorDescription: String? { message }
    var isOffline: Bool { code == "offline" }
    var isRateLimited: Bool { code == "rate_limited" }
    var isUnauthorized: Bool { code == "unauthorized" }

    /// The wire shape (`{error, message}`).
    nonisolated struct Body: Codable, Sendable {
        var error: String?
        var message: String?
    }
}
