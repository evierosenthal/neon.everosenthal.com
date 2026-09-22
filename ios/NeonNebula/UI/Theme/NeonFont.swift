import SwiftUI

/// Orbitron (display) and Inter (sans), bundled; SwiftUI falls back to the
/// system font if a face is missing.
enum NeonFont {
    enum Weight { case regular, semibold, bold, black, light }

    /// Orbitron: the web's 400 maps to Orbitron-Medium.
    static func display(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black: name = "Orbitron-Black"
        case .bold, .semibold: name = "Orbitron-Bold"
        case .regular, .light: name = "Orbitron-Medium"
        }
        return .custom(name, fixedSize: size)
    }

    /// Inter.
    static func sans(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light: name = "Inter-Light"
        case .regular: name = "Inter-Regular"
        case .semibold: name = "Inter-SemiBold"
        case .bold, .black: name = "Inter-Bold"
        }
        return .custom(name, fixedSize: size)
    }

    /// The settings launcher's monospace label.
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

extension View {
    /// CSS `letter-spacing: Xem` for a given font size.
    func tracking(em: CGFloat, size: CGFloat) -> some View {
        self.tracking(em * size)
    }

    /// The small uppercase label style used throughout (`.label`, `.home-stat-label`).
    func neonLabel(size: CGFloat = 10, color: Color = NeonColors.slate400, trackingEm: CGFloat = 0.1, weight: NeonFont.Weight = .bold) -> some View {
        self.font(NeonFont.sans(size, weight))
            .foregroundStyle(color)
            .tracking(trackingEm * size)
            .textCase(.uppercase)
    }

    /// `text-shadow: 0 0 Npx color` — a soft glow behind text.
    func neonGlow(_ color: Color, radius: CGFloat = 8) -> some View {
        self.shadow(color: color, radius: radius / 2)
    }
}
