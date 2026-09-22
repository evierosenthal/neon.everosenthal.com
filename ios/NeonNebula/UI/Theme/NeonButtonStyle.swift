import SwiftUI

/// styles.css `.btn` and its color variants (L1958-2131).
struct NeonButtonStyle: ButtonStyle {
    enum Variant: Sendable {
        case emerald, indigo, rose, superHard, cyan, muted
        case ghostIndigo, ghostRose, ghostCyan

        var background: Color {
            switch self {
            case .emerald: return NeonColors.emerald600
            case .indigo: return NeonColors.indigo600
            case .rose: return NeonColors.rose600
            case .superHard: return NeonColors.canvasBlack
            case .cyan: return NeonColors.cyan500
            case .muted: return NeonColors.white(0.05)
            case .ghostIndigo: return NeonColors.indigo500.opacity(0.2)
            case .ghostRose: return NeonColors.rose500.opacity(0.2)
            case .ghostCyan: return NeonColors.cyan500.opacity(0.15)
            }
        }

        var foreground: Color {
            switch self {
            case .emerald, .indigo, .rose: return .white
            case .superHard: return NeonColors.rose600
            case .cyan: return NeonColors.slate950
            case .muted: return NeonColors.slate400
            case .ghostIndigo: return NeonColors.indigo400
            case .ghostRose: return NeonColors.rose400
            case .ghostCyan: return NeonColors.cyan400
            }
        }

        var border: Color {
            switch self {
            case .emerald: return NeonColors.emerald400.opacity(0.3)
            case .indigo, .ghostIndigo: return NeonColors.indigo400.opacity(0.3)
            case .rose, .ghostRose: return NeonColors.rose400.opacity(0.3)
            case .superHard: return NeonColors.rose600
            case .cyan: return .clear
            case .muted: return NeonColors.white(0.1)
            case .ghostCyan: return NeonColors.cyan400.opacity(0.3)
            }
        }

        var borderWidth: CGFloat { self == .superHard ? 2 : 1 }

        var shadow: Color {
            switch self {
            case .emerald: return Color(css: "#022c22").opacity(0.3)
            case .indigo: return Color(css: "#1e1b4b").opacity(0.5)
            case .rose: return Color(css: "#4c0519").opacity(0.3)
            case .superHard: return Color(css: "#881337").opacity(0.5)
            case .cyan: return Color(css: "#083344").opacity(0.5)
            case .muted: return .clear
            case .ghostIndigo: return Color(css: "#1e1b4b").opacity(0.2)
            case .ghostRose: return Color(css: "#4c0519").opacity(0.2)
            case .ghostCyan: return Color(css: "#083344").opacity(0.2)
            }
        }

        /// `.btn-super .btn-sheen` — a faint rose wash over the black.
        var wash: Color { self == .superHard ? NeonColors.rose600.opacity(0.1) : .clear }
    }

    var variant: Variant
    var cornerRadius: CGFloat = 16
    var padding = EdgeInsets(top: 16, leading: 40, bottom: 16, trailing: 40)
    var fullWidth = true
    var font: Font = NeonFont.display(18, .black)

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(font)
            .foregroundStyle(variant.foreground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(padding)
            .background(shape.fill(variant.background))
            .overlay(shape.fill(variant.wash))
            .overlay(shape.stroke(variant.border, lineWidth: variant.borderWidth))
            .contentShape(shape)
            .shadow(color: variant.shadow, radius: 12, y: 10)
            .scaleEffect(configuration.isPressed ? (variant == .superHard ? 0.95 : 0.98) : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NeonButtonStyle {
    /// A full-size menu button.
    static func neon(_ variant: NeonButtonStyle.Variant) -> NeonButtonStyle {
        NeonButtonStyle(variant: variant)
    }

    /// `.btn-sm`: the modal buttons (padding 12/24, 14px, radius 12).
    static func neonSmall(_ variant: NeonButtonStyle.Variant, fullWidth: Bool = false) -> NeonButtonStyle {
        NeonButtonStyle(variant: variant, cornerRadius: 12,
                        padding: EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24),
                        fullWidth: fullWidth, font: NeonFont.display(14, .black))
    }

    /// `.btn-duo .btn` / `.btn-wide`: the half- and full-width menu buttons.
    static func neonMenu(_ variant: NeonButtonStyle.Variant) -> NeonButtonStyle {
        NeonButtonStyle(variant: variant, cornerRadius: 16,
                        padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
                        font: NeonFont.display(14, .black))
    }

    /// `.button-row .btn`: the end-screen buttons (padding 16/24, 15px).
    static func neonRow(_ variant: NeonButtonStyle.Variant) -> NeonButtonStyle {
        NeonButtonStyle(variant: variant, cornerRadius: 16,
                        padding: EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24),
                        font: NeonFont.display(15, .black))
    }

    /// `.btn-lg`: RESUME MISSION.
    static func neonLarge(_ variant: NeonButtonStyle.Variant) -> NeonButtonStyle {
        NeonButtonStyle(variant: variant, cornerRadius: 16,
                        padding: EdgeInsets(top: 20, leading: 64, bottom: 20, trailing: 64),
                        font: NeonFont.display(20, .black))
    }
}

/// `.close-btn`: the square X in modal headers.
struct CloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? .white : NeonColors.slate400)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NeonColors.white(configuration.isPressed ? 0.1 : 0.05)))
            .contentShape(Rectangle())
    }
}

/// `.link-btn`: underlined cyan text links.
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NeonFont.sans(12, .semibold))
            .foregroundStyle(configuration.isPressed ? NeonColors.cyan300 : NeonColors.cyan400)
            .underline()
    }
}

/// `.back-btn`: MAIN MENU in the sub-menus.
struct BackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NeonFont.sans(12, .bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(configuration.isPressed ? .white : NeonColors.slate400)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .glassTile(cornerRadius: 12, fill: NeonColors.white(0.05), border: NeonColors.white(0.1))
    }
}

/// `.icon-button`: the HUD pause button. `visualSize` is the drawn square
/// (44 on the web, 40 in the phone's slim bar); the hit target is always at
/// least 44pt.
struct IconButtonStyle: ButtonStyle {
    var visualSize: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: visualSize, height: visualSize)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NeonColors.white(configuration.isPressed ? 0.2 : 0.1)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(NeonColors.white(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.3), radius: 12, y: 10)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}
