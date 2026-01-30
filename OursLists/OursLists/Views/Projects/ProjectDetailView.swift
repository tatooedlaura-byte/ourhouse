import SwiftUI
import FirebaseFirestore

struct ProjectDetailView: View {
    let project: ProjectModel
    let spaceId: String
    let projectId: String
    @EnvironmentObject var spaceVM: SpaceViewModel

    @StateObject private var taskVM: ProjectTaskViewModel

    @State private var newTaskTitle = ""
    @State private var showingAddTask = false
    @State private var showingEditProject = false
    @State private var showCompleted = false
    @FocusState private var isAddFieldFocused: Bool

    init(project: ProjectModel, spaceId: String, projectId: String) {
        self.project = project
        self.spaceId = spaceId
        self.projectId = projectId
        _taskVM = StateObject(wrappedValue: ProjectTaskViewModel(spaceId: spaceId, projectId: projectId))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add task...", text: $newTaskTitle)
                        .focused($isAddFieldFocused)
                        .onSubmit { quickAddTask() }
                    if !newTaskTitle.isEmpty {
                        Button { quickAddTask() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(project.colorValue)
                        }
                    }
                }
            }

            if !taskVM.incompleteTasks.isEmpty {
                Section("To Do") {
                    ForEach(taskVM.incompleteTasks) { task in
                        ProjectTaskRow(task: task, accentColor: project.colorValue, taskVM: taskVM)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            Task { await taskVM.deleteTask(taskVM.incompleteTasks[i]) }
                        }
                    }
                }
            }

            if !taskVM.completedTasks.isEmpty {
                Section {
                    DisclosureGroup("Completed (\(taskVM.completedTasks.count))", isExpanded: $showCompleted) {
                        ForEach(taskVM.completedTasks) { task in
                            ProjectTaskRow(task: task, accentColor: project.colorValue, taskVM: taskVM)
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                Task { await taskVM.deleteTask(taskVM.completedTasks[i]) }
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(project.createdAt, style: .date).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(taskVM.completedTasks.count)/\(taskVM.tasks.count) tasks").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(project.name)
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
                        var updated = project
                        updated.isArchived.toggle()
                        Task { await spaceVM.updateProject(updated) }
                    } label: {
                        Label(project.isArchived ? "Unarchive" : "Archive", systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(taskVM: taskVM)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectSheet(project: project)
        }
    }

    private func quickAddTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let task = ProjectTaskModel(title: trimmed)
        Task { await taskVM.addTask(task) }
        newTaskTitle = ""
        isAddFieldFocused = true
    }
}

// MARK: - Project Task ViewModel
@MainActor
class ProjectTaskViewModel: ObservableObject {
    @Published var tasks: [ProjectTaskModel] = []

    private let firestore = FirestoreService.shared
    private var listener: ListenerRegistration?
    let spaceId: String
    let projectId: String

    var incompleteTasks: [ProjectTaskModel] {
        tasks.filter { $0.completedAt == nil }
            .sorted { t1, t2 in
                if t1.priority != t2.priority { return t1.priority > t2.priority }
                return t1.createdAt < t2.createdAt
            }
    }

    var completedTasks: [ProjectTaskModel] {
        tasks.filter { $0.completedAt != nil }
    }

    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count)
    }

    init(spaceId: String, projectId: String) {
        self.spaceId = spaceId
        self.projectId = projectId
        startListening()
    }

    func startListening() {
        let collection = firestore.projectTasksCollection(spaceId: spaceId, projectId: projectId)
        listener = collection.addSnapshotListener { [weak self] snapshot, _ in
            guard let documents = snapshot?.documents else { return }
            let tasks = documents.compactMap { try? $0.data(as: ProjectTaskModel.self) }
            Task { @MainActor in self?.tasks = tasks }
        }
    }

    func addTask(_ task: ProjectTaskModel) async {
        let collection = firestore.projectTasksCollection(spaceId: spaceId, projectId: projectId)
        do {
            _ = try await firestore.addDocument(to: collection, data: task)
        } catch {
            print("Error adding task: \(error)")
        }
    }

    func updateTask(_ task: ProjectTaskModel) async {
        guard let taskId = task.id else { return }
        let collection = firestore.projectTasksCollection(spaceId: spaceId, projectId: projectId)
        do {
            try await firestore.updateDocument(in: collection, id: taskId, data: task)
        } catch {
            print("Error updating task: \(error)")
        }
    }

    func toggleCompletion(_ task: ProjectTaskModel) async {
        var updated = task
        updated.completedAt = task.completedAt == nil ? Date() : nil
        await updateTask(updated)
    }

    func deleteTask(_ task: ProjectTaskModel) async {
        guard let taskId = task.id else { return }
        let collection = firestore.projectTasksCollection(spaceId: spaceId, projectId: projectId)
        do {
            try await firestore.deleteDocument(in: collection, id: taskId)
        } catch {
            print("Error deleting task: \(error)")
        }
    }

    deinit {
        listener?.remove()
    }
}

