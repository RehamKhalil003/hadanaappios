import SwiftUI
import AVKit

// MARK: - Models
struct SessionMedia: Identifiable {
    let id = UUID()
    let isVideo: Bool
    let url: String
    let color: Color
}

struct TimelineSession: Identifiable {
    let id = UUID()
    let sessionId: Int
    let title: String
    let titleEn: String
    let specialist: String
    let specialistEn: String
    let startTime: Date
    let durationMinutes: Int
    let goal: String
    let goalEn: String
    let nextGoal: String
    let nextGoalEn: String
    let achieved: String
    let achievedEn: String
    let media: [SessionMedia]
    var apiStatus: String? = nil
    var startedAt: Date? = nil
    var remainingMinutes: Int? = nil
    var approvedNotes: [String] = []

    var endTime: Date { startTime.addingTimeInterval(Double(durationMinutes) * 60) }
}

extension TimelineSession: Hashable {
    static func == (lhs: TimelineSession, rhs: TimelineSession) -> Bool { lhs.sessionId == rhs.sessionId }
    func hash(into hasher: inout Hasher) { hasher.combine(sessionId) }

    // الحالة الحقيقية جاية من الأخصائي: "جارية" فقط لو بدأها فعلياً (startedAt)، و"منتهية" فقط لو status == completed
    // من السيرفر (إنهاء يدوي أو auto-complete بعد ما تُبدأ) — مش من مقارنة الساعة بوقت الجلسة المجدول.
    var status: TimelineSessionStatus {
        if apiStatus == "completed" || apiStatus == "cancelled" || apiStatus == "absent" { return .completed }
        if startedAt != nil { return .active }
        return .upcoming
    }


}

enum TimelineSessionStatus {
    case upcoming, active, completed

    var label: (String, String) {
        switch self {
        case .upcoming:  return ("قادمة", "Upcoming")
        case .active:    return ("جارية", "Active")
        case .completed: return ("منتهية", "Completed")
        }
    }
    var color: Color {
        switch self {
        case .upcoming:  return .brandOrange
        case .active:    return .brandGreen
        case .completed: return .brandBlue
        }
    }
    var icon: String {
        switch self {
        case .upcoming:  return "clock"
        case .active:    return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}


// MARK: - API → TimelineSession Conversion (مشتركة بين Timeline والإشعارات)

func timelineSession(from s: SessionAPIModel, on date: Date) -> TimelineSession? {
    func parseTime(_ str: String, on base: Date) -> Date? {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base)
    }
    guard let start = parseTime(s.session_time, on: date) else { return nil }
    let end: Date
    if let timeTo = s.session_time_to, let e = parseTime(timeTo, on: date) {
        end = e
    } else {
        end = start.addingTimeInterval(45 * 60)
    }
    let duration = max(1, Int(end.timeIntervalSince(start) / 60))

    let goal = s.goal ?? ""
    let media = s.media.map { item in
        SessionMedia(isVideo: item.type == "video", url: item.url, color: .brandPurple.opacity(0.15))
    }

    return TimelineSession(
        sessionId: s.id,
        title: s.specialization ?? "",
        titleEn: s.specialization ?? "",
        specialist: s.specialist.name,
        specialistEn: s.specialist.name,
        startTime: start,
        durationMinutes: duration,
        goal: goal, goalEn: goal,
        nextGoal: "", nextGoalEn: "",
        achieved: "", achievedEn: "",
        media: media,
        apiStatus: s.status,
        startedAt: parseISODate(s.started_at),
        remainingMinutes: s.remaining_minutes,
        approvedNotes: s.notes.map { $0.text }
    )
}

func timelineSession(from s: SessionAPIModel) -> TimelineSession? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    guard let date = formatter.date(from: s.session_date) else { return nil }
    return timelineSession(from: s, on: date)
}

private func parseISODate(_ str: String?) -> Date? {
    guard let str else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: str) ?? ISO8601DateFormatter().date(from: str)
}

