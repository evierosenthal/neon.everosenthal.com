import XCTest
@testable import NeonEngine

final class WireCodecTests: XCTestCase {
    func roundTrip(_ m: NetMessage, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let data = try WireCodec.encode(m)
        let back = try WireCodec.decode(data)
        XCTAssertEqual(back, m, file: file, line: line)
        return data
    }

    func testSimpleMessages() throws {
        XCTAssertEqual(try roundTrip(.go).count, 1)
        XCTAssertEqual(try roundTrip(.ready).count, 1)
        XCTAssertEqual(try roundTrip(.bye).count, 1)
        _ = try roundTrip(.hello(NetMessage.Hello(name: "Eve ✨", skin: "galaxy", trail: "rainbow", flame: "moneystorm")))
        _ = try roundTrip(.hello(NetMessage.Hello(name: "", skin: "", trail: "", flame: "")))
    }

    func testInputKeepsTwoDecimals() throws {
        _ = try roundTrip(.input(dx: 0.71, dy: -0.71))
        _ = try roundTrip(.input(dx: 1, dy: 0))
        _ = try roundTrip(.input(dx: -0.33, dy: 0.94))
    }

    func testSnapshotRoundTrip() throws {
        let (host, _) = makeEngine({ $0.online = .host; $0.initialDifficulty = 0.62 }, rng: SeededRNG(seed: 11))
        // Fill every list with real engine output
        for _ in 0..<120 { host.input.pilot1 = InputScript.pilot(host.tickCount, pilot: 0); host.tick() }
        host.state!.difficulty = 0.62345678901
        host.state!.projectiles.append(Projectile(id: "j", x: 12.3, y: 45.6, vx: 0, vy: -10, color: "#fb7185"))
        host.addFloatingText(x: 1, y: 2, text: "-25% HULL DAMAGE", color: "#ff0000", scale: 1.25)
        host.state!.floatingTexts[host.state!.floatingTexts.count - 1].alpha = 0.7
        host.addPowerUp(x: 3.33, y: 4.44, .magnet)
        host.shake = 22 * 0.9 * 0.9
        host.state!.health = 63
        host.state!.hitCount = 3
        host.sentIds = []
        let snap = host.buildSnapshot()
        XCTAssertFalse(snap.an.isEmpty)
        XCTAssertFalse(snap.cn.isEmpty || snap.c.isEmpty)
        XCTAssertFalse(snap.pt.isEmpty)
        XCTAssertFalse(snap.j.isEmpty)
        XCTAssertFalse(snap.ft.isEmpty)
        XCTAssertNotNil(snap.p2)
        let data = try roundTrip(.snapshot(snap))
        let json = try JSONEncoder().encode(snap)
        XCTAssertLessThan(data.count, json.count / 2, "binary \(data.count) vs json \(json.count)")
    }

    func testSnapshotWithoutPlayerTwoAndNegativeValues() throws {
        var snap = Snapshot(world: WorldSize(width: 393, height: 852), score: -5, health: -15, difficulty: 8,
                            dying: true, gameOver: true, shipsDestroyed: true, shake: 0.1, hitCount: 0,
                            effects: ActiveEffects(shield: 0, speedBoost: 1000, weaponUpgrade: 2000, magnet: 600),
                            p: Snapshot.PackedPlayer(x: -12.3, y: 0, vx: -9.9, vy: 10, radius: 21.8), p2: nil)
        snap.seq = UInt32.max
        snap.a = [Snapshot.AsteroidRow(id: "zz", x: -99.9, y: 700.1, rotation: -6.283)]
        snap.pt = [Snapshot.ParticleRow(x: 0.1, y: 0.2, radius: 6.5, color: "hsl(226.4, 80%, 55%)", life: 3, maxLife: 45)]
        snap.ft = [Snapshot.TextRow(x: 400.5, y: 200, text: "HULL DESTROYED", color: "#ff0000", alpha: 0.3, scale: 1.4)]
        _ = try roundTrip(.snapshot(snap))
    }

    func testMalformedDataThrows() {
        XCTAssertThrowsError(try WireCodec.decode(Data()))
        XCTAssertThrowsError(try WireCodec.decode(Data([99])))
        XCTAssertThrowsError(try WireCodec.decode(Data([6, 1, 2])))
        XCTAssertThrowsError(try WireCodec.decode(Data([1, 5, 0, 0x41])))   // string length past the end
        var d = try! WireCodec.encode(.input(dx: 1, dy: 0))
        d.removeLast()
        XCTAssertThrowsError(try WireCodec.decode(d))
    }

    func testTagLayout() throws {
        XCTAssertEqual(try WireCodec.encode(.go).first, 2)
        XCTAssertEqual(try WireCodec.encode(.input(dx: 0, dy: 0)).count, 1 + 16)
        let hello = try WireCodec.encode(.hello(NetMessage.Hello(name: "ab", skin: "c", trail: "", flame: "d")))
        XCTAssertEqual(Array(hello), [1, 2, 0, 0x61, 0x62, 1, 0, 0x63, 0, 0, 1, 0, 0x64])
    }
}
