import SwiftUI

/// `#newhigh-screen` (index.php:432-517, styles.css:2278-2411). The `.none`
/// phase is the plain local celebration; the other phases carry the score
/// to the leaderboard (`NewHighPhaseView`).
struct NewHighScoreView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        EndScreenScaffold(borderColor: NeonColors.cyan400.opacity(0.3), topline: NeonColors.cyan400.opacity(0.6),
                          backdrop: { FireworksView() }) { compact in
            VStack(spacing: 0) {
                Text((app.pendingMode ?? app.currentMode).label)
                    .font(NeonFont.display(14, .bold))
                    .tracking(4.9)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NeonColors.amber400)
                    .neonGlow(NeonColors.amber400.opacity(0.5), radius: 10)
                    .padding(.bottom, 12)
                Text("NEW HIGH SCORE!")
                    .font(NeonFont.display(compact ? 34 : 48, .black))
                    .tracking(compact ? -0.7 : -1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(LinearGradient(colors: [NeonColors.cyan400, NeonColors.emerald400], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: glow ? NeonColors.emerald400.opacity(0.8) : NeonColors.cyan400.opacity(0.5), radius: glow ? 9 : 3)
                    .padding(.bottom, 8)
                Text("Galactic Record Broken")
                    .font(NeonFont.sans(10, .bold))
                    .tracking(4)
                    .textCase(.uppercase)
                    .foregroundStyle(NeonColors.cyan300.opacity(0.8))
                    .padding(.bottom, compact ? 16 : 24)

                ScoreCard(compact: compact) {
                    Text("Your New Record").scoreCardLabel()
                    GradientNumber(text: NumberFormat.integer(app.pendingScore ?? app.score), size: compact ? 44 : 60,
                                   colors: [.white, NeonColors.cyan400])
                    Text("+\(NumberFormat.integer(app.earnedCoins)) COINS — \(Economy.recordCoinMultiplier)× RECORD BONUS!")
                        .font(NeonFont.display(compact ? 13 : 16, .black))
                        .foregroundStyle(NeonColors.amber400)
                        .neonGlow(NeonColors.amber400.opacity(0.5), radius: 10)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .padding(.bottom, compact ? 16 : 24)

                NewHighPhaseView()
                    .padding(.bottom, compact ? 16 : 24)

                EndButtons()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// The phase area under the score card (index.php:445-500, ui.js:1391-1464):
/// the inline login offer, the register / forgot forms, the transmitting
/// line and the rank + top 10 result.
struct NewHighPhaseView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        switch app.newHighPhase {
        case .none:
            EmptyView()
        case .offer:
            VStack(spacing: 12) {
                Text("Log in to put your name on the leaderboard").newHighTagline()
                if app.session.offline { OfflineNotice() }
                SocialSignInButtons()
                LoginForm(submitLabel: "LOG IN & SAVE SCORE")
                HStack(spacing: 20) {
                    Button("Create account") { app.newHighAction(.register) }
                    Button("Forgot password?") { app.newHighAction(.forgot) }
                }
                .buttonStyle(LinkButtonStyle())
                Button("Skip") { app.newHighAction(.skip) }
                    .font(NeonFont.sans(12))
                    .foregroundStyle(NeonColors.slate500)
                    .underline()
            }
            .frame(maxWidth: 352)
        case .register:
            VStack(spacing: 12) {
                Text("Create an account to save your score").newHighTagline()
                RegisterForm(submitLabel: "CREATE ACCOUNT & SAVE")
                Button("Back to log in") { app.newHighAction(.backToLogin) }
                    .buttonStyle(LinkButtonStyle())
            }
            .frame(maxWidth: 352)
        case .forgot:
            VStack(spacing: 12) {
                Text("We'll email you a reset link").newHighTagline()
                ForgotForm()
                Button("Back to log in") { app.newHighAction(.backToLogin) }
                    .buttonStyle(LinkButtonStyle())
            }
            .frame(maxWidth: 352)
        case .submitting:
            HStack(spacing: 12) {
                ProgressView().tint(NeonColors.cyan400)
                Text("TRANSMITTING TO COMMAND…")
                    .font(NeonFont.display(13, .bold))
                    .tracking(1.3)
                    .foregroundStyle(NeonColors.cyan400)
                    .neonGlow(NeonColors.cyan400.opacity(0.5), radius: 10)
            }
        case .result:
            VStack(spacing: 12) {
                if !app.newHighRankText.isEmpty {
                    Text(app.newHighRankText)
                        .font(NeonFont.display(16, .black))
                        .tracking(1.6)
                        .foregroundStyle(NeonColors.amber400)
                        .neonGlow(NeonColors.amber400.opacity(0.5), radius: 12)
                        .multilineTextAlignment(.center)
                }
                if !app.newHighRows.isEmpty {
                    LeaderboardList(rows: app.newHighRows, me: app.session.user?.username, compact: true)
                }
                FormError(message: app.newHighSubmitError)
                if app.newHighCanRetry {
                    Button("RETRY TRANSMISSION") { app.newHighAction(.retry) }
                        .buttonStyle(.neonSmall(.muted))
                }
            }
            .frame(maxWidth: 352)
        }
    }
}

private extension View {
    func newHighTagline() -> some View {
        self.font(NeonFont.sans(13, .semibold))
            .tracking(0.65)
            .foregroundStyle(NeonColors.slate300)
            .multilineTextAlignment(.center)
    }
}