// MARK: - Main Timeline View
struct TimelineView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedDate = Date()
    @State private var selectedChildId: Int? = nil
    @State private var sessions: [TimelineSession] = []
    @State private var selectedSession: TimelineSession? = nil
    @State private var showDetail = false
    @State private var isLoading = false

    private var children: [Child] {
        if case .loggedIn(let user) = authVM.authState { return user.children }
        return []
    }

    private var effectiveChildId: Int? {
        selectedChildId ?? children.first?.id
    }

    private let weekDates: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -3 + $0, to: today) }
            .filter { cal.component(.weekday, from: $0) != 6 }
    }()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    if children.count > 1 { childPicker }
                    weekStrip
                    Divider()
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView()
                                    .padding(.top, 60)
                            } else {
                                ForEach(sessions) { session in
                                    TimelineSessionCard(session: session) {
                                        selectedSession = session
                                        showDetail = true
                                    }
                                }
                                if sessions.isEmpty && !isLoading { emptyState }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        if let cid = effectiveChildId {
                            await authVM.loadSessions(for: cid)
                        }
                        sessions = buildSessions(for: selectedDate)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                        .environmentObject(lang)
                        .environmentObject(authVM)
                }
            }
        }
        .environment(\.layoutDirection, lang.layoutDirection)
        .id(lang.isArabic)
        .onAppear {
            guard let cid = effectiveChildId else { return }
            isLoading = true
            Task {
                await authVM.loadSessions(for: cid)
                sessions = buildSessions(for: selectedDate)
                isLoading = false
            }
        }
        .onChange(of: selectedDate) { _, date in sessions = buildSessions(for: date) }
        .onChange(of: selectedChildId) { _, _ in
            guard let cid = effectiveChildId else { return }
            isLoading = true
            Task {
                await authVM.loadSessions(for: cid)
                sessions = buildSessions(for: selectedDate)
                isLoading = false
            }
        }
        .onChange(of: authVM.sessionsByChild) { _, _ in
            sessions = buildSessions(for: selectedDate)
            // حدّث selectedSession لو كان مفتوحاً لنفس الجلسة
            if let current = selectedSession,
               let fresh = sessions.first(where: { $0.sessionId == current.sessionId }) {
                selectedSession = fresh
            }
            // deep link: افتح الجلسة المطلوبة بعد refresh
            if let id = authVM.pendingDeepLinkSessionId,
               let target = sessions.first(where: { $0.sessionId == id }) {
                selectedSession = target
                showDetail = true
                authVM.pendingDeepLinkSessionId = nil
            }
        }
        .onChange(of: authVM.pendingDeepLinkSessionId) { _, id in
            guard let id else { return }
            if let target = sessions.first(where: { $0.sessionId == id }) {
                selectedSession = target
                showDetail = true
                authVM.pendingDeepLinkSessionId = nil
            }
        }
        .onChange(of: authVM.pendingTimelineChildId) { _, _ in applyPendingTimelineTarget() }
    }

    // يُستدعى لما يضغط ولي الأمر على إشعار "تمت إضافة جلسات" — ينقل التايم لاين لنفس الطفل والتاريخ
    private func applyPendingTimelineTarget() {
        guard let childId = authVM.pendingTimelineChildId else { return }
        selectedChildId = childId
        if let date = authVM.pendingTimelineDate { selectedDate = date }
        authVM.pendingTimelineChildId = nil
        authVM.pendingTimelineDate = nil
    }

    private func buildSessions(for date: Date) -> [TimelineSession] {
        guard let cid = effectiveChildId else {
            print("🔴 buildSessions: effectiveChildId = nil")
            return []
        }
        let base = Calendar.current.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateKey = formatter.string(from: date)
        let raw = authVM.sessions(for: cid)
        let filtered = raw.filter { $0.session_date == dateKey }
        print("🔵 buildSessions: cid=\(cid) dateKey=\(dateKey) raw=\(raw.count) filtered=\(filtered.count)")
        return filtered
            .compactMap { s in sessionFromAPI(s, date: base) }
            .sorted { $0.startTime < $1.startTime }
    }

    private func sessionFromAPI(_ s: SessionAPIModel, date: Date) -> TimelineSession? {
        timelineSession(from: s, on: date)
    }

    private var topBar: some View {
        HStack {
            Text(lang.t("التايم لاين", "Timeline"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer()
            Text(formattedMonth)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16).padding(.bottom, 12)
        .background(Color.white)
    }

    private var childPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(children) { child in
                    let isSelected = child.id == (selectedChildId ?? children.first?.id)
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedChildId = child.id
                        }
                    } label: {
                        Text(child.name)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .white : .brandPurple)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.brandPurple : Color.brandPurple.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                DayPill(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)) {
                    withAnimation(.spring(response: 0.3)) { selectedDate = date }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 44)).foregroundColor(.secondary.opacity(0.4))
            Text(lang.t("لا توجد جلسات هذا اليوم", "No sessions today")).font(.system(size: 16)).foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }

    private var formattedMonth: String {
        let f = DateFormatter(); f.locale = Locale(identifier: lang.isArabic ? "ar" : "en"); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }
}

