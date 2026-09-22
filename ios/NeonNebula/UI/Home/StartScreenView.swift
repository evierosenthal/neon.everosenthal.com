import SwiftUI

/// Layout numbers that follow the web's media queries (styles.css:1383-1472,
/// 1516-1523, 1627-1679): the panel is a fixed-width column that scrolls
/// when it is taller than the screen.
struct HomeMetrics {
    let size: CGSize

    /// `@media (max-height: 1000px)` compacts the panel.
    var shortScreen: Bool { size.height <= 1000 }
    /// `@media (max-width: 640px)`: chest joins the flow, no home rocket.
    var narrow: Bool { size.width <= 640 }
    /// The chest floats beside the panel only when the (safe-area-reduced)
    /// width leaves room for it; otherwise it joins the flow like on phones.
    var chestFloats: Bool { size.width >= panelMaxWidth + 2 * 128 }
    /// `@media (max-width: 900px)`: no galaxy, small gas giant, no planet.
    var midWidth: Bool { size.width <= 900 }
    /// The panel can never be centred on a short screen; leave room for the
    /// corner buttons above it instead.
    var scrolls: Bool { size.height < 760 }

    var panelMaxWidth: CGFloat { 576 }
    var panelPadding: CGFloat { narrow ? 20 : (shortScreen ? 32 : 48) }
    var panelRadius: CGFloat { narrow ? 24 : (shortScreen ? 32 : 48) }
    var titleSize: CGFloat { shortScreen ? 56 : (size.width >= 768 ? 96 : 72) }
    var titleSmallSize: CGFloat { shortScreen ? 36 : (size.width >= 768 ? 60 : 48) }
    var subtitleBottom: CGFloat { shortScreen ? 24 : 32 }
    var stackGap: CGFloat { shortScreen ? 10 : 12 }
    var topInset: CGFloat { scrolls ? 72 : 16 }
}

private struct HomeMetricsKey: EnvironmentKey {
    static let defaultValue = HomeMetrics(size: CGSize(width: 874, height: 402))
}

extension EnvironmentValues {
    var homeMetrics: HomeMetrics {
        get { self[HomeMetricsKey.self] }
        set { self[HomeMetricsKey.self] = newValue }
    }
}

/// The start screen (index.php:146-395): the animated space backdrop, the
/// daily chest and the frosted panel that hosts the three menus.
struct StartScreenView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var parallax = ParallaxController()
    @State private var dragParallax: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            let metrics = HomeMetrics(size: geo.size)
            let px = reduceMotion ? .zero : (dragParallax ?? parallax.offset)
            ZStack {
                NeonColors.scrim(0.6)
                HomeBackdropView(parallax: px, metrics: metrics)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        StartPanel()
                            .frame(maxWidth: metrics.panelMaxWidth)
                            .rotation3DEffect(.degrees(Double(px.x) * 4), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
                            .rotation3DEffect(.degrees(Double(-px.y) * 3), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
                        if !metrics.chestFloats {
                            DailyChestButton()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, metrics.topInset)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 16)
                    .frame(minHeight: geo.size.height)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard !reduceMotion, !parallax.isActive else { return }
                            let dx = (g.location.x - geo.size.width / 2) / geo.size.width * 1.4
                            let dy = (g.location.y - geo.size.height / 2) / geo.size.height * 1.4
                            dragParallax = CGPoint(x: max(-0.7, min(0.7, dx)), y: max(-0.7, min(0.7, dy)))
                        }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.35)) { dragParallax = nil } }
                )
                if metrics.chestFloats {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            DailyChestButton()
                                .padding(.trailing, 32)
                                .padding(.bottom, 32)
                        }
                    }
                }
            }
            .environment(\.homeMetrics, metrics)
            .animation(.easeOut(duration: 0.35), value: px)
        }
        .onAppear { if !reduceMotion { parallax.start() } }
        .onDisappear { parallax.stop() }
    }
}

/// `.panel-start`: the frosted column with its two accent glows and the
/// bobbing rocket, switching between the main, two-player and CPU menus.
struct StartPanel: View {
    @Environment(AppState.self) private var app
    @Environment(\.homeMetrics) private var m

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch app.menuMode {
                case .main: MainMenuView()
                case .twoPlayer: TwoPlayerMenuView()
                case .cpu: CPUMenuView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(m.panelPadding)
            if !m.narrow {
                HomeRocket()
                    .padding(.top, 28)
                    .padding(.trailing, 36)
            }
        }
        .background(alignment: .topTrailing) {
            RadialGradient(colors: [NeonColors.cyan500.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 120)
                .frame(width: 240, height: 240)
                .offset(x: 80, y: -80)
        }
        .background(alignment: .bottomLeading) {
            RadialGradient(colors: [NeonColors.indigo500.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 130)
                .frame(width: 260, height: 260)
                .offset(x: -90, y: 90)
        }
        .glassPanel(cornerRadius: m.panelRadius)
        .animation(.easeInOut(duration: 0.25), value: app.menuMode)
    }
}

/// `.title-block` + `.title-rule`: the big Orbitron heading and its gradient rule.
struct MenuTitle: View {
    let text: String
    let size: CGFloat
    let rule: [Color]
    var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(NeonFont.display(size, .black))
                .tracking(-0.05 * size)
                .lineSpacing(0)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: NeonColors.cyan400.opacity(glow && pulse ? 0.45 : 0.2), radius: glow && pulse ? 15 : 9)
                .shadow(color: NeonColors.indigo500.opacity(glow && pulse ? 0.25 : 0), radius: 30)
                .padding(.bottom, 8)
            LinearGradient(colors: rule, startPoint: .leading, endPoint: .trailing)
                .frame(width: 96, height: 4)
        }
        .onAppear {
            guard glow, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// `.subtitle`.
struct MenuSubtitle: View {
    let text: String
    var trackingEm: CGFloat = 0.3

    var body: some View {
        Text(text)
            .font(NeonFont.sans(12, .bold))
            .tracking(trackingEm * 12)
            .textCase(.uppercase)
            .foregroundStyle(NeonColors.slate400)
            .multilineTextAlignment(.center)
    }
}

/// `.back-btn`: MAIN MENU.
struct BackToMainButton: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            app.menuMode = .main
        } label: {
            HStack(spacing: 8) {
                Icon(NeonIcon.back, size: 16)
                Text("MAIN MENU")
            }
        }
        .buttonStyle(BackButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
