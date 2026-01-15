import SwiftUI
import CoreData

struct ProjectDetailView: View {
    @ObservedObject var project: Project
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var persistenceController: PersistenceController

    @State private var newTaskTitle = ""
    @State private var showingAddTask = false
    @State private var showingEditProject = false
    @State private var showCompleted = false
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        List {
            // Quick add section
            Section {
                HStack {
                    TextField("Add task...", text: $newTaskTitle)
                        .focused($isAddFieldFocused)
                        .onSubmit {
                            quickAddTask()
                        }

                    if !newTaskTitle.isEmpty {
                        Button {
                            quickAddTask()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(project.colorValue)
                        }
                    }
                }
            }

            // Incomplete tasks
            if !project.incompleteTasks.isEmpty {
                Section("To Do") {
                    ForEach(project.incompleteTasks) { task in
                        TaskRow(task: task, accentColor: project.colorValue)
                    }
                    .onDelete { offsets in
                        deleteTasks(offsets, from: project.incompleteTasks)
                    }
                }
            }

            // Completed tasks (collapsible)
            if !project.completedTasks.isEmpty {
                Section {
                    DisclosureGroup("Completed (\(project.completedTasks.count))", isExpanded: $showCompleted) {
                        ForEach(project.completedTasks) { task in
                            TaskRow(task: task, accentColor: project.colorValue)
                        }
                        .onDelete { offsets in
                            deleteTasks(offsets, from: project.completedTasks)
                        }
                    }
                }
            }

            // Project info
            Section {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(project.createdAt ?? Date(), style: .date)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(project.completedTasks.count)/\(project.tasksArray.count) tasks")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable {
            await persistenceController.performManualSync()
        }
        .navigationTitle(project.name ?? "Project")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddTask = true
                    } label: {
                        Label("Add Task with Details", systemImage: "plus.circle")
                    }

                    Button {
                        showingEditProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    Divider()

                    Button {
                        project.isArchived.toggle()
                        try? viewContext.save()
                    } label: {
                        Label(project.isArchived ? "Unarchive" : "Archive", systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(project: project)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectSheet(project: project)
        }
    }

    private func quickAddTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = ProjectTask(context: viewContext)
        task.id = UUID()
        task.title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        task.createdAt = Date()
        task.priority = ProjectTask.Priority.medium.rawValue
        task.project = project

        try? viewContext.save()
        newTaskTitle = ""
    }

    private func deleteTasks(_ offsets: IndexSet, from tasks: [ProjectTask]) {
        withAnimation {
            offsets.map { tasks[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Task Row
struct TaskRow: View {
    @ObservedObject var task: ProjectTask
    @Environment(\.managedObjectContext) private var viewContext

    var accentColor: Color

    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                toggleTask()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title ?? "")
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    if task.priorityEnum == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                HStack(spacing: 8) {
                    if let note = task.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                            Text(dueDate, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    if task.assignmentEnum != .unassigned {
                        Text("• \(task.assignmentEnum.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewContext.delete(task)
                try? viewContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                toggleTask()
            } label: {
                Label(task.isCompleted ? "Undo" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isCompleted ? .orange : .green)
        }
        .sheet(isPresented: $showingEdit) {
            EditTaskSheet(task: task)
        }
    }

    private func toggleTask() {
        withAnimation {
            task.toggleCompletion()
            try? viewContext.save()
        }
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var project: Project
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var priority: ProjectTask.Priority = .medium
    @State private var assignment: ProjectTask.Assignment = .unassigned
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task Title", text: $title)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(ProjectTask.Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }

                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ProjectTask.Assignment.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addTask() {
        let task = ProjectTask(context: viewContext)
        task.id = UUID()
        task.title = title
        task.note = note.isEmpty ? nil : note
        task.priorityEnum = priority
        task.assignmentEnum = assignment
        task.dueDate = hasDueDate ? dueDate : nil
        task.createdAt = Date()
        task.project = project

        try? viewContext.save()

        // Schedule notification if has due date
        if hasDueDate {
            NotificationService.shared.scheduleTaskNotification(for: task)
        }

        dismiss()
    }
}

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    @ObservedObject var task: ProjectTask
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var note: String
    @State private var priority: ProjectTask.Priority
    @State private var assignment: ProjectTask.Assignment
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: ProjectTask) {
        self.task = task
        _title = State(initialValue: task.title ?? "")
        _note = State(initialValue: task.note ?? "")
        _priority = State(initialValue: task.priorityEnum)
        _assignment = State(initialValue: task.assignmentEnum)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task Title", text: $title)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(ProjectTask.Priority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }

                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ProjectTask.Assignment.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Notes", text: $note, axis: .vertical)
                        .lineLimit(3)
                }

                if task.completedAt != nil {
                    Section {
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text(task.completedAt!, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        task.title = title
        task.note = note.isEmpty ? nil : note
        task.priorityEnum = priority
        task.assignmentEnum = assignment
        task.dueDate = hasDueDate ? dueDate : nil

        try? viewContext.save()

        // Update notification
        if hasDueDate && !task.isCompleted {
            NotificationService.shared.scheduleTaskNotification(for: task)
        } else {
            NotificationService.shared.cancelTaskNotification(for: task)
        }

        dismiss()
    }
}

// MARK: - Edit Project Sheet
struct EditProjectSheet: View {
    @ObservedObject var project: Project
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedColor: String

    let colorOptions = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"]

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name ?? "")
        _selectedColor = State(initialValue: project.color ?? "#007AFF")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProject() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveProject() {
        project.name = name
        project.color = selectedColor

        try? viewContext.save()
        dismiss()
    }
}

struct ProjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let project = Project(context: context)
        project.id = UUID()
        project.name = "Bathroom Renovation"
        project.color = "#007AFF"

        return NavigationStack {
            ProjectDetailView(project: project)
        }
        .environment(\.managedObjectContext, context)
    }
}
