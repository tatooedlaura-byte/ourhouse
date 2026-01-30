import SwiftUI

struct InviteMemberView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSending = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Spouse's email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Text("Invite by Email")
                } footer: {
                    Text("Enter the email your spouse uses with their Google account. They'll see the invite when they sign in to the app.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if showingSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Invitation sent!")
                        }
                    }
                }

                // Show pending invites
                if let space = spaceVM.space, !space.invitedEmails.isEmpty {
                    Section("Pending Invitations") {
                        ForEach(space.invitedEmails, id: \.self) { invited in
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.orange)
                                Text(invited)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invite Spouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendInvite()
                    }
                    .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
            }
        }
    }

    private func sendInvite() {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        guard let spaceId = spaceVM.spaceId else { return }

        isSending = true
        errorMessage = nil

        Task {
            do {
                try await HouseholdService.shared.inviteMember(email: trimmed, to: spaceId)
                showingSuccess = true
                email = ""
                // Refresh space data
                if let uid = spaceVM.space?.ownerUid {
                    await spaceVM.loadSpace(for: uid)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
