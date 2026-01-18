import SwiftUI

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var frequency: Reminder.Frequency = .weekly
    @State private var customDays: Int = 7
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder Name", text: $title)
                } footer: {
                    Text("e.g., Give dog heartworm pill, Check softener salt")
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(Reminder.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
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
        reminder.frequencyEnum = frequency
        reminder.customDays = Int16(customDays)
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.isPaused = false
        reminder.createdAt = Date()
        reminder.space = space

        // Set initial due date based on frequency
        let daysToAdd: Int
        if frequency == .custom {
            daysToAdd = customDays
        } else {
            daysToAdd = frequency.days
        }
        reminder.nextDueAt = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())

        try? viewContext.save()

        // Schedule notification for new reminder
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
    @State private var frequency: Reminder.Frequency
    @State private var customDays: Int
    @State private var notes: String
    @State private var isPaused: Bool

    init(reminder: Reminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title ?? "")
        _frequency = State(initialValue: reminder.frequencyEnum)
        _customDays = State(initialValue: Int(reminder.customDays))
        _notes = State(initialValue: reminder.notes ?? "")
        _isPaused = State(initialValue: reminder.isPaused)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder Name", text: $title)
                }

                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(Reminder.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    if frequency == .custom {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...365)
                    }
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                Section {
                    Toggle("Paused", isOn: $isPaused)
                } footer: {
                    Text("Paused reminders won't appear in the Today view or send notifications")
                }

                if reminder.nextDueAt != nil {
                    Section {
                        HStack {
                            Text("Next Due")
                            Spacer()
                            Text(reminder.nextDueAt!, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        reminder.frequencyEnum = frequency
        reminder.customDays = Int16(customDays)
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
