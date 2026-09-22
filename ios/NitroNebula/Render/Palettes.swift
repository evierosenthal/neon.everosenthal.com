import Foundation
import NitroEngine

/// One asteroid color scheme (game.js:18-104). Every string is verbatim.
struct AsteroidPalette {
    let gradient: [CSSColor]
    let craterFill: CSSColor
    let craterRim: CSSColor
    let speckle: CSSColor
    let glow: CSSColor
    let base: CSSColor
    let outline: CSSColor
    let facet: CSSColor
    let facetSoft: CSSColor
    let hole: CSSColor
    let blobBase: CSSColor
    let blobOutline: CSSColor
    let lit: CSSColor
    let blobCrater: CSSColor
    let blobRim: CSSColor
}

/// `ASTEROID_PALETTES`. rocky = gray, faceted = blue, blobby = darkblue in
/// play; purple and pink exist in the table but are never spawned.
let ASTEROID_PALETTES: [AsteroidTint: AsteroidPalette] = [
    .purple: AsteroidPalette(
        gradient: ["#8b5cf6", "#5b21b6", "#2e1065"],
        craterFill: "rgba(15, 5, 36, 0.6)",
        craterRim: "rgba(196, 181, 253, 0.35)",
        speckle: "rgba(233, 213, 255, 0.2)",
        glow: "rgba(139, 92, 246, 0.45)",
        base: "#5b21b6",
        outline: "#2e1065",
        facet: "rgba(167, 139, 250, 0.35)",
        facetSoft: "rgba(167, 139, 250, 0.18)",
        hole: "#1e1b4b",
        blobBase: "#6d28d9",
        blobOutline: "#3b0f6e",
        lit: "rgba(167, 139, 250, 0.22)",
        blobCrater: "#1a0b38",
        blobRim: "rgba(196, 181, 253, 0.4)"
    ),
    .pink: AsteroidPalette(
        gradient: ["#f9a8d4", "#db2777", "#831843"],
        craterFill: "rgba(50, 5, 30, 0.6)",
        craterRim: "rgba(251, 207, 232, 0.4)",
        speckle: "rgba(252, 231, 243, 0.25)",
        glow: "rgba(236, 72, 153, 0.5)",
        base: "#db2777",
        outline: "#831843",
        facet: "rgba(249, 168, 212, 0.4)",
        facetSoft: "rgba(249, 168, 212, 0.2)",
        hole: "#500724",
        blobBase: "#ec4899",
        blobOutline: "#9d174d",
        lit: "rgba(251, 207, 232, 0.25)",
        blobCrater: "#500724",
        blobRim: "rgba(251, 207, 232, 0.45)"
    ),
    .gray: AsteroidPalette( // the rocky photo's natural stone gray
        gradient: ["#e2e8f0", "#94a3b8", "#475569"],
        craterFill: "rgba(15, 23, 42, 0.5)",
        craterRim: "rgba(255, 255, 255, 0.35)",
        speckle: "rgba(255, 255, 255, 0.25)",
        glow: "rgba(148, 163, 184, 0.4)",
        base: "#94a3b8",
        outline: "#475569",
        facet: "rgba(226, 232, 240, 0.4)",
        facetSoft: "rgba(226, 232, 240, 0.2)",
        hole: "#1e293b",
        blobBase: "#94a3b8",
        blobOutline: "#475569",
        lit: "rgba(241, 245, 249, 0.25)",
        blobCrater: "#1e293b",
        blobRim: "rgba(255, 255, 255, 0.35)"
    ),
    .blue: AsteroidPalette( // the low-poly art's royal blue
        gradient: ["#93c5fd", "#2563eb", "#1e3a8a"],
        craterFill: "rgba(11, 20, 60, 0.6)",
        craterRim: "rgba(191, 219, 254, 0.4)",
        speckle: "rgba(219, 234, 254, 0.25)",
        glow: "rgba(59, 130, 246, 0.45)",
        base: "#2563eb",
        outline: "#1e3a8a",
        facet: "rgba(147, 197, 253, 0.45)",
        facetSoft: "rgba(147, 197, 253, 0.22)",
        hole: "#172554",
        blobBase: "#2563eb",
        blobOutline: "#1e3a8a",
        lit: "rgba(147, 197, 253, 0.25)",
        blobCrater: "#172554",
        blobRim: "rgba(191, 219, 254, 0.4)"
    ),
    .darkblue: AsteroidPalette( // the round cartoon's deep blue
        gradient: ["#60a5fa", "#1e40af", "#172554"],
        craterFill: "rgba(5, 10, 40, 0.65)",
        craterRim: "rgba(147, 197, 253, 0.4)",
        speckle: "rgba(191, 219, 254, 0.22)",
        glow: "rgba(37, 99, 235, 0.4)",
        base: "#1e40af",
        outline: "#172554",
        facet: "rgba(96, 165, 250, 0.35)",
        facetSoft: "rgba(96, 165, 250, 0.18)",
        hole: "#0f172a",
        blobBase: "#1e40af",
        blobOutline: "#172554",
        lit: "rgba(96, 165, 250, 0.25)",
        blobCrater: "#0f172a",
        blobRim: "rgba(147, 197, 253, 0.4)"
    )
]

extension AsteroidPalette {
    /// `ASTEROID_PALETTES[a.tint] || ASTEROID_PALETTES.purple`.
    static func palette(for tint: AsteroidTint) -> AsteroidPalette {
        ASTEROID_PALETTES[tint] ?? ASTEROID_PALETTES[.purple]!
    }
}
