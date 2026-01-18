import Foundation
import CoreData

@objc(Reminder)
public class Reminder: NSManagedObject {
    // Frequency enum - similar to Chore
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

    var frequencyEnum: Frequency {
        get {
            guard let frequencyString = frequency else { return .weekly }
            return Frequency(rawValue: frequencyString) ?? .weekly
        }
        set {
            frequency = newValue.rawValue
        }
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

    // Mark as done and calculate next due date
    func markDone() {
        lastCompletedAt = Date()

        // Calculate next due date based on frequency
        let daysToAdd: Int
        if frequencyEnum == .custom {
            daysToAdd = Int(customDays)
        } else {
            daysToAdd = frequencyEnum.days
        }

        nextDueAt = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())

        // Reschedule notification for next occurrence
        NotificationService.shared.scheduleReminderNotification(for: self)
    }

    // Snooze reminder by specified days (default 1 day)
    func snooze(days: Int = 1) {
        guard let currentDue = nextDueAt else {
            nextDueAt = Calendar.current.date(byAdding: .day, value: days, to: Date())
            return
        }

        // If already overdue, snooze from today; otherwise snooze from current due date
        let baseDate = currentDue < Date() ? Date() : currentDue
        nextDueAt = Calendar.current.date(byAdding: .day, value: days, to: baseDate)

        // Reschedule notification
        NotificationService.shared.scheduleReminderNotification(for: self)
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

    // Last completed description
    var lastCompletedDescription: String? {
        guard let lastDone = lastCompletedAt else { return nil }

        let days = Calendar.current.dateComponents([.day], from: lastDone, to: Date()).day ?? 0
        if days == 0 {
            return "Done today"
        } else if days == 1 {
            return "Done yesterday"
        } else {
            return "Done \(days) days ago"
        }
    }
}

extension Reminder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var frequency: String?
    @NSManaged public var customDays: Int16
    @NSManaged public var nextDueAt: Date?
    @NSManaged public var lastCompletedAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var isPaused: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
}

extension Reminder: Identifiable {}