// MARK: - Day Pill
private struct DayPill: View {
    let date: Date; let isSelected: Bool; let action: () -> Void
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(dayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .brandPurple.opacity(0.7) : .secondary)
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.brandPurple : Color.clear)
                        .frame(width: 36, height: 36)
                    Text(dayNum)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : (isToday ? .brandPurple : .primary))
                }
                if isToday && !isSelected {
                    Circle().fill(Color.brandPurple).frame(width: 4, height: 4)
                } else {
                    Circle().fill(Color.clear).frame(width: 4, height: 4)
                }
            }
            .frame(width: 42)
        }
    }
    @EnvironmentObject private var lang: LanguageManager
    private var dayNum: String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date) }
    private var dayName: String { let f = DateFormatter(); f.locale = Locale(identifier: lang.isArabic ? "ar" : "en"); f.dateFormat = "EEE"; return f.string(from: date) }
}

// MARK: - Session Card (summary only, tap → detail sheet)
private struct TimelineSessionCard: View {
    let session: TimelineSession
    let onTap: () -> Void
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(timeStr(session.startTime)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.brandPurple)
                        Text(timeStr(session.endTime)).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .frame(width: 46)

                    RoundedRectangle(cornerRadius: 3).fill(session.status.color).frame(width: 4, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t(session.title, session.titleEn))
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                        Text(lang.t(session.specialist, session.specialistEn))
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: session.status.icon).font(.system(size: 10))
                            Text(lang.t(session.status.label.0, session.status.label.1)).font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(session.status.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(session.status.color.opacity(0.12)).cornerRadius(8)

                        Image(systemName: lang.isArabic ? "chevron.left" : "chevron.right").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                .padding(16)

                // Countdown strip (only for upcoming/active)
                if session.status != .completed {
                    CountdownRow(session: session)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(session.status.color.opacity(0.05))
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func timeStr(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: d) }
}

