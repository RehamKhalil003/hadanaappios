import Foundation
import FirebaseMessaging
import LocalAuthentication

enum AuthState {
    case loggedOut
    case loading
    case loggedIn(User)
}

@MainActor
class AuthViewModel: ObservableObject {
    private static let defaultPhone = "0799709164"
    private static let defaultPassword = "password123"

    @Published var authState: AuthState = .loggedOut
    @Published var phoneNumber: String = AuthViewModel.defaultPhone
    @Published var password: String = AuthViewModel.defaultPassword
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var todaySessions: [SessionAPIModel] = []
    @Published var allSessions: [SessionAPIModel] = []
    @Published var sessionsByChild: [Int: [SessionAPIModel]] = [:]
    @Published var notifications: [AppNotification] = []

    // لما يضغط ولي الأمر على إشعار "تمت إضافة جلسات" — التايم لاين يقرأ هاي القيم وينتقل للطفل والتاريخ المطلوبين
    @Published var pendingTimelineChildId: Int? = nil
    @Published var pendingTimelineDate: Date? = nil

    // Deep link من الإشعار — tab + sessionId اختياري
    @Published var pendingDeepLinkTab: Int? = nil       // 0=رئيسية 1=تايملاين 2=إشعارات
    @Published var pendingDeepLinkSessionId: Int? = nil

    public let network = NetworkManager.shared

    init() {
        if network.isAuthenticated {
            Task { await checkAuth() }
        }
        NotificationCenter.default.addObserver(
            forName: .fcmTokenRefreshed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { try? await self?.network.updateFCMToken(token) }
        }
    }

    var isLoggedIn: Bool {
        if case .loggedIn = authState { return true }
        return false
    }

    // MARK: - Login

    func login(isArabic: Bool = true) {
        errorMessage = nil

        // Client-side validation
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)
        if phone.isEmpty && password.isEmpty {
            errorMessage = isArabic ? "يرجى تعبئة جميع الحقول" : "Please fill in all fields"
            return
        }
        if phone.isEmpty {
            errorMessage = isArabic ? "رقم الهاتف مطلوب" : "Phone number is required"
            return
        }
        if password.isEmpty {
            errorMessage = isArabic ? "كلمة المرور مطلوبة" : "Password is required"
            return
        }

        isLoading = true

