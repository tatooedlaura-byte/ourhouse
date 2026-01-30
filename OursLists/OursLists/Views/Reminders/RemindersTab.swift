import SwiftUI

struct RemindersTab: View {
    @EnvironmentObject var spaceVM: SpaceViewModel

    @State private var showingAddReminder = false
    @State private var showingSettings = false
    @State private var newReminderTitle = ""
    @FocusState private var isAddFieldFocused: Bool

    var reminders: [ReminderModel] { spaceVM.reminders.filter { !$0.isPaused } }

    var upcomingReminders: [ReminderModel] {
        reminders.filter { $0.isDueSoon || $0.isDueToday || $0.isOverdue }
            .sorted { r1, r2 in
                if r1.isOverdue != r2.isOverdue { return r1.isOverdue }
                if r1.isDueToday != r2.isDueToday { return r1.isDueToday }
                return (r1.nextDueAt ?? Date()) < (r2.nextDueAt ?? Date())
            }
    }

    var pausedReminders: [ReminderModel] { spaceVM.reminders.filter { $0.isPaused } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add reminder...", text: $newReminderTitle)
                            .focused($isAddFieldFocused)
                            .onSubmit { quickAddReminder() }
                        if !newReminderTitle.isEmpty {
                            Button { quickAddReminder() } label: {
                                Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                            }
                        }
                    }
                }

                if reminders.isEmpty && pausedReminders.isEmpty {
                    Section {
                        Text("Add reminders for monthly bills, pet meds, filter changes")
                            .foregroundStyle(.secondary)
                    }
                }

                if !upcomingReminders.isEmpty {
                    Section("Coming Up") {
                        ForEach(upcomingReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }

                if !reminders.isEmpty {
                    Section("All Reminders") {
                        ForEach(reminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                Task { await spaceVM.deleteReminder(reminders[i]) }
                            }
                        }
                    }
                }

                if !pausedReminders.isEmpty {
                    Section("Paused") {
                        ForEach(pausedReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingAddReminder = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape").font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder, onDismiss: { newReminderTitle = "" }) {
                AddReminderSheet(initialTitle: newReminderTitle)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private func quickAddReminder() {
        guard !newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        showingAddReminder = true
    }
}

// MARK: - Reminder Row
struct ReminderRow: View {
    let reminder: ReminderModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await spaceVM.markReminderDone(reminder) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isPaused ? .gray : .green)
            }
            .buttonStyle(.plain)
            .disabled(reminder.isPaused)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .foregroundStyle(reminder.isPaused ? .secondary : .primary)
                HStack(spacing: 8) {
                    Text(reminder.dueDescription)
                        .font(.caption)
                        .foregroundStyle(reminder.isOverdue ? .red : .secondary)
                    Text("• \(reminder.recurrenceEnum.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .contentShape(Rectangle())
        .onTapGesture { showingEdit = true }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await spaceVM.deleteReminder(reminder) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                var updated = reminder
                updated.isPaused.toggle()
                Task { await spaceVM.updateReminder(updated) }
            } label: {
                Label(reminder.isPaused ? "Resume" : "Pause", systemImage: reminder.isPaused ? "play" : "pause")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await spaceVM.markReminderDone(reminder) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .sheet(isPresented: $showingEdit) {
            EditReminderSheet(reminder: reminder)
        }
    }
}

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    var initialTitle: String = ""
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var recurrenceType: RecurrenceType = .monthly
    @State private var dayOfMonth = 1
    @State private var monthOfYear = 1
    @State private var notes = ""

    init(initialTitle: String = "") {
        self.initialTitle = initialTitle
        _title = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder Name", text: $title)
                } footer: {
                    Text("e.g., Dog heartworm meds, Change furnace filter")
                }

                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrenceType) {
                        ForEach(RecurrenceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Picker("Day of Month", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in Text("\(day)").tag(day) }
                    }
                    if recurrenceType == .yearly {
                        Picker("Month", selection: $monthOfYear) {
                            ForEach(1...12, id: \.self) { month in
                                Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                            }
                        }
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(3)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let reminder = ReminderModel(
                            title: title,
                            recurrenceType: recurrenceType.rawValue,
                            dayOfMonth: dayOfMonth,
                            monthOfYear: monthOfYear,
                            notes: notes.isEmpty ? nil : notes
                        )
                        Task {
                            await spaceVM.addReminder(reminder)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Reminder Sheet
struct EditReminderSheet: View {
    let reminder: ReminderModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var recurrenceType: RecurrenceType
    @State private var dayOfMonth: Int
    @State private var monthOfYear: Int
    @State private var notes: String
    @State private var isPaused: Bool

    init(reminder: ReminderModel) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _recurrenceType = State(initialValue: reminder.recurrenceEnum)
        _dayOfMonth = State(initialValue: reminder.dayOfMonth)
        _monthOfYear = State(initialValue: reminder.monthOfYear)
        _notes = State(initialValue: reminder.notes ?? "")
        _isPaused = State(initialValue: reminder.isPaused)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Reminder Name", text: $title) }

                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrenceType) {
                        ForEach(RecurrenceType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                    }
                    Picker("Day of Month", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in Text("\(day)").tag(day) }
                    }
                    if recurrenceType == .yearly {
                        Picker("Month", selection: $monthOfYear) {
                            ForEach(1...12, id: \.self) { m in
                                Text(DateFormatter().monthSymbols[m - 1]).tag(m)
                            }
                        }
                    }
                }

                Section { TextField("Notes", text: $notes, axis: .vertical).lineLimit(3) }

                Section {
                    Toggle("Paused", isOn: $isPaused)
                } footer: {
                    Text("Paused reminders won't show notifications")
                }

                if reminder.lastCompletedAt != nil {
                    Section {
                        HStack {
                            Text("Last Completed")
                            Spacer()
                            Text(reminder.lastCompletedAt!, style: .date).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = reminder
                        updated.title = title
                        updated.recurrenceType = recurrenceType.rawValue
                        updated.dayOfMonth = dayOfMonth
                        updated.monthOfYear = monthOfYear
                        updated.notes = notes.isEmpty ? nil : notes
                        updated.isPaused = isPaused
                        Task {
                            await spaceVM.updateReminder(updated)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
