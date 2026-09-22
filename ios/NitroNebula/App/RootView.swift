import SwiftUI
import NeonEngine

/// The single screen stack, in index.php order: nebula → canvas + HUD →
/// start / game over / new high → pause → modals → settings → the corner
/// buttons. The canvas ignores the safe area; everything else respects it.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var vSize
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            NebulaBackground()

            if app.phase == .playing {
                GeometryReader { geo in
                    GameCanvasView(engine: app.engine,
                                   controlLayout: app.isLocalMultiplayer ? .split : .single,
                                   isPaused: app.isPaused,
                                   onTick: { app.flushTick() })
                        .onAppear { app.canvasDidLayout(size: geo.size) }
                        .onChange(of: geo.size) { _, size in app.canvasDidLayout(size: size) }
                        .onDisappear { app.canvasDidDisappear() }
                }
                .ignoresSafeArea()
                HUDView()
                    .allowsHitTesting(!app.isPaused)
            }

            switch app.phase {
            case .start: StartScreenView()
            case .gameOver: GameOverView()
            case .newHigh: NewHighScoreView()
            case .playing: EmptyView()
            }

            if app.phase == .playing && app.isPaused {
                PauseOverlayView()
            }

            if let modal = app.modal {
                ModalOverlay(modal: modal)
            }

            if app.isSettingsOpen {
                SettingsModalView()
            }

            // The corner launchers (`.settings-btn` / `.user-chip` at 1.25rem).
            // Phones in landscape use the HUD's tighter 12pt inset so the gear
            // lines up with the slim bar beside it.
            if !app.anyModalOpen {
                VStack {
                    HStack(alignment: .top) {
                        SettingsButton()
                        Spacer()
                        if !app.isPlaying {
                            UserChipView()
                        }
                    }
                    .padding(vSize == .compact ? 12 : 20)
                    Spacer()
                }
            }

            if let notice = app.notice {
                NoticeToast(text: notice) { app.notice = nil }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.phase)
        .animation(.easeInOut(duration: 0.2), value: app.modal)
        .animation(.easeInOut(duration: 0.2), value: app.isSettingsOpen)
        .animation(.easeInOut(duration: 0.2), value: app.isPaused)
        .background(NeonColors.slate950)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.return) { app.enterPressed() ? .handled : .ignored }
        .onKeyPress(.escape) { app.escapePressed() ? .handled : .ignored }
        .onAppear { focused = true }
        .onChange(of: scenePhase) { _, phase in app.scenePhaseChanged(phase) }
        .task { await app.bootstrapSession() }
        .onOpenURL { url in app.google.handle(url: url) }
        .persistentSystemOverlays(.hidden)
    }
}

/// A brief toast for `app.notice`.
struct NoticeToast: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(NeonFont.sans(13, .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .glassPanel(cornerRadius: 12)
                .padding(.bottom, 24)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(3))
            dismiss()
        }
    }
}
