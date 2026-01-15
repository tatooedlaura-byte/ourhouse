import SwiftUI

struct HomeTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingAddGrocery = false
    @State private var showingAddChore = false
    @State private var showingAddProject = false
    @State private var showingSettings = false

    // Quick stats
    var overdueChores: Int {
        space.choresArray.filter { $0.isOverdue && !$0.isPaused }.count
    }

    var dueToday: Int {
        space.choresArray.filter { $0.isDueToday && !$0.isPaused }.count
    }

    var groceryItemsNeeded: Int {
        space.groceryListsArray.reduce(0) { $0 + $1.uncheckedCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(space.name ?? "Our Home")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 20)

                    // Quick stats banner
                    if overdueChores > 0 || dueToday > 0 || groceryItemsNeeded > 0 {
                        HStack(spacing: 16) {
                            if overdueChores > 0 {
                                StatBadge(
                                    count: overdueChores,
                                    label: "Overdue",
                                    color: .red,
                                    icon: "exclamationmark.circle.fill"
                                )
                            }
                            if dueToday > 0 {
                                StatBadge(
                                    count: dueToday,
                                    label: "Due Today",
                                    color: .orange,
                                    icon: "clock.fill"
                                )
                            }
                            if groceryItemsNeeded > 0 {
                                StatBadge(
                                    count: groceryItemsNeeded,
                                    label: "To Buy",
                                    color: .blue,
                                    icon: "cart.fill"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Quick Actions
                    VStack(spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            QuickActionButton(
                                title: "Add Grocery",
                                icon: "cart.badge.plus",
                                color: .green
                            ) {
                                showingAddGrocery = true
                            }

                            QuickActionButton(
                                title: "Add Chore",
                                icon: "plus.circle",
                                color: .purple
                            ) {
                                showingAddChore = true
                            }

                            QuickActionButton(
                                title: "New Project",
                                icon: "folder.badge.plus",
                                color: .blue
                            ) {
                                showingAddProject = true
                            }

                            QuickActionButton(
                                title: "Settings",
                                icon: "gear",
                                color: .gray
                            ) {
                                showingSettings = true
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Due Today section
                    if !todayChores.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Due Today")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(todayChores.prefix(3)) { chore in
                                    ChoreQuickRow(chore: chore)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddGrocery) {
                QuickAddGrocerySheet(space: space)
            }
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet(space: space)
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    var todayChores: [Chore] {
        space.choresArray
            .filter { ($0.isOverdue || $0.isDueToday) && !$0.isPaused }
            .sorted { chore1, chore2 in
                if chore1.isOverdue != chore2.isOverdue {
                    return chore1.isOverdue
                }
                return (chore1.nextDueAt ?? Date()) < (chore2.nextDueAt ?? Date())
            }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chore Quick Row
struct ChoreQuickRow: View {
    @ObservedObject var chore: Chore
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    chore.markDone()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title ?? "")
                    .font(.subheadline)
                Text(chore.dueDescription)
                    .font(.caption)
                    .foregroundStyle(chore.isOverdue ? .red : .secondary)
            }

            Spacer()

            Text(chore.frequencyEnum.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Add Grocery Sheet
struct QuickAddGrocerySheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var selectedList: GroceryList?

    var groceryLists: [GroceryList] {
        space.groceryListsArray
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $itemName)
                }

                Section("Add to List") {
                    if groceryLists.isEmpty {
                        Text("No grocery lists yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groceryLists) { list in
                            Button {
                                selectedList = list
                            } label: {
                                HStack {
                                    Text(list.name ?? "Untitled")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedList?.id == list.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Grocery Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(itemName.isEmpty || selectedList == nil)
                }
            }
            .onAppear {
                // Auto-select first list
                selectedList = groceryLists.first
            }
        }
    }

    private func addItem() {
        guard let list = selectedList else { return }

        let item = GroceryItem(context: viewContext)
        item.id = UUID()
        item.title = itemName.trimmingCharacters(in: .whitespaces)
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.groceryList = list

        try? viewContext.save()
        dismiss()
    }
}
