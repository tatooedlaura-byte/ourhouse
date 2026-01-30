import SwiftUI

struct ProjectsTab: View {
    @EnvironmentObject var spaceVM: SpaceViewModel

    @State private var showingAddProject = false
    @State private var showingSettings = false
    @State private var showArchived = false

    var activeProjects: [ProjectModel] { spaceVM.projects.filter { !$0.isArchived } }
    var archivedProjects: [ProjectModel] { spaceVM.projects.filter { $0.isArchived } }

    var body: some View {
        NavigationStack {
            Group {
                if activeProjects.isEmpty && archivedProjects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "folder")
                    } description: {
                        Text("Create projects to track long-term tasks and goals")
                    } actions: {
                        Button("Create Project") { showingAddProject = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !activeProjects.isEmpty {
                            Section("Active") {
                                ForEach(activeProjects) { project in
                                    if let spaceId = spaceVM.spaceId, let projectId = project.id {
                                        NavigationLink(destination: ProjectDetailView(project: project, spaceId: spaceId, projectId: projectId)) {
                                            ProjectRow(project: project)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    for i in offsets {
                                        Task { await spaceVM.deleteProject(activeProjects[i]) }
                                    }
                                }
                            }
                        }

                        if !archivedProjects.isEmpty {
                            Section {
                                DisclosureGroup("Archived (\(archivedProjects.count))", isExpanded: $showArchived) {
                                    ForEach(archivedProjects) { project in
                                        if let spaceId = spaceVM.spaceId, let projectId = project.id {
                                            NavigationLink(destination: ProjectDetailView(project: project, spaceId: spaceId, projectId: projectId)) {
                                                ProjectRow(project: project)
                                            }
                                        }
                                    }
                                    .onDelete { offsets in
                                        for i in offsets {
                                            Task { await spaceVM.deleteProject(archivedProjects[i]) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingAddProject = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape").font(.body)
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) { AddProjectSheet() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}

// MARK: - Project Row
struct ProjectRow: View {
    let project: ProjectModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(project.colorValue)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(project.isArchived ? .secondary : .primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 3)
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
    @EnvironmentObject var spaceVM: SpaceViewModel
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
                                    Circle().stroke(Color.primary, lineWidth: selectedColor == hex ? 3 : 0)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let project = ProjectModel(name: name, color: selectedColor)
                        Task {
                            await spaceVM.addProject(project)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
