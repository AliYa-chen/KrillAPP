import SwiftUI

@main
struct KrillApp: App {
    @State private var store = AppStore()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isRestoring {
                    ZStack {
                        KrillBackground()
                        VStack(spacing: 22) {
                            KrillMark(size: 68)
                            ProgressView().tint(KrillTheme.cyan)
                        }
                    }
                } else if store.isAuthenticated {
                    DashboardView(store: store)
                } else {
                    LoginView(store: store)
                }
            }
            .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
            .tint(KrillTheme.accent)
            .task {
                if ProcessInfo.processInfo.arguments.contains("--demo") {
                    store.enterDemo()
                } else {
                    await store.restoreSession()
                }
            }
        }
    }
}
