import Foundation
import XCTest
@testable import NeonNebula

nonisolated final class NetLobbyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    static let gameJSON = """
    {"game":{"code":"ABCDE","mode":"easy","status":"open","host":"eve","guest":null,"you":"host",
             "hostOnline":true,"guestOnline":false,"hostPlatform":"ios","guestPlatform":null}}
    """

    @MainActor func testCreateSendsPlatformIOS() async throws {
        let (client, _) = NetFixtures.makeClient()
        let lobby = LobbyService(client: client)
        StubURLProtocol.enqueue(.json(200, Self.gameJSON))
        let game = try await lobby.create(code: "ABCDE", mode: "easy")
        XCTAssertEqual(game.code, "ABCDE")
        XCTAssertTrue(game.isHost)
        XCTAssertNil(game.guest)
        XCTAssertEqual(game.hostPlatform, "ios")
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.lastPathComponent, "games.php")
        XCTAssertEqual(req.json["action"] as? String, "create")
        XCTAssertEqual(req.json["code"] as? String, "ABCDE")
        XCTAssertEqual(req.json["mode"] as? String, "easy")
        XCTAssertEqual(req.json["platform"] as? String, "ios")
    }

    @MainActor func testJoinSendsPlatformIOSAndSurfacesMismatch() async throws {
        let (client, _) = NetFixtures.makeClient()
        let lobby = LobbyService(client: client)
        StubURLProtocol.enqueue(.json(200, Self.gameJSON))
        _ = try await lobby.join(code: "ABCDE")
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.json["action"] as? String, "join")
        XCTAssertEqual(req.json["platform"] as? String, "ios")

        StubURLProtocol.enqueue(.json(409, "{\"error\":\"platform_mismatch\",\"message\":\"Online play pairs app with app and web with web — your friend is on the other version.\"}"))
        do {
            _ = try await lobby.join(code: "ABCDE")
            XCTFail("expected platform_mismatch")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "platform_mismatch")
            XCTAssertEqual(error.status, 409)
        }
    }

    @MainActor func testOtherActionsAndQueries() async throws {
        let (client, _) = NetFixtures.makeClient()
        let lobby = LobbyService(client: client)

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true,\"to\":\"bob\",\"code\":\"ABCDE\"}"))
        let invite = try await lobby.invite(username: "bob", code: "ABCDE")
        XCTAssertEqual(invite.to, "bob")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["action"] as? String, "invite")
        XCTAssertNil(StubURLProtocol.lastRequest?.json["platform"])

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        _ = try await lobby.decline(id: 42)
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["action"] as? String, "decline")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["id"] as? Int, 42)

        StubURLProtocol.enqueue(.json(200, Self.gameJSON))
        let started = try await lobby.start(code: "ABCDE")
        XCTAssertEqual(started.code, "ABCDE")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["action"] as? String, "start")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["code"] as? String, "ABCDE")

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        _ = try await lobby.leave(code: "ABCDE")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["action"] as? String, "leave")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["code"] as? String, "ABCDE")

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        _ = try await lobby.finish(code: "ABCDE")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["action"] as? String, "finish")
        XCTAssertEqual(StubURLProtocol.lastRequest?.json["code"] as? String, "ABCDE")

        StubURLProtocol.enqueue(.json(200, "{\"ok\":true}"))
        _ = try await lobby.signal(code: "ABCDE", payload: .gameCenter(gamePlayerID: "A:_123"))
        let payload = try XCTUnwrap(StubURLProtocol.lastRequest?.json["payload"] as? [String: Any])
        XCTAssertEqual(payload["type"] as? String, "gc")
        XCTAssertEqual(payload["gamePlayerID"] as? String, "A:_123")

        StubURLProtocol.enqueue(.json(200, "{\"messages\":[{\"id\":5,\"payload\":{\"type\":\"gc\",\"gamePlayerID\":\"B:_9\"}}],\"status\":\"started\"}"))
        let signals = try await lobby.signals(code: "ABCDE", after: 2)
        XCTAssertEqual(StubURLProtocol.lastRequest?.method, "GET")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url.absoluteString, "http://localhost:8000/api/games.php?action=signals&after=2&code=ABCDE")
        XCTAssertNil(StubURLProtocol.lastRequest?.header("X-CSRF-Token"))
        XCTAssertEqual(signals.messages.first?.payload.gamePlayerID, "B:_9")
        XCTAssertEqual(signals.status, "started")

        StubURLProtocol.enqueue(.json(200, "{\"invites\":[{\"id\":1,\"code\":\"ZZZZ\",\"from\":\"bob\",\"mode\":\"hard\"}],\"game\":null}"))
        let inbox = try await lobby.inbox()
        XCTAssertEqual(StubURLProtocol.lastRequest?.url.absoluteString, "http://localhost:8000/api/games.php?action=inbox")
        XCTAssertEqual(inbox.invites.first?.from, "bob")
        XCTAssertNil(inbox.game)

        StubURLProtocol.enqueue(.json(200, Self.gameJSON))
        let status = try await lobby.status(code: "ABCDE")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url.absoluteString, "http://localhost:8000/api/games.php?action=status&code=ABCDE")
        XCTAssertEqual(status.status, "open")
        XCTAssertTrue(status.hostOnline)
    }

    @MainActor func testNewGameCodeAlphabetAndLength() {
        let alphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        XCTAssertEqual(alphabet.count, 32)
        for _ in 0..<200 {
            let code = LobbyService.newGameCode()
            XCTAssertEqual(code.count, 5)
            XCTAssertTrue(code.allSatisfy { alphabet.contains($0) }, code)
            XCTAssertFalse(code.contains("0") || code.contains("O") || code.contains("1") || code.contains("I"))
        }
        // Every letter of the alphabet is reachable.
        var seen = Set<Character>()
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<2000 { seen.formUnion(LobbyService.newGameCode(using: &rng)) }
        XCTAssertEqual(seen, alphabet)
    }

    @MainActor func testCleanCode() {
        XCTAssertEqual(LobbyService.cleanCode(" ab-cd 12 "), "ABCD12")
        XCTAssertEqual(LobbyService.cleanCode("abcdefghijklmnop"), "ABCDEFGHIJKL")
        XCTAssertTrue(LobbyService.isValidCode("ABCD"))
        XCTAssertFalse(LobbyService.isValidCode("ABC"))
        XCTAssertFalse(LobbyService.isValidCode("abcd"))
    }

    @MainActor func testGamePayloadDecodesWithoutPlatformFields() throws {
        let json = "{\"code\":\"AB12\",\"mode\":\"hard\",\"status\":\"started\",\"host\":\"a\",\"guest\":\"b\",\"you\":\"guest\",\"hostOnline\":true,\"guestOnline\":true}"
        let game = try JSONDecoder().decode(GamePayload.self, from: Data(json.utf8))
        XCTAssertTrue(game.isGuest)
        XCTAssertNil(game.hostPlatform)
        XCTAssertEqual(game.guest, "b")
    }
}
