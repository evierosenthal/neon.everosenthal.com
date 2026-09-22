import SwiftUI

/// styles.css `.panel` / `.frosted-glass`: a 5% white fill over a 24px
/// backdrop blur, a 1px 10% white border and a deep drop shadow.
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    var borderColor: Color = NeonColors.white(0.1)
    var fill: Color = NeonColors.white(0.05)
    var shadowed = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape.fill(.ultraThinMaterial)
                    .overlay(shape.fill(fill))
            }
            .overlay(shape.stroke(borderColor, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: shadowed ? Color.black.opacity(0.5) : .clear, radius: 25, y: 20)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24, borderColor: Color = NeonColors.white(0.1),
                    fill: Color = NeonColors.white(0.05), shadowed: Bool = true) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, borderColor: borderColor, fill: fill, shadowed: shadowed))
    }

    /// A lighter inner tile (`.home-stat`, `.score-card`, `.lb-row`): a flat
    /// translucent fill with a faint border and no shadow.
    func glassTile(cornerRadius: CGFloat = 16, fill: Color = NeonColors.white(0.05),
                   border: Color = NeonColors.white(0.07), lineWidth: CGFloat = 1) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(fill))
            .overlay(shape.stroke(border, lineWidth: lineWidth))
    }
}

/// `.panel-topline`: the thin gradient line across the top of the end screens.
struct PanelTopline: View {
    var color: Color = NeonColors.rose500.opacity(0.5)

    var body: some View {
        LinearGradient(colors: [.clear, color, .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 4)
    }
}
