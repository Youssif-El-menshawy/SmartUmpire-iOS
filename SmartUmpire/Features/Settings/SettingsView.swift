import SwiftUI
import FirebaseAuth
import LocalAuthentication
import UserNotifications

// MARK: - MAIN SETTINGS VIEW

struct SettingsView: View {
    enum RoleLabel: String { case officiator = "Officiator Settings", admin = "Admin Settings" }
    let role: RoleLabel

    @EnvironmentObject private var appState: AppState

    // AppStorage
    @AppStorage("matchReminders") private var matchReminders = true
    @AppStorage("tournamentUpdates") private var tournamentUpdates = true
    @AppStorage("scheduleChanges") private var scheduleChanges = true
    @AppStorage("pushNotifications") private var pushNotifications = false

    @AppStorage("faceIDEnabled") private var faceIDEnabled = false

    // Password Change Sheet
    @State private var showChangePasswordSheet = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var validationMessage: String?

    // Toast
    @State private var toastMessage: String?
    @State private var showToast = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - HEADER
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Settings")
                            .font(.system(size: 26, weight: .bold))
                        Text("Customize your preferences and account")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                        Text(role.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary.opacity(0.7))
                    }

                    // MARK: - NOTIFICATIONS CARD
                    SettingsSectionCard(
                        title: "Notifications",
                        subtitle: "Customize alerts and reminders",
                        icon: "bell.fill",
                        tint: .primaryBlue
                    ) {
                        ToggleSettingRow(
                            title: "Match Reminders",
                            subtitle: "Alerts before assigned matches",
                            binding: $matchReminders
                        )

                        ToggleSettingRow(
                            title: "Tournament Updates",
                            subtitle: "Updates when tournaments change",
                            binding: $tournamentUpdates
                        )

                        ToggleSettingRow(
                            title: "Schedule Changes",
                            subtitle: "Be alerted when match times shift",
                            binding: $scheduleChanges
                        )

                        ToggleSettingRow(
                            title: "Push Notifications",
                            subtitle: "Enable system push alerts",
                            binding: Binding(
                                get: { pushNotifications },
                                set: { handlePushToggle($0) }
                            )
                        )
                    }

                    // MARK: - SECURITY CARD
                    SettingsSectionCard(
                        title: "Privacy & Security",
                        subtitle: "Manage authentication",
                        icon: "shield.fill",
                        tint: .errorRed
                    ) {
                        ToggleSettingRow(
                            title: "Open with Face ID",
                            subtitle: "Require Face ID on launch",
                            binding: Binding(
                                get: { faceIDEnabled },
                                set: { handleFaceIDToggle($0) }
                            )
                        )

                        Divider().padding(.vertical, 8)

                        SettingsActionRow(
                            title: "Change Password",
                            icon: "key.fill"
                        ) { showChangePasswordSheet = true }

                        SettingsActionRow(
                            title: "Reset via Email",
                            icon: "envelope.fill"
                        ) { sendPasswordReset() }

                        SettingsActionRow(
                            title: "Privacy Policy",
                            icon: "hand.raised.fill"
                        ) { openURL("https://smartumpire.app/privacy") }

                        SettingsActionRow(
                            title: "Terms of Service",
                            icon: "doc.text"
                        ) { openURL("https://smartumpire.app/terms") }
                    }

                    // MARK: - LOGOUT & FOOTER
                    VStack(spacing: 12) {
                        Button(role: .destructive) { appState.logout() } label: { HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Logout") } .frame(maxWidth: .infinity, minHeight: 56) }
                            .accessibilityIdentifier("logoutButton")
                            .background(Color.cardBackground) .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.errorRed)) .cornerRadius(12)

                        Text("SmartUmpire v1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)

                        Text("© 2025 SmartUmpire. All rights reserved.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityIdentifier("settingsScreen")
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)

            if showToast, let msg = toastMessage {
                Toast(message: msg)
            }
        }
        // MARK: - PASSWORD SHEET
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordSheet(
                currentPassword: $currentPassword,
                newPassword: $newPassword,
                confirmPassword: $confirmPassword,
                isChanging: $isChangingPassword,
                validationMessage: $validationMessage,
                onCancel: { showChangePasswordSheet = false },
                onConfirm: { Task { await changePasswordFlow() } }
            )
        }
    }
}

