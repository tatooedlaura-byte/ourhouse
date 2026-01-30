import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @EnvironmentObject var authService: AuthenticationService

    @State private var householdName = "Our Home"
    @State private var ownerName = ""
    @State private var showingCreateSpace = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Ours Lists")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Shared lists for your household")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Signed in status
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in as \(authService.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(authService.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showingCreateSpace = true
                    } label: {
                        Label("Create Household Space", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Text("Or wait to accept an invitation from your spouse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showingCreateSpace) {
                CreateSpaceSheet(
                    householdName: $householdName,
                    ownerName: $ownerName,
                    onComplete: createSpace
                )
            }
        }
    }

    private func createSpace() {
        let name = ownerName.isEmpty ? authService.displayName : ownerName
        Task {
            await spaceVM.createSpace(
                name: householdName,
                ownerName: name,
                uid: authService.uid,
                email: authService.email
            )
        }
        showingCreateSpace = false
    }
}

// MARK: - Create Space Sheet
struct CreateSpaceSheet: View {
    @Binding var householdName: String
    @Binding var ownerName: String
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Household Name", text: $householdName)
                } header: {
                    Text("Name your space")
                } footer: {
                    Text("This name will be shown when sharing with your spouse")
                }

                Section {
                    TextField("Your Name (optional)", text: $ownerName)
                } footer: {
                    Text("How you'll appear in shared items")
                }
            }
            .navigationTitle("Create Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onComplete() }
                        .disabled(householdName.isEmpty)
                }
            }
        }
    }
}
