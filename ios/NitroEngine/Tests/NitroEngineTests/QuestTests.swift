import XCTest
@testable import NitroEngine

/// The secret cookie quest (Quest.swift): the random-call contract of
/// start(), the burnt-cookie scoring rule, the difficulty freeze and the
/// phase machine's bookkeeping. Frame-for-frame behaviour against game.js
/// is covered by OracleParityTests.testCookieQuest*Parity.
final class QuestTests: XCTestCase {

    /// Math.random() calls consumed by start() for a config.
    private func randomsInStart(_ configure: (inout GameConfig) -> Void) -> Int {
        let (engine, _) = makeEngine(configure, rng: ConstantRNG(0.5))
        return engine.rngCalls
    }

    /// game.js:670-680 — only a local Hard run draws the cookie spawn frame,
    /// after the stars, so every other mode's sequence is untouched.
    func testOnlyHardRunsDrawTheCookieSpawnFrame() {
        let easy = randomsInStart { $0.initialDifficulty = 0.3 }
        let medium = randomsInStart { $0.initialDifficulty = 0.62 }
        let hard = randomsInStart { $0.initialDifficulty = 1.3 }
        let hardHooked = randomsInStart { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 300 }
        let superHard = randomsInStart { $0.initialDifficulty = 6.0 }
        let onlineHard = randomsInStart { $0.initialDifficulty = 1.3; $0.online = .host }
        XCTAssertEqual(easy, 2 + GameConstants.starCount * 3, "initial orb vx/vy + 3 per star")
        XCTAssertEqual(medium, easy)
        XCTAssertEqual(superHard, easy)
        XCTAssertEqual(onlineHard, easy)
        XCTAssertEqual(hardHooked, easy, "the cookieSpawnFrame hook replaces the draw")
        XCTAssertEqual(hard, easy + 1)
    }

