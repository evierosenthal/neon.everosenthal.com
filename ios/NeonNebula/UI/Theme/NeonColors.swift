import SwiftUI
import NeonEngine

extension Color {
    /// A CSS color string ('#rrggbb', 'rgba(...)', 'hsl(...)'), parsed by the
    /// engine's RGBA so the UI and the renderer agree on every literal.
    init(css: String) {
        let c = RGBA(css: css) ?? RGBA(r: 1, g: 1, b: 1, a: 1)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    init(_ css: CSSColor) {
        self.init(css.rgba)
    }
}

/// The design tokens of styles.css:6-30 (Tailwind palette names).
enum NeonColors {
    static let slate950 = Color(css: "#020617")
    static let slate900 = Color(css: "#0f172a")
    static let slate800 = Color(css: "#1e293b")
    static let slate500 = Color(css: "#64748b")
    static let slate400 = Color(css: "#94a3b8")
    static let slate300 = Color(css: "#cbd5e1")
    static let slate200 = Color(css: "#e2e8f0")
    static let indigo600 = Color(css: "#4f46e5")
    static let indigo500 = Color(css: "#6366f1")
    static let indigo400 = Color(css: "#818cf8")
    static let indigo300 = Color(css: "#a5b4fc")
    static let purple700 = Color(css: "#7e22ce")
    static let emerald800 = Color(css: "#065f46")
    static let emerald600 = Color(css: "#059669")
    static let emerald500 = Color(css: "#10b981")
    static let emerald400 = Color(css: "#34d399")
    static let rose600 = Color(css: "#e11d48")
    static let rose500 = Color(css: "#f43f5e")
    static let rose400 = Color(css: "#fb7185")
    static let cyan500 = Color(css: "#06b6d4")
    static let cyan400 = Color(css: "#22d3ee")
    static let cyan300 = Color(css: "#67e8f9")
    static let amber400 = Color(css: "#fbbf24")
    static let canvasBlack = Color(css: "#09090b")

    /// rgba(255,255,255,a) helpers used all over the stylesheet.
    static func white(_ alpha: Double) -> Color { Color.white.opacity(alpha) }
    /// rgba(2, 6, 23, a) — the overlay scrims.
    static func scrim(_ alpha: Double) -> Color { slate950.opacity(alpha) }
}
