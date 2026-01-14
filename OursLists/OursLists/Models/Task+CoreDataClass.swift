import Foundation
import CoreData

@objc(Task)
public class Task: NSManagedObject {
    enum Priority: Int16, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2

        var label: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }

    enum Assignment: String, CaseIterable {
        case me = "Me"
        case spouse = "Spouse"
        case both = "Both"
        case unassigned = "Unassigned"
    }

    var priorityEnum: Priority {
        get { Priority(rawValue: priority) ?? .medium }
        set { priority = newValue.rawValue }
    }

    var assignmentEnum: Assignment {
        get {
            guard let assignmentString = assignedTo else { return .unassigned }
            return Assignment(rawValue: assignmentString) ?? .unassigned
        }
        set {
            assignedTo = newValue.rawValue
        }
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    func toggleCompletion() {
        if completedAt != nil {
            completedAt = nil
        } else {
            completedAt = Date()
        }
    }
}

extension Task {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var note: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var priority: Int16
    @NSManaged public var assignedTo: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var project: Project?
}

extension Task: Identifiable {}
