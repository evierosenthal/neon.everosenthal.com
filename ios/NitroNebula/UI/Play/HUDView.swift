import SwiftUI

/// The in-flight bar (index.php:33-72, styles.css:162-339): terminal name,
/// score and record, the difficulty strip, the hull gauge and the pause
/// button. Only the pause button takes touches, so the joystick can start
/// anywhere else — even under the bar.
///
/// Sizing follows the web's `.hud` (1.5rem inset, 5rem bar, 80rem max) on
/// iPads. Phones in landscape have no room for that: there the bar is a
/// slimmer 48pt strip under a 12pt inset (60pt in all, under 15% of the
/// 402pt screen) so the whole playfield stays visible beneath it. Both
/// layouts sit to the right of the settings launcher (icon-only on phones,
/// icon + label on iPads) instead of underneath it.
struct HUDView: View {
    @Environment(AppState.self) private var app
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        GeometryReader { geo in
            let compact = vSize == .compact
            let m = HUDMetrics(width: geo.size.width, compact: compact)
            VStack(spacing: 0) {
                HStack(spacing: m.groupGap) {
                    HStack(spacing: m.statGap) {
                        if m.showsTerminal {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Commander Terminal")
                                    .neonLabel(size: 10, color: NeonColors.indigo300)
                                Text("NEBULA PRIME")
                                    .font(NeonFont.display(24, .black))
                                    .tracking(-1.2)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Rectangle().fill(NeonColors.white(0.1)).frame(width: 1, height: 32)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Score").neonLabel()
                            Text(NumberFormat.integer(app.score))
                                .font(NeonFont.display(20))
                                .foregroundStyle(NeonColors.cyan400)
                                .neonGlow(Color(css: "#00ffff").opacity(0.6))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("High Score").neonLabel()
                            Text(NumberFormat.integer(app.currentBest))
                                .font(NeonFont.display(14))
                                .foregroundStyle(NeonColors.amber400)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                    .allowsHitTesting(false)

                    Spacer(minLength: 8)

                    if m.showsModes {
                        ModeStrip(tiers: app.hudTiers, live: app.liveTier)
                            .allowsHitTesting(false)
                        Spacer(minLength: 8)
                    }

                    HStack(spacing: m.rightGap) {
                        HullGauge(health: app.health)
                            .frame(width: m.hullWidth)
                            .allowsHitTesting(false)
                        if !app.isOnlineGame {
                            Button { app.togglePause() } label: {
                                Icon(NeonIcon.pause, size: 20)
                            }
                            .buttonStyle(IconButtonStyle(visualSize: m.pauseSize))
                            .accessibilityLabel("Pause")
                        }
                    }
                }
                .padding(.horizontal, m.barPadding)
                .frame(height: m.barHeight)
                .glassPanel(cornerRadius: 16)
                .frame(maxWidth: 1280)
                Spacer(minLength: 0)
            }
            .padding(.top, m.topInset)
            .padding(.horizontal, m.sideInset)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The bar's numbers for a given width. Mirrors the web's media queries:
/// `.hud-modes` hides at 900px and below; the terminal block needs the
/// extra room of a wide bar.
struct HUDMetrics {
    let width: CGFloat
    let compact: Bool

    /// `@media (max-width: 900px) { .hud-modes { display: none } }`.
    var showsModes: Bool { width > 900 }
    var showsTerminal: Bool { width >= 1000 }

    /// Room for the settings launcher (`.settings-btn` at 1.25rem, icon-only
    /// on phones) plus the same gap on the right so the bar stays centred.
    var sideInset: CGFloat { compact ? 68 : 168 }
    /// `.hud { padding: 1.5rem }` on the web; tighter on phones.
    var topInset: CGFloat { compact ? 12 : 24 }
    /// `.hud-bar { height: 5rem }` on the web; 48pt on phones.
    var barHeight: CGFloat { compact ? 48 : 80 }
    /// `.hud-bar { padding: 0 2rem }`.
    var barPadding: CGFloat { compact ? 16 : (showsTerminal ? 32 : 20) }
    var groupGap: CGFloat { compact ? 16 : 24 }
    var statGap: CGFloat { compact ? 20 : 32 }
    var rightGap: CGFloat { compact ? 14 : 24 }
    /// `.hull { width: 12rem }`.
    var hullWidth: CGFloat { compact ? 150 : (width >= 700 ? 192 : 140) }
    var pauseSize: CGFloat { compact ? 40 : 44 }

    /// The bar's bottom edge, for layout checks.
    var bottomEdge: CGFloat { topInset + barHeight }
}

/// `.hud-modes`: the tiers from the starting mode upward; the lit tile
/// follows the engine's live difficulty (ui.js:775-810).
struct ModeStrip: View {
    let tiers: [Tier]
    let live: Tier

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tiers, id: \.self) { tier in
                let active = tier == live
                Text(tier.hudLabel)
                    .font(NeonFont.display(12, .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(active ? .white : NeonColors.slate500)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(active ? NeonColors.cyan500.opacity(0.15) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? NeonColors.cyan400 : .clear, lineWidth: 1))
                    .shadow(color: active ? NeonColors.cyan400.opacity(0.45) : .clear, radius: 6)
                    .neonGlow(active ? NeonColors.cyan400.opacity(0.6) : .clear)
                    .animation(.easeInOut(duration: 0.4), value: active)
            }
        }
    }
}

/// `.hull`: HULL INTEGRITY with the percentage and the gradient bar, red
/// below 30 (setHealth, ui.js:746-753).
struct HullGauge: View {
    let health: Int

    var body: some View {
        let pct = max(0, min(100, health))
        let critical = health <= 30
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Text("Hull Integrity").neonLabel().lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                Text("\(max(0, health))%")
                    .neonLabel(size: 10, color: critical ? NeonColors.rose500 : NeonColors.emerald400)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(NeonColors.white(0.05))
                        .overlay(Capsule().stroke(NeonColors.white(0.1), lineWidth: 1))
                    Capsule()
                        .fill(critical ? AnyShapeStyle(NeonColors.rose500)
                              : AnyShapeStyle(LinearGradient(colors: [NeonColors.emerald500, NeonColors.cyan500],
                                                             startPoint: .leading, endPoint: .trailing)))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                        .animation(.easeInOut(duration: 0.3), value: pct)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hull integrity \(max(0, health)) percent")
    }
}
