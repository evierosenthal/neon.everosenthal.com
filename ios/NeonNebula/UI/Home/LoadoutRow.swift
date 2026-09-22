import SwiftUI

/// `.home-loadout` (index.php:241-254): the equipped skin, trail and fire;
/// each chip opens the Tailor on its rack for that pilot.
struct LoadoutRow: View {
    @Environment(AppState.self) private var app
    let pilot: Int

    var body: some View {
        let loadout = app.loadout(pilot: pilot)
        HStack(spacing: 8) {
            ForEach(TailorTab.allCases, id: \.self) { tab in
                let id = loadout[tab]
                Button { app.openTailor(tab: tab, pilot: pilot) } label: {
                    HStack(spacing: 8) {
                        GearPreview(tab: tab, id: id)
                            .frame(width: 22, height: 35)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tab.chipKind)
                                .neonLabel(size: 9, color: NeonColors.slate500, trackingEm: 0.12)
                            Text(itemName(tab: tab, id: id))
                                .font(NeonFont.display(10, .bold))
                                .foregroundStyle(NeonColors.slate200)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .glassTile(cornerRadius: 12, fill: NeonColors.white(0.03), border: NeonColors.white(0.06))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.chipKind): \(itemName(tab: tab, id: id))")
                .accessibilityHint(pilot == 2 ? "Change Pilot 2's \(tab.chipKind.lowercased())" : "Change \(tab.chipKind.lowercased())")
            }
        }
        .padding(.horizontal, 8)
    }

    private func itemName(tab: TailorTab, id: String) -> String {
        Catalog.items(for: tab).first { $0.id == id }?.name ?? id
    }
}

/// `.loadout-row-label`: PILOT 1 · LEFT STICK / PILOT 2 · RIGHT STICK.
struct LoadoutRowLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(NeonFont.sans(9, .black))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }
}
