import Foundation
import CoreData

@objc(Reminder)
public class Reminder: NSManagedObject {
    // Recurrence type enum
    enum RecurrenceType: String, CaseIterable {
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
    }

    var recurrenceTypeEnum: RecurrenceType {
        get {
            guard let typeString = recurrenceType else { return .monthly }
            return RecurrenceType(rawValue: typeString) ?? .monthly
        }
        set {
            recurrenceType = newValue.rawValue
        }
    }

    // Computed: next due date based on recurrence
    var nextDueAt: Date? {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.year, .month, .day], from: now)

        var targetComponents = DateComponents()
        targetComponents.day = Int(dayOfMonth)

        switch recurrenceTypeEnum {
        case .monthly:
            // Find next occurrence of this day of month
            targetComponents.year = currentComponents.year
            targetComponents.month = currentComponents.month

            if let targetDate = calendar.date(from: targetComponents) {
                // If already passed this month (and we completed it), go to next month
                if let lastCompleted = lastCompletedAt,
                   calendar.isDate(lastCompleted, equalTo: targetDate, toGranularity: .month) {
                    targetComponents.month = (currentComponents.month ?? 1) + 1
                    return calendar.date(from: targetComponents)
                }
                // If date already passed this month, go to next month
                if targetDate < now {
                    targetComponents.month = (currentComponents.month ?? 1) + 1
                }
                return calendar.date(from: targetComponents)
            }

        case .quarterly:
            // Every 3 months on the specified day
            let quarterMonths = [1, 4, 7, 10] // Jan, Apr, Jul, Oct
            targetComponents.year = currentComponents.year

            for month in quarterMonths {
                targetComponents.month = month
                if let targetDate = calendar.date(from: targetComponents), targetDate >= now {
                    if let lastCompleted = lastCompletedAt,
                       calendar.isDate(lastCompleted, equalTo: targetDate, toGranularity: .month) {
                        continue
                    }
                    return targetDate
                }
            }
            // Next year's first quarter
            targetComponents.year = (currentComponents.year ?? 2024) + 1
            targetComponents.month = 1
            return calendar.date(from: targetComponents)

        case .yearly:
            // Once a year on the specified month and day
            targetComponents.month = Int(monthOfYear)
            targetComponents.year = currentComponents.year

            if let targetDate = calendar.date(from: targetComponents) {
                if let lastCompleted = lastCompletedAt,
                   calendar.isDate(lastCompleted, equalTo: targetDate, toGranularity: .year) {
                    targetComponents.year = (currentComponents.year ?? 2024) + 1
                    return calendar.date(from: targetComponents)
                }
                if targetDate < now {
                    targetComponents.year = (currentComponents.year ?? 2024) + 1
                }
                return calendar.date(from: targetComponents)
            }
        }

        return nil
    }

    // Computed: is due today
    var isDueToday: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    // Computed: is due soon (within 7 days for reminders)
    var isDueSoon: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return dueDate <= weekFromNow && dueDate >= Date()
    }

    // Computed: is overdue
    var isOverdue: Bool {
        guard !isPaused, let dueDate = nextDueAt else { return false }
        return !Calendar.current.isDateInToday(dueDate) && dueDate < Date()
    }

    // Mark as done
    func markDone() {
        lastCompletedAt = Date()
    }

    // Human-readable due description
    var dueDescription: String {
        guard !isPaused else { return "Paused" }
        guard let dueDate = nextDueAt else { return "No due date" }

        let calendar = Calendar.current

        if isOverdue {
            let days = calendar.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            if days == 1 {
                return "1 day overdue"
            } else {
                return "\(days) days overdue"
            }
        } else if isDueToday {
            return "Due today"
        } else {
            let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if days == 1 {
                return "Due tomorrow"
            } else if days < 7 {
                return "Due in \(days) days"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "Due \(formatter.string(from: dueDate))"
            }
        }
    }

    // Recurrence description
    var recurrenceDescription: String {
        switch recurrenceTypeEnum {
        case .monthly:
            return "Every month on the \(ordinal(Int(dayOfMonth)))"
        case .quarterly:
            return "Every quarter on the \(ordinal(Int(dayOfMonth)))"
        case .yearly:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            var components = DateComponents()
            components.month = Int(monthOfYear)
            let monthName = formatter.monthSymbols[Int(monthOfYear) - 1]
            return "Every year on \(monthName) \(ordinal(Int(dayOfMonth)))"
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

extension Reminder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var recurrenceType: String?
    @NSManaged public var dayOfMonth: Int16
    @NSManaged public var monthOfYear: Int16
    @NSManaged public var lastCompletedAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var isPaused: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
}

extension Reminder: Identifiable {}
