import XCTest
@testable import NeonEngine

final class SnapshotTests: XCTestCase {
    func hostAndGuest() -> (GameEngine, GameEngine, RecordingDelegate) {
        let (host, _) = makeEngine({ $0.online = .host }, rng: SeededRNG(seed: 3))
        let (guest, gd) = makeEngine({ $0.online = .guest }, rng: SeededRNG(seed: 4))
        return (host, guest, gd)
    }

    func testRoundTripThroughApply() {
        let (host, guest, gd) = hostAndGuest()
        host.clearField()
        _ = host.addAsteroid(x: 123.456, y: 78.9, vx: 1, vy: 2)
        host.addCollectible(x: 10.04, y: 20.06)
        host.addPowerUp(x: 30, y: 40, .magnet)
        host.state!.projectiles.append(Projectile(id: "j", x: 1.26, y: 2, vx: 0, vy: -10, color: "#00ffff"))
        host.addFloatingText(x: 5, y: 6, text: "+100", color: "#fbbf24", scale: 0.95)
        host.state!.score = 420
        host.state!.health = 63
        host.state!.hitCount = 2
        host.state!.activeEffects = ActiveEffects(shield: 1, speedBoost: 2, weaponUpgrade: 3, magnet: 4)
        host.state!.player.x = 100.06; host.state!.player.vx = -2.55
        host.state!.player2!.y = 250.04
        host.shake = 12.34

        let snap = host.buildSnapshot()
        XCTAssertEqual(snap.seq, 1)
        XCTAssertEqual(snap.world, testWorld)
        XCTAssertEqual(snap.an.count, 1)
        XCTAssertEqual(snap.a[0].x, 123.5)
        XCTAssertEqual(snap.cn.count, 1)
        XCTAssertEqual(snap.un.count, 1)
        XCTAssertEqual(snap.p.x, 100.1)
        XCTAssertEqual(snap.p.vx, -2.5)                    // Math.round(-25.5) = -25
        XCTAssertEqual(snap.p2?.y, 250)
        XCTAssertEqual(snap.j[0].x, 1.3)
        XCTAssertEqual(snap.ft[0].text, "+100")
        XCTAssertEqual(snap.shake, 12.3)

        guest.applySnapshot(snap)
        let g = guest.state!
        XCTAssertEqual(g.score, 420)
        XCTAssertEqual(g.health, 63)
        XCTAssertEqual(g.hitCount, 0)                      // hitCount itself isn't mirrored; hits are
        XCTAssertEqual(g.activeEffects, host.state!.activeEffects)
        XCTAssertEqual(g.player.x, 100.1)
        XCTAssertEqual(g.player2?.y, 250)
        XCTAssertEqual(g.asteroids.count, 1)
        XCTAssertEqual(g.asteroids[0].x, 123.5)
        XCTAssertEqual(g.asteroids[0].vertices, host.state!.asteroids[0].vertices)
        XCTAssertEqual(g.collectibles[0].x, 10)
        XCTAssertEqual(g.powerUps[0].subType, .magnet)
        XCTAssertEqual(g.projectiles[0].x, 1.3)
        XCTAssertEqual(g.floatingTexts[0].text, "+100")
        XCTAssertEqual(guest.shake, 12.3)
        XCTAssertEqual(guest.lastAppliedSeq, 1)
        XCTAssertEqual(gd.scores, [420])
        XCTAssertEqual(gd.healths, [63])
        XCTAssertEqual(gd.hits, 1)                         // one onHit per snapshot that raised hc
        XCTAssertEqual(gd.difficulties.count, 1)

        // Second snapshot: entities are rows only, and unchanged score/health are not re-reported
        let snap2 = host.buildSnapshot()
        XCTAssertEqual(snap2.seq, 2)
        XCTAssertEqual(snap2.an.count, 0)
        XCTAssertEqual(snap2.a.count, 1)
        guest.applySnapshot(snap2)
        XCTAssertEqual(guest.state!.asteroids.count, 1)
        XCTAssertEqual(gd.scores, [420])
        XCTAssertEqual(gd.hits, 1)
    }

