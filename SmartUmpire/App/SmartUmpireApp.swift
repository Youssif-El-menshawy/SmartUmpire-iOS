import SwiftUI
import LocalAuthentication
import UserNotifications

#if !UITEST
import Firebase
import FirebaseAuth
#endif

@main
struct SmartUmpireApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()
    @StateObject private var voiceEngine = VoiceEngine()

    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    /*
    init() {
        FirebaseApp.configure()

        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
    }
*/
   // /*
    init() {
        let isUITestAdmin =
            ProcessInfo.processInfo.arguments.contains("-UITest_Admin")

        if isUITestAdmin {
            let state = AppState(testMode: true)
            state.isLoggedIn = true
            state.currentRole = .admin
            _appState = StateObject(wrappedValue: state)
            return
        }

        _appState = StateObject(wrappedValue: AppState())

        #if !UITEST
        FirebaseApp.configure()
        #endif
    }
    // */

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(voiceEngine)



                // When user logs in or out
                .onChange(of: appState.isLoggedIn) { loggedIn in
                    if loggedIn && faceIDEnabled {
                        appState.isAppLocked = true
                    } else {
                        appState.isAppLocked = false
                    }
                }

                // When app enters background → lock on next resume
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        if appState.isLoggedIn && faceIDEnabled {
                            appState.isAppLocked = true
                        }
                    default:
                        break
                    }
                }
        }
    }
}
