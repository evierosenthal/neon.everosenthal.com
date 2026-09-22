import SwiftUI

/// The Lucide icons index.php inlines, as SF Symbols.
enum NeonIcon {
    static let zap = "bolt.fill"
    static let settings = "gearshape"
    static let sliders = "slider.horizontal.3"
    static let user = "person"
    static let users = "person.2"
    static let trophy = "trophy"
    static let tailor = "scissors"
    static let gift = "gift"
    static let pause = "pause.fill"
    static let check = "checkmark"
    static let close = "xmark"
    static let back = "arrow.left"
    static let home = "house"
    static let restart = "arrow.counterclockwise"
    static let globe = "globe"
    static let joystick = "gamecontroller"
    static let lock = "lock"
    static let logout = "rectangle.portrait.and.arrow.right"
    static let trash = "trash"
    static let info = "info.circle"
    static let coins = "circle.fill"
}

/// An icon at a CSS-like pixel size with a stroke-ish weight. Hidden from
/// VoiceOver: every icon sits beside its caption or inside a button that
/// carries its own `accessibilityLabel` (settings, pause, close), so the
/// symbol name would only be noise.
struct Icon: View {
    let name: String
    var size: CGFloat = 20
    var weight: Font.Weight = .semibold

    init(_ name: String, size: CGFloat = 20, weight: Font.Weight = .semibold) {
        self.name = name
        self.size = size
        self.weight = weight
    }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.85, weight: weight))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The gold coin dot before prices (`.coin-chip::before`, `.skin-status.price::before`).
struct CoinDot: View {
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(css: "#fde68a"), Color(css: "#f59e0b"), Color(css: "#b45309")],
                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size))
            .frame(width: size, height: size)
            .shadow(color: NeonColors.amber400.opacity(0.6), radius: 3)
    }
}

/// `.coin-chip`: the wallet pill in the Tailor header.
struct CoinChip: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            CoinDot(size: 13)
            Text(NumberFormat.integer(coins))
                .font(NeonFont.display(13, .bold))
        }
        .foregroundStyle(NeonColors.amber400)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule().fill(NeonColors.amber400.opacity(0.12)))
        .overlay(Capsule().stroke(NeonColors.amber400.opacity(0.4), lineWidth: 1))
    }
}
