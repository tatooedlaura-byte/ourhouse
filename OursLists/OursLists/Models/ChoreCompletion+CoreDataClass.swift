import Foundation
import CoreData

@objc(ChoreCompletion)
public class ChoreCompletion: NSManagedObject {
    // Time ago description
    var timeAgoDescription: String {
        guard let completedAt = completedAt else { return "Unknown" }

        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: completedAt, to: now)

        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

extension ChoreCompletion {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChoreCompletion> {
        return NSFetchRequest<ChoreCompletion>(entityName: "ChoreCompletion")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var completedAt: Date?
    @NSManaged public var completedBy: String?
    @NSManaged public var chore: Chore?
}

extension ChoreCompletion: Identifiable {}
