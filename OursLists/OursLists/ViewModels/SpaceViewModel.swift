import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SpaceViewModel: ObservableObject {
    @Published var space: SpaceModel?
    @Published var groceryLists: [GroceryListModel] = []
    @Published var chores: [ChoreModel] = []
    @Published var projects: [ProjectModel] = []
    @Published var reminders: [ReminderModel] = []
    @Published var purchaseHistory: [PurchaseHistoryModel] = []
    @Published var isLoading = true

    private let firestore = FirestoreService.shared
    private var listeners: [ListenerRegistration] = []

    var spaceId: String? { space?.id }

    // MARK: - Computed Properties for Tabs

    var groceryCount: Int {
        // We'll compute this from items loaded per list — for now badge from lists
        groceryLists.count
    }

    var urgentChoreCount: Int {
        chores.filter { !$0.isPaused && (($0.isOverdue) || $0.isDueToday || $0.isDueSoon) }.count
    }

    var urgentReminderCount: Int {
        reminders.filter { !$0.isPaused && ($0.isOverdue || $0.isDueToday || $0.isDueSoon) }.count
    }

    var activeProjectCount: Int {
        projects.filter { !$0.isArchived }.count
    }

    var frequentlyBoughtItems: [PurchaseHistoryModel] {
        Array(purchaseHistory.sorted { $0.purchaseCount > $1.purchaseCount }.prefix(20))
    }

    var recentlyBoughtItems: [PurchaseHistoryModel] {
        Array(purchaseHistory.sorted { $0.lastPurchasedAt > $1.lastPurchasedAt }.prefix(20))
    }

    // MARK: - Space Lifecycle

    func loadSpace(for uid: String) async {
        isLoading = true
        do {
            if let existing = try await firestore.fetchSpace(for: uid) {
                self.space = existing
                startListening()
            }
        } catch {
            print("Error loading space: \(error)")
        }
        isLoading = false
    }

    func createSpace(name: String, ownerName: String, uid: String, email: String) async {
        let newSpace = SpaceModel(name: name, ownerUid: uid, ownerName: ownerName, ownerEmail: email)
        do {
            let id = try await firestore.createSpace(newSpace)
            var created = newSpace
            created.id = id
            self.space = created

            // Create a default grocery list
            var defaultList = GroceryListModel(name: "Grocery List")
            let listId = try await firestore.addDocument(
                to: firestore.groceryListsCollection(spaceId: id),
                data: defaultList
            )
            defaultList.id = listId
            self.groceryLists = [defaultList]

            startListening()
        } catch {
            print("Error creating space: \(error)")
        }
    }

    func updateSpaceName(_ name: String) async {
        guard let spaceId else { return }
        do {
            try await firestore.updateSpace(spaceId: spaceId, data: ["name": name])
        } catch {
            print("Error updating space: \(error)")
        }
    }

    func updateOwnerName(_ name: String) async {
        guard let spaceId else { return }
        do {
            try await firestore.updateSpace(spaceId: spaceId, data: ["ownerName": name])
        } catch {
            print("Error updating owner: \(error)")
        }
    }

    func deleteSpace() async {
        guard let spaceId else { return }
        stopListening()
        do {
            try await firestore.deleteSpace(spaceId: spaceId)
            self.space = nil
            self.groceryLists = []
            self.chores = []
            self.projects = []
            self.reminders = []
            self.purchaseHistory = []
        } catch {
            print("Error deleting space: \(error)")
        }
    }

    // MARK: - Listeners

    func startListening() {
        guard let spaceId else { return }
        stopListening()

        listeners.append(firestore.listenToCollection(
            firestore.groceryListsCollection(spaceId: spaceId),
            as: GroceryListModel.self
        ) { [weak self] lists in
            Task { @MainActor in self?.groceryLists = lists.sorted { ($0.createdAt) < ($1.createdAt) } }
        })

        listeners.append(firestore.listenToCollection(
            firestore.choresCollection(spaceId: spaceId),
            as: ChoreModel.self
        ) { [weak self] chores in
            Task { @MainActor in self?.chores = chores }
        })

        listeners.append(firestore.listenToCollection(
            firestore.projectsCollection(spaceId: spaceId),
            as: ProjectModel.self
        ) { [weak self] projects in
            Task { @MainActor in self?.projects = projects }
        })

        listeners.append(firestore.listenToCollection(
            firestore.remindersCollection(spaceId: spaceId),
            as: ReminderModel.self
        ) { [weak self] reminders in
            Task { @MainActor in self?.reminders = reminders }
        })

        listeners.append(firestore.listenToCollection(
            firestore.purchaseHistoryCollection(spaceId: spaceId),
            as: PurchaseHistoryModel.self
        ) { [weak self] history in
            Task { @MainActor in self?.purchaseHistory = history }
        })
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Grocery Lists

    func addGroceryList(name: String) async {
        guard let spaceId else { return }
        let list = GroceryListModel(name: name)
        do {
            _ = try await firestore.addDocument(to: firestore.groceryListsCollection(spaceId: spaceId), data: list)
        } catch {
            print("Error adding grocery list: \(error)")
        }
    }

    func deleteGroceryList(_ list: GroceryListModel) async {
        guard let spaceId, let listId = list.id else { return }
        do {
            // Delete all items first
            let items = try await firestore.groceryItemsCollection(spaceId: spaceId, listId: listId).getDocuments()
            for item in items.documents { try await item.reference.delete() }
            try await firestore.deleteDocument(in: firestore.groceryListsCollection(spaceId: spaceId), id: listId)
        } catch {
            print("Error deleting grocery list: \(error)")
        }
    }

    // MARK: - Chores

    func addChore(_ chore: ChoreModel) async {
        guard let spaceId else { return }
        do {
            _ = try await firestore.addDocument(to: firestore.choresCollection(spaceId: spaceId), data: chore)
        } catch {
            print("Error adding chore: \(error)")
        }
    }

    func updateChore(_ chore: ChoreModel) async {
        guard let spaceId, let choreId = chore.id else { return }
        do {
            try await firestore.updateDocument(in: firestore.choresCollection(spaceId: spaceId), id: choreId, data: chore)
        } catch {
            print("Error updating chore: \(error)")
        }
    }

    func markChoreDone(_ chore: ChoreModel, completedBy: String?) async {
        guard let spaceId, let choreId = chore.id else { return }
        do {
            try await firestore.choresCollection(spaceId: spaceId).document(choreId).updateData([
                "lastDoneAt": Timestamp(date: Date())
            ])
            let completion = ChoreCompletionModel(completedBy: completedBy)
            _ = try await firestore.addDocument(
                to: firestore.choreCompletionsCollection(spaceId: spaceId, choreId: choreId),
                data: completion
            )
        } catch {
            print("Error marking chore done: \(error)")
        }
    }

    func deleteChore(_ chore: ChoreModel) async {
        guard let spaceId, let choreId = chore.id else { return }
        do {
            let completions = try await firestore.choreCompletionsCollection(spaceId: spaceId, choreId: choreId).getDocuments()
            for c in completions.documents { try await c.reference.delete() }
            try await firestore.deleteDocument(in: firestore.choresCollection(spaceId: spaceId), id: choreId)
        } catch {
            print("Error deleting chore: \(error)")
        }
    }

    // MARK: - Projects

    func addProject(_ project: ProjectModel) async {
        guard let spaceId else { return }
        do {
            _ = try await firestore.addDocument(to: firestore.projectsCollection(spaceId: spaceId), data: project)
        } catch {
            print("Error adding project: \(error)")
        }
    }

    func updateProject(_ project: ProjectModel) async {
        guard let spaceId, let projectId = project.id else { return }
        do {
            try await firestore.updateDocument(in: firestore.projectsCollection(spaceId: spaceId), id: projectId, data: project)
        } catch {
            print("Error updating project: \(error)")
        }
    }

    func deleteProject(_ project: ProjectModel) async {
        guard let spaceId, let projectId = project.id else { return }
        do {
            let tasks = try await firestore.projectTasksCollection(spaceId: spaceId, projectId: projectId).getDocuments()
            for t in tasks.documents { try await t.reference.delete() }
            try await firestore.deleteDocument(in: firestore.projectsCollection(spaceId: spaceId), id: projectId)
        } catch {
            print("Error deleting project: \(error)")
        }
    }

    // MARK: - Reminders

    func addReminder(_ reminder: ReminderModel) async {
        guard let spaceId else { return }
        do {
            _ = try await firestore.addDocument(to: firestore.remindersCollection(spaceId: spaceId), data: reminder)
        } catch {
            print("Error adding reminder: \(error)")
        }
    }

    func updateReminder(_ reminder: ReminderModel) async {
        guard let spaceId, let reminderId = reminder.id else { return }
        do {
            try await firestore.updateDocument(in: firestore.remindersCollection(spaceId: spaceId), id: reminderId, data: reminder)
        } catch {
            print("Error updating reminder: \(error)")
        }
    }

    func markReminderDone(_ reminder: ReminderModel) async {
        guard let spaceId, let reminderId = reminder.id else { return }
        do {
            try await firestore.remindersCollection(spaceId: spaceId).document(reminderId).updateData([
                "lastCompletedAt": Timestamp(date: Date())
            ])
        } catch {
            print("Error marking reminder done: \(error)")
        }
    }

    func deleteReminder(_ reminder: ReminderModel) async {
        guard let spaceId, let reminderId = reminder.id else { return }
        do {
            try await firestore.deleteDocument(in: firestore.remindersCollection(spaceId: spaceId), id: reminderId)
        } catch {
            print("Error deleting reminder: \(error)")
        }
    }

    // MARK: - Purchase History

    func recordPurchase(item: GroceryItemModel) async {
        guard let spaceId else { return }
        let collection = firestore.purchaseHistoryCollection(spaceId: spaceId)
        do {
            // Check for existing by normalized title
            let snapshot = try await collection.getDocuments()
            let existing = snapshot.documents.compactMap { try? $0.data(as: PurchaseHistoryModel.self) }
            if let match = existing.first(where: { $0.normalizedTitle == item.title.lowercased() }) {
                guard let matchId = match.id else { return }
                try await collection.document(matchId).updateData([
                    "purchaseCount": match.purchaseCount + 1,
                    "lastPurchasedAt": Timestamp(date: Date()),
                    "quantity": item.quantity as Any,
                    "category": item.category as Any
                ])
            } else {
                let history = PurchaseHistoryModel(
                    itemTitle: item.title,
                    quantity: item.quantity,
                    category: item.category
                )
                _ = try await firestore.addDocument(to: collection, data: history)
            }
        } catch {
            print("Error recording purchase: \(error)")
        }
    }
}
