import Foundation
import CoreData

class PurchaseHistoryService {
    static let shared = PurchaseHistoryService()

    /// Records a purchase when an item is checked off
    func recordPurchase(item: GroceryItem, in context: NSManagedObjectContext) {
        guard let title = item.title?.trimmingCharacters(in: .whitespaces),
              !title.isEmpty,
              let space = item.groceryList?.space else {
            return
        }

        // Check if this item already exists in history (case-insensitive match)
        let request: NSFetchRequest<PurchaseHistory> = PurchaseHistory.fetchRequest()
        request.predicate = NSPredicate(
            format: "space == %@ AND itemTitle ==[c] %@",
            space, title
        )
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                // Update existing record
                existing.purchaseCount += 1
                existing.lastPurchasedAt = Date()
                // Update quantity and category if provided
                if let quantity = item.quantity, !quantity.isEmpty {
                    existing.quantity = quantity
                }
                if let category = item.category {
                    existing.category = category
                }
            } else {
                // Create new record
                let history = PurchaseHistory(context: context)
                history.id = UUID()
                history.itemTitle = title
                history.quantity = item.quantity
                history.category = item.category
                history.purchaseCount = 1
                history.lastPurchasedAt = Date()
                history.createdAt = Date()
                history.space = space
            }

            try context.save()
        } catch {
            print("Error recording purchase: \(error)")
        }
    }

    /// Fetches frequent items for suggestions
    func fetchFrequentItems(for space: Space, limit: Int = 20, in context: NSManagedObjectContext) -> [PurchaseHistory] {
        let request: NSFetchRequest<PurchaseHistory> = PurchaseHistory.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@", space)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PurchaseHistory.purchaseCount, ascending: false),
            NSSortDescriptor(keyPath: \PurchaseHistory.lastPurchasedAt, ascending: false)
        ]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching frequent items: \(error)")
            return []
        }
    }

    /// Fetches recent items for suggestions
    func fetchRecentItems(for space: Space, limit: Int = 20, in context: NSManagedObjectContext) -> [PurchaseHistory] {
        let request: NSFetchRequest<PurchaseHistory> = PurchaseHistory.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@", space)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PurchaseHistory.lastPurchasedAt, ascending: false)
        ]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recent items: \(error)")
            return []
        }
    }
}
