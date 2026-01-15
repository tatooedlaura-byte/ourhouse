import SwiftUI
import CoreData

struct FrequentItemsSheet: View {
    @ObservedObject var groceryList: GroceryList
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var selectedItems: Set<UUID> = []

    @FetchRequest private var frequentItems: FetchedResults<PurchaseHistory>
    @FetchRequest private var recentItems: FetchedResults<PurchaseHistory>

    init(groceryList: GroceryList) {
        self.groceryList = groceryList

        let space = groceryList.space

        // Frequent items fetch request
        let frequentRequest: NSFetchRequest<PurchaseHistory> = PurchaseHistory.fetchRequest()
        frequentRequest.predicate = NSPredicate(format: "space == %@", space ?? NSNull())
        frequentRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \PurchaseHistory.purchaseCount, ascending: false)
        ]
        frequentRequest.fetchLimit = 30
        _frequentItems = FetchRequest(fetchRequest: frequentRequest)

        // Recent items fetch request
        let recentRequest: NSFetchRequest<PurchaseHistory> = PurchaseHistory.fetchRequest()
        recentRequest.predicate = NSPredicate(format: "space == %@", space ?? NSNull())
        recentRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \PurchaseHistory.lastPurchasedAt, ascending: false)
        ]
        recentRequest.fetchLimit = 30
        _recentItems = FetchRequest(fetchRequest: recentRequest)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Frequent").tag(0)
                    Text("Recent").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Items list
                let items = selectedTab == 0 ? Array(frequentItems) : Array(recentItems)

                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No History", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Items you purchase will appear here for quick re-adding")
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            FrequentItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id ?? UUID()),
                                onToggle: { toggleSelection(item) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedItems.count))") {
                        addSelectedItems()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(_ item: PurchaseHistory) {
        guard let id = item.id else { return }
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    private func addSelectedItems() {
        let allItems = Array(frequentItems) + Array(recentItems)

        for item in allItems where selectedItems.contains(item.id ?? UUID()) {
            let groceryItem = GroceryItem(context: viewContext)
            groceryItem.id = UUID()
            groceryItem.title = item.itemTitle
            groceryItem.quantity = item.quantity
            groceryItem.category = item.category
            groceryItem.isChecked = false
            groceryItem.createdAt = Date()
            groceryItem.updatedAt = Date()
            groceryItem.groceryList = groceryList
        }

        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Frequent Item Row
struct FrequentItemRow: View {
    let item: PurchaseHistory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? .blue : .gray)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemTitle ?? "")

                HStack(spacing: 8) {
                    if let quantity = item.quantity, !quantity.isEmpty {
                        Text(quantity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(item.purchaseCount)x purchased")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Category badge
            if let category = item.category {
                Text(category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
