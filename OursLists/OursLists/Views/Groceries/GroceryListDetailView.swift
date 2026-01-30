import SwiftUI

struct GroceryListDetailView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @StateObject private var groceryVM: GroceryViewModel

    @State private var newItemTitle = ""
    @State private var showingAddItem = false
    @State private var showingFrequentItems = false
    @State private var sortByCategory = false
    @FocusState private var isAddFieldFocused: Bool

    let listName: String

    init(spaceId: String, listId: String, listName: String) {
        self.listName = listName
        _groceryVM = StateObject(wrappedValue: GroceryViewModel(spaceId: spaceId, listId: listId))
    }

    var uncheckedItems: [GroceryItemModel] {
        if sortByCategory {
            return groceryVM.items.filter { !$0.isChecked }.sorted {
                ($0.category ?? "zzz") < ($1.category ?? "zzz")
            }
        }
        return groceryVM.uncheckedItems
    }

    var checkedItems: [GroceryItemModel] { groceryVM.checkedItems }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add item...", text: $newItemTitle)
                        .focused($isAddFieldFocused)
                        .onSubmit { quickAddItem() }
                    if !newItemTitle.isEmpty {
                        Button { quickAddItem() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            if !uncheckedItems.isEmpty {
                Section("To Get") {
                    ForEach(uncheckedItems) { item in
                        GroceryItemRow(item: item, groceryVM: groceryVM)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            Task { await groceryVM.deleteItem(uncheckedItems[i]) }
                        }
                    }
                }
            }

            if !checkedItems.isEmpty {
                Section {
                    ForEach(checkedItems) { item in
                        GroceryItemRow(item: item, groceryVM: groceryVM)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            Task { await groceryVM.deleteItem(checkedItems[i]) }
                        }
                    }
                } header: {
                    HStack {
                        Text("Got It (\(checkedItems.count))")
                        Spacer()
                        Button("Clear All") {
                            for item in checkedItems {
                                Task { await groceryVM.deleteItem(item) }
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(listName)
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
                        Label(sortByCategory ? "Sort by Added" : "Sort by Category", systemImage: sortByCategory ? "clock" : "folder")
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
            AddGroceryItemSheet(groceryVM: groceryVM)
        }
        .sheet(isPresented: $showingFrequentItems) {
            FrequentItemsSheet(groceryVM: groceryVM)
        }
    }

    private func quickAddItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task { await groceryVM.addItem(title: trimmed) }
        newItemTitle = ""
        isAddFieldFocused = true
    }
}

// MARK: - Grocery Item Row
struct GroceryItemRow: View {
    let item: GroceryItemModel
    @ObservedObject var groceryVM: GroceryViewModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await groceryVM.toggleCheck(item, spaceVM: spaceVM) }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
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
        .onTapGesture { showingEdit = true }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await groceryVM.deleteItem(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await groceryVM.toggleCheck(item, spaceVM: spaceVM) }
            } label: {
                Label(item.isChecked ? "Uncheck" : "Check", systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(item.isChecked ? .orange : .green)
        }
        .sheet(isPresented: $showingEdit) {
            EditGroceryItemSheet(item: item, groceryVM: groceryVM)
        }
    }
}

// MARK: - Add Grocery Item Sheet
struct AddGroceryItemSheet: View {
    @ObservedObject var groceryVM: GroceryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var quantity = ""
    @State private var note = ""
    @State private var category: GroceryCategory?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item Name", text: $title)
                    TextField("Quantity (optional)", text: $quantity)
                }
                Section {
                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as GroceryCategory?)
                        ForEach(GroceryCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat as GroceryCategory?)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await groceryVM.addItem(
                                title: title,
                                quantity: quantity.isEmpty ? nil : quantity,
                                note: note.isEmpty ? nil : note,
                                category: category?.rawValue
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Grocery Item Sheet
struct EditGroceryItemSheet: View {
    let item: GroceryItemModel
    @ObservedObject var groceryVM: GroceryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var quantity: String
    @State private var note: String
    @State private var category: GroceryCategory?

    init(item: GroceryItemModel, groceryVM: GroceryViewModel) {
        self.item = item
        self.groceryVM = groceryVM
        _title = State(initialValue: item.title)
        _quantity = State(initialValue: item.quantity ?? "")
        _note = State(initialValue: item.note ?? "")
        _category = State(initialValue: GroceryCategory(rawValue: item.category ?? ""))
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
                        Text("None").tag(nil as GroceryCategory?)
                        ForEach(GroceryCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat as GroceryCategory?)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = item
                        updated.title = title
                        updated.quantity = quantity.isEmpty ? nil : quantity
                        updated.note = note.isEmpty ? nil : note
                        updated.category = category?.rawValue
                        updated.updatedAt = Date()
                        Task {
                            await groceryVM.updateItem(updated)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
