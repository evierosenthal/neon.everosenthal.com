import XCTest
import JavaScriptCore
@testable import NitroEngine

/// Runs the real www/game.js inside JavaScriptCore with a seeded Math.random
/// and a frame-driven Date.now, drives it with synthetic key events, and
/// checks the Swift engine reproduces the same ship positions, velocities,
/// score and health frame by frame. The JavaScript is the truth.
final class OracleParityTests: XCTestCase {

    struct Scenario {
        var name: String
        var frames = 1200
        var seed: UInt64 = 42
        /// Pilot 1 steering computed from the Swift engine's telemetry
        /// (the positions after the previous frame) and fed to both sims as
        /// the same arrow keys; nil uses the fixed InputScript.
        var input: ((GameEngine.DebugPositions) -> PilotInput)? = nil
        /// Ends the run early once true (checked after each frame's comparison).
        var stopWhen: ((GameEngine.DebugPositions, RecordingDelegate) -> Bool)? = nil
        var configure: (inout GameConfig) -> Void
    }

    // MARK: Harness

    static func gameJSURL() -> URL {
        // .../ios/NitroEngine/Tests/NitroEngineTests/OracleParityTests.swift -> repo root
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() } // file, NitroEngineTests, Tests, NitroEngine, ios
        return url.appendingPathComponent("www/game.js")
    }

    /// A JSContext with the browser stubs and game.js loaded.
    func loadOracle() throws -> JSContext {
        let gameURL = OracleParityTests.gameJSURL()
        guard FileManager.default.fileExists(atPath: gameURL.path) else {
            throw XCTSkip("www/game.js not found at \(gameURL.path)")
        }
        let gameSource = try String(contentsOf: gameURL, encoding: .utf8)
        guard let harnessURL = Bundle.module.url(forResource: "oracle_harness", withExtension: "js", subdirectory: "Fixtures") else {
            XCTFail("oracle_harness.js fixture missing"); throw XCTSkip("fixture missing")
        }
        let harness = try String(contentsOf: harnessURL, encoding: .utf8)

        let context = JSContext()!
        var exceptions: [String] = []
        context.exceptionHandler = { _, value in
            exceptions.append(value?.toString() ?? "unknown")
        }
        context.evaluateScript(harness, withSourceURL: harnessURL)
        context.evaluateScript(gameSource, withSourceURL: gameURL)
        XCTAssertTrue(exceptions.isEmpty, "JS exceptions while loading: \(exceptions)")
        XCTAssertFalse(context.evaluateScript("typeof NeonNebula.createGame").toString() != "function", "game.js did not export createGame")
        return context
    }

    /// JSON for a gear struct (Codable keys match the ui.js field names).
    func js<T: Encodable>(_ value: T?) -> String {
        guard let v = value, let data = try? JSONEncoder().encode(v) else { return "null" }
        return String(data: data, encoding: .utf8)!
    }

    func startOptions(_ config: GameConfig) -> String {
        return """
        { initialDifficulty: \(config.initialDifficulty),
          isLocalMultiplayer: \(config.isLocalMultiplayer), isCPUMultiplayer: \(config.isCPUMultiplayer),
          controlModePreference: '\(config.controlModePreference.rawValue)',
          skin: \(js(config.skin)), trail: \(js(config.trail)), flame: \(js(config.flame)),
          skin2: \(js(config.skin2)), trail2: \(js(config.trail2)), flame2: \(js(config.flame2)),
          cookieSpawnFrame: \(config.cookieSpawnFrame.map(String.init) ?? "undefined"),
          cookieAimAtShip: \(config.cookieAimAtShip),
          questBossHP: \(config.questBossHP.map(String.init) ?? "undefined") }
        """
    }

    struct OracleFrame: Decodable {
        struct Pos: Decodable { var x, y, vx, vy: Double }
        struct Pt: Decodable { var x, y: Double }
        struct Quest: Decodable { var level: Int; var phase: String; var collected: Int; var timer: Int; var bossHp: Int? }
        struct Boss: Decodable { var x, y, vx, vy: Double; var hp: Int }
        struct Ast: Decodable { var x, y, vx, vy, r: Double; var style: String }
        var p1: Pos?
        var p2: Pos?
        var score: Int
        var health: Int
        var hits: Int
        var deaths: Int
        var gameOver: Int?
        // Secret cookie quest telemetry + callbacks
        var frame: Int
        var cookieSpawnFrame: Int
        var cookie: Pt?
        var quest: Quest?
        var questCookies: [Pt]
        var boss: Boss?
        struct SunPt: Decodable { var x, y, vx, vy: Double }
        var suns: [SunPt]
        struct Orb: Decodable { var x, y: Double; var type: String }
        var weapon: Int
        var powerUps: [Orb]
        var asteroids: [Ast]
        var questComplete: Int
        var questEvents: [String]
    }

    /// Press/release the keys for a steering vector. Solo/CPU: arrows; local
    /// 2P: WASD for pilot 1 and arrows for pilot 2 (game.js:527-530, 637-640).
    func setKeys(_ context: JSContext, _ input: PilotInput, wasd: Bool) {
        let set = context.objectForKeyedSubscript("__setKey")!
        func key(_ arrow: String, _ letter: String, _ code: String, _ down: Bool) {
            if wasd { set.call(withArguments: [letter, code, down]) }
            else { set.call(withArguments: [arrow, arrow, down]) }
        }
        key("ArrowRight", "d", "KeyD", input.dx > 0)
        key("ArrowLeft", "a", "KeyA", input.dx < 0)
        key("ArrowUp", "w", "KeyW", input.dy < 0)
        key("ArrowDown", "s", "KeyS", input.dy > 0)
    }

    func run(_ scenario: Scenario, file: StaticString = #filePath, line: UInt = #line) throws {
        let context = try loadOracle()
        var config = GameConfig()
        scenario.configure(&config)

        // JavaScript side
        context.evaluateScript("__rng.seed(\(scenario.seed)); __frame = 0;")
        context.evaluateScript("var game = NeonNebula.createGame(canvas, __callbacks);")
        context.evaluateScript("game.start(\(startOptions(config)));")
        let step = context.objectForKeyedSubscript("__step")!
        let snapshot = context.objectForKeyedSubscript("__snapshot")!
        let game = context.objectForKeyedSubscript("game")!

        // Swift side
        let engine = GameEngine(rng: SeededRNG(seed: scenario.seed))
        let delegate = RecordingDelegate()
        engine.delegate = delegate
        engine.start(config, worldSize: testWorld)

        var lastScore = 0, lastHealth = 100
        var mismatches = 0
        var framesRun = 0
        for frame in 0..<scenario.frames {
            let in1 = scenario.input.map { $0(engine.debugPositions!) } ?? InputScript.pilot(frame, pilot: 0)
            let in2 = InputScript.pilot(frame, pilot: 1)
            setKeys(context, in1, wasd: config.isLocalMultiplayer)
            if config.isLocalMultiplayer { setKeys(context, in2, wasd: false) }
            step.call(withArguments: [frame])
            let json = snapshot.call(withArguments: [game])!.toString()!
            let oracle = try JSONDecoder().decode(OracleFrame.self, from: Data(json.utf8))

            engine.input.pilot1 = in1
            engine.input.pilot2 = config.isLocalMultiplayer ? in2 : .zero
            engine.tick()
            let mine = engine.debugPositions!
            if let s = delegate.scores.last { lastScore = s }
            if let h = delegate.healths.last { lastHealth = h }

            func same(_ a: OracleFrame.Pos?, _ b: (x: Double, y: Double, vx: Double, vy: Double)?, _ label: String) -> Bool {
                switch (a, b) {
                case (nil, nil): return true
                case let (o?, m?):
                    let ok = abs(o.x - m.x) <= 0.1 && abs(o.y - m.y) <= 0.1 && abs(o.vx - m.vx) <= 0.01 && abs(o.vy - m.vy) <= 0.01
                    if !ok {
                        XCTFail("\(scenario.name) frame \(frame) \(label): js=(\(o.x), \(o.y), \(o.vx), \(o.vy)) swift=(\(m.x), \(m.y), \(m.vx), \(m.vy))", file: file, line: line)
                    }
                    return ok
                default:
                    XCTFail("\(scenario.name) frame \(frame) \(label): presence differs", file: file, line: line)
                    return false
                }
            }
            var ok = same(oracle.p1, mine.p1, "p1")
            ok = same(oracle.p2, mine.p2, "p2") && ok
            if oracle.score != lastScore || oracle.health != lastHealth {
                XCTFail("\(scenario.name) frame \(frame): js score/health \(oracle.score)/\(oracle.health) swift \(lastScore)/\(lastHealth)", file: file, line: line)
                ok = false
            }
            if oracle.hits != delegate.hits || oracle.deaths != delegate.deaths {
                XCTFail("\(scenario.name) frame \(frame): js hits/deaths \(oracle.hits)/\(oracle.deaths) swift \(delegate.hits)/\(delegate.deaths)", file: file, line: line)
                ok = false
            }
            ok = sameQuest(oracle, mine, delegate, "\(scenario.name) frame \(frame)", file: file, line: line) && ok
            if !ok {
                mismatches += 1
                if mismatches > 3 { break }
            }
            framesRun = frame + 1
            if let stop = scenario.stopWhen, stop(mine, delegate) { break }
        }
        let final = snapshot.call(withArguments: [game])!.toString()!
        let oracle = try JSONDecoder().decode(OracleFrame.self, from: Data(final.utf8))
        XCTAssertEqual(oracle.gameOver, delegate.gameOverScore, "\(scenario.name): game-over score", file: file, line: line)
        XCTAssertEqual(oracle.score, engine.state?.score, "\(scenario.name): final score", file: file, line: line)
        XCTAssertEqual(oracle.questComplete, delegate.questCompletes, "\(scenario.name): onQuestComplete count", file: file, line: line)
        XCTAssertEqual(oracle.questEvents, delegate.questEvents, "\(scenario.name): quest events", file: file, line: line)
        print("[oracle] \(scenario.name): \(framesRun) frames, final score \(oracle.score), health \(oracle.health), hits \(oracle.hits), gameOver \(String(describing: oracle.gameOver)), quest events \(oracle.questEvents)")
    }

    /// The cookie quest telemetry: quest level/phase/collected/timer/bossHp,
    /// the drifting cookie, the boss, the quest cookies and the asteroids
    /// (positions to 0.1 like p1/p2), plus the callback counts so far.
    func sameQuest(_ o: OracleFrame, _ m: GameEngine.DebugPositions, _ d: RecordingDelegate, _ tag: String,
                   file: StaticString, line: UInt) -> Bool {
        var ok = true
        func fail(_ msg: String) { XCTFail("\(tag): \(msg)", file: file, line: line); ok = false }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= 0.1 }
        if o.frame != m.frame || o.cookieSpawnFrame != m.cookieSpawnFrame {
            fail("frame/cookieSpawnFrame js \(o.frame)/\(o.cookieSpawnFrame) swift \(m.frame)/\(m.cookieSpawnFrame)")
        }
        switch (o.cookie, m.cookie) {
        case (nil, nil): break
        case let (a?, b?): if !near(a.x, b.x) || !near(a.y, b.y) { fail("cookie js (\(a.x), \(a.y)) swift (\(b.x), \(b.y))") }
        default: fail("cookie presence js \(o.cookie != nil) swift \(m.cookie != nil)")
        }
        switch (o.quest, m.quest) {
        case (nil, nil): break
        case let (a?, b?):
            if a.level != b.level || a.phase != b.phase.rawValue || a.collected != b.collected || a.timer != b.timer || a.bossHp != b.bossHp {
                fail("quest js \(a.level)/\(a.phase)/\(a.collected)/\(a.timer)/\(String(describing: a.bossHp)) swift \(b.level)/\(b.phase.rawValue)/\(b.collected)/\(b.timer)/\(String(describing: b.bossHp))")
            }
        default: fail("quest presence js \(o.quest != nil) swift \(m.quest != nil)")
        }
        switch (o.boss, m.boss) {
        case (nil, nil): break
        case let (a?, b?):
            if !near(a.x, b.x) || !near(a.y, b.y) || !near(a.vx, b.vx) || !near(a.vy, b.vy) || a.hp != b.hp {
                fail("boss js (\(a.x), \(a.y), \(a.vx), \(a.vy), hp \(a.hp)) swift (\(b.x), \(b.y), \(b.vx), \(b.vy), hp \(b.hp))")
            }
        default: fail("boss presence js \(o.boss != nil) swift \(m.boss != nil)")
        }
        if o.questCookies.count != m.questCookies.count {
            fail("quest cookie count js \(o.questCookies.count) swift \(m.questCookies.count)")
        } else {
            for (i, (a, b)) in zip(o.questCookies, m.questCookies).enumerated() where !near(a.x, b.x) || !near(a.y, b.y) {
                fail("quest cookie \(i) js (\(a.x), \(a.y)) swift (\(b.x), \(b.y))")
                break
            }
        }
        if o.weapon != m.weapon { fail("weaponUpgrade js \(o.weapon) swift \(m.weapon)") }
        if o.powerUps.count != m.powerUps.count {
            fail("power-up count js \(o.powerUps.count) swift \(m.powerUps.count)")
        } else {
            for (i, (a, b)) in zip(o.powerUps, m.powerUps).enumerated() where !near(a.x, b.x) || !near(a.y, b.y) || a.type != b.type.rawValue {
                fail("power-up \(i) js (\(a.x), \(a.y), \(a.type)) swift (\(b.x), \(b.y), \(b.type.rawValue))")
                break
            }
        }
        if o.suns.count != m.suns.count {
            fail("sun count js \(o.suns.count) swift \(m.suns.count)")
        } else {
            for (i, (a, b)) in zip(o.suns, m.suns).enumerated() where !near(a.x, b.x) || !near(a.y, b.y) {
                fail("sun \(i) js (\(a.x), \(a.y)) swift (\(b.x), \(b.y))")
                break
            }
        }
        if o.asteroids.count != m.asteroids.count {
            fail("asteroid count js \(o.asteroids.count) swift \(m.asteroids.count)")
        } else {
            for (i, (a, b)) in zip(o.asteroids, m.asteroids).enumerated()
            where !near(a.x, b.x) || !near(a.y, b.y) || !near(a.vx, b.vx) || !near(a.vy, b.vy) || !near(a.r, b.r) || a.style != b.style.rawValue {
                fail("asteroid \(i) js (\(a.x), \(a.y), \(a.vx), \(a.vy), r \(a.r), \(a.style)) swift (\(b.x), \(b.y), \(b.vx), \(b.vy), r \(b.r), \(b.style.rawValue))")
                break
            }
        }
        if o.questComplete != d.questCompletes || o.questEvents != d.questEvents {
            fail("quest callbacks js \(o.questComplete) \(o.questEvents) swift \(d.questCompletes) \(d.questEvents)")
        }
        return ok
    }

    // MARK: RNG agreement

    func testSeededRNGMatchesJavaScriptGenerator() throws {
        let context = try loadOracle()
        context.evaluateScript("__rng.seed(42);")
        let jsValues = context.evaluateScript("(function(){ var a=[]; for (var i=0;i<20;i++) a.push(Math.random()); return a; })()")!
            .toArray()!.map { ($0 as! NSNumber).doubleValue }
        var rng = SeededRNG(seed: 42)
        let swiftValues = (0..<20).map { _ in rng.next() }
        XCTAssertEqual(jsValues, swiftValues)
        XCTAssertTrue(swiftValues.allSatisfy { $0 >= 0 && $0 < 1 })
        XCTAssertEqual(Set(swiftValues).count, 20)
    }

    // MARK: Scenarios

    func testSoloKeyboardParity() throws {
        try run(Scenario(name: "solo bouncy+pulse") { c in
            c.initialDifficulty = 0.62
            c.controlModePreference = .keyboard
            c.skin = GearCatalog.skin(id: "ice")
            c.trail = GearCatalog.trail(id: "pulse")
            c.flame = GearCatalog.flame(id: "bouncyblast")
        })
    }

    func testSoloStockGearParity() throws {
        try run(Scenario(name: "solo stock", seed: 7) { c in
            c.initialDifficulty = 1.3
            c.controlModePreference = .keyboard
        })
    }

    func testCPUMultiplayerParity() throws {
        try run(Scenario(name: "cpu turbo+rainbow", seed: 99) { c in
            c.initialDifficulty = 0.62
            c.isCPUMultiplayer = true
            c.controlModePreference = .keyboard
            c.trail = GearCatalog.trail(id: "rainbow")
            c.flame = GearCatalog.flame(id: "turbo")
            c.flame2 = GearCatalog.flame(id: "pocketrocket")
        })
    }

    func testLocalMultiplayerParity() throws {
        try run(Scenario(name: "local wobble+ironforge", seed: 2024) { c in
            c.initialDifficulty = 1.3
            c.isLocalMultiplayer = true
            c.flame = GearCatalog.flame(id: "wobblesmoke")
            c.trail2 = GearCatalog.trail(id: "comet")
            c.flame2 = GearCatalog.flame(id: "ironforge")
        })
    }

    /// Depends on the game.js fix that moved the second magnet decrement
    /// after updateCollectibles() (game.js:1226-1233); the Swift port always
    /// has it. If the web file is ever reverted this scenario diverges.
    func testMagnetMuzzleParity() throws {
        try run(Scenario(name: "solo magnetmuzzle", seed: 5) { c in
            c.initialDifficulty = 0.3
            c.controlModePreference = .keyboard
            c.flame = GearCatalog.flame(id: "magnetmuzzle")
        })
    }

    func testSuperHardMultiSpawnParity() throws {
        try run(Scenario(name: "solo super hard", frames: 900, seed: 3) { c in
            c.initialDifficulty = 6.0
            c.controlModePreference = .keyboard
            c.flame = GearCatalog.flame(id: "megaburner")
        })
    }

    // MARK: Secret cookie quest

    /// The cookie is aimed at the ship, which dodges and intercepts it: catch
    /// -> level 1 intro -> 1800-frame play phase among the Hard asteroids,
    /// dodging cookies -> "TIME'S UP" banner -> the normal Hard run resumes
    /// (www/tests/cookie-quest.jsc.js "fail path").
    func testCookieQuestFailParity() throws {
        let delegateRef = RecordingDelegateBox()
        var framesSinceEnd = 0
        try run(Scenario(name: "cookie quest fail", frames: 2700, seed: 8,
                         input: OracleParityTests.cookieQuestFailSteering,
                         stopWhen: { positions, delegate in
                             delegateRef.delegate = delegate
                             // 60 frames after the "TIME'S UP" banner ends; the
                             // resumed Hard run is not under test here.
                             if delegate.questEvents.contains("failed:1") && positions.quest == nil { framesSinceEnd += 1 }
                             return framesSinceEnd > 60
                         }) { c in
            c.initialDifficulty = 1.3
            c.controlModePreference = .keyboard
            c.cookieSpawnFrame = 120
            c.cookieAimAtShip = true
        })
        let delegate = try XCTUnwrap(delegateRef.delegate)
        XCTAssertEqual(delegate.questEvents, ["start:1", "failed:1"])
        XCTAssertEqual(delegate.questCompletes, 0)
        XCTAssertNil(delegate.gameOverScore, "ship survived through the quest")
    }

    typealias ShipPos = (x: Double, y: Double, vx: Double, vy: Double)

    /// safeSpot from www/tests/cookie-quest.jsc.js: the spot (lane x, one of
    /// three rows around `rowY`) with the least predicted danger along the
    /// path there and while holding it, pulled toward `wantX` / `rowY`, kept
    /// off the side walls, and (fail path) pushed away from raining cookies.
    static func safeSpot(_ d: GameEngine.DebugPositions, p: ShipPos, wantX: Double,
                         rowY: Double, avoidCookies: Bool) -> (x: Double, y: Double) {
        func pathDanger(_ ox: Double, _ oy: Double, _ ovx: Double, _ ovy: Double, _ oradius: Double,
                        _ lane: Double, _ row: Double) -> Double {
            let travel = max(abs(lane - p.x), abs(row - p.y)) / 7
            var closest = Double.infinity
            for k in 0...6 {
                let frac = Double(k) / 6
                let sx = p.x + (lane - p.x) * frac, sy = p.y + (row - p.y) * frac, t = travel * frac
                let ddx = ox + ovx * t - sx, ddy = oy + ovy * t - sy
                let dist = (ddx * ddx + ddy * ddy).squareRoot() - oradius - 15
                if dist < closest { closest = dist }
            }
            var t2 = travel
            while t2 <= 60 {
                let hdx = ox + ovx * t2 - lane, hdy = oy + ovy * t2 - row
                let hdist = (hdx * hdx + hdy * hdy).squareRoot() - oradius - 15
                if hdist < closest { closest = hdist }
                t2 += 6
            }
            return closest
        }
        let rows = [rowY - 60, rowY, rowY + 60].map { max(140, min(560, $0)) }
        var best = (x: p.x, y: rowY), bestDanger = Double.infinity
        var lane = 100.0
        while lane <= 700 {
            for row in rows {
                var danger = abs(lane - wantX) / 150 + abs(row - rowY) / 120
                if lane <= 140 || lane >= 660 { danger += 0.8 } // no cornering against a wall
                for a in d.asteroids {
                    let c = pathDanger(a.x, a.y, a.vx, a.vy, a.r, lane, row)
                    if c < 70 { danger += 3 * (70 - c) / 70 }
                }
                if let boss = d.boss {
                    // The jar: a bump costs as much hull as any hit
                    let bc = pathDanger(boss.x, boss.y, boss.vx, boss.vy, 58, lane, row)
                    if bc < 90 { danger += 4 * (90 - bc) / 90 }
                }
                for sun in d.suns {
                    // Lethal: keep a wide berth from where it will be
                    let sc = pathDanger(sun.x, sun.y, sun.vx, sun.vy, 14, lane, row)
                    if sc < 110 { danger += 8 * (110 - sc) / 110 }
                }
                if avoidCookies {
                    for c in d.questCookies where c.y < row && abs(c.x - lane) < 50 { danger += 1.5 }
                }
                if danger < bestDanger { bestDanger = danger; best = (x: lane, y: row) }
            }
            lane += 40
        }
        return best
    }

    /// preQuestTarget: dodge while waiting, intercept the drifting cookie.
    static func preQuestTarget(_ d: GameEngine.DebugPositions, p: ShipPos) -> (x: Double, y: Double) {
        if let c = d.cookie { return safeSpot(d, p: p, wantX: c.x, rowY: c.y, avoidCookies: false) }
        return safeSpot(d, p: p, wantX: 400, rowY: 300, avoidCookies: false)
    }

    /// steer(dx, dy): a key is held past a 6 px dead zone.
    static func keys(dx: Double, dy: Double) -> PilotInput {
        let dead = 6.0
        return PilotInput(dx: dx > dead ? 1 : (dx < -dead ? -1 : 0), dy: dy > dead ? 1 : (dy < -dead ? -1 : 0))
    }

    /// The "fail path" steering of www/tests/cookie-quest.jsc.js: dodge and
    /// intercept the cookie, then keep to the safest lane while avoiding
    /// cookies so level 1 times out.
    static func cookieQuestFailSteering(_ d: GameEngine.DebugPositions) -> PilotInput {
        let p = d.p1!
        let target: (x: Double, y: Double) = d.quest != nil
            ? safeSpot(d, p: p, wantX: p.x, rowY: 330, avoidCookies: true)
            : preQuestTarget(d, p: p)
        return keys(dx: target.x - p.x, dy: target.y - p.y)
    }

    /// The "complete path" steering of www/tests/cookie-quest.jsc.js: levels
    /// 1-2 head for the nearest cookie above (the Magnet Muzzle drags them
    /// in) along the safest lane; level 3 shadows the jar from 150 px below,
    /// offset 34 px so the straight-down crumb misses, and lets the blasters
    /// work.
    static func cookieQuestSteering(_ d: GameEngine.DebugPositions) -> PilotInput {
        let p = d.p1!
        var dx = 0.0, dy = 0.0
        if let q = d.quest, q.phase == .play, let boss = d.boss {
            let spot: (x: Double, y: Double)
            let hunter = d.suns.first { sn in
                let hdx = sn.x - p.x, hdy = sn.y - p.y
                return (hdx * hdx + hdy * hdy).squareRoot() < 170 && (sn.vx * hdx + sn.vy * hdy) < 0 // closing in
            }
            if let hunter {
                // A sun is bearing down on us: run straight away from it first
                let away = atan2(p.y - hunter.y, p.x - hunter.x)
                spot = safeSpot(d, p: p, wantX: max(100, min(700, p.x + cos(away) * 240)),
                                rowY: max(140, min(560, p.y + sin(away) * 240)), avoidCookies: false)
            } else if d.weapon <= 0, let orb = d.powerUps.first(where: { $0.type == .weapon }) {
                // Unarmed: go and grab the W orb first
                spot = (safeSpot(d, p: p, wantX: orb.x, rowY: orb.y, avoidCookies: false).x, orb.y)
            } else if boss.y < 330 {
                // Armed and the jar is high: shadow it from ~170 px below
                spot = safeSpot(d, p: p, wantX: boss.x + 30, rowY: min(boss.y + 170, 500), avoidCookies: false)
            } else {
                // The jar has dived low: back off on our own side at mid height
                spot = safeSpot(d, p: p, wantX: p.x < boss.x ? 160 : 640, rowY: 440, avoidCookies: false)
            }
            dx = spot.x - p.x
            dy = spot.y - p.y
        } else if let q = d.quest, q.phase == .play {
            var wantX = 400.0, ty = 330.0, best = Double.infinity
            for c in d.questCookies {
                let dist = abs(c.x - p.x) + abs(c.y - p.y)
                if c.y < p.y + 40 && dist < best { best = dist; wantX = c.x; ty = max(c.y + 60, 200) }
            }
            let lv = safeSpot(d, p: p, wantX: wantX, rowY: ty, avoidCookies: false)
            dx = lv.x - p.x
            dy = lv.y - p.y
        } else if d.quest == nil {
            let pre = preQuestTarget(d, p: p)
            dx = pre.x - p.x
            dy = pre.y - p.y
        }
        return keys(dx: dx, dy: dy)
    }

    /// The whole quest at full difficulty, both engines in lock-step until
    /// the ship dies or the quest ends. The Cookie Jar at full strength is
    /// beyond the scripted pilot, so this run asserts parity through the
    /// fight (suns, hunter, shots, orbs) rather than victory.
    func testCookieJarFightParity() throws {
        let delegateRef = RecordingDelegateBox()
        try run(Scenario(name: "cookie jar fight", frames: 9000, seed: 2,
                         input: OracleParityTests.cookieQuestSteering,
                         stopWhen: { positions, delegate in
                             delegateRef.delegate = delegate
                             return delegate.gameOverScore != nil || (delegate.questCompletes == 1 && positions.quest == nil)
                         }) { c in
            c.initialDifficulty = 1.3
            c.controlModePreference = .keyboard
            c.flame = GearCatalog.flames.first { $0.power == .magnet }
            c.cookieSpawnFrame = 120
            c.cookieAimAtShip = true
        })
        let delegate = try XCTUnwrap(delegateRef.delegate)
        XCTAssertTrue(delegate.questEvents.contains("levelWon:2"), "the pilot reaches the Cookie Jar: \(delegate.questEvents)")
    }

    /// The quest's ending, end to end on both engines: with the Giant
    /// Cookie's hit points overridden to 3 (the `questBossHP` test hook) the
    /// pilot grabs the W orb and cracks it before the suns arm, and the run
    /// stops when the 'complete' banner ends, 180 frames after
    /// engineDidCompleteQuest.
    func testCookieQuestCompleteParity() throws {
        let delegateRef = RecordingDelegateBox()
        try run(Scenario(name: "cookie quest complete", frames: 9000, seed: 2,
                         input: OracleParityTests.cookieQuestSteering,
                         stopWhen: { positions, delegate in
                             delegateRef.delegate = delegate
                             return delegate.gameOverScore != nil || (delegate.questCompletes == 1 && positions.quest == nil)
                         }) { c in
            c.initialDifficulty = 1.3
            c.controlModePreference = .keyboard
            c.flame = GearCatalog.flames.first { $0.power == .magnet }
            c.cookieSpawnFrame = 120
            c.cookieAimAtShip = true
            c.questBossHP = 3
        })
        let delegate = try XCTUnwrap(delegateRef.delegate)
        XCTAssertEqual(delegate.questCompletes, 1, "engineDidCompleteQuest fired once")
        XCTAssertEqual(delegate.questEvents, ["start:1", "levelWon:1", "levelWon:2", "levelWon:3"])
        XCTAssertNil(delegate.gameOverScore, "ship survived the complete path")
    }

    /// Lets a scenario's stopWhen hand the recording delegate back to the test.
    final class RecordingDelegateBox { var delegate: RecordingDelegate? }
}
