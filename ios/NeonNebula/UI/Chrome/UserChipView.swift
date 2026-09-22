import SwiftUI

/// Top right: the logged-in pilot chip (index.php:75-79) or the login
/// button (L82). Both hide during play; the login button also hides on the
/// celebration screen, which has its own login flow (ui.js:1228-1240).
struct UserChipView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let user = app.session.user {
            HStack(spacing: 10) {
                Text(user.roleLabel)
                    .neonLabel(size: 10, color: NeonColors.slate500)
                Text(user.username)
                    .font(NeonFont.display(12, .bold))
                    .foregroundStyle(NeonColors.cyan400)
                    .lineLimit(1)
                Button("Logout") { app.logout() }
                    .font(NeonFont.sans(11, .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(NeonColors.slate400)
                    .underline()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .chipBackground()
        } else if app.phase != .newHigh {
            LoginButton()
        }
    }
}

/// "LOG IN" for returning pilots, "CREATE AN ACCOUNT" for first-timers.
struct LoginButton: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.openModal(.auth) } label: {
            Text(app.hasAccount ? "LOG IN" : "CREATE AN ACCOUNT")
                .font(NeonFont.display(12, .bold))
                .tracking(0.7)
                .foregroundStyle(NeonColors.cyan400)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .chipBackground()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// `.user-chip`: the dark frosted corner pill.
    func chipBackground() -> some View {
        self.background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NeonColors.slate900.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(NeonColors.white(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 10)
    }
}
