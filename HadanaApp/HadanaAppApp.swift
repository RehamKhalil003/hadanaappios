import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct HadanaAppApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var lang   = LanguageManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {}

    var body: some Scene {
        WindowGroup {
            // LayoutDirection set ONCE here — all children inherit automatically.
            // Never set it again in any child view.
            RootView()
                .environmentObject(authVM)
                .environmentObject(lang)
                .environment(\.layoutDirection, lang.layoutDirection)
                .preferredColorScheme(.light)
        }
    }
}

/// Thin wrapper so environment updates (language toggle) propagate to the whole tree.
struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        ContentView()
            // Re-stamp direction so SwiftUI picks up changes when lang toggles
            .environment(\.layoutDirection, lang.layoutDirection)
    }
}
