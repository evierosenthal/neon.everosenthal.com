import Foundation
import NitroEngine
import XCTest
@testable import NitroNebula

// Shared scaffolding for the AppState-level auth / online tests: a fake
// Game Center, a droppable loopback transport, a tiny routed server and an
// AppState wired to both.

/// Stands in for `GameCenterService`: hands out a prepared link.
@MainActor
final class FakeMatchmaking: OnlineMatchmaking {
    var authenticated = true
    var gamePlayerID: String? = "me"
    var link: OnlineLink?
    var connectError: Error?
    var connectCalls = 0
    var cancelCalls = 0
    var authenticateCalls = 0

    func authenticate() async -> Bool {
        authenticateCalls += 1
        return authenticated
    }

    func connect(code: String, role: OnlineRoleName) async throws -> OnlineLink {
        connectCalls += 1
        if let connectError { throw connectError }
        guard let link else { throw GameCenterService.GameCenterError.timeout }
        return link
    }

    func cancel() {
        cancelCalls += 1
    }
}

/// A `LoopbackTransport` that can also report the peer going away, the way
/// `GameKitTransport` does, so `NetSession.onClosed` fires in tests.
nonisolated final class DroppableTransport: NetTransport, DisconnectReporting, @unchecked Sendable {
    let inner: LoopbackTransport
    var onDisconnect: (() -> Void)?

    init(_ inner: LoopbackTransport) {
        self.inner = inner
    }

    var onReceive: ((NetMessage) -> Void)? {
        get { inner.onReceive }
        set { inner.onReceive = newValue }
    }

    @discardableResult
    func send(_ message: NetMessage) -> Bool { inner.send(message) }

    func close() { inner.close() }

    func flush() { inner.flush() }

    /// The other side vanished.
    @MainActor func drop() {
        inner.close()
        onDisconnect?()
    }
}