    func testSeqGuardDropsStaleSnapshots() {
        let (host, guest, _) = hostAndGuest()
        host.clearField()
        let first = host.buildSnapshot()
        var second = host.buildSnapshot()
        second.score = 999
        guest.receive(.snapshot(second))
        guest.tick()
        XCTAssertEqual(guest.state!.score, 999)
        XCTAssertEqual(guest.lastAppliedSeq, 2)
        guest.receive(.snapshot(first))
        XCTAssertNil(guest.pendingSnapshot)
        guest.tick()
        XCTAssertEqual(guest.state!.score, 999)
        // Only the newest pending snapshot is applied per tick
        var third = host.buildSnapshot(); third.score = 3
        var fourth = host.buildSnapshot(); fourth.score = 4
        guest.receive(.snapshot(third))
        guest.receive(.snapshot(fourth))
        guest.tick()
        XCTAssertEqual(guest.state!.score, 4)
    }

    func testIntroBeforeRowInSameSnapshot() {
        let (host, guest, _) = hostAndGuest()
        host.clearField()
        _ = host.addAsteroid(x: 50, y: 60)
        let snap = host.buildSnapshot()
        XCTAssertEqual(snap.an.map(\.id), snap.a.map(\.id))
        guest.applySnapshot(snap)
        XCTAssertEqual(guest.state!.asteroids.count, 1)
        XCTAssertEqual(guest.knownAsteroids.count, 1)
    }

    func testRowBeforeIntroIsSkippedUntilTheFullRecordArrives() {
        let (host, guest, _) = hostAndGuest()
        host.clearField()
        _ = host.addAsteroid(x: 50, y: 60)
        host.addCollectible(x: 1, y: 2)
        host.addPowerUp(x: 3, y: 4, .speed)
        var snap = host.buildSnapshot()
        let full = snap
        snap.an = []; snap.cn = []; snap.un = []
        guest.applySnapshot(snap)
        XCTAssertEqual(guest.state!.asteroids.count, 0)
        XCTAssertEqual(guest.state!.collectibles.count, 0)
        XCTAssertEqual(guest.state!.powerUps.count, 0)
        guest.applySnapshot(full)
        XCTAssertEqual(guest.state!.asteroids.count, 1)
        XCTAssertEqual(guest.state!.collectibles.count, 1)
        XCTAssertEqual(guest.state!.powerUps.count, 1)
    }

    func testGuestPrunesKnownEntitiesEvery300Frames() {
        let (host, guest, _) = hostAndGuest()
        host.clearField()
        _ = host.addAsteroid(x: 50, y: 60)
        guest.applySnapshot(host.buildSnapshot())      // netFrame 0: prune (harmless)
        host.state!.asteroids = []
        _ = host.addAsteroid(x: 70, y: 80)
        host.state!.asteroids[0].id = "second"
        for _ in 0..<298 { guest.applySnapshot(host.buildSnapshot()) }
        XCTAssertEqual(guest.knownAsteroids.count, 2)  // old one still remembered
        guest.applySnapshot(host.buildSnapshot())      // netFrame 299
        XCTAssertEqual(guest.knownAsteroids.count, 2)
        guest.applySnapshot(host.buildSnapshot())      // netFrame 300: prune to live
        XCTAssertEqual(guest.knownAsteroids.count, 1)
        XCTAssertEqual(guest.state!.asteroids.count, 1)
    }

    func testHostPrunesSentIdsEvery300FramesAndResends() {
        let (host, guest, _) = hostAndGuest()
        host.clearField()
        let a = host.addAsteroid(x: 50, y: 60)
        host.tick()
        for _ in 0..<299 { host.netFrame += 1 }        // as if 299 frames were sent
        host.state!.asteroids = [a]
        host.netFrame = 299
        _ = host.buildSnapshot()                       // netFrame 300 -> keeps live ids
        XCTAssertEqual(host.sentIds, [a.id])
        host.state!.asteroids = []
        host.netFrame = 599
        _ = host.buildSnapshot()
        host.netFrame = 600
        _ = host.buildSnapshot()
        XCTAssertTrue(host.sentIds.isEmpty)
        _ = guest
    }

