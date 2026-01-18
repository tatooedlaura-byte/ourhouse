import SwiftUI

struct HomeTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingAddGrocery = false
    @State private var showingAddChore = false
    @State private var showingAddProject = false
    @State private var showingAddReminder = false
    @State private var showingSettings = false
    @State private var showingOverdue = false
    @State private var showingDueToday = false
    @State private var showingToBuy = false

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
                                Button {
                                    showingOverdue = true
                                } label: {
                                    StatBadge(
                                        count: overdueChores,
                                        label: "Overdue",
                                        color: .red,
                                        icon: "exclamationmark.circle.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            if dueToday > 0 {
                                Button {
                                    showingDueToday = true
                                } label: {
                                    StatBadge(
                                        count: dueToday,
                                        label: "Due Today",
                                        color: .orange,
                                        icon: "clock.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            if groceryItemsNeeded > 0 {
                                Button {
                                    showingToBuy = true
                                } label: {
                                    StatBadge(
                                        count: groceryItemsNeeded,
                                        label: "To Buy",
                                        color: .blue,
                                        icon: "cart.fill"
                                    )
                                }
                                .buttonStyle(.plain)
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
                                title: "Add Reminder",
                                icon: "bell.badge",
                                color: .orange
                            ) {
                                showingAddReminder = true
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddGrocery) {
                QuickAddGrocerySheet(space: space)
            }
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet(space: space)
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet(space: space)
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
            .sheet(isPresented: $showingOverdue) {
                OverdueChoresSheet(space: space)
            }
            .sheet(isPresented: $showingDueToday) {
                DueTodayChoresSheet(space: space)
            }
            .sheet(isPresented: $showingToBuy) {
                ToBuySheet(space: space)
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

// MARK: - Overdue Chores Sheet
struct OverdueChoresSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var overdueChores: [Chore] {
        space.choresArray
            .filter { $0.isOverdue && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(overdueChores) { chore in
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
                                .foregroundStyle(.red)
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
                }
            }
            .navigationTitle("Overdue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Due Today Chores Sheet
struct DueTodayChoresSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var dueTodayChores: [Chore] {
        space.choresArray
            .filter { $0.isDueToday && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dueTodayChores) { chore in
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
                                .foregroundStyle(.secondary)
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
                }
            }
            .navigationTitle("Due Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - To Buy Sheet
struct ToBuySheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var groceryLists: [GroceryList] {
        space.groceryListsArray.filter { $0.uncheckedCount > 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groceryLists) { list in
                    Section(list.name ?? "Untitled") {
                        ForEach(list.itemsArray.filter { !$0.isChecked }) { item in
                            HStack(spacing: 12) {
                                Button {
                                    withAnimation {
                                        item.isChecked = true
                                        item.updatedAt = Date()
                                        try? viewContext.save()
                                    }
                                } label: {
                                    Image(systemName: "circle")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title ?? "")
                                        .font(.subheadline)
                                    if let quantity = item.quantity, !quantity.isEmpty {
                                        Text(quantity)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("To Buy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
