import SwiftUI

/// `#gameover-screen` (index.php:398-429, styles.css:2169-2276).
struct GameOverView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        EndScreenScaffold(borderColor: NeonColors.rose500.opacity(0.3), topline: NeonColors.rose500.opacity(0.5)) { compact in
            VStack(spacing: 0) {
                Text("SECTOR LOST")
                    .font(NeonFont.display(compact ? 36 : 48, .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 8)
                Text(app.lastRoundConnectionLost ? "Connection to your co-pilot was lost" : "Critical Hull Failure Detected")
                    .font(NeonFont.sans(10, .bold))
                    .tracking(4)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NeonColors.rose400.opacity(0.8))
                    .padding(.bottom, compact ? 20 : 40)

                ScoreCard(compact: compact) {
                    Text("Efficiency Rating").scoreCardLabel()
                    GradientNumber(text: NumberFormat.integer(app.score), size: compact ? 44 : 60,
                                   colors: [.white, NeonColors.slate500])
                        .padding(.bottom, compact ? 12 : 24)
                    Rectangle().fill(NeonColors.white(0.1)).frame(height: 1)
                        .padding(.bottom, compact ? 12 : 24)
                    ScoreCardRow(key: "COINS EARNED", value: "+" + NumberFormat.integer(app.earnedCoins), color: NeonColors.amber400)
                        .padding(.bottom, 8)
                    ScoreCardRow(key: "HISTORICAL PEAK", value: NumberFormat.integer(app.currentBest), color: NeonColors.cyan400, glow: true)
                }
                .padding(.bottom, compact ? 20 : 40)

                EndButtons()
            }
        }
    }
}

/// COMMAND / RESTART MISSION (shared by both end screens).
struct EndButtons: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 16) {
            Button { app.returnToStart() } label: {
                HStack(spacing: 12) {
                    Icon(NeonIcon.home, size: 20)
                    Text("COMMAND").lineLimit(1).fixedSize()
                }
            }
            .buttonStyle(NeonButtonStyle(variant: .muted, cornerRadius: 16,
                                         padding: EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20),
                                         fullWidth: false, font: NeonFont.display(15, .black)))
            Button { app.restartLastMission() } label: {
                HStack(spacing: 12) {
                    Icon(NeonIcon.restart, size: 20)
                    Text("RESTART MISSION").lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(.neonRow(.indigo))
            .layoutPriority(2)
        }
    }
}

/// `.overlay-gameover` + `.panel-gameover`: a dark blurred scrim with a
/// centred, scrollable panel. `content` receives whether the screen is
/// short (phones in landscape) so it can tighten its spacing.
struct EndScreenScaffold<Content: View, Backdrop: View>: View {
    let borderColor: Color
    let topline: Color
    let backdrop: Backdrop
    let content: (Bool) -> Content

    init(borderColor: Color, topline: Color, @ViewBuilder backdrop: () -> Backdrop = { EmptyView() },
         @ViewBuilder content: @escaping (Bool) -> Content) {
        self.borderColor = borderColor
        self.topline = topline
        self.backdrop = backdrop()
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 600
            ZStack {
                NeonColors.scrim(0.8)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                backdrop
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        content(compact)
                            .padding(compact ? 24 : 48)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .top) { PanelTopline(color: topline) }
                            .glassPanel(cornerRadius: compact ? 28 : 40, borderColor: borderColor)
                            .frame(maxWidth: 512)
                    }
                    .frame(maxWidth: .infinity)
                    // Short screens: start below the corner chrome (12pt
                    // inset + 44pt chip) so the chip never sits on the panel.
                    .padding(.top, compact ? 64 : 24)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 16)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .transition(.opacity)
    }
}

/// `.score-card`.
struct ScoreCard<Content: View>: View {
    let compact: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(compact ? 20 : 32)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(NeonColors.white(0.05))
                .shadow(color: Color.black.opacity(0.3), radius: 2, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(NeonColors.white(0.05), lineWidth: 1))
    }
}

struct ScoreCardRow: View {
    let key: String
    let value: String
    let color: Color
    var glow = false

    var body: some View {
        HStack {
            Text(key)
                .font(NeonFont.display(12, .bold))
                .tracking(1.2)
                .foregroundStyle(NeonColors.slate500)
            Spacer()
            Text(value)
                .font(NeonFont.display(12, .black))
                .tracking(1.2)
                .foregroundStyle(color)
                .neonGlow(glow ? Color(css: "#00ffff").opacity(0.6) : .clear)
        }
    }
}

/// `.score-card-value`: a huge number filled with a vertical gradient.
struct GradientNumber: View {
    let text: String
    let size: CGFloat
    let colors: [Color]

    var body: some View {
        Text(text)
            .font(NeonFont.display(size, .black))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
    }
}

extension View {
    func scoreCardLabel() -> some View {
        self.neonLabel(size: 10, color: NeonColors.slate500).padding(.bottom, 8)
    }
}
