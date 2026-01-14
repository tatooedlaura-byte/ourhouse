import SwiftUI
import CloudKit

@main
struct OursListsApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var sharingService = CloudKitSharingService.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(persistenceController)
                .environmentObject(sharingService)
                .environmentObject(appState)
                .onOpenURL { url in
                    // Handle CloudKit share acceptance URLs
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // CloudKit share URLs come through here
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "cloudkit-share" else {
            return
        }

        // The share metadata will be fetched by the scene delegate
        // This is handled in the SceneDelegate for UIKit integration
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

    @Published var pendingShareMetadata: CKShare.Metadata?

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.currentSpaceID = UserDefaults.standard.string(forKey: "currentSpaceID")
    }
}
