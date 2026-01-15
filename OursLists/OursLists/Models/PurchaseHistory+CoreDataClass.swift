import Foundation
import CoreData

@objc(PurchaseHistory)
public class PurchaseHistory: NSManagedObject {
    // Computed property to get normalized title for matching
    var normalizedTitle: String {
        (itemTitle ?? "").lowercased().trimmingCharacters(in: .whitespaces)
    }

    // Category enum reuse from GroceryItem
    var categoryEnum: GroceryItem.Category? {
        guard let categoryString = category else { return nil }
        return GroceryItem.Category(rawValue: categoryString)
    }
}

extension PurchaseHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PurchaseHistory> {
        return NSFetchRequest<PurchaseHistory>(entityName: "PurchaseHistory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var itemTitle: String?
    @NSManaged public var quantity: String?
    @NSManaged public var category: String?
    @NSManaged public var purchaseCount: Int32
    @NSManaged public var lastPurchasedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
}

extension PurchaseHistory: Identifiable {}
