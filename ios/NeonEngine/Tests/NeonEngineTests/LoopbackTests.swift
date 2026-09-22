import XCTest
@testable import NeonEngine

/// Two engines wired host <-> guest through LoopbackTransport.
final class LoopbackTests: XCTestCase {
    final class Link {
        let engine: GameEngine
        let delegate: RecordingDelegate
        let transport: LoopbackTransport
        init(engine: GameEngine, delegate: RecordingDelegate, transport: LoopbackTransport) {
            self.engine = engine; self.delegate = delegate; self.transport = transport
            delegate.onSend = { [transport] m in transport.send(m) }
            transport.onReceive = { [engine] m in engine.receive(m) }
        }
    }

    func makePair(hostSeed: UInt64 = 42) -> (Link, Link) {
        let (ht, gt) = LoopbackTransport.pair()
        let (host, hd) = makeEngine({ $0.online = .host; $0.initialDifficulty = 0.62 }, rng: SeededRNG(seed: hostSeed))
        let (guest, gd) = makeEngine({ $0.online = .guest; $0.initialDifficulty = 0.62 }, rng: SeededRNG(seed: 9))
        return (Link(engine: host, delegate: hd, transport: ht), Link(engine: guest, delegate: gd, transport: gt))
    }

    func testGuestMirrorsHostFor600Ticks() {
        let (host, guest) = makePair()
        var maxLag = 0
        for frame in 0..<600 {
            host.engine.input.pilot1 = InputScript.pilot(frame, pilot: 0)
            guest.engine.input.pilot1 = InputScript.pilot(frame, pilot: 1)
            host.engine.tick()
            host.transport.flush()
            guest.engine.tick()
            guest.transport.flush()
            if frame % 3 == 2 {
                // A snapshot was built after this host tick and applied by the guest tick
                XCTAssertEqual(guest.engine.state!.score, host.engine.state!.score, "frame \(frame)")
                XCTAssertEqual(guest.engine.state!.health, host.engine.state!.health, "frame \(frame)")
                XCTAssertEqual(guest.engine.state!.player.x, GameEngine.r1(host.engine.state!.player.x), "frame \(frame)")
                XCTAssertEqual(guest.engine.state!.asteroids.count, host.engine.state!.asteroids.count, "frame \(frame)")
            }
            maxLag = max(maxLag, abs(host.engine.state!.score - guest.engine.state!.score))
        }
        XCTAssertGreaterThan(host.engine.state!.score, 0)
        XCTAssertEqual(guest.engine.state!.score, host.engine.state!.score)
        XCTAssertEqual(guest.engine.state!.health, host.engine.state!.health)
        XCTAssertEqual(guest.delegate.scores.last, host.engine.state!.score)
        XCTAssertEqual(guest.delegate.hits, host.delegate.hits)
        XCTAssertEqual(guest.engine.state!.difficulty, host.engine.state!.difficulty)
        // The guest steered ship 2 on the host
        XCTAssertNotEqual(host.engine.state!.player2!.x, 800.0 / 3 * 2)
        XCTAssertGreaterThan(guest.transport.sentCount, 5)
        XCTAssertEqual(host.transport.sentCount, 200)
        // The guest never simulates: it draws thruster sparks only
        XCTAssertEqual(guest.engine.state!.player2!.x, GameEngine.r1(host.engine.state!.player2!.x))
    }

    func testMessagesSurviveTheWireCodec() throws {
        let (host, guest) = makePair(hostSeed: 8)
        host.delegate.onSend = { [t = host.transport] m in
            t.send(try! WireCodec.decode(try! WireCodec.encode(m)))
        }
        guest.delegate.onSend = { [t = guest.transport] m in
            t.send(try! WireCodec.decode(try! WireCodec.encode(m)))
        }
        for frame in 0..<120 {
            host.engine.input.pilot1 = InputScript.pilot(frame, pilot: 0)
            guest.engine.input.pilot1 = InputScript.pilot(frame, pilot: 2)
            host.engine.tick(); host.transport.flush()
            guest.engine.tick(); guest.transport.flush()
        }
        XCTAssertEqual(guest.engine.state!.score, host.engine.state!.score)
        XCTAssertEqual(guest.engine.state!.asteroids.map(\.id), host.engine.state!.asteroids.map(\.id))
        XCTAssertEqual(host.engine.remoteInput, guest.engine.lastInput)
    }

    func testGameOverReachesTheGuest() {
        let (host, guest) = makePair()
        host.engine.clearField()
        host.engine.state!.health = 5
        _ = host.engine.addAsteroid(x: host.engine.state!.player.x, y: host.engine.state!.player.y)
        for _ in 0..<110 {
            host.engine.tick(); host.transport.flush()
            guest.engine.tick(); guest.transport.flush()
        }
        XCTAssertTrue(host.engine.state!.isGameOver)
        XCTAssertTrue(guest.engine.state!.isGameOver)
        XCTAssertEqual(guest.delegate.deaths, 1)
        XCTAssertEqual(guest.delegate.gameOverScore, host.engine.state!.score)
        XCTAssertEqual(host.delegate.gameOverScore, guest.delegate.gameOverScore)
        // Final snapshot sent exactly once, then silence
        let sentAtEnd = host.transport.sentCount
        host.engine.tick(); host.engine.tick(); host.engine.tick()
        XCTAssertEqual(host.transport.sentCount, sentAtEnd)
        XCTAssertTrue(host.engine.finalSnapshotSent)
    }
}
