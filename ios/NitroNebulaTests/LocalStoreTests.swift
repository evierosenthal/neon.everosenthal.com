import XCTest
import NeonEngine
@testable import NeonNebula

nonisolated final class LocalStoreTests: XCTestCase {
    nonisolated(unsafe) private var defaults: UserDefaults!
    nonisolated(unsafe) private var store: LocalStore!
    private let suite = "NeonNebulaTests.LocalStore"

    @MainActor override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = LocalStore(defaults: defaults)
    }

    @MainActor override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    @MainActor func testHighScoresRoundTripAsDecimalStrings() {
        for mode in GameMode.allCases { XCTAssertEqual(store.highScore(mode), 0) }
        store.setHighScore(.duoSuperHard, 12345)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_highscore_2p_super"), "12345")
        XCTAssertEqual(store.highScore(.duoSuperHard), 12345)
        defaults.set("42abc", forKey: "neon_nebula_highscore_easy") // parseInt semantics
        XCTAssertEqual(store.highScore(.easy), 42)
        defaults.set("junk", forKey: "neon_nebula_highscore_hard")
        XCTAssertEqual(store.highScore(.hard), 0)
    }

    @MainActor func testSettingsKeysAndValidation() {
        XCTAssertEqual(store.speedPercent, 100)
        XCTAssertEqual(store.musicPercent, 100)
        XCTAssertEqual(store.sfxPercent, 100)
        store.speedPercent = 250
        store.musicPercent = 0
        store.sfxPercent = 33
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_speed"), "250")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_music"), "0")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_sfx"), "33")
        XCTAssertEqual(store.musicPercent, 0)
        defaults.set("301", forKey: "neon_nebula_speed")
        XCTAssertEqual(store.speedPercent, 100)
        defaults.set("0", forKey: "neon_nebula_speed")
        XCTAssertEqual(store.speedPercent, 100)
        defaults.set("101", forKey: "neon_nebula_sfx")
        XCTAssertEqual(store.sfxPercent, 100)

        store.controlMode = .keyboard
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_control_mode"), "keyboard")
        defaults.set("bogus", forKey: "neon_nebula_control_mode")
        XCTAssertEqual(store.controlMode, .keyboard)
        defaults.set("mouse", forKey: "neon_nebula_control_mode")
        XCTAssertEqual(store.controlMode, .mouse)

        XCTAssertFalse(store.hasAccount)
        store.hasAccount = true
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_has_account"), "1")
    }

    @MainActor func testLastMissionJSONMatchesWeb() {
        XCTAssertNil(store.lastMission)
        store.lastMission = LastMission(diff: 0.62, mode: .single)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_last_mission"), "{\"diff\":0.62,\"mode\":\"single\"}")
        store.lastMission = LastMission(diff: 6.0, mode: .local)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_last_mission"), "{\"diff\":6,\"mode\":\"local\"}")
        XCTAssertEqual(store.lastMission, LastMission(diff: 6, mode: .local))
        defaults.set("{\"diff\":1.3,\"mode\":\"cpu\"}", forKey: "neon_nebula_last_mission")
        XCTAssertEqual(store.lastMission, LastMission(diff: 1.3, mode: .cpu))
        defaults.set("{\"diff\":\"x\",\"mode\":\"cpu\"}", forKey: "neon_nebula_last_mission")
        XCTAssertNil(store.lastMission)
        defaults.set("{\"diff\":1,\"mode\":\"online\"}", forKey: "neon_nebula_last_mission")
        XCTAssertNil(store.lastMission)
    }

    @MainActor func testWalletKeysAndFormats() {
        XCTAssertEqual(store.coins, 0)
        XCTAssertEqual(store.owned(.skins), ["cyan"])
        XCTAssertEqual(store.owned(.trails), ["classic"])
        XCTAssertEqual(store.owned(.flames), ["classic"])
        XCTAssertEqual(store.equipped(.skins, pilot: 1), "cyan")

        var p2 = LoadoutIDs()
        p2.skin = "rose"; p2.flame = "turbo"
        store.saveWallet(coins: 1500, ownedSkins: ["cyan", "rose"], ownedTrails: ["classic", "ember"],
                         ownedFlames: ["classic", "turbo"], loadout1: LoadoutIDs(skin: "cyan", trail: "ember", flame: "classic"),
                         loadout2: p2)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_coins"), "1500")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_skins_owned"), "[\"cyan\",\"rose\"]")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_trails_owned"), "[\"classic\",\"ember\"]")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_flames_owned"), "[\"classic\",\"turbo\"]")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_skin"), "cyan")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_trail"), "ember")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_flame"), "classic")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_skin_p2"), "rose")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_trail_p2"), "classic")
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_flame_p2"), "turbo")
        XCTAssertEqual(store.loadout(pilot: 2), p2)

        // Unknown ids fall back; the default id is always in the owned list.
        defaults.set("nope", forKey: "neon_nebula_skin")
        XCTAssertEqual(store.equipped(.skins, pilot: 1), "cyan")
        defaults.set("[\"rose\"]", forKey: "neon_nebula_skins_owned")
        XCTAssertEqual(store.owned(.skins), ["rose", "cyan"])
        defaults.set("[]", forKey: "neon_nebula_skins_owned")
        XCTAssertEqual(store.owned(.skins), ["cyan"])
        defaults.set("not json", forKey: "neon_nebula_skins_owned")
        XCTAssertEqual(store.owned(.skins), ["cyan"])
    }

    @MainActor func testDailyStampUnpadded() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 2; comps.hour = 12
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(Economy.todayStamp(date), "2026-9-2")
        store.dailyClaimStamp = Economy.todayStamp(date)
        XCTAssertEqual(defaults.string(forKey: "neon_nebula_daily_claim"), "2026-9-2")
        XCTAssertTrue(store.dailyClaimed(now: date))
        XCTAssertFalse(store.dailyClaimed(now: date.addingTimeInterval(86400)))
    }

    @MainActor func testJSHelpers() {
        XCTAssertEqual(JS.parseInt("  -12px"), -12)
        XCTAssertEqual(JS.parseInt("+7"), 7)
        XCTAssertNil(JS.parseInt("abc"))
        XCTAssertNil(JS.parseInt(""))
        XCTAssertEqual(JS.number(0.3), "0.3")
        XCTAssertEqual(JS.number(1.3), "1.3")
        XCTAssertEqual(JS.number(6), "6")
        XCTAssertEqual(JS.stringArray(["a", "b"]), "[\"a\",\"b\"]")
    }
}
