import Foundation
import CloudKit
import CoreData
import UIKit
import SwiftUI

// MARK: - CloudKit Sharing Service
class CloudKitSharingService: NSObject, ObservableObject {
    static let shared = CloudKitSharingService()

    @Published var iCloudAvailable = false
    @Published var iCloudAccountStatus: CKAccountStatus = .couldNotDetermine
    @Published var sharingStatus: SharingStatus = .notShared
    @Published var participants: [CKShare.Participant] = []
    @Published var errorMessage: String?

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    enum SharingStatus: Equatable {
        case notShared
        case pendingShare
        case shared
        case sharedWithMe
        case error(String)

        static func == (lhs: SharingStatus, rhs: SharingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notShared, .notShared),
                 (.pendingShare, .pendingShare),
                 (.shared, .shared),
                 (.sharedWithMe, .sharedWithMe):
                return true
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    override init() {
        self.container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        super.init()
        checkiCloudStatus()
    }

    // MARK: - Check iCloud Status
    func checkiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.iCloudAccountStatus = status
                self?.iCloudAvailable = (status == .available)

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Create Share for Space
    func createShare(for space: Space, in context: NSManagedObjectContext) async throws -> CKShare {
        // Create share using NSPersistentCloudKitContainer
        let (_, share, _) = try await PersistenceController.shared.container.share(
            [space],
            to: nil
        )

        // Configure the share
        share[CKShare.SystemFieldKey.title] = space.name ?? "Our Household"
        share.publicPermission = .none // Private sharing only

        // Save the share record data for reference
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: share.recordID, requiringSecureCoding: true) {
            space.shareRecordData = encoded
            space.isShared = true
            try context.save()
        }

        await MainActor.run {
            self.sharingStatus = .pendingShare
        }

        return share
    }

    // MARK: - Present Sharing UI
    func presentSharingUI(for space: Space, from viewController: UIViewController) async {
        guard let context = space.managedObjectContext else { return }

        do {
            // Check if share already exists
            let existingShares = try PersistenceController.shared.container.fetchShares(matching: [space.objectID])

            let share: CKShare
            if let existingShare = existingShares[space.objectID] {
                share = existingShare
            } else {
                share = try await createShare(for: space, in: context)
            }

            await MainActor.run {
                let sharingController = UICloudSharingController(share: share, container: self.container)
                sharingController.delegate = self
                sharingController.availablePermissions = [.allowReadWrite]

                if let popover = sharingController.popoverPresentationController {
                    popover.sourceView = viewController.view
                    popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                                y: viewController.view.bounds.midY,
                                                width: 0, height: 0)
                }

                viewController.present(sharingController, animated: true)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.sharingStatus = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Accept Share
    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await container.accept(metadata)

        await MainActor.run {
            self.sharingStatus = .sharedWithMe
        }
    }

    // MARK: - Fetch Share Participants
    func fetchParticipants(for space: Space) async {
        guard space.isShared else {
            await MainActor.run {
                self.participants = []
            }
            return
        }

        do {
            let shares = try PersistenceController.shared.container.fetchShares(matching: [space.objectID])
            if let share = shares[space.objectID] {
                await MainActor.run {
                    self.participants = share.participants.map { $0 }
                    self.sharingStatus = share.participants.count > 1 ? .shared : .pendingShare
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Stop Sharing
    func stopSharing(for space: Space) async throws {
        guard let context = space.managedObjectContext else { return }

        let shares = try PersistenceController.shared.container.fetchShares(matching: [space.objectID])
        if let share = shares[space.objectID] {
            try await PersistenceController.shared.container.purgeObjectsAndRecordsInZone(
                with: share.recordID.zoneID,
                in: PersistenceController.shared.container.persistentStoreCoordinator.persistentStores.first!
            )
        }

        space.isShared = false
        space.shareRecordData = nil
        try context.save()

        await MainActor.run {
            self.sharingStatus = .notShared
            self.participants = []
        }
    }
}

// MARK: - UICloudSharingControllerDelegate
extension CloudKitSharingService: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.sharingStatus = .error(error.localizedDescription)
        }
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Our Household"
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        return nil
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        DispatchQueue.main.async {
            self.sharingStatus = .pendingShare
        }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        DispatchQueue.main.async {
            self.sharingStatus = .notShared
            self.participants = []
        }
    }
}

// MARK: - Sharing Error
enum SharingError: LocalizedError {
    case noPersistentStore
    case shareCreationFailed
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .noPersistentStore:
            return "Could not access data store"
        case .shareCreationFailed:
            return "Failed to create share"
        case .notSignedIn:
            return "Please sign in to iCloud"
        }
    }
}
