import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Space

struct SpaceModel: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var ownerUid: String
    var ownerName: String
    var memberUids: [String]
    var memberEmails: [String]
    var invitedEmails: [String]
    var createdAt: Date

    init(name: String, ownerUid: String, ownerName: String, ownerEmail: String) {
        self.name = name
        self.ownerUid = ownerUid
        self.ownerName = ownerName
        self.memberUids = [ownerUid]
        self.memberEmails = [ownerEmail]
        self.invitedEmails = []
        self.createdAt = Date()
    }
}

// MARK: - Grocery List

struct GroceryListModel: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var createdAt: Date

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Grocery Item

struct GroceryItemModel: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var quantity: String?
    var note: String?
    var isChecked: Bool
    var category: String?
    var createdBy: String?
    var createdAt: Date
    var updatedAt: Date

    init(title: String, quantity: String? = nil, note: String? = nil, category: String? = nil, createdBy: String? = nil) {
        self.title = title
        self.quantity = quantity
        self.note = note
        self.isChecked = false
        self.category = category
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var categoryEnum: GroceryCategory {
        GroceryCategory(rawValue: category ?? "") ?? .other
    }
}

enum GroceryCategory: String, CaseIterable, Codable {
    case produce = "Produce"
    case dairy = "Dairy"
    case meat = "Meat"
    case bakery = "Bakery"
    case frozen = "Frozen"
    case pantry = "Pantry"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case household = "Household"
    case personalCare = "Personal Care"
    case other = "Other"
}

// MARK: - Chore

struct ChoreModel: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var frequency: String
    var customDays: Int
    var assignedTo: String
    var lastDoneAt: Date?
    var isPaused: Bool
    var notes: String?
    var createdAt: Date

    init(title: String, frequency: String = "Daily", customDays: Int = 1, assignedTo: String = "Unassigned", notes: String? = nil) {
        self.title = title
        self.frequency = frequency
        self.customDays = customDays
        self.assignedTo = assignedTo
        self.lastDoneAt = nil
        self.isPaused = false
        self.notes = notes
        self.createdAt = Date()
    }

    var frequencyEnum: ChoreFrequency {
        ChoreFrequency(rawValue: frequency) ?? .daily
    }

    var assignmentEnum: ChoreAssignment {
        ChoreAssignment(rawValue: assignedTo) ?? .unassigned
    }

    var nextDueAt: Date? {
        if frequencyEnum == .oneTime {
            return lastDoneAt == nil ? createdAt : nil
        }
        guard let lastDone = lastDoneAt ?? Optional(createdAt) else { return nil }
        let calendar = Calendar.current
        switch frequencyEnum {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: lastDone)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: lastDone)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: lastDone)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: lastDone)
        case .custom:
            return calendar.date(byAdding: .day, value: max(1, customDays), to: lastDone)
        case .oneTime:
            return nil
        }
    }

    var isOverdue: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        return Calendar.current.isDateInToday(due)
    }

    var isDueSoon: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        let start = Calendar.current.startOfDay(for: Date())
        let threeDays = Calendar.current.date(byAdding: .day, value: 3, to: start)!
        return due > start && due <= threeDays
    }

    var isCompleted: Bool {
        frequencyEnum == .oneTime && lastDoneAt != nil
    }

    var dueDescription: String {
        if isPaused { return "Paused" }
        if isCompleted { return "Done" }
        guard let due = nextDueAt else { return "" }
        if Calendar.current.isDateInToday(due) { return "Due today" }
        if Calendar.current.isDateInTomorrow(due) { return "Due tomorrow" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: due)).day ?? 0
        if days < 0 { return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue" }
        return "Due in \(days) day\(days == 1 ? "" : "s")"
    }
}

enum ChoreFrequency: String, CaseIterable, Codable {
    case oneTime = "One-time"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case custom = "Custom"
}

enum ChoreAssignment: String, CaseIterable, Codable {
    case me = "Me"
    case spouse = "Spouse"
    case both = "Both"
    case unassigned = "Unassigned"
}

// MARK: - Chore Completion

struct ChoreCompletionModel: Codable, Identifiable {
    @DocumentID var id: String?
    var completedAt: Date
    var completedBy: String?

    init(completedBy: String? = nil) {
        self.completedAt = Date()
        self.completedBy = completedBy
    }

