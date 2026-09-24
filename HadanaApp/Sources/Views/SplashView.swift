import SwiftUI

struct SplashView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -15
    @State private var arNameOffset: CGFloat = 40
    @State private var arNameOpacity: Double = 0
    @State private var enNameOffset: CGFloat = 40
    @State private var enNameOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -300
    @State private var dotsScale: [CGFloat] = [0, 0, 0, 0, 0]
    @State private var bgCircle1Scale: CGFloat = 0
    @State private var bgCircle2Scale: CGFloat = 0
    @State private var bgCircle3Scale: CGFloat = 0

    let dotColors: [Color] = [
        .brandPurple, .brandMagenta, .brandGreen, .brandBlue, .brandOrange
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.brandPurple.opacity(0.08),
                    Color.white,
                    Color.brandMagenta.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated bg circles
            Circle()
                .fill(Color.brandPurple.opacity(0.10))
                .frame(width: 300)
                .scaleEffect(bgCircle1Scale)
                .offset(x: -120, y: -200)
                .blur(radius: 10)

            Circle()
                .fill(Color.brandMagenta.opacity(0.08))
                .frame(width: 250)
                .scaleEffect(bgCircle2Scale)
                .offset(x: 140, y: 220)
                .blur(radius: 8)

            Circle()
                .fill(Color.brandBlue.opacity(0.07))
                .frame(width: 180)
                .scaleEffect(bgCircle3Scale)
                .offset(x: 130, y: -260)
                .blur(radius: 6)

            VStack(spacing: 0) {
                Spacer()

                // Logo with shimmer
                ZStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 46))
                        .shadow(color: Color.brandPurple.opacity(0.25), radius: 30, x: 0, y: 12)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(logoRotation))

                    // Shimmer overlay
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 260, height: 260)
                        .offset(x: shimmerOffset)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .opacity(logoOpacity)
                }

                Spacer().frame(height: 36)

                // Arabic name
                Text("أكاديمية المشهد للعقول النيرة")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color.brandPurple)
                    .multilineTextAlignment(.center)
                    .offset(y: arNameOffset)
                    .opacity(arNameOpacity)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 8)

                // English name
                Text("Al Mashhad Academy for Bright Minds")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.brandMagenta)
                    .multilineTextAlignment(.center)
                    .offset(y: enNameOffset)
                    .opacity(enNameOpacity)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 48)

                // Animated dots
                HStack(spacing: 10) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(dotColors[i])
                            .frame(width: 10, height: 10)
                            .scaleEffect(dotsScale[i])
                            .shadow(color: dotColors[i].opacity(0.4), radius: 4)
                    }
                }

                Spacer()
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Background circles
        withAnimation(.spring(response: 1.2, dampingFraction: 0.6).delay(0.0)) {
            bgCircle1Scale = 1
        }
        withAnimation(.spring(response: 1.4, dampingFraction: 0.6).delay(0.1)) {
            bgCircle2Scale = 1
        }
        withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.05)) {
            bgCircle3Scale = 1
        }

        // Logo entrance
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.15)) {
            logoScale = 1.08
            logoOpacity = 1
            logoRotation = 0
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.85)) {
            logoScale = 1.0
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.7).delay(0.9)) {
            shimmerOffset = 300
        }

        // Arabic name slide up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.55)) {
            arNameOffset = 0
            arNameOpacity = 1
        }

        // English name slide up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.70)) {
            enNameOffset = 0
            enNameOpacity = 1
        }

        // Dots pop in one by one
        for i in 0..<5 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.85 + Double(i) * 0.09)) {
                dotsScale[i] = 1
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(LanguageManager())
}
