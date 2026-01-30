import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    init() {
        let settings = db.settings
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }

    // MARK: - Collection References

    func spacesCollection() -> CollectionReference {
        db.collection("spaces")
    }

    func groceryListsCollection(spaceId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("groceryLists")
    }

    func groceryItemsCollection(spaceId: String, listId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("groceryLists").document(listId).collection("items")
    }

    func choresCollection(spaceId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("chores")
    }

    func choreCompletionsCollection(spaceId: String, choreId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("chores").document(choreId).collection("completions")
    }

    func projectsCollection(spaceId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("projects")
    }

    func projectTasksCollection(spaceId: String, projectId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("projects").document(projectId).collection("tasks")
    }

    func remindersCollection(spaceId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("reminders")
    }

    func purchaseHistoryCollection(spaceId: String) -> CollectionReference {
        db.collection("spaces").document(spaceId).collection("purchaseHistory")
    }

    // MARK: - Space Operations

    func createSpace(_ space: SpaceModel) async throws -> String {
        let ref = try spacesCollection().addDocument(from: space)
        return ref.documentID
    }

    func fetchSpace(for uid: String) async throws -> SpaceModel? {
        let snapshot = try await spacesCollection()
            .whereField("memberUids", arrayContains: uid)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first?.data(as: SpaceModel.self)
    }

    func updateSpace(spaceId: String, data: [String: Any]) async throws {
        try await spacesCollection().document(spaceId).updateData(data)
    }

    func deleteSpace(spaceId: String) async throws {
        // Delete all subcollections first
        try await deleteSubcollection(spacesCollection().document(spaceId).collection("groceryLists"), spaceId: spaceId)
        try await deleteSubcollection(spacesCollection().document(spaceId).collection("chores"), spaceId: spaceId)
        try await deleteSubcollection(spacesCollection().document(spaceId).collection("projects"), spaceId: spaceId)
        try await deleteSubcollection(spacesCollection().document(spaceId).collection("reminders"))
        try await deleteSubcollection(spacesCollection().document(spaceId).collection("purchaseHistory"))
        try await spacesCollection().document(spaceId).delete()
    }

    private func deleteSubcollection(_ ref: CollectionReference, spaceId: String? = nil) async throws {
        let snapshot = try await ref.getDocuments()
        for doc in snapshot.documents {
            // Delete nested subcollections if needed
            if let spaceId = spaceId {
                let path = doc.reference.path
                if path.contains("groceryLists") {
                    let items = try await groceryItemsCollection(spaceId: spaceId, listId: doc.documentID).getDocuments()
                    for item in items.documents { try await item.reference.delete() }
                } else if path.contains("chores") {
                    let completions = try await choreCompletionsCollection(spaceId: spaceId, choreId: doc.documentID).getDocuments()
                    for c in completions.documents { try await c.reference.delete() }
                } else if path.contains("projects") {
                    let tasks = try await projectTasksCollection(spaceId: spaceId, projectId: doc.documentID).getDocuments()
                    for t in tasks.documents { try await t.reference.delete() }
                }
            }
            try await doc.reference.delete()
        }
    }

    // MARK: - Generic CRUD

    func addDocument<T: Encodable>(to collection: CollectionReference, data: T) async throws -> String {
        let ref = try collection.addDocument(from: data)
        return ref.documentID
    }

    func updateDocument<T: Encodable>(in collection: CollectionReference, id: String, data: T) async throws {
        try collection.document(id).setData(from: data, merge: true)
    }

    func deleteDocument(in collection: CollectionReference, id: String) async throws {
        try await collection.document(id).delete()
    }

    func listenToCollection<T: Decodable>(
        _ collection: CollectionReference,
        as type: T.Type,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        collection.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let items = documents.compactMap { try? $0.data(as: T.self) }
            onChange(items)
        }
    }
}