    var timeAgoDescription: String {
        let interval = Date().timeIntervalSince(completedAt)
        let days = Int(interval / 86400)
        if days == 0 {
            let hours = Int(interval / 3600)
            if hours == 0 {
                return "Just now"
            }
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

// MARK: - Project

struct ProjectModel: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var isArchived: Bool
    var color: String
    var createdAt: Date

    init(name: String, color: String = "#4A90D9") {
        self.name = name
        self.isArchived = false
        self.color = color
        self.createdAt = Date()
    }

    var colorValue: Color {
        Color(hex: color) ?? .blue
    }
}

// MARK: - Project Task

struct ProjectTaskModel: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var note: String?
    var createdAt: Date
    var completedAt: Date?
    var priority: Int
    var assignedTo: String?
    var dueDate: Date?

    init(title: String, note: String? = nil, priority: Int = 1, assignedTo: String? = nil, dueDate: Date? = nil) {
        self.title = title
        self.note = note
        self.createdAt = Date()
        self.completedAt = nil
        self.priority = priority
        self.assignedTo = assignedTo
        self.dueDate = dueDate
    }

    var isCompleted: Bool { completedAt != nil }

    var isOverdue: Bool {
        guard let due = dueDate, completedAt == nil else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var priorityEnum: TaskPriority {
        TaskPriority(rawValue: priority) ?? .medium
    }

    var assignmentEnum: ChoreAssignment {
        ChoreAssignment(rawValue: assignedTo ?? "") ?? .unassigned
    }
}

enum TaskPriority: Int, CaseIterable, Codable {
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

// MARK: - Reminder

struct ReminderModel: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var recurrenceType: String
    var dayOfMonth: Int
    var monthOfYear: Int
    var lastCompletedAt: Date?
    var notes: String?
    var isPaused: Bool
    var createdAt: Date

    init(title: String, recurrenceType: String = "Monthly", dayOfMonth: Int = 1, monthOfYear: Int = 1, notes: String? = nil) {
        self.title = title
        self.recurrenceType = recurrenceType
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.lastCompletedAt = nil
        self.isPaused = false
        self.notes = notes
        self.createdAt = Date()
    }

    var recurrenceEnum: RecurrenceType {
        RecurrenceType(rawValue: recurrenceType) ?? .monthly
    }

    var nextDueAt: Date? {
        let calendar = Calendar.current
        let now = Date()
        let day = max(1, min(28, dayOfMonth))

        switch recurrenceEnum {
        case .monthly:
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = day
            if let date = calendar.date(from: components), date > now {
                return date
            }
            components.month = (components.month ?? 1) + 1
            return calendar.date(from: components)

        case .quarterly:
            let quarterMonths = [1, 4, 7, 10]
            let currentMonth = calendar.component(.month, from: now)
            for qm in quarterMonths {
                var components = calendar.dateComponents([.year], from: now)
                components.month = qm
                components.day = day
                if let date = calendar.date(from: components), date > now {
                    return date
                }
            }
            var components = calendar.dateComponents([.year], from: now)
            components.year = (components.year ?? 2026) + 1
            components.month = 1
            components.day = day
            return calendar.date(from: components)

        case .yearly:
            var components = calendar.dateComponents([.year], from: now)
            components.month = max(1, min(12, monthOfYear))
            components.day = day
            if let date = calendar.date(from: components), date > now {
                return date
            }
            components.year = (components.year ?? 2026) + 1
            return calendar.date(from: components)
        }
    }

    var isDueToday: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        return Calendar.current.isDateInToday(due)
    }

    var isDueSoon: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        let start = Calendar.current.startOfDay(for: Date())
        let sevenDays = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        return due > start && due <= sevenDays
    }

    var isOverdue: Bool {
        guard !isPaused, let due = nextDueAt else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var dueDescription: String {
        if isPaused { return "Paused" }
        guard let due = nextDueAt else { return "" }
        if Calendar.current.isDateInToday(due) { return "Due today" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: due)).day ?? 0
        if days < 0 { return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days) days"
    }

    var recurrenceDescription: String {
        switch recurrenceEnum {
        case .monthly: return "Monthly on day \(dayOfMonth)"
        case .quarterly: return "Quarterly on day \(dayOfMonth)"
        case .yearly:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            var components = DateComponents()
            components.month = monthOfYear
            if let date = Calendar.current.date(from: components) {
                return "Yearly on \(formatter.string(from: date)) \(dayOfMonth)"
            }
            return "Yearly"
        }
    }
}

enum RecurrenceType: String, CaseIterable, Codable {
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}

// MARK: - Purchase History

struct PurchaseHistoryModel: Codable, Identifiable {
    @DocumentID var id: String?
    var itemTitle: String
    var quantity: String?
    var category: String?
    var purchaseCount: Int
    var lastPurchasedAt: Date
    var createdAt: Date

    init(itemTitle: String, quantity: String? = nil, category: String? = nil) {
        self.itemTitle = itemTitle
        self.quantity = quantity
        self.category = category
        self.purchaseCount = 1
        self.lastPurchasedAt = Date()
        self.createdAt = Date()
    }

    var normalizedTitle: String { itemTitle.lowercased() }

    var categoryEnum: GroceryCategory {
        GroceryCategory(rawValue: category ?? "") ?? .other
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#0000FF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
