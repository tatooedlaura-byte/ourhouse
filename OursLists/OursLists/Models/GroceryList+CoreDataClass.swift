import Foundation
import CoreData

@objc(GroceryList)
public class GroceryList: NSManagedObject {
    var itemsArray: [GroceryItem] {
        let set = items as? Set<GroceryItem> ?? []
        return set.sorted {
            // Unchecked items first, then by creation date
            if $0.isChecked != $1.isChecked {
                return !$0.isChecked
            }
            return ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
        }
    }

    var uncheckedCount: Int {
        itemsArray.filter { !$0.isChecked }.count
    }

    var checkedCount: Int {
        itemsArray.filter { $0.isChecked }.count
    }
}

extension GroceryList {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GroceryList> {
        return NSFetchRequest<GroceryList>(entityName: "GroceryList")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var items: NSSet?
}

// MARK: - Generated accessors for items
extension GroceryList {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: GroceryItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: GroceryItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

extension GroceryList: Identifiable {}