    func testCookieSpawnFrameRangeAndHook() {
        let (hard, _) = makeEngine({ $0.initialDifficulty = 1.3 }, rng: ConstantRNG(0.999))
        XCTAssertEqual(hard.state?.cookieSpawnFrame, 1200 + Int((0.999 * 2401).rounded(.down)))
        let (low, _) = makeEngine({ $0.initialDifficulty = 1.3 }, rng: ConstantRNG(0))
        XCTAssertEqual(low.state?.cookieSpawnFrame, 1200)
        let (hooked, _) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 42 }
        XCTAssertEqual(hooked.state?.cookieSpawnFrame, 42)
        let (easy, _) = makeEngine { $0.initialDifficulty = 0.3 }
        XCTAssertEqual(easy.state?.cookieSpawnFrame, -1)
        let (online, _) = makeEngine { $0.initialDifficulty = 1.3; $0.online = .host }
        XCTAssertEqual(online.state?.cookieSpawnFrame, -1)
        XCTAssertEqual(hooked.state?.frame, 0)
        XCTAssertNil(hooked.state?.cookie)
        XCTAssertNil(hooked.state?.quest)
    }

    /// game.js:1231-1240 — a burnt cookie leaving the screen pays nothing;
    /// a regular asteroid pays the usual +10.
    func testBurntCookieLeavingTheScreenPaysNothing() {
        let (engine, delegate) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 100_000 }
        engine.clearField()
        var burnt = engine.createCrumb(x: 400, y: testWorld.height + 95, angle: Double.pi / 2)
        burnt.vy = 10
        engine.state!.asteroids.append(burnt)
        engine.tick()
        XCTAssertEqual(engine.state?.score, 0)
        XCTAssertFalse(engine.state!.asteroids.contains { $0.style == .burnt })
        XCTAssertTrue(delegate.scores.isEmpty)

        engine.clearField()
        _ = engine.addAsteroid(x: 400, y: testWorld.height + 95, vy: 10)
        engine.tick()
        XCTAssertEqual(engine.state?.score, 10)
        XCTAssertEqual(delegate.scores, [10])
    }

    func testBurntCookieFactoriesAreBurntAsteroids() {
        let (engine, _) = makeEngine({ $0.initialDifficulty = 1.3 }, rng: ConstantRNG(0.5))
        let before = engine.rngCalls
        let burnt = engine.createBurntCookie(width: 800, height: 600)
        XCTAssertEqual(engine.rngCalls - before, 17, "radius, x, vx, vy, rotation, spin, 10 vertices, id")
        XCTAssertEqual(burnt.style, .burnt)
        XCTAssertEqual(burnt.tint, .burnt)
        XCTAssertEqual(burnt.vertices.count, 10)
        XCTAssertTrue(burnt.craters.isEmpty)
        XCTAssertTrue(burnt.speckles.isEmpty)
        XCTAssertEqual(burnt.y, -40)
        XCTAssertEqual(burnt.color, "#3b2314")

        let mid = engine.rngCalls
        let crumb = engine.createCrumb(x: 10, y: 20, angle: 0)
        XCTAssertEqual(engine.rngCalls - mid, 1, "only the id")
        XCTAssertEqual(crumb.vertices, GameConstants.crumbVertices)
        XCTAssertEqual(crumb.radius, 9)
        XCTAssertEqual(crumb.vx, 3.2)
        XCTAssertEqual(crumb.vy, 0)
        XCTAssertEqual(crumb.spinSpeed, 0.04)

        let c0 = engine.rngCalls
        _ = engine.createQuestCookie(width: 800)
        XCTAssertEqual(engine.rngCalls - c0, 6, "x, vx, vy, rotation, spin, id")
        let d0 = engine.rngCalls
        let cookie = engine.createDriftingCookie(width: 800, height: 600)
        XCTAssertEqual(engine.rngCalls - d0, 3, "side, y, wobble")
        XCTAssertEqual(cookie.id, "secret_cookie")
        XCTAssertEqual(cookie.radius, 11)
    }

    /// The cookie aimed at the still ship is caught, the field is wiped and
    /// difficulty stops growing until the quest is over (game.js:1683).
    func testDifficultyIsFrozenDuringAQuest() {
        let (engine, delegate) = makeEngine {
            $0.initialDifficulty = 1.3
            $0.controlModePreference = .keyboard
            $0.cookieSpawnFrame = 5
            $0.cookieAimAtShip = true
        }
        var caughtAt = -1
        for frame in 0..<600 {
            engine.tick()
            if engine.state?.quest != nil { caughtAt = frame; break }
        }
        XCTAssertGreaterThan(caughtAt, 5, "the still ship caught the cookie aimed at it")
        XCTAssertEqual(engine.state?.quest?.level, 1)
        XCTAssertEqual(engine.state?.quest?.phase, .intro)
        XCTAssertEqual(engine.state?.quest?.phaseTimer, 120)
        XCTAssertTrue(engine.state!.asteroids.isEmpty, "field wiped on the catch")
        XCTAssertTrue(engine.state!.powerUps.isEmpty)
        XCTAssertNil(engine.state?.cookie)
        XCTAssertEqual(delegate.questEvents, ["start:1"])

        let frozen = engine.state!.difficulty
        let reports = delegate.difficulties.count
        for _ in 0..<300 { engine.tick() }
        XCTAssertEqual(engine.state?.quest?.phase, .play)
        XCTAssertEqual(engine.state!.difficulty, frozen)
        XCTAssertEqual(delegate.difficulties.count, reports, "no difficulty report during the quest")
        XCTAssertGreaterThan(engine.state!.activeEffects.weaponUpgrade, 0, "blasters granted for the level")
    }

    private func installQuest(_ engine: GameEngine, level: Int, phase: QuestPhase, phaseTimer: Int = 120,
                              goal: Int, collected: Int, boss: QuestBoss? = nil) {
        engine.clearField()
        engine.state!.quest = QuestState(level: level, phase: phase, phaseTimer: phaseTimer, timer: 50, goal: goal,
                                         collected: collected,
                                         cookies: [QuestCookie(id: "q", x: 100, y: 100, vx: 0, vy: 1, rotation: 0, spin: 0)],
                                         boss: boss)
    }

    /// game.js:1400-1406, 1467-1476 — won banner, then the next level's
    /// intro with its own goal and an empty basket.
    func testQuestLevelWonResetsGoalAndCollected() {
        let (engine, delegate) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 100_000 }
        installQuest(engine, level: 1, phase: .play, goal: 10, collected: 10,
                     boss: QuestBoss(x: 1, y: 1, vx: 0, vy: 0, hp: 3, maxHp: 36))
        engine.questLevelWon()
        XCTAssertEqual(engine.state?.quest?.phase, .won)
        XCTAssertEqual(engine.state?.quest?.phaseTimer, 120)
        XCTAssertNil(engine.state?.quest?.boss)
        XCTAssertEqual(delegate.questEvents, ["levelWon:1"])

        for _ in 0..<119 { engine.tick() }
        XCTAssertEqual(engine.state?.quest?.phase, .won)
        engine.tick()
        XCTAssertEqual(engine.state?.quest?.level, 2)
        XCTAssertEqual(engine.state?.quest?.phase, .intro)
        XCTAssertEqual(engine.state?.quest?.phaseTimer, 120)
        XCTAssertEqual(engine.state?.quest?.timer, 0)
        XCTAssertEqual(engine.state?.quest?.goal, GameConstants.questLevels[1].goal)
        XCTAssertEqual(engine.state?.quest?.collected, 0)
        XCTAssertEqual(engine.state?.quest?.cookies.count, 0)
        XCTAssertEqual(delegate.questCompletes, 0)
    }

    /// game.js:1477-1484 — level 3's won banner turns into the 180-frame
    /// 'complete' banner, firing onQuestComplete exactly once; the quest
    /// then ends and the run resumes.
    func testQuestCompleteFiresOnce() {
        let (engine, delegate) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 100_000 }
        installQuest(engine, level: 3, phase: .won, phaseTimer: 1, goal: 1, collected: 0)
        engine.tick()
        XCTAssertEqual(engine.state?.quest?.phase, .complete)
        XCTAssertEqual(engine.state?.quest?.phaseTimer, 180)
        XCTAssertEqual(delegate.questCompletes, 1)
        for _ in 0..<179 { engine.tick() }
        XCTAssertEqual(engine.state?.quest?.phase, .complete)
        engine.tick()
        XCTAssertNil(engine.state?.quest)
        XCTAssertEqual(delegate.questCompletes, 1)
        for _ in 0..<60 { engine.tick() }
        XCTAssertEqual(delegate.questCompletes, 1)
        XCTAssertTrue(delegate.questEvents.isEmpty)
        XCTAssertGreaterThan(delegate.difficulties.count, 0, "difficulty growth resumes after the quest")
    }

    /// game.js:1408-1414, 1485 — the level clock runs out: failed banner,
    /// then back to the nebula.
    func testQuestFailedEndsTheQuest() {
        let (engine, delegate) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 100_000 }
        installQuest(engine, level: 2, phase: .play, goal: 15, collected: 3)
        engine.state!.quest!.timer = GameConstants.questLevels[1].duration - 1
        engine.tick()
        XCTAssertEqual(engine.state?.quest?.phase, .failed)
        XCTAssertEqual(delegate.questEvents, ["failed:2"])
        for _ in 0..<120 { engine.tick() }
        XCTAssertNil(engine.state?.quest)
        XCTAssertEqual(delegate.questCompletes, 0)
    }

    func testDebugPositionsCarryQuestTelemetry() {
        let (engine, _) = makeEngine { $0.initialDifficulty = 1.3; $0.cookieSpawnFrame = 7 }
        XCTAssertEqual(engine.debugPositions?.cookieSpawnFrame, 7)
        XCTAssertNil(engine.debugPositions?.quest)
        installQuest(engine, level: 3, phase: .play, goal: 1, collected: 0,
                     boss: QuestBoss(x: 400.04, y: 168.06, vx: 2.2, vy: 1.3, hp: 36, maxHp: 36))
        let d = engine.debugPositions!
        XCTAssertEqual(d.quest, GameEngine.DebugPositions.Quest(level: 3, phase: .play, collected: 0, timer: 50, bossHp: 36))
        XCTAssertEqual(d.boss, GameEngine.DebugPositions.Boss(x: 400, y: 168.1, vx: 2.2, vy: 1.3, hp: 36))
        XCTAssertEqual(d.questCookies, [GameEngine.DebugPositions.Point(x: 100, y: 100)])
        XCTAssertEqual(d.asteroids, [])
    }
}
