import Foundation

/// Port of `window.NeonAuth` (www/auth.js:89-194): the account and
/// leaderboard calls, plus the little state the web keeps (`state.user`,
/// `state.googleClientId`, `state.offline`, `onAuthChange`).
///
/// Every call goes through one `APIClient`, so the session cookie and CSRF
/// token are shared with `LobbyService`. Errors are `APIError`s; the
/// `message` is what the server (or auth.js) would show the player.
@MainActor
final class AuthService {
    /// `SCORE_MIN_INTERVAL_SEC`: how long to wait after a `rate_limited`
    /// submit-score before trying again.
    nonisolated static let scoreMinInterval: TimeInterval = APIClient.scoreMinIntervalSec

    let client: APIClient

    /// `state.user`
    private(set) var user: APIUser?
    /// `state.googleClientId` (the web OAuth client; the app's own lives in
    /// Info.plist `GIDClientID`). Kept for reference.
    private(set) var googleClientId: String?
    /// `state.offline`: session.php was unreachable or reported the DB down.
    private(set) var offline = false
    /// `state.ready`: bootstrap() has completed (even if offline).
    private(set) var ready = false
    /// session.php `apiVersion`; bump on the server means "update the app".
    private(set) var apiVersion: Int?

    /// `onAuthChange` listeners: called with the new user after every
    /// login / logout / register / reset / delete.
    var onAuthChange: ((APIUser?) -> Void)?

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    var isLoggedIn: Bool { user != nil }

    // MARK: - Bootstrap (auth.js:105-121)

    /// GET session.php. Never throws: an unreachable server yields the same
    /// `offline` session the web falls back to, so the game can still start.
    @discardableResult
    func bootstrap() async -> SessionResponse {
        do {
            let data: SessionResponse = try await client.get("session.php")
            applySession(data)
            googleClientId = data.googleClientId
            apiVersion = data.apiVersion
            offline = data.isOffline
            ready = true
            if user != nil { onAuthChange?(user) }
            return data
        } catch {
            offline = true
            ready = true
            return .offlineFallback
        }
    }

    // MARK: - Accounts

    /// register.php → logged in as the new account.
    @discardableResult
    func register(username: String, email: String, password: String) async throws -> APIUser? {
        let data: SessionResponse = try await client.post("register.php", body: RegisterBody(username: username, email: email, password: password))
        applySession(data)
        onAuthChange?(user)
        return user
    }

    /// login.php. Social-only accounts get `use_google` / `use_apple`.
    @discardableResult
    func login(usernameOrEmail: String, password: String) async throws -> APIUser? {
        let data: SessionResponse = try await client.post("login.php", body: LoginBody(usernameOrEmail: usernameOrEmail, password: password))
        applySession(data)
        onAuthChange?(user)
        return user
    }

    /// logout.php: ends the session; the reply carries a fresh CSRF token.
    func logout() async throws {
        let data: SessionResponse = try await client.post("logout.php")
        applySession(data)
        onAuthChange?(user)
    }

    /// google.php `{credential}` with the ID token from `GoogleAuth.signIn`.
    @discardableResult
    func googleSignIn(idToken: String) async throws -> APIUser? {
        let data: SessionResponse = try await client.post("google.php", body: GoogleBody(credential: idToken))
        applySession(data)
        onAuthChange?(user)
        return user
    }

    /// apple.php with the payload from `AppleAuth.signIn`. The raw nonce lets
    /// the server check the token's hashed nonce; `fullName` only arrives on
    /// the very first authorization, so pass it whenever Apple gave it.
    @discardableResult
    func appleSignIn(identityToken: String, authorizationCode: String? = nil, nonce: String? = nil,
                     fullName: (given: String?, family: String?)? = nil) async throws -> APIUser? {
        let name = fullName.map { AppleBody.FullName(givenName: $0.given, familyName: $0.family) }
        let body = AppleBody(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce, fullName: name)
        let data: SessionResponse = try await client.post("apple.php", body: body)
        applySession(data)
        onAuthChange?(user)
        return user
    }

    /// delete-account.php. Password accounts must send their password; an
    /// Apple-linked account may send a fresh authorization code
    /// (`AppleAuth.reauthorize`) so the server can revoke Apple's grant.
    func deleteAccount(password: String? = nil, appleAuthorizationCode: String? = nil) async throws {
        let body = DeleteBody(password: password, appleAuthorizationCode: appleAuthorizationCode)
        let data: SessionResponse = try await client.post("delete-account.php", body: body)
        applySession(data)
        onAuthChange?(user)
    }

    // MARK: - Scores

    /// submit-score.php. A `rate_limited` APIError carries `retryAfter`
    /// (10 s); the caller should hold the score and resubmit after that.
    func submitScore(score: Int, mode: String) async throws -> ScoreSubmitResponse {
        let result: ScoreSubmitResponse = try await client.post("submit-score.php", body: ScoreBody(score: score, mode: mode))
        if var u = user, u.bestScores[mode, default: 0] < result.bestScore {
            u.bestScores[mode] = result.bestScore
            user = u
        }
        return result
    }

    /// leaderboard.php: top 10 per mode.
    func leaderboards() async throws -> [String: [APILeaderboardRow]] {
        let data: LeaderboardsResponse = try await client.get("leaderboard.php")
        return data.leaderboards
    }

    // MARK: - Password reset

    /// request-reset.php: always "ok" so account existence cannot be probed.
    func requestReset(email: String) async throws -> OkResponse {
        try await client.post("request-reset.php", body: EmailBody(email: email))
    }

    /// reset-password.php: consumes the emailed token and logs in.
    @discardableResult
    func resetPassword(token: String, newPassword: String) async throws -> APIUser? {
        let data: SessionResponse = try await client.post("reset-password.php", body: ResetBody(token: token, newPassword: newPassword))
        applySession(data)
        onAuthChange?(user)
        return user
    }

    // MARK: - Lead developer tools

    /// set-role.php (lead developers only): 'developer' or 'normal'.
    func setRole(username: String, role: String) async throws -> RoleResponse {
        try await client.post("set-role.php", body: RoleBody(username: username, role: role))
    }

    /// run-migrations.php (lead developers only).
    func runMigrations() async throws -> MigrationsResponse {
        try await client.post("run-migrations.php")
    }

    // MARK: - Internals

    /// `applySession()` (auth.js:58-61). The CSRF token itself is picked up
    /// by APIClient from the same response.
    private func applySession(_ data: SessionResponse) {
        user = data.user
    }

    // Request bodies (field names are what the PHP reads).
    nonisolated private struct RegisterBody: Encodable, Sendable { var username, email, password: String }
    nonisolated private struct LoginBody: Encodable, Sendable { var usernameOrEmail, password: String }
    nonisolated private struct GoogleBody: Encodable, Sendable { var credential: String }
    nonisolated private struct AppleBody: Encodable, Sendable {
        var identityToken: String
        var authorizationCode: String?
        var nonce: String?
        var fullName: FullName?
        nonisolated struct FullName: Encodable, Sendable { var givenName: String?; var familyName: String? }
    }
    nonisolated private struct DeleteBody: Encodable, Sendable { var password: String?; var appleAuthorizationCode: String? }
    nonisolated private struct ScoreBody: Encodable, Sendable { var score: Int; var mode: String }
    nonisolated private struct EmailBody: Encodable, Sendable { var email: String }
    nonisolated private struct ResetBody: Encodable, Sendable { var token, newPassword: String }
    nonisolated private struct RoleBody: Encodable, Sendable { var username, role: String }
}
