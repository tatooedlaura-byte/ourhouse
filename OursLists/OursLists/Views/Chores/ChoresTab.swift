import SwiftUI
import CoreData

struct ChoresTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingAddChore = false
    @State private var showingSettings = false
    @State private var selectedView: ChoreViewType = .today

    enum ChoreViewType: String, CaseIterable {
        case today = "Today"
        case all = "All"
    }

    var chores: [Chore] {
        space.choresArray.filter { !$0.isPaused }
    }

    var todayChores: [Chore] {
        chores.filter { $0.isOverdue || $0.isDueToday || $0.isDueSoon }
            .sorted { chore1, chore2 in
                // Overdue first, then today, then soon
                if chore1.isOverdue != chore2.isOverdue {
                    return chore1.isOverdue
                }
                if chore1.isDueToday != chore2.isDueToday {
                    return chore1.isDueToday
                }
                return (chore1.nextDueAt ?? Date()) < (chore2.nextDueAt ?? Date())
            }
    }

    var pausedChores: [Chore] {
        space.choresArray.filter { $0.isPaused }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View selector
                Picker("View", selection: $selectedView) {
                    ForEach(ChoreViewType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch selectedView {
                    case .today:
                        todayView
                    case .all:
                        allView
                    }
                }
            }
            .navigationTitle("Chores")
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
                        showingAddChore = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    @ViewBuilder
    private var todayView: some View {
        if todayChores.isEmpty {
            ContentUnavailableView {
                Label("All Caught Up", systemImage: "checkmark.circle")
            } description: {
                Text("No chores due today")
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
        if chores.isEmpty && pausedChores.isEmpty {
            ContentUnavailableView {
                Label("No Chores", systemImage: "checklist")
            } description: {
                Text("Add recurring chores to keep track of household tasks")
            } actions: {
                Button("Add Chore") {
                    showingAddChore = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                if !chores.isEmpty {
                    Section("Active") {
                        ForEach(chores) { chore in
                            ChoreRow(chore: chore)
                        }
                        .onDelete(perform: deleteChores)
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
    }

    private func deleteChores(offsets: IndexSet) {
        withAnimation {
            offsets.map { chores[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Chore Row
struct ChoreRow: View {
    @ObservedObject var chore: Chore
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            // Done button
            Button {
                markDone()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(chore.isPaused ? .gray : .green)
            }
            .buttonStyle(.plain)
            .disabled(chore.isPaused)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.title ?? "")
                    .foregroundStyle(chore.isPaused ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Due label
                    Text(chore.dueDescription)
                        .font(.caption)
                        .foregroundStyle(chore.isOverdue ? .red : .secondary)

                    // Assignment
                    if chore.assignmentEnum != .unassigned {
                        Text("• \(chore.assignmentEnum.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Frequency badge
            Text(chore.frequencyEnum.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .cornerRadius(4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewContext.delete(chore)
                try? viewContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                chore.isPaused.toggle()
                try? viewContext.save()
            } label: {
                Label(chore.isPaused ? "Resume" : "Pause", systemImage: chore.isPaused ? "play" : "pause")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                markDone()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
            .disabled(chore.isPaused)
        }
        .sheet(isPresented: $showingEdit) {
            EditChoreSheet(chore: chore)
        }
    }

    private func markDone() {
        withAnimation {
            chore.markDone()
            try? viewContext.save()
        }
    }
}

// MARK: - Add Chore Sheet
struct AddChoreSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var frequency: Chore.Frequency = .weekly
    @State private var customDays: Int = 7
    @State private var assignment: Chore.Assignment = .unassigned
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chore Name", text: $title)
                } footer: {
                    Text("e.g., Vacuum living room, Take out trash")
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(Chore.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
                    }
                }

                Section("Assignment") {
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(Chore.Assignment.allCases, id: \.self) { assign in
                            Text(assign.rawValue).tag(assign)
                        }
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("New Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addChore() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addChore() {
        let chore = Chore(context: viewContext)
        chore.id = UUID()
        chore.title = title
        chore.frequencyEnum = frequency
        chore.customDays = Int16(customDays)
        chore.assignmentEnum = assignment
        chore.notes = notes.isEmpty ? nil : notes
        chore.isPaused = false
        chore.createdAt = Date()
        chore.space = space

        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Edit Chore Sheet
struct EditChoreSheet: View {
    @ObservedObject var chore: Chore
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var frequency: Chore.Frequency
    @State private var customDays: Int
    @State private var assignment: Chore.Assignment
    @State private var notes: String
    @State private var isPaused: Bool

    init(chore: Chore) {
        self.chore = chore
        _title = State(initialValue: chore.title ?? "")
        _frequency = State(initialValue: chore.frequencyEnum)
        _customDays = State(initialValue: Int(chore.customDays))
        _assignment = State(initialValue: chore.assignmentEnum)
        _notes = State(initialValue: chore.notes ?? "")
        _isPaused = State(initialValue: chore.isPaused)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chore Name", text: $title)
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(Chore.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
                    }
                }

                Section("Assignment") {
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(Chore.Assignment.allCases, id: \.self) { assign in
                            Text(assign.rawValue).tag(assign)
                        }
                    }
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                Section {
                    Toggle("Paused", isOn: $isPaused)
                } footer: {
                    Text("Paused chores won't appear in the Today view")
                }

                if chore.lastDoneAt != nil {
                    Section {
                        HStack {
                            Text("Last Completed")
                            Spacer()
                            Text(chore.lastDoneAt!, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChore() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveChore() {
        chore.title = title
        chore.frequencyEnum = frequency
        chore.customDays = Int16(customDays)
        chore.assignmentEnum = assignment
        chore.notes = notes.isEmpty ? nil : notes
        chore.isPaused = isPaused

        try? viewContext.save()
        dismiss()
    }
}

struct ChoresTab_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let space = Space(context: context)
        space.id = UUID()
        space.name = "Our Home"

        return ChoresTab(space: space)
            .environment(\.managedObjectContext, context)
            .environmentObject(CloudKitSharingService.shared)
    }
}
