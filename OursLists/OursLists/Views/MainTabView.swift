import SwiftUI

struct MainTabView: View {
    @ObservedObject var space: Space
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTab(space: space)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            GroceriesTab(space: space)
                .tabItem {
                    Label("Groceries", systemImage: "cart.fill")
                }
                .tag(1)

            ChoresTab(space: space)
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }
                .tag(2)

            ProjectsTab(space: space)
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(3)

            RemindersTab(space: space)
                .tabItem {
                    Label("Reminders", systemImage: "bell.fill")
                }
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