// MARK: - Project Task Row
struct ProjectTaskRow: View {
    let task: ProjectTaskModel
    var accentColor: Color
    @ObservedObject var taskVM: ProjectTaskViewModel
    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await taskVM.toggleCompletion(task) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
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
        .onTapGesture { showingEdit = true }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await taskVM.deleteTask(task) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await taskVM.toggleCompletion(task) }
            } label: {
                Label(task.isCompleted ? "Undo" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isCompleted ? .orange : .green)
        }
        .sheet(isPresented: $showingEdit) {
            EditTaskSheet(task: task, taskVM: taskVM)
        }
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var taskVM: ProjectTaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var priority: TaskPriority = .medium
    @State private var assignment: ChoreAssignment = .unassigned
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Task Title", text: $title) }
                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.label).tag(p) }
                    }
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ChoreAssignment.allCases, id: \.self) { a in Text(a.rawValue).tag(a) }
                    }
                }
                Section {
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section {
                    TextField("Notes (optional)", text: $note, axis: .vertical).lineLimit(3)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let task = ProjectTaskModel(
                            title: title,
                            note: note.isEmpty ? nil : note,
                            priority: priority.rawValue,
                            assignedTo: assignment == .unassigned ? nil : assignment.rawValue,
                            dueDate: hasDueDate ? dueDate : nil
                        )
                        Task {
                            await taskVM.addTask(task)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    let task: ProjectTaskModel
    @ObservedObject var taskVM: ProjectTaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var note: String
    @State private var priority: TaskPriority
    @State private var assignment: ChoreAssignment
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: ProjectTaskModel, taskVM: ProjectTaskViewModel) {
        self.task = task
        self.taskVM = taskVM
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
        _priority = State(initialValue: task.priorityEnum)
        _assignment = State(initialValue: task.assignmentEnum)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Task Title", text: $title) }
                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.label).tag(p) }
                    }
                    Picker("Assigned To", selection: $assignment) {
                        ForEach(ChoreAssignment.allCases, id: \.self) { a in Text(a.rawValue).tag(a) }
                    }
                }
                Section {
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section { TextField("Notes", text: $note, axis: .vertical).lineLimit(3) }
                if task.completedAt != nil {
                    Section {
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text(task.completedAt!, style: .date).foregroundStyle(.secondary)
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
                        var updated = task
                        updated.title = title
                        updated.note = note.isEmpty ? nil : note
                        updated.priority = priority.rawValue
                        updated.assignedTo = assignment == .unassigned ? nil : assignment.rawValue
                        updated.dueDate = hasDueDate ? dueDate : nil
                        Task {
                            await taskVM.updateTask(updated)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Project Sheet
struct EditProjectSheet: View {
    let project: ProjectModel
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedColor: String

    let colorOptions = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"]

    init(project: ProjectModel) {
        self.project = project
        _name = State(initialValue: project.name)
        _selectedColor = State(initialValue: project.color)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Project Name", text: $name) }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == hex ? 3 : 0))
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = project
                        updated.name = name
                        updated.color = selectedColor
                        Task {
                            await spaceVM.updateProject(updated)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
