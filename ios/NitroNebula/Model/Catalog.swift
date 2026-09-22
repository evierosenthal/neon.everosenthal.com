import Foundation
import NitroEngine

/// The Tailor's three racks (ui.js:305, 1578-1611, 977-993) as the UI sees
/// them: thin wrappers over `GearCatalog` plus the wallet rules.
enum TailorTab: String, CaseIterable, Sendable, Hashable {
    case skins, trails, flames

    var title: String {
        switch self {
        case .skins: return "ROCKET SKINS"
        case .trails: return "TRAILS"
        case .flames: return "FIRE"
        }
    }

    /// The loadout chip's kind label (index.php:244-252).
    var chipKind: String {
        switch self {
        case .skins: return "Skin"
        case .trails: return "Trail"
        case .flames: return "Fire"
        }
    }

    var defaultID: String {
        switch self {
        case .skins: return GearCatalog.skins[0].id
        case .trails: return GearCatalog.trails[0].id
        case .flames: return GearCatalog.flames[0].id
        }
    }
}

/// One card on a rack, whichever rack it is.
struct GearItem: Identifiable, Hashable, Sendable {
    let tab: TailorTab
    let id: String
    let name: String
    let price: Int
    /// Fires only.
    let powerLabel: String?
    let hasPower: Bool

    init(skin: Skin) {
        tab = .skins; id = skin.id; name = skin.name; price = skin.price
        powerLabel = nil; hasPower = false
    }

    init(trail: Trail) {
        tab = .trails; id = trail.id; name = trail.name; price = trail.price
        powerLabel = nil; hasPower = false
    }

    init(flame: Flame) {
        tab = .flames; id = flame.id; name = flame.name; price = flame.price
        powerLabel = flame.powerLabel; hasPower = flame.power != nil
    }
}

enum Catalog {
    static func items(for tab: TailorTab) -> [GearItem] {
        switch tab {
        case .skins: return GearCatalog.skins.map(GearItem.init(skin:))
        case .trails: return GearCatalog.trails.map(GearItem.init(trail:))
        case .flames: return GearCatalog.flames.map(GearItem.init(flame:))
        }
    }

    static func exists(_ id: String, in tab: TailorTab) -> Bool {
        switch tab {
        case .skins: return GearCatalog.skins.contains { $0.id == id }
        case .trails: return GearCatalog.trails.contains { $0.id == id }
        case .flames: return GearCatalog.flames.contains { $0.id == id }
        }
    }

    static func price(of id: String, in tab: TailorTab) -> Int {
        items(for: tab).first { $0.id == id }?.price ?? 0
    }

    static func canAfford(_ item: GearItem, coins: Int) -> Bool {
        coins >= item.price
    }

    /// refreshTailorBadge() (ui.js:977-993): true when any rack has an
    /// unowned item the wallet can pay for. Developers get everything free,
    /// so the badge never nags them.
    static func anyAffordableUnowned(coins: Int, ownedSkins: [String], ownedTrails: [String],
                                    ownedFlames: [String], isDeveloper: Bool) -> Bool {
        if isDeveloper { return false }
        let racks: [(TailorTab, [String])] = [(.skins, ownedSkins), (.trails, ownedTrails), (.flames, ownedFlames)]
        for (tab, owned) in racks {
            for item in items(for: tab) where !owned.contains(item.id) && item.price <= coins {
                return true
            }
        }
        return false
    }
}

/// A pilot's equipped ids (the three `selected*` variables per pilot).
struct LoadoutIDs: Hashable, Sendable, Codable {
    var skin: String = GearCatalog.skins[0].id
    var trail: String = GearCatalog.trails[0].id
    var flame: String = GearCatalog.flames[0].id

    subscript(tab: TailorTab) -> String {
        get {
            switch tab {
            case .skins: return skin
            case .trails: return trail
            case .flames: return flame
            }
        }
        set {
            switch tab {
            case .skins: skin = newValue
            case .trails: trail = newValue
            case .flames: flame = newValue
            }
        }
    }

    var resolved: Loadout {
        Loadout(skin: GearCatalog.skin(id: skin), trail: GearCatalog.trail(id: trail), flame: GearCatalog.flame(id: flame))
    }

    /// enforceOwnedGear() for one pilot (ui.js:1601-1611): anything not owned
    /// drops back to the free item. Returns true when something changed.
    mutating func enforceOwned(skins: [String], trails: [String], flames: [String]) -> Bool {
        var changed = false
        if !skins.contains(skin) { skin = TailorTab.skins.defaultID; changed = true }
        if !trails.contains(trail) { trail = TailorTab.trails.defaultID; changed = true }
        if !flames.contains(flame) { flame = TailorTab.flames.defaultID; changed = true }
        return changed
    }
}
