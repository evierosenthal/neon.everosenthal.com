import SwiftUI

/// The persistent top-left launcher (index.php:140-143, styles.css:343-392).
struct SettingsButton: View {
    @Environment(AppState.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        Button { app.openSettings() } label: {
            HStack(spacing: 8) {
                Icon(NeonIcon.settings, size: 18)
                    .foregroundStyle(NeonColors.cyan400)
                // `.settings-btn-text` hides at 640px and below; phones in
                // landscape are wider than that but the HUD only leaves room
                // for the icon, so the label is iPad-only (HUDMetrics.sideInset).
                if hSize == .regular && vSize == .regular {
                    Text("Settings")
                        .font(NeonFont.mono(12))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(NeonColors.slate200)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NeonColors.slate900.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(NeonColors.white(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Flight Control Settings")
    }
}
