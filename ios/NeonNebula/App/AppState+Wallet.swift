import Foundation
import NeonEngine

// Coins, the daily chest and the Tailor (ui.js:1160-1185, 1578-1873).

extension AppState {
    /// saveWallet (ui.js:1620-1633): every wallet key at once.
    func saveWallet() {
        store.saveWallet(coins: coins, ownedSkins: ownedSkins, ownedTrails: ownedTrails,
                         ownedFlames: ownedFlames, loadout1: loadout1, loadout2: loadout2)
    }

    // MARK: Daily chest

    func isDailyClaimed(now: Date = Date()) -> Bool {
        store.dailyClaimed(now: now)
    }

    /// claimDailyBonus (ui.js:1167-1185).
    func claimDaily(now: Date = Date()) {
        if isDailyClaimed(now: now) { return }
        store.dailyClaimStamp = Economy.todayStamp(now)
        coins += Economy.dailyBonus
        saveWallet()
        dailyClaimBurst += 1
    }

    // MARK: Tailor

    /// openTailor (ui.js:1847-1856): the pilot switch only counts from the
    /// two-player menu.
    func openTailor(tab: TailorTab? = nil, pilot: Int = 1) {
        if let tab { tailorTab = tab }
        tailorPilot = (menuMode == .twoPlayer && pilot == 2) ? 2 : 1
        tailorError = nil
        openModal(.tailor)
    }

    func setTailorTab(_ tab: TailorTab) {
        tailorTab = tab
        tailorError = nil
    }

    func setTailorPilot(_ pilot: Int) {
        tailorPilot = pilot == 2 ? 2 : 1
        tailorError = nil
    }

    func isOwned(_ item: GearItem) -> Bool {
        owned(item.tab).contains(item.id)
    }

    func isEquipped(_ item: GearItem) -> Bool {
        loadout(pilot: tailorPilot)[item.tab] == item.id
    }

    /// handleSkinClick and its trail/flame twins (ui.js:1755-1769): buy if
    /// needed (developers wear anything for free), then equip for the pilot
    /// being dressed.
    func tapGear(_ item: GearItem) {
        tailorError = nil
        if !isOwned(item) && !isDeveloper {
            if coins < item.price {
                tailorError = Economy.shortfallMessage(price: item.price, coins: coins)
                return
            }
            coins -= item.price
            addOwned(item.tab, item.id)
        }
        equip(item.tab, id: item.id, pilot: tailorPilot)
        saveWallet()
    }

    func equip(_ tab: TailorTab, id: String, pilot: Int) {
        if pilot == 2 { loadout2[tab] = id } else { loadout1[tab] = id }
    }

    private func addOwned(_ tab: TailorTab, _ id: String) {
        switch tab {
        case .skins: ownedSkins.append(id)
        case .trails: ownedTrails.append(id)
        case .flames: ownedFlames.append(id)
        }
    }

    /// enforceOwnedGear (ui.js:1601-1611): once we know who is logged in,
    /// anyone who isn't a developer drops back to gear they actually own.
    func enforceOwnedGear() {
        if isDeveloper { return }
        var changed = loadout1.enforceOwned(skins: ownedSkins, trails: ownedTrails, flames: ownedFlames)
        if loadout2.enforceOwned(skins: ownedSkins, trails: ownedTrails, flames: ownedFlames) { changed = true }
        if changed { saveWallet() }
    }
}
