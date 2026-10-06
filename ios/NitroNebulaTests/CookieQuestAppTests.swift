import XCTest
import NitroEngine
@testable import NitroNebula

/// The app side of the secret cookie quest: reward, secret skins and toast
/// (the quest itself is tested in NitroEngine).
nonisolated final class CookieQuestAppTests: XCTestCase {
    private let suite = "NitroNebulaTests.CookieQuest"

    @MainActor override func tearDown() async throws {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    @MainActor func testCompletionPaysUnlocksAndRemembers() {
        let (app, _, defaults) = AppStateFixtures.makeApp(suite: suite)
        app.coins = 120
        XCTAssertFalse(app.cookieQuestDone)
        let golden = Catalog.items(for: .skins).first { $0.id == "goldencookie" }!
        XCTAssertTrue(app.isSecretLocked(golden))

        app.engineDidCompleteQuest(app.engine)
        XCTAssertEqual(app.coins, 120, "the payout waits for flushTick")
        app.flushTick()

        XCTAssertEqual(app.coins, 1120)
        for id in AppState.secretSkinIDs { XCTAssertTrue(app.ownedSkins.contains(id), id) }
        XCTAssertTrue(app.cookieQuestDone)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_cookie_quest"), "1")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_coins"), "1120")
        XCTAssertTrue((defaults.string(forKey: "neon_nebula_skins_owned") ?? "").contains("chocochip"))
        XCTAssertEqual(app.questToast, "SECRET QUEST COMPLETE · +1,000 COINS · 3 SKINS UNLOCKED")
        XCTAssertFalse(app.isSecretLocked(golden))

        // Completing again (another device's run, say) never double-adds skins.
        app.handleQuestComplete()
        XCTAssertEqual(app.ownedSkins.filter { $0 == "cookie" }.count, 1)
        XCTAssertEqual(app.coins, 2120)
    }

    @MainActor func testFireCoinPowersApplyToTheReward() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        let jackpot = GearCatalog.flames.first { $0.power == .jackpot }!
        app.ownedFlames.append(jackpot.id)
        app.loadout1.flame = jackpot.id
        app.coins = 0
        app.handleQuestComplete()
        XCTAssertEqual(app.coins, 3000)
    }

    @MainActor func testSecretSkinsStayLockedEvenForDevelopers() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        app.session.user = APIUser(id: 1, username: "dev", role: "developer", bestScores: [:],
                                   email: nil, provider: "password", hasPassword: true)
        XCTAssertTrue(app.isDeveloper)
        let cookie = Catalog.items(for: .skins).first { $0.id == "cookie" }!
        let galaxy = Catalog.items(for: .skins).first { $0.id == "galaxy" }!
        XCTAssertTrue(app.isDevFree(galaxy))
        XCTAssertFalse(app.isDevFree(cookie))
        XCTAssertTrue(app.isSecretLocked(cookie))

        app.coins = 0
        app.tapGear(cookie)
        XCTAssertEqual(app.tailorError, "Find the secret cookie — it drifts by once a mission reaches Medium difficulty.")
        XCTAssertEqual(app.loadout1.skin, "cyan")
        XCTAssertFalse(app.ownedSkins.contains("cookie"))

        app.handleQuestComplete()
        app.tailorError = nil
        app.tapGear(cookie)
        XCTAssertNil(app.tailorError)
        XCTAssertEqual(app.loadout1.skin, "cookie")
    }

    @MainActor func testQuestMusicSwapsWithTheQuest() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        XCTAssertTrue(app.audio.questMusic.isLoaded, "cookie-quest-music.m4a is bundled")
        XCTAssertFalse(app.audio.questMusicActive)
        app.engine(app.engine, questEvent: .start, level: 1)
        XCTAssertTrue(app.audio.questMusicActive)
        app.engine(app.engine, questEvent: .levelWon, level: 1)
        XCTAssertTrue(app.audio.questMusicActive, "level banners keep the quest loop")
        app.engine(app.engine, questEvent: .failed, level: 2)
        XCTAssertFalse(app.audio.questMusicActive)

        app.engine(app.engine, questEvent: .start, level: 1)
        app.handleQuestComplete()
        XCTAssertFalse(app.audio.questMusicActive, "completion hands back to the mission loop")

        app.engine(app.engine, questEvent: .start, level: 1)
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertFalse(app.audio.questMusicActive, "a new mission always starts on the mission loop")
    }

    @MainActor func testQuestEventsToastAndClearOffMission() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        app.engine(app.engine, questEvent: .start, level: 1)
        XCTAssertEqual(app.questToast, "SECRET LEVEL FOUND · THE COOKIE QUEST BEGINS")
        app.engine(app.engine, questEvent: .levelWon, level: 1)
        XCTAssertEqual(app.questToast, "SECRET LEVEL FOUND · THE COOKIE QUEST BEGINS", "a cleared level is the canvas banner's job")
        app.engine(app.engine, questEvent: .failed, level: 2)
        XCTAssertEqual(app.questToast, "COOKIE QUEST OVER · BACK TO THE NEBULA")
        app.phase = .start
        app.sync()
        XCTAssertNil(app.questToast)
    }

    @MainActor func testLeadDevelopersGetTheCookieEarly() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertNil(app.pendingStart?.cookieSpawnFrame, "players wait the random 20–60 s")
        XCTAssertEqual(app.pendingStart?.cookieAimAtShip, false)

        app.session.user = APIUser(id: 1, username: "dev", role: "developer", bestScores: [:],
                                   email: nil, provider: "password", hasPassword: true)
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertNil(app.pendingStart?.cookieSpawnFrame, "plain developers play it straight too")

        app.session.user = APIUser(id: 2, username: "lead", role: "lead_developer", bestScores: [:],
                                   email: nil, provider: "password", hasPassword: true)
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertEqual(app.pendingStart?.cookieSpawnFrame, 180)
        XCTAssertEqual(app.pendingStart?.cookieAimAtShip, true)

        app.debugCookieSpawnFrame = 60
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertEqual(app.pendingStart?.cookieSpawnFrame, 60, "the debug hook still wins")
    }

    @MainActor func testDebugHooksReachTheEngineConfig() {
        let (app, _, _) = AppStateFixtures.makeApp(suite: suite)
        app.debugCookieSpawnFrame = 180
        app.debugCookieAimAtShip = true
        app.startGame(difficulty: 1.3, mode: .single)
        XCTAssertEqual(app.pendingStart?.cookieSpawnFrame, 180)
        XCTAssertEqual(app.pendingStart?.cookieAimAtShip, true)
    }
}
