import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    
    // UI state
    @State private var selectedRole: UserRole = .umpire
    @State private var isSecure: Bool = true
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var showToast: Bool = false
    @State private var isLoading = false
    @State private var keyboardHeight: CGFloat = 0
    
    
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    
    
    var body: some View {
        ZStack {
            // Background gradient like the mock
            @Environment(\.colorScheme) var scheme

            LinearGradient(
                colors: [
                    Color.primaryBlue.opacity(scheme == .dark ? 0.20 : 0.08),
                    Color.appBackground
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: Hero / Logo
                    VStack(spacing: 16) {
                        Image("LoginImage2")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        
                        Text("Welcome to\nSmartUmpire")
                            .font(.system(size: 34, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.textPrimary)
                        
                        Text("Professional Tennis Match Management")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // MARK: Card
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Login As
                        Text("Login As")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        RoleSegmented(selection: $selectedRole)
                        
                        // Email
                        LabeledField(label: "Email Address") {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope")
                                    .foregroundColor(.textSecondary)
                                TextField("Enter your email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                        }
                        
                        // Password
                        LabeledField(label: "Password") {
                            HStack(spacing: 8) {
                                Image(systemName: "lock")
                                    .foregroundColor(.textSecondary)
                                Group {
                                    if isSecure {
                                        SecureField("Enter your password", text: $password)
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                    } else {
                                        TextField("Enter your password", text: $password)
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                    }
                                }
                                .onSubmit {
                                    if focusedField == .email {
                                        focusedField = .password
                                    } else {
                                        login()
                                    }
                                }
                                Button {
                                    isSecure.toggle()
                                } label: {
                                    Image(systemName: isSecure ? "eye.slash" : "eye")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        
                        // UNDER the Password field block
                        Button("Forgot password?") {
                            guard !email.isEmpty else {
                                showToastMessage("Enter your email first.")
                                return
                            }
                            Auth.auth().sendPasswordReset(withEmail: email) { err in
                                if let err = err {
                                    showToastMessage("Error: \(err.localizedDescription)")
                                } else {
                                    showToastMessage("Reset link sent to \(email).")
                                }
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryBlue)
                        
                        AppButton("Login",
                                  variant: .primary,
                                  isLoading: isLoading,
                                  isFullWidth: true,
                                  action: login)
                        .disabled(email.isEmpty || password.isEmpty)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                    }
                    
                    .padding(16)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16).stroke(Color.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Footer tagline
                    Text("Automate your tennis officiating experience")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 560) // nice on iPad/macCatalyst; harmless on iPhone
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)           // lets you drag to hide
            .padding(.bottom, keyboardHeight)
            .contentShape(Rectangle())                // <— lets taps register anywhere
            .onTapGesture { focusedField = nil }      // <— dismiss keyboard
            // Toast overlay
            if showToast, let message = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Text(message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                    }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showToast)
                }
            }
            
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Signing in...")
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(12)
            }

        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            if let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let screenH = UIScreen.main.bounds.height
                let newHeight = max(0, screenH - end.origin.y)
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = newHeight }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
    }
    
    // MARK: - Auth + Role Gate
    private func login() {
        errorMessage = nil
        showToast = false
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async { isLoading = false }  // <— ensure on main
            if let error = error {
                DispatchQueue.main.async { self.showToastMessage("⚠️ \(error.localizedDescription)") }
                return
            }

            guard let uid = result?.user.uid else {
                DispatchQueue.main.async { self.showToastMessage("Login failed. Please try again.") }
                return
            }

            Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument { snapshot, err in
                    if let err = err {
                        DispatchQueue.main.async { self.showToastMessage("Error fetching user data: \(err.localizedDescription)") }
                        return
                    }

                    guard let data = snapshot?.data(),
                          let roleStr = data["role"] as? String else {
                        DispatchQueue.main.async { self.showToastMessage("No role found for this account.") }
                        return
                    }

                    let fetchedRole: UserRole? = {
                        switch roleStr.lowercased() {
                        case "admin": return .admin
                        case "umpire", "officiator": return .umpire
                        default: return nil
                        }
                    }()

                    guard let role = fetchedRole else {
                        DispatchQueue.main.async { self.showToastMessage("Unsupported user role.") }
                        return
                    }

                    if role != selectedRole {
                        DispatchQueue.main.async { self.showToastMessage("Access denied. You don't have permission to this area.") }
                        return
                    }

                    // Successful login
                    DispatchQueue.main.async { appState.login(as: role) }
                }
        }
    }
    
    // Helper to show the toast
    private func showToastMessage(_ message: String) {
        withAnimation {
            self.errorMessage = message
            self.showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    
    // MARK: - Pieces
    
    private struct RoleSegmented: View {
        @Binding var selection: UserRole
        var body: some View {
            HStack(spacing: 0) {
                segButton("Officiator", role: .umpire, system: "figure.tennis")
                segButton("Admin", role: .admin, system: "gearshape.2")
            }
            .background(Color.appBackground)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border))
            .cornerRadius(12)
        }
        
        private func segButton(_ title: String, role: UserRole, system: String) -> some View {
            Button {
                selection = role
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: system)
                    Text(title)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selection == role ? .white : .textPrimary)
                .background(selection == role ? Color.primaryBlue : .clear)
                .cornerRadius(10)
                .padding(4) // creates the pill effect inside the outer rounded rect
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct LabeledField<Content: View>: View {
        let label: String
        @ViewBuilder var content: Content
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                content
                    .padding(12)
                    .background(Color.appBackground)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border))
                    .cornerRadius(12)
            }
        }
    }
}
