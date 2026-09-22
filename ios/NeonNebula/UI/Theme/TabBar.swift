import SwiftUI

/// `.lb-tabs` / `.lb-tab`: a row of equal-width pill tabs.
struct NeonTabBar<T: Hashable>: View {
    struct Item: Identifiable {
        let value: T
        let title: String
        var id: T { value }
    }

    let items: [Item]
    let selection: T
    var activeTint: Color = NeonColors.cyan400
    var activeFill: Color = NeonColors.cyan500.opacity(0.15)
    var fontSize: CGFloat = 11
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                let active = item.value == selection
                Button { onSelect(item.value) } label: {
                    Text(item.title)
                        .font(NeonFont.display(fontSize, .bold))
                        .tracking(0.08 * fontSize)
                        .foregroundStyle(active ? .white : NeonColors.slate400)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .glassTile(cornerRadius: 10,
                                   fill: active ? activeFill : NeonColors.white(0.05),
                                   border: active ? activeTint : NeonColors.white(0.08))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
    }
}
