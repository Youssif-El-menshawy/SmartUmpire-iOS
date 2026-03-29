import SwiftUI
import LocalAuthentication
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
        @AppStorage("faceIDEnabled") private var faceIDEnabled = false
        @State private var isBooting: Bool = true
        @State private var bootError: String? = nil
        @StateObject private var voice = VoiceEngine()
    
    
    var body: some View {
        ZStack {
            if isBooting {
                SplashView { }
                    .transition(.opacity)
                    .zIndex(1)
                    .overlay(alignment: .bottom) {
                        if let bootError {
                            Text(bootError)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(Color.red.opacity(0.9))
                                .cornerRadius(10)
                                .padding(.bottom, 32)
                        }
                    }
                    .task { await bootstrap() }

            } else {
                Group {
                    if !appState.isLoggedIn {
                        LoginView()

                    } else if appState.isAppLocked {
                        LockScreen {
                            appState.isAppLocked = false
                        }

                    } else if let role = appState.currentRole {
                        switch role {
                        case .umpire:
                            UmpireNavigationView()
                        case .admin:
                            AdminNavigationView()
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isBooting)
        .tint(.primaryBlue)
        .background(Color.appBackground.ignoresSafeArea())
        .environmentObject(voice)
    }

    // MARK: - Firebase restore session + role routing
    @MainActor
    private func bootstrap() async {
        defer {
            withAnimation(.easeInOut(duration: 0.25)) {
                isBooting = false
            }
        } 

        guard let user = Auth.auth().currentUser else { return }

        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .getDocument()

            guard let data = doc.data(),
                  let roleStr = data["role"] as? String else {
                bootError = "No role found for this account."
                return
            }

            let role: UserRole?
            switch roleStr.lowercased() {
            case "admin": role = .admin
            case "umpire", "officiator": role = .umpire
            default: role = nil
            }

            guard let mapped = role else {
                bootError = "Unsupported user role."
                return
            }

            appState.login(as: mapped)

            if faceIDEnabled {
                appState.isAppLocked = true
            }
            
        } catch {
            bootError = error.localizedDescription
        }
    }
    
    private func attemptFaceIDUnlock() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Unlock SmartUmpire") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        appState.isAppLocked = false
                    }
                }
            }
        }
    }
}


// MARK: - Umpire flow shell
struct UmpireNavigationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.umpirePath) {
            UmpireDashboardView()
                .navigationDestination(for: UmpireRoute.self) { route in
                    switch route {
                    case .tournamentDetail(let t):
                        TournamentDetailView(tournament: t)
                            .environmentObject(appState)

                    case .matchScoring(let m):
                        MatchScoringView(match: m)
                            .environmentObject(appState)
                        
                    case .matchDetails(let match):
                        MatchDetailsView(
                            match: match,
                            tournament: appState.selectedTournament!
                        )

                    case .profile:
                        UmpireProfileView()
                            .environmentObject(appState)

                    case .settings:
                        SettingsView(role: .officiator)
                            .environmentObject(appState)
                }
            }
        }
    }
}

// MARK: - Admin flow shell
struct AdminNavigationView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        NavigationStack(path: $appState.adminPath) {
            AdminDashboardView()
                .navigationDestination(for: AdminRoute.self) { route in
                    
                    switch route {
                
                    case .settings:
                        SettingsView(role: .admin)
                        
                    case .viewUmpireMatches(let umpireID):
                        AdminUmpireMatchesView(umpireID: umpireID)
                            .environmentObject(appState)
                        
                    case .editUmpireCertifications(let umpireID):
                        if let umpire = appState.umpires.first(where: { $0.id == umpireID }) {
                            CertificationsEditorView(umpire: umpire)
                        }

                    case .adminUmpireDetailMatchWithTournament(let match, let tournament):
                            AdminMatchDetailView(
                                match: match,
                                tournament: tournament
                            )
                    case .adminUmpireDetail(let umpireID):
                        AdminUmpireDetailView(umpireID: umpireID)
                            .environmentObject(appState)
                }
            }
        }
    }
}

struct FaceIDLockView: View {
    let unlockAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundColor(.white)

            AppButton("Unlock with Face ID",
                      variant: .primary,
                      icon: nil,
                      isLoading: false,
                      isFullWidth: true,
                      action: unlockAction)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .ignoresSafeArea()
    }
}




struct SomeScreen: View {
    @EnvironmentObject var voice: VoiceEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MicButton(engine: voice)
            Text(voice.transcript).lineLimit(4)
            if let err = voice.errorMessage {
                Text(err).foregroundColor(.red)
            }
        }
        .padding()
    }
}


#Preview("Login") {
    let state = AppState()                
    return ContentView()
        .environmentObject(state)
}

#Preview("Umpire") {
    let state = AppState()
    state.currentRole = .umpire
    state.isLoggedIn = true
    return ContentView()
        .environmentObject(state)
}

#Preview("Admin") {
    let state = AppState()
    state.currentRole = .admin
    return ContentView()
        .environmentObject(state)
}

#Preview("Dark")  {
    LoginView().environmentObject(AppState())
        .preferredColorScheme(.dark)
}
