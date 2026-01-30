import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct OursListsApp: App {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var appState = AppState()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(notificationService)
                .environmentObject(appState)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await notificationService.requestAuthorization()
                }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var currentSpaceID: String? {
        didSet {
            UserDefaults.standard.set(currentSpaceID, forKey: "currentSpaceID")
        }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.currentSpaceID = UserDefaults.standard.string(forKey: "currentSpaceID")
    }
}
