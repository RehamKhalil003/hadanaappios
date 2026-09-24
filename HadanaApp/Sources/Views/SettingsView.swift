import SwiftUI


struct SettingsView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showContactForm = false

    private var user: User? {
        if case .loggedIn(let u) = authVM.authState { return u }
        return nil
    }

    var body: some View {
        NavigationStack {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                childInfoCard
                parentInfoCard
                languageCard
                toiletCard
                contactCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 32)

            logoutButton
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(lang.t("الإعدادات", "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.layoutDirection, lang.layoutDirection)
        .id(lang.isArabic)
        } // NavigationStack
    }

    // MARK: - Children Info
    private var childInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: lang.t("الأطفال", "Children"), icon: "person.2.fill", color: .brandBlue)
            Divider()
            if let children = user?.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { idx, child in
                    let isActive = child.id == user?.activeChildId
                    Button {
                        authVM.switchChild(to: child.id)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(isActive ? Color.brandPurple : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                Text(String(child.name.prefix(1)))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(isActive ? .white : .secondary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(child.name)
                                        .font(.system(size: 15, weight: isActive ? .bold : .medium))
                                        .foregroundColor(.primary)
                                    if child.toiletReminder?.isActive == true {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                    }
                                }
                                Text(child.childClass)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isActive ? Color.brandPurple.opacity(0.04) : Color.white)
                    }
                    if idx < children.count - 1 { Divider().padding(.leading, 66) }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Parent Info
    private var parentInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: lang.t("معلومات ولي الأمر", "Guardian Information"), icon: "person.2.fill", color: .brandPurple)
            Divider()
            infoRow(label: lang.t("الاسم", "Name"),         value: user?.name ?? "ولي الأمر")
            Divider().padding(.leading, 16)
            infoRow(label: lang.t("رقم الهاتف", "Phone"),   value: user?.phone ?? "07XXXXXXXX")
            Divider().padding(.leading, 16)
            infoRow(label: lang.t("الدور", "Role"),          value: lang.t("ولي أمر", "Guardian"))
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Language
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: lang.t("اللغة", "Language"), icon: "globe", color: .brandPurple)
            Divider()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.t("لغة التطبيق", "App Language"))
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(lang.isArabic ? "العربية" : "English")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: lang.toggle) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe").font(.system(size: 13, weight: .semibold))
                        Text(lang.isArabic ? "EN" : "ع").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.brandPurple)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Toilet Reminder
    private var toiletCard: some View {
        let reminder = user?.activeChild?.toiletReminder
        let isActive = reminder?.isActive == true
        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: lang.t("التذكيرات", "Reminders"), icon: "bell.fill", color: .brandOrange)
            Divider()
            HStack(spacing: 14) {
                Text("🚽").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.t("تذكير دورة المياه", "Toilet Reminder"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    if let r = reminder, r.isActive {
                        Text(lang.t(
                            "مفعّل · كل \(r.intervalMinutes) دقيقة · \(r.startTime) - \(r.endTime)",
                            "Active · Every \(r.intervalMinutes) min · \(r.startTime) - \(r.endTime)"
                        ))
                        .font(.system(size: 12))
                        .foregroundColor(.brandGreen)
                    } else {
                        Text(lang.t("غير مفعّل — يُفعَّل من الحضانة", "Inactive — activated by nursery"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isActive ? "bell.fill" : "bell.slash")
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .brandOrange : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Contact
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: lang.t("تواصل معنا", "Contact Us"), icon: "phone.fill", color: .brandGreen)
            Divider()
            contactRow(icon: "phone.fill", color: .brandGreen,
                       label: lang.t("الهاتف", "Phone"), value: "07X XXX XXXX")
            Divider().padding(.leading, 16)
            contactRow(icon: "envelope.fill", color: .brandBlue,
                       label: lang.t("البريد الإلكتروني", "Email"), value: "info@almashhad.edu")
            Divider().padding(.leading, 16)
            contactRow(icon: "mappin.circle.fill", color: .brandMagenta,
                       label: lang.t("العنوان", "Address"),
                       value: lang.t("عمّان، الأردن", "Amman, Jordan"))
            Divider().padding(.leading, 16)

            // Send message button
            Button { showContactForm = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill").font(.system(size: 14)).foregroundColor(.brandGreen)
                    Text(lang.t("أرسل لنا رسالة", "Send us a message"))
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.brandGreen)
                    Spacer()
                    Image(systemName: lang.isArabic ? "chevron.left" : "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .navigationDestination(isPresented: $showContactForm) {
            ContactFormView().environmentObject(lang)
        }
    }

    // MARK: - Logout
    private var logoutButton: some View {
        Button {
            authVM.logout()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text(lang.t("تسجيل الخروج", "Sign Out"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.brandRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandRed.opacity(0.08))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandRed.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Helpers
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func contactRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(color).frame(width: 20)
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Contact Form
struct ContactFormView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var sent = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: FormField?

    enum FormField { case subject, message }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // Banner
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.brandGreen.opacity(0.15), .brandBlue.opacity(0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.brandGreen.opacity(0.18)).frame(width: 56, height: 56)
                            Image(systemName: "envelope.fill").font(.system(size: 24)).foregroundColor(.brandGreen)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.t("كيف نقدر نساعدك؟", "How can we help?"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(lang.t("سيصلك رد خلال 24 ساعة", "We'll reply within 24 hours"))
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .padding(.top, 4)

                // Fields card
                VStack(spacing: 0) {
                    // Subject
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("الموضوع", "Subject"), systemImage: "tag.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.brandPurple)
                        TextField(lang.t("مثال: مشكلة في التطبيق", "e.g. App issue"), text: $subject)
                            .focused($focusedField, equals: .subject)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .subject ? Color.brandPurple.opacity(0.4) : Color.clear, lineWidth: 1.5))
                    }

                    Divider().padding(.vertical, 16)

                    // Message
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("رسالتك", "Your message"), systemImage: "text.alignright")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.brandPurple)
                        ZStack(alignment: .topLeading) {
                            if message.isEmpty {
                                Text(lang.t("اكتب رسالتك هنا...", "Write your message here..."))
                                    .foregroundColor(Color(.systemGray3))
                                    .padding(.horizontal, 14).padding(.top, 14)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $message)
                                .focused($focusedField, equals: .message)
                                .frame(minHeight: 140)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .message ? Color.brandPurple.opacity(0.4) : Color.clear, lineWidth: 1.5))

                        HStack {
                            Spacer()
                            Text("\(message.count)/500")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                // Error message
                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                // Send button
                Button {
                    focusedField = nil
                    isSending = true
                    errorMessage = nil
                    Task {
                        do {
                            _ = try await NetworkManager.shared.sendContactMessage(subject: subject, message: message)
                            await MainActor.run {
                                withAnimation(.spring(response: 0.4)) { sent = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
                            }
                        } catch {
                            await MainActor.run {
                                errorMessage = lang.t("تعذّر إرسال الرسالة. تحقق من الاتصال.", "Failed to send. Check your connection.")
                                isSending = false
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isSending && !sent {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: sent ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 16))
                        }
                        Text(sent ? lang.t("تم الإرسال!", "Sent!") : lang.t("إرسال الرسالة", "Send Message"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        Group {
                            if sent { Color.brandGreen }
                            else if subject.isEmpty || message.isEmpty || isSending { Color(.systemGray4) }
                            else {
                                LinearGradient(colors: [.brandGreen, .brandBlue],
                                               startPoint: .leading, endPoint: .trailing)
                            }
                        }
                    )
                    .cornerRadius(16)
                    .shadow(color: (subject.isEmpty || message.isEmpty || sent || isSending) ? .clear : Color.brandGreen.opacity(0.3),
                            radius: 10, x: 0, y: 5)
                    .scaleEffect(sent ? 1.02 : 1.0)
                }
                .disabled(subject.isEmpty || message.isEmpty || sent || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(lang.t("تواصل معنا", "Contact Us"))
        .navigationBarTitleDisplayMode(.inline)
        .navBackButton()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("تم", "Done")) { focusedField = nil }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.brandPurple)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LanguageManager())
        .environmentObject(AuthViewModel())
        .environment(\.layoutDirection, .rightToLeft)
}
