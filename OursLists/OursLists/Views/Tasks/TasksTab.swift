import SwiftUI

struct TasksTab: View {
    var body: some View {
        NavigationStack {
            TasksContent()
        }
    }
}

struct TasksContent: View {
    @State private var selectedSegment: TaskSegment = .chores
    @State private var showingAddChore = false
    @State private var showingAddReminder = false

    enum TaskSegment: String, CaseIterable {
        case chores = "Chores"
        case reminders = "Reminders"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedSegment) {
                ForEach(TaskSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selectedSegment {
                case .chores:
                    ChoresContent()
                case .reminders:
                    RemindersContent()
                }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    switch selectedSegment {
                    case .chores: showingAddChore = true
                    case .reminders: showingAddReminder = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChore) {
            AddChoreSheet()
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet()
        }
    }
}
