import SwiftUI

struct JoinSpaceView: View {
    let pendingSpaces: [SpaceModel]
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var spaceVM: SpaceViewModel

    @State private var isJoining = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "envelope.open.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("You've Been Invited!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                ForEach(pendingSpaces) { space in
                    VStack(spacing: 12) {
                        Text("Join \"\(space.name)\"")
                            .font(.headline)

                        Text("Created by \(space.ownerName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            joinSpace(space)
                        } label: {
                            if isJoining {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Join Household")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isJoining)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 32)

            Button("Create New Household Instead") {
                // Will show onboarding
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func joinSpace(_ space: SpaceModel) {
        guard let spaceId = space.id else { return }
        isJoining = true
        Task {
            do {
                try await HouseholdService.shared.acceptInvite(
                    spaceId: spaceId,
                    uid: authService.uid,
                    email: authService.email
                )
                await spaceVM.loadSpace(for: authService.uid)
            } catch {
                print("Error joining space: \(error)")
            }
            isJoining = false
        }
    }
}
