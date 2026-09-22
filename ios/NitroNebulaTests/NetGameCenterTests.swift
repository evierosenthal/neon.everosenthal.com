import Foundation
import GameKit
import NeonEngine
import XCTest
@testable import NeonNebula

nonisolated final class NetGameCenterTests: XCTestCase {
    @MainActor func testFNV1a32KnownVectors() {
        XCTAssertEqual(FNV1a.hash32(""), 0x811c9dc5)
        XCTAssertEqual(FNV1a.hash32("a"), 0xe40c292c)
        XCTAssertEqual(FNV1a.hash32("foobar"), 0xbf9cf968)
        XCTAssertEqual(FNV1a.hash32([]), FNV1a.offset32)
        // Same code, same group on both phones; different codes differ.
        XCTAssertEqual(FNV1a.hash32("neon:ABCDE"), FNV1a.hash32("neon:ABCDE"))
        XCTAssertNotEqual(FNV1a.hash32("neon:ABCDE"), FNV1a.hash32("neon:ABCDF"))
        XCTAssertEqual(Int(FNV1a.hash32("neon:ABCDE")), Int(UInt32(FNV1a.hash32("neon:ABCDE"))))
    }

    @MainActor func testRoleAttributesAreComplementary() {
        XCTAssertEqual(GameCenterService.hostAttributes ^ GameCenterService.guestAttributes, 0xFFFF_FFFF)
        XCTAssertEqual(GameCenterService.hostAttributes & GameCenterService.guestAttributes, 0)
    }

    @MainActor func testWireCodecRoundTripThroughTransportDeliverPath() async throws {
        // A bare GKMatch (no real matchmaking) is enough to host the delegate path.
        let transport = GameKitTransport(match: GKMatch())
        var received: [NetMessage] = []
        let expectation = expectation(description: "three messages on the main actor")
        expectation.expectedFulfillmentCount = 3
        transport.onReceive = { message in
            XCTAssertTrue(Thread.isMainThread)
            received.append(message)
            expectation.fulfill()
        }

        let hello = NetMessage.hello(.init(name: "eve", skin: "classic", trail: "none", flame: "blue"))
        let messages: [NetMessage] = [hello, .go, .input(dx: 0.5, dy: -1)]
        for m in messages {
            let data = try WireCodec.encode(m)
            XCTAssertEqual(transport.deliver(data), m)
        }
        // Garbage is dropped, not delivered.
        XCTAssertNil(transport.deliver(Data("nope".utf8)))

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(received, messages)
        XCTAssertTrue(transport.isOpen)
    }

    @MainActor func testTransportReportsDisconnectOnceAndCloseIsQuiet() async throws {
        let transport = GameKitTransport(match: GKMatch())
        var disconnects = 0
        let expectation = expectation(description: "one disconnect")
        transport.onDisconnect = {
            disconnects += 1
            expectation.fulfill()
        }
        transport.reportDisconnect()
        transport.reportDisconnect()
        await fulfillment(of: [expectation], timeout: 2)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(disconnects, 1)
        XCTAssertFalse(transport.isOpen)
        XCTAssertFalse(transport.send(.go))

        let quiet = GameKitTransport(match: GKMatch())
        var quietDisconnects = 0
        quiet.onDisconnect = { quietDisconnects += 1 }
        quiet.close()
        quiet.reportDisconnect()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(quietDisconnects, 0)
        XCTAssertFalse(quiet.isOpen)
    }

    // MARK: NetSession

    @MainActor func testNetSessionRoutesMessagesOverLoopback() {
        let (a, b) = LoopbackTransport.pair()
        let session = NetSession(transport: a)
        var got: [NetMessage] = []
        session.onMessage = { got.append($0) }

        XCTAssertTrue(session.send(.ready))
        a.flush()
        XCTAssertEqual(b.outbox, [])
        b.send(.go)
        b.flush()
        XCTAssertEqual(got, [.go])

        session.close()
        XCTAssertFalse(session.isOpen)
        XCTAssertFalse(session.send(.bye))
        XCTAssertFalse(a.isOpen)
    }

    @MainActor func testSnapshotWatchdogClosesWhenSnapshotsStop() async throws {
        let (a, b) = LoopbackTransport.pair()
        let session = NetSession(transport: a, snapshotTimeout: 0.15)
        var closedReason: String?
        let closed = expectation(description: "closed")
        session.onClosed = { closedReason = $0; closed.fulfill() }

        session.expectingSnapshots = true
        // A snapshot arriving keeps it alive...
        try await Task.sleep(for: .milliseconds(80))
        b.send(.snapshot(Self.snapshot(seq: 1)))
        b.flush()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(session.isOpen)
        // ...until they stop.
        await fulfillment(of: [closed], timeout: 2)
        XCTAssertEqual(closedReason, "snapshot timeout")
        XCTAssertFalse(session.isOpen)
    }

    @MainActor func testWatchdogIdleWhenNotExpectingSnapshots() async throws {
        let (a, _) = LoopbackTransport.pair()
        let session = NetSession(transport: a, snapshotTimeout: 0.05)
        var closedCount = 0
        session.onClosed = { _ in closedCount += 1 }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(session.isOpen)
        XCTAssertEqual(closedCount, 0)
    }

    private static func snapshot(seq: UInt32) -> Snapshot {
        var s = Snapshot(world: WorldSize(width: 800, height: 600), score: 0, health: 100, difficulty: 0.5,
                         dying: false, gameOver: false, shipsDestroyed: false, shake: 0, hitCount: 0,
                         effects: ActiveEffects(), p: .init(x: 1, y: 2, vx: 0, vy: 0, radius: 12), p2: nil)
        s.seq = seq
        return s
    }
}
