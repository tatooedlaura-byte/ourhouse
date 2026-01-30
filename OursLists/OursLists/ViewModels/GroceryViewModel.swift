import Foundation
import FirebaseFirestore

@MainActor
class GroceryViewModel: ObservableObject {
    @Published var items: [GroceryItemModel] = []

    private let firestore = FirestoreService.shared
    private var listener: ListenerRegistration?
    let spaceId: String
    let listId: String

    var uncheckedItems: [GroceryItemModel] {
        items.filter { !$0.isChecked }.sorted { $0.createdAt < $1.createdAt }
    }

    var checkedItems: [GroceryItemModel] {
        items.filter { $0.isChecked }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var uncheckedCount: Int { uncheckedItems.count }
    var checkedCount: Int { checkedItems.count }

    func uncheckedItemsSortedByCategory() -> [GroceryItemModel] {
        items.filter { !$0.isChecked }.sorted {
            ($0.category ?? "Other") < ($1.category ?? "Other")
        }
    }

    init(spaceId: String, listId: String) {
        self.spaceId = spaceId
        self.listId = listId
        startListening()
    }

    func startListening() {
        let collection = firestore.groceryItemsCollection(spaceId: spaceId, listId: listId)
        listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let items = documents.compactMap { try? $0.data(as: GroceryItemModel.self) }
            Task { @MainActor in
                self?.items = items
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addItem(title: String, quantity: String? = nil, note: String? = nil, category: String? = nil, createdBy: String? = nil) async {
        let item = GroceryItemModel(title: title, quantity: quantity, note: note, category: category, createdBy: createdBy)
        let collection = firestore.groceryItemsCollection(spaceId: spaceId, listId: listId)
        do {
            _ = try await firestore.addDocument(to: collection, data: item)
        } catch {
            print("Error adding item: \(error)")
        }
    }

    func updateItem(_ item: GroceryItemModel) async {
        guard let itemId = item.id else { return }
        let collection = firestore.groceryItemsCollection(spaceId: spaceId, listId: listId)
        do {
            try await firestore.updateDocument(in: collection, id: itemId, data: item)
        } catch {
            print("Error updating item: \(error)")
        }
    }

    func toggleCheck(_ item: GroceryItemModel, spaceVM: SpaceViewModel) async {
        guard let itemId = item.id else { return }
        let collection = firestore.groceryItemsCollection(spaceId: spaceId, listId: listId)
        let newChecked = !item.isChecked
        do {
            try await collection.document(itemId).updateData([
                "isChecked": newChecked,
                "updatedAt": Timestamp(date: Date())
            ])
            if newChecked {
                await spaceVM.recordPurchase(item: item)
            }
        } catch {
            print("Error toggling check: \(error)")
        }
    }

    func deleteItem(_ item: GroceryItemModel) async {
        guard let itemId = item.id else { return }
        let collection = firestore.groceryItemsCollection(spaceId: spaceId, listId: listId)
        do {
            try await firestore.deleteDocument(in: collection, id: itemId)
        } catch {
            print("Error deleting item: \(error)")
        }
    }

    func addFrequentItems(_ historyItems: [PurchaseHistoryModel]) async {
        for item in historyItems {
            await addItem(title: item.itemTitle, quantity: item.quantity, category: item.category)
        }
    }

    deinit {
        listener?.remove()
    }
}
