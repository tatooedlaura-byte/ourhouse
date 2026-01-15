import Foundation
import UserNotifications
import CoreData

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    // Notification identifier prefixes
    private static let chorePrefix = "chore-"
    private static let taskPrefix = "task-"

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Chore Notifications

    func scheduleChoreNotification(for chore: Chore) {
        guard let choreId = chore.id?.uuidString,
              let title = chore.title,
              let dueDate = chore.nextDueAt,
              !chore.isPaused else {
            return
        }

        // Cancel existing notification for this chore
        cancelNotification(for: choreId, prefix: Self.chorePrefix)

        // Don't schedule if already overdue or due date is in the past
        guard dueDate > Date() else { return }

        // Schedule notification for the morning of the due date (9:00 AM)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Chore Due Today"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = "CHORE_REMINDER"
        content.userInfo = ["choreId": choreId]

        let request = UNNotificationRequest(
            identifier: "\(Self.chorePrefix)\(choreId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling chore notification: \(error)")
            }
        }
    }

    // MARK: - Task Notifications

    func scheduleTaskNotification(for task: ProjectTask) {
        guard let taskId = task.id?.uuidString,
              let title = task.title,
              let dueDate = task.dueDate,
              !task.isCompleted else {
            return
        }

        // Cancel existing notification for this task
        cancelNotification(for: taskId, prefix: Self.taskPrefix)

        // Don't schedule if already overdue
        guard dueDate > Date() else { return }

        // Schedule notification for the morning of the due date (9:00 AM)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Task Due Today"
        content.body = title
        if let projectName = task.project?.name {
            content.subtitle = projectName
        }
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskId": taskId]

        let request = UNNotificationRequest(
            identifier: "\(Self.taskPrefix)\(taskId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling task notification: \(error)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelNotification(for id: String, prefix: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(prefix)\(id)"])
    }

    func cancelChoreNotification(for chore: Chore) {
        guard let choreId = chore.id?.uuidString else { return }
        cancelNotification(for: choreId, prefix: Self.chorePrefix)
    }

    func cancelTaskNotification(for task: ProjectTask) {
        guard let taskId = task.id?.uuidString else { return }
        cancelNotification(for: taskId, prefix: Self.taskPrefix)
    }

    // MARK: - Reschedule All

    func rescheduleAllNotifications(context: NSManagedObjectContext) {
        // Cancel all existing notifications
        center.removeAllPendingNotificationRequests()

        // Reschedule chores
        let choreRequest: NSFetchRequest<Chore> = Chore.fetchRequest()
        choreRequest.predicate = NSPredicate(format: "isPaused == NO")

        if let chores = try? context.fetch(choreRequest) {
            for chore in chores {
                scheduleChoreNotification(for: chore)
            }
        }

        // Reschedule tasks with due dates
        let taskRequest: NSFetchRequest<ProjectTask> = ProjectTask.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "completedAt == nil AND dueDate != nil")

        if let tasks = try? context.fetch(taskRequest) {
            for task in tasks {
                scheduleTaskNotification(for: task)
            }
        }
    }
}
