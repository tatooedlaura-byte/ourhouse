import Foundation
import FirebaseFirestore

class HouseholdService {
    static let shared = HouseholdService()
    private let db = Firestore.firestore()

    /// Invite a member by email — adds their email to invitedEmails on the space
    func inviteMember(email: String, to spaceId: String) async throws {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        try await db.collection("spaces").document(spaceId).updateData([
            "invitedEmails": FieldValue.arrayUnion([normalized])
        ])
    }

    /// Check if the given email has any pending invitations
    func checkPendingInvites(for email: String) async throws -> [SpaceModel] {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        let snapshot = try await db.collection("spaces")
            .whereField("invitedEmails", arrayContains: normalized)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: SpaceModel.self) }
    }

    /// Accept an invite — moves user from invitedEmails to memberUids/memberEmails
    func acceptInvite(spaceId: String, uid: String, email: String) async throws {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        try await db.collection("spaces").document(spaceId).updateData([
            "invitedEmails": FieldValue.arrayRemove([normalized]),
            "memberUids": FieldValue.arrayUnion([uid]),
            "memberEmails": FieldValue.arrayUnion([normalized])
        ])
    }

    /// Remove a member from the space
    func removeMember(uid: String, email: String, from spaceId: String) async throws {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        try await db.collection("spaces").document(spaceId).updateData([
            "memberUids": FieldValue.arrayRemove([uid]),
            "memberEmails": FieldValue.arrayRemove([normalized])
        ])
    }
}
