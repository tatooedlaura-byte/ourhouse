import SwiftUI
import CloudKit

struct OnboardingView: View {
    @EnvironmentObject var sharingService: CloudKitSharingService
    @EnvironmentObject var persistenceController: PersistenceController
    @Environment(\.managedObjectContext) private var viewContext

    @State private var householdName = "Our Home"
    @State private var ownerName = ""
    @State private var showingCreateSpace = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App Icon/Logo area
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

                // iCloud Status
                iCloudStatusView

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button {
                        showingCreateSpace = true
                    } label: {
                        Label("Create Household Space", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(sharingService.iCloudAvailable ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!sharingService.iCloudAvailable)

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
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private var iCloudStatusView: some View {
        HStack(spacing: 12) {
            Image(systemName: sharingService.iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                .font(.title2)
                .foregroundStyle(sharingService.iCloudAvailable ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(sharingService.iCloudAvailable ? "iCloud Connected" : "iCloud Not Available")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !sharingService.iCloudAvailable {
                    Text("Sign in to iCloud in Settings to enable sharing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 32)
    }

    private func createSpace() {
        guard !householdName.isEmpty else {
            errorMessage = "Please enter a household name"
            showingError = true
            return
        }

        let name = ownerName.isEmpty ? "Me" : ownerName
        _ = persistenceController.createDefaultSpace(name: householdName, ownerName: name)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onComplete()
                    }
                    .disabled(householdName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(CloudKitSharingService.shared)
        .environmentObject(PersistenceController.preview)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
