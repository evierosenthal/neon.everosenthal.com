import SwiftUI
import NitroEngine

/// `.home-rocket` (styles.css:1067-1091): the equipped skin bobbing beside
/// the title.
struct HomeRocket: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        GearPreview(tab: .skins, id: app.loadout1.skin)
            .frame(width: 52, height: 83)
            .shadow(color: NeonColors.cyan400.opacity(0.45), radius: 6)
            .offset(y: bob ? -9 : 0)
            .rotationEffect(.degrees(bob ? 4 : -4))
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}