        Task {
            do {
                let loginResp = try await network.login(phone: phoneNumber, password: password)
                let user = try await buildUser(from: loginResp.user)
                await self.sendFCMTokenToServer(userId: user.id)
                isLoading = false
                authState = .loggedIn(user)
                loadTodaySessions()
                loadNotifications()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                print("❌ LOGIN ERROR: \(error)")
                print("❌ LOGIN ERROR localized: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Face ID login

    func loginWithBiometrics(isArabic: Bool = true) {
        errorMessage = nil
        let context = LAContext()
        var evalError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) else {
            errorMessage = isArabic ? "بصمة الوجه غير متاحة على هذا الجهاز" : "Face ID is not available on this device"
            return
        }

        let reason = isArabic ? "سجّل الدخول باستخدام بصمة الوجه" : "Sign in using Face ID"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, policyError in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.login(isArabic: isArabic)
                } else if let policyError = policyError as NSError?, policyError.code != LAError.userCancel.rawValue {
                    self.errorMessage = policyError.localizedDescription
                }
            }
        }
    }

    // MARK: - Auto-login on launch

    func checkAuth() async {
        guard network.isAuthenticated else { return }
        authState = .loading
        do {
            let meResp = try await network.me()
            let user = try await buildUser(from: meResp)
            await sendFCMTokenToServer(userId: user.id)
            authState = .loggedIn(user)
            loadTodaySessions()
            loadNotifications()
        } catch {
            network.token = nil
            authState = .loggedOut
        }
    }

    // MARK: - Switch active child (local only)

    func switchChild(to childId: Int) {
        if case .loggedIn(var user) = authState {
            user.activeChildId = childId
            authState = .loggedIn(user)
        }
    }

    // MARK: - FCM Token

    private func sendFCMTokenToServer(userId: Int) async {
        guard let token = Messaging.messaging().fcmToken else { return }
        try? await network.updateFCMToken(token)
    }

    // MARK: - Logout

    func logout() {
        Task {
            try? await network.logout()
            try? await network.removeFCMToken()
            authState = .loggedOut
            phoneNumber = AuthViewModel.defaultPhone
            password = AuthViewModel.defaultPassword
            errorMessage = nil
        }
    }

    // MARK: - Load Today Sessions

    func loadTodaySessions() {
        guard case .loggedIn(let user) = authState else { return }
        let children = user.children
        guard !children.isEmpty else { return }
        Task {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.locale = Locale(identifier: "en_US_POSIX")
            let today = fmt.string(from: Date())
            var merged: [SessionAPIModel] = []
            for child in children {
                if let resp = try? await network.fetchSessions(childId: child.id) {
                    sessionsByChild[child.id] = resp.data
                    merged += resp.data.filter { $0.session_date == today }
                }
            }
            todaySessions = merged
            if let firstId = children.first?.id {
                allSessions = sessionsByChild[firstId] ?? []
            }
        }
    }

    func loadAllSessions() async {
        guard case .loggedIn(let user) = authState,
              let childId = user.activeChild?.id else { return }
        await loadSessions(for: childId)
    }

    func loadSessions(for childId: Int) async {
        do {
            print("📡 fetching sessions for childId=\(childId)")
            let resp = try await network.fetchSessions(childId: childId)
            print("✅ got \(resp.data.count) sessions for childId=\(childId)")
            sessionsByChild[childId] = resp.data
            if case .loggedIn(let user) = authState, user.activeChild?.id == childId {
                allSessions = resp.data
                let fmt2 = DateFormatter(); fmt2.dateFormat = "yyyy-MM-dd"; fmt2.locale = Locale(identifier: "en_US_POSIX")
                let today2 = fmt2.string(from: Date())
                todaySessions = resp.data.filter { $0.session_date == today2 }
            }
        } catch {
            print("❌ sessions error for childId=\(childId): \(error.localizedDescription)")
        }
    }

    func sessions(for childId: Int) -> [SessionAPIModel] {
        sessionsByChild[childId] ?? []
    }

    func session(withId id: Int) -> SessionAPIModel? {
        sessionsByChild.values.flatMap { $0 }.first { $0.id == id }
    }

    // MARK: - Deep Link من الإشعار

    func handleNotificationTap(type: String, sessionId: String) {
        let sid = Int(sessionId)
        switch type {
        case "session_start", "session_end", "specialist_note", "session_media":
            // فتح التايم لاين وتحديث البيانات
            pendingDeepLinkTab = 1
            pendingDeepLinkSessionId = sid
            // refresh الجلسات
            Task {
                if case .loggedIn(let user) = authState {
                    for child in user.children { await loadSessions(for: child.id) }
                }
                loadNotifications()
            }
        case "pickup", "dropoff":
            // فتح الرئيسية وتحديثها
            pendingDeepLinkTab = 0
            Task {
                if case .loggedIn(let user) = authState {
                    for child in user.children { await loadSessions(for: child.id) }
                }
                loadNotifications()
            }
        case "payment_due", "payment_received":
            pendingDeepLinkTab = 0
            loadNotifications()
        default:
            // admin_broadcast أو general — فتح الإشعارات
            pendingDeepLinkTab = 2
            loadNotifications()
        }
    }

    // MARK: - Notifications

    func loadNotifications() {
        Task {
            if let resp = try? await network.fetchNotifications() {
                notifications = resp.data.map { AppNotification(from: $0) }
            }
        }
    }

    func markNotificationRead(_ id: Int) {
        if let idx = notifications.firstIndex(where: { $0.id == id }), !notifications[idx].isRead {
            notifications[idx].isRead = true
        }
        Task { try? await network.markNotificationRead(id: id) }
    }

    func markAllNotificationsRead() {
        notifications.indices.forEach { notifications[$0].isRead = true }
        Task { try? await network.markAllNotificationsRead() }
    }

    // MARK: - Refresh Children

    func loadChildren() {
        Task {
            guard let meResp = try? await network.me() else { return }
            let refreshed = try? await buildUser(from: meResp)
            guard let refreshed else { return }
            await MainActor.run {
                if case .loggedIn(var user) = authState {
                    user = refreshed
                    authState = .loggedIn(user)
                }
            }
        }
    }

    @MainActor
    func reloadMe() async {
        guard let meResp = try? await network.me() else { return }
        let refreshed = try? await buildUser(from: meResp)
        guard let refreshed else { return }
        if case .loggedIn(var user) = authState {
            user = refreshed
            authState = .loggedIn(user)
        }
    }

    // MARK: - Helper

    private func buildUser(from me: MeResponse) async throws -> User {
        print("🔑 TOKEN: \(network.token ?? "nil")")
        print("👤 PARENT id=\(me.id) name=\(me.name)")
        let childrenResp = try await network.children()
        let children = childrenResp.data.map { c in
            Child(
                id: c.id,
                name: c.name,
                nurseryOnly: c.nursery_only,
                specialists: c.specialists.map { s in
                    ChildSpecialist(id: s.id, name: s.name, specialization: s.specialization ?? "")
                },
                arrivalTime: c.arrival_time,
                departureTime: c.departure_time,
                toiletReminder: c.toilet_reminder.map {
                    ToiletReminderInfo(
                        isActive: $0.is_active,
                        intervalMinutes: $0.interval_minutes,
                        startTime: $0.start_time,
                        endTime: $0.end_time
                    )
                }
            )
        }
        for c in children {
            print("👶 CHILD id=\(c.id) name=\(c.name)")
        }
        return User(
            id: me.id,
            name: me.name,
            phone: me.phone,
            carPhotoUrl: me.carPhoto.flatMap { URL(string: $0) != nil ? $0 : nil },
            children: children,
            activeChildId: children.first?.id ?? 0
        )
    }
}
