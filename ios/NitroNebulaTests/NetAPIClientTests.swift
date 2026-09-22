import Foundation
import XCTest
@testable import NitroNebula

// MARK: - Stub transport

/// A canned HTTP server: every request is recorded (with its body) and
/// answered by the current `responder`.
nonisolated final class StubURLProtocol: URLProtocol {
    struct Response: Sendable {
        var status: Int
        var headers: [String: String]
        var body: Data

        static func json(_ status: Int = 200, _ text: String, headers: [String: String] = [:]) -> Response {
            var h = ["Content-Type": "application/json; charset=utf-8"]
            h.merge(headers) { _, new in new }
            return Response(status: status, headers: h, body: Data(text.utf8))
        }
    }

    /// What the stub answers, or a transport error (`URLError`).
    enum Reply: Sendable {
        case response(Response)
        case failure(URLError)
    }

    struct Captured: Sendable {
        var method: String
        var url: URL
        var headers: [String: String]
        var body: Data

        var json: [String: Any] {
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        }

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }

    /// A route-based answerer, consulted before the FIFO queue (AppState
    /// flows fire several requests whose order is not fixed).
    typealias Responder = @Sendable (Captured) -> Reply?

    private struct State {
        var requests: [Captured] = []
        var replies: [Reply] = []
        var responder: Responder? = nil
    }

    private static let state = Locked(State())

    static func reset() {
        state.withLock { $0 = State() }
    }

    static func enqueue(_ reply: Reply) {
        state.withLock { $0.replies.append(reply) }
    }

    static func enqueue(_ response: Response) {
        enqueue(.response(response))
    }

    static var requests: [Captured] {
        state.withLock { $0.requests }
    }

    static func respond(_ responder: Responder?) {
        state.withLock { $0.responder = responder }
    }

    static var lastRequest: Captured? { requests.last }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        let body = request.httpBody ?? Self.drain(request.httpBodyStream)
        let captured = Captured(method: request.httpMethod ?? "GET",
                                url: request.url!,
                                headers: request.allHTTPHeaderFields ?? [:],
                                body: body)
        let reply: Reply = Self.state.withLock { state in
            state.requests.append(captured)
            if let routed = state.responder?(captured) { return routed }
            return state.replies.isEmpty ? .response(.json(200, "{}")) : state.replies.removeFirst()
        }
        switch reply {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .response(let r):
            let response = HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: "HTTP/1.1", headerFields: r.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: r.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

// MARK: - Fixtures

enum NetFixtures {
    static let baseURL = URL(string: "http://localhost:8000/api/")!

    static let userJSON = """
    {"id":7,"username":"eve","email":"eve@example.com","role":"lead_developer","provider":"password","hasPassword":true,
     "bestScores":{"easy":10,"medium":0,"hard":0,"super":0,"2p_easy":0,"2p_medium":0,"2p_hard":0,"2p_super":0}}
    """

    static func session(loggedIn: Bool, csrf: String) -> String {
        """
        {"loggedIn":\(loggedIn),"user":\(loggedIn ? userJSON : "null"),"csrf":"\(csrf)",
         "googleClientId":"web-client","apiVersion":1}
        """
    }

    /// A client whose cookies live in a private jar and whose sockets are the stub.
    @MainActor
    static func makeClient() -> (APIClient, HTTPCookieStorage) {
        let session = APIClient.makeSession(protocolClasses: [StubURLProtocol.self], ephemeral: true)
        let jar = session.configuration.httpCookieStorage!
        jar.removeCookies(since: .distantPast)
        return (APIClient(baseURL: baseURL, session: session), jar)
    }
}

// MARK: - Tests

nonisolated final class NetAPIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    @MainActor func testGetSendsNoCSRFAndNoOrigin() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: false, csrf: "tok1")))
        let s: SessionResponse = try await client.get("session.php")
        XCTAssertFalse(s.loggedIn)
        XCTAssertEqual(s.csrf, "tok1")
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(req.url.absoluteString, "http://localhost:8000/api/session.php")
        XCTAssertNil(req.header("X-CSRF-Token"))
        XCTAssertNil(req.header("Origin"))
        XCTAssertEqual(req.header("User-Agent")?.hasPrefix("NitroNebula-iOS/"), true)
        let stored = await client.csrf
        XCTAssertEqual(stored, "tok1")
    }

    @MainActor func testGetQueryIsEncoded() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(200, "{\"invites\":[],\"game\":null}"))
        let _: InboxResponse = try await client.get("games.php", query: ["action": "status", "code": "AB CD"])
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.url.absoluteString, "http://localhost:8000/api/games.php?action=status&code=AB%20CD")
    }

    @MainActor func testPostSendsJSONBodyAndCSRFHeader() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: false, csrf: "tok1")))
        let _: SessionResponse = try await client.get("session.php")

        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: true, csrf: "tok2")))
        nonisolated struct Body: Encodable, Sendable { var usernameOrEmail: String; var password: String }
        let s: SessionResponse = try await client.post("login.php", body: Body(usernameOrEmail: "eve", password: "pw"))
        XCTAssertTrue(s.loggedIn)
        XCTAssertEqual(s.user?.username, "eve")
        XCTAssertEqual(s.user?.provider, "password")
        XCTAssertEqual(s.user?.bestScores["easy"], 10)

        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.header("Content-Type"), "application/json")
        XCTAssertEqual(req.header("X-CSRF-Token"), "tok1")
        XCTAssertNil(req.header("Origin"))
        XCTAssertEqual(req.json["usernameOrEmail"] as? String, "eve")
        XCTAssertEqual(req.json["password"] as? String, "pw")

        // The login response rotated the token; the next POST carries the new one.
        let rotated = await client.csrf
        XCTAssertEqual(rotated, "tok2")
        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        let _: OkResponse = try await client.post("logout.php")
        let next = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(next.header("X-CSRF-Token"), "tok2")
        XCTAssertEqual(String(decoding: next.body, as: UTF8.self), "{}")
    }

    @MainActor func testPostBeforeBootstrapSendsEmptyCSRF() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        let _: OkResponse = try await client.post("logout.php")
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.header("X-CSRF-Token"), "")
    }

    /// Through the real HTTP stack: the PHP session cookie set by one
    /// response is stored in the session's jar and sent on the next request.
    @MainActor func testSessionCookiePersistsAcrossRequests() async throws {
        let server = try NetLoopbackServer()
        try await server.start()
        defer { server.stop() }
        let session = APIClient.makeSession(ephemeral: true)
        let jar = try XCTUnwrap(session.configuration.httpCookieStorage)
        jar.removeCookies(since: .distantPast)
        let client = APIClient(baseURL: server.baseURL, session: session)

        server.enqueue(.init(headers: ["Content-Type": "application/json", "Set-Cookie": "neon_sid=abc; Path=/; HttpOnly"],
                             body: NetFixtures.session(loggedIn: false, csrf: "tok1")))
        let s: SessionResponse = try await client.get("session.php")
        XCTAssertEqual(s.csrf, "tok1")
        let cookies = jar.cookies(for: server.baseURL) ?? []
        XCTAssertEqual(cookies.map(\.name), ["neon_sid"])
        XCTAssertEqual(cookies.first?.value, "abc")
        XCTAssertEqual(cookies.first?.isHTTPOnly, true)

        server.enqueue(.init(body: "{\"leaderboards\":{}}"))
        let _: LeaderboardsResponse = try await client.get("leaderboard.php")
        let requests = server.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.path, "/api/leaderboard.php")
        XCTAssertEqual(requests.last?.header("Cookie"), "neon_sid=abc")
        XCTAssertNil(requests.last?.header("Origin"))
        XCTAssertNil(requests.last?.header("X-CSRF-Token"))
        XCTAssertEqual(requests.last?.header("User-Agent")?.hasPrefix("NitroNebula-iOS/"), true)

        // A POST over the real stack carries cookie, CSRF and JSON body together.
        server.enqueue(.init(body: "{\"ok\":true}"))
        let _: OkResponse = try await client.post("logout.php")
        let post = try XCTUnwrap(server.requests.last)
        XCTAssertEqual(post.method, "POST")
        XCTAssertEqual(post.header("Cookie"), "neon_sid=abc")
        XCTAssertEqual(post.header("X-CSRF-Token"), "tok1")
        XCTAssertEqual(post.header("Content-Type"), "application/json")
        XCTAssertEqual(String(decoding: post.body, as: UTF8.self), "{}")
    }

    @MainActor func testErrorBodyMapsToAPIError() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(400, "{\"error\":\"bad_code\",\"message\":\"Game codes are 4 to 12 letters or numbers.\"}"))
        do {
            let _: OkResponse = try await client.post("games.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "bad_code")
            XCTAssertEqual(error.message, "Game codes are 4 to 12 letters or numbers.")
            XCTAssertEqual(error.status, 400)
            XCTAssertNil(error.retryAfter)
        }
    }

    @MainActor func testUnreadableServerResponseIsServerError() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(StubURLProtocol.Response(status: 500, headers: ["Content-Type": "text/html"], body: Data("<h1>Fatal error</h1>".utf8)))
        do {
            let _: OkResponse = try await client.get("leaderboard.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "server_error")
            XCTAssertEqual(error.message, "Server returned an unreadable response")
            XCTAssertEqual(error.status, 500)
        }
        // A 200 that is not the expected JSON is unreadable too (auth.js:38-42).
        StubURLProtocol.enqueue(StubURLProtocol.Response(status: 200, headers: [:], body: Data("<html>".utf8)))
        do {
            let _: OkResponse = try await client.get("leaderboard.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "server_error")
        }
    }

    @MainActor func testTransportFailureIsOffline() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.failure(URLError(.notConnectedToInternet)))
        do {
            let _: SessionResponse = try await client.get("session.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "offline")
            XCTAssertTrue(error.isOffline)
            XCTAssertEqual(error.status, 0)
        }
    }

    @MainActor func testRateLimitedCarriesRetryAfter() async throws {
        let (client, _) = NetFixtures.makeClient()
        StubURLProtocol.enqueue(.json(429, "{\"error\":\"rate_limited\",\"message\":\"Scores can only be submitted every few seconds.\"}"))
        do {
            let _: ScoreSubmitResponse = try await client.post("submit-score.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "rate_limited")
            XCTAssertTrue(error.isRateLimited)
            XCTAssertEqual(error.retryAfter, 10)
            XCTAssertEqual(error.status, 429)
        }
        // An explicit Retry-After header wins.
        StubURLProtocol.enqueue(.json(429, "{\"error\":\"rate_limited\",\"message\":\"slow down\"}", headers: ["Retry-After": "30"]))
        do {
            let _: ScoreSubmitResponse = try await client.post("submit-score.php")
            XCTFail("expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error.retryAfter, 30)
        }
    }

    // MARK: AuthService

    @MainActor func testBootstrapFallsBackToOfflineSession() async throws {
        let (client, _) = NetFixtures.makeClient()
        let auth = AuthService(client: client)
        StubURLProtocol.enqueue(.failure(URLError(.cannotConnectToHost)))
        let s = await auth.bootstrap()
        XCTAssertTrue(s.isOffline)
        XCTAssertFalse(s.loggedIn)
        XCTAssertTrue(auth.offline)
        XCTAssertTrue(auth.ready)
        XCTAssertNil(auth.user)
    }

    @MainActor func testBootstrapThenLoginUpdatesUserAndNotifies() async throws {
        let (client, _) = NetFixtures.makeClient()
        let auth = AuthService(client: client)
        var changes: [String?] = []
        auth.onAuthChange = { changes.append($0?.username) }

        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: false, csrf: "tok1")))
        let s = await auth.bootstrap()
        XCTAssertEqual(s.apiVersion, 1)
        XCTAssertEqual(auth.googleClientId, "web-client")
        XCTAssertFalse(auth.offline)

        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: true, csrf: "tok2")))
        let user = try await auth.login(usernameOrEmail: "eve", password: "pw")
        XCTAssertEqual(user?.id, 7)
        XCTAssertEqual(auth.user?.username, "eve")
        XCTAssertEqual(changes, ["eve"])

        StubURLProtocol.enqueue(.json(200, "{\"loggedIn\":false,\"user\":null,\"csrf\":\"tok3\"}"))
        try await auth.logout()
        XCTAssertNil(auth.user)
        XCTAssertEqual(changes, ["eve", nil])
        let csrf = await client.csrf
        XCTAssertEqual(csrf, "tok3")
    }

    @MainActor func testAppleSignInBodyShape() async throws {
        let (client, _) = NetFixtures.makeClient()
        let auth = AuthService(client: client)
        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: true, csrf: "tok2")))
        try await auth.appleSignIn(identityToken: "jwt", authorizationCode: "code", nonce: "raw", fullName: (given: "Eve", family: nil))
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.url.lastPathComponent, "apple.php")
        XCTAssertEqual(req.json["identityToken"] as? String, "jwt")
        XCTAssertEqual(req.json["authorizationCode"] as? String, "code")
        XCTAssertEqual(req.json["nonce"] as? String, "raw")
        let name = try XCTUnwrap(req.json["fullName"] as? [String: Any])
        XCTAssertEqual(name["givenName"] as? String, "Eve")
        XCTAssertNil(name["familyName"])
    }

    @MainActor func testGoogleAndScoreAndDeleteBodies() async throws {
        let (client, _) = NetFixtures.makeClient()
        let auth = AuthService(client: client)

        StubURLProtocol.enqueue(.json(200, NetFixtures.session(loggedIn: true, csrf: "tok2")))
        try await auth.googleSignIn(idToken: "id-token")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["credential"] as? String, "id-token")

        StubURLProtocol.enqueue(.json(200, "{\"mode\":\"easy\",\"bestScore\":500,\"improved\":true,\"rank\":3,\"leaderboard\":[{\"rank\":1,\"username\":\"x\",\"score\":900}]}"))
        let result = try await auth.submitScore(score: 500, mode: "easy")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["score"] as? Int, 500)
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["mode"] as? String, "easy")
        XCTAssertEqual(result.rank, 3)
        XCTAssertEqual(result.leaderboard.first?.username, "x")
        XCTAssertEqual(auth.user?.bestScores["easy"], 500)

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true,\"loggedIn\":false,\"user\":null,\"csrf\":\"tok9\"}"))
        try await auth.deleteAccount(password: "pw")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url.lastPathComponent, "delete-account.php")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["password"] as? String, "pw")
        XCTAssertNil(StubURLProtocol.lastRequest?.json["appleAuthorizationCode"])
        XCTAssertNil(auth.user)

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true,\"results\":{\"06_apple_sign_in.sql\":\"applied\"}}"))
        let migrations = try await auth.runMigrations()
        XCTAssertEqual(migrations.results["06_apple_sign_in.sql"], "applied")

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true,\"username\":\"bob\",\"role\":\"developer\"}"))
        let role = try await auth.setRole(username: "bob", role: "developer")
        XCTAssertEqual(role.role, "developer")
    }
}