/// A routed stub server for the whole api/ surface the AppState flows touch.
/// Mutable knobs are lock-guarded because the stub answers off-main.
nonisolated final class FakeServer: @unchecked Sendable {
    struct Knobs {
        var loggedIn = false
        var userJSON = """
        {"id":7,"username":"eve","email":"eve@example.com","role":"lead_developer","provider":"password","hasPassword":true,
         "bestScores":{"easy":10,"medium":0,"hard":0,"super":0,"2p_easy":0,"2p_medium":0,"2p_hard":0,"2p_super":0}}
        """
        var gameStatus = "open"
        var guest: String? = nil
        var guestOnline = false
        var hostOnline = true
        var invitesJSON = "[]"
        /// Peer player ids keyed by the requesting client's host name.
        var peerIDs: [String: String] = [:]
        var scoreReplies: [StubURLProtocol.Response] = []
        var loginReply: StubURLProtocol.Response? = nil
        var joinReply: StubURLProtocol.Response? = nil
        var statusReply: StubURLProtocol.Response? = nil
    }

    let knobs = Locked(Knobs())

    func set(_ change: (inout Knobs) -> Void) {
        knobs.withLock(change)
    }

    func install() {
        StubURLProtocol.respond { [self] req in self.route(req) }
    }

    private func gameJSON(_ k: Knobs, you: String?) -> String {
        let guest = k.guest.map { "\"\($0)\"" } ?? "null"
        let youText = you.map { "\"\($0)\"" } ?? "null"
        return """
        {"game":{"code":"NEBULA","mode":"medium","status":"\(k.gameStatus)","host":"eve","guest":\(guest),"you":\(youText),
         "hostOnline":\(k.hostOnline),"guestOnline":\(k.guestOnline),"hostPlatform":"ios","guestPlatform":null}}
        """
    }

    /// The router itself, for responders that wrap it.
    func route(_ req: StubURLProtocol.Captured) -> StubURLProtocol.Reply? {
        let k = knobs.withLock { $0 }
        let path = req.url.lastPathComponent
        let comps = URLComponents(url: req.url, resolvingAgainstBaseURL: false)
        let query = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let host = req.url.host ?? ""
        switch path {
        case "session.php":
            return .response(.json(200, "{\"loggedIn\":\(k.loggedIn),\"user\":\(k.loggedIn ? k.userJSON : "null"),\"csrf\":\"tok\",\"googleClientId\":\"web-client\",\"apiVersion\":1}"))
        case "login.php", "register.php":
            if let reply = k.loginReply { return .response(reply) }
            return .response(.json(200, "{\"loggedIn\":true,\"user\":\(k.userJSON),\"csrf\":\"tok2\"}"))
        case "logout.php":
            return .response(.json(200, "{\"loggedIn\":false,\"user\":null,\"csrf\":\"tok3\"}"))
        case "submit-score.php":
            let reply = knobs.withLock { $0.scoreReplies.isEmpty ? nil : $0.scoreReplies.removeFirst() }
            return .response(reply ?? .json(200, "{\"mode\":\"easy\",\"bestScore\":500,\"improved\":true,\"rank\":3,\"leaderboard\":[{\"rank\":1,\"username\":\"x\",\"score\":900}]}"))
        case "leaderboard.php":
            return .response(.json(200, "{\"leaderboards\":{\"easy\":[{\"rank\":1,\"username\":\"eve\",\"score\":10}]}}"))
        case "games.php":
            if req.method == "GET" {
                switch query["action"] {
                case "inbox":
                    return .response(.json(200, "{\"invites\":\(k.invitesJSON),\"game\":null}"))
                case "status":
                    if let reply = k.statusReply { return .response(reply) }
                    return .response(.json(200, gameJSON(k, you: nil)))
                case "signals":
                    let messages = k.peerIDs[host].map { "[{\"id\":1,\"payload\":{\"type\":\"gc\",\"gamePlayerID\":\"\($0)\"}}]" } ?? "[]"
                    return .response(.json(200, "{\"messages\":\(messages),\"status\":\"\(k.gameStatus)\"}"))
                default:
                    return nil
                }
            }
            switch req.json["action"] as? String {
            case "create":
                return .response(.json(200, gameJSON(k, you: "host")))
            case "join":
                if let reply = k.joinReply { return .response(reply) }
                return .response(.json(200, gameJSON(k, you: "guest")))
            case "start":
                knobs.withLock { $0.gameStatus = "started" }
                var started = k
                started.gameStatus = "started"
                return .response(.json(200, gameJSON(started, you: "host")))
            case "invite":
                return .response(.json(200, "{\"ok\":true,\"to\":\"bob\",\"code\":\"NEBULA\"}"))
            default:
                return .response(.json(200, "{\"ok\":true}"))
            }
        default:
            return nil
        }
    }
}

enum AppStateFixtures {
    /// An AppState on a private defaults suite, the stub sockets and a fake
    /// matchmaker. `host` names the stub client so the server can tell two
    /// apps apart.
    @MainActor
    static func makeApp(suite: String, host: String = "localhost",
                        matchmaking: FakeMatchmaking = FakeMatchmaking()) -> (AppState, FakeMatchmaking, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let session = APIClient.makeSession(protocolClasses: [StubURLProtocol.self], ephemeral: true)
        let client = APIClient(baseURL: URL(string: "http://\(host):8000/api/")!, session: session)
        let app = AppState(store: LocalStore(defaults: defaults), client: client, matchmaking: matchmaking)
        return (app, matchmaking, defaults)
    }

    /// Spin the main actor until `condition` holds (or the timeout passes).
    @MainActor
    static func waitUntil(timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    static let eveUser = APIUser(id: 7, username: "eve", role: "normal", bestScores: [:], email: nil, provider: "password", hasPassword: true)
    static let bobUser = APIUser(id: 8, username: "bob", role: "normal", bestScores: [:], email: nil, provider: "apple", hasPassword: false)
}
