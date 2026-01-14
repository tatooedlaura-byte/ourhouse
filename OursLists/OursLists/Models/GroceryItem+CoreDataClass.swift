import Foundation
import CoreData

@objc(GroceryItem)
public class GroceryItem: NSManagedObject {
    // Category enum for organizing items
    enum Category: String, CaseIterable {
        case produce = "Produce"
        case dairy = "Dairy"
        case meat = "Meat"
        case bakery = "Bakery"
        case frozen = "Frozen"
        case pantry = "Pantry"
        case beverages = "Beverages"
        case snacks = "Snacks"
        case household = "Household"
        case personal = "Personal Care"
        case other = "Other"
    }

    var categoryEnum: Category? {
        get {
            guard let categoryString = category else { return nil }
            return Category(rawValue: categoryString)
        }
        set {
            category = newValue?.rawValue
        }
    }
}

extension GroceryItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GroceryItem> {
        return NSFetchRequest<GroceryItem>(entityName: "GroceryItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var quantity: String?
    @NSManaged public var note: String?
    @NSManaged public var isChecked: Bool
    @NSManaged public var category: String?
    @NSManaged public var createdBy: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var groceryList: GroceryList?
}

extension GroceryItem: Identifiable {}
