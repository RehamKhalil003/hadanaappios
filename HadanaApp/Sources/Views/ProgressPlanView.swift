import SwiftUI

// MARK: - SessionStatus

private enum SessionStatus {
    case completed, inProgress, upcoming

    func label(lang: LanguageManager) -> String {
        switch self {
        case .completed:  return lang.t("منجز", "Completed")
        case .inProgress: return lang.t("قيد التنفيذ", "In Progress")
        case .upcoming:   return lang.t("قادم", "Upcoming")
        }
    }

    var color: Color {
        switch self {
        case .completed:  return .brandGreen
        case .inProgress: return .brandOrange
        case .upcoming:   return Color(.systemGray3)
        }
    }
}

// MARK: - SessionPlan Model

private struct SessionPlan: Identifiable {
    let id = UUID()
    let number: Int
    let type: String
    let goal: String
    let achieved: String?
    let nextGoal: String
    let status: SessionStatus
}

// MARK: - ProgressPlanView

struct ProgressPlanView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.presentationMode) var presentationMode

    private var sessions: [SessionPlan] {
        [
            SessionPlan(
                number: 1,
                type: lang.t("جلسة النطق ١", "Speech Session 1"),
                goal: lang.t("نطق حرف الراء", "Pronounce letter R"),
                achieved: lang.t("تم نطق الحرف بشكل صحيح", "Letter pronounced correctly"),
                nextGoal: lang.t("نطق الكلمات", "Word pronunciation"),
                status: .completed
            ),
            SessionPlan(
                number: 2,
                type: lang.t("جلسة السلوك ١", "Behavior Session 1"),
                goal: lang.t("التواصل البصري", "Eye contact"),
                achieved: lang.t("تحقق التواصل البصري لمدة 5 ثوانٍ", "Eye contact achieved for 5 seconds"),
                nextGoal: lang.t("التفاعل الاجتماعي", "Social interaction"),
                status: .completed
            ),
            SessionPlan(
                number: 3,
                type: lang.t("جلسة النطق ٢", "Speech Session 2"),
                goal: lang.t("نطق الكلمات", "Word pronunciation"),
                achieved: nil,
                nextGoal: lang.t("الجمل القصيرة", "Short sentences"),
                status: .inProgress
            ),
            SessionPlan(
                number: 4,
                type: lang.t("جلسة السلوك ٢", "Behavior Session 2"),
                goal: lang.t("التفاعل الاجتماعي", "Social interaction"),
                achieved: nil,
                nextGoal: lang.t("اللعب التشاركي", "Cooperative play"),
                status: .upcoming
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    overallProgressCard
                    ForEach(sessions) { session in
                        SessionCard(session: session)
                            .environmentObject(lang)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: lang.isArabic ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brandOrange)
                    .padding(10)
                    .background(Color.brandOrange.opacity(0.10))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("خطة الإنجاز", "Progress Plan"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(lang.t("سارة", "Sara"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Overall Progress Card

    private var overallProgressCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.brandPurple.opacity(0.15), lineWidth: 12)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        LinearGradient(colors: [.brandPurple, .brandMagenta], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                Text("75%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.brandPurple)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t("التقدم العام", "Overall Progress"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(lang.t("3 من 4 جلسات مكتملة", "3 of 4 sessions complete"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.brandYellow)
                    Text(lang.t("أداء ممتاز!", "Excellent performance!"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandOrange)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.brandPurple.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

// MARK: - SessionCard

private struct SessionCard: View {
    @EnvironmentObject var lang: LanguageManager
    let session: SessionPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(session.status.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("\(session.number)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(session.status.color)
                    }
                    Text(session.type)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text(session.status.label(lang: lang))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(session.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(session.status.color.opacity(0.12))
                    .cornerRadius(10)
            }

            Divider()

            // Goal row
            infoRow(
                icon: "target",
                iconColor: .brandBlue,
                label: lang.t("الهدف", "Goal"),
                value: session.goal
            )

            // Achieved row
            if let achieved = session.achieved {
                infoRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .brandGreen,
                    label: lang.t("ما تحقق", "Achieved"),
                    value: achieved
                )
            }

            // Next goal row
            infoRow(
                icon: "arrow.right.circle.fill",
                iconColor: .brandOrange,
                label: lang.t("الهدف القادم", "Next Goal"),
                value: session.nextGoal
            )
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: session.status.color.opacity(0.10), radius: 10, x: 0, y: 5)
    }

    private func infoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ProgressPlanView()
            .environmentObject(LanguageManager())
    }
    .environment(\.layoutDirection, .rightToLeft)
}