// MARK: - ACTIONS

extension SettingsView {
    private func showToast(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func handlePushToggle(_ newValue: Bool) {
        pushNotifications = newValue

        if newValue {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        showToast("Notifications enabled.")
                    } else {
                        pushNotifications = false
                        showToast("Notifications denied in Settings.")
                    }
                }
            }
        }
    }


    private func handleFaceIDToggle(_ newValue: Bool) {
        let context = LAContext()
        var error: NSError?

        if newValue {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                       localizedReason: "Enable Face ID for SmartUmpire") { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            faceIDEnabled = true
                            showToast("Face ID enabled.")
                        } else {
                            faceIDEnabled = false
                            showToast("Face ID setup cancelled.")
                        }
                    }
                }
            } else {
                faceIDEnabled = false
                showToast("Face ID not available on this device.")
            }
        } else {
            faceIDEnabled = false
            showToast("Face ID disabled.")
        }
    }

    private func sendPasswordReset() {
        guard let email = Auth.auth().currentUser?.email else {
            showToast("No email found on account.")
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                showToast("Error: \(error.localizedDescription)")
            } else {
                showToast("Reset link sent to \(email).")
            }
        }
    }

    @MainActor
    private func changePasswordFlow() async {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            validationMessage = "User not found."
            return
        }

        isChangingPassword = true
        defer { isChangingPassword = false }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)

            showChangePasswordSheet = false
            validationMessage = nil
            showToast("Password updated.")
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}


// MARK: - SETTINGS CARD

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.textSecondary)
                }
            }

            content
        }
        .accessibilityIdentifier("settingsSection_\(title)")
        .cardStyle()
    }
}

// MARK: - TOGGLE ROW

struct ToggleSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var binding: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $binding).labelsHidden()
        }
        .accessibilityIdentifier("toggle_\(title)")
    }
}

// MARK: - ACTION ROW

struct SettingsActionRow: View {
    let title: String
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("settingsAction_\(title)")
    }
}


// MARK: - PASSWORD SHEET

struct ChangePasswordSheet: View {
    @Binding var currentPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    @Binding var isChanging: Bool
    @Binding var validationMessage: String?

    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var show1 = false
    @State private var show2 = false
    @State private var show3 = false

    var body: some View {
        VStack(spacing: 20) {

            Text("Change Password")
                .font(.system(size: 20, weight: .semibold))

            LabeledSecureField(label: "Current Password",
                               text: $currentPassword,
                               isVisible: $show1)

            LabeledSecureField(label: "New Password",
                               text: $newPassword,
                               isVisible: $show2)

            LabeledSecureField(label: "Confirm New Password",
                               text: $confirmPassword,
                               isVisible: $show3)

            if let msg = validationMessage {
                Text(msg)
                    .foregroundColor(.errorRed)
                    .font(.system(size: 12))
            }

            HStack(spacing: 12) {
                AppButton("Cancel", variant: .ghost, isFullWidth: true) {
                    onCancel()
                }

                AppButton("Update Password",
                          variant: .primary,
                          isLoading: isChanging,
                          isFullWidth: true) {
                    onConfirm()
                }
            }
        }
        .accessibilityIdentifier("changePasswordSheet")
        .padding(20)
        .presentationDetents([.medium])
    }
}

// MARK: - SECURE FIELD

struct LabeledSecureField: View {
    let label: String
    @Binding var text: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)

            HStack {
                if isVisible {
                    TextField("", text: $text)
                } else {
                    SecureField("", text: $text)
                }

                Button { isVisible.toggle() } label: {
                    Image(systemName: isVisible ? "eye" : "eye.slash")
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(12)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.border)
            )
            .cornerRadius(12)
        }
        .accessibilityIdentifier("passwordField_\(label)")
    }
}

// MARK: - TOAST

struct Toast: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .padding(.bottom, 40)
                .shadow(radius: 6)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

