import SwiftUI
import CoreData

struct GroceriesTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingAddList = false
    @State private var showingSettings = false

    var groceryLists: [GroceryList] {
        space.groceryListsArray
    }

    var body: some View {
        NavigationStack {
            Group {
                if groceryLists.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "house.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddList) {
                AddGroceryListSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Grocery Lists", systemImage: "cart")
        } description: {
            Text("Create your first grocery list to get started")
        } actions: {
            Button("Create List") {
                showingAddList = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            ForEach(groceryLists) { list in
                NavigationLink(destination: GroceryListDetailView(groceryList: list)) {
                    GroceryListRow(groceryList: list)
                }
            }
            .onDelete(perform: deleteLists)
        }
    }

    private func deleteLists(offsets: IndexSet) {
        withAnimation {
            offsets.map { groceryLists[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Grocery List Row
struct GroceryListRow: View {
    @ObservedObject var groceryList: GroceryList

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(groceryList.name ?? "Untitled")
                    .font(.headline)

                if groceryList.itemsArray.isEmpty {
                    Text("No items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(groceryList.uncheckedCount) items remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if groceryList.checkedCount > 0 {
                Text("\(groceryList.checkedCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Grocery List Sheet
struct AddGroceryListSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.isEmpty)
                }
            }
        }
    }

    private func createList() {
        let newList = GroceryList(context: viewContext)
        newList.id = UUID()
        newList.name = listName
        newList.createdAt = Date()
        newList.space = space

        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let space = Space(context: context)
    space.id = UUID()
    space.name = "Our Home"

    return GroceriesTab(space: space)
        .environment(\.managedObjectContext, context)
        .environmentObject(CloudKitSharingService.shared)
}
