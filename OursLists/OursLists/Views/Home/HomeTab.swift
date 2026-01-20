import SwiftUI

struct HomeTab: View {
    @ObservedObject var space: Space
    @Binding var selectedTab: Int
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingAddGrocery = false
    @State private var showingAddChore = false
    @State private var showingAddReminder = false
    @State private var showingAddProject = false
    @State private var showingSettings = false
    @State private var showingOverdue = false
    @State private var showingDueToday = false
    @State private var showingToBuy = false

    // Quick stats
    var overdueTasks: Int {
        space.choresArray.filter { $0.isOverdue && !$0.isPaused }.count
    }

    var dueTodayTasks: Int {
        space.choresArray.filter { $0.isDueToday && !$0.isPaused }.count
    }

    var groceryItemsNeeded: Int {
        space.groceryListsArray.reduce(0) { $0 + $1.uncheckedCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header with app icon
                    VStack(spacing: 12) {
                        AppIconView(size: 80)

                        VStack(spacing: 4) {
                            Text("Welcome to")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(space.name ?? "Our Home")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.top, 20)

                    // Quick stats banner
                    if overdueTasks > 0 || dueTodayTasks > 0 || groceryItemsNeeded > 0 {
                        HStack(spacing: 16) {
                            if overdueTasks > 0 {
                                Button {
                                    showingOverdue = true
                                } label: {
                                    StatBadge(
                                        count: overdueTasks,
                                        label: "Overdue",
                                        color: .red,
                                        icon: "exclamationmark.circle.fill"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            if dueTodayTasks > 0 {
                                Button {
                                    showingDueToday = true
                                } label: {
                                    StatBadge(
                                        count: dueTodayTasks,
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
                        ], spacing: 12) {
                            SmallActionButton(
                                title: "Grocery",
                                icon: "cart.badge.plus",
                                color: .green
                            ) {
                                showingAddGrocery = true
                            }

                            SmallActionButton(
                                title: "Chore",
                                icon: "checklist",
                                color: .purple
                            ) {
                                showingAddChore = true
                            }

                            SmallActionButton(
                                title: "Reminder",
                                icon: "bell.badge.fill",
                                color: .orange
                            ) {
                                showingAddReminder = true
                            }

                            SmallActionButton(
                                title: "Project",
                                icon: "folder.badge.plus",
                                color: .blue
                            ) {
                                showingAddProject = true
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Due Today section
                    if !todayTasks.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Due Today")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(todayTasks.prefix(5)) { task in
                                    TaskQuickRow(task: task)
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
            .sheet(isPresented: $showingAddReminder) {
                AddReminderSheet(space: space)
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
            .sheet(isPresented: $showingOverdue) {
                OverdueTasksSheet(space: space)
            }
            .sheet(isPresented: $showingDueToday) {
                DueTodayTasksSheet(space: space)
            }
            .sheet(isPresented: $showingToBuy) {
                ToBuySheet(space: space)
            }
        }
    }

    var todayTasks: [Chore] {
        space.choresArray
            .filter { ($0.isOverdue || $0.isDueToday) && !$0.isPaused }
            .sorted { task1, task2 in
                if task1.isOverdue != task2.isOverdue {
                    return task1.isOverdue
                }
                return (task1.nextDueAt ?? Date()) < (task2.nextDueAt ?? Date())
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

// MARK: - Small Action Button
struct SmallActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Quick Row
struct TaskQuickRow: View {
    @ObservedObject var task: Chore
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    task.markDone()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "")
                    .font(.subheadline)
                Text(task.dueDescription)
                    .font(.caption)
                    .foregroundStyle(task.isOverdue ? .red : .secondary)
            }

            Spacer()

            Text(task.frequencyEnum.rawValue)
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
    @State private var newListName = ""
    @State private var showingCreateList = false
    @State private var addedItems: [String] = []
    @FocusState private var isItemFieldFocused: Bool

    var groceryLists: [GroceryList] {
        space.groceryListsArray
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // List selection
                    Section("Add to List") {
                        if groceryLists.isEmpty && !showingCreateList {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("No grocery lists yet")
                                    .foregroundStyle(.secondary)

                                Button {
                                    showingCreateList = true
                                } label: {
                                    Label("Create a List", systemImage: "plus.circle.fill")
                                }
                            }
                        } else {
                            ForEach(groceryLists) { list in
                                Button {
                                    selectedList = list
                                    addedItems = [] // Clear when switching lists
                                } label: {
                                    HStack {
                                        Image(systemName: selectedList?.id == list.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedList?.id == list.id ? .green : .gray)
                                        Text(list.name ?? "Untitled")
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(list.itemsArray.count) items")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if !showingCreateList {
                                Button {
                                    showingCreateList = true
                                } label: {
                                    Label("New List", systemImage: "plus")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        if showingCreateList {
                            HStack {
                                TextField("List name", text: $newListName)
                                    .onSubmit {
                                        createList()
                                    }

                                Button {
                                    createList()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }

                    // Add item input
                    if selectedList != nil {
                        Section {
                            HStack {
                                TextField("Item name", text: $itemName)
                                    .focused($isItemFieldFocused)
                                    .onSubmit {
                                        addItem()
                                    }

                                if !itemName.isEmpty {
                                    Button {
                                        addItem()
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        } header: {
                            Text("Add Items")
                        } footer: {
                            Text("Press return or tap + to add each item")
                        }
                    }

                    // Show added items
                    if !addedItems.isEmpty {
                        Section("Just Added ✓") {
                            ForEach(addedItems, id: \.self) { item in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Groceries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selectedList = groceryLists.first
                isItemFieldFocused = true
            }
        }
    }

    private func createList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let list = GroceryList(context: viewContext)
        list.id = UUID()
        list.name = trimmedName
        list.createdAt = Date()
        list.space = space

        try? viewContext.save()

        selectedList = list
        newListName = ""
        showingCreateList = false
        addedItems = []
        isItemFieldFocused = true
    }

    private func addItem() {
        guard let list = selectedList else { return }
        let trimmedName = itemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let item = GroceryItem(context: viewContext)
        item.id = UUID()
        item.title = trimmedName
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.groceryList = list

        try? viewContext.save()

        // Show the item was added
        withAnimation {
            addedItems.insert(trimmedName, at: 0)
        }

        // Clear and refocus for next item
        itemName = ""
        isItemFieldFocused = true
    }
}

// MARK: - Overdue Tasks Sheet
struct OverdueTasksSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var overdueTasks: [Chore] {
        space.choresArray
            .filter { $0.isOverdue && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(overdueTasks) { task in
                    TaskRowForSheet(task: task, isOverdue: true)
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

// MARK: - Due Today Tasks Sheet
struct DueTodayTasksSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var dueTodayTasks: [Chore] {
        space.choresArray
            .filter { $0.isDueToday && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dueTodayTasks) { task in
                    TaskRowForSheet(task: task, isOverdue: false)
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

// MARK: - Task Row for Sheets
struct TaskRowForSheet: View {
    @ObservedObject var task: Chore
    @Environment(\.managedObjectContext) private var viewContext
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    task.markDone()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title ?? "")
                    .font(.subheadline)
                Text(task.dueDescription)
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
            }

            Spacer()

            Text(task.frequencyEnum.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .cornerRadius(6)
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

// MARK: - App Icon View
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Image("AppIconImage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}
