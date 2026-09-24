import SwiftUI

// MARK: - PhotoCard Model

private struct PhotoCard: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let gradientStart: Color
    let gradientEnd: Color
}

// MARK: - PhotosView

struct PhotosView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedCard: PhotoCard? = nil

    private var cards: [PhotoCard] {
        [
            PhotoCard(emoji: "🗣️", label: lang.t("جلسة النطق", "Speech"), gradientStart: .brandBlue, gradientEnd: .brandPurple),
            PhotoCard(emoji: "🧩", label: lang.t("جلسة سلوك", "Behavior"), gradientStart: .brandGreen, gradientEnd: .brandBlue),
            PhotoCard(emoji: "🎨", label: lang.t("نشاط", "Activity"), gradientStart: .brandMagenta, gradientEnd: .brandOrange),
            PhotoCard(emoji: "📚", label: lang.t("تعلّم", "Learning"), gradientStart: .brandPurple, gradientEnd: .brandMagenta),
            PhotoCard(emoji: "🎵", label: lang.t("موسيقى", "Music"), gradientStart: .brandOrange, gradientEnd: .brandYellow),
            PhotoCard(emoji: "🤸", label: lang.t("حركة", "Movement"), gradientStart: .brandGreen, gradientEnd: .brandMagenta),
        ]
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    consentBanner
                    sectionHeader
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(cards) { card in
                            PhotoCardView(card: card)
                                .onTapGesture { selectedCard = card }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $selectedCard) { card in
            PhotoDetailSheet(card: card)
                .environmentObject(lang)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: lang.isArabic ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brandGreen)
                    .padding(10)
                    .background(Color.brandGreen.opacity(0.10))
                    .clipShape(Circle())
            }

            Text(lang.t("الصور", "Photos"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Text(lang.t("اليوم", "Today"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandGreen.opacity(0.10))
                .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Consent Banner

    private var consentBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.brandGreen)
                .font(.system(size: 20))
            Text(lang.t("تمت الموافقة على استقبال الصور", "Photo sharing consent given"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(14)
        .background(Color.brandYellow.opacity(0.18))
        .cornerRadius(14)
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Text(lang.t("اليوم - الخميس", "Today - Thursday"))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 2)
    }
}

// MARK: - PhotoCardView

private struct PhotoCardView: View {
    let card: PhotoCard

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [card.gradientStart, card.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)
                Text(card.emoji)
                    .font(.system(size: 40))
            }
            Text(card.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - PhotoDetailSheet

private struct PhotoDetailSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss
    let card: PhotoCard

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [card.gradientStart, card.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                Text(card.emoji)
                    .font(.system(size: 80))
            }

            VStack(spacing: 8) {
                Text(card.label)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(lang.t("اليوم - الخميس", "Today - Thursday"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("11:00")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PhotosView()
            .environmentObject(LanguageManager())
    }
    .environment(\.layoutDirection, .rightToLeft)
}
