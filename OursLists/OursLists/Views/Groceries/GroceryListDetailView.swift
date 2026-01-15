import SwiftUI
import CoreData

struct GroceryListDetailView: View {
    @ObservedObject var groceryList: GroceryList
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var persistenceController: PersistenceController

    @State private var newItemTitle = ""
    @State private var showingAddItem = false
    @State private var showingFrequentItems = false
    @State private var sortByCategory = false
    @FocusState private var isAddFieldFocused: Bool

    var items: [GroceryItem] {
        if sortByCategory {
            return groceryList.itemsArray.sorted {
                let cat0 = $0.category ?? "zzz"
                let cat1 = $1.category ?? "zzz"
                if cat0 != cat1 { return cat0 < cat1 }
                if $0.isChecked != $1.isChecked { return !$0.isChecked }
                return ($0.title ?? "") < ($1.title ?? "")
            }
        }
        return groceryList.itemsArray
    }

    var uncheckedItems: [GroceryItem] {
        items.filter { !$0.isChecked }
    }

    var checkedItems: [GroceryItem] {
        items.filter { $0.isChecked }
    }

    var body: some View {
        List {
            // Quick add section
            Section {
                HStack {
                    TextField("Add item...", text: $newItemTitle)
                        .focused($isAddFieldFocused)
                        .onSubmit {
                            quickAddItem()
                        }

                    if !newItemTitle.isEmpty {
                        Button {
                            quickAddItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Unchecked items
            if !uncheckedItems.isEmpty {
                Section("To Get") {
                    ForEach(uncheckedItems) { item in
                        GroceryItemRow(item: item)
                    }
                    .onDelete { offsets in
                        deleteItems(offsets, from: uncheckedItems)
                    }
                }
            }

            // Checked items (collapsible)
            if !checkedItems.isEmpty {
                Section {
                    ForEach(checkedItems) { item in
                        GroceryItemRow(item: item)
                    }
                    .onDelete { offsets in
                        deleteItems(offsets, from: checkedItems)
                    }
                } header: {
                    HStack {
                        Text("Got It (\(checkedItems.count))")
                        Spacer()
                        Button("Clear All") {
                            clearCheckedItems()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .refreshable {
            await persistenceController.performManualSync()
        }
        .navigationTitle(groceryList.name ?? "Grocery List")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingFrequentItems = true
                    } label: {
                        Label("Add Frequent Items", systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        sortByCategory.toggle()
                    } label: {
                        Label(
                            sortByCategory ? "Sort by Added" : "Sort by Category",
                            systemImage: sortByCategory ? "clock" : "folder"
                        )
                    }

                    Divider()

                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add with Details", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddGroceryItemSheet(groceryList: groceryList)
        }
        .sheet(isPresented: $showingFrequentItems) {
            FrequentItemsSheet(groceryList: groceryList)
        }
    }

    private func quickAddItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let item = GroceryItem(context: viewContext)
        item.id = UUID()
        item.title = newItemTitle.trimmingCharacters(in: .whitespaces)
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.groceryList = groceryList

        try? viewContext.save()
        newItemTitle = ""
    }

    private func deleteItems(_ offsets: IndexSet, from items: [GroceryItem]) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }

    private func clearCheckedItems() {
        withAnimation {
            checkedItems.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Grocery Item Row
struct GroceryItemRow: View {
    @ObservedObject var item: GroceryItem
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                toggleItem()
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "")
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                if let quantity = item.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
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
            showingEdit = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewContext.delete(item)
                try? viewContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                toggleItem()
            } label: {
                Label(item.isChecked ? "Uncheck" : "Check", systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(item.isChecked ? .orange : .green)
        }
        .sheet(isPresented: $showingEdit) {
            EditGroceryItemSheet(item: item)
        }
    }

    private func toggleItem() {
        withAnimation {
            let wasChecked = item.isChecked
            item.isChecked.toggle()
            item.updatedAt = Date()

            // Record purchase when item is checked (not unchecked)
            if !wasChecked && item.isChecked {
                PurchaseHistoryService.shared.recordPurchase(item: item, in: viewContext)
            }

            try? viewContext.save()
        }
    }
}

// MARK: - Add Grocery Item Sheet
struct AddGroceryItemSheet: View {
    @ObservedObject var groceryList: GroceryList
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var quantity = ""
    @State private var note = ""
    @State private var category: GroceryItem.Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item Name", text: $title)
                    TextField("Quantity (optional)", text: $quantity)
                }

                Section {
                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as GroceryItem.Category?)
                        ForEach(GroceryItem.Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat as GroceryItem.Category?)
                        }
                    }
                }

                Section {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let item = GroceryItem(context: viewContext)
        item.id = UUID()
        item.title = title
        item.quantity = quantity.isEmpty ? nil : quantity
        item.note = note.isEmpty ? nil : note
        item.category = category?.rawValue
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.groceryList = groceryList

        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Edit Grocery Item Sheet
struct EditGroceryItemSheet: View {
    @ObservedObject var item: GroceryItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var quantity: String
    @State private var note: String
    @State private var category: GroceryItem.Category?

    init(item: GroceryItem) {
        self.item = item
        _title = State(initialValue: item.title ?? "")
        _quantity = State(initialValue: item.quantity ?? "")
        _note = State(initialValue: item.note ?? "")
        _category = State(initialValue: item.categoryEnum)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item Name", text: $title)
                    TextField("Quantity", text: $quantity)
                }

                Section {
                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as GroceryItem.Category?)
                        ForEach(GroceryItem.Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat as GroceryItem.Category?)
                        }
                    }
                }

                Section {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        item.title = title
        item.quantity = quantity.isEmpty ? nil : quantity
        item.note = note.isEmpty ? nil : note
        item.category = category?.rawValue
        item.updatedAt = Date()

        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let list = GroceryList(context: context)
    list.id = UUID()
    list.name = "Weekly Groceries"

    return NavigationStack {
        GroceryListDetailView(groceryList: list)
    }
    .environment(\.managedObjectContext, context)
}
