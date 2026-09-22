import Foundation

/// Binary encoding of NetMessage for GameKit. Little-endian throughout:
///
///   UInt8 tag (1 hello, 2 go, 3 ready, 4 bye, 5 input, 6 snapshot)
///   strings: UInt16 byte length + UTF-8
///   Int32 for counts / scores / lives / effect frames
///   Float32 for the per-frame rows (positions, velocities, radii, alpha,
///     scale, rotation) — the host already rounds those to 0.1 (r1) or
///     0.001 (rotation), so the decoder re-rounds and gets the host's exact
///     doubles back (Float32 carries ~7 digits; more than enough for a
///     four-digit coordinate with one decimal).
///   Float64 for values that are not rounded (difficulty, world size, input
///     steering, and the full entity records that travel once).
///
/// A JSON snapshot on the web is 5-10 KB; this is roughly a fifth of that.
public enum WireCodec {
    public enum CodecError: Error { case malformed, tooLong }

    enum Tag: UInt8 { case hello = 1, go, ready, bye, input, snapshot }

    public static func encode(_ message: NetMessage) throws -> Data {
        var w = ByteWriter()
        switch message {
        case .hello(let h):
            w.u8(Tag.hello.rawValue)
            try w.str(h.name); try w.str(h.skin); try w.str(h.trail); try w.str(h.flame)
        case .go: w.u8(Tag.go.rawValue)
        case .ready: w.u8(Tag.ready.rawValue)
        case .bye: w.u8(Tag.bye.rawValue)
        case .input(let dx, let dy):
            w.u8(Tag.input.rawValue)
            w.f64(dx); w.f64(dy)
        case .snapshot(let s):
            w.u8(Tag.snapshot.rawValue)
            try encodeSnapshot(s, into: &w)
        }
        return w.data
    }

    public static func decode(_ data: Data) throws -> NetMessage {
        var r = ByteReader(data)
        guard let tag = Tag(rawValue: try r.u8()) else { throw CodecError.malformed }
        switch tag {
        case .hello:
            return .hello(NetMessage.Hello(name: try r.str(), skin: try r.str(), trail: try r.str(), flame: try r.str()))
        case .go: return .go
        case .ready: return .ready
        case .bye: return .bye
        case .input:
            return .input(dx: try r.f64(), dy: try r.f64())
        case .snapshot:
            return .snapshot(try decodeSnapshot(&r))
        }
    }

    // MARK: Snapshot

    /// Rounded row values: Float32 on the wire, re-rounded on decode.
    private static func r1(_ v: Float) -> Double { jsRound(Double(v) * 10) / 10 }
    private static func r2(_ v: Float) -> Double { jsRound(Double(v) * 100) / 100 }
    private static func r3(_ v: Float) -> Double { jsRound(Double(v) * 1000) / 1000 }

    private static func encodeSnapshot(_ s: Snapshot, into w: inout ByteWriter) throws {
        w.u32(s.seq)
        w.f64(s.world.width); w.f64(s.world.height)
        try w.i32(s.score)
        w.f32(s.health)
        w.f64(s.difficulty)
        w.u8((s.dying ? 1 : 0) | (s.gameOver ? 2 : 0) | (s.shipsDestroyed ? 4 : 0))
        w.f32(s.shake)
        try w.i32(s.hitCount)
        try w.i32(s.effects.shield); try w.i32(s.effects.speedBoost)
        try w.i32(s.effects.weaponUpgrade); try w.i32(s.effects.magnet)
        packed(s.p, &w)
        if let p2 = s.p2 { w.u8(1); packed(p2, &w) } else { w.u8(0) }

        try w.i32(s.a.count)
        for row in s.a { try w.str(row.id); w.f32(row.x); w.f32(row.y); w.f32(row.rotation) }
        try w.i32(s.an.count)
        for a in s.an { try asteroid(a, &w) }
        try w.i32(s.c.count)
        for row in s.c { try w.str(row.id); w.f32(row.x); w.f32(row.y) }
        try w.i32(s.cn.count)
        for c in s.cn { try collectible(c, &w) }
        try w.i32(s.u.count)
        for row in s.u { try w.str(row.id); w.f32(row.x); w.f32(row.y); try w.i32(row.life) }
        try w.i32(s.un.count)
        for u in s.un { try powerUp(u, &w) }
        try w.i32(s.j.count)
        for row in s.j { w.f32(row.x); w.f32(row.y); w.f32(row.radius); try w.str(row.color.css) }
        try w.i32(s.pt.count)
        for row in s.pt {
            w.f32(row.x); w.f32(row.y); w.f32(row.radius); try w.str(row.color.css)
            try w.i32(row.life); try w.i32(row.maxLife)
        }
        try w.i32(s.ft.count)
        for row in s.ft {
            w.f32(row.x); w.f32(row.y); try w.str(row.text); try w.str(row.color.css)
            w.f32(row.alpha); w.f32(row.scale)
        }
    }

