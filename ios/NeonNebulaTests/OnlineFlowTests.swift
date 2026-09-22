import Foundation
import NeonEngine
import XCTest
@testable import NeonNebula

nonisolated final class OnlineFlowTests: XCTestCase {
    private let server = FakeServer()

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        server.install()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: Lobby → beginOnlineGame

    @MainActor func testGuestJoinThenStartedStatusReachesBeginOnlineGame() async {
        server.set { k in
            k.guest = "bob"
            k.guestOnline = true
            k.peerIDs = ["localhost": "peer"]
        }
        let (app, gc, _) = AppStateFixtures.makeApp(suite: "Online.guest")
        // A link with nobody on the other end: the handshake waits for hello.
        gc.link = OnlineLink(transport: DroppableTransport(LoopbackTransport()), peerPlayerID: "peer")
        app.session.user = AppStateFixtures.bobUser
        app.openFriends()
        XCTAssertEqual(app.modal, .friends)

        app.joinByCode("nebula")
        await AppStateFixtures.waitUntil { app.online != nil }
        XCTAssertEqual(gc.authenticateCalls, 1)
        XCTAssertEqual(app.online?.role, .guest)
        XCTAssertEqual(app.online?.code, "NEBULA")
        XCTAssertEqual(app.modal, .lobby)
        XCTAssertEqual(app.lobbyPhase, .wait)
        XCTAssertEqual(app.menuMode, .twoPlayer)
        let join = StubURLProtocol.requests.first { $0.json["action"] as? String == "join" }
        XCTAssertEqual(join?.json["code"] as? String, "NEBULA")
        XCTAssertEqual(join?.json["platform"] as? String, "ios")

        // The host presses START on their phone: the next poll sees it and
        // the guest goes to beginOnlineGame → connect.
        server.set { $0.gameStatus = "started" }
        await AppStateFixtures.waitUntil { app.netSession != nil }
        XCTAssertEqual(app.lobbyPhase, .connecting)
        XCTAssertEqual(app.online?.status, "started")
        XCTAssertEqual(gc.connectCalls, 1)
        XCTAssertFalse(app.isOnlineGame)
        app.leaveLobby(notifyServer: true, message: nil)
        XCTAssertNil(app.online)
        XCTAssertNil(app.modal)

        // Without a link the connect fails and the lobby reopens with the reason.
        gc.link = nil
        let game = GamePayload(code: "NEBULA", mode: "medium", status: "started", host: "eve", guest: "bob", you: "guest",
                               hostOnline: true, guestOnline: true, hostPlatform: "ios", guestPlatform: "ios")
        app.online = OnlineLobby(game: game, role: .guest)
        app.beginOnlineGame()
        await AppStateFixtures.waitUntil { app.online == nil }
        XCTAssertEqual(gc.connectCalls, 2)
        XCTAssertEqual(app.lobbyPhase, .setup)
        XCTAssertEqual(app.modal, .lobby)
        XCTAssertEqual(app.lobbySetupMessage, GameCenterService.GameCenterError.timeout.localizedDescription)
    }

    @MainActor func testHostCreateThenStartReachesBeginOnlineGame() async {
        server.set { $0.peerIDs = ["localhost": "peer"] }
        let (app, gc, _) = AppStateFixtures.makeApp(suite: "Online.host")
        // A link with nobody on the other end: the handshake waits for hello.
        gc.link = OnlineLink(transport: DroppableTransport(LoopbackTransport()), peerPlayerID: "peer")
        app.session.user = AppStateFixtures.eveUser
        app.openLobby()
        XCTAssertEqual(app.modal, .lobby)
        XCTAssertEqual(app.lobbyPhase, .setup)
        XCTAssertEqual(app.lobbyCodeField.count, 5)

        app.lobbyCodeField = "nebula"
        app.createLobby()
        await AppStateFixtures.waitUntil { app.online != nil }
        XCTAssertEqual(app.online?.role, .host)
        XCTAssertEqual(app.lobbyPhase, .wait)
        XCTAssertFalse(app.lobbyReady)
        let create = StubURLProtocol.requests.first { $0.json["action"] as? String == "create" }
        XCTAssertEqual(create?.json["code"] as? String, "NEBULA")
        XCTAssertEqual(create?.json["mode"] as? String, "medium")
        XCTAssertEqual(create?.json["platform"] as? String, "ios")

        // Pilot 2 sits down; the poll lights up START.
        server.set { k in
            k.guest = "bob"
            k.guestOnline = true
        }
        await AppStateFixtures.waitUntil(timeout: 4) { app.lobbyReady }
        XCTAssertTrue(app.lobbyReady)
        app.hostStart()
        await AppStateFixtures.waitUntil { app.lobbyPhase == .connecting }
        XCTAssertEqual(app.online?.status, "started")
        await AppStateFixtures.waitUntil { app.netSession != nil }
        XCTAssertEqual(gc.connectCalls, 1)
        XCTAssertEqual(app.lobbyPhase, .connecting)
        XCTAssertFalse(app.isOnlineGame)
        app.leaveLobby(notifyServer: false, message: nil)
        XCTAssertNil(app.online)
        XCTAssertNil(app.netSession)
        XCTAssertNil(app.modal)
    }

    @MainActor func testGameCenterGateBlocksLobbyActions() async {
        let (app, gc, _) = AppStateFixtures.makeApp(suite: "Online.gate")
        gc.authenticated = false
        app.session.user = AppStateFixtures.eveUser
        app.openLobby()
        app.lobbyCodeField = "NEBULA"
        app.createLobby()
        await AppStateFixtures.waitUntil { app.notice != nil }
        XCTAssertEqual(app.notice, AppState.gameCenterNotice)
        XCTAssertNil(app.online)
        XCTAssertFalse(StubURLProtocol.requests.contains { $0.json["action"] as? String == "create" })
    }

    @MainActor func testJoinErrorShowsServerMessage() async {
        server.set { k in
            k.joinReply = .json(409, "{\"error\":\"platform_mismatch\",\"message\":\"Online play pairs app with app and web with web — your friend is on the other version.\"}")
        }
        let (app, _, _) = AppStateFixtures.makeApp(suite: "Online.mismatch")
        app.session.user = AppStateFixtures.bobUser
        app.joinByCode("NEBULA")
        await AppStateFixtures.waitUntil { app.friendsJoinError != nil }
        XCTAssertEqual(app.friendsJoinError, "Online play pairs app with app and web with web — your friend is on the other version.")
        XCTAssertNil(app.online)
        app.joinByCode("AB")
        XCTAssertEqual(app.friendsJoinError, AppState.badCodeMessage)
    }

    // MARK: The handshake and the round

    /// Two AppStates, one lobby, a loopback link: hello/go/ready runs, both
    /// engines start in their roles and the guest mirrors the host.
    @MainActor func testHandshakeStartsBothEnginesAndGuestMirrorsHost() async {
        let (host, guest, hostLink, guestLink) = await connectPair(suite: "Online.handshake")

        XCTAssertTrue(host.isOnlineGame)
        XCTAssertTrue(guest.isOnlineGame)
        XCTAssertEqual(host.engine.config.online, .host)
        XCTAssertEqual(guest.engine.config.online, .guest)
        XCTAssertTrue(host.engine.isRunning)
        XCTAssertTrue(guest.engine.isRunning)
        XCTAssertEqual(host.phase, .playing)
        XCTAssertEqual(guest.phase, .playing)
        XCTAssertEqual(host.currentMode, .duoMedium)
        XCTAssertEqual(guest.currentMode, .duoMedium)
        XCTAssertNil(host.modal)
        XCTAssertNil(guest.modal)
        XCTAssertTrue(guest.netSession?.expectingSnapshots ?? false)
        // Each pilot flies in their own gear: the guest's skin is the host's skin2.
        XCTAssertEqual(host.engine.config.skin2?.id, guest.loadout1.skin)
        XCTAssertEqual(guest.engine.config.skin?.id, host.loadout1.skin)

        // 201 ticks so the last host tick is a snapshot tick (every 3rd).
        for _ in 0..<201 {
            host.engine.tick()
            host.flushTick()
            hostLink.flush()
            guest.engine.tick()
            guest.flushTick()
            guestLink.flush()
        }
        XCTAssertEqual(host.phase, .playing)
        XCTAssertEqual(guest.phase, .playing)
        XCTAssertEqual(guest.engine.state?.score, host.engine.state?.score)
        XCTAssertEqual(guest.engine.state?.health, host.engine.state?.health)
        XCTAssertEqual(guest.score, host.score)
        XCTAssertEqual(guest.health, host.health)
        XCTAssertEqual(guest.engine.state?.asteroids.count, host.engine.state?.asteroids.count)
        XCTAssertGreaterThan(hostLink.inner.sentCount, 60)
        XCTAssertGreaterThan(guestLink.inner.sentCount, 0)

        // Pausing is off online.
        host.setPaused(true)
        XCTAssertFalse(host.isPaused)
        host.returnToStart()
        guest.returnToStart()
    }

    @MainActor func testConnectionLossMidGameEndsRoundAsLost() async {
        let (host, guest, hostLink, guestLink) = await connectPair(suite: "Online.drop")
        for _ in 0..<30 {
            host.engine.tick(); host.flushTick(); hostLink.flush()
            guest.engine.tick(); guest.flushTick(); guestLink.flush()
        }
        XCTAssertFalse(host.connectionLost)
        hostLink.drop()
        XCTAssertEqual(host.phase, .gameOver)
        XCTAssertTrue(host.lastRoundConnectionLost)
        XCTAssertTrue(host.lastGameWasOnline)
        XCTAssertFalse(host.isOnlineGame)
        XCTAssertNil(host.online)
        XCTAssertNil(host.netSession)
        XCTAssertFalse(host.engine.isRunning)
        await AppStateFixtures.waitUntil { StubURLProtocol.requests.contains { $0.json["action"] as? String == "finish" } }
        XCTAssertTrue(StubURLProtocol.requests.contains { $0.json["action"] as? String == "finish" })

        // The guest hears `bye` the same way.
        guest.handleNetMessage(.bye)
        XCTAssertEqual(guest.phase, .gameOver)
        XCTAssertTrue(guest.lastRoundConnectionLost)
        XCTAssertFalse(guest.isOnlineGame)

        // RESTART after an online round goes back to the duo menu.
        host.restartLastMission()
        XCTAssertEqual(host.phase, .start)
        XCTAssertEqual(host.menuMode, .twoPlayer)
    }

    @MainActor func testBackgroundingEndsOnlineRoundAndLeavesLobby() async {
        let (host, guest, _, _) = await connectPair(suite: "Online.background")
        host.scenePhaseChanged(.background)
        XCTAssertEqual(host.phase, .gameOver)
        XCTAssertTrue(host.lastRoundConnectionLost)

        // A lobby that has not started is simply left.
        guest.returnToStart()
        guest.endOnlineGame()
        let game = GamePayload(code: "NEBULA", mode: "medium", status: "open", host: "eve", guest: "bob", you: "guest",
                               hostOnline: true, guestOnline: true, hostPlatform: "ios", guestPlatform: "ios")
        guest.online = OnlineLobby(game: game, role: .guest)
        guest.modal = .lobby
        guest.lobbyPhase = .wait
        StubURLProtocol.reset()
        server.install()
        guest.scenePhaseChanged(.background)
        XCTAssertNil(guest.online)
        XCTAssertNil(guest.modal)
        await AppStateFixtures.waitUntil { StubURLProtocol.requests.contains { $0.json["action"] as? String == "leave" } }
        XCTAssertTrue(StubURLProtocol.requests.contains { $0.json["action"] as? String == "leave" })
    }

    @MainActor func testWrongPeerRetriesOnceThenFails() async {
        server.set { $0.peerIDs = ["hostphone": "guest-id"] }
        let gc = FakeMatchmaking()
        gc.gamePlayerID = "host-id"
        let (a, b) = LoopbackTransport.pair()
        _ = b
        gc.link = OnlineLink(transport: DroppableTransport(a), peerPlayerID: "someone-else")
        let (host, _, _) = AppStateFixtures.makeApp(suite: "Online.wrongPeer", host: "hostphone", matchmaking: gc)
        host.session.user = AppStateFixtures.eveUser
        let game = GamePayload(code: "NEBULA", mode: "medium", status: "started", host: "eve", guest: "bob", you: "host",
                               hostOnline: true, guestOnline: true, hostPlatform: "ios", guestPlatform: "ios")
        host.online = OnlineLobby(game: game, role: .host)
        host.beginOnlineGame()
        XCTAssertEqual(host.lobbyPhase, .connecting)
        await AppStateFixtures.waitUntil(timeout: 8) { host.online == nil }
        XCTAssertEqual(gc.connectCalls, 2)
        XCTAssertNil(host.online)
        XCTAssertEqual(host.lobbySetupMessage, AppState.OnlineError.wrongPeer.errorDescription)
    }

    // MARK: Helpers

    /// Two apps in one started lobby, linked over a loopback pair, brought
    /// through hello/go/ready until both engines run.
    @MainActor
    private func connectPair(suite: String) async -> (AppState, AppState, DroppableTransport, DroppableTransport) {
        server.set { k in
            k.gameStatus = "started"
            k.guest = "bob"
            k.guestOnline = true
            k.peerIDs = ["hostphone": "guest-id", "guestphone": "host-id"]
        }
        let (a, b) = LoopbackTransport.pair()
        let hostLink = DroppableTransport(a)
        let guestLink = DroppableTransport(b)

        let hostGC = FakeMatchmaking()
        hostGC.gamePlayerID = "host-id"
        hostGC.link = OnlineLink(transport: hostLink, peerPlayerID: "guest-id")
        let guestGC = FakeMatchmaking()
        guestGC.gamePlayerID = "guest-id"
        guestGC.link = OnlineLink(transport: guestLink, peerPlayerID: "host-id")

        let (host, _, _) = AppStateFixtures.makeApp(suite: suite + ".host", host: "hostphone", matchmaking: hostGC)
        let (guest, _, _) = AppStateFixtures.makeApp(suite: suite + ".guest", host: "guestphone", matchmaking: guestGC)
        host.session.user = AppStateFixtures.eveUser
        guest.session.user = AppStateFixtures.bobUser
        host.loadout1.skin = GearCatalog.skins[1].id
        guest.loadout1.skin = GearCatalog.skins[2].id
        host.canvasDidLayout(size: CGSize(width: 800, height: 600))
        guest.canvasDidLayout(size: CGSize(width: 800, height: 600))

        let game = GamePayload(code: "NEBULA", mode: "medium", status: "started", host: "eve", guest: "bob", you: nil,
                               hostOnline: true, guestOnline: true, hostPlatform: "ios", guestPlatform: "ios")
        host.online = OnlineLobby(game: game, role: .host)
        guest.online = OnlineLobby(game: game, role: .guest)
        host.beginOnlineGame()
        guest.beginOnlineGame()

        // Once both sessions are attached, pump the loopback until both
        // sides are flying (each flush delivers the queued hello / go / ready).
        let deadline = Date().addingTimeInterval(8)
        while !(host.isOnlineGame && guest.isOnlineGame) && Date() < deadline {
            if host.netSession != nil && guest.netSession != nil {
                hostLink.flush()
                guestLink.flush()
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        hostLink.flush()
        guestLink.flush()
        return (host, guest, hostLink, guestLink)
    }
}
