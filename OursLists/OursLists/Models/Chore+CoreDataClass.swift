import Foundation
import CoreData

@objc(Chore)
public class Chore: NSManagedObject {
    // Frequency enum
    enum Frequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case biweekly = "Biweekly"
        case monthly = "Monthly"
        case custom = "Custom"

        var days: Int {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .biweekly: return 14
            case .monthly: return 30
            case .custom: return 0
            }
        }
    }

    // Assignment enum
    enum Assignment: String, CaseIterable {
        case me = "Me"
        case spouse = "Spouse"
        case both = "Both"
        case unassigned = "Unassigned"
    }

    var frequencyEnum: Frequency {
        get {
            guard let frequencyString = frequency else { return .weekly }
            return Frequency(rawValue: frequencyString) ?? .weekly
        }
        set {
            frequency = newValue.rawValue
        }
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

    // Computed: next due date
    var nextDueAt: Date? {
        guard let lastDone = lastDoneAt else {
            // If never done, it's due now
            return createdAt ?? Date()
        }

        let daysToAdd: Int
        if frequencyEnum == .custom {
            daysToAdd = Int(customDays)
        } else {
            daysToAdd = frequencyEnum.days
        }

        return Calendar.current.date(byAdding: .day, value: daysToAdd, to: lastDone)
    }

    // Computed: is overdue
    var isOverdue: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        return dueDate < Date()
    }

    // Computed: is due today
    var isDueToday: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    // Computed: is due soon (within 2 days)
    var isDueSoon: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return dueDate <= twoDaysFromNow && dueDate >= Date()
    }

    // Mark as done and record completion
    func markDone(completedBy: String? = nil) {
        lastDoneAt = Date()

        // Create completion record
        if let context = self.managedObjectContext {
            let completion = ChoreCompletion(context: context)
            completion.id = UUID()
            completion.completedAt = Date()
            completion.completedBy = completedBy
            completion.chore = self
        }

        // Reschedule notification for next occurrence
        NotificationService.shared.scheduleChoreNotification(for: self)
    }

    // Computed property to get all completions sorted by date
    var completionsArray: [ChoreCompletion] {
        let set = completions as? Set<ChoreCompletion> ?? []
        return set.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }

    // Most recent completion
    var lastCompletion: ChoreCompletion? {
        completionsArray.first
    }

    // Last completed by description
    var lastCompletedByDescription: String? {
        guard let completion = lastCompletion else { return nil }
        let timeAgo = completion.timeAgoDescription
        if let by = completion.completedBy, !by.isEmpty {
            return "\(timeAgo) by \(by)"
        }
        return timeAgo
    }

    // Human-readable due description
    var dueDescription: String {
        guard !isPaused else { return "Paused" }
        guard let dueDate = nextDueAt else { return "No due date" }

        if isOverdue {
            let days = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            if days == 0 {
                return "Due today"
            } else if days == 1 {
                return "1 day overdue"
            } else {
                return "\(days) days overdue"
            }
        } else if isDueToday {
            return "Due today"
        } else {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if days == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(days) days"
            }
        }
    }
}

extension Chore {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chore> {
        return NSFetchRequest<Chore>(entityName: "Chore")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var frequency: String?
    @NSManaged public var customDays: Int16
    @NSManaged public var assignedTo: String?
    @NSManaged public var lastDoneAt: Date?
    @NSManaged public var isPaused: Bool
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var completions: NSSet?
}

// MARK: - Generated accessors for completions
extension Chore {
    @objc(addCompletionsObject:)
    @NSManaged public func addToCompletions(_ value: ChoreCompletion)

    @objc(removeCompletionsObject:)
    @NSManaged public func removeFromCompletions(_ value: ChoreCompletion)

    @objc(addCompletions:)
    @NSManaged public func addToCompletions(_ values: NSSet)

    @objc(removeCompletions:)
    @NSManaged public func removeFromCompletions(_ values: NSSet)
}

extension Chore: Identifiable {}
