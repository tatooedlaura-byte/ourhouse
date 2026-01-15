import CoreData
import CloudKit

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    // CloudKit container identifier - must match your CloudKit container
    static let cloudKitContainerIdentifier = "iCloud.com.short.OursLists"

    // For previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Create sample data
        let space = Space(context: viewContext)
        space.id = UUID()
        space.name = "Our Home"
        space.createdAt = Date()
        space.ownerName = "Preview User"

        let groceryList = GroceryList(context: viewContext)
        groceryList.id = UUID()
        groceryList.name = "Weekly Groceries"
        groceryList.createdAt = Date()
        groceryList.space = space

        let item = GroceryItem(context: viewContext)
        item.id = UUID()
        item.title = "Milk"
        item.quantity = "1 gallon"
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.groceryList = groceryList

        do {
            try viewContext.save()
        } catch {
            print("Preview save error: \(error)")
        }

        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "OursLists")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Configure for CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        // Enable CloudKit
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Self.cloudKitContainerIdentifier
        )

        // Enable history tracking for CloudKit sync
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Enable lightweight migration for model changes
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { description, error in
            print("PersistenceController: loadPersistentStores completed")
            if let error = error {
                print("PersistenceController: Core Data failed to load: \(error.localizedDescription)")

                // If migration fails, delete the store and try again
                if let storeURL = description.url {
                    print("Attempting to delete and recreate store...")
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        // Also remove related files
                        let walURL = storeURL.appendingPathExtension("wal")
                        let shmURL = storeURL.appendingPathExtension("shm")
                        try? FileManager.default.removeItem(at: walURL)
                        try? FileManager.default.removeItem(at: shmURL)

                        // Try loading again
                        try self.container.persistentStoreCoordinator.addPersistentStore(
                            ofType: NSSQLiteStoreType,
                            configurationName: nil,
                            at: storeURL,
                            options: [
                                NSMigratePersistentStoresAutomaticallyOption: true,
                                NSInferMappingModelAutomaticallyOption: true
                            ]
                        )
                        print("Store recreated successfully")
                    } catch {
                        print("Failed to recreate store: \(error)")
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Listen for remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        // Refresh the view context when remote changes arrive
        DispatchQueue.main.async {
            self.container.viewContext.refreshAllObjects()
        }
    }

    // MARK: - Manual Sync (Pull to Refresh)
    func performManualSync() async {
        await MainActor.run {
            container.viewContext.refreshAllObjects()
        }
        // Small delay to allow CloudKit sync to propagate
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    // MARK: - Fetch Space
    func fetchSpace() -> Space? {
        let request: NSFetchRequest<Space> = Space.fetchRequest()
        request.fetchLimit = 1
        do {
            return try container.viewContext.fetch(request).first
        } catch {
            print("Error fetching space: \(error)")
            return nil
        }
    }

    // MARK: - Create Default Space
    func createDefaultSpace(name: String, ownerName: String) -> Space {
        let space = Space(context: container.viewContext)
        space.id = UUID()
        space.name = name
        space.createdAt = Date()
        space.ownerName = ownerName

        // Create default grocery list
        let groceryList = GroceryList(context: container.viewContext)
        groceryList.id = UUID()
        groceryList.name = "Weekly Groceries"
        groceryList.createdAt = Date()
        groceryList.space = space

        save()
        return space
    }
}
