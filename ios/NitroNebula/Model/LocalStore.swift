import Foundation
import NeonEngine

/// The web's localStorage, on UserDefaults: same keys, same string formats
/// (ui.js:12-18, 56-65, 129-130, 164-165, 2397-2480), so a value written by
/// this app reads back through the same rules the browser applies and the
/// raw strings stay diffable against the web.
struct LocalStore {
    enum Key {
        static let highScorePrefix = "neon_nebula_highscore_"
        static let controlMode = "neon_nebula_control_mode"
        static let speed = "neon_nebula_speed"
        static let music = "neon_nebula_music"
        static let sfx = "neon_nebula_sfx"
        static let hasAccount = "neon_nebula_has_account"
        static let lastMission = "neon_nebula_last_mission"
        static let coins = "neon_nebula_coins"
        static let dailyClaim = "neon_nebula_daily_claim"
        static let skin = "neon_nebula_skin"
        static let trail = "neon_nebula_trail"
        static let flame = "neon_nebula_flame"
        static let skin2 = "neon_nebula_skin_p2"
        static let trail2 = "neon_nebula_trail_p2"
        static let flame2 = "neon_nebula_flame_p2"
        static let skinsOwned = "neon_nebula_skins_owned"
        static let trailsOwned = "neon_nebula_trails_owned"
        static let flamesOwned = "neon_nebula_flames_owned"

        static func highScore(_ mode: GameMode) -> String { highScorePrefix + mode.rawValue }

        static func equipped(_ tab: TailorTab, pilot: Int) -> String {
            switch (tab, pilot) {
            case (.skins, 2): return skin2
            case (.trails, 2): return trail2
            case (.flames, 2): return flame2
            case (.skins, _): return skin
            case (.trails, _): return trail
            case (.flames, _): return flame
            }
        }

        static func owned(_ tab: TailorTab) -> String {
            switch tab {
            case .skins: return skinsOwned
            case .trails: return trailsOwned
            case .flames: return flamesOwned
            }
        }
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Raw access (every value is a string, like localStorage)

    func string(_ key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String, for key: String) {
        defaults.set(value, forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }

    // MARK: High scores — decimal strings, `parseInt(saved, 10) || 0`

    func highScore(_ mode: GameMode) -> Int {
        guard let raw = string(Key.highScore(mode)), !raw.isEmpty else { return 0 }
        return JS.parseInt(raw) ?? 0
    }

    func setHighScore(_ mode: GameMode, _ value: Int) {
        set(String(value), for: Key.highScore(mode))
    }

    func allHighScores() -> [GameMode: Int] {
        var scores: [GameMode: Int] = [:]
        for mode in GameMode.allCases { scores[mode] = highScore(mode) }
        return scores
    }

    // MARK: Settings

    /// `mouse` / `keyboard` / `both`; anything else falls back to the iOS
    /// default (keyboard = the joystick path).
    var controlMode: ControlModePreference {
        get { string(Key.controlMode).flatMap(ControlModePreference.init(rawValue:)) ?? .keyboard }
        nonmutating set { set(newValue.rawValue, for: Key.controlMode) }
    }

    /// Rocket speed percent, 1...300, default 100 (ui.js:2450-2456).
    var speedPercent: Int {
        get {
            guard let v = string(Key.speed).flatMap(JS.parseInt), (1...300).contains(v) else { return 100 }
            return v
        }
        nonmutating set { set(String(newValue), for: Key.speed) }
    }

    /// Music volume percent, 0...100, default 100.
    var musicPercent: Int {
        get { percent(Key.music) }
        nonmutating set { set(String(newValue), for: Key.music) }
    }

    /// Sound effects volume percent, 0...100, default 100.
    var sfxPercent: Int {
        get { percent(Key.sfx) }
        nonmutating set { set(String(newValue), for: Key.sfx) }
    }

    private func percent(_ key: String) -> Int {
        guard let v = string(key).flatMap(JS.parseInt), (0...100).contains(v) else { return 100 }
        return v
    }

    /// hasAccountHistory() (ui.js:814-820): set to "1" after any login.
    var hasAccount: Bool {
        get { string(Key.hasAccount) == "1" }
        nonmutating set { if newValue { set("1", for: Key.hasAccount) } else { remove(Key.hasAccount) } }
    }

    // MARK: Last mission — `{"diff":0.62,"mode":"single"}`

    var lastMission: LastMission? {
        get {
            guard let raw = string(Key.lastMission), let data = raw.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let diff = obj["diff"] as? Double,
                  let modeRaw = obj["mode"] as? String, let mode = MissionMode(rawValue: modeRaw)
            else { return nil }
            return LastMission(diff: diff, mode: mode)
        }
        nonmutating set {
            guard let m = newValue else { remove(Key.lastMission); return }
            set("{\"diff\":\(JS.number(m.diff)),\"mode\":\"\(m.mode.rawValue)\"}", for: Key.lastMission)
        }
    }

    // MARK: Wallet

    /// `parseInt(...) || 0`.
    var coins: Int {
        get { string(Key.coins).flatMap(JS.parseInt) ?? 0 }
        nonmutating set { set(String(newValue), for: Key.coins) }
    }

    /// The `Y-M-D` stamp of the last daily claim, if any.
    var dailyClaimStamp: String? {
        get { string(Key.dailyClaim) }
        nonmutating set { if let s = newValue { set(s, for: Key.dailyClaim) } else { remove(Key.dailyClaim) } }
    }

    func dailyClaimed(now: Date = Date()) -> Bool {
        dailyClaimStamp == Economy.todayStamp(now)
    }

    /// Owned ids for a rack: a JSON array; the free item is always included
    /// (ui.js:2407-2411). Missing or empty → just the default.
    func owned(_ tab: TailorTab) -> [String] {
        let fallback = [tab.defaultID]
        guard let raw = string(Key.owned(tab)), let data = raw.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return fallback }
        var ids = arr.compactMap { $0 as? String }
        guard !ids.isEmpty else { return fallback }
        if !ids.contains(tab.defaultID) { ids.append(tab.defaultID) }
        return ids
    }

