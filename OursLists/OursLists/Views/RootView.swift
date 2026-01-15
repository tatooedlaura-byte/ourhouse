import SwiftUI
import CoreData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var persistenceController: PersistenceController
    @EnvironmentObject var sharingService: CloudKitSharingService

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Space.createdAt, ascending: true)],
        animation: .default
    )
    private var spaces: FetchedResults<Space>

    var body: some View {
        Group {
            if let space = spaces.first {
                // We have a space, show the main app
                let _ = print("RootView: Found space '\(space.name ?? "unnamed")', showing MainTabView")
                MainTabView(space: space)
            } else {
                // No space yet, show onboarding
                let _ = print("RootView: No space found, showing OnboardingView")
                OnboardingView()
            }
        }
        .onAppear {
            print("RootView: Appeared, spaces count = \(spaces.count)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { _ in
            // Refresh when a share is accepted
            persistenceController.container.viewContext.refreshAllObjects()
        }
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(PersistenceController.preview)
        .environmentObject(CloudKitSharingService.shared)
        .environmentObject(AppState())
}
