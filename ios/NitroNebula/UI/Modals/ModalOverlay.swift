import SwiftUI

/// `.overlay-settings` + `.panel-settings` (styles.css:429-435, 2878-2944):
/// a dimmed, blurred full-screen scrim with a centred frosted panel that
/// scrolls inside when it is taller than the screen. Maps `app.modal` to
/// its view; the placeholder modals live in PendingModals.swift.
struct ModalOverlay: View {
    @Environment(AppState.self) private var app
    let modal: AppState.Modal

    var body: some View {
        ModalScaffold {
            switch modal {
            case .tailor: TailorModalView()
            case .auth: AuthModalView()
            case .leaderboard: LeaderboardModalView()
            case .friends: FriendsModalView()
            case .lobby: LobbyModalView()
            case .reset: ResetPasswordModalView()
            }
        }
    }
}

/// The scrim + panel shell shared by every modal (settings included).
struct ModalScaffold<Content: View>: View {
    var maxWidth: CGFloat = 512
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 500
            ZStack {
                NeonColors.scrim(0.75)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .padding(compact ? 20 : 32)
                        .frame(maxWidth: .infinity)
                        .glassPanel(cornerRadius: 24)
                        .frame(maxWidth: maxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .frame(minHeight: geo.size.height)
                }
            }
        }
        .transition(.opacity)
    }
}

/// `.settings-header`: icon box, title, subtitle and the close button.
struct ModalHeader<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let onClose: () -> Void
    @ViewBuilder var trailing: Trailing

    init(icon: String, title: String, subtitle: String, onClose: @escaping () -> Void,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.onClose = onClose
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Icon(icon, size: 20)
                .foregroundStyle(NeonColors.cyan400)
                .padding(10)
                .glassTile(cornerRadius: 12, fill: NeonColors.cyan500.opacity(0.1), border: NeonColors.cyan500.opacity(0.2))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NeonFont.display(20, .black))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .neonLabel(size: 10, color: NeonColors.slate400)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
            Button { onClose() } label: { Icon(NeonIcon.close, size: 20) }
                .buttonStyle(CloseButtonStyle())
                .accessibilityLabel("Close")
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(NeonColors.white(0.1)).frame(height: 1) }
        .padding(.bottom, 24)
    }
}

/// `.lb-section-head`: a ruled heading inside a modal.
struct SectionHead: View {
    let icon: String
    let text: String
    var first = false

    var body: some View {
        HStack(spacing: 8) {
            Icon(icon, size: 16)
            Text(text)
                .font(NeonFont.display(13, .bold))
                .tracking(1.3)
        }
        .foregroundStyle(NeonColors.indigo300)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, first ? 0 : 16)
        .overlay(alignment: .top) { if !first { Rectangle().fill(NeonColors.white(0.1)).frame(height: 1) } }
        .padding(.top, first ? 0 : 20)
        .padding(.bottom, 12)
    }
}
