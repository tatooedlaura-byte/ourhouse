import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var spaceVM: SpaceViewModel
    @State private var selectedTab = 0

    var overdueCount: Int {
        spaceVM.chores.filter { $0.isOverdue && !$0.isPaused }.count
        + spaceVM.reminders.filter { $0.isOverdue && !$0.isPaused }.count
    }

    var urgentTaskCount: Int {
        spaceVM.chores.filter { ($0.isOverdue || $0.isDueToday) && !$0.isPaused }.count
        + spaceVM.reminders.filter { ($0.isOverdue || $0.isDueToday) && !$0.isPaused }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)
                .badge(overdueCount)

            GroceriesTab()
                .tabItem {
                    Label("Groceries", systemImage: "cart.fill")
                }
                .tag(1)
                .badge(spaceVM.groceryLists.count)

            TasksTab()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(2)
                .badge(urgentTaskCount)

            ProjectsTab()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(3)
                .badge(spaceVM.activeProjectCount)
        }
    }
}
