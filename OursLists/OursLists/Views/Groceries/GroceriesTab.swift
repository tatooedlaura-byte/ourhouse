import SwiftUI

struct GroceriesTab: View {
    @EnvironmentObject var spaceVM: SpaceViewModel

    @State private var showingAddList = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if spaceVM.groceryLists.isEmpty {
                    ContentUnavailableView {
                        Label("No Grocery Lists", systemImage: "cart")
                    } description: {
                        Text("Create your first grocery list to get started")
                    } actions: {
                        Button("Create List") { showingAddList = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(spaceVM.groceryLists) { list in
                            if let spaceId = spaceVM.spaceId, let listId = list.id {
                                NavigationLink(destination: GroceryListDetailView(spaceId: spaceId, listId: listId, listName: list.name)) {
                                    GroceryListRow(list: list)
                                }
                            }
                        }
                        .onDelete(perform: deleteLists)
                    }
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingAddList = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddList) {
                AddGroceryListSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func deleteLists(offsets: IndexSet) {
        for index in offsets {
            let list = spaceVM.groceryLists[index]
            Task { await spaceVM.deleteGroceryList(list) }
        }
    }
}

// MARK: - Grocery List Row
struct GroceryListRow: View {
    let list: GroceryListModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Grocery List Sheet
struct AddGroceryListSheet: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var listName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                } footer: {
                    Text("e.g., Weekly Groceries, Costco Run, Party Supplies")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await spaceVM.addGroceryList(name: listName)
                            dismiss()
                        }
                    }
                    .disabled(listName.isEmpty)
                }
            }
        }
    }
}
