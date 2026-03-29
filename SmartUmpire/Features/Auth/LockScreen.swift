import SwiftUI
import LocalAuthentication

struct LockScreen: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 24) {

            Image(systemName: "faceid")
                .font(.system(size: 60, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 4)

            Text("Unlock with Face ID")
                .font(.system(size: 20, weight: .semibold))


            AppButton.primary(
                "Unlock",
                icon: "lock.open.fill",
                loading: false,
                isFullWidth: true
            ) {
                authenticateWithBiometrics()
            }
            .padding(.horizontal, 40)

        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Face ID + Passcode Auth
    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        // Check if device supports Face ID / Touch ID / Passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {

            let reason = "Unlock Smart Umpire"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        onUnlock()
                    } else {
                        // Authentication failed — iOS already handled passcode UI
                        // Nothing to do here
                    }
                }
            }

        } else {
            // Device doesn't support biometrics — fallback immediately to passcode UI
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Smart Umpire") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        onUnlock()
                    }
                }
            }
        }
    }
}
