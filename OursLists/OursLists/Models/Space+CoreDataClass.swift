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

extension Space: Identifiable {}
