import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    @State private var showingEditSpace = false
    @State private var showingDeleteConfirmation = false
    @State private var showingInvite = false

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
                            Text(spaceVM.space?.name ?? "Our Home")
                                .font(.headline)
                            Text("Owner: \(spaceVM.space?.ownerName ?? "Me")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button { showingEditSpace = true } label: {
                        Label("Edit Household Name", systemImage: "pencil")
                    }
                }

                // Account
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.displayName)
                                .font(.headline)
                            Text(authService.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Members
                    if let space = spaceVM.space {
                        ForEach(space.memberEmails, id: \.self) { email in
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 32)
                                Text(email)
                                    .font(.subheadline)
                                if email == space.memberEmails.first {
                                    Spacer()
                                    Text("Owner")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        showingInvite = true
                    } label: {
                        Label("Invite Spouse", systemImage: "person.badge.plus")
                    }

                    Button {
                        authService.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }

                // Notifications
                Section {
                    HStack {
                        Image(systemName: notificationService.isAuthorized ? "bell.fill" : "bell.slash.fill")
                            .foregroundStyle(notificationService.isAuthorized ? .green : .gray)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminders")
                                .font(.headline)
                            Text(notificationService.isAuthorized ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !notificationService.isAuthorized {
                        Button {
                            Task { await notificationService.requestAuthorization() }
                        } label: {
                            Label("Enable Reminders", systemImage: "bell.badge")
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get reminded when chores and tasks are due.")
                }

                // Appearance
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose light, dark, or match your device settings.")
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
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditSpace) {
                EditSpaceSheet()
            }
            .sheet(isPresented: $showingInvite) {
                InviteMemberView()
            }
            .alert("Delete Household?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await spaceVM.deleteSpace()
                        dismiss()
                    }
                }
            } message: {
                Text("This will permanently delete all data in this household. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Edit Space Sheet
struct EditSpaceSheet: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ownerName: String = ""

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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await spaceVM.updateSpaceName(name)
                            if !ownerName.isEmpty {
                                await spaceVM.updateOwnerName(ownerName)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = spaceVM.space?.name ?? ""
                ownerName = spaceVM.space?.ownerName ?? ""
            }
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
