import SwiftUI

struct HomeTab: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @EnvironmentObject var authService: AuthenticationService
    @Binding var selectedTab: Int

    @State private var showingAddGrocery = false
    @State private var showingAddChore = false
    @State private var showingAddReminder = false
    @State private var showingAddProject = false
    @State private var showingSettings = false
    @State private var showingOverdue = false
    @State private var showingDueToday = false
    @State private var showingToBuy = false

    var overdueTasks: Int {
        spaceVM.chores.filter { $0.isOverdue && !$0.isPaused }.count
    }

    var dueTodayTasks: Int {
        spaceVM.chores.filter { $0.isDueToday && !$0.isPaused }.count
    }

    var groceryItemsNeeded: Int {
        spaceVM.groceryLists.count
    }

    var todayChores: [ChoreModel] {
        spaceVM.chores
            .filter { ($0.isOverdue || $0.isDueToday) && !$0.isPaused }
            .sorted { chore1, chore2 in
                if chore1.isOverdue != chore2.isOverdue { return chore1.isOverdue }
                return (chore1.nextDueAt ?? Date()) < (chore2.nextDueAt ?? Date())
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        AppIconView(size: 80)
                        VStack(spacing: 4) {
                            Text("Welcome to")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(spaceVM.space?.name ?? "Our Home")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.top, 20)

                    if overdueTasks > 0 || dueTodayTasks > 0 || groceryItemsNeeded > 0 {
                        HStack(spacing: 16) {
                            if overdueTasks > 0 {
                                Button { showingOverdue = true } label: {
                                    StatBadge(count: overdueTasks, label: "Overdue", color: .red, icon: "exclamationmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            if dueTodayTasks > 0 {
                                Button { showingDueToday = true } label: {
                                    StatBadge(count: dueTodayTasks, label: "Due Today", color: .orange, icon: "clock.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            if groceryItemsNeeded > 0 {
                                Button { showingToBuy = true } label: {
                                    StatBadge(count: groceryItemsNeeded, label: "Lists", color: .blue, icon: "cart.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            SmallActionButton(title: "Grocery", icon: "cart.badge.plus", color: .green) { showingAddGrocery = true }
                            SmallActionButton(title: "Chore", icon: "checklist", color: .purple) { showingAddChore = true }
                            SmallActionButton(title: "Reminder", icon: "bell.badge.fill", color: .orange) { showingAddReminder = true }
                            SmallActionButton(title: "Project", icon: "folder.badge.plus", color: .blue) { showingAddProject = true }
                        }
                        .padding(.horizontal)
                    }

                    if !todayChores.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Due Today")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(todayChores.prefix(5)) { chore in
                                    TaskQuickRow(chore: chore)
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
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddGrocery) {
                QuickAddGrocerySheet()
            }
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet()
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderSheet()
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingOverdue) {
                OverdueTasksSheet()
            }
            .sheet(isPresented: $showingDueToday) {
                DueTodayTasksSheet()
            }
            .sheet(isPresented: $showingToBuy) {
                ToBuySheet()
            }
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
    let chore: ChoreModel
    @EnvironmentObject var spaceVM: SpaceViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await spaceVM.markChoreDone(chore, completedBy: nil) }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
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
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var selectedList: GroceryListModel?
    @State private var newListName = ""
    @State private var showingCreateList = false
    @State private var addedItems: [String] = []
    @FocusState private var isItemFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Add to List") {
                        if spaceVM.groceryLists.isEmpty && !showingCreateList {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("No grocery lists yet")
                                    .foregroundStyle(.secondary)
                                Button { showingCreateList = true } label: {
                                    Label("Create a List", systemImage: "plus.circle.fill")
                                }
                            }
                        } else {
                            ForEach(spaceVM.groceryLists) { list in
                                Button {
                                    selectedList = list
                                    addedItems = []
                                } label: {
                                    HStack {
                                        Image(systemName: selectedList?.id == list.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedList?.id == list.id ? .green : .gray)
                                        Text(list.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                            }

                            if !showingCreateList {
                                Button { showingCreateList = true } label: {
                                    Label("New List", systemImage: "plus")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        if showingCreateList {
                            HStack {
                                TextField("List name", text: $newListName)
                                    .onSubmit { createList() }
                                Button { createList() } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }

                    if selectedList != nil {
                        Section {
                            HStack {
                                TextField("Item name", text: $itemName)
                                    .focused($isItemFieldFocused)
                                    .onSubmit { addItem() }
                                if !itemName.isEmpty {
                                    Button { addItem() } label: {
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

                    if !addedItems.isEmpty {
                        Section("Just Added") {
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
                selectedList = spaceVM.groceryLists.first
                isItemFieldFocused = true
            }
        }
    }

    private func createList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        Task {
            await spaceVM.addGroceryList(name: trimmedName)
            newListName = ""
            showingCreateList = false
            // Select the newly created list after a brief delay for listener to update
            try? await Task.sleep(nanoseconds: 500_000_000)
            selectedList = spaceVM.groceryLists.last
            addedItems = []
            isItemFieldFocused = true
        }
    }

    private func addItem() {
        guard let list = selectedList, let spaceId = spaceVM.spaceId, let listId = list.id else { return }
        let trimmedName = itemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let vm = GroceryViewModel(spaceId: spaceId, listId: listId)
        Task {
            await vm.addItem(title: trimmedName)
            vm.stopListening()
        }

        withAnimation { addedItems.insert(trimmedName, at: 0) }
        itemName = ""
        isItemFieldFocused = true
    }
}

// MARK: - Overdue Tasks Sheet
struct OverdueTasksSheet: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    var overdueTasks: [ChoreModel] {
        spaceVM.chores
            .filter { $0.isOverdue && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(overdueTasks) { chore in
                    TaskRowForSheet(chore: chore, isOverdue: true)
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
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    var dueTodayTasks: [ChoreModel] {
        spaceVM.chores
            .filter { $0.isDueToday && !$0.isPaused }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dueTodayTasks) { chore in
                    TaskRowForSheet(chore: chore, isOverdue: false)
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
    let chore: ChoreModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await spaceVM.markChoreDone(chore, completedBy: nil) }
            } label: {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                    .font(.subheadline)
                Text(chore.dueDescription)
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
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

// MARK: - To Buy Sheet
struct ToBuySheet: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(spaceVM.groceryLists) { list in
                    Section(list.name) {
                        Text("Open Groceries tab to view items")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Grocery Lists")
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
