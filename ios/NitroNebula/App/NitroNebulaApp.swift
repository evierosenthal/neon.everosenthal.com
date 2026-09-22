import SwiftUI

@main
struct NitroNebulaApp: App {
    @State private var app: AppState = {
        let state = AppState()
        #if DEBUG
        DebugLaunch.apply(to: state)
        #endif
        return state
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
