import SwiftUI

/// `.difficulty-buttons` (ui.js:1264-1286): the 2x2 grid of launch buttons,
/// each wearing that tier's record and a LAST tag on the most recent launch.
struct DifficultyButtons: View {
    @Environment(AppState.self) private var app
    let mode: MissionMode

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Difficulty.all) { diff in
                let bestMode = GameMode.forMission(difficulty: diff.value, duo: mode == .local)
                let best = app.highScores[bestMode] ?? 0
                let isLast = app.lastMission.map { $0.diff == diff.value && $0.mode == mode } ?? false
                Button { app.startGame(difficulty: diff.value, mode: mode) } label: {
                    VStack(spacing: 3) {
                        HStack(spacing: 8) {
                            if diff.zap { ZapIcon() }
                            Text(diff.label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if diff.zap { ZapIcon() }
                        }
                        Text(best > 0 ? "BEST " + NumberFormat.integer(best) : "NO RECORD YET")
                            .font(NeonFont.sans(9, .bold))
                            .tracking(1.26)
                            .foregroundStyle(bestColor(diff, empty: best == 0))
                    }
                }
                .buttonStyle(NeonButtonStyle(variant: variant(diff), cornerRadius: 16,
                                             padding: EdgeInsets(top: 11, leading: 16, bottom: 10, trailing: 16),
                                             font: NeonFont.display(16, .black)))
                .overlay(alignment: .topTrailing) {
                    if isLast { LastTag() }
                }
                .accessibilityLabel(diff.label + (isLast ? ", last played" : ""))
                .accessibilityValue(best > 0 ? "Best \(best)" : "No record yet")
            }
        }
    }

    private func variant(_ d: Difficulty) -> NeonButtonStyle.Variant {
        switch d.variant {
        case .emerald: return .emerald
        case .indigo: return .indigo
        case .rose: return .rose
        case .superHard: return .superHard
        }
    }

    private func bestColor(_ d: Difficulty, empty: Bool) -> Color {
        if d.variant == .superHard { return NeonColors.rose400.opacity(empty ? 0.4 : 0.75) }
        return NeonColors.white(empty ? 0.4 : 0.72)
    }
}

/// `.btn.last-played::after`.
struct LastTag: View {
    var body: some View {
        Text("LAST")
            .font(NeonFont.display(8, .bold))
            .tracking(1.1)
            .foregroundStyle(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(NeonColors.white(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(NeonColors.white(0.25), lineWidth: 1))
            .padding(.top, 6)
            .padding(.trailing, 7)
            .allowsHitTesting(false)
    }
}

/// The pulsing lightning bolt on SUPER HARD.
struct ZapIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Icon(NeonIcon.zap, size: 20)
            .foregroundStyle(NeonColors.rose500)
            .opacity(dim ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}
