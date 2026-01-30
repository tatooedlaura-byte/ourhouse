import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            GroceriesTab()
                .tabItem {
                    Label("Groceries", systemImage: "cart.fill")
                }
                .badge(spaceVM.groceryCount > 0 ? spaceVM.groceryCount : 0)
                .tag(1)

            ChoresTab()
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }
                .badge(spaceVM.urgentChoreCount > 0 ? spaceVM.urgentChoreCount : 0)
                .tag(2)

            RemindersTab()
                .tabItem {
                    Label("Reminders", systemImage: "bell.fill")
                }
                .badge(spaceVM.urgentReminderCount > 0 ? spaceVM.urgentReminderCount : 0)
                .tag(3)

            ProjectsTab()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .badge(spaceVM.activeProjectCount > 0 ? spaceVM.activeProjectCount : 0)
                .tag(4)
        }
    }
}
