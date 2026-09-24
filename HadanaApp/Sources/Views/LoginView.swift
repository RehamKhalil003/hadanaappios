import SwiftUI

// MARK: - Brand Colors
extension Color {
    static let brandPurple  = Color(hex: "#6B4FA0")
    static let brandMagenta = Color(hex: "#C060A1")
    static let brandGreen   = Color(hex: "#5CB85C")
    static let brandBlue    = Color(hex: "#4AABDB")
    static let brandOrange  = Color(hex: "#F0AD4E")
    static let brandYellow  = Color(hex: "#F7CA18")
    static let brandRed     = Color(hex: "#D9534F")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Academy Logo
struct AcademyLogoView: View {
    let size: CGFloat
    var body: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.16))
            .shadow(color: Color.brandPurple.opacity(0.20), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Native UITextField wrapper (guarantees black text + correct RTL alignment)
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 8) {
            _NativeTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure && !showPassword,
                keyboardType: keyboardType
            )
            .frame(height: 24)

            if isSecure {
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(Color(.systemGray3))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandPurple.opacity(0.20), lineWidth: 1))
    }
}

// MARK: - UIViewRepresentable core
private struct _NativeTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool
    var keyboardType: UIKeyboardType

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.textColor = UIColor.black
        tf.tintColor = UIColor(Color.brandPurple)
        tf.keyboardType = keyboardType
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.systemGray3]
        )
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.textChanged(_:)),
                     for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
        tf.isSecureTextEntry = isSecure
        tf.keyboardType = keyboardType
        // أرقام الهاتف دائماً من اليسار، باقي الحقول من اليمين
        tf.textAlignment = (keyboardType == .phonePad) ? .left : .right
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: _NativeTextField
        init(_ p: _NativeTextField) { self.parent = p }

        @objc func textChanged(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
    }
}

// MARK: - Custom Nav Back Button
struct NavBackModifier: ViewModifier {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: lang.isArabic ? "chevron.right" : "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.brandPurple)
                    }
                }
            }
    }
}
extension View {
    func navBackButton() -> some View { modifier(NavBackModifier()) }
}

// MARK: - Language Toggle
struct LanguageToggleButton: View {
    @EnvironmentObject var lang: LanguageManager
    var body: some View {
        Button(action: lang.toggle) {
            HStack(spacing: 6) {
                Image(systemName: "globe").font(.system(size: 13, weight: .semibold))
                Text(lang.isArabic ? "EN" : "ع").font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.brandPurple)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.brandPurple.opacity(0.10))
                    .overlay(Capsule().stroke(Color.brandPurple.opacity(0.25), lineWidth: 1))
            )
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Decorative blobs
            GeometryReader { geo in
                Circle().fill(Color.brandPurple.opacity(0.07)).frame(width: 220).offset(x: -60, y: -60)
                Circle().fill(Color.brandMagenta.opacity(0.06)).frame(width: 160).offset(x: geo.size.width - 80, y: geo.size.height - 160)
                Circle().fill(Color.brandBlue.opacity(0.05)).frame(width: 100).offset(x: geo.size.width - 50, y: 100)
            }.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // VStack(alignment: .leading) = right-aligned in RTL automatically
                VStack(alignment: .leading, spacing: 0) {

                    // Language toggle — leading edge (right in AR, left in EN)
                    LanguageToggleButton()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    // Logo centered
                    AcademyLogoView(size: 210)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)

                    Spacer().frame(height: 32)

                    // Card
                    VStack(alignment: .leading, spacing: 20) {

                        // Greeting
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.t("مرحباً بك", "Welcome Back"))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Color(.label))
                            Text(lang.t("سجّل دخولك للمتابعة", "Sign in to continue"))
                                .font(.system(size: 14))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)

                        // Phone
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("رقم الهاتف", "Phone Number"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.brandPurple)
                            AppTextField(
                                placeholder: "07XXXXXXXX",
                                text: $authVM.phoneNumber,
                                keyboardType: .phonePad
                            )
                        }
                        .padding(.horizontal, 24)

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("كلمة المرور", "Password"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.brandPurple)
                            AppTextField(
                                placeholder: lang.t("أدخل كلمة المرور", "Enter your password"),
                                text: $authVM.password,
                                isSecure: true
                            )
                        }
                        .padding(.horizontal, 24)

                        // Error
                        if let error = authVM.errorMessage {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.brandRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Login button
                        Button(action: { authVM.login(isArabic: lang.isArabic) }) {
                            ZStack {
                                if authVM.isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(lang.t("تسجيل الدخول", "Sign In"))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [.brandPurple, .brandMagenta],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.brandPurple.opacity(0.35), radius: 12, x: 0, y: 6)
                        }
                        .disabled(authVM.isLoading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)

                        // Face ID login
                        Button(action: { authVM.loginWithBiometrics(isArabic: lang.isArabic) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(lang.t("الدخول ببصمة الوجه", "Sign in with Face ID"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.brandPurple)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.brandPurple.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandPurple.opacity(0.25), lineWidth: 1))
                            )
                        }
                        .disabled(authVM.isLoading)
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: -4)
                    )
                    .padding(.horizontal, 12)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: lang.isArabic)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager())
        .environment(\.layoutDirection, .rightToLeft)
}
