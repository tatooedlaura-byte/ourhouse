import SwiftUI

struct ChoresTab: View {
    @State private var showingAddChore = false

    var body: some View {
        NavigationStack {
            ChoresContent()
                .navigationTitle("Chores")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingAddChore = true } label: { Image(systemName: "plus") }
                    }
                }
                .sheet(isPresented: $showingAddChore) { AddChoreSheet() }
        }
    }
}

struct ChoresContent: View {
    @EnvironmentObject var spaceVM: SpaceViewModel

    @State private var selectedView: ChoreViewType = .today
    @State private var newChoreTitle = ""
    @FocusState private var isAddFieldFocused: Bool

    enum ChoreViewType: String, CaseIterable {
        case today = "Today"
        case all = "All"
    }

    var chores: [ChoreModel] {
        spaceVM.chores.filter { !$0.isPaused }
    }

    var todayChores: [ChoreModel] {
        chores.filter { $0.isOverdue || $0.isDueToday || $0.isDueSoon }
            .sorted { c1, c2 in
                if c1.isOverdue != c2.isOverdue { return c1.isOverdue }
                if c1.isDueToday != c2.isDueToday { return c1.isDueToday }
                return (c1.nextDueAt ?? Date()) < (c2.nextDueAt ?? Date())
            }
    }

    var pausedChores: [ChoreModel] {
        spaceVM.chores.filter { $0.isPaused }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedView) {
                ForEach(ChoreViewType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selectedView {
                case .today: todayView
                case .all: allView
                }
            }
        }
    }

    @ViewBuilder
    private var todayView: some View {
        if todayChores.isEmpty {
            ContentUnavailableView {
                Label("All Caught Up", systemImage: "checkmark.circle")
            } description: {
                Text("No tasks due today")
            }
        } else {
            List {
                ForEach(todayChores) { chore in
                    ChoreRow(chore: chore)
                }
            }
        }
    }

    @ViewBuilder
    private var allView: some View {
        List {
            Section {
                HStack {
                    TextField("Add chore...", text: $newChoreTitle)
                        .focused($isAddFieldFocused)
                        .onSubmit { quickAddChore() }
                    if !newChoreTitle.isEmpty {
                        Button { quickAddChore() } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.purple)
                        }
                    }
                }
            }

            if chores.isEmpty && pausedChores.isEmpty {
                Section {
                    Text("Add chores to keep track of household tasks")
                        .foregroundStyle(.secondary)
                }
            }

            if !chores.isEmpty {
                Section("Active") {
                    ForEach(chores) { chore in
                        ChoreRow(chore: chore)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            Task { await spaceVM.deleteChore(chores[i]) }
                        }
                    }
                }
            }

            if !pausedChores.isEmpty {
                Section("Paused") {
                    ForEach(pausedChores) { chore in
                        ChoreRow(chore: chore)
                    }
                }
            }
        }
    }

    private func quickAddChore() {
        let trimmed = newChoreTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let chore = ChoreModel(title: trimmed, frequency: "Weekly")
        Task { await spaceVM.addChore(chore) }
        newChoreTitle = ""
        isAddFieldFocused = true
    }
}

// MARK: - Chore Row
struct ChoreRow: View {
    let chore: ChoreModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await spaceVM.markChoreDone(chore, completedBy: nil) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(chore.isPaused ? .gray : .green)
            }
            .buttonStyle(.plain)
            .disabled(chore.isPaused)

            VStack(alignment: .leading, spacing: 4) {
                Text(chore.title)
                    .foregroundStyle(chore.isPaused ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(chore.dueDescription)
                        .font(.caption)
                        .foregroundStyle(chore.isOverdue ? .red : .secondary)
                    if chore.assignmentEnum != .unassigned {
                        Text("• \(chore.assignmentEnum.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(chore.frequencyEnum.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
        .onTapGesture { showingEdit = true }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await spaceVM.deleteChore(chore) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                var updated = chore
                updated.isPaused.toggle()
                Task { await spaceVM.updateChore(updated) }
            } label: {
                Label(chore.isPaused ? "Resume" : "Pause", systemImage: chore.isPaused ? "play" : "pause")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await spaceVM.markChoreDone(chore, completedBy: nil) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .sheet(isPresented: $showingEdit) {
            EditChoreSheet(chore: chore)
        }
    }
}

// MARK: - Add Chore Sheet
struct AddChoreSheet: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var frequency: ChoreFrequency = .weekly
    @State private var customDays: Int = 7
    @State private var assignment: ChoreAssignment = .unassigned
    @State private var notes = ""

    var matchingChore: ChoreModel? {
        guard !title.isEmpty else { return nil }
        let normalized = title.lowercased().trimmingCharacters(in: .whitespaces)
        return spaceVM.chores.first { $0.title.lowercased() == normalized }
    }

    var similarChores: [ChoreModel] {
        guard title.count >= 2 else { return [] }
        let normalized = title.lowercased().trimmingCharacters(in: .whitespaces)
        return Array(spaceVM.chores.filter {
            let t = $0.title.lowercased()
            return t.contains(normalized) || normalized.contains(t)
        }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chore Name", text: $title)
                    if matchingChore != nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("A task with this name already exists")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                } footer: {
                    Text("e.g., Vacuum living room, Give dog meds")
                }

                if !similarChores.isEmpty && matchingChore == nil {
                    Section("Similar Existing Tasks") {
                        ForEach(similarChores) { chore in
                            HStack {
                                Text(chore.title).foregroundStyle(.secondary)
                                Spacer()
                                Text(chore.frequencyEnum.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(ChoreFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
                    }
                }

                Section("Assignment") {
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ChoreAssignment.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(3)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let chore = ChoreModel(
                            title: title,
                            frequency: frequency.rawValue,
                            customDays: customDays,
                            assignedTo: assignment.rawValue,
                            notes: notes.isEmpty ? nil : notes
                        )
                        Task {
                            await spaceVM.addChore(chore)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Chore Sheet
struct EditChoreSheet: View {
    let chore: ChoreModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var frequency: ChoreFrequency
    @State private var customDays: Int
    @State private var assignment: ChoreAssignment
    @State private var notes: String
    @State private var isPaused: Bool

    init(chore: ChoreModel) {
        self.chore = chore
        _title = State(initialValue: chore.title)
        _frequency = State(initialValue: chore.frequencyEnum)
        _customDays = State(initialValue: chore.customDays)
        _assignment = State(initialValue: chore.assignmentEnum)
        _notes = State(initialValue: chore.notes ?? "")
        _isPaused = State(initialValue: chore.isPaused)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Chore Name", text: $title) }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(ChoreFrequency.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                    }
                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
                    }
                }

                Section("Assignment") {
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ChoreAssignment.allCases, id: \.self) { a in Text(a.rawValue).tag(a) }
                    }
                }

                Section { TextField("Notes", text: $notes, axis: .vertical).lineLimit(3) }

                Section {
                    Toggle("Paused", isOn: $isPaused)
                } footer: {
                    Text("Paused tasks won't appear in the Today view")
                }

                if chore.lastDoneAt != nil {
                    Section {
                        HStack {
                            Text("Last Completed")
                            Spacer()
                            Text(chore.lastDoneAt!, style: .date).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = chore
                        updated.title = title
                        updated.frequency = frequency.rawValue
                        updated.customDays = customDays
                        updated.assignedTo = assignment.rawValue
                        updated.notes = notes.isEmpty ? nil : notes
                        updated.isPaused = isPaused
                        Task {
                            await spaceVM.updateChore(updated)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
