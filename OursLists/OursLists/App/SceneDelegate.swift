import UIKit
import CloudKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // Handle CloudKit share acceptance
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        // Accept the share
        Task {
            do {
                try await CloudKitSharingService.shared.acceptShare(metadata: cloudKitShareMetadata)

                // Notify the app to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: cloudKitShareMetadata)
                }
            } catch {
                print("Error accepting share: \(error)")
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
}
