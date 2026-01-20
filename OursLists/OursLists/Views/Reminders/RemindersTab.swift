import SwiftUI
import CoreData

struct RemindersTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var persistenceController: PersistenceController

    @State private var showingAddReminder = false
    @State private var showingSettings = false
    @State private var newReminderTitle = ""
    @FocusState private var isAddFieldFocused: Bool

    var reminders: [Reminder] {
        space.remindersArray.filter { !$0.isPaused }
    }

    var upcomingReminders: [Reminder] {
        reminders.filter { $0.isDueSoon || $0.isDueToday || $0.isOverdue }
            .sorted { reminder1, reminder2 in
                if reminder1.isOverdue != reminder2.isOverdue {
                    return reminder1.isOverdue
                }
                if reminder1.isDueToday != reminder2.isDueToday {
                    return reminder1.isDueToday
                }
                return (reminder1.nextDueAt ?? Date()) < (reminder2.nextDueAt ?? Date())
            }
    }

    var pausedReminders: [Reminder] {
        space.remindersArray.filter { $0.isPaused }
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick add section
                Section {
                    HStack {
                        TextField("Add reminder...", text: $newReminderTitle)
                            .focused($isAddFieldFocused)
                            .onSubmit {
                                quickAddReminder()
                            }

                        if !newReminderTitle.isEmpty {
                            Button {
                                quickAddReminder()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.orange)
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
                        .onDelete(perform: deleteReminders)
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
            .refreshable {
                await persistenceController.performManualSync()
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder, onDismiss: {
                newReminderTitle = ""
            }) {
                AddReminderSheet(space: space, initialTitle: newReminderTitle)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    private func quickAddReminder() {
        guard !newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Open the full sheet to set timing
        showingAddReminder = true
    }

    private func deleteReminders(offsets: IndexSet) {
        withAnimation {
            offsets.map { reminders[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Reminder Row
struct ReminderRow: View {
    @ObservedObject var reminder: Reminder
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
                    .foregroundStyle(reminder.isPaused ? .gray : .green)
            }
            .buttonStyle(.plain)
            .disabled(reminder.isPaused)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "")
                    .foregroundStyle(reminder.isPaused ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Due label
                    Text(reminder.dueDescription)
                        .font(.caption)
                        .foregroundStyle(reminder.isOverdue ? .red : .secondary)

                    // Recurrence
                    Text("• \(reminder.recurrenceTypeEnum.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Bell icon
            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewContext.delete(reminder)
                try? viewContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                reminder.isPaused.toggle()
                try? viewContext.save()
            } label: {
                Label(reminder.isPaused ? "Resume" : "Pause", systemImage: reminder.isPaused ? "play" : "pause")
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
            .disabled(reminder.isPaused)
        }
        .sheet(isPresented: $showingEdit) {
            EditReminderSheet(reminder: reminder)
        }
    }

    private func markDone() {
        withAnimation {
            reminder.markDone()
            try? viewContext.save()

            // Reschedule notification for next occurrence
            NotificationService.shared.scheduleReminderNotification(for: reminder)
        }
    }
}

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    @ObservedObject var space: Space
    var initialTitle: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var recurrenceType: Reminder.RecurrenceType = .monthly
    @State private var dayOfMonth = 1
    @State private var monthOfYear = 1
    @State private var notes = ""

    init(space: Space, initialTitle: String = "") {
        self.space = space
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
                        ForEach(Reminder.RecurrenceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Day of Month", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
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
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addReminder() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addReminder() {
        let reminder = Reminder(context: viewContext)
        reminder.id = UUID()
        reminder.title = title
        reminder.recurrenceTypeEnum = recurrenceType
        reminder.dayOfMonth = Int16(dayOfMonth)
        reminder.monthOfYear = Int16(monthOfYear)
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.isPaused = false
        reminder.createdAt = Date()
        reminder.space = space

        try? viewContext.save()

        // Schedule notification
        NotificationService.shared.scheduleReminderNotification(for: reminder)

        dismiss()
    }
}

// MARK: - Edit Reminder Sheet
struct EditReminderSheet: View {
    @ObservedObject var reminder: Reminder
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var recurrenceType: Reminder.RecurrenceType
    @State private var dayOfMonth: Int
    @State private var monthOfYear: Int
    @State private var notes: String
    @State private var isPaused: Bool

    init(reminder: Reminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title ?? "")
        _recurrenceType = State(initialValue: reminder.recurrenceTypeEnum)
        _dayOfMonth = State(initialValue: Int(reminder.dayOfMonth))
        _monthOfYear = State(initialValue: Int(reminder.monthOfYear))
        _notes = State(initialValue: reminder.notes ?? "")
        _isPaused = State(initialValue: reminder.isPaused)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder Name", text: $title)
                }

                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrenceType) {
                        ForEach(Reminder.RecurrenceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Day of Month", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
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
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

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
                            Text(reminder.lastCompletedAt!, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReminder() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveReminder() {
        reminder.title = title
        reminder.recurrenceTypeEnum = recurrenceType
        reminder.dayOfMonth = Int16(dayOfMonth)
        reminder.monthOfYear = Int16(monthOfYear)
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.isPaused = isPaused

        try? viewContext.save()

        // Update notification
        if isPaused {
            NotificationService.shared.cancelReminderNotification(for: reminder)
        } else {
            NotificationService.shared.scheduleReminderNotification(for: reminder)
        }

        dismiss()
    }
}
