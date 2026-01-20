import SwiftUI

struct MainTabView: View {
    @ObservedObject var space: Space
    @State private var selectedTab = 0

    // Badge counts for tabs
    var groceryCount: Int {
        space.groceryListsArray.reduce(0) { $0 + $1.uncheckedCount }
    }

    var choreCount: Int {
        space.choresArray.filter { !$0.isPaused && ($0.isOverdue || $0.isDueToday || $0.isDueSoon) }.count
    }

    var reminderCount: Int {
        space.remindersArray.filter { !$0.isPaused && ($0.isOverdue || $0.isDueToday || $0.isDueSoon) }.count
    }

    var projectCount: Int {
        space.projectsArray.filter { !$0.isArchived }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(space: space, selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            GroceriesTab(space: space)
                .tabItem {
                    Label("Groceries", systemImage: "cart.fill")
                }
                .badge(groceryCount > 0 ? groceryCount : 0)
                .tag(1)

            ChoresTab(space: space)
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }
                .badge(choreCount > 0 ? choreCount : 0)
                .tag(2)

            RemindersTab(space: space)
                .tabItem {
                    Label("Reminders", systemImage: "bell.fill")
                }
                .badge(reminderCount > 0 ? reminderCount : 0)
                .tag(3)

            ProjectsTab(space: space)
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .badge(projectCount > 0 ? projectCount : 0)
                .tag(4)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let space = Space(context: context)
        space.id = UUID()
        space.name = "Our Home"
        space.createdAt = Date()

        return MainTabView(space: space)
            .environment(\.managedObjectContext, context)
            .environmentObject(PersistenceController.preview)
            .environmentObject(CloudKitSharingService.shared)
    }
}
