import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, lang.layoutDirection)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
            }
        }
        // لو التطبيق كان مسكر وفُتح من إشعار — HomeView ما اتحمّل بعد — نحتاج نخزن الـ deep link
        // HomeView يلتقطه من authVM.pendingDeepLinkTab لما يظهر
        .onReceive(NotificationCenter.default.publisher(for: .parentNotificationTapped)) { notif in
            guard let info = notif.userInfo else { return }
            let type = info["type"] as? String ?? ""
            let sid  = info["session_id"] as? String ?? ""
            authVM.handleNotificationTap(type: type, sessionId: sid)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch authVM.authState {
        case .loggedOut:
            LoginView()

        case .loading:
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 20) {
                    AcademyLogoView(size: 100)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandPurple))
                        .scaleEffect(1.3)
                }
            }

        case .loggedIn:
            HomeView()
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager())
        .environment(\.layoutDirection, .rightToLeft)
}