    func testGuestDeathAndGameOverAreMirroredOnce() {
        let (host, guest, gd) = hostAndGuest()
        host.clearField()
        host.state!.health = 5
        _ = host.addAsteroid(x: host.state!.player.x, y: host.state!.player.y)
        host.updateAsteroids()
        guest.applySnapshot(host.buildSnapshot())
        XCTAssertTrue(guest.state!.dying)
        XCTAssertTrue(guest.state!.shipsDestroyed)
        XCTAssertEqual(gd.deaths, 1)
        guest.applySnapshot(host.buildSnapshot())
        XCTAssertEqual(gd.deaths, 1)
        host.state!.isGameOver = true
        host.state!.score = 77
        guest.applySnapshot(host.buildSnapshot())
        guest.applySnapshot(host.buildSnapshot())
        XCTAssertEqual(gd.gameOverScore, 77)
        XCTAssertTrue(guest.state!.isGameOver)
    }

    func testMaybeSendSnapshotEveryThirdFrameAndFinalOnce() {
        let (host, hd) = makeEngine { $0.online = .host }
        for _ in 0..<9 { host.tick() }
        XCTAssertEqual(hd.sent.count, 3)
        host.state!.isGameOver = true
        host.tick(); host.tick(); host.tick()
        XCTAssertEqual(hd.sent.count, 4)
        if case .snapshot(let s) = hd.sent.last! { XCTAssertTrue(s.gameOver) } else { XCTFail() }
    }

    func testMaybeSendInputOnChangeAndKeepAlive() {
        let (guest, gd) = makeEngine { $0.online = .guest }
        guest.tick()
        XCTAssertEqual(gd.sent, [.input(dx: 0, dy: 0)])   // first frame always sends (web: Date.now() - 0 > 250)
        guest.input.pilot1 = PilotInput(dx: 1, dy: 1)
        guest.tick()
        XCTAssertEqual(gd.sent.last, .input(dx: 0.71, dy: 0.71))
        let count = gd.sent.count
        for _ in 0..<14 { guest.tick() }                   // 14 x 16.7 = 233 ms: no keep-alive yet
        XCTAssertEqual(gd.sent.count, count)
        guest.tick()
        guest.tick()
        XCTAssertEqual(gd.sent.count, count + 1)
        guest.input.pilot1 = .zero
        guest.tick()
        XCTAssertEqual(gd.sent.last, .input(dx: 0, dy: 0))
    }

    func testHostAppliesRemoteInputToShipTwo() {
        let (host, _) = makeEngine { $0.online = .host }
        host.receive(.input(dx: 2, dy: -0.5))            // clamped to 1
        host.tick()
        XCTAssertEqual(host.state!.player2!.vx, 0.5 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(host.state!.player2!.vy, -0.25 * 0.92, accuracy: 1e-12)
        XCTAssertEqual(host.remoteInput, PilotInput(dx: 1, dy: -0.5))
    }

    func testResetNetClearsEverything() {
        let (host, hd) = makeEngine { $0.online = .host }
        defer { _ = hd } // the delegate is weak; without it no snapshot is built
        host.receive(.input(dx: 1, dy: 0))
        host.tick(); host.tick(); host.tick()
        XCTAssertFalse(host.sentIds.isEmpty)
        host.start(host.config, worldSize: testWorld)
        XCTAssertTrue(host.sentIds.isEmpty)
        XCTAssertEqual(host.netFrame, 0)
        XCTAssertEqual(host.nextSeq, 0)
        XCTAssertEqual(host.remoteInput, .zero)
    }
}
