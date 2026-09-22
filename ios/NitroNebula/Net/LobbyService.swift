import Foundation

/// Port of `NeonNet.lobby` (www/net.js:36-68): the thin wrappers over
/// api/games.php that pair two accounts under a game code. The round itself
/// then runs over Game Center (`GameCenterService` + `GameKitTransport`);
/// the only thing relayed through `signal` is `{type:'gc', gamePlayerID}`.
///
/// Every create/join says `platform: "ios"` so the server pairs app with app
/// (a web host refuses an app guest with `platform_mismatch`, and vice versa).
@MainActor
final class LobbyService {
    /// What we tell the server we are (net.js:38 sends 'web').
    nonisolated static let platform = "ios"

    /// The code alphabet the web draws from: no 0/O/1/I look-alikes (ui.js:1968).
    nonisolated static let codeAlphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    nonisolated static let codeLength = 5

    // Timings the web uses to drive the lobby (ui.js:1952-2384, net.js:24-26).
    /// Inbox poll while the Friends page is open.
    nonisolated static let inboxPollOpen: TimeInterval = 5
    /// Inbox poll on the start screen (badge only).
    nonisolated static let inboxPollIdle: TimeInterval = 20
    /// Lobby status poll while waiting (also our "still here" heartbeat;
    /// the server marks a side gone after 45 s without one).
    nonisolated static let lobbyPoll: TimeInterval = 2
    /// How often to ask for the other side's signal while connecting.
    nonisolated static let signalPoll: TimeInterval = 0.9
    /// Give up linking after this long.
    nonisolated static let connectTimeout: TimeInterval = 30

    let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    // MARK: - Codes

    /// Five characters from `codeAlphabet` (ui.js:1967-1972).
    nonisolated static func newGameCode() -> String {
        var rng = SystemRandomNumberGenerator()
        return newGameCode(using: &rng)
    }

    nonisolated static func newGameCode(using rng: inout some RandomNumberGenerator) -> String {
        String((0..<codeLength).map { _ in codeAlphabet.randomElement(using: &rng)! })
    }

    func newGameCode() -> String { Self.newGameCode() }

    /// `cleanCode()` (ui.js:1974-1976): upper-case, alphanumerics only, max 12.
    nonisolated static func cleanCode(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(12))
    }

    /// The server accepts 4 to 12 cleaned characters.
    nonisolated static func isValidCode(_ code: String) -> Bool {
        let c = cleanCode(code)
        return c.count >= 4 && c.count <= 12 && c == code
    }

    // MARK: - Lobby actions (POST)

    /// Open a lobby I host. `mode` is 'easy' | 'medium' | 'hard'.
    func create(code: String, mode: String) async throws -> GamePayload {
        let data: GameResponse = try await client.post("games.php", body: CreateBody(code: code, mode: mode))
        return data.game
    }

    /// Invite a pilot by username into my open lobby.
    func invite(username: String, code: String) async throws -> InviteResponse {
        try await client.post("games.php", body: InviteBody(username: username, code: code))
    }

    /// Take the guest seat. Errors: not_found, own_game, started, full,
    /// platform_mismatch (the host is on the web).
    func join(code: String) async throws -> GamePayload {
        let data: GameResponse = try await client.post("games.php", body: JoinBody(code: code))
        return data.game
    }

    /// Dismiss an invite.
    func decline(id: Int) async throws -> OkResponse {
        try await client.post("games.php", body: DeclineBody(id: id))
    }

    /// Host only, guest must be seated: status → 'started'.
    func start(code: String) async throws -> GamePayload {
        let data: GameResponse = try await client.post("games.php", body: CodeBody(action: "start", code: code))
        return data.game
    }

    /// Host closes the lobby / guest steps out. Always ok.
    func leave(code: String) async throws -> OkResponse {
        try await client.post("games.php", body: CodeBody(action: "leave", code: code))
    }

    /// Either side: the round is over.
    func finish(code: String) async throws -> OkResponse {
        try await client.post("games.php", body: CodeBody(action: "finish", code: code))
    }

    /// Relay a small JSON object to the other side. The app sends
    /// `SignalPayload.gameCenter(gamePlayerID:)` so each side can check the
    /// Game Center peer it got is the account it expects.
    func signal(code: String, payload: SignalPayload) async throws -> OkResponse {
        try await client.post("games.php", body: SignalBody(code: code, payload: payload))
    }

    // MARK: - Polling (GET)

    /// Messages from the other side with id > `after` (max 50), plus the
    /// lobby status. Also counts as a heartbeat.
    func signals(code: String, after: Int = 0) async throws -> SignalsResponse {
        try await client.get("games.php", query: ["action": "signals", "code": code, "after": String(after)])
    }

    /// Pending invites + the lobby I'm already sitting in, if any.
    func inbox() async throws -> InboxResponse {
        try await client.get("games.php", query: ["action": "inbox"])
    }

    /// Lobby state; my heartbeat. Errors: not_found, forbidden (the web
    /// treats both as "that game is gone").
    func status(code: String) async throws -> GamePayload {
        let data: GameResponse = try await client.get("games.php", query: ["action": "status", "code": code])
        return data.game
    }

    // MARK: - Bodies

    nonisolated private struct CreateBody: Encodable, Sendable {
        var action = "create"
        var code: String
        var mode: String
        var platform = LobbyService.platform
    }
    nonisolated private struct JoinBody: Encodable, Sendable {
        var action = "join"
        var code: String
        var platform = LobbyService.platform
    }
    nonisolated private struct InviteBody: Encodable, Sendable {
        var action = "invite"
        var username: String
        var code: String
    }
    nonisolated private struct DeclineBody: Encodable, Sendable {
        var action = "decline"
        var id: Int
    }
    nonisolated private struct CodeBody: Encodable, Sendable {
        var action: String
        var code: String
    }
    nonisolated private struct SignalBody: Encodable, Sendable {
        var action = "signal"
        var code: String
        var payload: SignalPayload
    }
}
