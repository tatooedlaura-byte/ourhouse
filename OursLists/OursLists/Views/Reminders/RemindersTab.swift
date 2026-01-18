import SwiftUI
import CoreData

struct RemindersTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService
    @EnvironmentObject var persistenceController: PersistenceController

    @State private var showingAddReminder = false
    @State private var showingSettings = false
    @State private var selectedView: ReminderViewType = .today

    enum ReminderViewType: String, CaseIterable {
        case today = "Today"
        case all = "All"
    }

    var reminders: [Reminder] {
        space.remindersArray.filter { !$0.isPaused }
    }

    var todayReminders: [Reminder] {
        reminders.filter { $0.isOverdue || $0.isDueToday || $0.isDueSoon }
            .sorted { reminder1, reminder2 in
                // Overdue first, then today, then soon
                if reminder1.isOverdue != reminder2.isOverdue {
                    return reminder1.isOverdue
                }
                if reminder1.isDueToday != reminder2.isDueToday {
                    return reminder1.isDueToday
                }
                return (reminder1.nextDueAt ?? Date()) < (reminder2.nextDueAt ?? Date())
            }
    }

    var overdueReminders: [Reminder] {
        reminders.filter { $0.isOverdue }
    }

    var dueTodayReminders: [Reminder] {
        reminders.filter { $0.isDueToday && !$0.isOverdue }
    }

    var upcomingReminders: [Reminder] {
        reminders.filter { !$0.isOverdue && !$0.isDueToday }
            .sorted { ($0.nextDueAt ?? Date()) < ($1.nextDueAt ?? Date()) }
    }

    var pausedReminders: [Reminder] {
        space.remindersArray.filter { $0.isPaused }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View selector
                Picker("View", selection: $selectedView) {
                    ForEach(ReminderViewType.allCases, id: \.self) { type in
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
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    @ViewBuilder
    private var todayView: some View {
        if todayReminders.isEmpty {
            ContentUnavailableView {
                Label("All Caught Up", systemImage: "bell.badge")
            } description: {
                Text("No reminders due today")
            }
        } else {
            List {
                if !overdueReminders.isEmpty {
                    Section("Overdue") {
                        ForEach(overdueReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }

                if !dueTodayReminders.isEmpty {
                    Section("Due Today") {
                        ForEach(dueTodayReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }

                let dueSoon = todayReminders.filter { $0.isDueSoon && !$0.isDueToday && !$0.isOverdue }
                if !dueSoon.isEmpty {
                    Section("Coming Up") {
                        ForEach(dueSoon) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }
            }
            .refreshable {
                await persistenceController.performManualSync()
            }
        }
    }

    @ViewBuilder
    private var allView: some View {
        if reminders.isEmpty && pausedReminders.isEmpty {
            ContentUnavailableView {
                Label("No Reminders", systemImage: "bell")
            } description: {
                Text("Add reminders for recurring tasks like pet medications, maintenance checks, and more")
            } actions: {
                Button("Add Reminder") {
                    showingAddReminder = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                if !overdueReminders.isEmpty {
                    Section("Overdue") {
                        ForEach(overdueReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                        .onDelete { offsets in
                            deleteReminders(offsets: offsets, from: overdueReminders)
                        }
                    }
                }

                if !upcomingReminders.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                        .onDelete { offsets in
                            deleteReminders(offsets: offsets, from: upcomingReminders)
                        }
                    }
                }

                if !pausedReminders.isEmpty {
                    Section("Paused") {
                        ForEach(pausedReminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                        .onDelete { offsets in
                            deleteReminders(offsets: offsets, from: pausedReminders)
                        }
                    }
                }
            }
            .refreshable {
                await persistenceController.performManualSync()
            }
        }
    }

    private func deleteReminders(offsets: IndexSet, from list: [Reminder]) {
        withAnimation {
            offsets.map { list[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct RemindersTab_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let space = Space(context: context)
        space.id = UUID()
        space.name = "Our Home"

        return RemindersTab(space: space)
            .environment(\.managedObjectContext, context)
            .environmentObject(CloudKitSharingService.shared)
            .environmentObject(PersistenceController.preview)
    }
}
