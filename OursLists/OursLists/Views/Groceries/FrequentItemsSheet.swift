import SwiftUI

struct FrequentItemsSheet: View {
    @ObservedObject var groceryVM: GroceryViewModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var selectedItems: Set<String> = []

    var frequentItems: [PurchaseHistoryModel] { spaceVM.frequentlyBoughtItems }
    var recentItems: [PurchaseHistoryModel] { spaceVM.recentlyBoughtItems }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Frequent").tag(0)
                    Text("Recent").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                let items = selectedTab == 0 ? frequentItems : recentItems

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
                                isSelected: selectedItems.contains(item.id ?? ""),
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

    private func toggleSelection(_ item: PurchaseHistoryModel) {
        guard let id = item.id else { return }
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }

    private func addSelectedItems() {
        let allItems = frequentItems + recentItems
        let selected = allItems.filter { selectedItems.contains($0.id ?? "") }
        Task {
            await groceryVM.addFrequentItems(selected)
            dismiss()
        }
    }
}

// MARK: - Frequent Item Row
struct FrequentItemRow: View {
    let item: PurchaseHistoryModel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? .blue : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemTitle)
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
        .onTapGesture { onToggle() }
    }
}
