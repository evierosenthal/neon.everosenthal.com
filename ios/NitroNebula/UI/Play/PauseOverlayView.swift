import SwiftUI

/// `#pause-screen` (index.php:720-732, styles.css:2849-2874).
struct PauseOverlayView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 500
            ZStack {
                NeonColors.scrim(0.6)
                    .background(.ultraThinMaterial)
                VStack(spacing: 0) {
                    Text("SUSPENDED")
                        .font(NeonFont.display(compact ? 44 : 72, .black))
                        .tracking(compact ? -2.2 : -3.6)
                        .foregroundStyle(.white)
                        .padding(.bottom, compact ? 8 : 16)
                    Text("Awaiting Further Orders")
                        .font(NeonFont.sans(10, .bold))
                        .italic()
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(NeonColors.indigo300)
                        .padding(.bottom, compact ? 20 : 48)
                    VStack(spacing: 12) {
                        Button("RESUME MISSION") { app.setPaused(false) }
                            .buttonStyle(.neonLarge(.indigo))
                        Button { app.returnToStart() } label: {
                            HStack(spacing: 12) {
                                Icon(NeonIcon.home, size: 20)
                                Text("RETURN TO HOME")
                            }
                        }
                        .buttonStyle(.neon(.muted))
                    }
                }
                .padding(compact ? 28 : 64)
                .glassPanel(cornerRadius: compact ? 32 : 48)
                .frame(maxWidth: 480)
                .padding(16)
            }
            .ignoresSafeArea()
        }
        .transition(.opacity)
    }
}