    private static func decodeSnapshot(_ r: inout ByteReader) throws -> Snapshot {
        let seq = try r.u32()
        let world = WorldSize(width: try r.f64(), height: try r.f64())
        let score = try r.i32()
        let health = r1(try r.f32())
        let difficulty = try r.f64()
        let flags = try r.u8()
        let shake = r1(try r.f32())
        let hitCount = try r.i32()
        let effects = ActiveEffects(shield: try r.i32(), speedBoost: try r.i32(),
                                    weaponUpgrade: try r.i32(), magnet: try r.i32())
        let p = try packed(&r)
        let p2: Snapshot.PackedPlayer? = try r.u8() == 1 ? try packed(&r) : nil
        var s = Snapshot(world: world, score: score, health: health, difficulty: difficulty,
                         dying: flags & 1 != 0, gameOver: flags & 2 != 0, shipsDestroyed: flags & 4 != 0,
                         shake: shake, hitCount: hitCount, effects: effects, p: p, p2: p2)
        s.seq = seq

        for _ in 0..<(try r.count()) {
            s.a.append(Snapshot.AsteroidRow(id: try r.str(), x: r1(try r.f32()), y: r1(try r.f32()), rotation: r3(try r.f32())))
        }
        for _ in 0..<(try r.count()) { s.an.append(try asteroid(&r)) }
        for _ in 0..<(try r.count()) {
            s.c.append(Snapshot.CollectibleRow(id: try r.str(), x: r1(try r.f32()), y: r1(try r.f32())))
        }
        for _ in 0..<(try r.count()) { s.cn.append(try collectible(&r)) }
        for _ in 0..<(try r.count()) {
            s.u.append(Snapshot.PowerUpRow(id: try r.str(), x: r1(try r.f32()), y: r1(try r.f32()), life: try r.i32()))
        }
        for _ in 0..<(try r.count()) { s.un.append(try powerUp(&r)) }
        for _ in 0..<(try r.count()) {
            s.j.append(Snapshot.ProjectileRow(x: r1(try r.f32()), y: r1(try r.f32()), radius: r1(try r.f32()),
                                              color: CSSColor(try r.str())))
        }
        for _ in 0..<(try r.count()) {
            s.pt.append(Snapshot.ParticleRow(x: r1(try r.f32()), y: r1(try r.f32()), radius: r1(try r.f32()),
                                             color: CSSColor(try r.str()), life: try r.i32(), maxLife: try r.i32()))
        }
        for _ in 0..<(try r.count()) {
            s.ft.append(Snapshot.TextRow(x: r1(try r.f32()), y: r1(try r.f32()), text: try r.str(),
                                         color: CSSColor(try r.str()), alpha: r1(try r.f32()), scale: r2(try r.f32())))
        }
        return s
    }

    private static func packed(_ p: Snapshot.PackedPlayer, _ w: inout ByteWriter) {
        w.f32(p.x); w.f32(p.y); w.f32(p.vx); w.f32(p.vy); w.f32(p.radius)
    }
    private static func packed(_ r: inout ByteReader) throws -> Snapshot.PackedPlayer {
        Snapshot.PackedPlayer(x: r1(try r.f32()), y: r1(try r.f32()), vx: r1(try r.f32()), vy: r1(try r.f32()), radius: r1(try r.f32()))
    }

    // Full records: raw doubles, sent once per entity.

    private static func asteroid(_ a: Asteroid, _ w: inout ByteWriter) throws {
        try w.str(a.id)
        w.f64(a.x); w.f64(a.y); w.f64(a.vx); w.f64(a.vy); w.f64(a.radius)
        try w.str(a.color.css); try w.str(a.style.rawValue); try w.str(a.tint.rawValue)
        try w.i32(a.vertices.count)
        for v in a.vertices { w.f64(v) }
        try w.i32(a.craters.count)
        for c in a.craters { w.f64(c.rx); w.f64(c.ry); w.f64(c.r); w.f64(c.rot) }
        try w.i32(a.speckles.count)
        for sp in a.speckles { w.f64(sp.rx); w.f64(sp.ry); w.f64(sp.r) }
        w.f64(a.rotation); w.f64(a.spinSpeed)
    }
    private static func asteroid(_ r: inout ByteReader) throws -> Asteroid {
        let id = try r.str()
        let x = try r.f64(), y = try r.f64(), vx = try r.f64(), vy = try r.f64(), radius = try r.f64()
        let color = CSSColor(try r.str())
        guard let style = AsteroidStyle(rawValue: try r.str()), let tint = AsteroidTint(rawValue: try r.str()) else {
            throw CodecError.malformed
        }
        var vertices: [Double] = []
        for _ in 0..<(try r.count()) { vertices.append(try r.f64()) }
        var craters: [Crater] = []
        for _ in 0..<(try r.count()) {
            craters.append(Crater(rx: try r.f64(), ry: try r.f64(), r: try r.f64(), rot: try r.f64()))
        }
        var speckles: [Speckle] = []
        for _ in 0..<(try r.count()) {
            speckles.append(Speckle(rx: try r.f64(), ry: try r.f64(), r: try r.f64()))
        }
        let rotation = try r.f64(), spinSpeed = try r.f64()
        return Asteroid(id: id, x: x, y: y, vx: vx, vy: vy, radius: radius, color: color, style: style, tint: tint,
                        vertices: vertices, craters: craters, speckles: speckles, rotation: rotation, spinSpeed: spinSpeed)
    }

