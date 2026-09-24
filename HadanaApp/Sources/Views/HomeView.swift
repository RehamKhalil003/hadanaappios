import SwiftUI

// MARK: - Main Tab Container
struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedTab = 0

    init() {
        // Tab bar: white bg, purple selected, light gray unselected
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.iconColor   = UIColor(red: 0.42, green: 0.31, blue: 0.63, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes   = [.foregroundColor: UIColor(red: 0.42, green: 0.31, blue: 0.63, alpha: 1)]
        let fadedPurple = UIColor(red: 0.78, green: 0.72, blue: 0.88, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor    = fadedPurple
        appearance.stackedLayoutAppearance.normal.titleTextAttributes     = [.foregroundColor: fadedPurple]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label(lang.t("الرئيسية", "Home"),
                          systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            TimelineView()
                .tabItem {
                    Label(lang.t("التايم لاين", "Timeline"),
                          systemImage: selectedTab == 1 ? "calendar" : "calendar")
                }
                .tag(1)

            NotificationsView(selectedTab: $selectedTab)
                .tabItem {
                    Label(lang.t("الإشعارات", "Notifications"),
                          systemImage: selectedTab == 2 ? "bell.fill" : "bell")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(lang.t("الإعدادات", "Settings"),
                          systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                }
                .tag(3)
        }
        .accentColor(.brandPurple)
        .environment(\.layoutDirection, lang.layoutDirection)
        .id(lang.isArabic)
        .onReceive(NotificationCenter.default.publisher(for: .parentNotificationTapped)) { notif in
            guard let info = notif.userInfo else { return }
            let type = info["type"] as? String ?? ""
            let sid  = info["session_id"] as? String ?? ""
            authVM.handleNotificationTap(type: type, sessionId: sid)
        }
        .onChange(of: authVM.pendingDeepLinkTab) { _, tab in
            guard let tab else { return }
            selectedTab = tab
            authVM.pendingDeepLinkTab = nil
        }
    }
}

// MARK: - Dashboard Nav Card
private struct DashNavCard: View {
    let icon: String; let title: String; let subtitle: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - Dashboard (Home Tab)
struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Binding var selectedTab: Int
    @State private var isRefreshing = false

    private var user: User? {
        if case .loggedIn(let u) = authVM.authState { return u }
        return nil
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? lang.t("صباح الخير", "Good Morning") : lang.t("مساء الخير", "Good Evening")
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Logo refresh indicator
                    if isRefreshing {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.brandPurple.opacity(0.2), radius: 6, x: 0, y: 3)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isRefreshing)
                    }

                    Color.clear.frame(height: 110)
                    todayCard
                    childrenArrivalCard
                    childStatusCard
                    navCards
                    toiletButton
                    recentActivity
                    nextSessionCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                isRefreshing = true
                authVM.loadTodaySessions()
                try? await Task.sleep(nanoseconds: 800_000_000)
                isRefreshing = false
            }
            .tint(Color.clear)

            headerView
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            authVM.loadTodaySessions()
            authVM.loadChildren()
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            // Greeting + child name
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                Text(lang.isArabic
                     ? "\(user?.name ?? "") مرحبا 👋"
                     : "Hello \(user?.name ?? "") 👋")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Logo
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.brandPurple.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 14)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var activeChild: Child? { user?.activeChild }

    // MARK: Children Arrival Card
    @ViewBuilder
    private var childrenArrivalCard: some View {
        let children = user?.children ?? []
        if children.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandPurple)
                    Text(lang.t("حالة الأطفال اليوم", "Children Status Today"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(children.filter { $0.arrivalTime != nil }.count)/\(children.count)")
                        .font(.caption.bold())
                        .foregroundColor(.brandPurple)
                }

                Divider()

                ForEach(children) { child in
                    HStack(spacing: 12) {
                        // أيقونة الحالة
                        ZStack {
                            Circle()
                                .fill(child.departureTime != nil ? Color.secondary.opacity(0.08)
                                      : child.arrivalTime != nil ? Color.brandGreen.opacity(0.12)
                                      : Color.secondary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: child.departureTime != nil ? "house.circle.fill"
                                  : child.arrivalTime != nil ? "checkmark.circle.fill"
                                  : "clock.fill")
                                .font(.system(size: 15))
                                .foregroundColor(child.departureTime != nil ? .secondary
                                                 : child.arrivalTime != nil ? .brandGreen
                                                 : .secondary.opacity(0.4))
                        }

                        // الاسم + مؤشر التذكير
                        HStack(spacing: 5) {
                            Text(child.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            if child.toiletReminder?.isActive == true {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        // الحالة
                        if let time = child.departureTimeFormatted {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(lang.t("غادر", "Left"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(time)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                        } else if let time = child.arrivalTimeFormatted {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(lang.t("وصل", "Arrived"))
                                    .font(.caption2)
                                    .foregroundColor(.brandGreen)
                                Text(time)
                                    .font(.caption.bold())
                                    .foregroundColor(.brandGreen)
                            }
                        } else {
                            Text(lang.t("لم يصل بعد", "Not arrived"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if child.id != children.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: Child Status Card
    @ViewBuilder
    private var childStatusCard: some View {
        if let child = activeChild {
            if child.isNurseryOnly {
                // حضانة فقط — بدون أخصائي
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.brandOrange.opacity(0.12)).frame(width: 48, height: 48)
                        Image(systemName: "house.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t("حضانة فقط", "Nursery Only"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.brandOrange)
                        Text(lang.t("لم يتم إسناد أخصائي لهذا الطفل بعد",
                                    "No specialist assigned yet"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.brandOrange.opacity(0.6))
                }
                .padding(16)
                .background(Color.brandOrange.opacity(0.06))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandOrange.opacity(0.25), lineWidth: 1))
                .shadow(color: Color.brandOrange.opacity(0.08), radius: 8, x: 0, y: 3)
            } else {
                // أطفال مع أخصائيين — عرض قائمة التخصصات
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandPurple)
                        Text(lang.t("الأخصائيون المعيّنون", "Assigned Specialists"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(child.specialists.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandPurple)
                            .cornerRadius(10)
                    }
                    Divider()
                    ForEach(child.specialists) { sp in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.brandPurple.opacity(0.10)).frame(width: 36, height: 36)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.brandPurple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.isArabic ? sp.name : sp.nameEn)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(lang.isArabic ? sp.specialty : sp.specialtyEn)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
        }
    }

    // MARK: Nav Cards Grid
    private var navCards: some View {
        DashNavCardsGrid(lang: lang, selectedTab: $selectedTab)
    }

    // MARK: Today Summary Card
    private var todayCard: some View {
        TodayStatsCard(
            lang: lang,
            sessionCount: authVM.todaySessions.count,
            completedCount: authVM.todaySessions.filter { $0.status == "completed" }.count,
            arrivalTime: user?.activeChild?.arrivalTimeFormatted
        )
    }

    // MARK: Next Session Card
    private var nextSessionCard: some View {
        let next = authVM.todaySessions.first { $0.status == "pending" }
        return NextSessionCard(lang: lang, session: next)
    }

    private var toiletButton: some View {
        let reminder = user?.activeChild?.toiletReminder
        return ToiletReminderRow(lang: lang, reminder: reminder)
    }

    private var recentActivity: some View {
        TodaySessionsListCard(lang: lang, sessions: authVM.todaySessions)
    }

}

// MARK: - Dashboard Nav Cards Grid
struct DashNavCardsGrid: View {
    let lang: LanguageManager
    @Binding var selectedTab: Int
    @State private var showContact = false
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                DashNavCard(icon: "calendar", title: lang.t("التايم لاين", "Timeline"),
                            subtitle: lang.t("أحداث اليوم", "Today's Events"), color: .brandBlue)   { selectedTab = 1 }
                DashNavCard(icon: "bell",     title: lang.t("الإشعارات", "Notifications"),
                            subtitle: lang.t("آخر التحديثات", "Latest Updates"), color: .brandMagenta) { selectedTab = 2 }
                DashNavCard(icon: "gearshape", title: lang.t("الإعدادات", "Settings"),
                            subtitle: lang.t("معلومات وتذكيرات", "Info & Reminders"), color: .brandOrange) { selectedTab = 3 }
                DashNavCard(icon: "envelope.fill", title: lang.t("تواصل معنا", "Contact Us"),
                            subtitle: lang.t("أرسل رسالة", "Send a message"), color: .brandGreen) { showContact = true }
            }
            .navigationDestination(isPresented: $showContact) {
                ContactFormView().environmentObject(lang)
            }
        }
    }
}

// MARK: - Today Sessions List Card
struct TodaySessionsListCard: View {
    let lang: LanguageManager
    let sessions: [SessionAPIModel]

    var body: some View {
        if sessions.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("جلسات اليوم", "Today's Sessions"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, s in
                        SessionRow(lang: lang, session: s)
                        if idx < sessions.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            }
        }
    }
}

private struct SessionRow: View {
    let lang: LanguageManager
    let session: SessionAPIModel

    private var icon: String {
        switch session.status {
        case "completed": return "✅"
        case "started":   return "🔵"
        default:          return "🕐"
        }
    }
    private var dotColor: Color {
        switch session.status {
        case "completed": return .brandGreen
        case "started":   return .brandBlue
        default:          return .secondary
        }
    }
    private var displayTime: String { String(session.session_time.prefix(5)) }
    private var title: String {
        let spec = session.specialization ?? lang.t("جلسة", "Session")
        return lang.t("جلسة \(spec)", "\(spec) Session")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(dotColor.opacity(0.15)).frame(width: 40, height: 40)
                Text(icon).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(session.specialist.name)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(displayTime)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Toilet Reminder Row
struct ToiletReminderRow: View {
    let lang: LanguageManager
    let reminder: ToiletReminderInfo?

    private var isActive: Bool { reminder?.isActive == true }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "bell.fill" : "bell.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isActive ? .brandPurple : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("تذكير دورة المياه 🚽", "Toilet Reminder 🚽"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                if let r = reminder, r.isActive {
                    Text(lang.t(
                        "كل \(r.intervalMinutes) دقيقة · \(r.startTime) - \(r.endTime)",
                        "Every \(r.intervalMinutes) min · \(r.startTime) - \(r.endTime)"
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(isActive
                 ? lang.t("مفعّل ✅", "Active ✅")
                 : lang.t("غير فعّال", "Inactive"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? .brandGreen : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isActive ? Color.brandPurple.opacity(0.4) : Color(.systemGray5), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Next Session Card
struct NextSessionCard: View {
    let lang: LanguageManager
    let session: SessionAPIModel?

    var body: some View {
        if let s = session {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.brandBlue.opacity(0.12)).frame(width: 50, height: 50)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.brandBlue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("الجلسة القادمة", "Next Session"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    let spec = s.specialization ?? lang.t("جلسة", "Session")
                    Text(lang.t("جلسة \(spec) - \(String(s.session_time.prefix(5)))",
                                "\(spec) - \(String(s.session_time.prefix(5)))"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(lang.t("مع \(s.specialist.name)", "With \(s.specialist.name)"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Today Stats Card
struct TodayStatsCard: View {
    let lang: LanguageManager
    var sessionCount: Int = 0
    var completedCount: Int = 0
    var arrivalTime: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            statItem(value: "\(sessionCount)",
                     label: lang.t("جلسات اليوم", "Sessions Today"),
                     color: .brandBlue, icon: "calendar")
            Divider().frame(height: 44)
            statItem(value: arrivalTime ?? "--:--",
                     label: lang.t("وقت الوصول", "Arrival Time"),
                     color: arrivalTime != nil ? .brandGreen : .secondary,
                     icon: "clock")
            Divider().frame(height: 44)
            statItem(value: "\(completedCount)",
                     label: lang.t("منجز", "Completed"),
                     color: .brandOrange, icon: "checkmark.seal.fill")
        }
        .padding(.vertical, 18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func statItem(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable StatChip
struct StatChip: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(color)
            }
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10))
        .cornerRadius(14)
    }
}

// MARK: - Reusable ActivityRow
struct ActivityRow: View {
    let icon: String; let dotColor: Color; let title: String; let time: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(dotColor.opacity(0.15)).frame(width: 40, height: 40)
                Text(icon).font(.system(size: 18))
            }
            Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
            Spacer()
            Text(time).font(.system(size: 13)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager())
        .environment(\.layoutDirection, .rightToLeft)
}