    func setOwned(_ tab: TailorTab, _ ids: [String]) {
        set(JS.stringArray(ids), for: Key.owned(tab))
    }

    /// The equipped id for a rack and pilot, validated against the catalog
    /// (ui.js:2412-2436): unknown ids fall back to the free item.
    func equipped(_ tab: TailorTab, pilot: Int) -> String {
        guard let id = string(Key.equipped(tab, pilot: pilot)), !id.isEmpty, Catalog.exists(id, in: tab)
        else { return tab.defaultID }
        return id
    }

    func loadout(pilot: Int) -> LoadoutIDs {
        LoadoutIDs(skin: equipped(.skins, pilot: pilot),
                   trail: equipped(.trails, pilot: pilot),
                   flame: equipped(.flames, pilot: pilot))
    }

    /// saveWallet() (ui.js:1620-1633): every wallet key in one go.
    func saveWallet(coins: Int, ownedSkins: [String], ownedTrails: [String], ownedFlames: [String],
                    loadout1: LoadoutIDs, loadout2: LoadoutIDs) {
        set(String(coins), for: Key.coins)
        setOwned(.skins, ownedSkins)
        set(loadout1.skin, for: Key.skin)
        setOwned(.trails, ownedTrails)
        set(loadout1.trail, for: Key.trail)
        setOwned(.flames, ownedFlames)
        set(loadout1.flame, for: Key.flame)
        set(loadout2.skin, for: Key.skin2)
        set(loadout2.trail, for: Key.trail2)
        set(loadout2.flame, for: Key.flame2)
    }
}

/// JavaScript's number/string semantics where the stored formats depend on them.
enum JS {
    /// `parseInt(s, 10)`: leading whitespace, optional sign, then digits;
    /// nil when there are none (NaN).
    static func parseInt(_ s: String) -> Int? {
        var chars = Substring(s.drop { $0.isWhitespace })
        var negative = false
        if let first = chars.first, first == "-" || first == "+" {
            negative = first == "-"
            chars = chars.dropFirst()
        }
        let digits = chars.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        return negative ? -value : value
    }

    /// `String(n)` / `JSON.stringify(n)` for a finite double: integers print
    /// without a fraction ("6"), everything else with the shortest round-trip
    /// digits ("0.62").
    static func number(_ x: Double) -> String {
        if x.isFinite, x == x.rounded(), abs(x) < 1e15 { return String(Int(x)) }
        return "\(x)"
    }

    /// `JSON.stringify(["a","b"])` — no spaces.
    static func stringArray(_ ids: [String]) -> String {
        "[" + ids.map { "\"" + escape($0) + "\"" }.joined(separator: ",") + "]"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
