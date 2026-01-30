import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var appState: AppState
    @StateObject private var spaceVM = SpaceViewModel()

    @State private var pendingSpaces: [SpaceModel] = []
    @State private var checkedInvites = false

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView("Loading...")
            } else if !authService.isSignedIn {
                SignInView()
            } else if spaceVM.isLoading {
                ProgressView("Loading household...")
            } else if spaceVM.space != nil {
                MainTabView()
                    .environmentObject(spaceVM)
            } else if !pendingSpaces.isEmpty {
                JoinSpaceView(pendingSpaces: pendingSpaces)
                    .environmentObject(spaceVM)
            } else {
                OnboardingView()
                    .environmentObject(spaceVM)
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                loadData()
            } else {
                spaceVM.stopListening()
                pendingSpaces = []
                checkedInvites = false
            }
        }
        .onChange(of: spaceVM.space?.id) { _, _ in
            // When space is set (e.g. after joining), clear pending
            if spaceVM.space != nil {
                pendingSpaces = []
            }
        }
        .task {
            if authService.isSignedIn {
                loadData()
            }
        }
    }

    private func loadData() {
        Task {
            await spaceVM.loadSpace(for: authService.uid)
            if spaceVM.space == nil && !checkedInvites {
                checkedInvites = true
                do {
                    pendingSpaces = try await HouseholdService.shared.checkPendingInvites(for: authService.email)
                } catch {
                    print("Error checking invites: \(error)")
                }
            }
        }
    }
}
