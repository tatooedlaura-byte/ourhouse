import SwiftUI
import CloudKit

struct SettingsView: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var showingShareSheet = false
    @State private var showingEditSpace = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Household Info
                Section("Household") {
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(space.name ?? "Our Home")
                                .font(.headline)
                            Text("Created by \(space.ownerName ?? "Me")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        showingEditSpace = true
                    } label: {
                        Label("Edit Household Name", systemImage: "pencil")
                    }
                }

                // Sharing Section
                Section {
                    // iCloud Status
                    HStack {
                        Image(systemName: sharingService.iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                            .foregroundStyle(sharingService.iCloudAvailable ? .green : .red)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud")
                                .font(.headline)
                            Text(sharingService.iCloudAvailable ? "Connected" : "Not Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Sharing Status
                    HStack {
                        Image(systemName: sharingStatusIcon)
                            .foregroundStyle(sharingStatusColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sharing")
                                .font(.headline)
                            Text(sharingStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Share/Manage Button
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label(
                            space.isShared ? "Manage Sharing" : "Invite Spouse",
                            systemImage: space.isShared ? "person.2.fill" : "person.badge.plus"
                        )
                    }
                    .disabled(!sharingService.iCloudAvailable)
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("Share your household with your spouse so you can both view and edit lists together.")
                }

                // Participants
                if !sharingService.participants.isEmpty {
                    Section("People with Access") {
                        ForEach(sharingService.participants, id: \.userIdentity.userRecordID) { participant in
                            ParticipantRow(participant: participant)
                        }
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Household", systemImage: "trash")
                    }
                } footer: {
                    Text("This will permanently delete all your lists, chores, and projects.")
                }
            }
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSpaceView(space: space)
            }
            .sheet(isPresented: $showingEditSpace) {
                EditSpaceSheet(space: space)
            }
            .alert("Delete Household?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSpace()
                }
            } message: {
                Text("This will permanently delete all data in this household. This action cannot be undone.")
            }
            .task {
                await sharingService.fetchParticipants(for: space)
            }
        }
    }

    private var sharingStatusIcon: String {
        switch sharingService.sharingStatus {
        case .notShared: return "person.slash"
        case .pendingShare: return "clock"
        case .shared: return "person.2.fill"
        case .sharedWithMe: return "person.2.fill"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var sharingStatusColor: Color {
        switch sharingService.sharingStatus {
        case .notShared: return .gray
        case .pendingShare: return .orange
        case .shared, .sharedWithMe: return .green
        case .error: return .red
        }
    }

    private var sharingStatusText: String {
        switch sharingService.sharingStatus {
        case .notShared: return "Not shared yet"
        case .pendingShare: return "Invitation pending"
        case .shared: return "Shared with spouse"
        case .sharedWithMe: return "Shared by spouse"
        case .error(let message): return message
        }
    }

    private func deleteSpace() {
        viewContext.delete(space)
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - Participant Row
struct ParticipantRow: View {
    let participant: CKShare.Participant

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(participantName)
                    .font(.headline)

                Text(roleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    private var participantName: String {
        if let nameComponents = participant.userIdentity.nameComponents {
            return PersonNameComponentsFormatter().string(from: nameComponents)
        }
        return "Unknown"
    }

    private var roleText: String {
        switch participant.role {
        case .owner: return "Owner"
        case .privateUser: return "Member"
        case .publicUser: return "Public"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch participant.acceptanceStatus {
        case .accepted: return .green
        case .pending: return .orange
        case .removed: return .red
        case .unknown: return .gray
        @unknown default: return .gray
        }
    }
}

// MARK: - Share Space View
struct ShareSpaceView: View {
    @ObservedObject var space: Space
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sharingService: CloudKitSharingService

    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Share \"\(space.name ?? "Our Home")\"")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Invite your spouse to share this household. They'll be able to view and edit all lists, chores, and projects.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    presentSharing()
                } label: {
                    if isSharing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Share via iCloud")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .disabled(isSharing)

                Text("Your spouse will receive a notification to accept the invitation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Share Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func presentSharing() {
        isSharing = true

        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isSharing = false
            return
        }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        Task {
            await sharingService.presentSharingUI(for: space, from: topVC)
            await MainActor.run {
                isSharing = false
                dismiss()
            }
        }
    }
}

// MARK: - Edit Space Sheet
struct EditSpaceSheet: View {
    @ObservedObject var space: Space
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var ownerName: String

    init(space: Space) {
        self.space = space
        _name = State(initialValue: space.name ?? "")
        _ownerName = State(initialValue: space.ownerName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Household Name", text: $name)
                }

                Section {
                    TextField("Your Name", text: $ownerName)
                } footer: {
                    Text("How you appear in shared items")
                }
            }
            .navigationTitle("Edit Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSpace() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveSpace() {
        space.name = name
        space.ownerName = ownerName.isEmpty ? "Me" : ownerName

        try? viewContext.save()
        dismiss()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let space = Space(context: context)
        space.id = UUID()
        space.name = "Our Home"
        space.ownerName = "Laura"

        return SettingsView(space: space)
            .environment(\.managedObjectContext, context)
            .environmentObject(CloudKitSharingService.shared)
    }
}
