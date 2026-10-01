import SwiftUI

/// `#game-toast` (index.php, styles.css `.game-toast`): the cookie quest's
/// amber notice pill at the bottom centre of the playfield. It slides up
/// when a message appears and fades out when it clears.
struct GameToastView: View {
    let message: String?
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let message {
                Text(message)
                    .font(NeonFont.display(vSize == .compact ? 10 : 11, .black))
                    .tracking(1.3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color(css: "#1c1917"))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Capsule().fill(NeonColors.amber400))
                    .shadow(color: NeonColors.amber400.opacity(0.6), radius: 9)
                    .padding(.horizontal, 16)
                    .padding(.bottom, vSize == .compact ? 16 : 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.25), value: message)
    }
}
