import SwiftUI

// MARK: - Models
enum NotifType {
    case arrival, sessionStart, sessionEnd, specialistNote, sessionMedia, sessionsAdded, sessionUpdated
    case pickup, dropoff, adminBroadcast, general

    init(rawType: String) {
        switch rawType {
        case "pickup":                          self = .pickup
        case "dropoff":                         self = .dropoff
        case "admin_broadcast":                 self = .adminBroadcast
        case "arrival":                         self = .arrival
        case "sessionStart", "session_start":   self = .sessionStart
        case "sessionEnd", "session_end":       self = .sessionEnd
        case "specialistNote", "specialist_note": self = .specialistNote
        case "sessionMedia", "session_media":   self = .sessionMedia
        case "sessionsAdded", "sessions_added": self = .sessionsAdded
        case "sessionUpdated", "session_updated": self = .sessionUpdated
        default:                                self = .general
        }
    }

    // إشعارات فيها جلسة مرتبطة → الضغط عليها ينقل لتفاصيل الجلسة
    var opensSessionDetail: Bool {
        switch self {
        case .sessionStart, .sessionEnd, .specialistNote, .sessionMedia, .sessionUpdated: return true
        default: return false
        }
    }

    // إشعار إضافة جلسات → الضغط عليه ينقل لشاشة التايم لاين على الطفل والتاريخ
    var opensTimeline: Bool { self == .sessionsAdded }

    var icon: String {
        switch self {
        case .arrival, .pickup: return "figure.walk.arrival"
        case .dropoff:          return "house.fill"
        case .sessionStart:     return "play.circle.fill"
        case .sessionEnd:       return "checkmark.circle.fill"
        case .specialistNote:   return "bubble.left.fill"
        case .sessionMedia:     return "photo.fill"
        case .sessionsAdded:    return "calendar.badge.plus"
        case .sessionUpdated:   return "pencil.circle.fill"
        case .adminBroadcast:   return "megaphone.fill"
        case .general:          return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .arrival, .pickup: return .brandGreen
        case .dropoff:          return .brandBlue
        case .sessionStart:     return .brandBlue
        case .sessionEnd:       return .brandOrange
        case .specialistNote:   return .brandPurple
        case .sessionMedia:     return .brandPurple
        case .sessionsAdded:    return .brandBlue
        case .sessionUpdated:   return .brandOrange
        case .adminBroadcast:   return .brandMagenta
        case .general:          return .brandPurple
        }
    }
}

struct AppNotification: Identifiable {
    let id: Int
    let type: NotifType
    let title: String
    let titleEn: String
    let body: String
    let bodyEn: String
    let time: String
    let specialist: String?
    let specialistEn: String?
    let sessionId: Int?
    let childId: Int?
    let dateString: String?
    var isRead: Bool = false

    init(from api: NotificationAPIModel) {
        id = api.id
        type = NotifType(rawType: api.type)
        title = api.title
        titleEn = api.title
        body = api.body
        bodyEn = api.body
        time = AppNotification.formatTime(api.created_at)
        specialist = nil
        specialistEn = nil
        sessionId = api.data?.session_id
        childId = api.data?.child_id
        dateString = api.data?.date
        isRead = api.is_read
    }

    private static func formatTime(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }

        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "h:mm a"
            return f.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "أمس"
        } else {
            let f = DateFormatter(); f.dateFormat = "d/M"
            return f.string(from: date)
        }
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Binding var selectedTab: Int
    @State private var selectedSession: TimelineSession?

    private var notifications: [AppNotification] { authVM.notifications }
    private var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Divider()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(notifications.enumerated()), id: \.element.id) { idx, notif in
                                NotifRow(notif: notif) {
                                    authVM.markNotificationRead(notif.id)
                                    openSessionIfNeeded(for: notif)
                                    openTimelineIfNeeded(for: notif)
                                }
                                if idx < notifications.count - 1 { Divider().padding(.leading, 70) }
                            }
                        }
                        .background(Color.white)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .refreshable { authVM.loadNotifications() }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(session: session)
                    .environmentObject(authVM)
            }
        }
        .environment(\.layoutDirection, lang.layoutDirection)
        .id(lang.isArabic)
        .task {
            authVM.loadNotifications()
            authVM.loadTodaySessions()
        }
    }

    private func openSessionIfNeeded(for notif: AppNotification) {
        guard notif.type.opensSessionDetail, let sessionId = notif.sessionId else { return }
        if let api = authVM.session(withId: sessionId), let session = timelineSession(from: api) {
            selectedSession = session
        }
    }

    private func openTimelineIfNeeded(for notif: AppNotification) {
        guard notif.type.opensTimeline, let childId = notif.childId else { return }
        authVM.pendingTimelineChildId = childId
        if let dateString = notif.dateString {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            authVM.pendingTimelineDate = f.date(from: dateString)
        }
        selectedTab = 1
    }

    private var topBar: some View {
        HStack {
            Text(lang.t("الإشعارات", "Notifications"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.brandPurple)
                    .clipShape(Capsule())
            }
            Spacer()
            if unreadCount > 0 {
                Button(lang.t("قراءة الكل", "Mark all read")) {
                    withAnimation { authVM.markAllNotificationsRead() }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.brandPurple)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16).padding(.bottom, 14)
        .background(Color.white)
    }
}

// MARK: - Notification Row
private struct NotifRow: View {
    let notif: AppNotification
    let onTap: () -> Void
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    Circle().fill(notif.type.color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: notif.type.icon)
                        .font(.system(size: 18)).foregroundColor(notif.type.color)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(lang.t(notif.title, notif.titleEn))
                            .font(.system(size: 14, weight: notif.isRead ? .medium : .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(notif.time)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(lang.t(notif.body, notif.bodyEn))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let spec = lang.isArabic ? notif.specialist : notif.specialistEn {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill").font(.system(size: 10)).foregroundColor(notif.type.color)
                            Text(spec).font(.system(size: 11, weight: .medium)).foregroundColor(notif.type.color)
                        }
                    }
                }

                if !notif.isRead {
                    Circle().fill(Color.brandPurple).frame(width: 8, height: 8).padding(.top, 6)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(notif.isRead ? Color.white : Color.brandPurple.opacity(0.03))
        }
    }
}

#Preview {
    NotificationsView(selectedTab: .constant(2))
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager())
        .environment(\.layoutDirection, .rightToLeft)
}
