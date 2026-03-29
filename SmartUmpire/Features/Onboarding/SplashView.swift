import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void
    @State private var fadeIn = false
    @State private var scaleUp = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            // Same gradient as LaunchScreen
            LinearGradient(
                colors: [
                    Color.primaryBlue.opacity(scheme == .dark ? 0.20 : 0.08),
                    Color.appBackground
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Centered block = logo + title (matches LaunchScreen)
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Image("LoginImage2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .scaleEffect(scaleUp ? 1.0 : 0.9)
                        .opacity(fadeIn ? 1 : 0)

                    Text("SmartUmpire")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .opacity(fadeIn ? 1 : 0)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            // Spinner doesn’t affect centering
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.1)
                    .opacity(fadeIn ? 1 : 0)
                    .padding(.bottom, 72)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                fadeIn = true
                scaleUp = true
            }
        }
    }
}
