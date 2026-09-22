import Combine
import SwiftUI

/// `.daily-chest` (index.php:200-210, styles.css:789-870): bounces while a
/// claim is available, then counts down to local midnight.
struct DailyChestButton: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = Date()
    @State private var pops: [CoinPop] = []
    @State private var bounce = false
    /// Minute ticks for the countdown; one publisher per view, not per body.
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private struct CoinPop: Identifiable {
        let id = UUID()
        let dx: CGFloat
        let dy: CGFloat
        let delay: Double
    }

    var body: some View {
        let claimed = app.isDailyClaimed(now: now)
        Button {
            guard !claimed else { return }
            app.claimDaily()
            burst()
        } label: {
            VStack(spacing: 6) {
                ChestShape()
                    .frame(width: 52, height: 45.6)
                    .shadow(color: claimed ? .clear : NeonColors.amber400.opacity(0.6), radius: 7)
                    .offset(y: bounce ? -7 : 0)
                    .rotationEffect(.degrees(bounce ? -3 : 2))
                Text(Economy.chestLabel(claimed: claimed, now: now))
                    .font(NeonFont.display(9, .bold))
                    .tracking(1.1)
                    .foregroundStyle(NeonColors.amber400)
                    .neonGlow(NeonColors.amber400.opacity(0.4))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(8)
            .frame(minWidth: 88, minHeight: 44)
            .opacity(claimed ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(claimed)
        .overlay {
            ForEach(pops) { pop in
                CoinDot(size: 10)
                    .modifier(PopMotion(dx: pop.dx, dy: pop.dy, delay: pop.delay))
            }
        }
        .accessibilityLabel(claimed ? "Daily bonus claimed, next in \(Economy.untilMidnightLabel(now))" : "Claim daily bonus")
        .onReceive(minute) { date in now = date }
        .onAppear { startBounce(claimed: claimed) }
        .onChange(of: claimed) { _, c in startBounce(claimed: c) }
    }

    private func startBounce(claimed: Bool) {
        guard !claimed, !reduceMotion else { bounce = false; return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bounce = true }
    }

    /// claimDailyBonus's coin-pop burst (ui.js:1174-1182).
    private func burst() {
        pops = (0..<12).map { _ in
            CoinPop(dx: CGFloat.random(in: -70...70), dy: -CGFloat.random(in: 30...130), delay: Double.random(in: 0...0.15))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { pops = [] }
    }
}

private struct PopMotion: ViewModifier {
    let dx: CGFloat
    let dy: CGFloat
    let delay: Double
    @State private var flown = false

    func body(content: Content) -> some View {
        content
            .offset(x: flown ? dx : 0, y: flown ? dy - 6 : -6)
            .opacity(flown ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.85).delay(delay)) { flown = true } }
            .allowsHitTesting(false)
    }
}

/// The treasure chest SVG (index.php:201-208) in a 48x42 box.
struct ChestShape: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 48, size.height / 42)
            let t = CGAffineTransform(translationX: (size.width - 48 * s) / 2, y: (size.height - 42 * s) / 2).scaledBy(x: s, y: s)
            let dark = Color(css: "#78350f")
            let base = Path(roundedRect: CGRect(x: 4, y: 18, width: 40, height: 20), cornerRadius: 4).applying(t)
            ctx.fill(base, with: .color(Color(css: "#92400e")))
            ctx.stroke(base, with: .color(dark), lineWidth: 2 * s)
            var lid = Path()
            lid.move(to: CGPoint(x: 4, y: 22))
            lid.addQuadCurve(to: CGPoint(x: 24, y: 8), control: CGPoint(x: 4, y: 8))
            lid.addQuadCurve(to: CGPoint(x: 44, y: 22), control: CGPoint(x: 44, y: 8))
            lid.closeSubpath()
            let lidT = lid.applying(t)
            ctx.fill(lidT, with: .color(Color(css: "#b45309")))
            ctx.stroke(lidT, with: .color(dark), lineWidth: 2 * s)
            ctx.fill(Path(CGRect(x: 10, y: 9, width: 4, height: 29)).applying(t), with: .color(dark.opacity(0.55)))
            ctx.fill(Path(CGRect(x: 34, y: 9, width: 4, height: 29)).applying(t), with: .color(dark.opacity(0.55)))
            let latch = Path(roundedRect: CGRect(x: 20, y: 16, width: 8, height: 12), cornerRadius: 2).applying(t)
            ctx.fill(latch, with: .color(NeonColors.amber400))
            ctx.stroke(latch, with: .color(Color(css: "#b45309")), lineWidth: 1.5 * s)
            ctx.fill(Path(ellipseIn: CGRect(x: 22, y: 20, width: 4, height: 4)).applying(t), with: .color(dark))
        }
    }
}