    private static func collectible(_ c: Collectible, _ w: inout ByteWriter) throws {
        try w.str(c.id)
        w.f64(c.x); w.f64(c.y); w.f64(c.vx); w.f64(c.vy); w.f64(c.radius)
        try w.str(c.color.css); try w.str(c.kind.rawValue)
        try w.i32(c.sprinkles.count)
        for sp in c.sprinkles { w.f64(sp.a); w.f64(sp.d); w.f64(sp.rot); try w.str(sp.color.css) }
    }
    private static func collectible(_ r: inout ByteReader) throws -> Collectible {
        let id = try r.str()
        let x = try r.f64(), y = try r.f64(), vx = try r.f64(), vy = try r.f64(), radius = try r.f64()
        let color = CSSColor(try r.str())
        guard let kind = CollectibleKind(rawValue: try r.str()) else { throw CodecError.malformed }
        var sprinkles: [Sprinkle] = []
        for _ in 0..<(try r.count()) {
            sprinkles.append(Sprinkle(a: try r.f64(), d: try r.f64(), rot: try r.f64(), color: CSSColor(try r.str())))
        }
        var c = Collectible(id: id, x: x, y: y, vx: vx, vy: vy, color: color, kind: kind, sprinkles: sprinkles)
        c.radius = radius
        return c
    }

    private static func powerUp(_ u: PowerUp, _ w: inout ByteWriter) throws {
        try w.str(u.id)
        w.f64(u.x); w.f64(u.y); w.f64(u.vx); w.f64(u.vy); w.f64(u.radius)
        try w.str(u.color.css); try w.i32(u.life); try w.i32(u.maxLife); try w.str(u.subType.rawValue)
    }
    private static func powerUp(_ r: inout ByteReader) throws -> PowerUp {
        let id = try r.str()
        let x = try r.f64(), y = try r.f64(), vx = try r.f64(), vy = try r.f64(), radius = try r.f64()
        let color = CSSColor(try r.str())
        let life = try r.i32(), maxLife = try r.i32()
        guard let subType = PowerUpType(rawValue: try r.str()) else { throw CodecError.malformed }
        var u = PowerUp(id: id, x: x, y: y, vx: vx, vy: vy, life: life, maxLife: maxLife, subType: subType)
        u.radius = radius
        u.color = color
        return u
    }
}

// MARK: - Byte helpers (little-endian)

struct ByteWriter {
    var data = Data()

    mutating func u8(_ v: UInt8) { data.append(v) }
    mutating func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    mutating func i32(_ v: Int) throws {
        guard let v32 = Int32(exactly: v) else { throw WireCodec.CodecError.tooLong }
        withUnsafeBytes(of: v32.littleEndian) { data.append(contentsOf: $0) }
    }
    mutating func f32(_ v: Double) { withUnsafeBytes(of: Float(v).bitPattern.littleEndian) { data.append(contentsOf: $0) } }
    mutating func f64(_ v: Double) { withUnsafeBytes(of: v.bitPattern.littleEndian) { data.append(contentsOf: $0) } }
    mutating func str(_ s: String) throws {
        let bytes = Array(s.utf8)
        guard bytes.count <= Int(UInt16.max) else { throw WireCodec.CodecError.tooLong }
        withUnsafeBytes(of: UInt16(bytes.count).littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: bytes)
    }
}

struct ByteReader {
    private let bytes: [UInt8]
    private var pos = 0

    init(_ data: Data) { bytes = Array(data) }

    private mutating func take(_ n: Int) throws -> ArraySlice<UInt8> {
        guard n >= 0, pos + n <= bytes.count else { throw WireCodec.CodecError.malformed }
        defer { pos += n }
        return bytes[pos..<(pos + n)]
    }
    private mutating func load<T: FixedWidthInteger>(_: T.Type) throws -> T {
        let slice = try take(MemoryLayout<T>.size)
        var v: T = 0
        withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: slice) }
        return T(littleEndian: v)
    }

    mutating func u8() throws -> UInt8 { try load(UInt8.self) }
    mutating func u32() throws -> UInt32 { try load(UInt32.self) }
    mutating func i32() throws -> Int { Int(try load(Int32.self)) }
    /// A non-negative Int32 element count.
    mutating func count() throws -> Int {
        let n = try i32()
        guard n >= 0 else { throw WireCodec.CodecError.malformed }
        return n
    }
    mutating func f32() throws -> Float { Float(bitPattern: try load(UInt32.self)) }
    mutating func f64() throws -> Double { Double(bitPattern: try load(UInt64.self)) }
    mutating func str() throws -> String {
        let n = Int(try load(UInt16.self))
        guard let s = String(bytes: try take(n), encoding: .utf8) else { throw WireCodec.CodecError.malformed }
        return s
    }
}
