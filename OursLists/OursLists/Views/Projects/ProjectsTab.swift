import SwiftUI
import CoreData

struct ProjectsTab: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sharingService: CloudKitSharingService
    @EnvironmentObject var persistenceController: PersistenceController

    @State private var showingAddProject = false
    @State private var showingSettings = false
    @State private var showArchived = false

    var activeProjects: [Project] {
        space.projectsArray.filter { !$0.isArchived }
    }

    var archivedProjects: [Project] {
        space.projectsArray.filter { $0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeProjects.isEmpty && archivedProjects.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Projects")
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
                        showingAddProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet(space: space)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(space: space)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
        } description: {
            Text("Create projects to track long-term tasks and goals")
        } actions: {
            Button("Create Project") {
                showingAddProject = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            if !activeProjects.isEmpty {
                Section("Active") {
                    ForEach(activeProjects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectRow(project: project)
                        }
                    }
                    .onDelete(perform: deleteActiveProjects)
                }
            }

            if !archivedProjects.isEmpty {
                Section {
                    DisclosureGroup("Archived (\(archivedProjects.count))", isExpanded: $showArchived) {
                        ForEach(archivedProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                        .onDelete(perform: deleteArchivedProjects)
                    }
                }
            }
        }
        .refreshable {
            await persistenceController.performManualSync()
        }
    }

    private func deleteActiveProjects(offsets: IndexSet) {
        withAnimation {
            offsets.map { activeProjects[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }

    private func deleteArchivedProjects(offsets: IndexSet) {
        withAnimation {
            offsets.map { archivedProjects[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Project Row
struct ProjectRow: View {
    @ObservedObject var project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(project.colorValue)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(project.isArchived ? .secondary : .primary)

                if project.tasksArray.isEmpty {
                    Text("No tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(project.incompleteTasks.count) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Progress indicator
            if !project.tasksArray.isEmpty {
                CircularProgressView(progress: project.progress)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Project Sheet
struct AddProjectSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColor = "#007AFF"

    let colorOptions = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                } footer: {
                    Text("e.g., Bathroom Renovation, Garden Project")
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
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func createProject() {
        let project = Project(context: viewContext)
        project.id = UUID()
        project.name = name
        project.color = selectedColor
        project.isArchived = false
        project.createdAt = Date()
        project.space = space

        try? viewContext.save()
        dismiss()
    }
}

struct ProjectsTab_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let space = Space(context: context)
        space.id = UUID()
        space.name = "Our Home"

        return ProjectsTab(space: space)
            .environment(\.managedObjectContext, context)
            .environmentObject(CloudKitSharingService.shared)
    }
}