// MARK: - Session Detail View (Sheet)
struct SessionDetailView: View {
    @State var session: TimelineSession
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var fullScreenMedia: SessionMedia? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                statusBar
                VStack(spacing: 12) {
                    detailsCard
                    if !session.approvedNotes.isEmpty { notesCard }
                    if !session.media.isEmpty { mediaCard }
                }
                .padding(.horizontal, 0)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(lang.t(session.title, session.titleEn))
        .navigationBarTitleDisplayMode(.inline)
        .navBackButton()
        .fullScreenCover(item: $fullScreenMedia) { item in
            FullScreenMediaViewer(url: item.url, isVideo: item.isVideo) { fullScreenMedia = nil }
        }
        .onAppear { refreshSession() }
        .onChange(of: authVM.sessionsByChild) { _, _ in refreshSession() }
    }

    private func refreshSession() {
        guard let fresh = authVM.session(withId: session.sessionId),
              let updated = timelineSession(from: fresh) else { return }
        session = updated
    }

    // MARK: Status Bar
    private var statusBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: session.status.icon).foregroundColor(session.status.color)
                Text(lang.t(session.status.label.0, session.status.label.1))
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(session.status.color)
                Spacer()
                Text(lang.t(session.specialist, session.specialistEn))
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            if session.status != .completed {
                CountdownRow(session: session)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(session.status.color.opacity(0.07))
    }

    // MARK: Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(lang.t("تفاصيل الجلسة", "Session Details"), icon: "list.bullet.clipboard")

            if !lang.t(session.goal, session.goalEn).isEmpty {
                detailRow(icon: "target", color: .brandBlue,
                          label: lang.t("هدف الجلسة", "Session Goal"),
                          value: lang.t(session.goal, session.goalEn))
            }
            if let startedAt = session.startedAt {
                detailRow(icon: "play.circle.fill", color: .brandGreen,
                          label: lang.t("بدأت الساعة", "Started at"),
                          value: startedAt.formatted(date: .omitted, time: .shortened))
            }
            if !lang.t(session.achieved, session.achievedEn).isEmpty {
                detailRow(icon: "checkmark.seal.fill", color: .brandGreen,
                          label: lang.t("ما تم إنجازه", "Achieved"),
                          value: lang.t(session.achieved, session.achievedEn))
            }
            if !lang.t(session.nextGoal, session.nextGoalEn).isEmpty {
                detailRow(icon: "arrow.forward.circle.fill", color: .brandOrange,
                          label: lang.t("هدف الجلسة القادمة", "Next Session Goal"),
                          value: lang.t(session.nextGoal, session.nextGoalEn))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(lang.t("ملاحظات الأخصائي", "Specialist Notes"), icon: "bubble.left.fill")
            ForEach(Array(session.approvedNotes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: Media Card
    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(lang.t("الصور والفيديوهات", "Photos & Videos"), icon: "photo.on.rectangle")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(session.media) { item in
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(item.color).frame(width: 110, height: 110)
                            AsyncImage(url: URL(string: item.url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            if item.isVideo {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .onTapGesture { fullScreenMedia = item }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 16)
        .background(Color.white)
    }

    // MARK: Helpers
    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(.brandPurple)
            Text(text).font(.system(size: 15, weight: .bold, design: .rounded))
        }
    }

    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Text(value).font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
            }
        }
    }
}

// MARK: - Session Time Row (وقت ثابت)
private struct CountdownRow: View {
    let session: TimelineSession
    @EnvironmentObject var lang: LanguageManager

    private var label: String {
        switch session.status {
        case .upcoming:  return lang.t("تبدأ الساعة", "Starts at")
        case .active:    return lang.t("تنتهي الساعة", "Ends at")
        case .completed: return lang.t("انتهت الساعة", "Ended at")
        }
    }

    private var timeText: String {
        let target = session.status == .active ? session.endTime : session.startTime
        return target.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12)).foregroundColor(session.status.color)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(timeText).font(.system(size: 14, weight: .bold)).foregroundColor(session.status.color)
        }
    }
}

// MARK: - Full Screen Media Viewer
struct FullScreenMediaViewer: View {
    let url: String
    let isVideo: Bool
    let onClose: () -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onDisappear { player.pause() }
                } else {
                    ProgressView().tint(.white)
                }
            } else {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in scale = max(1, lastScale * value) }
                                    .onEnded { _ in lastScale = scale }
                            )
                            .onTapGesture(count: 1) { onClose() }
                    case .failure:
                        Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.white.opacity(0.6))
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .onTapGesture(count: 2) { scale = 1; lastScale = 1 }
            }
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(20)
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            if isVideo, let videoURL = URL(string: url) {
                let p = AVPlayer(url: videoURL)
                player = p
                p.play()
            }
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(LanguageManager())
        .environmentObject(AuthViewModel())
        .environment(\.layoutDirection, .rightToLeft)
}
