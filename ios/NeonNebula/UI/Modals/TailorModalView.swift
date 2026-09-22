import SwiftUI

/// `#skins-modal` (index.php:563-594, ui.js:1734-1873): three racks of
/// cards, a coin chip, and a Pilot 1 / Pilot 2 switch when opened from the
/// two-player menu.
struct TailorModalView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(icon: NeonIcon.tailor, title: "THE TAILOR",
                        subtitle: app.tailorPilot == 2 ? "Dressing Pilot 2 — gear is shared with Pilot 1" : "Earn coins by flying missions",
                        onClose: { app.closeModal() }) {
                CoinChip(coins: app.coins)
            }

            if app.tailorShowsPilots {
                NeonTabBar(items: [.init(value: 1, title: "PILOT 1"), .init(value: 2, title: "PILOT 2")],
                           selection: app.tailorPilot,
                           activeTint: app.tailorPilot == 2 ? NeonColors.rose400 : NeonColors.cyan400,
                           activeFill: app.tailorPilot == 2 ? NeonColors.rose500.opacity(0.15) : NeonColors.cyan500.opacity(0.15)) {
                    app.setTailorPilot($0)
                }
                .frame(maxWidth: 256)
                .padding(.bottom, 12)
            }

            NeonTabBar(items: TailorTab.allCases.map { .init(value: $0, title: $0.title) },
                       selection: app.tailorTab) { app.setTailorTab($0) }
                .padding(.bottom, 16)

            GearGrid(tab: app.tailorTab)

            FormError(message: app.tailorError)
                .padding(.top, 12)
        }
    }
}

/// `.skins-grid`: three columns of cards (two on narrow screens).
struct GearGrid: View {
    @Environment(AppState.self) private var app
    let tab: TailorTab

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(columns: 3).frame(minWidth: 400)
            grid(columns: 2)
        }
    }

    private func grid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            ForEach(Catalog.items(for: tab)) { item in
                GearCard(item: item, equipped: app.isEquipped(item), owned: app.isOwned(item), devFree: !app.isOwned(item) && app.isDeveloper)
                    .onTapGesture { app.tapGear(item) }
            }
        }
    }
}

/// `.skin-card`.
struct GearCard: View {
    let item: GearItem
    let equipped: Bool
    let owned: Bool
    let devFree: Bool

    var body: some View {
        VStack(spacing: 6) {
            GearPreview(tab: item.tab, id: item.id)
                .frame(width: 48, height: 64)
            Text(item.name)
                .font(NeonFont.display(11, .bold))
                .foregroundStyle(NeonColors.slate200)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let power = item.powerLabel {
                Text(power)
                    .font(NeonFont.sans(9, .bold))
                    .tracking(0.5)
                    .foregroundStyle(item.hasPower ? NeonColors.amber400 : NeonColors.slate500)
                    .neonGlow(item.hasPower ? NeonColors.amber400.opacity(0.4) : .clear, radius: 6)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if equipped {
                status("EQUIPPED", color: NeonColors.cyan400)
            } else if owned {
                status("TAP TO EQUIP", color: NeonColors.slate500)
            } else {
                price
                if devFree { status("FREE — DEV", color: NeonColors.slate500) }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .glassTile(cornerRadius: 16,
                   fill: equipped ? NeonColors.cyan500.opacity(0.15) : NeonColors.white(0.05),
                   border: equipped ? NeonColors.cyan400 : NeonColors.white(0.08))
        .shadow(color: equipped ? NeonColors.cyan400.opacity(0.3) : .clear, radius: 6)
        .opacity(!owned && !devFree && !equipped ? 0.85 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityText)
    }

    private var price: some View {
        HStack(spacing: 5) {
            CoinDot(size: 9)
            Text(NumberFormat.integer(item.price))
        }
        .font(NeonFont.sans(10, .bold))
        .tracking(0.8)
        .foregroundStyle(NeonColors.amber400)
    }

    private func status(_ text: String, color: Color) -> some View {
        Text(text)
            .font(NeonFont.sans(10, .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    private var accessibilityText: String {
        var parts = [item.name]
        if let power = item.powerLabel { parts.append(power) }
        if equipped { parts.append("equipped") }
        else if owned { parts.append("tap to equip") }
        else { parts.append("\(item.price) coins" + (devFree ? ", free for developers" : "")) }
        return parts.joined(separator: ", ")
    }
}
