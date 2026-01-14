import Foundation
import CoreData
import SwiftUI

@objc(Project)
public class Project: NSManagedObject {
    var tasksArray: [ProjectTask] {
        let set = tasks as? Set<ProjectTask> ?? []
        return set.sorted {
            // Incomplete first, then by priority, then by creation date
            if ($0.completedAt == nil) != ($1.completedAt == nil) {
                return $0.completedAt == nil
            }
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
        }
    }

    var incompleteTasks: [ProjectTask] {
        tasksArray.filter { $0.completedAt == nil }
    }

    var completedTasks: [ProjectTask] {
        tasksArray.filter { $0.completedAt != nil }
    }

    var progress: Double {
        guard !tasksArray.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasksArray.count)
    }

    var colorValue: Color {
        guard let colorHex = color else { return .blue }
        return Color(hex: colorHex) ?? .blue
    }
}

extension Project {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Project> {
        return NSFetchRequest<Project>(entityName: "Project")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var isArchived: Bool
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var tasks: NSSet?
}

// MARK: - Generated accessors for tasks
extension Project {
    @objc(addTasksObject:)
    @NSManaged public func addToTasks(_ value: ProjectTask)

    @objc(removeTasksObject:)
    @NSManaged public func removeFromTasks(_ value: ProjectTask)

    @objc(addTasks:)
    @NSManaged public func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged public func removeFromTasks(_ values: NSSet)
}

extension Project: Identifiable {}

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
