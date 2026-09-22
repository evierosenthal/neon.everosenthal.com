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
          skin2: \(js(config.skin2)), trail2: \(js(config.trail2)), flame2: \(js(config.flame2)) }
        """
    }

    struct OracleFrame: Decodable {
        struct Pos: Decodable { var x, y, vx, vy: Double }
        var p1: Pos?
        var p2: Pos?
        var score: Int
        var health: Int
        var hits: Int
        var deaths: Int
        var gameOver: Int?
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
        for frame in 0..<scenario.frames {
            let in1 = InputScript.pilot(frame, pilot: 0)
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
            if !ok {
                mismatches += 1
                if mismatches > 3 { break }
            }
        }
        let final = snapshot.call(withArguments: [game])!.toString()!
        let oracle = try JSONDecoder().decode(OracleFrame.self, from: Data(final.utf8))
        XCTAssertEqual(oracle.gameOver, delegate.gameOverScore, "\(scenario.name): game-over score", file: file, line: line)
        XCTAssertEqual(oracle.score, engine.state?.score, "\(scenario.name): final score", file: file, line: line)
        print("[oracle] \(scenario.name): \(scenario.frames) frames, final score \(oracle.score), health \(oracle.health), hits \(oracle.hits), gameOver \(String(describing: oracle.gameOver))")
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
}
