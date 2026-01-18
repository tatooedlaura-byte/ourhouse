import Foundation
import CoreData
import CloudKit

@objc(Space)
public class Space: NSManagedObject {
    // Computed property to get all grocery lists
    var groceryListsArray: [GroceryList] {
        let set = groceryLists as? Set<GroceryList> ?? []
        return set.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }

    // Computed property to get all chores
    var choresArray: [Chore] {
        let set = chores as? Set<Chore> ?? []
        return set.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    // Computed property to get all projects
    var projectsArray: [Project] {
        let set = projects as? Set<Project> ?? []
        return set.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }

    // Computed property to get all reminders sorted by title
    var remindersArray: [Reminder] {
        let set = reminders as? Set<Reminder> ?? []
        return set.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    // Computed property to get purchase history sorted by count
    var purchaseHistoryArray: [PurchaseHistory] {
        let set = purchaseHistory as? Set<PurchaseHistory> ?? []
        return set.sorted { $0.purchaseCount > $1.purchaseCount }
    }

    // Get frequently bought items (top items by count)
    var frequentlyBoughtItems: [PurchaseHistory] {
        Array(purchaseHistoryArray.prefix(20))
    }

    // Get recently bought items (sorted by last purchase date)
    var recentlyBoughtItems: [PurchaseHistory] {
        let set = purchaseHistory as? Set<PurchaseHistory> ?? []
        return set.sorted { ($0.lastPurchasedAt ?? Date.distantPast) > ($1.lastPurchasedAt ?? Date.distantPast) }
            .prefix(20)
            .map { $0 }
    }
}

extension Space {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Space> {
        return NSFetchRequest<Space>(entityName: "Space")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var ownerName: String?
    @NSManaged public var isShared: Bool
    @NSManaged public var shareRecordData: Data?
    @NSManaged public var groceryLists: NSSet?
    @NSManaged public var chores: NSSet?
    @NSManaged public var projects: NSSet?
    @NSManaged public var purchaseHistory: NSSet?
    @NSManaged public var reminders: NSSet?
}

// MARK: - Generated accessors for groceryLists
extension Space {
    @objc(addGroceryListsObject:)
    @NSManaged public func addToGroceryLists(_ value: GroceryList)

    @objc(removeGroceryListsObject:)
    @NSManaged public func removeFromGroceryLists(_ value: GroceryList)

    @objc(addGroceryLists:)
    @NSManaged public func addToGroceryLists(_ values: NSSet)

    @objc(removeGroceryLists:)
    @NSManaged public func removeFromGroceryLists(_ values: NSSet)
}

// MARK: - Generated accessors for chores
extension Space {
    @objc(addChoresObject:)
    @NSManaged public func addToChores(_ value: Chore)

    @objc(removeChoresObject:)
    @NSManaged public func removeFromChores(_ value: Chore)

    @objc(addChores:)
    @NSManaged public func addToChores(_ values: NSSet)

    @objc(removeChores:)
    @NSManaged public func removeFromChores(_ values: NSSet)
}

// MARK: - Generated accessors for projects
extension Space {
    @objc(addProjectsObject:)
    @NSManaged public func addToProjects(_ value: Project)

    @objc(removeProjectsObject:)
    @NSManaged public func removeFromProjects(_ value: Project)

    @objc(addProjects:)
    @NSManaged public func addToProjects(_ values: NSSet)

    @objc(removeProjects:)
    @NSManaged public func removeFromProjects(_ values: NSSet)
}

// MARK: - Generated accessors for purchaseHistory
extension Space {
    @objc(addPurchaseHistoryObject:)
    @NSManaged public func addToPurchaseHistory(_ value: PurchaseHistory)

    @objc(removePurchaseHistoryObject:)
    @NSManaged public func removeFromPurchaseHistory(_ value: PurchaseHistory)

    @objc(addPurchaseHistory:)
    @NSManaged public func addToPurchaseHistory(_ values: NSSet)

    @objc(removePurchaseHistory:)
    @NSManaged public func removeFromPurchaseHistory(_ values: NSSet)
}

// MARK: - Generated accessors for reminders
extension Space {
    @objc(addRemindersObject:)
    @NSManaged public func addToReminders(_ value: Reminder)

    @objc(removeRemindersObject:)
    @NSManaged public func removeFromReminders(_ value: Reminder)

    @objc(addReminders:)
    @NSManaged public func addToReminders(_ values: NSSet)

    @objc(removeReminders:)
    @NSManaged public func removeFromReminders(_ values: NSSet)
}

extension Space: Identifiable {}
